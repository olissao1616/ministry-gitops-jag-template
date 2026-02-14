#!/usr/bin/env node
// Query GitHub for all repos in ORGS (orgs or users) and report which were created from TEMPLATE_FULL_NAME
// Usage: node scripts/template-report.mjs <outputFile>

import fs from 'node:fs/promises';
import path from 'node:path';

const outputFile = process.argv[2] || 'reports/template-usage.md';
const env = process.env;
const token = env.GH_TOKEN || env.GITHUB_TOKEN;
const orgs = (env.ORGS || '').split(/\s+/).filter(Boolean);
const templateFullName = env.TEMPLATE_FULL_NAME; // e.g., org/template-repo
const branchesToCheck = String(env.BRANCHES || env.PROTECT_BRANCHES || 'main,test,develop')
  .split(',')
  .map(s => s.trim())
  .filter(Boolean);
const MAX_PAGES = env.MAX_PAGES ? parseInt(env.MAX_PAGES, 10) : (env.FAST ? 1 : Infinity);
const newWithinHours = env.NEW_WITHIN_HOURS ? parseInt(env.NEW_WITHIN_HOURS, 10) : null;
const newJsonFile = env.NEW_JSON_FILE || null;

if (!token) {
  console.error('Missing GH_TOKEN/GITHUB_TOKEN in environment');
  process.exit(1);
}
if (!orgs.length) {
  console.error('No ORGS specified (space-separated). Values may be orgs or user accounts.');
  process.exit(1);
}
if (!templateFullName) {
  console.error('TEMPLATE_FULL_NAME is not set. Define a repository variable or set it in the workflow.');
  process.exit(1);
}

if (newWithinHours !== null && (!Number.isFinite(newWithinHours) || newWithinHours <= 0)) {
  console.error('NEW_WITHIN_HOURS must be a positive integer when set');
  process.exit(1);
}

const gh = async (url, { method = 'GET' } = {}) => {
  const res = await fetch(url, {
    method,
    headers: {
      'Authorization': `Bearer ${token}`,
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      'User-Agent': 'template-report-script'
    }
  });
  if (!res.ok) {
    const txt = await res.text();
    throw new Error(`${res.status} ${res.statusText}: ${txt}`);
  }
  return res.json();
};

const getHttpStatus = (err) => {
  const msg = err?.message || String(err);
  const m = msg.match(/^(\d{3})\s/);
  if (m) return parseInt(m[1], 10);
  return err?.status ?? err?.response?.status ?? null;
};

const mdEscape = (s) => String(s ?? '').replace(/\|/g, '\\|');

const sym = {
  ok: '✅',
  no: '❌',
  missing: '—',
  unknown: '⚠',
};

const yn = (v) => (v === true ? 'Yes' : v === false ? 'No' : '—');

const getEnabled = (obj) => {
  if (obj === null || obj === undefined) return null;
  if (typeof obj === 'boolean') return obj;
  if (typeof obj === 'object' && typeof obj.enabled === 'boolean') return obj.enabled;
  return null;
};

const fetchBranchExists = async (owner, repo, branch) => {
  try {
    await gh(`https://api.github.com/repos/${owner}/${repo}/branches/${encodeURIComponent(branch)}`);
    return true;
  } catch (err) {
    const status = getHttpStatus(err);
    if (status === 404) return false;
    throw err;
  }
};

const fetchBranchProtection = async (owner, repo, branch) => {
  try {
    const protection = await gh(`https://api.github.com/repos/${owner}/${repo}/branches/${encodeURIComponent(branch)}/protection`);
    const requiredStatusChecks = protection?.required_status_checks ?? null;
    const prReviews = protection?.required_pull_request_reviews ?? null;

    const contexts = Array.isArray(requiredStatusChecks?.contexts)
      ? requiredStatusChecks.contexts
      : (Array.isArray(requiredStatusChecks?.checks)
        ? requiredStatusChecks.checks.map(c => c?.context).filter(Boolean)
        : []);

    return {
      status: 'protected',
      strict: requiredStatusChecks ? Boolean(requiredStatusChecks.strict) : null,
      contexts,
      approvals: typeof prReviews?.required_approving_review_count === 'number' ? prReviews.required_approving_review_count : null,
      codeowners: prReviews ? Boolean(prReviews.require_code_owner_reviews) : null,
      dismissStale: prReviews ? Boolean(prReviews.dismiss_stale_reviews) : null,
      enforceAdmins: getEnabled(protection?.enforce_admins),
      linearHistory: getEnabled(protection?.required_linear_history),
      conversationResolution: getEnabled(protection?.required_conversation_resolution),
      allowForcePushes: getEnabled(protection?.allow_force_pushes),
      allowDeletions: getEnabled(protection?.allow_deletions),
    };
  } catch (err) {
    const status = getHttpStatus(err);
    if (status === 404) return { status: 'unprotected' };
    if (status === 403) return { status: 'unknown', message: 'Access denied reading protection (403)' };
    return { status: 'unknown', message: err?.message || String(err) };
  }
};

const ghGraphQL = async (query, variables) => {
  const res = await fetch('https://api.github.com/graphql', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      'User-Agent': 'template-report-script'
    },
    body: JSON.stringify({ query, variables })
  });
  const body = await res.json();
  if (!res.ok || body.errors) {
    const err = JSON.stringify(body.errors || body, null, 2);
    throw new Error(`GraphQL error: ${res.status} ${res.statusText}: ${err}`);
  }
  return body.data;
};

const paginate = async (url) => {
  const results = [];
  let page = 1;
  while (true) {
    const u = new URL(url);
    u.searchParams.set('per_page', '100');
    u.searchParams.set('page', String(page));
    const data = await gh(u.toString());
    if (!Array.isArray(data) || data.length === 0) break;
    results.push(...data);
    if (data.length < 100) break;
    page += 1;
  }
  return results;
};

const fetchOrgReposViaGraphQL = async (org) => {
  const nodes = [];
  let after = null;
  let pages = 0;
  const query = `
    query($org:String!, $after:String) {
      organization(login:$org) {
        repositories(first: 100, after: $after, orderBy: {field: CREATED_AT, direction: DESC}) {
          nodes {
            name
            nameWithOwner
            url
            createdAt
            templateRepository { nameWithOwner }
          }
          pageInfo { hasNextPage endCursor }
          totalCount
        }
      }
    }
  `;
  while (true) {
    if (pages >= MAX_PAGES) break;
    pages += 1;
    const data = await ghGraphQL(query, { org, after });
    const conn = data?.organization?.repositories;
    if (!conn) break;
    if (Array.isArray(conn.nodes)) nodes.push(...conn.nodes);
    if (!conn.pageInfo?.hasNextPage) break;
    after = conn.pageInfo.endCursor;
  }
  return nodes.map(n => ({
    name: n.name,
    full_name: n.nameWithOwner,
    html_url: n.url,
    created_at: n.createdAt,
    template_full_name: n.templateRepository?.nameWithOwner || null,
  }));
};

const fetchUserReposViaGraphQL = async (login) => {
  const nodes = [];
  let after = null;
  let pages = 0;
  const query = `
    query($login:String!, $after:String) {
      user(login:$login) {
        repositories(first: 100, after: $after, orderBy: {field: CREATED_AT, direction: DESC}) {
          nodes {
            name
            nameWithOwner
            url
            createdAt
            templateRepository { nameWithOwner }
          }
          pageInfo { hasNextPage endCursor }
          totalCount
        }
      }
    }
  `;
  while (true) {
    if (pages >= MAX_PAGES) break;
    pages += 1;
    const data = await ghGraphQL(query, { login, after });
    const conn = data?.user?.repositories;
    if (!conn) break;
    if (Array.isArray(conn.nodes)) nodes.push(...conn.nodes);
    if (!conn.pageInfo?.hasNextPage) break;
    after = conn.pageInfo.endCursor;
  }
  return nodes.map(n => ({
    name: n.name,
    full_name: n.nameWithOwner,
    html_url: n.url,
    created_at: n.createdAt,
    template_full_name: n.templateRepository?.nameWithOwner || null,
  }));
};

const fetchOwnerRepos = async (login) => {
  // Prefer GraphQL (fast, includes templateRepository) and fall back to REST.
  try {
    const orgRepos = await fetchOrgReposViaGraphQL(login);
    if (orgRepos.length > 0) return orgRepos;
  } catch {}

  try {
    const userRepos = await fetchUserReposViaGraphQL(login);
    if (userRepos.length > 0) return userRepos;
  } catch {}

  // REST fallback: try org listing, then user listing.
  let restRepos = [];
  try {
    restRepos = await paginate(`https://api.github.com/orgs/${login}/repos?type=all&sort=created&direction=desc`);
  } catch (e) {
    const msg = e?.message || String(e);
    if (msg.includes('404') || msg.includes('Not Found')) {
      restRepos = await paginate(`https://api.github.com/users/${login}/repos?type=all&sort=created&direction=desc`);
    } else {
      throw e;
    }
  }

  const repos = [];
  for (const r of restRepos) {
    try {
      const repo = await gh(`https://api.github.com/repos/${r.full_name}`);
      repos.push({
        name: r.name,
        full_name: r.full_name,
        html_url: r.html_url,
        created_at: r.created_at,
        template_full_name: repo.template_repository?.full_name || null,
      });
    } catch {}
  }
  return repos;
};

const main = async () => {
  const report = [];
  report.push('# Template usage report');
  report.push('');
  report.push(`Template: ${templateFullName}`);
  report.push(`Owners scanned: ${orgs.join(', ')}`);
  report.push(`Branches checked: ${branchesToCheck.join(', ')}`);
  report.push('Note: Branch protection status may show ⚠ if the token cannot read protection settings.');
  report.push('');

  const allRepos = [];
  const matches = [];
  let totalReposScanned = 0;

  for (const owner of orgs) {
    let repos = [];
    repos = await fetchOwnerRepos(owner);
    totalReposScanned += repos.length;

    for (const r of repos) {
      const isFromTemplate = r.template_full_name === templateFullName;
      const item = {
        owner,
        name: r.name,
        full_name: r.full_name,
        html_url: r.html_url,
        created_at: r.created_at,
        template_full_name: r.template_full_name,
        isFromTemplate,
      };
      allRepos.push(item);
      if (isFromTemplate) matches.push(item);
    }
  }

  // Per-repo branch protection checks
  for (const repo of allRepos) {
    const [owner, name] = repo.full_name.split('/', 2);
    repo.branches = {};
    for (const branch of branchesToCheck) {
      const exists = await fetchBranchExists(owner, name, branch).catch(err => {
        // If we can't even determine branch existence, treat as unknown.
        return null;
      });

      if (exists === false) {
        repo.branches[branch] = { exists: false, protection: { status: 'missing' } };
        continue;
      }
      if (exists === null) {
        repo.branches[branch] = { exists: null, protection: { status: 'unknown', message: 'Unable to read branch metadata' } };
        continue;
      }

      const protection = await fetchBranchProtection(owner, name, branch);
      repo.branches[branch] = { exists: true, protection };
    }
  }

  // Summary section
  report.push('## Summary');
  report.push('');
  report.push(`- Owners scanned: ${orgs.length}`);
  report.push(`- Total repos scanned: ${totalReposScanned}`);
  report.push(`- Total repos created from template: ${matches.length}`);
  report.push('');

  // Clean table: all repos
  report.push('## Repositories');
  report.push('');

  const header = ['Repo', 'Created', 'From template', ...branchesToCheck, 'Notes'];
  report.push(`| ${header.join(' | ')} |`);
  report.push(`| ${header.map(() => '---').join(' | ')} |`);

  for (const r of allRepos) {
    const repoLink = `[${mdEscape(r.full_name)}](${r.html_url})`;
    const created = mdEscape(r.created_at);
    const fromTemplate = r.isFromTemplate ? 'Yes' : 'No';

    const notes = [];
    const cells = [];
    for (const branch of branchesToCheck) {
      const info = r.branches?.[branch];
      if (!info) {
        cells.push(sym.unknown);
        continue;
      }
      if (info.exists === false) {
        cells.push(sym.missing);
        continue;
      }
      const p = info.protection;
      if (p?.status === 'protected') {
        cells.push(sym.ok);
      } else if (p?.status === 'unprotected') {
        cells.push(sym.no);
      } else if (p?.status === 'missing') {
        cells.push(sym.missing);
      } else {
        cells.push(sym.unknown);
        if (p?.message) notes.push(`${branch}: ${p.message}`);
      }
    }

    // Notes: surface missing branches and unknowns
    const missingBranches = branchesToCheck.filter(b => r.branches?.[b]?.exists === false);
    if (missingBranches.length) notes.push(`Missing branches: ${missingBranches.join(', ')}`);
    if (!notes.length) notes.push('');

    report.push(`| ${[repoLink, created, fromTemplate, ...cells, mdEscape(notes.join('; '))].join(' | ')} |`);
  }

  report.push('');
  report.push('Legend: ✅ protected, ❌ not protected, — branch missing, ⚠ unknown/insufficient permissions');
  report.push('');

  // Detailed tables per repo
  report.push('## Branch protection details');
  report.push('');

  for (const r of allRepos) {
    report.push(`### ${r.full_name}`);
    report.push('');
    report.push(`- URL: ${r.html_url}`);
    report.push(`- Created: ${r.created_at}`);
    report.push(`- From template: ${r.isFromTemplate ? 'Yes' : 'No'}`);
    report.push('');

    const h = ['Branch', 'Exists', 'Protection', 'Contexts', 'Strict', 'Approvals', 'Codeowners', 'Linear history', 'Conversation resolution', 'Admins enforced', 'Notes'];
    report.push(`| ${h.join(' | ')} |`);
    report.push(`| ${h.map(() => '---').join(' | ')} |`);

    for (const branch of branchesToCheck) {
      const info = r.branches?.[branch];
      if (!info) {
        report.push(`| ${mdEscape(branch)} | ${yn(null)} | ${sym.unknown} | — | — | — | — | — | — | — | No data |`);
        continue;
      }

      const exists = info.exists;
      if (exists === false) {
        report.push(`| ${mdEscape(branch)} | No | ${sym.missing} | — | — | — | — | — | — | — | Branch does not exist |`);
        continue;
      }
      if (exists === null) {
        report.push(`| ${mdEscape(branch)} | — | ${sym.unknown} | — | — | — | — | — | — | — | Unable to read branch metadata |`);
        continue;
      }

      const p = info.protection;
      if (p?.status === 'protected') {
        const contexts = (p.contexts && p.contexts.length) ? mdEscape(p.contexts.join(', ')) : '—';
        const strict = p.strict === null ? '—' : (p.strict ? 'Yes' : 'No');
        const approvals = typeof p.approvals === 'number' ? String(p.approvals) : '—';
        const codeowners = p.codeowners === null ? '—' : (p.codeowners ? 'Yes' : 'No');
        const linear = p.linearHistory === null ? '—' : (p.linearHistory ? 'Yes' : 'No');
        const conv = p.conversationResolution === null ? '—' : (p.conversationResolution ? 'Yes' : 'No');
        const admins = p.enforceAdmins === null ? '—' : (p.enforceAdmins ? 'Yes' : 'No');
        report.push(`| ${mdEscape(branch)} | Yes | ${sym.ok} | ${contexts} | ${strict} | ${approvals} | ${codeowners} | ${linear} | ${conv} | ${admins} |  |`);
      } else if (p?.status === 'unprotected') {
        report.push(`| ${mdEscape(branch)} | Yes | ${sym.no} | — | — | — | — | — | — | — | Not protected |`);
      } else {
        report.push(`| ${mdEscape(branch)} | Yes | ${sym.unknown} | — | — | — | — | — | — | — | ${mdEscape(p?.message || 'Unknown')} |`);
      }
    }

    report.push('');
  }

  await fs.writeFile(outputFile, report.join('\n'), 'utf8');

  // Optional: write a JSON list of newly-created repos from this template.
  if (newJsonFile && newWithinHours !== null) {
    const cutoff = new Date(Date.now() - (newWithinHours * 60 * 60 * 1000));
    const newlyCreated = matches
      .filter(m => {
        const created = new Date(m.created_at);
        return Number.isFinite(created.getTime()) && created >= cutoff;
      })
      .map(m => m.full_name)
      // Deduplicate and keep stable ordering
      .filter((v, i, a) => a.indexOf(v) === i);

    const dir = path.dirname(newJsonFile);
    if (dir && dir !== '.') {
      await fs.mkdir(dir, { recursive: true });
    }
    await fs.writeFile(newJsonFile, JSON.stringify({
      template: templateFullName,
      orgs,
      branches: branchesToCheck,
      newWithinHours,
      cutoff: cutoff.toISOString(),
      repos: newlyCreated,
    }, null, 2) + '\n', 'utf8');
  }
};

main().catch(err => {
  console.error(err.stack || err.message || String(err));
  process.exit(1);
});

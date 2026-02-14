#!/usr/bin/env node
// Template Security Posture Report
//
// - Discovers repos created from TEMPLATE_FULL_NAME under owners in ORGS
// - Generates a professional markdown report + JSON findings
// - Optionally opens PRs to auto-fix baseline files (CODEOWNERS, dependabot.yml)
//
// Usage: node scripts/template-security-report.mjs <markdownOutputFile>

import fs from 'node:fs/promises';
import path from 'node:path';

const outputFile = process.argv[2] || 'reports/template-security-report.md';
const env = process.env;

const token = env.GH_TOKEN || env.GITHUB_TOKEN;
const owners = (env.ORGS || '').split(/\s+/).filter(Boolean);
const templateFullName = env.TEMPLATE_FULL_NAME;

const branchesToCheck = String(env.BRANCHES || env.PROTECT_BRANCHES || 'main,test,develop')
  .split(',')
  .map(s => s.trim())
  .filter(Boolean);

const reportMode = String(env.REPORT_MODE || 'template-only').toLowerCase(); // template-only | all
const autoFix = String(env.AUTO_FIX || 'true').toLowerCase() === 'true';
const fixCodeowners = String(env.FIX_CODEOWNERS || 'true').toLowerCase() === 'true';
const fixDependabot = String(env.FIX_DEPENDABOT || 'true').toLowerCase() === 'true';
const maxAutofixPRs = env.MAX_AUTOFIX_PRS ? parseInt(env.MAX_AUTOFIX_PRS, 10) : 5;

const newWithinHours = env.NEW_WITHIN_HOURS ? parseInt(env.NEW_WITHIN_HOURS, 10) : null;
const jsonOutputFile = env.JSON_OUTPUT_FILE || 'reports/template-security-findings.json';

if (!token) {
  console.error('Missing GH_TOKEN/GITHUB_TOKEN in environment');
  process.exit(1);
}
if (!owners.length) {
  console.error('No ORGS specified (space-separated). Values may be orgs or user accounts.');
  process.exit(1);
}
if (!templateFullName) {
  console.error('TEMPLATE_FULL_NAME is not set');
  process.exit(1);
}

if (autoFix && !env.GH_TOKEN) {
  console.error('AUTO_FIX is enabled but GH_TOKEN is not set. Provide an admin-capable PAT/GitHub App token in GH_TOKEN to create PRs in other repos.');
  process.exit(1);
}

if (!Number.isFinite(maxAutofixPRs) || maxAutofixPRs < 0) {
  console.error('MAX_AUTOFIX_PRS must be a non-negative integer when set');
  process.exit(1);
}

const mdEscape = (s) => String(s ?? '').replace(/\|/g, '\\|');
const sym = { ok: '✅', no: '❌', missing: '—', unknown: '⚠' };

const getStatusEnabled = (obj) => {
  if (obj === null || obj === undefined) return null;
  if (typeof obj === 'boolean') return obj;
  if (typeof obj === 'object' && typeof obj.enabled === 'boolean') return obj.enabled;
  if (typeof obj === 'object' && typeof obj.status === 'string') return obj.status === 'enabled';
  if (typeof obj === 'string') return obj === 'enabled';
  return null;
};

const gh = async (url, { method = 'GET', body } = {}) => {
  const res = await fetch(url, {
    method,
    headers: {
      'Authorization': `Bearer ${token}`,
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      'User-Agent': 'template-security-report-script'
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!res.ok) {
    const txt = await res.text();
    const err = new Error(`${res.status} ${res.statusText}: ${txt}`);
    err.status = res.status;
    throw err;
  }
  // Some endpoints return empty bodies
  const ct = res.headers.get('content-type') || '';
  if (!ct.includes('application/json')) return null;
  return res.json();
};

const ghBooleanFrom204 = async (url) => {
  // Many GitHub security feature endpoints return:
  // - 204 if enabled
  // - 404 if disabled
  // - 403 if you lack permissions
  const res = await fetch(url, {
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      'User-Agent': 'template-security-report-script'
    },
  });

  if (res.status === 204) return true;
  if (res.status === 404) return false;
  if (res.status === 403) return null;
  if (res.ok) return true;

  const txt = await res.text();
  const err = new Error(`${res.status} ${res.statusText}: ${txt}`);
  err.status = res.status;
  throw err;
};

const ghGraphQL = async (query, variables) => {
  const res = await fetch('https://api.github.com/graphql', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      'User-Agent': 'template-security-report-script'
    },
    body: JSON.stringify({ query, variables })
  });
  const body = await res.json();
  if (!res.ok || body.errors) {
    const err = JSON.stringify(body.errors || body, null, 2);
    const e = new Error(`GraphQL error: ${res.status} ${res.statusText}: ${err}`);
    e.status = res.status;
    throw e;
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
  const query = `
    query($org:String!, $after:String) {
      organization(login:$org) {
        repositories(first: 100, after: $after, orderBy: {field: CREATED_AT, direction: DESC}) {
          nodes {
            name
            nameWithOwner
            url
            createdAt
            defaultBranchRef { name }
            templateRepository { nameWithOwner }
          }
          pageInfo { hasNextPage endCursor }
          totalCount
        }
      }
    }
  `;
  while (true) {
    const data = await ghGraphQL(query, { org, after });
    const conn = data?.organization?.repositories;
    if (!conn) break;
    if (Array.isArray(conn.nodes)) nodes.push(...conn.nodes);
    if (!conn.pageInfo?.hasNextPage) break;
    after = conn.pageInfo.endCursor;
  }
  return nodes.map(n => ({
    full_name: n.nameWithOwner,
    html_url: n.url,
    created_at: n.createdAt,
    default_branch: n.defaultBranchRef?.name || null,
    template_full_name: n.templateRepository?.nameWithOwner || null,
  }));
};

const fetchUserReposViaGraphQL = async (login) => {
  const nodes = [];
  let after = null;
  const query = `
    query($login:String!, $after:String) {
      user(login:$login) {
        repositories(first: 100, after: $after, orderBy: {field: CREATED_AT, direction: DESC}) {
          nodes {
            nameWithOwner
            url
            createdAt
            defaultBranchRef { name }
            templateRepository { nameWithOwner }
          }
          pageInfo { hasNextPage endCursor }
          totalCount
        }
      }
    }
  `;
  while (true) {
    const data = await ghGraphQL(query, { login, after });
    const conn = data?.user?.repositories;
    if (!conn) break;
    if (Array.isArray(conn.nodes)) nodes.push(...conn.nodes);
    if (!conn.pageInfo?.hasNextPage) break;
    after = conn.pageInfo.endCursor;
  }
  return nodes.map(n => ({
    full_name: n.nameWithOwner,
    html_url: n.url,
    created_at: n.createdAt,
    default_branch: n.defaultBranchRef?.name || null,
    template_full_name: n.templateRepository?.nameWithOwner || null,
  }));
};

const fetchOwnerRepos = async (login) => {
  try {
    const orgRepos = await fetchOrgReposViaGraphQL(login);
    if (orgRepos.length) return orgRepos;
  } catch {}

  try {
    const userRepos = await fetchUserReposViaGraphQL(login);
    if (userRepos.length) return userRepos;
  } catch {}

  // REST fallback (no templateRepository in list; we enrich per repo)
  let restRepos = [];
  try {
    restRepos = await paginate(`https://api.github.com/orgs/${login}/repos?type=all&sort=created&direction=desc`);
  } catch (e) {
    if (String(e?.message || e).includes('404')) {
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
        full_name: r.full_name,
        html_url: r.html_url,
        created_at: r.created_at,
        default_branch: repo?.default_branch || null,
        template_full_name: repo?.template_repository?.full_name || null,
      });
    } catch {}
  }
  return repos;
};

const fetchBranchExists = async (owner, repo, branch) => {
  try {
    await gh(`https://api.github.com/repos/${owner}/${repo}/branches/${encodeURIComponent(branch)}`);
    return true;
  } catch (err) {
    if (err?.status === 404) return false;
    return null;
  }
};

const getEnabled = (obj) => {
  if (obj === null || obj === undefined) return null;
  if (typeof obj === 'boolean') return obj;
  if (typeof obj === 'object' && typeof obj.enabled === 'boolean') return obj.enabled;
  return null;
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
      enforceAdmins: getEnabled(protection?.enforce_admins),
      linearHistory: getEnabled(protection?.required_linear_history),
      conversationResolution: getEnabled(protection?.required_conversation_resolution),
      allowForcePushes: getEnabled(protection?.allow_force_pushes),
      allowDeletions: getEnabled(protection?.allow_deletions),
    };
  } catch (err) {
    if (err?.status === 404) return { status: 'unprotected' };
    if (err?.status === 403) return { status: 'unknown', message: 'Access denied reading protection (403)' };
    return { status: 'unknown', message: err?.message || String(err) };
  }
};

const fetchSecurityAndAnalysis = async (owner, repo) => {
  try {
    const repoInfo = await gh(`https://api.github.com/repos/${owner}/${repo}`);
    const saa = repoInfo?.security_and_analysis ?? null;
    if (!saa) return { status: 'unknown', message: 'security_and_analysis not available (user repo or missing permissions)' };

    return {
      status: 'reported',
      advancedSecurity: getStatusEnabled(saa.advanced_security),
      secretScanning: getStatusEnabled(saa.secret_scanning),
      secretScanningPushProtection: getStatusEnabled(saa.secret_scanning_push_protection),
      dependabotSecurityUpdates: getStatusEnabled(saa.dependabot_security_updates),
    };
  } catch (err) {
    if (err?.status === 403) return { status: 'unknown', message: 'Access denied reading repo security settings (403)' };
    return { status: 'unknown', message: err?.message || String(err) };
  }
};

const fetchVulnerabilityAlertsEnabled = async (owner, repo) => {
  try {
    const enabled = await ghBooleanFrom204(`https://api.github.com/repos/${owner}/${repo}/vulnerability-alerts`);
    return enabled;
  } catch (err) {
    if (err?.status === 403) return null;
    return null;
  }
};

const fetchAutomatedSecurityFixesEnabled = async (owner, repo) => {
  try {
    const enabled = await ghBooleanFrom204(`https://api.github.com/repos/${owner}/${repo}/automated-security-fixes`);
    return enabled;
  } catch (err) {
    if (err?.status === 403) return null;
    return null;
  }
};

const fetchContent = async (owner, repo, ref, filePath) => {
  // Contents API
  const url = `https://api.github.com/repos/${owner}/${repo}/contents/${encodeURIComponent(filePath).replace(/%2F/g, '/')}`;
  return gh(`${url}?ref=${encodeURIComponent(ref)}`);
};

const tryFileExists = async (owner, repo, ref, filePath) => {
  try {
    const data = await fetchContent(owner, repo, ref, filePath);
    return Boolean(data);
  } catch (err) {
    if (err?.status === 404) return false;
    if (err?.status === 403) return null;
    return null;
  }
};

const listWorkflows = async (owner, repo, ref) => {
  try {
    const dir = await fetchContent(owner, repo, ref, '.github/workflows');
    if (!Array.isArray(dir)) return [];
    return dir
      .filter(e => e?.type === 'file' && typeof e?.path === 'string' && (e.path.endsWith('.yml') || e.path.endsWith('.yaml')))
      .map(e => ({ path: e.path, sha: e.sha }));
  } catch (err) {
    if (err?.status === 404) return [];
    return [];
  }
};

const getFileText = async (owner, repo, ref, filePath) => {
  const data = await fetchContent(owner, repo, ref, filePath);
  if (!data || data.type !== 'file' || !data.content) return '';
  const raw = Buffer.from(data.content, 'base64').toString('utf8');
  return raw;
};

const analyzeWorkflowText = (text) => {
  // Lightweight static analysis (no YAML parsing) – intentionally conservative.
  const lines = String(text || '').split(/\r?\n/);

  const usesRefs = [];
  for (const line of lines) {
    const m = line.match(/\buses:\s*([^\s#]+)\s*/);
    if (m) usesRefs.push(m[1]);
  }

  const pinned = usesRefs.filter(u => /@([0-9a-f]{40})$/.test(u)).length;
  const totalUses = usesRefs.length;
  const pinnedPct = totalUses ? Math.round((pinned / totalUses) * 100) : 100;

  const hasPullRequestTarget = /\bon:\s*[\s\S]*\bpull_request_target\b/.test(text);
  const checkoutPersistFalse = /uses:\s*actions\/checkout@[^\n]+[\s\S]*persist-credentials:\s*false/.test(text);
  const hasPermissionsBlock = /\bpermissions:\b/.test(text);

  return {
    totalUses,
    pinned,
    pinnedPct,
    hasPullRequestTarget,
    checkoutPersistFalse,
    hasPermissionsBlock,
  };
};

const b64 = (s) => Buffer.from(String(s), 'utf8').toString('base64');

const createOrUpdateFile = async ({ owner, repo, branch, filePath, content, message }) => {
  // Get existing SHA if file exists
  let sha = undefined;
  try {
    const existing = await gh(`https://api.github.com/repos/${owner}/${repo}/contents/${encodeURIComponent(filePath).replace(/%2F/g, '/')}?ref=${encodeURIComponent(branch)}`);
    sha = existing?.sha;
  } catch (err) {
    if (err?.status !== 404) throw err;
  }

  return gh(
    `https://api.github.com/repos/${owner}/${repo}/contents/${encodeURIComponent(filePath).replace(/%2F/g, '/')}`,
    {
      method: 'PUT',
      body: {
        message,
        content: b64(content),
        branch,
        sha,
      },
    }
  );
};

const getBranchRefSha = async (owner, repo, branch) => {
  try {
    const r = await gh(`https://api.github.com/repos/${owner}/${repo}/git/ref/heads/${encodeURIComponent(branch)}`);
    return r?.object?.sha || null;
  } catch (err) {
    if (err?.status === 404) return null;
    throw err;
  }
};

const setBranchRefSha = async (owner, repo, branch, sha, { force = false } = {}) => {
  return gh(`https://api.github.com/repos/${owner}/${repo}/git/refs/heads/${encodeURIComponent(branch)}`,
    {
      method: 'PATCH',
      body: { sha, force },
    }
  );
};

const findOpenPRForBranch = async ({ owner, repo, base, headBranch }) => {
  // List open PRs and find one that matches head branch.
  // Using list+filter avoids GitHub API quirks with head param in some cases.
  try {
    const prs = await gh(`https://api.github.com/repos/${owner}/${repo}/pulls?state=open&base=${encodeURIComponent(base)}&per_page=100`);
    if (!Array.isArray(prs)) return null;
    return prs.find(pr => pr?.head?.ref === headBranch) || null;
  } catch (err) {
    if (err?.status === 403) return null;
    throw err;
  }
};

const ensureFixPR = async ({ owner, repo, defaultBranch, fixes }) => {
  // fixes: [{path, content, message}]
  const repoInfo = await gh(`https://api.github.com/repos/${owner}/${repo}`);
  const base = defaultBranch || repoInfo?.default_branch || 'main';

  const baseRef = await gh(`https://api.github.com/repos/${owner}/${repo}/git/ref/heads/${encodeURIComponent(base)}`);
  const baseSha = baseRef?.object?.sha;
  if (!baseSha) throw new Error(`Unable to resolve base sha for ${owner}/${repo}:${base}`);

  // Stable branch so we don't open a new PR every run
  const branchName = 'security/template-baseline';

  // If an open PR already exists for this branch, reuse it.
  const existingPR = await findOpenPRForBranch({ owner, repo, base, headBranch: branchName });

  // Ensure branch exists. If branch exists and there is no open PR, reset it to the latest base.
  const existingBranchSha = await getBranchRefSha(owner, repo, branchName);
  if (!existingBranchSha) {
    await gh(`https://api.github.com/repos/${owner}/${repo}/git/refs`, {
      method: 'POST',
      body: { ref: `refs/heads/${branchName}`, sha: baseSha },
    });
  } else if (!existingPR) {
    // Keep branch fresh when it's not actively under review.
    await setBranchRefSha(owner, repo, branchName, baseSha, { force: true });
  }

  // Apply fixes
  for (const f of fixes) {
    await createOrUpdateFile({
      owner,
      repo,
      branch: branchName,
      filePath: f.path,
      content: f.content,
      message: f.message,
    });
  }

  if (existingPR) {
    return { branch: branchName, prUrl: existingPR?.html_url || null, prNumber: existingPR?.number || null, reused: true };
  }

  // Create PR
  const pr = await gh(`https://api.github.com/repos/${owner}/${repo}/pulls`, {
    method: 'POST',
    body: {
      title: 'chore(security): baseline repo security files',
      head: branchName,
      base,
      body: [
        'This PR is automatically generated by the template security cron job.',
        '',
        'Changes:',
        ...fixes.map(f => `- Add/update \`${f.path}\``),
        '',
        'If you prefer a team-based CODEOWNERS rule, update `.github/CODEOWNERS` accordingly.'
      ].join('\n'),
    },
  });

  return { branch: branchName, prUrl: pr?.html_url || null, prNumber: pr?.number || null, reused: false };
};

const buildCodeowners = (ownerLogin) => {
  return [
    '# This file was generated by the template security posture automation.',
    '# Update owners as appropriate (team-based ownership recommended for orgs).',
    `* @${ownerLogin}`,
    '',
  ].join('\n');
};

const buildDependabot = () => {
  return [
    'version: 2',
    'updates:',
    '  - package-ecosystem: "github-actions"',
    '    directory: "/"',
    '    schedule:',
    '      interval: "weekly"',
    '',
  ].join('\n');
};

const main = async () => {
  const findings = {
    generatedAt: new Date().toISOString(),
    template: templateFullName,
    owners,
    reportMode,
    autoFix,
    fixCodeowners,
    fixDependabot,
    branchesChecked: branchesToCheck,
    newWithinHours,
    reposScanned: 0,
    templateRepos: 0,
    templateReposNewInWindow: 0,
    repos: [],
  };

  const allRepos = [];
  const templateRepos = [];
  const templateReposNewInWindow = [];

  const cutoffMs = (newWithinHours !== null)
    ? (Date.now() - (newWithinHours * 60 * 60 * 1000))
    : null;

  for (const owner of owners) {
    const repos = await fetchOwnerRepos(owner);
    findings.reposScanned += repos.length;
    for (const r of repos) {
      const isFromTemplate = r.template_full_name === templateFullName;
      const item = {
        owner,
        full_name: r.full_name,
        html_url: r.html_url,
        created_at: r.created_at,
        default_branch: r.default_branch,
        template_full_name: r.template_full_name,
        isFromTemplate,
      };
      allRepos.push(item);
      if (isFromTemplate) {
        templateRepos.push(item);
        if (cutoffMs !== null) {
          const createdMs = Date.parse(String(r.created_at || ''));
          if (Number.isFinite(createdMs) && createdMs >= cutoffMs) templateReposNewInWindow.push(item);
        }
      }
    }
  }

  findings.templateRepos = templateRepos.length;
  findings.templateReposNewInWindow = templateReposNewInWindow.length;

  const displayRepos = reportMode === 'all' ? allRepos : templateRepos;

  let openedOrUpdatedPRs = 0;

  for (const repo of displayRepos) {
    const [owner, name] = repo.full_name.split('/', 2);
    const ref = repo.default_branch || 'main';

    const rec = {
      full_name: repo.full_name,
      url: repo.html_url,
      created_at: repo.created_at,
      from_template: repo.isFromTemplate,
      default_branch: ref,
      checks: {
        codeowners: { status: 'unknown' },
        dependabot: { status: 'unknown' },
        actions: { status: 'unknown' },
        security: { status: 'unknown' },
        branchProtection: { status: 'unknown', branches: {} },
      },
      autofix: { attempted: false, prUrl: null, reason: null, fixes: [] },
    };

    // CODEOWNERS
    const codeownersPaths = ['.github/CODEOWNERS', 'CODEOWNERS', 'docs/CODEOWNERS'];
    let codeownersFound = false;
    let codeownersUnknown = false;
    for (const p of codeownersPaths) {
      const exists = await tryFileExists(owner, name, ref, p);
      if (exists === true) { codeownersFound = true; break; }
      if (exists === null) codeownersUnknown = true;
    }
    if (codeownersFound) {
      rec.checks.codeowners = { status: 'present' };
    } else if (codeownersUnknown) {
      rec.checks.codeowners = { status: 'unknown', message: 'Unable to read repo contents (403?)' };
    } else {
      rec.checks.codeowners = { status: 'missing' };
    }

    // Dependabot
    const dep = await tryFileExists(owner, name, ref, '.github/dependabot.yml');
    if (dep === true) rec.checks.dependabot = { status: 'present' };
    else if (dep === false) rec.checks.dependabot = { status: 'missing' };
    else rec.checks.dependabot = { status: 'unknown', message: 'Unable to read repo contents (403?)' };

    // Security policy / basic security settings (report-only)
    const securityPolicyPaths = ['SECURITY.md', '.github/SECURITY.md', 'docs/SECURITY.md'];
    let securityPolicyFound = false;
    let securityPolicyUnknown = false;
    for (const p of securityPolicyPaths) {
      const exists = await tryFileExists(owner, name, ref, p);
      if (exists === true) { securityPolicyFound = true; break; }
      if (exists === null) securityPolicyUnknown = true;
    }

    const saa = await fetchSecurityAndAnalysis(owner, name);
    const vulnAlertsEnabled = await fetchVulnerabilityAlertsEnabled(owner, name);
    const autoSecurityFixesEnabled = await fetchAutomatedSecurityFixesEnabled(owner, name);

    rec.checks.security = {
      status: 'reported',
      securityPolicy: securityPolicyFound ? 'present' : (securityPolicyUnknown ? 'unknown' : 'missing'),
      vulnerabilityAlerts: vulnAlertsEnabled,
      automatedSecurityFixes: autoSecurityFixesEnabled,
      securityAndAnalysis: saa,
    };

    // Actions hardening (report-only)
    try {
      const workflows = await listWorkflows(owner, name, ref);
      const analyses = [];
      for (const wf of workflows) {
        const txt = await getFileText(owner, name, ref, wf.path);
        analyses.push({ path: wf.path, ...analyzeWorkflowText(txt) });
      }
      const totalUses = analyses.reduce((a, b) => a + b.totalUses, 0);
      const pinned = analyses.reduce((a, b) => a + b.pinned, 0);
      const pinnedPct = totalUses ? Math.round((pinned / totalUses) * 100) : 100;
      const hasPullRequestTarget = analyses.some(a => a.hasPullRequestTarget);
      const checkoutPersistFalse = analyses.some(a => a.checkoutPersistFalse);
      const hasPermissionsBlock = analyses.some(a => a.hasPermissionsBlock);
      rec.checks.actions = {
        status: 'reported',
        workflows: analyses,
        totalUses,
        pinned,
        pinnedPct,
        hasPullRequestTarget,
        checkoutPersistFalse,
        hasPermissionsBlock,
      };
    } catch (err) {
      rec.checks.actions = { status: 'unknown', message: err?.message || String(err) };
    }

    // Branch protection summary
    rec.checks.branchProtection.branches = {};
    for (const br of branchesToCheck) {
      const exists = await fetchBranchExists(owner, name, br);
      if (exists === false) {
        rec.checks.branchProtection.branches[br] = { exists: false, status: 'missing' };
        continue;
      }
      if (exists === null) {
        rec.checks.branchProtection.branches[br] = { exists: null, status: 'unknown' };
        continue;
      }
      const p = await fetchBranchProtection(owner, name, br);
      rec.checks.branchProtection.branches[br] = { exists: true, ...p };
    }

    // Auto-fix (PR-based)
    if (autoFix && openedOrUpdatedPRs < maxAutofixPRs) {
      const fixes = [];
      if (fixCodeowners && rec.checks.codeowners.status === 'missing') {
        fixes.push({
          path: '.github/CODEOWNERS',
          content: buildCodeowners(owner),
          message: 'chore(security): add CODEOWNERS',
        });
        rec.autofix.fixes.push('CODEOWNERS');
      }
      if (fixDependabot && rec.checks.dependabot.status === 'missing') {
        fixes.push({
          path: '.github/dependabot.yml',
          content: buildDependabot(),
          message: 'chore(security): add dependabot config',
        });
        rec.autofix.fixes.push('dependabot.yml');
      }

      if (fixes.length) {
        rec.autofix.attempted = true;
        try {
          const { prUrl, reused } = await ensureFixPR({
            owner,
            repo: name,
            defaultBranch: ref,
            fixes,
          });
          rec.autofix.prUrl = prUrl;
          openedOrUpdatedPRs += 1;
          rec.autofix.reused = Boolean(reused);
        } catch (err) {
          rec.autofix.reason = err?.message || String(err);
        }
      }
    } else if (autoFix && openedOrUpdatedPRs >= maxAutofixPRs) {
      rec.autofix.reason = `Skipped auto-fix: MAX_AUTOFIX_PRS=${maxAutofixPRs} reached for this run`;
    }

    findings.repos.push(rec);
  }

  // Markdown report
  const report = [];
  report.push('# Template security posture report');
  report.push('');
  report.push(`Template: ${templateFullName}`);
  report.push(`Owners scanned: ${owners.join(', ')}`);
  report.push(`Report mode: ${reportMode}`);
  report.push(`Branches checked: ${branchesToCheck.join(', ')}`);
  report.push(`Auto-fix via PRs: ${autoFix ? 'enabled' : 'disabled'}`);
  report.push(`Max auto-fix PRs per run: ${maxAutofixPRs}`);
  report.push('');

  report.push('## Summary');
  report.push('');
  report.push(`- Total repos scanned: ${findings.reposScanned}`);
  report.push(`- Template-derived repos: ${findings.templateRepos}`);
  if (newWithinHours !== null) {
    report.push(`- New window: last ${newWithinHours} hour(s)`);
    report.push(`- Template-derived repos created in window: ${findings.templateReposNewInWindow}`);
  }
  if (reportMode !== 'all') report.push(`- Note: Detailed checks are only performed for template-derived repos (REPORT_MODE=${reportMode})`);
  report.push('');

  if (newWithinHours !== null) {
    report.push('## New template-derived repositories (window)');
    report.push('');
    if (templateReposNewInWindow.length === 0) {
      report.push('- None');
      report.push('');
    } else {
      report.push('| Repo | Created | Default branch |');
      report.push('| --- | --- | --- |');
      for (const r of templateReposNewInWindow) {
        report.push(`| [${mdEscape(r.full_name)}](${r.html_url}) | ${r.created_at} | ${mdEscape(r.default_branch || '—')} |`);
      }
      report.push('');
    }
  }

  report.push('## Repositories (template-derived)');
  report.push('');

  const header = ['Repo', 'Created', 'CODEOWNERS', 'Dependabot', 'SECURITY.md', 'Vuln alerts', 'Secret scan', 'Push protect', 'Actions pinned', ...branchesToCheck, 'Auto-fix PR', 'Notes'];
  report.push(`| ${header.join(' | ')} |`);
  report.push(`| ${header.map(() => '---').join(' | ')} |`);

  for (const r of findings.repos) {
    const link = `[${mdEscape(r.full_name)}](${r.url})`;

    const co = r.checks.codeowners.status === 'present' ? sym.ok
      : r.checks.codeowners.status === 'missing' ? sym.no
        : sym.unknown;

    const dep = r.checks.dependabot.status === 'present' ? sym.ok
      : r.checks.dependabot.status === 'missing' ? sym.no
        : sym.unknown;

    const pinnedPct = r.checks.actions?.pinnedPct;
    const actionsCell = typeof pinnedPct === 'number' ? `${pinnedPct}%` : sym.unknown;

    const secPolicy = r.checks.security?.securityPolicy === 'present' ? sym.ok
      : r.checks.security?.securityPolicy === 'missing' ? sym.no
        : sym.unknown;

    const vulnAlerts = r.checks.security?.vulnerabilityAlerts === true ? sym.ok
      : r.checks.security?.vulnerabilityAlerts === false ? sym.no
        : sym.unknown;

    const secretScan = r.checks.security?.securityAndAnalysis?.secretScanning === true ? sym.ok
      : r.checks.security?.securityAndAnalysis?.secretScanning === false ? sym.no
        : sym.unknown;

    const pushProtect = r.checks.security?.securityAndAnalysis?.secretScanningPushProtection === true ? sym.ok
      : r.checks.security?.securityAndAnalysis?.secretScanningPushProtection === false ? sym.no
        : sym.unknown;

    const bpCells = branchesToCheck.map(br => {
      const b = r.checks.branchProtection.branches?.[br];
      if (!b) return sym.unknown;
      if (b.exists === false) return sym.missing;
      if (b.status === 'protected') return sym.ok;
      if (b.status === 'unprotected') return sym.no;
      return sym.unknown;
    });

    const pr = r.autofix?.prUrl ? `[PR](${r.autofix.prUrl})` : (r.autofix?.attempted ? sym.no : '');

    const notes = [];
    if (r.checks.actions?.hasPullRequestTarget) notes.push('Uses pull_request_target');
    if (r.checks.actions?.totalUses > 0 && r.checks.actions?.pinnedPct < 100) notes.push('Unpinned actions');
    if (r.checks.codeowners?.message) notes.push(`CODEOWNERS: ${r.checks.codeowners.message}`);
    if (r.autofix?.prUrl && Array.isArray(r.autofix?.fixes) && r.autofix.fixes.length) {
      notes.push(`Auto-fix pending merge (${r.autofix.fixes.join(', ')})`);
    }

    const cells = [
      link,
      r.created_at,
      co,
      dep,
      secPolicy,
      vulnAlerts,
      secretScan,
      pushProtect,
      actionsCell,
      ...bpCells,
      pr,
      mdEscape(notes.join('; ')),
    ];

    report.push(`| ${cells.join(' | ')} |`);
  }

  report.push('');
  report.push('Legend: ✅ compliant/present, ❌ missing/non-compliant, — branch missing, ⚠ unknown (permissions/API)');
  report.push('');

  report.push('## Branch protection details');
  report.push('');

  for (const r of findings.repos) {
    report.push(`### ${r.full_name}`);
    report.push('');
    report.push(`- URL: ${r.url}`);
    report.push(`- Default branch: ${r.default_branch}`);
    if (r.autofix?.prUrl) report.push(`- Auto-fix PR: ${r.autofix.prUrl}`);
    if (r.autofix?.reason) report.push(`- Auto-fix error: ${r.autofix.reason}`);
    report.push('');

    const h = ['Branch', 'Exists', 'Protected', 'Strict', 'Contexts', 'Approvals', 'Codeowners required', 'Linear history', 'Conversation resolution', 'Admins enforced', 'Notes'];
    report.push(`| ${h.join(' | ')} |`);
    report.push(`| ${h.map(() => '---').join(' | ')} |`);

    for (const br of branchesToCheck) {
      const b = r.checks.branchProtection.branches?.[br];
      if (!b) {
        report.push(`| ${mdEscape(br)} | ${sym.unknown} | ${sym.unknown} | — | — | — | — | — | — | — | No data |`);
        continue;
      }
      if (b.exists === false) {
        report.push(`| ${mdEscape(br)} | No | ${sym.missing} | — | — | — | — | — | — | — | Branch missing |`);
        continue;
      }
      if (b.status === 'protected') {
        report.push(`| ${mdEscape(br)} | Yes | ${sym.ok} | ${b.strict ? 'Yes' : 'No'} | ${mdEscape((b.contexts || []).join(', ') || '—')} | ${b.approvals ?? '—'} | ${b.codeowners === null ? '—' : (b.codeowners ? 'Yes' : 'No')} | ${b.linearHistory === null ? '—' : (b.linearHistory ? 'Yes' : 'No')} | ${b.conversationResolution === null ? '—' : (b.conversationResolution ? 'Yes' : 'No')} | ${b.enforceAdmins === null ? '—' : (b.enforceAdmins ? 'Yes' : 'No')} |  |`);
      } else if (b.status === 'unprotected') {
        report.push(`| ${mdEscape(br)} | Yes | ${sym.no} | — | — | — | — | — | — | — | Not protected |`);
      } else {
        report.push(`| ${mdEscape(br)} | ${b.exists === null ? '—' : 'Yes'} | ${sym.unknown} | — | — | — | — | — | — | — | ${mdEscape(b.message || 'Unknown')} |`);
      }
    }

    report.push('');
  }

  // Write outputs
  await fs.mkdir(path.dirname(outputFile), { recursive: true }).catch(() => {});
  await fs.writeFile(outputFile, report.join('\n'), 'utf8');

  await fs.mkdir(path.dirname(jsonOutputFile), { recursive: true }).catch(() => {});
  await fs.writeFile(jsonOutputFile, JSON.stringify(findings, null, 2) + '\n', 'utf8');
};

main().catch(err => {
  console.error(err.stack || err.message || String(err));
  process.exit(1);
});

#!/usr/bin/env node
// Query GitHub for all repos in ORGS and report which were created from TEMPLATE_FULL_NAME
// Usage: node scripts/template-report.mjs <outputFile>

import fs from 'node:fs/promises';
import path from 'node:path';

const outputFile = process.argv[2] || 'reports/template-usage.md';
const env = process.env;
const token = env.GH_TOKEN || env.GITHUB_TOKEN;
const orgs = (env.ORGS || '').split(/\s+/).filter(Boolean);
const templateFullName = env.TEMPLATE_FULL_NAME; // e.g., org/template-repo
const MAX_PAGES = env.MAX_PAGES ? parseInt(env.MAX_PAGES, 10) : (env.FAST ? 1 : Infinity);
const newWithinHours = env.NEW_WITHIN_HOURS ? parseInt(env.NEW_WITHIN_HOURS, 10) : null;
const newJsonFile = env.NEW_JSON_FILE || null;

if (!token) {
  console.error('Missing GH_TOKEN/GITHUB_TOKEN in environment');
  process.exit(1);
}
if (!orgs.length) {
  console.error('No ORGS specified (space-separated)');
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

const main = async () => {
  const report = [];
  report.push(`# Template usage report`);
  report.push("");
  report.push(`Template: ${templateFullName}`);
  report.push(`Orgs: ${orgs.join(', ')}`);
  report.push("");

  const [templateOwner, templateRepo] = templateFullName.split('/');
  if (!templateOwner || !templateRepo) {
    throw new Error('TEMPLATE_FULL_NAME must be in the form owner/repo');
  }

  const matches = [];

  for (const org of orgs) {
    report.push(`## Org: ${org}`);
    let repos = [];
    try {
      repos = await fetchOrgReposViaGraphQL(org);
    } catch (e) {
      // Fallback to REST if GraphQL fails
      const restRepos = await paginate(`https://api.github.com/orgs/${org}/repos?type=all&sort=created&direction=desc`);
      // Note: REST fallback will require per-repo fetch (slow); leave as last resort
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
    }
    report.push(`Found ${repos.length} repos${Number.isFinite(MAX_PAGES) ? ` (limited by MAX_PAGES=${MAX_PAGES})` : ''}`);

    for (const r of repos) {
      if (r.template_full_name === templateFullName) {
        matches.push({ org, name: r.name, full_name: r.full_name, html_url: r.html_url, created_at: r.created_at });
      }
    }

    // Write per-org section
    if (matches.filter(m => m.org === org).length) {
      report.push('Repos created from template:');
      for (const m of matches.filter(m => m.org === org)) {
        report.push(`- ${m.full_name} | ${m.html_url} | created: ${m.created_at}`);
      }
    } else {
      report.push('No repos found from template in this org.');
    }

    report.push("");
  }

  // Summary
  report.push('---');
  report.push(`Total matches: ${matches.length}`);

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

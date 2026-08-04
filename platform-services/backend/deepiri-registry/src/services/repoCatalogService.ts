import { secureLog } from '@team-deepiri/shared-utils';
import prisma from '../db';

const GITHUB_ORG = 'Team-Deepiri';
const SEED_REFRESH_INTERVAL_MS = 60 * 60 * 1000; // re-pull from GitHub at most once an hour

// Core, always-tier-0 repos: gateway/frontend/platform surface. Everything
// else pulled from the real org falls back to tier 1 unless overridden.
const TIER_0_REPOS = new Set([
  'deepiri-platform',
  'deepiri-api-gateway',
  'deepiri-web-frontend',
  'deepiri-auth-service',
  'deepiri-messaging-service',
]);

// Used only if the live GitHub API pull fails outright (no token, network
// error, rate limit) so the service still boots with *something* rather than
// an empty catalog — but this is explicitly a degraded-mode fallback, not a
// pretend-real catalog. ensureCatalogSeed() logs loudly when it's used.
const FALLBACK_REPOS = [
  { name: 'deepiri-platform', description: 'Platform monorepo and compose stack' },
  { name: 'deepiri-api-gateway', description: 'Edge API gateway' },
  { name: 'deepiri-web-frontend', description: 'Web frontend' },
  { name: 'diri-cyrex', description: 'Runtime inference and agent services' },
  { name: 'diri-helox', description: 'Training and MLOps' },
  { name: 'deepiri-auth-service', description: 'Authentication service' },
  { name: 'deepiri-messaging-service', description: 'Messaging and notifications' },
];

const DEFAULT_TOOLS = [
  { name: 'skaffold', kind: 'deploy', description: 'Local and cloud deploy profiles' },
  { name: 'deepiri-jobs', kind: 'orchestration', description: 'Async job runner including helox.train' },
  { name: 'synapse', kind: 'events', description: 'Redis stream event bus' },
];

interface GitHubRepo {
  name: string;
  html_url: string;
  description: string | null;
  archived: boolean;
}

async function fetchOrgRepos(): Promise<GitHubRepo[]> {
  const token = process.env.GITHUB_TOKEN?.trim();
  if (!token) {
    throw new Error('GITHUB_TOKEN is not configured; cannot pull the real org repo list');
  }

  const repos: GitHubRepo[] = [];
  let page = 1;
  // GitHub caps per_page at 100; a 56-repo org fits in a single page, but
  // paginate properly so this doesn't silently truncate as the org grows.
  for (;;) {
    const res = await fetch(
      `https://api.github.com/orgs/${GITHUB_ORG}/repos?per_page=100&page=${page}`,
      {
        headers: {
          Authorization: `Bearer ${token}`,
          Accept: 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
      },
    );
    if (!res.ok) {
      throw new Error(`GitHub API returned ${res.status} while listing ${GITHUB_ORG} repos`);
    }
    const batch = (await res.json()) as GitHubRepo[];
    if (batch.length === 0) break;
    repos.push(...batch);
    if (batch.length < 100) break;
    page += 1;
  }
  return repos;
}

let lastSeededAt = 0;

export async function ensureCatalogSeed(): Promise<void> {
  if (Date.now() - lastSeededAt < SEED_REFRESH_INTERVAL_MS) return;

  let repos: { name: string; description: string | null; githubUrl: string }[];
  try {
    const liveRepos = await fetchOrgRepos();
    repos = liveRepos
      .filter((r) => !r.archived)
      .map((r) => ({ name: r.name, description: r.description, githubUrl: r.html_url }));
    secureLog('info', `Registry: seeded catalog from live GitHub API (${repos.length} repos)`);
  } catch (err: unknown) {
    secureLog(
      'warn',
      'Registry: GitHub org pull failed, falling back to a small static repo list. ' +
        'Catalog will be incomplete until GITHUB_TOKEN is configured correctly.',
      err,
    );
    repos = FALLBACK_REPOS.map((r) => ({
      name: r.name,
      description: r.description,
      githubUrl: `https://github.com/${GITHUB_ORG}/${r.name}`,
    }));
  }

  for (const repo of repos) {
    const tier = TIER_0_REPOS.has(repo.name) ? 0 : 1;
    await prisma.repo.upsert({
      where: { org_name: { org: GITHUB_ORG, name: repo.name } },
      create: {
        org: GITHUB_ORG,
        name: repo.name,
        displayName: repo.name,
        githubUrl: repo.githubUrl,
        tier,
        description: repo.description ?? undefined,
      },
      update: {
        displayName: repo.name,
        githubUrl: repo.githubUrl,
        tier,
        description: repo.description ?? undefined,
      },
    });
  }

  for (const tool of DEFAULT_TOOLS) {
    await prisma.toolRegistration.upsert({
      where: { name: tool.name },
      create: tool,
      update: { kind: tool.kind, description: tool.description },
    });
  }

  lastSeededAt = Date.now();
}

export async function listRepos() {
  await ensureCatalogSeed();
  return prisma.repo.findMany({ orderBy: { name: 'asc' } });
}

export async function getRepo(id: string) {
  await ensureCatalogSeed();
  return prisma.repo.findUnique({ where: { id }, include: { healthChecks: { take: 1, orderBy: { checkedAt: 'desc' } } } });
}

export async function recordRepoHealth(repoId: string, status: string, detail?: string) {
  return prisma.repoHealthCheck.create({
    data: { repoId, status, detail },
  });
}

export async function listTools() {
  await ensureCatalogSeed();
  return prisma.toolRegistration.findMany({ orderBy: { name: 'asc' } });
}

export async function getEcosystemHealth() {
  await ensureCatalogSeed();
  const repos = await prisma.repo.findMany({
    include: { healthChecks: { take: 1, orderBy: { checkedAt: 'desc' } } },
  });
  const services = await prisma.registeredService.findMany();
  return {
    repos: repos.map((repo) => ({
      id: repo.id,
      name: repo.name,
      status: repo.healthChecks[0]?.status ?? 'unknown',
      lastChecked: repo.healthChecks[0]?.checkedAt ?? null,
    })),
    services: services.map((svc) => ({
      name: svc.name,
      status: svc.status,
      lastSeen: svc.lastSeen,
    })),
  };
}

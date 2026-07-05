import prisma from '../db';

const DEFAULT_REPOS = [
  { name: 'deepiri-platform', tier: 0, description: 'Platform monorepo and compose stack' },
  { name: 'deepiri-api-gateway', tier: 0, description: 'Edge API gateway' },
  { name: 'deepiri-web-frontend', tier: 0, description: 'Web frontend' },
  { name: 'diri-cyrex', tier: 1, description: 'Runtime inference and agent services' },
  { name: 'diri-helox', tier: 1, description: 'Training and MLOps' },
  { name: 'deepiri-auth-service', tier: 0, description: 'Authentication service' },
  { name: 'deepiri-messaging-service', tier: 0, description: 'Messaging and notifications' },
];

const DEFAULT_TOOLS = [
  { name: 'skaffold', kind: 'deploy', description: 'Local and cloud deploy profiles' },
  { name: 'deepiri-jobs', kind: 'orchestration', description: 'Async job runner including helox.train' },
  { name: 'synapse', kind: 'events', description: 'Redis stream event bus' },
];

let seeded = false;

export async function ensureCatalogSeed(): Promise<void> {
  if (seeded) return;

  for (const repo of DEFAULT_REPOS) {
    await prisma.repo.upsert({
      where: { org_name: { org: 'Team-Deepiri', name: repo.name } },
      create: {
        org: 'Team-Deepiri',
        name: repo.name,
        displayName: repo.name,
        githubUrl: `https://github.com/Team-Deepiri/${repo.name}`,
        tier: repo.tier,
        description: repo.description,
      },
      update: {
        displayName: repo.name,
        githubUrl: `https://github.com/Team-Deepiri/${repo.name}`,
        tier: repo.tier,
        description: repo.description,
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

  seeded = true;
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

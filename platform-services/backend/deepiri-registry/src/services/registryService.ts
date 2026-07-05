import prisma from '../db';

export interface RegistryEntry {
  name: string;
  repo?: string;
  healthUrl?: string;
  tier: 0 | 1 | 2 | 3;
  status: 'unknown' | 'healthy' | 'degraded' | 'down';
  lastSeen?: string;
  metadata?: Record<string, unknown>;
}

function toEntry(row: {
  name: string;
  repo: string | null;
  healthUrl: string | null;
  tier: number;
  status: string;
  lastSeen: Date | null;
  metadata: unknown;
}): RegistryEntry {
  return {
    name: row.name,
    repo: row.repo ?? undefined,
    healthUrl: row.healthUrl ?? undefined,
    tier: row.tier as RegistryEntry['tier'],
    status: row.status as RegistryEntry['status'],
    lastSeen: row.lastSeen?.toISOString(),
    metadata: (row.metadata ?? {}) as Record<string, unknown>,
  };
}

class RegistryService {
  async listServices(): Promise<RegistryEntry[]> {
    const rows = await prisma.registeredService.findMany({ orderBy: { name: 'asc' } });
    return rows.map(toEntry);
  }

  async getService(name: string): Promise<RegistryEntry | undefined> {
    const row = await prisma.registeredService.findUnique({ where: { name } });
    return row ? toEntry(row) : undefined;
  }

  async registerService(payload: Partial<RegistryEntry> & { name: string }): Promise<RegistryEntry> {
    const row = await prisma.registeredService.upsert({
      where: { name: payload.name },
      create: {
        name: payload.name,
        repo: payload.repo,
        healthUrl: payload.healthUrl,
        tier: payload.tier ?? 1,
        status: payload.status ?? 'unknown',
        lastSeen: new Date(),
        metadata: payload.metadata ?? {},
      },
      update: {
        repo: payload.repo,
        healthUrl: payload.healthUrl,
        tier: payload.tier,
        status: payload.status,
        lastSeen: new Date(),
        metadata: payload.metadata ?? {},
      },
    });
    return toEntry(row);
  }

  async pollHealth(): Promise<RegistryEntry[]> {
    const rows = await prisma.registeredService.findMany();
    const results: RegistryEntry[] = [];

    for (const row of rows) {
      if (!row.healthUrl) continue;
      let status: RegistryEntry['status'] = 'down';
      try {
        const res = await fetch(row.healthUrl, { signal: AbortSignal.timeout(5000) });
        status = res.ok ? 'healthy' : 'degraded';
      } catch {
        status = 'down';
      }
      const updated = await prisma.registeredService.update({
        where: { id: row.id },
        data: { status, lastSeen: new Date() },
      });
      results.push(toEntry(updated));
    }

    return results;
  }
}

export const registryService = new RegistryService();

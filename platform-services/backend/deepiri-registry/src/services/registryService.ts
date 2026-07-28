import { Prisma } from '@prisma/client';
import prisma from '../db';

// Known in-network services' fixed health-check URLs. registerService()
// accepts a caller-supplied healthUrl, so rather than validate that string
// and re-use any part of it, we use its hostname only as a lookup key into
// this fixed map and return the corresponding constant URL untouched --
// nothing from the caller's input ends up in the request pollHealth() sends.
// Otherwise a caller could aim the registry server's outbound requests at an
// arbitrary internal or external host (SSRF, CodeQL js/request-forgery).
const ALLOWED_HEALTH_URLS: Record<string, string> = {
  'api-gateway': 'http://api-gateway:5000/health',
  'auth-service': 'http://auth-service:5001/health',
  truss: 'http://truss:5002/health',
  registry: 'http://registry:5003/health',
  telemetry: 'http://telemetry:5004/health',
  'external-bridge-service': 'http://external-bridge-service:5006/health',
  jobs: 'http://jobs:5007/health',
  'realtime-gateway': 'http://realtime-gateway:5008/health',
  'language-intelligence-service': 'http://language-intelligence-service:5010/health',
  'messaging-service': 'http://messaging-service:5009/health',
  cyrex: 'http://cyrex:8000/health',
  synapse: 'http://synapse:8002/health',
  'sugar-glider': 'http://sugar-glider:8081/health',
};

/**
 * Resolves a caller-supplied healthUrl to one of the fixed URLs in
 * ALLOWED_HEALTH_URLS, selected by hostname. The caller's path/query are
 * discarded entirely, not incorporated into the result -- returns undefined
 * if the input doesn't name a known service.
 */
function resolveTrustedHealthUrl(value: string): string | undefined {
  let parsed: URL;
  try {
    parsed = new URL(value);
  } catch {
    return undefined;
  }
  return ALLOWED_HEALTH_URLS[parsed.hostname];
}

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
    if (payload.healthUrl && resolveTrustedHealthUrl(payload.healthUrl) === undefined) {
      throw new Error(`Rejected healthUrl for "${payload.name}": host is not an allowed internal service.`);
    }
    const row = await prisma.registeredService.upsert({
      where: { name: payload.name },
      create: {
        name: payload.name,
        repo: payload.repo,
        healthUrl: payload.healthUrl,
        tier: payload.tier ?? 1,
        status: payload.status ?? 'unknown',
        lastSeen: new Date(),
        metadata: (payload.metadata ?? {}) as Prisma.InputJsonValue,
      },
      update: {
        repo: payload.repo,
        healthUrl: payload.healthUrl,
        tier: payload.tier,
        status: payload.status,
        lastSeen: new Date(),
        metadata: (payload.metadata ?? {}) as Prisma.InputJsonValue,
      },
    });
    return toEntry(row);
  }

  async pollHealth(): Promise<RegistryEntry[]> {
    const rows = await prisma.registeredService.findMany();
    const results: RegistryEntry[] = [];

    for (const row of rows) {
      if (!row.healthUrl) continue;
      const trustedUrl = resolveTrustedHealthUrl(row.healthUrl);
      if (!trustedUrl) continue;
      let status: RegistryEntry['status'] = 'down';
      try {
        const res = await fetch(trustedUrl, { signal: AbortSignal.timeout(5000) });
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

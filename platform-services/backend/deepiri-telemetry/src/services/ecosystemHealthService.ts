import { Request, Response } from 'express';
import { secureLog } from '@team-deepiri/shared-utils';

export async function getEcosystemHealth(): Promise<{
  status: 'ok' | 'degraded';
  registry?: unknown;
  error?: string;
}> {
  const registryUrl = process.env.REGISTRY_URL?.trim();
  if (!registryUrl) {
    return { status: 'degraded', error: 'REGISTRY_URL is not configured' };
  }

  try {
    const res = await fetch(`${registryUrl.replace(/\/$/, '')}/health/ecosystem`, {
      signal: AbortSignal.timeout(5000),
    });
    if (!res.ok) {
      return { status: 'degraded', error: `Registry returned ${res.status}` };
    }
    const registry = await res.json();
    return { status: 'ok', registry };
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Registry health poll failed';
    secureLog('warn', 'Telemetry: ecosystem health poll failed', err);
    return { status: 'degraded', error: message };
  }
}

export async function handleGetEcosystemHealth(_req: Request, res: Response): Promise<void> {
  const health = await getEcosystemHealth();
  res.json(health);
}

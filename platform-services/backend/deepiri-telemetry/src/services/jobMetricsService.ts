import { Request, Response } from 'express';
import { secureLog } from '@team-deepiri/shared-utils';

export async function getJobMetrics(): Promise<{
  status: 'ok' | 'degraded';
  stats?: Record<string, number>;
  error?: string;
}> {
  const jobsUrl = process.env.JOBS_URL?.trim();
  if (!jobsUrl) {
    return { status: 'degraded', error: 'JOBS_URL is not configured' };
  }

  try {
    const res = await fetch(`${jobsUrl.replace(/\/$/, '')}/api/queues/stats`, {
      signal: AbortSignal.timeout(5000),
    });
    if (!res.ok) {
      return { status: 'degraded', error: `Jobs service returned ${res.status}` };
    }
    const body = (await res.json()) as { stats?: Record<string, number> };
    return { status: 'ok', stats: body.stats ?? {} };
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Jobs metrics poll failed';
    secureLog('warn', 'Telemetry: job metrics poll failed', err);
    return { status: 'degraded', error: message };
  }
}

export async function handleGetJobMetrics(_req: Request, res: Response): Promise<void> {
  const metrics = await getJobMetrics();
  res.json(metrics);
}

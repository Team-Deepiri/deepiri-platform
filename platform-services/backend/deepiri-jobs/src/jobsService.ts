import { Request, Response } from 'express';
import { secureLog } from '@team-deepiri/shared-utils';

export interface JobRecord {
  id: string;
  type: string;
  status: 'queued' | 'running' | 'completed' | 'failed';
  payload: Record<string, unknown>;
  createdAt: string;
  updatedAt: string;
  result?: Record<string, unknown>;
  error?: string;
}

const jobs = new Map<string, JobRecord>();

function newId(): string {
  return `job_${Date.now()}_${Math.random().toString(36).slice(2, 9)}`;
}

export async function handleCreateJob(req: Request, res: Response): Promise<void> {
  const { type, payload } = req.body ?? {};
  if (!type) {
    res.status(400).json({ error: 'type is required' });
    return;
  }
  const now = new Date().toISOString();
  const job: JobRecord = {
    id: newId(),
    type,
    status: 'queued',
    payload: payload ?? {},
    createdAt: now,
    updatedAt: now,
  };
  jobs.set(job.id, job);

  if (type === 'helox.train') {
    void triggerHeloxTraining(job);
  }

  res.status(201).json(job);
}

export function handleListJobs(_req: Request, res: Response): void {
  res.json({ jobs: Array.from(jobs.values()) });
}

export function handleGetJob(req: Request, res: Response): void {
  const job = jobs.get(req.params.id);
  if (!job) {
    res.status(404).json({ error: 'Job not found' });
    return;
  }
  res.json(job);
}

async function triggerHeloxTraining(job: JobRecord): Promise<void> {
  const heloxUrl = process.env.HELOX_URL || process.env.CYREX_URL || 'http://cyrex:8000';
  job.status = 'running';
  job.updatedAt = new Date().toISOString();
  jobs.set(job.id, job);

  try {
    const res = await fetch(`${heloxUrl}/training/runs`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(process.env.HELOX_API_KEY ? { 'x-api-key': process.env.HELOX_API_KEY } : {}),
      },
      body: JSON.stringify({ jobId: job.id, ...job.payload }),
    });
    const body = await res.json().catch(() => ({}));
    job.status = res.ok ? 'completed' : 'failed';
    job.result = body as Record<string, unknown>;
    if (!res.ok) job.error = `Helox returned ${res.status}`;
  } catch (err: unknown) {
    job.status = 'failed';
    job.error = err instanceof Error ? err.message : 'Helox request failed';
    secureLog('error', 'helox.train failed', err);
  }
  job.updatedAt = new Date().toISOString();
  jobs.set(job.id, job);
}

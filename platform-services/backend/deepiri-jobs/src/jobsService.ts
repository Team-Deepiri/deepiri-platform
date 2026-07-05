import { Job } from '@prisma/client';
import { Request, Response } from 'express';
import { secureLog } from '@team-deepiri/shared-utils';
import prisma from './db';

export type JobStatus = 'queued' | 'running' | 'completed' | 'failed';

export interface JobRecord {
  id: string;
  type: string;
  status: JobStatus;
  payload: Record<string, unknown>;
  createdAt: string;
  updatedAt: string;
  result?: Record<string, unknown>;
  error?: string;
}

function toRecord(job: Job): JobRecord {
  return {
    id: job.id,
    type: job.type,
    status: job.status as JobStatus,
    payload: (job.payload ?? {}) as Record<string, unknown>,
    createdAt: job.createdAt.toISOString(),
    updatedAt: job.updatedAt.toISOString(),
    result: job.result ? (job.result as Record<string, unknown>) : undefined,
    error: job.error ?? undefined,
  };
}

export async function handleCreateJob(req: Request, res: Response): Promise<void> {
  const { type, payload } = req.body ?? {};
  if (!type) {
    res.status(400).json({ error: 'type is required' });
    return;
  }

  const job = await prisma.job.create({
    data: {
      type,
      status: 'queued',
      payload: payload ?? {},
    },
  });

  if (type === 'helox.train') {
    void triggerHeloxTraining(job.id);
  }

  res.status(201).json(toRecord(job));
}

export async function handleListJobs(_req: Request, res: Response): Promise<void> {
  const jobs = await prisma.job.findMany({ orderBy: { createdAt: 'desc' } });
  res.json({ jobs: jobs.map(toRecord) });
}

export async function handleGetJob(req: Request, res: Response): Promise<void> {
  const job = await prisma.job.findUnique({ where: { id: req.params.id } });
  if (!job) {
    res.status(404).json({ error: 'Job not found' });
    return;
  }
  res.json(toRecord(job));
}

function resolveHeloxUrl(): string {
  const heloxUrl = process.env.HELOX_URL?.trim();
  if (!heloxUrl) {
    throw new Error('HELOX_URL is not configured');
  }
  return heloxUrl.replace(/\/$/, '');
}

async function triggerHeloxTraining(jobId: string): Promise<void> {
  let heloxUrl: string;
  try {
    heloxUrl = resolveHeloxUrl();
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'HELOX_URL is not configured';
    await prisma.job.update({
      where: { id: jobId },
      data: { status: 'failed', error: message },
    });
    secureLog('error', 'helox.train failed: missing HELOX_URL', err);
    return;
  }

  const job = await prisma.job.update({
    where: { id: jobId },
    data: { status: 'running' },
  });

  try {
    const res = await fetch(`${heloxUrl}/training/runs`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(process.env.HELOX_API_KEY ? { 'x-api-key': process.env.HELOX_API_KEY } : {}),
      },
      body: JSON.stringify({ jobId: job.id, ...(job.payload as Record<string, unknown>) }),
    });
    const body = await res.json().catch(() => ({}));
    await prisma.job.update({
      where: { id: jobId },
      data: {
        status: res.ok ? 'completed' : 'failed',
        result: body as Record<string, unknown>,
        error: res.ok ? null : `Helox returned ${res.status}`,
      },
    });
  } catch (err: unknown) {
    await prisma.job.update({
      where: { id: jobId },
      data: {
        status: 'failed',
        error: err instanceof Error ? err.message : 'Helox request failed',
      },
    });
    secureLog('error', 'helox.train failed', err);
  }
}

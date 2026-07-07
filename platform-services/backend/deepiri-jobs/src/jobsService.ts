import { Job, Prisma } from '@prisma/client';
import { Request, Response } from 'express';
import { secureLog } from '@team-deepiri/shared-utils';
import prisma from './db';

export type JobStatus = 'queued' | 'running' | 'completed' | 'failed' | 'cancelled';

export interface JobRecord {
  id: string;
  type: string;
  status: JobStatus;
  payload: Record<string, unknown>;
  labels: Record<string, string>;
  idempotencyKey?: string;
  createdAt: string;
  updatedAt: string;
  result?: Record<string, unknown>;
  error?: string;
}

const TERMINAL_STATUSES: JobStatus[] = ['completed', 'failed', 'cancelled'];

function toRecord(job: Job): JobRecord {
  return {
    id: job.id,
    type: job.type,
    status: job.status as JobStatus,
    payload: (job.payload ?? {}) as Record<string, unknown>,
    labels: (job.labels ?? {}) as Record<string, string>,
    idempotencyKey: job.idempotencyKey ?? undefined,
    createdAt: job.createdAt.toISOString(),
    updatedAt: job.updatedAt.toISOString(),
    result: job.result ? (job.result as Record<string, unknown>) : undefined,
    error: job.error ?? undefined,
  };
}

async function appendJobLog(jobId: string, line: string): Promise<void> {
  try {
    await prisma.jobLog.create({ data: { jobId, line } });
  } catch (err: unknown) {
    // Logging must never take down the job itself.
    secureLog('error', `failed to append job log for ${jobId}`, err);
  }
}

export async function handleCreateJob(req: Request, res: Response): Promise<void> {
  const { type, payload, labels, idempotencyKey } = req.body ?? {};
  if (!type) {
    res.status(400).json({ error: 'type is required' });
    return;
  }

  if (idempotencyKey) {
    const existing = await prisma.job.findUnique({ where: { idempotencyKey } });
    if (existing) {
      res.status(200).json(toRecord(existing));
      return;
    }
  }

  const job = await prisma.job.create({
    data: {
      type,
      status: 'queued',
      payload: payload ?? {},
      labels: labels ?? {},
      idempotencyKey: idempotencyKey ?? undefined,
    },
  });
  await appendJobLog(job.id, `Job created (type=${type})`);

  if (type === 'helox.train') {
    void triggerHeloxTraining(job.id);
  }

  res.status(201).json(toRecord(job));
}

export async function handleListJobs(req: Request, res: Response): Promise<void> {
  const { type, status, label } = req.query;
  const where: Record<string, unknown> = {};
  if (typeof type === 'string') where.type = type;
  if (typeof status === 'string') where.status = status;
  if (typeof label === 'string') {
    const [key, value] = label.split(':');
    if (key && value !== undefined) {
      where.labels = { path: [key], equals: value };
    }
  }

  const jobs = await prisma.job.findMany({ where, orderBy: { createdAt: 'desc' } });
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

export async function handleGetJobLogs(req: Request, res: Response): Promise<void> {
  const job = await prisma.job.findUnique({ where: { id: req.params.id } });
  if (!job) {
    res.status(404).json({ error: 'Job not found' });
    return;
  }
  const logs = await prisma.jobLog.findMany({
    where: { jobId: req.params.id },
    orderBy: { createdAt: 'asc' },
  });
  res.json({ logs: logs.map((l) => ({ line: l.line, createdAt: l.createdAt.toISOString() })) });
}

export async function handleCancelJob(req: Request, res: Response): Promise<void> {
  const job = await prisma.job.findUnique({ where: { id: req.params.id } });
  if (!job) {
    res.status(404).json({ error: 'Job not found' });
    return;
  }
  if (TERMINAL_STATUSES.includes(job.status as JobStatus)) {
    res.status(409).json({ error: `Job is already ${job.status} and cannot be cancelled` });
    return;
  }
  // NOTE: this only marks the job record cancelled locally -- there is no
  // Helox-side abort hook today, so an in-flight helox.train HTTP call will
  // still run to completion; its eventual result is just ignored once the
  // job is marked cancelled. Real cancellation of the remote run is a
  // follow-up once Helox exposes a cancel endpoint.
  const updated = await prisma.job.update({
    where: { id: req.params.id },
    data: { status: 'cancelled' },
  });
  await appendJobLog(job.id, 'Job cancelled by request');
  res.json(toRecord(updated));
}

export async function handleRetryJob(req: Request, res: Response): Promise<void> {
  const job = await prisma.job.findUnique({ where: { id: req.params.id } });
  if (!job) {
    res.status(404).json({ error: 'Job not found' });
    return;
  }
  if (job.status !== 'failed') {
    res.status(409).json({ error: `Only failed jobs can be retried (current status: ${job.status})` });
    return;
  }

  const retryJob = await prisma.job.create({
    data: {
      type: job.type,
      status: 'queued',
      payload: job.payload ?? {},
      labels: { ...((job.labels as Record<string, string>) ?? {}), retryOf: job.id },
    },
  });
  await appendJobLog(retryJob.id, `Retry of job ${job.id}`);

  if (retryJob.type === 'helox.train') {
    void triggerHeloxTraining(retryJob.id);
  }

  res.status(201).json(toRecord(retryJob));
}

export async function handleQueueStats(_req: Request, res: Response): Promise<void> {
  const counts = await prisma.job.groupBy({ by: ['status'], _count: true });
  const stats: Record<string, number> = {};
  for (const row of counts) {
    stats[row.status] = row._count;
  }
  res.json({ stats });
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
    await appendJobLog(jobId, `Failed: ${message}`);
    secureLog('error', 'helox.train failed: missing HELOX_URL', err);
    return;
  }

  const job = await prisma.job.update({
    where: { id: jobId },
    data: { status: 'running' },
  });
  await appendJobLog(jobId, `Dispatching to Helox at ${heloxUrl}`);

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
    // A job may have been cancelled locally while the Helox request was
    // in flight; don't clobber that terminal state with a late result.
    const current = await prisma.job.findUnique({ where: { id: jobId } });
    if (current?.status === 'cancelled') {
      await appendJobLog(jobId, 'Helox responded after job was cancelled; ignoring result');
      return;
    }
    await prisma.job.update({
      where: { id: jobId },
      data: {
        status: res.ok ? 'completed' : 'failed',
        result: body as Prisma.InputJsonValue,
        error: res.ok ? null : `Helox returned ${res.status}`,
      },
    });
    await appendJobLog(jobId, res.ok ? 'Completed successfully' : `Failed: Helox returned ${res.status}`);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Helox request failed';
    await prisma.job.update({
      where: { id: jobId },
      data: { status: 'failed', error: message },
    });
    await appendJobLog(jobId, `Failed: ${message}`);
    secureLog('error', 'helox.train failed', err);
  }
}

import cron from 'node-cron';
import { secureLog } from '@team-deepiri/shared-utils';
import prisma from './db';
import { PLATFORM_PG_BACKUP_JOB_TYPE, runPlatformPgBackup } from './platformPgBackup';

function isSchedulerEnabled(): boolean {
  return process.env.PG_BACKUP_SCHEDULER_ENABLED === 'true';
}

function scheduledIdempotencyKey(forDate: Date = new Date()): string {
  const day = forDate.toISOString().slice(0, 10);
  return `${PLATFORM_PG_BACKUP_JOB_TYPE}:${day}`;
}

export async function enqueuePlatformPgBackup(source: 'schedule' | 'manual' = 'manual'): Promise<string | null> {
  const idempotencyKey = source === 'schedule' ? scheduledIdempotencyKey() : undefined;

  if (idempotencyKey) {
    const existing = await prisma.job.findUnique({ where: { idempotencyKey } });
    if (existing) {
      secureLog('info', `platform.pg_backup already queued for today (${existing.id})`);
      return existing.id;
    }
  }

  const job = await prisma.job.create({
    data: {
      type: PLATFORM_PG_BACKUP_JOB_TYPE,
      status: 'queued',
      payload: { source },
      labels: { plane: 'platform', subsystem: 'backup' },
      idempotencyKey,
    },
  });

  await prisma.jobLog.create({
    data: { jobId: job.id, line: `Job created (type=${PLATFORM_PG_BACKUP_JOB_TYPE}, source=${source})` },
  });

  void runPlatformPgBackup(job.id);
  return job.id;
}

export function startBackupScheduler(): void {
  if (!isSchedulerEnabled()) {
    secureLog('info', 'PG backup scheduler disabled (PG_BACKUP_SCHEDULER_ENABLED != true)');
    return;
  }

  const schedule = process.env.PG_BACKUP_CRON?.trim() || '0 2 * * *';
  if (!cron.validate(schedule)) {
    secureLog('error', `Invalid PG_BACKUP_CRON: ${schedule}`);
    return;
  }

  cron.schedule(schedule, () => {
    void enqueuePlatformPgBackup('schedule');
  });

  secureLog('info', `PG backup scheduler active (${schedule})`);
}

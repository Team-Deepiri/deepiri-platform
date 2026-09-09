import { execFile } from 'node:child_process';
import { promises as fs } from 'node:fs';
import path from 'node:path';
import { promisify } from 'node:util';
import { secureLog } from '@team-deepiri/shared-utils';
import prisma from './db';

const execFileAsync = promisify(execFile);

export const PLATFORM_PG_BACKUP_JOB_TYPE = 'platform.pg_backup';

export interface PgBackupConfig {
  host: string;
  port: string;
  database: string;
  user: string;
  password: string;
  backupDir: string;
  retentionDays: number;
}

export function resolvePgBackupConfig(): PgBackupConfig {
  const password =
    process.env.PG_BACKUP_PASSWORD?.trim() ||
    process.env.POSTGRES_PASSWORD?.trim() ||
    process.env.POSTGRES_CORE_PASSWORD?.trim();

  if (!password) {
    throw new Error('PG backup password is not configured (PG_BACKUP_PASSWORD or POSTGRES_PASSWORD)');
  }

  return {
    host: process.env.PG_BACKUP_HOST?.trim() || process.env.POSTGRES_HOST?.trim() || 'postgres',
    port: process.env.PG_BACKUP_PORT?.trim() || process.env.POSTGRES_PORT?.trim() || '5432',
    database:
      process.env.PG_BACKUP_DB?.trim() ||
      process.env.POSTGRES_DB?.trim() ||
      process.env.POSTGRES_CORE_DB?.trim() ||
      'platform_core',
    user:
      process.env.PG_BACKUP_USER?.trim() ||
      process.env.POSTGRES_USER?.trim() ||
      process.env.POSTGRES_CORE_USER?.trim() ||
      'deepiri',
    password,
    backupDir: process.env.PG_BACKUP_DIR?.trim() || '/backups/postgres',
    retentionDays: parseInt(process.env.PG_BACKUP_RETENTION_DAYS || process.env.BACKUP_RETENTION_DAYS || '30', 10),
  };
}

async function appendJobLog(jobId: string, line: string): Promise<void> {
  try {
    await prisma.jobLog.create({ data: { jobId, line } });
  } catch (err: unknown) {
    secureLog('error', `failed to append job log for ${jobId}`, err);
  }
}

async function verifyPostgresConnection(config: PgBackupConfig): Promise<void> {
  await execFileAsync(
    'psql',
    ['-h', config.host, '-p', config.port, '-U', config.user, '-d', config.database, '-c', '\\q'],
    { env: { ...process.env, PGPASSWORD: config.password } },
  );
}

async function dumpDatabase(config: PgBackupConfig, sqlPath: string): Promise<void> {
  await execFileAsync(
    'pg_dump',
    [
      '-h',
      config.host,
      '-p',
      config.port,
      '-U',
      config.user,
      '-d',
      config.database,
      '--clean',
      '--if-exists',
      '--format=plain',
      '--no-owner',
      '--no-privileges',
      '-f',
      sqlPath,
    ],
    { env: { ...process.env, PGPASSWORD: config.password } },
  );
}

async function compressBackup(sqlPath: string): Promise<string> {
  await execFileAsync('gzip', ['-f', sqlPath]);
  return `${sqlPath}.gz`;
}

async function pruneOldBackups(config: PgBackupConfig): Promise<number> {
  const entries = await fs.readdir(config.backupDir);
  const cutoff = Date.now() - config.retentionDays * 24 * 60 * 60 * 1000;
  let removed = 0;

  for (const name of entries) {
    if (!name.startsWith('deepiri_backup_') || !name.endsWith('.sql.gz')) continue;
    const fullPath = path.join(config.backupDir, name);
    const stat = await fs.stat(fullPath);
    if (stat.mtimeMs < cutoff) {
      await fs.unlink(fullPath);
      removed += 1;
    }
  }

  return removed;
}

export async function runPlatformPgBackup(jobId: string): Promise<void> {
  let config: PgBackupConfig;
  try {
    config = resolvePgBackupConfig();
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'PG backup configuration error';
    await prisma.job.update({ where: { id: jobId }, data: { status: 'failed', error: message } });
    await appendJobLog(jobId, `Failed: ${message}`);
    secureLog('error', 'platform.pg_backup failed: bad config', err);
    return;
  }

  const concurrent = await prisma.job.findFirst({
    where: {
      type: PLATFORM_PG_BACKUP_JOB_TYPE,
      status: 'running',
      NOT: { id: jobId },
    },
  });
  if (concurrent) {
    const message = `Another backup is already running (${concurrent.id})`;
    await prisma.job.update({ where: { id: jobId }, data: { status: 'failed', error: message } });
    await appendJobLog(jobId, message);
    return;
  }

  await prisma.job.update({ where: { id: jobId }, data: { status: 'running', error: null } });
  await appendJobLog(jobId, `Starting pg_dump of ${config.database}@${config.host}:${config.port}`);

  const timestamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\..+/, '').replace('T', '_');
  const backupBase = `deepiri_backup_${timestamp}.sql`;
  const sqlPath = path.join(config.backupDir, backupBase);
  const gzPath = `${sqlPath}.gz`;

  try {
    await fs.mkdir(config.backupDir, { recursive: true });
    await verifyPostgresConnection(config);
    await appendJobLog(jobId, 'PostgreSQL connection verified');
    await dumpDatabase(config, sqlPath);
    await appendJobLog(jobId, `Dump written to ${backupBase}`);
    await compressBackup(sqlPath);
    const stat = await fs.stat(gzPath);
    await fs.symlink(path.basename(gzPath), path.join(config.backupDir, 'latest.sql.gz')).catch(async () => {
      await fs.unlink(path.join(config.backupDir, 'latest.sql.gz')).catch(() => undefined);
      await fs.symlink(path.basename(gzPath), path.join(config.backupDir, 'latest.sql.gz'));
    });
    const removed = await pruneOldBackups(config);
    await appendJobLog(jobId, `Retention cleanup removed ${removed} file(s)`);

    await prisma.job.update({
      where: { id: jobId },
      data: {
        status: 'completed',
        result: {
          file: path.basename(gzPath),
          path: gzPath,
          bytes: stat.size,
          database: config.database,
          host: config.host,
        },
      },
    });
    await appendJobLog(jobId, `Completed: ${path.basename(gzPath)} (${stat.size} bytes)`);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'pg_dump failed';
    await fs.unlink(sqlPath).catch(() => undefined);
    await fs.unlink(gzPath).catch(() => undefined);
    await prisma.job.update({ where: { id: jobId }, data: { status: 'failed', error: message } });
    await appendJobLog(jobId, `Failed: ${message}`);
    secureLog('error', 'platform.pg_backup failed', err);
  }
}

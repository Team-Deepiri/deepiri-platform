import express, { Express, Request, Response, ErrorRequestHandler } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import { Server } from 'node:http';
import { secureLog } from '@team-deepiri/shared-utils';
import {
  handleCreateJob,
  handleGetJob,
  handleListJobs,
  handleGetJobLogs,
  handleCancelJob,
  handleRetryJob,
  handleQueueStats,
} from './jobsService';
import { validateBodyIfPresent } from './middleware/inputValidation';
import { requireInternalAuth } from './middleware/requireInternalAuth';
import { startBackupScheduler, stopBackupScheduler } from './backupScheduler';
import { connectDatabase, disconnectDatabase } from './db';
import { PLATFORM_PG_BACKUP_JOB_TYPE } from './platformPgBackup';

dotenv.config();

const app: Express = express();
const PORT: number = parseInt(process.env.PORT || '5007', 10);

app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '100kb' }));
app.use(validateBodyIfPresent());

app.get('/health', (_req: Request, res: Response) => {
  res.json({
    status: 'healthy',
    service: 'deepiri-jobs',
    capabilities: ['async-jobs', 'helox.train', PLATFORM_PG_BACKUP_JOB_TYPE],
    timestamp: new Date().toISOString(),
  });
});

app.get('/api/jobs', requireInternalAuth, handleListJobs);
app.post('/api/jobs', requireInternalAuth, handleCreateJob);
app.get('/api/jobs/:id', requireInternalAuth, handleGetJob);
app.get('/api/jobs/:id/logs', requireInternalAuth, handleGetJobLogs);
app.post('/api/jobs/:id/cancel', requireInternalAuth, handleCancelJob);
app.post('/api/jobs/:id/retry', requireInternalAuth, handleRetryJob);
app.get('/api/queues/stats', requireInternalAuth, handleQueueStats);

const errorHandler: ErrorRequestHandler = (err, _req, res, _next) => {
  secureLog('error', 'Jobs service error:', err);
  res.status(500).json({ error: 'Internal server error' });
};
app.use(errorHandler);

let server: Server | undefined;

async function startServer(): Promise<void> {
  await connectDatabase();
  startBackupScheduler();
  server = app.listen(PORT, () => {
    secureLog('info', `Jobs service running on port ${PORT}`);
  });
}

async function shutdown(signal: string): Promise<void> {
  secureLog('info', `Received ${signal}; shutting down jobs service`);
  stopBackupScheduler();
  server?.close();
  await disconnectDatabase();
  process.exit(0);
}

process.on('SIGTERM', () => {
  void shutdown('SIGTERM');
});
process.on('SIGINT', () => {
  void shutdown('SIGINT');
});

void startServer().catch((err: Error) => {
  secureLog('error', 'Jobs service failed to start', err);
  void disconnectDatabase().finally(() => process.exit(1));
});

export default app;

import express, { Express, Request, Response, ErrorRequestHandler } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
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
import { startBackupScheduler } from './backupScheduler';
import { connectDatabase } from './db';
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

app.get('/api/jobs', handleListJobs);
app.post('/api/jobs', handleCreateJob);
app.get('/api/jobs/:id', handleGetJob);
app.get('/api/jobs/:id/logs', handleGetJobLogs);
app.post('/api/jobs/:id/cancel', handleCancelJob);
app.post('/api/jobs/:id/retry', handleRetryJob);
app.get('/api/queues/stats', handleQueueStats);

const errorHandler: ErrorRequestHandler = (err, _req, res, _next) => {
  secureLog('error', 'Jobs service error:', err);
  res.status(500).json({ error: 'Internal server error' });
};
app.use(errorHandler);

app.listen(PORT, async () => {
  await connectDatabase();
  startBackupScheduler();
  secureLog('info', `Jobs service running on port ${PORT}`);
});

export default app;

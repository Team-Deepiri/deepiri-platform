import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import { config } from './config/environment';
import { logger } from './utils/logger';
import { initializeEventPublisher } from './streaming/eventPublisher';
import healthRoutes from './routes/healthRoutes';
import documentRoutes from './routes/documentRoutes';
import structuredDataRoutes from './routes/structuredDataRoutes';

dotenv.config();

const app = express();

app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '10mb' }));

app.use('/', healthRoutes);
app.use('/documents', documentRoutes);
app.use('/data', structuredDataRoutes);

app.use((err: Error, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  logger.error('Unhandled error', { error: err.message, stack: err.stack });
  res.status(500).json({ error: 'Internal server error' });
});

async function start() {
  try {
    await initializeEventPublisher();
    logger.info('Event publisher initialised');
  } catch (err) {
    logger.warn('Event publisher unavailable at startup – will retry on first publish', { error: (err as Error).message });
  }

  app.listen(config.port, () => {
    logger.info(`Data Ingestion Service running on port ${config.port}`);
  });
}

start();

export { app };

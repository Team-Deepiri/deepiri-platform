import express, { Express, Request, Response, ErrorRequestHandler } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import winston from 'winston';
import routes from './index';
import { connectDatabase } from './db';

dotenv.config();

const app: Express = express();
const PORT: number = parseInt(process.env.PORT || '5002', 10);

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [new winston.transports.Console({ format: winston.format.simple() })]
});

app.use(helmet());
app.use(cors());
app.use(express.json());

// PostgreSQL connection via Prisma
connectDatabase()
  .catch((err: Error) => {
    logger.error('Task Orchestrator: Failed to connect to PostgreSQL', err);
    process.exit(1);
  });

// Initialize event publisher
import { initializeEventPublisher } from './streaming/eventPublisher';
initializeEventPublisher().catch((err) => {
  logger.error('Failed to initialize event publisher:', err);
});

app.get('/health', (req: Request, res: Response) => {
  res.json({ status: 'healthy', service: 'task-orchestrator', timestamp: new Date().toISOString() });
});

app.use('/', routes);

const errorHandler: ErrorRequestHandler = (err, req, res, next) => {
  logger.error('Task Orchestrator error:', err);
  res.status(500).json({ error: 'Internal server error' });
};
app.use(errorHandler);

app.listen(PORT, () => {
  logger.info(`Task Orchestrator running on port ${PORT}`);
});

export default app;


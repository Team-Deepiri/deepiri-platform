import express, { Express, Request, Response, ErrorRequestHandler } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import { secureLog } from '@team-deepiri/shared-utils';
import routes from './index';
import { connectDatabase } from './db';
import { validateBodyIfPresent } from './middleware/inputValidation';
import { startEventConsumption } from './streaming/eventConsumer';

dotenv.config();

const app: Express = express();
const PORT: number = parseInt(process.env.PORT || '5003', 10);

app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '100kb' }));
app.use(validateBodyIfPresent());

// PostgreSQL connection via Prisma
connectDatabase()
  .catch((err: Error) => {
    secureLog('error', 'Engagement Service: Failed to connect to PostgreSQL', err);
    process.exit(1);
  });

// Redis Streams consumer — react to platform events (task completions, registrations, etc.)
startEventConsumption().catch((err: Error) => {
  secureLog('error', 'Engagement Service: Failed to start event consumption', err);
});

app.get('/health', (req: Request, res: Response) => {
  res.json({ status: 'healthy', service: 'engagement-service', timestamp: new Date().toISOString() });
});

app.use('/', routes);

const errorHandler: ErrorRequestHandler = (err, req, res, next) => {
  secureLog('error', 'Engagement Service error:', err);
  res.status(500).json({ error: 'Internal server error' });
};
app.use(errorHandler);

app.listen(PORT, () => {
  secureLog('info', `Engagement Service running on port ${PORT}`);
});

export default app;


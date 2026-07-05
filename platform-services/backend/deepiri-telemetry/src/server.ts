import express, { Express, Request, Response, ErrorRequestHandler } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import { secureLog } from '@team-deepiri/shared-utils';
import routes from './index';
import { validateBodyIfPresent } from './middleware/inputValidation';

dotenv.config();

const app: Express = express();
const PORT: number = parseInt(process.env.PORT || '5004', 10);

app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '100kb' }));
app.use(validateBodyIfPresent());

app.get('/health', (_req: Request, res: Response) => {
  res.json({
    status: 'healthy',
    service: 'deepiri-telemetry',
    capabilities: [
      'time-series-analytics',
      'platform-signals',
      'behavioral-clustering',
      'predictive-modeling',
    ],
    timestamp: new Date().toISOString(),
  });
});

app.use('/api/telemetry', routes);
app.use('/', routes);

app.get('/capabilities', (_req: Request, res: Response) => {
  res.json({
    service: 'deepiri-telemetry',
    version: '2.0.0',
    capabilities: {
      analytics: {
        description: 'Time-series and behavioral analytics',
        endpoints: ['/*'],
      },
    },
  });
});

const errorHandler: ErrorRequestHandler = (err, _req, res, _next) => {
  secureLog('error', 'Telemetry service error:', err);
  res.status(500).json({ error: 'Internal server error' });
};
app.use(errorHandler);

import { startEventConsumption } from './streaming/eventConsumer';
startEventConsumption().catch((err) => {
  secureLog('error', 'Failed to start event consumption:', err);
});

app.listen(PORT, () => {
  secureLog('info', `Telemetry service running on port ${PORT}`);
});

export default app;

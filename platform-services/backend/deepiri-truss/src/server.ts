import express, { Express, Request, Response, ErrorRequestHandler } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import { secureLog } from '@team-deepiri/shared-utils';
import routes from './index';
import { connectDatabase } from './db';
import { validateBodyIfPresent } from './middleware/inputValidation';

dotenv.config();

const app: Express = express();
const PORT: number = parseInt(process.env.PORT || '5002', 10);

app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '100kb' }));
app.use(validateBodyIfPresent());

connectDatabase()
  .catch((err: Error) => {
    secureLog('error', 'Truss: Failed to connect to PostgreSQL', err);
    process.exit(1);
  });

import { initializeEventPublisher } from './streaming/eventPublisher';
initializeEventPublisher().catch((err) => {
  secureLog('error', 'Failed to initialize event publisher:', err);
});

app.get('/health', (req: Request, res: Response) => {
  res.json({
    status: 'healthy',
    service: 'deepiri-truss',
    capabilities: [
      'workflow-orchestration',
      'truss-definitions',
      'truss-runs',
      'job-step',
      'condition-step',
      'wait-event-step'
    ],
    timestamp: new Date().toISOString()
  });
});

app.use('/api/truss', routes);
app.use('/', routes);

app.get('/capabilities', (req: Request, res: Response) => {
  res.json({
    service: 'deepiri-truss',
    version: '2.0.0',
    capabilities: {
      workflow: {
        description: 'DB-backed Truss workflow orchestration',
        endpoints: [
          'GET /api/truss/definitions',
          'POST /api/truss/definitions',
          'POST /api/truss/definitions/:id/runs',
          'POST /api/truss/templates/ml.train-publish',
          'GET /api/truss/runs',
          'GET /api/truss/runs/:id',
          'GET /api/truss/runs/:id/steps',
          'POST /api/truss/runs/:id/cancel'
        ]
      }
    }
  });
});

const errorHandler: ErrorRequestHandler = (err, req, res, next) => {
  secureLog('error', 'Truss error:', err);
  res.status(500).json({ error: 'Internal server error' });
};
app.use(errorHandler);

app.listen(PORT, () => {
  secureLog('info', `Truss running on port ${PORT}`);
});

export default app;


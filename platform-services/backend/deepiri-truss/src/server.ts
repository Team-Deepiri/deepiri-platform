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
      'task-lifecycle',
      'task-versioning',
      'dependency-graphs',
      'workflow-definition',
      'fastapi-available'
    ],
    fastapi_endpoint: '/fastapi',
    timestamp: new Date().toISOString()
  });
});

app.use('/api/truss', routes);
app.use('/tasks', routes);
app.use('/', routes);

app.get('/fastapi', (req: Request, res: Response) => {
  res.json({
    service: 'deepiri-workflow-orchestrator',
    fastapi_available: true,
    docs: '/docs (when uvicorn running)',
    modules: [
      'task-lifecycle',
      'task-versioning',
      'dependency-graphs',
      'workflow-definition'
    ]
  });
});

app.get('/capabilities', (req: Request, res: Response) => {
  res.json({
    service: 'deepiri-workflow-orchestrator',
    version: '2.0.0',
    capabilities: {
      task: {
        description: 'Task lifecycle management',
        endpoints: ['/task/*']
      },
      versioning: {
        description: 'Task versioning history',
        endpoints: ['/task/*/version']
      },
      dependency: {
        description: 'DAG-based dependency tracking',
        endpoints: ['/task/*/graph']
      },
      workflow: {
        description: 'Multi-stage workflow orchestration',
        endpoints: ['/workflow/*']
      },
      fastapi: {
        description: 'Async FastAPI module available',
        endpoints: ['GET /fastapi']
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
  secureLog('info', `FastAPI module available at src/fastapi_app.py`);
});

export default app;


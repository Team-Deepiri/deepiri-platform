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
const PORT: number = parseInt(process.env.PORT || '5003', 10);

app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '100kb' }));
app.use(validateBodyIfPresent());

connectDatabase().catch((err: Error) => {
  secureLog('error', 'Registry: Failed to connect to PostgreSQL', err);
  process.exit(1);
});

app.get('/health', (_req: Request, res: Response) => {
  res.json({
    status: 'healthy',
    service: 'deepiri-registry',
    capabilities: ['service-catalog', 'health-polling', 'deepiri-yaml-discovery'],
    timestamp: new Date().toISOString(),
  });
});

app.use('/api/registry', routes);
app.use('/', routes);

const errorHandler: ErrorRequestHandler = (err, _req, res, _next) => {
  secureLog('error', 'Registry error:', err);
  res.status(500).json({ error: 'Internal server error' });
};
app.use(errorHandler);

app.listen(PORT, () => {
  secureLog('info', `Registry running on port ${PORT}`);
});

export default app;

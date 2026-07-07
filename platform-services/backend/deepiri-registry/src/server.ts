import express, { Express, Request, Response, ErrorRequestHandler } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import { secureLog } from '@team-deepiri/shared-utils';
import routes from './index';
import { connectDatabase } from './db';
import { validateBodyIfPresent } from './middleware/inputValidation';
import {
  handleAwardPoints,
  handleGetBalance,
  handleGetTrustScore,
  handleCheckRateLimits,
  handleCheckTrust
} from './core/incentiveEngineCore';

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
    secureLog('error', 'Incentive Engine: Failed to connect to PostgreSQL', err);
    process.exit(1);
  });

app.get('/health', (req: Request, res: Response) => {
  res.json({
    status: 'healthy',
    service: 'deepiri-registry',
    capabilities: [
      'multi-currency',
      'badges',
      'leaderboard',
      'momentum',
      'streaks',
      'boosts',
      'odysseys',
      'rewards',
      'tenant-policies',
      'anti-abuse',
      'fraud-controls',
      'trust-scoring',
      'incentive-ledger'
    ],
    timestamp: new Date().toISOString()
  });
});

app.use('/', routes);

// Tenant Incentive API
app.post('/incentive/award', handleAwardPoints);
app.get('/incentive/balance', handleGetBalance);
app.get('/incentive/trust', handleGetTrustScore);
app.get('/incentive/rate-limit', handleCheckRateLimits);
app.post('/incentive/trust/check', handleCheckTrust);

app.get('/capabilities', (req: Request, res: Response) => {
  res.json({
    service: 'deepiri-registry',
    version: '2.0.0',
    capabilities: {
      gamification: {
        description: 'Game mechanics (currency, badges, leaderboards)',
        endpoints: ['/multiCurrency/*', '/badge/*', '/eloLeaderboard/*']
      },
      incentive: {
        description: 'Tenant-scoped incentive policies',
        endpoints: ['/incentive/*']
      },
      antiAbuse: {
        description: 'Rate limiting and trust scoring',
        endpoints: ['/incentive/rate-limit', '/incentive/trust/check']
      }
    }
  });
});

const errorHandler: ErrorRequestHandler = (err, req, res, next) => {
  secureLog('error', 'Incentive Engine error:', err);
  res.status(500).json({ error: 'Internal server error' });
};
app.use(errorHandler);

app.listen(PORT, () => {
  secureLog('info', `Incentive Engine running on port ${PORT}`);
});

export default app;


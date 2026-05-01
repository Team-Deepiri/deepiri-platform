import express, { Express, Request, Response, ErrorRequestHandler } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import { secureLog } from '@team-deepiri/shared-utils';
import routes from './index';
import { validateBodyIfPresent } from './middleware/inputValidation';
import {
  handleCreateExperiment,
  handleAssignVariant,
  handleTrackMetric,
  handleDetectAnomalies,
  handleForecast,
  handleGetInsights,
  handleMeasureEffect
} from './core/decisionIntelligence';

dotenv.config();

const app: Express = express();
const PORT: number = parseInt(process.env.PORT || '5004', 10);

app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '100kb' }));
app.use(validateBodyIfPresent());

app.get('/health', (req: Request, res: Response) => {
  res.json({
    status: 'healthy',
    service: 'deepiri-decision-intelligence',
    capabilities: [
      'time-series-analytics',
      'behavioral-clustering',
      'predictive-modeling',
      'anomaly-detection',
      'forecasting',
      'experimentation',
      'effect-measurement',
      'insights'
    ],
    timestamp: new Date().toISOString()
  });
});

app.use('/', routes);

// Decision Intelligence API
app.post('/experiment', handleCreateExperiment);
app.post('/experiment/assign', handleAssignVariant);
app.post('/experiment/track', handleTrackMetric);
app.get('/anomaly', handleDetectAnomalies);
app.get('/forecast', handleForecast);
app.get('/insights', handleGetInsights);
app.post('/experiment/effect', handleMeasureEffect);

app.get('/capabilities', (req: Request, res: Response) => {
  res.json({
    service: 'deepiri-decision-intelligence',
    version: '2.0.0',
    capabilities: {
      analytics: {
        description: 'Time-series and behavioral analytics',
        endpoints: ['/*']
      },
      experimentation: {
        description: 'A/B testing and effect measurement',
        endpoints: ['POST /experiment/*', 'GET /experiment/effect']
      },
      anomalyDetection: {
        description: 'Anomaly early warning',
        endpoints: ['GET /anomaly']
      },
      forecasting: {
        description: 'Predictive forecasts',
        endpoints: ['GET /forecast']
      },
      insights: {
        description: 'AI-powered insights',
        endpoints: ['GET /insights']
      }
    }
  });
});

const errorHandler: ErrorRequestHandler = (err, req, res, next) => {
  secureLog('error', 'Decision Intelligence error:', err);
  res.status(500).json({ error: 'Internal server error' });
};
app.use(errorHandler);

import { startEventConsumption } from './streaming/eventConsumer';
startEventConsumption().catch((err) => {
  secureLog('error', 'Failed to start event consumption:', err);
});

app.listen(PORT, () => {
  secureLog('info', `Decision Intelligence running on port ${PORT}`);
});

export default app;


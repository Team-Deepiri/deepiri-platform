import express, { Express, Request, Response, ErrorRequestHandler } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import { secureLog } from '@team-deepiri/shared-utils';
import {
  handleGenerateMission,
  handleGenerateObjective,
  handleGeneratePrompt,
  handleBuildOnboarding,
  handleBuildLearning,
  handleNextBestAction,
  handleCheckPacing
} from './adaptiveEngine';

dotenv.config();

const app: Express = express();
const PORT: number = parseInt(process.env.PORT || '5007', 10);

app.use(helmet());
app.use(cors());
app.use(express.json());

app.get('/health', (req: Request, res: Response) => {
  res.json({
    status: 'healthy',
    service: 'deepiri-adaptive-experience-engine',
    capabilities: [
      'mission-generation',
      'objective-generation',
      'prompt-generation',
      'onboarding-paths',
      'learning-paths',
      'next-best-action',
      'pacing-policy',
      'constraint-validation'
    ],
    timestamp: new Date().toISOString()
  });
});

app.post('/generate/mission', handleGenerateMission);
app.post('/generate/objective', handleGenerateObjective);
app.post('/generate/prompt', handleGeneratePrompt);
app.post('/path/onboarding', handleBuildOnboarding);
app.post('/path/learning', handleBuildLearning);
app.post('/next-best-action', handleNextBestAction);
app.post('/pacing/check', handleCheckPacing);

app.get('/capabilities', (req: Request, res: Response) => {
  res.json({
    service: 'deepiri-adaptive-experience-engine',
    version: '2.0.0',
    capabilities: {
      mission: {
        description: 'Dynamic mission generation with context awareness',
        endpoints: ['POST /generate/mission'],
        adaptive: true
      },
      objective: {
        description: 'Personalized objective creation',
        endpoints: ['POST /generate/objective'],
        adaptive: true
      },
      prompt: {
        description: 'AI-powered prompt generation',
        endpoints: ['POST /generate/prompt'],
        adaptive: true
      },
      onboarding: {
        description: 'Personalized onboarding flow builder',
        endpoints: ['POST /path/onboarding']
      },
      learning: {
        description: 'Adaptive learning path generator',
        endpoints: ['POST /path/learning']
      },
      nba: {
        description: 'Next-best-action recommendation',
        endpoints: ['POST /next-best-action']
      },
      pacing: {
        description: 'Pacing policy enforcement',
        endpoints: ['POST /pacing/check']
      }
    }
  });
});

const errorHandler: ErrorRequestHandler = (err, req, res, next) => {
  secureLog('error', 'Adaptive Experience Engine error:', err);
  res.status(500).json({ error: 'Internal server error' });
};
app.use(errorHandler);

app.listen(PORT, () => {
  secureLog('info', `Adaptive Experience Engine running on port ${PORT}`);
});

export default app;
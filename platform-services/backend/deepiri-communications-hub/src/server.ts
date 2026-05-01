import express, { Express, Request, Response, ErrorRequestHandler } from 'express';
import { createServer } from 'http';
import { Server } from 'socket.io';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import { secureLog } from '@team-deepiri/shared-utils';
import { router, websocket } from './index';
import { validateBodyIfPresent } from './middleware/inputValidation';
import {
  handleSend,
  handleSendBatch,
  handleRegisterTemplate,
  handleGetPreferences,
  handleSetPreferences
} from './core/communicationsHub';

dotenv.config();

const app: Express = express();
const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: { origin: '*' }
});

const PORT: number = parseInt(process.env.PORT || '5005', 10);

app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '100kb' }));
app.use(validateBodyIfPresent());

websocket.initialize(io);

import { startEventConsumption } from './streaming/eventConsumer';
startEventConsumption(io).catch((err) => {
  secureLog('error', 'Failed to start event consumption:', err);
});

app.get('/health', (req: Request, res: Response) => {
  res.json({
    status: 'healthy',
    service: 'deepiri-communications-hub',
    capabilities: [
      'push',
      'email',
      'webhooks',
      'in-app',
      'templates',
      'preference-center',
      'quiet-hours',
      'channel-fallback',
      'delivery-observability',
      'retry-logic',
      'socket.io'
    ],
    channels: ['email', 'push', 'in-app', 'webhook', 'sms', 'slack', 'discord'],
    timestamp: new Date().toISOString()
  });
});

app.use('/', router);

// Communications API
app.post('/comm/send', handleSend);
app.post('/comm/send-batch', handleSendBatch);
app.post('/comm/template', handleRegisterTemplate);
app.get('/comm/preferences', handleGetPreferences);
app.post('/comm/preferences', handleSetPreferences);

app.get('/capabilities', (req: Request, res: Response) => {
  res.json({
    service: 'deepiri-communications-hub',
    version: '2.0.0',
    capabilities: {
      transactional: {
        description: 'One-to-one messaging',
        endpoints: ['POST /comm/send']
      },
      campaign: {
        description: 'Batch messaging',
        endpoints: ['POST /comm/send-batch']
      },
      templates: {
        description: 'Template management',
        endpoints: ['POST /comm/template']
      },
      preferences: {
        description: 'User preference center',
        endpoints: ['GET/POST /comm/preferences']
      }
    },
    channels: {
      email: { adapter: 'nodemailer', retry: true },
      push: { adapter: 'web-push', retry: true },
      inApp: { adapter: 'socket.io', retry: false },
      webhook: { adapter: 'axios', retry: true },
      slack: { adapter: 'webapi', retry: true },
      discord: { adapter: 'webapi', retry: true }
    }
  });
});

const errorHandler: ErrorRequestHandler = (err, req, res, next) => {
  secureLog('error', 'Communications Hub error:', err);
  res.status(500).json({ error: 'Internal server error' });
};
app.use(errorHandler);

httpServer.listen(PORT, () => {
  secureLog('info', `Communications Hub running on port ${PORT}`);
});

export { app, io };


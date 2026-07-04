import express, { Express, Request, Response } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { config } from './config/environment';
import { logger } from './utils/logger';
import routes from './routes';
import notificationRoutes from './routes/notificationRoutes';
import { validateBodyIfPresent } from './middleware/inputValidation';

export function createServer(): Express {
  const app = express();

  // Security middleware
  app.use(helmet());
  app.use(cors({
    origin: process.env.CORS_ORIGIN || '*',
    credentials: true,
  }));

  // Body parsing
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true, limit: '10mb' }));
  app.use(validateBodyIfPresent());

  // Health check
  app.get('/health', (req: Request, res: Response) => {
    res.json({
      status: 'healthy',
      service: 'messaging-service',
      capabilities: ['chat', 'agent-messaging', 'push', 'webhooks', 'templates', 'preferences'],
      timestamp: new Date().toISOString(),
    });
  });

  // API routes
  app.use('/api/v1', routes);
  // Legacy communications-hub paths (push, webhooks — no Socket.IO here; RTG owns realtime)
  app.use('/comm', notificationRoutes);
  app.use('/api/notifications', notificationRoutes);

  // Error handling middleware
  app.use((err: any, req: Request, res: Response, next: any) => {
    logger.error('Unhandled error', {
      error: err.message,
      stack: err.stack,
      path: req.path,
    });

    res.status(err.statusCode || 500).json({
      error: err.message || 'Internal server error',
      ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
    });
  });

  // 404 handler
  app.use((req: Request, res: Response) => {
    res.status(404).json({
      error: 'Not found',
      path: req.path,
    });
  });

  return app;
}


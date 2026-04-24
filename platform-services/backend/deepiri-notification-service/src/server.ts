import express, { Express, Request, Response, ErrorRequestHandler } from 'express';
import { createServer } from 'http';
import { Server } from 'socket.io';
// MongoDB removed - using PostgreSQL via Prisma if needed
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import { secureLog } from '@team-deepiri/shared-utils';
import { router, websocket } from './index';
import { validateBodyIfPresent } from './middleware/inputValidation';

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

// PostgreSQL connection via Prisma (if needed for notifications storage)
// For now, notifications are primarily real-time via WebSocket

websocket.initialize(io);

// Start event consumption
import { startEventConsumption } from './streaming/eventConsumer';
startEventConsumption(io).catch((err) => {
  secureLog('error', 'Failed to start event consumption:', err);
});

app.get('/health', (req: Request, res: Response) => {
  res.json({ status: 'healthy', service: 'notification-service', timestamp: new Date().toISOString() });
});

app.use('/', router);

const errorHandler: ErrorRequestHandler = (err, req, res, next) => {
  secureLog('error', 'Notification Service error:', err);
  res.status(500).json({ error: 'Internal server error' });
};
app.use(errorHandler);

httpServer.listen(PORT, () => {
  secureLog('info', `Notification Service running on port ${PORT}`);
});

export { app, io };


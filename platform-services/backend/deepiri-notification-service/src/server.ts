import express, { Express, Request, Response, ErrorRequestHandler } from 'express';
import { createServer } from 'http';
import { Server } from 'socket.io';
// MongoDB removed - using PostgreSQL via Prisma if needed
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import winston from 'winston';
import { router, websocket } from './index';

dotenv.config();

const app: Express = express();
const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: { origin: '*' }
});

const PORT: number = parseInt(process.env.PORT || '5005', 10);

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [new winston.transports.Console({ format: winston.format.simple() })]
});

app.use(helmet());
app.use(cors());
app.use(express.json());

// PostgreSQL connection via Prisma (if needed for notifications storage)
// For now, notifications are primarily real-time via WebSocket

websocket.initialize(io);

// Start event consumption
import { startEventConsumption } from './streaming/eventConsumer';
startEventConsumption(io).catch((err) => {
  logger.error('Failed to start event consumption:', err);
});

app.get('/health', (req: Request, res: Response) => {
  res.json({ status: 'healthy', service: 'notification-service', timestamp: new Date().toISOString() });
});

app.use('/', router);

const errorHandler: ErrorRequestHandler = (err, req, res, next) => {
  logger.error('Notification Service error:', err);
  res.status(500).json({ error: 'Internal server error' });
};
app.use(errorHandler);

httpServer.listen(PORT, () => {
  logger.info(`Notification Service running on port ${PORT}`);
});

export { app, io };


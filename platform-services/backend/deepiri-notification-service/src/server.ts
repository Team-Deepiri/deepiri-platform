import express, { Express, Request, Response, ErrorRequestHandler } from 'express';
import { createServer } from 'http';
import { Server } from 'socket.io';
import mongoose from 'mongoose';
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

const MONGO_URI: string = process.env.MONGO_URI || 'mongodb://mongodb:27017/deepiri';
mongoose.connect(MONGO_URI)
  .then(() => logger.info('Notification Service: Connected to MongoDB'))
  .catch((err: Error) => logger.error('Notification Service: MongoDB connection error', err));

websocket.initialize(io);

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


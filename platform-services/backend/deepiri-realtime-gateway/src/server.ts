import { createServer } from 'http';
import { Server } from 'socket.io';
import express, { Express, Request, Response } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import { secureLog } from '@deepiri/shared-utils';
import { validateBodyIfPresent } from './middleware/inputValidation';

dotenv.config();

const app: Express = express();
const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: { origin: '*' }
});

const PORT: number = parseInt(process.env.PORT || '5008', 10);

app.use(cors());
app.use(helmet());
app.use(express.json({ limit: '100kb' }));
app.use(validateBodyIfPresent());

// Start event consumption for streaming events
import { startEventConsumption } from './streaming/eventConsumer';
startEventConsumption(io).catch((err) => {
  secureLog('error', 'Failed to start event consumption:', err);
});

io.on('connection', (socket) => {
  secureLog('info', `WebSocket client connected: ${socket.id}`);

  socket.emit('connection_confirmed', {
    socketId: socket.id,
    timestamp: new Date().toISOString()
  });

  socket.on('join_user_room', (userId: string) => {
    socket.join(`user_${userId}`);
    secureLog('info', `User ${userId} joined room`);
  });

  socket.on('join_adventure_room', (adventureId: string) => {
    socket.join(`adventure_${adventureId}`);
    secureLog('info', `User joined adventure room: ${adventureId}`);
  });

  socket.on('disconnect', (reason: string) => {
    secureLog('info', `WebSocket client disconnected: ${socket.id}, reason: ${reason}`);
  });
});

app.get('/health', (req: Request, res: Response) => {
  res.json({
    status: 'healthy',
    service: 'realtime-gateway',
    connections: io.sockets.sockets.size,
    timestamp: new Date().toISOString()
  });
});

httpServer.listen(PORT, () => {
  secureLog('info', `Realtime Gateway running on port ${PORT}`);
});

export { app, io };


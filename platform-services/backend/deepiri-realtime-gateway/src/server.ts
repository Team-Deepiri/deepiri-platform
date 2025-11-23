import { createServer } from 'http';
import { Server } from 'socket.io';
import express, { Express, Request, Response } from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import winston from 'winston';

dotenv.config();

const app: Express = express();
const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: { origin: '*' }
});

const PORT: number = parseInt(process.env.PORT || '5008', 10);

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [new winston.transports.Console({ format: winston.format.simple() })]
});

app.use(cors());
app.use(express.json());

io.on('connection', (socket) => {
  logger.info(`WebSocket client connected: ${socket.id}`);
  
  socket.emit('connection_confirmed', {
    socketId: socket.id,
    timestamp: new Date().toISOString()
  });
  
  socket.on('join_user_room', (userId: string) => {
    socket.join(`user_${userId}`);
    logger.info(`User ${userId} joined room`);
  });
  
  socket.on('join_adventure_room', (adventureId: string) => {
    socket.join(`adventure_${adventureId}`);
    logger.info(`User joined adventure room: ${adventureId}`);
  });
  
  socket.on('disconnect', (reason: string) => {
    logger.info(`WebSocket client disconnected: ${socket.id}, reason: ${reason}`);
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
  logger.info(`Realtime Gateway running on port ${PORT}`);
});

export { app, io };


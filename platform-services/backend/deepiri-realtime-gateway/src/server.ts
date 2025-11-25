import { createServer } from 'http';
import { Server } from 'socket.io';
import express, { Express, Request, Response } from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import winston from 'winston';
import { setupGamificationEvents, GamificationEventEmitter } from './gamificationEvents';

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

// Setup gamification events
const gamificationEmitter = setupGamificationEvents(io);

// HTTP endpoint to emit gamification events (called by engagement service)
app.post('/emit/gamification', (req: Request, res: Response) => {
  const { userId, type, data } = req.body;
  
  if (!userId || !type) {
    return res.status(400).json({ error: 'userId and type are required' });
  }

  // Emit based on type
  switch (type) {
    case 'momentum_awarded':
      gamificationEmitter.emitMomentumAwarded(userId, data.amount, data.source, data.newTotal, data.currentLevel);
      break;
    case 'level_up':
      gamificationEmitter.emitLevelUp(userId, data.newLevel, data.totalMomentum);
      break;
    case 'streak_updated':
      gamificationEmitter.emitStreakUpdated(userId, data.streakType, data.currentStreak, data.longestStreak);
      break;
    case 'boost_activated':
      gamificationEmitter.emitBoostActivated(userId, data.boostType, data.duration, data.expiresAt);
      break;
    case 'objective_completed':
      gamificationEmitter.emitObjectiveCompleted(userId, data.objectiveId, data.title, data.momentumEarned);
      break;
    case 'milestone_completed':
      gamificationEmitter.emitMilestoneCompleted(userId, data.odysseyId, data.milestoneTitle, data.momentumEarned);
      break;
    case 'reward_earned':
      gamificationEmitter.emitRewardEarned(userId, data.rewardType, data.amount, data.description);
      break;
    default:
      return res.status(400).json({ error: 'Unknown event type' });
  }

  res.json({ success: true });
});

// Export emitter for use by other services
export { gamificationEmitter };

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
  logger.info(`Gamification events enabled`);
});

export { app, io };


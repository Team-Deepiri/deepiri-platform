import { createServer } from 'http';
import { Server } from 'socket.io';
import express, { Express, Request, Response } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import { secureLog } from '@team-deepiri/shared-utils';
import { setupGamificationEvents, GamificationEventEmitter } from './gamificationEvents';
import { validateBodyIfPresent } from './middleware/inputValidation';
import {
  handleEmitToChannel,
  handleGetRooms,
  handleGetPresence,
  handleGetMetrics,
  realtimeGateway
} from './core/realtimeGateway';

dotenv.config();

const app: Express = express();
const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: { origin: '*' }
});

// Attach io to app for core module access
app.set('io', io);

const PORT: number = parseInt(process.env.PORT || '5008', 10);

app.use(cors());
app.use(helmet());
app.use(express.json({ limit: '100kb' }));
app.use(validateBodyIfPresent());

const gamificationEmitter = setupGamificationEvents(io);

import { startEventConsumption } from './streaming/eventConsumer';
startEventConsumption(io).catch((err) => {
  secureLog('error', 'Failed to start event consumption:', err);
});

app.post('/emit/gamification', (req: Request, res: Response) => {
  const { userId, type, data } = req.body;
  
  if (!userId || !type) {
    return res.status(400).json({ error: 'userId and type are required' });
  }

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

export { gamificationEmitter };

io.on('connection', (socket) => {
  secureLog('info', `WebSocket client connected: ${socket.id}`);
  realtimeGateway.handleConnection(socket);
  
  socket.emit('connection_confirmed', {
    socketId: socket.id,
    timestamp: new Date().toISOString()
  });
  
  socket.on('join_user_room', (userId: string) => {
    realtimeGateway.joinRoom(socket, userId, 'user');
  });
  
  socket.on('join_user_room_legacy', (userId: string) => {
    socket.join(`user_${userId}`);
    secureLog('info', `User ${userId} joined room (legacy)`);
  });
  
  socket.on('join_party_room', (partyId: string) => {
    realtimeGateway.joinRoom(socket, partyId, 'party');
  });
  
  socket.on('join_org_room', (orgId: string) => {
    realtimeGateway.joinRoom(socket, orgId, 'org');
  });
  
  socket.on('join_global_room', () => {
    realtimeGateway.joinRoom(socket, 'global', 'global');
  });
  
  socket.on('join_adventure_room', (adventureId: string) => {
    socket.join(`adventure_${adventureId}`);
    secureLog('info', `User joined adventure room: ${adventureId}`);
  });
  
  socket.on('set_presence', (data: { userId: string; status: 'online' | 'away' | 'offline' }) => {
    realtimeGateway.broadcastPresence(socket, data.userId, data.status);
  });
  
  socket.on('disconnect', (reason: string) => {
    secureLog('info', `WebSocket client disconnected: ${socket.id}, reason: ${reason}`);
    realtimeGateway.handleDisconnect(socket);
  });
});

app.get('/health', (req: Request, res: Response) => {
  res.json({ 
    status: 'healthy', 
    service: 'deepiri-realtime-gateway',
    capabilities: [
      'socket.io',
      'multi-channel-rooms',
      'presence-tracking',
      'event-fanout',
      'idempotent-delivery',
      'rate-limiting',
      'durable-stream-replay',
      'backpressure-monitoring',
      'gateway-observability'
    ],
    connections: io.sockets.sockets.size,
    timestamp: new Date().toISOString() 
  });
});

// Realtime Gateway API
app.post('/emit/channel', handleEmitToChannel);
app.get('/rooms', handleGetRooms);
app.get('/presence', handleGetPresence);
app.get('/metrics', handleGetMetrics);

app.get('/capabilities', (req: Request, res: Response) => {
  res.json({
    service: 'deepiri-realtime-gateway',
    version: '2.0.0',
    capabilities: {
      websocket: {
        description: 'Socket.IO real-time communication',
        events: ['connection', 'join_user_room', 'join_party_room', 'join_org_room', 'join_global_room']
      },
      fanout: {
        description: 'Multi-channel event distribution',
        endpoints: ['POST /emit/channel', 'POST /emit/gamification']
      },
      presence: {
        description: 'Online status tracking',
        endpoints: ['GET /presence', 'socket.set_presence']
      },
      observability: {
        description: 'Gateway metrics',
        endpoints: ['GET /metrics']
      }
    }
  });
});

httpServer.listen(PORT, () => {
  secureLog('info', `Realtime Gateway running on port ${PORT}`);
  secureLog('info', `Gamification events enabled`);
  secureLog('info', `Multi-channel rooms enabled`);
  secureLog('info', `Presence tracking enabled`);
});

export { app, io };


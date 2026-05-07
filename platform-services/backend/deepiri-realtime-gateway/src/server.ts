import { createServer } from 'http';
import { Server } from 'socket.io';
import express, { Express, Request, Response } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import { secureLog } from '@team-deepiri/shared-utils';
import { setupGamificationEvents, GamificationEventEmitter } from './gamificationEvents';
import { validateBodyIfPresent } from './middleware/inputValidation';

dotenv.config();

const app: Express = express();
const httpServer = createServer(app);
const ALLOWED_SOCKET_TRANSPORTS = new Set(['polling', 'websocket']);
const ALLOWED_SOCKET_PARSERS = new Set(['default', 'msgpack']);

type NativeAddonStatus = {
  installed: boolean;
  active: boolean;
  reason: 'active' | 'disabled_by_env' | 'not_installed';
};

type SocketParserStatus = {
  requested: 'default' | 'msgpack';
  active: 'default' | 'msgpack';
  installed: boolean;
  reason: 'default' | 'active' | 'not_installed' | 'invalid' | 'load_failed';
  package?: string;
  error?: string;
};

function isAddonDisabledByEnv(envName: string): boolean {
  const raw = (process.env[envName] || '').trim().toLowerCase();
  return raw === '1' || raw === 'true' || raw === 'yes';
}

function parseBoolean(value: string | undefined, fallback: boolean): boolean {
  if (value === undefined) {
    return fallback;
  }

  const normalized = value.trim().toLowerCase();
  if (['1', 'true', 'yes', 'on'].includes(normalized)) {
    return true;
  }
  if (['0', 'false', 'no', 'off'].includes(normalized)) {
    return false;
  }

  return fallback;
}

function detectNativeAddon(moduleName: string, disableEnvName: string): NativeAddonStatus {
  const disabledByEnv = isAddonDisabledByEnv(disableEnvName);
  let installed = false;

  try {
    require.resolve(moduleName);
    installed = true;
  } catch {
    installed = false;
  }

  if (disabledByEnv) {
    return {
      installed,
      active: false,
      reason: 'disabled_by_env',
    };
  }

  if (!installed) {
    return {
      installed: false,
      active: false,
      reason: 'not_installed',
    };
  }

  return {
    installed: true,
    active: true,
    reason: 'active',
  };
}

const bufferutilStatus = detectNativeAddon('bufferutil', 'WS_NO_BUFFER_UTIL');
const utf8ValidateStatus = detectNativeAddon('utf-8-validate', 'WS_NO_UTF_8_VALIDATE');

function parseSocketTransports(raw: string | undefined): ('polling' | 'websocket')[] {
  if (!raw || !raw.trim()) {
    return ['polling', 'websocket'];
  }
  const parsed = raw
    .split(',')
    .map((value) => value.trim().toLowerCase())
    .filter((value): value is 'polling' | 'websocket' => ALLOWED_SOCKET_TRANSPORTS.has(value));
  return parsed.length ? [...new Set(parsed)] : ['polling', 'websocket'];
}

function parseSocketParser(raw: string | undefined): { requested: 'default' | 'msgpack'; invalid: boolean } {
  const normalized = (raw || 'default').trim().toLowerCase();
  if (ALLOWED_SOCKET_PARSERS.has(normalized)) {
    return { requested: normalized as 'default' | 'msgpack', invalid: false };
  }
  return { requested: 'default', invalid: true };
}

function resolveSocketParser(): { parser?: unknown; status: SocketParserStatus } {
  const parsed = parseSocketParser(process.env.SOCKET_IO_PARSER);
  if (parsed.invalid) {
    return {
      status: {
        requested: 'default',
        active: 'default',
        installed: false,
        reason: 'invalid',
      },
    };
  }

  if (parsed.requested === 'default') {
    return {
      status: {
        requested: 'default',
        active: 'default',
        installed: true,
        reason: 'default',
      },
    };
  }

  const packageName = 'socket.io-msgpack-parser';
  try {
    require.resolve(packageName);
  } catch {
    return {
      status: {
        requested: 'msgpack',
        active: 'default',
        installed: false,
        reason: 'not_installed',
        package: packageName,
      },
    };
  }

  try {
    const loadedParser = require(packageName);
    return {
      parser: loadedParser?.default || loadedParser,
      status: {
        requested: 'msgpack',
        active: 'msgpack',
        installed: true,
        reason: 'active',
        package: packageName,
      },
    };
  } catch (error) {
    return {
      status: {
        requested: 'msgpack',
        active: 'default',
        installed: true,
        reason: 'load_failed',
        package: packageName,
        error: error instanceof Error ? error.message : String(error),
      },
    };
  }
}

const socketTransports = parseSocketTransports(process.env.SOCKET_IO_TRANSPORTS);
const socketParser = resolveSocketParser();
const discardInitialRequest = parseBoolean(process.env.SOCKET_IO_DISCARD_INITIAL_REQUEST, false);
const socketServerOptions = {
  cors: { origin: '*' },
  transports: socketTransports,
  ...(socketParser.parser ? { parser: socketParser.parser } : {}),
};
const io = new Server(httpServer, socketServerOptions as any);

if (discardInitialRequest) {
  io.engine.on('connection', (rawSocket) => {
    (rawSocket as { request?: unknown }).request = undefined;
  });
}

const PORT: number = parseInt(process.env.PORT || '5008', 10);

app.use(cors());
app.use(helmet());
app.use(express.json({ limit: '100kb' }));
app.use(validateBodyIfPresent());

// Setup gamification events
const gamificationEmitter = setupGamificationEvents(io);

// Start event consumption for streaming events
import {
  getRuntimeBreakthroughSnapshot,
  getSocketHotPathProfileSnapshot,
  startEventConsumption,
} from './streaming/eventConsumer';
startEventConsumption(io).catch((err) => {
  secureLog('error', 'Failed to start event consumption:', err);
});

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
  const hotPathProfile = getSocketHotPathProfileSnapshot();
  res.json({ 
    status: 'healthy', 
    service: 'realtime-gateway',
    connections: io.sockets.sockets.size,
    timestamp: new Date().toISOString(),
    socket_io: {
      transports: socketTransports,
      native_addons: {
        bufferutil: bufferutilStatus,
        utf8_validate: utf8ValidateStatus,
      },
      parser: socketParser.status,
      discard_initial_request: discardInitialRequest,
    },
    streaming: {
      runtime_breakthroughs: getRuntimeBreakthroughSnapshot(),
      socket_hotpath_profile: {
        enabled: hotPathProfile.enabled,
        track_all_buckets: hotPathProfile.track_all_buckets,
        bucket_targets: hotPathProfile.bucket_targets,
        sample_limit: hotPathProfile.sample_limit,
        bucket_count: hotPathProfile.bucket_count,
        total_events_tracked: hotPathProfile.total_events_tracked,
      },
    },
  });
});

app.get('/v1/streaming/profile', (req: Request, res: Response) => {
  res.json(getSocketHotPathProfileSnapshot());
});

httpServer.listen(PORT, () => {
  secureLog('info', `Realtime Gateway running on port ${PORT}`);
  secureLog('info', `Gamification events enabled`);
  secureLog('info', `Socket.IO transports: ${socketTransports.join(',')}`);
  secureLog(
    'info',
    `Socket.IO parser: requested=${socketParser.status.requested}, active=${socketParser.status.active}, reason=${socketParser.status.reason}`
  );
  secureLog('info', `Socket.IO discard initial request: ${discardInitialRequest}`);
  secureLog(
    'info',
    `Socket.IO native addons: bufferutil(installed=${bufferutilStatus.installed},active=${bufferutilStatus.active},reason=${bufferutilStatus.reason}), utf-8-validate(installed=${utf8ValidateStatus.installed},active=${utf8ValidateStatus.active},reason=${utf8ValidateStatus.reason})`
  );
});

export { app, io };


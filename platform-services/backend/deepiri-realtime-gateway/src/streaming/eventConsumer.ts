/**
 * Event Consumer for Realtime Gateway
 * Subscribes to all event streams and forwards to WebSocket clients
 */
import { StreamingClient, StreamTopics, StreamEvent } from '@deepiri/shared-utils';
import winston from 'winston';
import { Server } from 'socket.io';

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [new winston.transports.Console({ format: winston.format.simple() })]
});

let streamingClient: StreamingClient | null = null;
let isConsuming = false;
let io: Server | null = null;

/**
 * Initialize and start consuming events
 */
export async function startEventConsumption(socketIO: Server): Promise<void> {
  if (isConsuming) {
    logger.warn('Event consumption already started');
    return;
  }

  io = socketIO;

  try {
    streamingClient = new StreamingClient(
      process.env.REDIS_HOST || 'redis',
      parseInt(process.env.REDIS_PORT || '6379'),
      process.env.REDIS_PASSWORD || 'redispassword'
    );

    await streamingClient.connect();
    logger.info('[Realtime Gateway] Connected to Redis Streams');

    // Start consuming all event streams
    consumeInferenceEvents().catch((err) => {
      logger.error('[Realtime Gateway] Inference events consumption error:', err);
    });

    consumePlatformEvents().catch((err) => {
      logger.error('[Realtime Gateway] Platform events consumption error:', err);
    });

    consumeModelEvents().catch((err) => {
      logger.error('[Realtime Gateway] Model events consumption error:', err);
    });

    consumeTrainingEvents().catch((err) => {
      logger.error('[Realtime Gateway] Training events consumption error:', err);
    });

    isConsuming = true;
    logger.info('[Realtime Gateway] Event consumption started');
  } catch (error) {
    logger.error('[Realtime Gateway] Failed to start event consumption:', error);
    throw error;
  }
}

/**
 * Consume inference events
 */
async function consumeInferenceEvents(): Promise<void> {
  if (!streamingClient || !io) {
    throw new Error('Streaming client or Socket.IO not initialized');
  }

  await streamingClient.subscribe(
    StreamTopics.INFERENCE_EVENTS,
    async (event: StreamEvent) => {
      try {
        // Broadcast to all clients or specific user room
        if (event.user_id) {
          io!.to(`user_${event.user_id}`).emit('inference-event', event);
        } else {
          io!.emit('inference-event', event);
        }
      } catch (error) {
        logger.error('[Realtime Gateway] Error forwarding inference event:', error);
      }
    },
    {
      consumerGroup: 'realtime-gateway',
      consumerName: 'realtime-1',
      blockMs: 1000
    }
  );
}

/**
 * Consume platform events
 */
async function consumePlatformEvents(): Promise<void> {
  if (!streamingClient || !io) {
    throw new Error('Streaming client or Socket.IO not initialized');
  }

  await streamingClient.subscribe(
    StreamTopics.PLATFORM_EVENTS,
    async (event: StreamEvent) => {
      try {
        // Broadcast to all clients or specific user room
        if (event.user_id) {
          io!.to(`user_${event.user_id}`).emit('platform-event', event);
        } else {
          io!.emit('platform-event', event);
        }
      } catch (error) {
        logger.error('[Realtime Gateway] Error forwarding platform event:', error);
      }
    },
    {
      consumerGroup: 'realtime-gateway',
      consumerName: 'realtime-1',
      blockMs: 1000
    }
  );
}

/**
 * Consume model events
 */
async function consumeModelEvents(): Promise<void> {
  if (!streamingClient || !io) {
    throw new Error('Streaming client or Socket.IO not initialized');
  }

  await streamingClient.subscribe(
    StreamTopics.MODEL_EVENTS,
    async (event: StreamEvent) => {
      try {
        // Broadcast model events to all clients
        io!.emit('model-event', event);
      } catch (error) {
        logger.error('[Realtime Gateway] Error forwarding model event:', error);
      }
    },
    {
      consumerGroup: 'realtime-gateway',
      consumerName: 'realtime-1',
      blockMs: 1000
    }
  );
}

/**
 * Consume training events
 */
async function consumeTrainingEvents(): Promise<void> {
  if (!streamingClient || !io) {
    throw new Error('Streaming client or Socket.IO not initialized');
  }

  await streamingClient.subscribe(
    StreamTopics.TRAINING_EVENTS,
    async (event: StreamEvent) => {
      try {
        // Broadcast training events to all clients
        io!.emit('training-event', event);
      } catch (error) {
        logger.error('[Realtime Gateway] Error forwarding training event:', error);
      }
    },
    {
      consumerGroup: 'realtime-gateway',
      consumerName: 'realtime-1',
      blockMs: 1000
    }
  );
}

/**
 * Stop event consumption
 */
export async function stopEventConsumption(): Promise<void> {
  if (streamingClient) {
    await streamingClient.disconnect();
    streamingClient = null;
    isConsuming = false;
    logger.info('[Realtime Gateway] Event consumption stopped');
  }
}


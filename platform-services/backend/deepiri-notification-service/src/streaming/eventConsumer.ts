/**
 * Event Consumer for Notification Service
 * Subscribes to platform-events and inference-events streams
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
  io = socketIO;
  if (isConsuming) {
    logger.warn('Event consumption already started');
    return;
  }

  try {
    streamingClient = new StreamingClient(
      process.env.REDIS_HOST || 'redis',
      parseInt(process.env.REDIS_PORT || '6379'),
      process.env.REDIS_PASSWORD || 'redispassword'
    );

    await streamingClient.connect();
    logger.info('[Notification] Connected to Redis Streams');

    // Start consuming platform events
    consumePlatformEvents().catch((err) => {
      logger.error('[Notification] Platform events consumption error:', err);
    });

    // Start consuming inference events (for error notifications)
    consumeInferenceEvents().catch((err) => {
      logger.error('[Notification] Inference events consumption error:', err);
    });

    isConsuming = true;
    logger.info('[Notification] Event consumption started');
  } catch (error) {
    logger.error('[Notification] Failed to start event consumption:', error);
    throw error;
  }
}

/**
 * Consume platform events
 */
async function consumePlatformEvents(): Promise<void> {
  if (!streamingClient) {
    throw new Error('Streaming client not initialized');
  }

  await streamingClient.subscribe(
    StreamTopics.PLATFORM_EVENTS,
    async (event: StreamEvent) => {
      try {
        logger.info(`[Notification] Received platform event: ${event.event}`, {
          service: event.service,
          user_id: event.user_id
        });

        // Send notification based on event type
        if (event.user_id && io) {
          const userId = event.user_id;
          
          switch (event.event) {
            case 'task-completed':
              io.to(`user_${userId}`).emit('notification', {
                type: 'task-completed',
                message: `Task completed successfully`,
                data: event.data,
                timestamp: event.timestamp
              });
              break;
            
            case 'task-failed':
              io.to(`user_${userId}`).emit('notification', {
                type: 'task-failed',
                message: `Task failed: ${event.data?.error || 'Unknown error'}`,
                data: event.data,
                timestamp: event.timestamp
              });
              break;
            
            case 'user-interaction':
              // Handle user interaction events
              break;
            
            default:
              // Generic notification
              io.to(`user_${userId}`).emit('notification', {
                type: event.event,
                message: `Event: ${event.event}`,
                data: event.data,
                timestamp: event.timestamp
              });
          }
        }

        logger.info('[Notification] Platform event processed');
      } catch (error) {
        logger.error('[Notification] Error processing platform event:', error);
      }
    },
    {
      consumerGroup: 'notification-service',
      consumerName: 'notification-1',
      blockMs: 1000
    }
  );
}

/**
 * Consume inference events (for error notifications)
 */
async function consumeInferenceEvents(): Promise<void> {
  if (!streamingClient) {
    throw new Error('Streaming client not initialized');
  }

  await streamingClient.subscribe(
    StreamTopics.INFERENCE_EVENTS,
    async (event: StreamEvent) => {
      try {
        // Only notify on failures
        if (event.success === false && event.user_id && io) {
          logger.info(`[Notification] Inference failed for user: ${event.user_id}`);
          
          io.to(`user_${event.user_id}`).emit('notification', {
            type: 'inference-failed',
            message: `AI inference failed for model: ${event.model_name}`,
            data: {
              model_name: event.model_name,
              error: event.error || 'Unknown error'
            },
            timestamp: event.timestamp
          });
        }
      } catch (error) {
        logger.error('[Notification] Error processing inference event:', error);
      }
    },
    {
      consumerGroup: 'notification-service',
      consumerName: 'notification-1',
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
    logger.info('[Notification] Event consumption stopped');
  }
}


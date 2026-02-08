/**
 * Event Publisher for Task Orchestrator Service
 * Publishes platform-events for task lifecycle
 */
import { StreamingClient, StreamTopics, StreamEvent } from '@deepiri/shared-utils';
import winston from 'winston';

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [new winston.transports.Console({ format: winston.format.simple() })]
});

let streamingClient: StreamingClient | null = null;

/**
 * Initialize streaming client
 */
export async function initializeEventPublisher(): Promise<void> {
  try {
    streamingClient = new StreamingClient(
      process.env.REDIS_HOST || 'redis',
      parseInt(process.env.REDIS_PORT || '6379'),
      process.env.REDIS_PASSWORD || 'redispassword'
    );

    await streamingClient.connect();
    logger.info('[Task Orchestrator] Connected to Redis Streams');
  } catch (error) {
    logger.error('[Task Orchestrator] Failed to initialize event publisher:', error);
    throw error;
  }
}

/**
 * Publish task created event
 */
export async function publishTaskCreated(
  taskId: string,
  userId: string,
  taskData: any
): Promise<void> {
  if (!streamingClient) {
    await initializeEventPublisher();
  }

  const event: StreamEvent = {
    event: 'task-created',
    timestamp: new Date().toISOString(),
    source: 'task-orchestrator',
    service: 'task-orchestrator',
    user_id: userId,
    action: 'task-created',
    data: {
      task_id: taskId,
      ...taskData
    }
  };

  try {
    await streamingClient!.publish(StreamTopics.PLATFORM_EVENTS, event);
    logger.info(`[Task Orchestrator] Published task-created event: ${taskId}`);
  } catch (error) {
    logger.error('[Task Orchestrator] Failed to publish task-created event:', error);
  }
}

/**
 * Publish task started event
 */
export async function publishTaskStarted(
  taskId: string,
  userId: string
): Promise<void> {
  if (!streamingClient) {
    await initializeEventPublisher();
  }

  const event: StreamEvent = {
    event: 'task-started',
    timestamp: new Date().toISOString(),
    source: 'task-orchestrator',
    service: 'task-orchestrator',
    user_id: userId,
    action: 'task-started',
    data: {
      task_id: taskId
    }
  };

  try {
    await streamingClient!.publish(StreamTopics.PLATFORM_EVENTS, event);
    logger.info(`[Task Orchestrator] Published task-started event: ${taskId}`);
  } catch (error) {
    logger.error('[Task Orchestrator] Failed to publish task-started event:', error);
  }
}

/**
 * Publish task completed event
 */
export async function publishTaskCompleted(
  taskId: string,
  userId: string,
  result?: any
): Promise<void> {
  if (!streamingClient) {
    await initializeEventPublisher();
  }

  const event: StreamEvent = {
    event: 'task-completed',
    timestamp: new Date().toISOString(),
    source: 'task-orchestrator',
    service: 'task-orchestrator',
    user_id: userId,
    action: 'task-completed',
    data: {
      task_id: taskId,
      result
    }
  };

  try {
    await streamingClient!.publish(StreamTopics.PLATFORM_EVENTS, event);
    logger.info(`[Task Orchestrator] Published task-completed event: ${taskId}`);
  } catch (error) {
    logger.error('[Task Orchestrator] Failed to publish task-completed event:', error);
  }
}

/**
 * Publish task failed event
 */
export async function publishTaskFailed(
  taskId: string,
  userId: string,
  error: string
): Promise<void> {
  if (!streamingClient) {
    await initializeEventPublisher();
  }

  const event: StreamEvent = {
    event: 'task-failed',
    timestamp: new Date().toISOString(),
    source: 'task-orchestrator',
    service: 'task-orchestrator',
    user_id: userId,
    action: 'task-failed',
    data: {
      task_id: taskId,
      error
    }
  };

  try {
    await streamingClient!.publish(StreamTopics.PLATFORM_EVENTS, event);
    logger.info(`[Task Orchestrator] Published task-failed event: ${taskId}`);
  } catch (error) {
    logger.error('[Task Orchestrator] Failed to publish task-failed event:', error);
  }
}


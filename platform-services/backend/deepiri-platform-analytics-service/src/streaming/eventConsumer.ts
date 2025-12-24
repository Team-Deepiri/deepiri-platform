/**
 * Event Consumer for Platform Analytics Service
 * Subscribes to inference-events and training-events streams
 */
import { StreamingClient, StreamTopics, StreamEvent } from '@deepiri/shared-utils';
import winston from 'winston';

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [new winston.transports.Console({ format: winston.format.simple() })]
});

let streamingClient: StreamingClient | null = null;
let isConsuming = false;

/**
 * Initialize and start consuming events
 */
export async function startEventConsumption(): Promise<void> {
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
    logger.info('[Analytics] Connected to Redis Streams');

    // Start consuming inference events
    consumeInferenceEvents().catch((err) => {
      logger.error('[Analytics] Inference events consumption error:', err);
    });

    // Start consuming training events
    consumeTrainingEvents().catch((err) => {
      logger.error('[Analytics] Training events consumption error:', err);
    });

    isConsuming = true;
    logger.info('[Analytics] Event consumption started');
  } catch (error) {
    logger.error('[Analytics] Failed to start event consumption:', error);
    throw error;
  }
}

/**
 * Consume inference events from Cyrex
 */
async function consumeInferenceEvents(): Promise<void> {
  if (!streamingClient) {
    throw new Error('Streaming client not initialized');
  }

  await streamingClient.subscribe(
    StreamTopics.INFERENCE_EVENTS,
    async (event: StreamEvent) => {
      try {
        logger.info(`[Analytics] Received inference event: ${event.event}`, {
          model_name: event.model_name,
          latency_ms: event.latency_ms,
          user_id: event.user_id
        });

        // TODO: Store in InfluxDB
        // await influxDB.writePoint({
        //   measurement: 'inference_metrics',
        //   tags: {
        //     model_name: event.model_name,
        //     version: event.version,
        //     user_id: event.user_id || 'anonymous'
        //   },
        //   fields: {
        //     latency_ms: event.latency_ms,
        //     tokens_used: event.tokens_used || 0,
        //     confidence: event.confidence || 0
        //   },
        //   timestamp: new Date(event.timestamp)
        // });

        logger.info('[Analytics] Inference event processed');
      } catch (error) {
        logger.error('[Analytics] Error processing inference event:', error);
      }
    },
    {
      consumerGroup: 'analytics-service',
      consumerName: 'analytics-1',
      blockMs: 1000
    }
  );
}

/**
 * Consume training events from Helox
 */
async function consumeTrainingEvents(): Promise<void> {
  if (!streamingClient) {
    throw new Error('Streaming client not initialized');
  }

  await streamingClient.subscribe(
    StreamTopics.TRAINING_EVENTS,
    async (event: StreamEvent) => {
      try {
        logger.info(`[Analytics] Received training event: ${event.event}`, {
          experiment_id: event.experiment_id,
          model_name: event.model_name,
          status: event.status
        });

        // TODO: Store in InfluxDB
        // await influxDB.writePoint({
        //   measurement: 'training_metrics',
        //   tags: {
        //     experiment_id: event.experiment_id,
        //     model_name: event.model_name,
        //     status: event.status
        //   },
        //   fields: {
        //     progress: event.progress || 0,
        //     ...event.metrics
        //   },
        //   timestamp: new Date(event.timestamp)
        // });

        logger.info('[Analytics] Training event processed');
      } catch (error) {
        logger.error('[Analytics] Error processing training event:', error);
      }
    },
    {
      consumerGroup: 'analytics-service',
      consumerName: 'analytics-1',
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
    logger.info('[Analytics] Event consumption stopped');
  }
}


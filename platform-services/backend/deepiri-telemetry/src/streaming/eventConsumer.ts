/**
 * Event Consumer for Platform Analytics Service
 * Subscribes to inference-events and training-events streams
 */
import { StreamingClient, StreamTopics, StreamEvent } from '@team-deepiri/shared-utils';
import { secureLog } from '@team-deepiri/shared-utils';
import { recordEvent } from '../services/synapseEventIndexService';

let streamingClient: StreamingClient | null = null;
let isConsuming = false;

/**
 * Initialize and start consuming events
 */
export async function startEventConsumption(): Promise<void> {
  if (isConsuming) {
    secureLog('warn', 'Event consumption already started');
    return;
  }

  try {
    streamingClient = new StreamingClient(
      process.env.REDIS_HOST || 'redis',
      parseInt(process.env.REDIS_PORT || '6379'),
      process.env.REDIS_PASSWORD || 'redispassword'
    );

    await streamingClient.connect();
    secureLog('info', '[Analytics] Connected to Redis Streams');

    // Start consuming inference events
    consumeInferenceEvents().catch((err) => {
      secureLog('error', '[Analytics] Inference events consumption error:', err);
    });

    // Start consuming training events
    consumeTrainingEvents().catch((err) => {
      secureLog('error', '[Analytics] Training events consumption error:', err);
    });

    // Start consuming ecosystem-wide platform events (registry/truss/jobs/
    // notification/etc.) so GET /events/recent reflects the whole platform,
    // not just AI-specific traffic.
    consumePlatformEvents().catch((err) => {
      secureLog('error', '[Analytics] Platform events consumption error:', err);
    });

    isConsuming = true;
    secureLog('info', '[Analytics] Event consumption started');
  } catch (error) {
    secureLog('error', '[Analytics] Failed to start event consumption:', error);
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
        secureLog('info', `[Analytics] Received inference event: ${event.event}`, {
          model_name: event.model_name,
          latency_ms: event.latency_ms,
          user_id: event.user_id
        });

        recordEvent(String(event.event || 'inference-event'), 'inference-events', event);

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

        secureLog('info', '[Analytics] Inference event processed');
      } catch (error) {
        secureLog('error', '[Analytics] Error processing inference event:', error);
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
        secureLog('info', `[Analytics] Received training event: ${event.event}`, {
          experiment_id: event.experiment_id,
          model_name: event.model_name,
          status: event.status
        });

        recordEvent(String(event.event || 'training-event'), 'training-events', event);

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

        secureLog('info', '[Analytics] Training event processed');
      } catch (error) {
        secureLog('error', '[Analytics] Error processing training event:', error);
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
 * Consume ecosystem-wide platform events (registry.*, truss.*, jobs.*,
 * notification.*, etc.) so the recent-events feed reflects the whole
 * platform, not just AI-specific traffic.
 */
async function consumePlatformEvents(): Promise<void> {
  if (!streamingClient) {
    throw new Error('Streaming client not initialized');
  }

  await streamingClient.subscribe(
    StreamTopics.PLATFORM_EVENTS,
    async (event: StreamEvent) => {
      try {
        const eventType = String(event.event_type || event.event || 'platform-event');
        recordEvent(eventType, String(event.source || 'platform-events'), event);
      } catch (error) {
        secureLog('error', '[Analytics] Error processing platform event:', error);
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
    secureLog('info', '[Analytics] Event consumption stopped');
  }
}


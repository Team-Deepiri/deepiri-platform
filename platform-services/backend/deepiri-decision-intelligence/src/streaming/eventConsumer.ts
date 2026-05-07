/**
 * Event Consumer for Decision Intelligence
 * Subscribes to inference-events and training-events streams
 */
import { StreamingClient, StreamTopics, StreamEvent } from '@team-deepiri/shared-utils';
import { secureLog } from '@team-deepiri/shared-utils';
import timeSeriesAnalytics from '../timeSeriesAnalytics';

let streamingClient: StreamingClient | null = null;
let isConsuming = false;
const CONSUMER_NAME = process.env.REDIS_CONSUMER_NAME || `decision-intelligence-${process.pid}`;

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
    secureLog('info', '[DecisionIntelligence] Connected to Redis Streams');

    // Start consuming inference events
    consumeInferenceEvents().catch((err) => {
      secureLog('error', '[DecisionIntelligence] Inference events consumption error:', err);
    });

    // Start consuming training events
    consumeTrainingEvents().catch((err) => {
      secureLog('error', '[DecisionIntelligence] Training events consumption error:', err);
    });

    isConsuming = true;
    secureLog('info', '[DecisionIntelligence] Event consumption started');
  } catch (error) {
    secureLog('error', '[DecisionIntelligence] Failed to start event consumption:', error);
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
        secureLog('info', `[DecisionIntelligence] Received inference event: ${event.event}`, {
          model_name: event.model_name,
          latency_ms: event.latency_ms,
          user_id: event.user_id
        });

        await timeSeriesAnalytics.recordInferenceMetrics({
          model_name:  event.model_name,
          version:     event.version,
          user_id:     event.user_id,
          latency_ms:  event.latency_ms,
          tokens_used: event.tokens_used,
          confidence:  event.confidence,
        });

        secureLog('info', '[DecisionIntelligence] Inference event processed');
      } catch (error) {
        secureLog('error', '[DecisionIntelligence] Error processing inference event:', error);
      }
    },
    {
      consumerGroup: 'decision-intelligence',
      consumerName: CONSUMER_NAME,
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
        secureLog('info', `[DecisionIntelligence] Received training event: ${event.event}`, {
          experiment_id: event.experiment_id,
          model_name: event.model_name,
          status: event.status
        });

        await timeSeriesAnalytics.recordTrainingMetrics({
          experiment_id: event.experiment_id,
          model_name:    event.model_name,
          status:        event.status,
          progress:      event.progress,
          metrics:       event.metrics,
        });

        secureLog('info', '[DecisionIntelligence] Training event processed');
      } catch (error) {
        secureLog('error', '[DecisionIntelligence] Error processing training event:', error);
      }
    },
    {
      consumerGroup: 'decision-intelligence',
      consumerName: CONSUMER_NAME,
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
    secureLog('info', '[DecisionIntelligence] Event consumption stopped');
  }
}


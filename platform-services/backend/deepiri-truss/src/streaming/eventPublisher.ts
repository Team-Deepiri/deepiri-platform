import { StreamingClient, StreamTopics, StreamEvent } from '@team-deepiri/shared-utils';
import { secureLog } from '@team-deepiri/shared-utils';

let streamingClient: StreamingClient | null = null;

type TrussEventPayload = Record<string, unknown>;

export async function initializeEventPublisher(): Promise<void> {
  if (streamingClient) {
    return;
  }

  try {
    streamingClient = new StreamingClient(
      process.env.REDIS_HOST || 'redis',
      parseInt(process.env.REDIS_PORT || '6379', 10),
      process.env.REDIS_PASSWORD || 'redispassword'
    );

    await streamingClient.connect();
    secureLog('info', '[Truss] Connected to Redis Streams');
  } catch (error) {
    secureLog('error', '[Truss] Failed to initialize event publisher:', error);
    throw error;
  }
}

async function publishTrussEvent(eventType: string, data: TrussEventPayload): Promise<void> {
  try {
    if (!streamingClient) {
      await initializeEventPublisher();
    }

    const event: StreamEvent = {
      event: eventType,
      event_type: eventType,
      timestamp: new Date().toISOString(),
      source: 'deepiri-truss',
      service: 'deepiri-truss',
      action: eventType,
      data,
    };

    await streamingClient!.publish(StreamTopics.PLATFORM_EVENTS, event);
    secureLog('info', `[Truss] Published ${eventType}`, data);
  } catch (error) {
    // State changes are already committed in Postgres; event publishing should
    // not roll back or break the workflow engine.
    secureLog('error', `[Truss] Failed to publish ${eventType}:`, error);
  }
}

export async function publishTrussRunEvent(
  status: string,
  runId: string,
  data: TrussEventPayload = {}
): Promise<void> {
  await publishTrussEvent(`truss.run.${status}`, {
    runId,
    ...data,
  });
}

export async function publishTrussStepEvent(
  status: string,
  runId: string,
  stepId: string,
  data: TrussEventPayload = {}
): Promise<void> {
  await publishTrussEvent(`truss.step.${status}`, {
    runId,
    stepId,
    ...data,
  });
}

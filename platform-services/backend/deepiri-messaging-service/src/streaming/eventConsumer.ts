import { StreamingClient, StreamEvent, StreamTopics } from '@team-deepiri/shared-utils';
import { secureLog } from '@team-deepiri/shared-utils';
import { createNotification } from '../services/notificationService';

let streamingClient: StreamingClient | null = null;
let isConsuming = false;

async function publishNotificationEvent(
  userId: string,
  eventType: string,
  message: string,
  data: Record<string, unknown> = {},
): Promise<void> {
  // Persist first so GET /api/notifications reflects this even if the live
  // stream publish below fails or nothing is connected to receive it.
  try {
    await createNotification(userId, eventType, message, message, data);
  } catch (err: unknown) {
    secureLog('error', '[Messaging] failed to persist notification row', err);
  }

  if (!streamingClient) return;
  await streamingClient.publish(StreamTopics.PLATFORM_EVENTS, {
    event_type: eventType,
    event: eventType,
    user_id: userId,
    timestamp: new Date().toISOString(),
    source: 'messaging-service',
    data: { message, ...data },
  });
}

export async function startEventConsumption(): Promise<void> {
  if (isConsuming) return;

  streamingClient = new StreamingClient(
    process.env.REDIS_HOST || 'redis',
    parseInt(process.env.REDIS_PORT || '6379', 10),
    process.env.REDIS_PASSWORD || 'redispassword',
  );

  await streamingClient.connect();

  await streamingClient.subscribe(
    StreamTopics.PLATFORM_EVENTS,
    async (event: StreamEvent) => {
      if (!event.user_id) return;
      const userId = String(event.user_id);
      const name = String(event.event || '');

      switch (name) {
        case 'task-completed':
          await publishNotificationEvent(userId, 'notification.task-completed', 'Task completed successfully', {
            data: event.data as Record<string, unknown>,
          });
          break;
        case 'task-failed':
          await publishNotificationEvent(userId, 'notification.task-failed', 'Task failed', {
            data: event.data as Record<string, unknown>,
          });
          break;
        default:
          break;
      }
    },
    {
      consumerGroup: 'messaging-service',
      consumerName: 'messaging-notifications-1',
      blockMs: 1000,
    },
  );

  await streamingClient.subscribe(
    StreamTopics.INFERENCE_EVENTS,
    async (event: StreamEvent) => {
      if (event.success !== false || !event.user_id) return;
      await publishNotificationEvent(
        String(event.user_id),
        'notification.inference-failed',
        `AI inference failed for model: ${event.model_name ?? 'unknown'}`,
        {
          model_name: event.model_name,
          error: event.error || 'Unknown error',
        },
      );
    },
    {
      consumerGroup: 'messaging-service',
      consumerName: 'messaging-notifications-1',
      blockMs: 1000,
    },
  );

  isConsuming = true;
  secureLog('info', '[Messaging] notification event consumption started');
}

export async function stopEventConsumption(): Promise<void> {
  if (streamingClient) {
    await streamingClient.disconnect();
    streamingClient = null;
    isConsuming = false;
  }
}

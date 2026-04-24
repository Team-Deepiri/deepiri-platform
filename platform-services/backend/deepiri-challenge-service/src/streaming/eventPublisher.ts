/**
 * Event Publisher for Challenge Service.
 *
 * Publishes challenge-generated events so other services (analytics, engagement)
 * can react. userId is optional — callers that don't provide it still get the
 * event published with user_id: 'anonymous' for analytics purposes.
 */
import { StreamingClient, StreamTopics, StreamEvent, secureLog } from '@team-deepiri/shared-utils';

let streamingClient: StreamingClient | null = null;

export async function initializeEventPublisher(): Promise<void> {
  try {
    streamingClient = new StreamingClient(
      process.env.REDIS_HOST || 'redis',
      parseInt(process.env.REDIS_PORT || '6379'),
      process.env.REDIS_PASSWORD || 'redispassword'
    );
    await streamingClient.connect();
    secureLog('info', '[Challenge] Connected to Redis Streams');
  } catch (error) {
    secureLog('error', '[Challenge] Failed to initialize event publisher:', error);
    throw error;
  }
}

async function ensureClient(): Promise<void> {
  if (!streamingClient) {
    await initializeEventPublisher();
  }
}

export async function publishChallengeGenerated(
  userId: string | undefined,
  challengeData: any
): Promise<void> {
  try {
    await ensureClient();
    const event: StreamEvent = {
      event:     'challenge-generated',
      timestamp: new Date().toISOString(),
      source:    'challenge-service',
      service:   'challenge-service',
      user_id:   userId || 'anonymous',
      action:    'challenge-generated',
      data:      { challenge: challengeData },
    };
    await streamingClient!.publish(StreamTopics.PLATFORM_EVENTS, event);
    secureLog('info', `[Challenge] Published challenge-generated event for user: ${userId || 'anonymous'}`);
  } catch (error) {
    secureLog('error', '[Challenge] Failed to publish challenge-generated event:', error);
  }
}

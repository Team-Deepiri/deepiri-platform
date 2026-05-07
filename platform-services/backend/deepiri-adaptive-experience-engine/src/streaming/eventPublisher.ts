/**
 * Event publisher for Adaptive Experience Engine.
 *
 * Publishes generated experience events onto platform-events so analytics and
 * incentive consumers can react without coupling to the HTTP request path.
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
    secureLog('info', '[AdaptiveExperience] Connected to Redis Streams');
  } catch (error) {
    secureLog('error', '[AdaptiveExperience] Failed to initialize event publisher:', error);
    throw error;
  }
}

async function ensureClient(): Promise<void> {
  if (!streamingClient) {
    await initializeEventPublisher();
  }
}

export async function publishAdaptiveExperienceGenerated(
  userId: string | undefined,
  experienceType: string,
  experienceData: any
): Promise<void> {
  try {
    await ensureClient();
    const event: StreamEvent = {
      event: 'challenge-generated',
      timestamp: new Date().toISOString(),
      source: 'adaptive-experience-engine',
      service: 'deepiri-adaptive-experience-engine',
      user_id: userId || 'anonymous',
      action: 'challenge-generated',
      data: {
        experience_type: experienceType,
        challenge: experienceData,
      },
    };
    await streamingClient!.publish(StreamTopics.PLATFORM_EVENTS, event);
    secureLog('info', `[AdaptiveExperience] Published ${experienceType} event for user: ${userId || 'anonymous'}`);
  } catch (error) {
    secureLog('error', '[AdaptiveExperience] Failed to publish generated experience event:', error);
  }
}

/**
 * Event Consumer for Engagement Service.
 *
 * Listens to platform-events and automatically awards momentum / updates
 * streaks when users complete tasks or register. This is what makes the
 * gamification system react to platform activity in real time instead of
 * requiring manual API calls.
 *
 * Event → action mapping:
 *   task-completed   → +10 momentum (tasks), daily streak, project streak
 *   task-created     → +2 momentum (tasks) — rewards planning behaviour
 *   user-registered  → +5 momentum (attendance) — welcome bonus
 */
import { StreamingClient, StreamTopics, StreamEvent, secureLog } from '@team-deepiri/shared-utils';
import momentumService from '../services/momentumService';
import streakService from '../services/streakService';

let streamingClient: StreamingClient | null = null;
let isConsuming = false;
const CONSUMER_NAME = process.env.REDIS_CONSUMER_NAME || `engagement-${process.pid}`;

export async function startEventConsumption(): Promise<void> {
  if (isConsuming) {
    secureLog('warn', '[Engagement] Event consumption already started');
    return;
  }

  try {
    streamingClient = new StreamingClient(
      process.env.REDIS_HOST || 'redis',
      parseInt(process.env.REDIS_PORT || '6379'),
      process.env.REDIS_PASSWORD || 'redispassword'
    );

    await streamingClient.connect();
    secureLog('info', '[Engagement] Connected to Redis Streams');

    consumePlatformEvents().catch((err) => {
      secureLog('error', '[Engagement] Platform events consumption error:', err);
    });

    isConsuming = true;
    secureLog('info', '[Engagement] Event consumption started');
  } catch (error) {
    secureLog('error', '[Engagement] Failed to start event consumption:', error);
    throw error;
  }
}

async function consumePlatformEvents(): Promise<void> {
  if (!streamingClient) {
    throw new Error('Streaming client not initialized');
  }

  await streamingClient.subscribe(
    StreamTopics.PLATFORM_EVENTS,
    async (event: StreamEvent) => {
      // All gamification actions require a userId
      if (!event.user_id) return;
      const userId = event.user_id;

      try {
        switch (event.event) {
          case 'task-completed':
            await momentumService.awardMomentum(userId, 10, 'tasks', {
              task_id: event.data?.task_id,
              source_event: 'task-completed',
            });
            await streakService.updateDailyStreak(userId);
            await streakService.updateProjectStreak(userId, event.data?.task_id || 'default');
            secureLog('info', `[Engagement] Awarded 10 momentum to ${userId} for task-completed`);
            break;

          case 'task-created':
            await momentumService.awardMomentum(userId, 2, 'tasks', {
              task_id: event.data?.task_id,
              source_event: 'task-created',
            });
            secureLog('info', `[Engagement] Awarded 2 momentum to ${userId} for task-created`);
            break;

          case 'user-registered':
            await momentumService.awardMomentum(userId, 5, 'attendance', {
              source_event: 'user-registered',
            });
            secureLog('info', `[Engagement] Awarded 5 welcome momentum to ${userId}`);
            break;
        }
      } catch (err) {
        // Log but never rethrow — a single-user error must not kill the consumer loop
        secureLog('error', `[Engagement] Error processing ${event.event} for user ${userId}:`, err);
      }
    },
    {
      consumerGroup: 'engagement-service',
      consumerName:  CONSUMER_NAME,
      blockMs:       1000,
    }
  );
}

export async function stopEventConsumption(): Promise<void> {
  if (streamingClient) {
    await streamingClient.disconnect();
    streamingClient = null;
    isConsuming = false;
    secureLog('info', '[Engagement] Event consumption stopped');
  }
}

import Redis, { RedisOptions } from 'ioredis';

/**
 * Creates and returns a configured ioredis client.
 * Reads REDIS_URL from the environment (injected via K8s Secret/ConfigMap).
 *
 * @param overrides - Optional ioredis config overrides.
 * @returns A connected ioredis instance.
 */
export function createRedisClient(overrides: Partial<RedisOptions> = {}): Redis {
  const host = process.env.REDIS_HOST || 'localhost';
  const port = process.env.REDIS_PORT || '6379';
  const password = process.env.REDIS_PASSWORD || '';
  const defaultUrl = password
    ? `redis://:${password}@${host}:${port}`
    : `redis://${host}:${port}`;
  const client = new Redis(process.env.REDIS_URL ?? defaultUrl, {
    retryStrategy(times: number): number | null {
      if (times > 10) {
        console.error('[Redis] Max reconnection attempts reached. Giving up.');
        return null; // Stop retrying — let the K8s liveness probe restart the pod
      }
      const delay = Math.min(times * 150, 3000);
      console.warn(`[Redis] Reconnecting... attempt ${times}, delay ${delay}ms`);
      return delay;
    },
    enableOfflineQueue: true,
    connectTimeout: 10_000,
    maxRetriesPerRequest: 3,
    ...overrides,
  } as RedisOptions);

  client.on('connect', (): void => console.info('[Redis] Connected.'));
  client.on('error', (err: Error): void =>
    console.error('[Redis] Client error:', err.message)
  );

  return client;
}
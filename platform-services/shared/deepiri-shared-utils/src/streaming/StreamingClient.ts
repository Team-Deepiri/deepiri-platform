/**
 * Streaming Client for Platform Services
 * Wraps Redis Streams for event publishing and consumption
 */
import Redis from 'ioredis';

export interface StreamEvent {
  event: string;
  timestamp: string;
  source: string;
  correlation_id?: string;
  [key: string]: any;
}

export class StreamingClient {
  private redis: Redis;
  private connected: boolean = false;

  constructor(
    redisHost: string = process.env.REDIS_HOST || 'redis',
    redisPort: number = parseInt(process.env.REDIS_PORT || '6379'),
    redisPassword: string = process.env.REDIS_PASSWORD || 'redispassword'
  ) {
    this.redis = new Redis({
      host: redisHost,
      port: redisPort,
      password: redisPassword,
      retryStrategy: (times) => {
        const delay = Math.min(times * 50, 2000);
        return delay;
      },
      maxRetriesPerRequest: 3,
    });

    this.redis.on('connect', () => {
      this.connected = true;
      console.log('[StreamingClient] Connected to Redis');
    });

    this.redis.on('error', (err) => {
      console.error('[StreamingClient] Redis error:', err);
      this.connected = false;
    });
  }

  async connect(): Promise<void> {
    if (this.connected) return;
    
    try {
      await this.redis.ping();
      this.connected = true;
    } catch (error) {
      console.error('[StreamingClient] Failed to connect:', error);
      throw error;
    }
  }

  async disconnect(): Promise<void> {
    await this.redis.quit();
    this.connected = false;
  }

  /**
   * Publish event to stream
   */
  async publish(
    streamName: string,
    event: StreamEvent,
    maxLength: number = 10000
  ): Promise<string> {
    if (!this.connected) {
      await this.connect();
    }

    try {
      // Ensure stream exists and set max length
      const messageId = await this.redis.xadd(
        streamName,
        'MAXLEN',
        '~',
        maxLength.toString(),
        '*',
        ...this.flattenEvent(event)
      );

      return messageId as string;
    } catch (error) {
      console.error(`[StreamingClient] Failed to publish to ${streamName}:`, error);
      throw error;
    }
  }

  /**
   * Subscribe to stream with callback
   */
  async subscribe(
    streamName: string,
    callback: (event: StreamEvent) => Promise<void> | void,
    options: {
      consumerGroup?: string;
      consumerName?: string;
      lastId?: string;
      blockMs?: number;
    } = {}
  ): Promise<void> {
    if (!this.connected) {
      await this.connect();
    }

    const {
      consumerGroup,
      consumerName,
      lastId = '0',
      blockMs = 1000,
    } = options;

    // Create consumer group if provided
    if (consumerGroup && consumerName) {
      try {
        await this.redis.xgroup('CREATE', streamName, consumerGroup, '0', 'MKSTREAM');
      } catch (error: any) {
        // Group already exists is fine
        if (!error.message?.includes('BUSYGROUP')) {
          console.warn(`[StreamingClient] Failed to create consumer group:`, error);
        }
      }
    }

    // Start consuming
    while (true) {
      try {
        let messages: any[];

        if (consumerGroup && consumerName) {
          // Read from consumer group
          messages = await this.redis.xreadgroup(
            'GROUP',
            consumerGroup,
            consumerName,
            'COUNT',
            '10',
            'BLOCK',
            blockMs.toString(),
            'STREAMS',
            streamName,
            '>'
          );
        } else {
          // Direct read
          const readResult = await this.redis.xread(
            'COUNT',
            '10',
            'BLOCK',
            blockMs.toString(),
            'STREAMS',
            streamName,
            lastId
          );
          messages = readResult || [];
        }

        if (messages && messages.length > 0) {
          const streamData = messages[0];
          if (streamData && streamData[1]) {
            const streamMessages = streamData[1] as any[];

            for (const [msgId, data] of streamMessages) {
              try {
                const event = this.unflattenEvent(data);
                await callback(event);

                // Acknowledge if using consumer group
                if (consumerGroup && consumerName) {
                  await this.redis.xack(streamName, consumerGroup, msgId);
                }
              } catch (error) {
                console.error(`[StreamingClient] Callback error:`, error);
              }
            }
          }
        }
      } catch (error) {
        console.error(`[StreamingClient] Subscription error:`, error);
        await new Promise((resolve) => setTimeout(resolve, 1000));
      }
    }
  }

  /**
   * Flatten event object for Redis
   */
  private flattenEvent(event: StreamEvent): string[] {
    const flat: string[] = [];
    for (const [key, value] of Object.entries(event)) {
      flat.push(key);
      flat.push(typeof value === 'object' ? JSON.stringify(value) : String(value));
    }
    return flat;
  }

  /**
   * Unflatten Redis data to event object
   */
  private unflattenEvent(data: any[]): StreamEvent {
    const event: any = {};
    for (let i = 0; i < data.length; i += 2) {
      const key = data[i];
      let value = data[i + 1];
      
      // Try to parse JSON
      try {
        value = JSON.parse(value);
      } catch {
        // Not JSON, keep as string
      }
      
      event[key] = value;
    }
    return event as StreamEvent;
  }
}

/**
 * Stream topic constants
 */
export const StreamTopics = {
  MODEL_EVENTS: 'model-events',
  INFERENCE_EVENTS: 'inference-events',
  PLATFORM_EVENTS: 'platform-events',
  AGI_DECISIONS: 'agi-decisions',
  TRAINING_EVENTS: 'training-events',
} as const;


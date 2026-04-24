import { StreamingClient, StreamTopics } from '@team-deepiri/shared-utils';
import { config } from '../config/environment';
import { logger } from '../utils/logger';

let streamingClient: StreamingClient | null = null;

class EventPublisher {
  private async ensureClient(): Promise<StreamingClient> {
    if (!streamingClient) {
      streamingClient = new StreamingClient(
        config.redis.host,
        config.redis.port,
        config.redis.password
      );
      await streamingClient.connect();
    }
    return streamingClient;
  }

  /**
   * Publish message created event
   */
  async publishMessageCreated(message: any): Promise<void> {
    try {
      logger.info('Message created event', {
        messageId: message.id,
        chatRoomId: message.chatRoomId,
        senderType: message.senderType,
      });

      const client = await this.ensureClient();
      await client.publish(StreamTopics.PLATFORM_EVENTS, {
        event: 'message:new',
        timestamp: new Date().toISOString(),
        source: 'messaging-service',
        data: {
          id: message.id,
          chatRoomId: message.chatRoomId,
          senderId: message.senderId,
          senderType: message.senderType,
          content: message.content,
          createdAt: message.createdAt,
        },
      });
    } catch (error: any) {
      logger.error('Failed to publish message created event', {
        error: error.message,
      });
    }
  }

  /**
   * Publish chat room created event
   */
  async publishChatRoomCreated(chatRoomId: string, type: string): Promise<void> {
    try {
      logger.info('Chat room created event', {
        chatRoomId,
        type,
      });

      const client = await this.ensureClient();
      await client.publish(StreamTopics.PLATFORM_EVENTS, {
        event: 'chat-room:created',
        timestamp: new Date().toISOString(),
        source: 'messaging-service',
        data: {
          chatRoomId,
          type,
        },
      });
    } catch (error: any) {
      logger.error('Failed to publish chat room created event', {
        error: error.message,
      });
    }
  }
}

export const eventPublisher = new EventPublisher();

import { logger } from '../utils/logger';
import { config } from '../config/environment';
import { StreamingClient, StreamTopics } from '@deepiri/shared-utils';

let streamingClient: StreamingClient | null = null;

export async function initializeEventPublisher(): Promise<void> {  
  streamingClient = new StreamingClient(
    config.redis.host,
    config.redis.port,    
    config.redis.password
  );  
  await streamingClient.connect();
}

// For now, use simple event publishing
// In production, integrate with Redis Streams or message queue
class EventPublisher {
  /**
   * Publish message created event
   */
  async publishMessageCreated(message: any): Promise<void> {
    try {
      if (!streamingClient) await initializeEventPublisher();

      await streamingClient!.publish(StreamTopics.PLATFORM_EVENTS, {
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


      logger.info('Message created event', {
        messageId: message.id,
        chatRoomId: message.chatRoomId,
        senderType: message.senderType,
      });

      // TODO: Integrate with Redis Streams or message queue
      // For now, just log the event
      // In production, this would publish to Redis Streams for Realtime Gateway
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
      if (!streamingClient) await initializeEventPublisher();

      await streamingClient!.publish(StreamTopics.PLATFORM_EVENTS, {
        event: 'chatroom:new',
        timestamp: new Date().toISOString(),
        source: 'messaging-service',    
        data: {
          chatRoomId,
          type
        },
      });

      logger.info('Chat room created event', {
        chatRoomId,
        type,
      });

    } catch (error: any) {
      logger.error('Failed to publish chat room created event', {
        error: error.message,
      });
    }
  }
}

export const eventPublisher = new EventPublisher();


import { prisma } from '../db';
import { cyrexAgentClient } from './cyrexAgentClient';
import { chatService } from './chatService';
import { eventPublisher } from '../streaming/eventPublisher';
import { logger } from '../utils/logger';
import { MessageNotFoundError, ChatRoomNotFoundError } from '../utils/errors';
import type { Message, Prisma } from '@prisma/client';

export interface CreateMessageInput {
  chatRoomId: string;
  senderId: string;
  senderType: 'USER' | 'AGENT' | 'SYSTEM';
  content: string;
  messageType?: 'TEXT' | 'IMAGE' | 'FILE' | 'SYSTEM' | 'TOOL_CALL' | 'TOOL_RESULT';
  agentInstanceId?: string;
  parentMessageId?: string;
  metadata?: any;
}

export class MessageService {
  /**
   * Create message in database
   */
  async createMessage(input: CreateMessageInput): Promise<Message> {
    try {
      // Verify chat room exists
      await chatService.getChatRoom(input.chatRoomId);

      const message = await prisma.message.create({
        data: {
          chatRoomId: input.chatRoomId,
          senderId: input.senderId,
          senderType: input.senderType,
          agentInstanceId: input.agentInstanceId,
          content: input.content,
          messageType: input.messageType || 'TEXT',
          parentMessageId: input.parentMessageId,
          metadata: input.metadata || {},
        },
      });

      logger.info('Message created', {
        messageId: message.id,
        chatRoomId: input.chatRoomId,
        senderType: input.senderType,
      });

      // Publish event for real-time updates
      await eventPublisher.publishMessageCreated(message);

      return message;
    } catch (error: any) {
      logger.error('Failed to create message', {
        input,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Forward message to cyrex agent
   * This is where cyrex integration happens for messaging
   */
  async forwardToAgent(
    agentInstanceId: string,
    userMessage: string,
    chatRoomId: string,
    senderId: string
  ): Promise<Message> {
    try {
      logger.info('Forwarding message to agent', {
        agentInstanceId,
        chatRoomId,
      });

      // Call cyrex agent (pass chatRoomId so cyrex can send response back)
      const response = await cyrexAgentClient.sendMessage(agentInstanceId, userMessage, chatRoomId);

      // Extract response content
      const agentResponse = response.data?.message || response.message || 'No response from agent';

      // Save agent response to database
      const message = await this.createMessage({
        chatRoomId,
        senderId: '', // Agent doesn't have user ID
        senderType: 'AGENT',
        content: agentResponse,
        agentInstanceId,
        metadata: {
          toolCalls: response.data?.toolCalls,
          tokens: response.data?.tokens,
        },
      });

      return message;
    } catch (error: any) {
      logger.error('Failed to forward message to agent', {
        agentInstanceId,
        chatRoomId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Forward streaming message to agent
   * Returns stream that can be forwarded via WebSocket
   */
  async forwardToAgentStream(
    agentInstanceId: string,
    userMessage: string,
    chatRoomId: string,
    senderId: string
  ): Promise<{ stream: NodeJS.ReadableStream; messageId: string }> {
    try {
      logger.info('Forwarding streaming message to agent', {
        agentInstanceId,
        chatRoomId,
      });

      // Create placeholder message for streaming
      const message = await this.createMessage({
        chatRoomId,
        senderId: '',
        senderType: 'AGENT',
        content: '', // Will be updated as stream progresses
        agentInstanceId,
        metadata: { streaming: true },
      });

      // Get stream from cyrex (pass chatRoomId so cyrex can send response back)
      const stream = await cyrexAgentClient.sendMessageStream(agentInstanceId, userMessage, chatRoomId);
      
      if (!stream) {
        throw new Error('No stream received from cyrex');
      }

      return { stream, messageId: message.id };
    } catch (error: any) {
      logger.error('Failed to stream message to agent', {
        agentInstanceId,
        chatRoomId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get messages for chat room
   */
  async getMessages(
    chatRoomId: string,
    options?: {
      limit?: number;
      offset?: number;
      before?: Date;
      after?: Date;
    }
  ): Promise<{ messages: Message[]; total: number }> {
    try {
      await chatService.getChatRoom(chatRoomId); // Verify exists

      const where: Prisma.MessageWhereInput = {
        chatRoomId,
        isDeleted: false,
      };

      if (options?.before || options?.after) {
        where.createdAt = {};
        if (options?.before) {
          where.createdAt.lt = options.before;
        }
        if (options?.after) {
          where.createdAt.gt = options.after;
        }
      }

      const [messages, total] = await Promise.all([
        prisma.message.findMany({
          where,
          include: {
            readReceipts: true,
            replies: {
              where: { isDeleted: false },
              take: 5,
            },
          },
          orderBy: { createdAt: 'desc' },
          take: options?.limit || 50,
          skip: options?.offset || 0,
        }),
        prisma.message.count({ where }),
      ]);

      return { messages: messages.reverse(), total }; // Reverse to get chronological order
    } catch (error: any) {
      logger.error('Failed to get messages', {
        chatRoomId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get message by ID
   */
  async getMessage(messageId: string): Promise<Message> {
    try {
      const message = await prisma.message.findUnique({
        where: { id: messageId },
        include: {
          readReceipts: true,
          replies: {
            where: { isDeleted: false },
          },
        },
      });

      if (!message) {
        throw new MessageNotFoundError(messageId);
      }

      return message;
    } catch (error: any) {
      if (error instanceof MessageNotFoundError) {
        throw error;
      }
      logger.error('Failed to get message', {
        messageId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Update message
   */
  async updateMessage(
    messageId: string,
    content: string
  ): Promise<Message> {
    try {
      const message = await prisma.message.update({
        where: { id: messageId },
        data: {
          content,
          isEdited: true,
          editedAt: new Date(),
        },
      });

      logger.info('Message updated', { messageId });
      return message;
    } catch (error: any) {
      logger.error('Failed to update message', {
        messageId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Delete message (soft delete)
   */
  async deleteMessage(messageId: string): Promise<void> {
    try {
      await prisma.message.update({
        where: { id: messageId },
        data: {
          isDeleted: true,
          content: '[Message deleted]',
        },
      });

      logger.info('Message deleted', { messageId });
    } catch (error: any) {
      logger.error('Failed to delete message', {
        messageId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Mark message as read
   */
  async markAsRead(messageId: string, userId: string): Promise<void> {
    try {
      await prisma.messageReadReceipt.upsert({
        where: {
          messageId_userId: {
            messageId,
            userId,
          },
        },
        create: {
          messageId,
          userId,
        },
        update: {
          readAt: new Date(),
        },
      });

      logger.debug('Message marked as read', { messageId, userId });
    } catch (error: any) {
      logger.error('Failed to mark message as read', {
        messageId,
        userId,
        error: error.message,
      });
      throw error;
    }
  }
}

export const messageService = new MessageService();


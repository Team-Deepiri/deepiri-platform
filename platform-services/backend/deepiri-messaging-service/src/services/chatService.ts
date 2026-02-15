import { prisma } from '../db';
import { logger } from '../utils/logger';
import { ChatRoomNotFoundError, ValidationError } from '../utils/errors';
import type { ChatRoom, ChatParticipant, Prisma } from '@prisma/client';

export interface CreateChatRoomInput {
  name?: string;
  type: 'AGENT' | 'GROUP' | 'DIRECT';
  agentInstanceId?: string;
  userIds?: string[];
  agentIds?: string[];
  createdBy?: string;
  metadata?: any;
}

export interface UpdateChatRoomInput {
  name?: string;
  metadata?: any;
  isArchived?: boolean;
}

export class ChatService {
  /**
   * Create chat room
   */
  async createChatRoom(input: CreateChatRoomInput): Promise<ChatRoom> {
    try {
      // Validate input
      if (input.type === 'AGENT' && !input.agentInstanceId) {
        throw new ValidationError('agentInstanceId is required for AGENT chat rooms');
      }

      if (input.type === 'DIRECT' && (!input.userIds || input.userIds.length !== 2)) {
        throw new ValidationError('DIRECT chat rooms require exactly 2 users');
      }

      // Create chat room
      const chatRoom = await prisma.chatRoom.create({
        data: {
          name: input.name,
          type: input.type,
          agentInstanceId: input.agentInstanceId,
          createdBy: input.createdBy,
          metadata: input.metadata || {},
        },
      });

      // Add participants
      const participants: Prisma.ChatParticipantCreateManyInput[] = [];

      // Add creator as participant
      if (input.createdBy) {
        participants.push({
          chatRoomId: chatRoom.id,
          userId: input.createdBy,
          role: 'admin',
        });
      }

      // Add user participants
      if (input.userIds) {
        for (const userId of input.userIds) {
          if (userId !== input.createdBy) {
            participants.push({
              chatRoomId: chatRoom.id,
              userId,
              role: 'member',
            });
          }
        }
      }

      // Add agent participants
      if (input.agentIds) {
        for (const agentId of input.agentIds) {
          participants.push({
            chatRoomId: chatRoom.id,
            agentInstanceId: agentId,
            role: 'member',
          });
        }
      }

      if (participants.length > 0) {
        await prisma.chatParticipant.createMany({
          data: participants,
        });
      }

      logger.info('Chat room created', {
        chatRoomId: chatRoom.id,
        type: chatRoom.type,
      });

      return await this.getChatRoom(chatRoom.id);
    } catch (error: any) {
      logger.error('Failed to create chat room', {
        input,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get chat room by ID
   */
  async getChatRoom(chatRoomId: string): Promise<ChatRoom> {
    try {
      const chatRoom = await prisma.chatRoom.findUnique({
        where: { id: chatRoomId },
        include: {
          participants: {
            where: { isActive: true },
          },
        },
      });

      if (!chatRoom) {
        throw new ChatRoomNotFoundError(chatRoomId);
      }

      return chatRoom;
    } catch (error: any) {
      if (error instanceof ChatRoomNotFoundError) {
        throw error;
      }
      logger.error('Failed to get chat room', {
        chatRoomId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get chat rooms for a user
   */
  async getChatRoomsForUser(
    userId: string,
    filters?: {
      type?: 'AGENT' | 'GROUP' | 'DIRECT';
      isArchived?: boolean;
      skip?: number;
      take?: number;
    }
  ): Promise<{ chatRooms: ChatRoom[]; total: number }> {
    try {
      const where: Prisma.ChatRoomWhereInput = {
        participants: {
          some: {
            userId,
            isActive: true,
          },
        },
        isArchived: filters?.isArchived || false,
      };

      if (filters?.type) {
        where.type = filters.type;
      }

      const [chatRooms, total] = await Promise.all([
        prisma.chatRoom.findMany({
          where,
          include: {
            participants: {
              where: { isActive: true },
              take: 10, // Limit participants for list view
            },
            messages: {
              orderBy: { createdAt: 'desc' },
              take: 1, // Get last message
            },
          },
          orderBy: { updatedAt: 'desc' },
          skip: filters?.skip || 0,
          take: filters?.take || 50,
        }),
        prisma.chatRoom.count({ where }),
      ]);

      return { chatRooms, total };
    } catch (error: any) {
      logger.error('Failed to get chat rooms for user', {
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Update chat room
   */
  async updateChatRoom(
    chatRoomId: string,
    input: UpdateChatRoomInput
  ): Promise<ChatRoom> {
    try {
      await this.getChatRoom(chatRoomId); // Verify exists

      const updated = await prisma.chatRoom.update({
        where: { id: chatRoomId },
        data: {
          name: input.name,
          metadata: input.metadata,
          isArchived: input.isArchived,
        },
      });

      logger.info('Chat room updated', { chatRoomId });
      return await this.getChatRoom(chatRoomId);
    } catch (error: any) {
      logger.error('Failed to update chat room', {
        chatRoomId,
        input,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Add participant to chat room
   */
  async addParticipant(
    chatRoomId: string,
    userId?: string,
    agentInstanceId?: string,
    role: string = 'member'
  ): Promise<ChatParticipant> {
    try {
      await this.getChatRoom(chatRoomId); // Verify exists

      const participant = await prisma.chatParticipant.create({
        data: {
          chatRoomId,
          userId,
          agentInstanceId,
          role,
        },
      });

      logger.info('Participant added to chat room', {
        chatRoomId,
        userId,
        agentInstanceId,
      });

      return participant;
    } catch (error: any) {
      logger.error('Failed to add participant', {
        chatRoomId,
        userId,
        agentInstanceId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Remove participant from chat room
   */
  async removeParticipant(
    chatRoomId: string,
    userId?: string,
    agentInstanceId?: string
  ): Promise<void> {
    try {
      await prisma.chatParticipant.updateMany({
        where: {
          chatRoomId,
          userId: userId || undefined,
          agentInstanceId: agentInstanceId || undefined,
        },
        data: {
          isActive: false,
        },
      });

      logger.info('Participant removed from chat room', {
        chatRoomId,
        userId,
        agentInstanceId,
      });
    } catch (error: any) {
      logger.error('Failed to remove participant', {
        chatRoomId,
        userId,
        agentInstanceId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Archive chat room
   */
  async archiveChatRoom(chatRoomId: string): Promise<ChatRoom> {
    return await this.updateChatRoom(chatRoomId, { isArchived: true });
  }
}

export const chatService = new ChatService();


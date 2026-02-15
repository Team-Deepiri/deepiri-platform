import { Router, Request, Response } from 'express';
import { body, param, query, validationResult } from 'express-validator';
import { messageService } from '../services/messageService';
import { chatService } from '../services/chatService';
import { authenticate } from './middleware/auth';
import { handleValidationErrors } from './middleware/validation';

const router = Router();

/**
 * POST /api/v1/chats/:chatRoomId/messages
 * Send message to chat room
 * If agent chat, forwards to cyrex
 */
router.post(
  '/:chatRoomId/messages',
  authenticate,
  [
    param('chatRoomId').isUUID(),
    body('content').notEmpty().trim(),
    body('messageType').optional().isIn(['TEXT', 'IMAGE', 'FILE', 'SYSTEM', 'TOOL_CALL', 'TOOL_RESULT']),
    body('parentMessageId').optional().isUUID(),
    body('metadata').optional(),
  ],
  handleValidationErrors,
  async (req: Request, res: Response) => {
    try {
      const { chatRoomId } = req.params;
      const { content, messageType, parentMessageId, metadata } = req.body;

      // Create message in database
      const message = await messageService.createMessage({
        chatRoomId,
        senderId: req.user!.id,
        senderType: 'USER',
        content,
        messageType: messageType || 'TEXT',
        parentMessageId,
        metadata,
      });

      // If agent chat, forward to cyrex
      const chatRoom = await chatService.getChatRoom(chatRoomId);
      if (chatRoom.type === 'AGENT' && chatRoom.agentInstanceId) {
        // Forward to cyrex agent (async, don't wait)
        messageService.forwardToAgent(
          chatRoom.agentInstanceId,
          content,
          chatRoomId,
          req.user!.id
        ).catch((error) => {
          console.error('Failed to forward to agent', error);
        });
      }

      res.status(201).json({ success: true, data: message });
    } catch (error: any) {
      res.status(500).json({ 
        error: 'Failed to send message', 
        message: error.message 
      });
    }
  }
);

/**
 * GET /api/v1/chats/:chatRoomId/messages
 * Get messages for chat room
 */
router.get(
  '/:chatRoomId/messages',
  authenticate,
  [
    param('chatRoomId').isUUID(),
    query('limit').optional().isInt({ min: 1, max: 100 }),
    query('offset').optional().isInt({ min: 0 }),
    query('before').optional().isISO8601(),
    query('after').optional().isISO8601(),
  ],
  handleValidationErrors,
  async (req: Request, res: Response) => {
    try {
      const { chatRoomId } = req.params;
      const { limit, offset, before, after } = req.query;

      const { messages, total } = await messageService.getMessages(
        chatRoomId,
        {
          limit: limit ? parseInt(limit as string) : undefined,
          offset: offset ? parseInt(offset as string) : undefined,
          before: before ? new Date(before as string) : undefined,
          after: after ? new Date(after as string) : undefined,
        }
      );

      res.json({ 
        success: true, 
        data: messages,
        total,
      });
    } catch (error: any) {
      res.status(500).json({ 
        error: 'Failed to fetch messages', 
        message: error.message 
      });
    }
  }
);

/**
 * GET /api/v1/messages/:id
 * Get message by ID
 */
router.get(
  '/messages/:id',
  authenticate,
  [param('id').isUUID()],
  handleValidationErrors,
  async (req: Request, res: Response) => {
    try {
      const message = await messageService.getMessage(req.params.id);
      res.json({ success: true, data: message });
    } catch (error: any) {
      const statusCode = error.statusCode || 500;
      res.status(statusCode).json({ 
        error: 'Failed to fetch message', 
        message: error.message 
      });
    }
  }
);

/**
 * PUT /api/v1/messages/:id
 * Update message
 */
router.put(
  '/messages/:id',
  authenticate,
  [
    param('id').isUUID(),
    body('content').notEmpty().trim(),
  ],
  handleValidationErrors,
  async (req: Request, res: Response) => {
    try {
      const message = await messageService.updateMessage(
        req.params.id,
        req.body.content
      );

      res.json({ success: true, data: message });
    } catch (error: any) {
      res.status(500).json({ 
        error: 'Failed to update message', 
        message: error.message 
      });
    }
  }
);

/**
 * DELETE /api/v1/messages/:id
 * Delete message (soft delete)
 */
router.delete(
  '/messages/:id',
  authenticate,
  [param('id').isUUID()],
  handleValidationErrors,
  async (req: Request, res: Response) => {
    try {
      await messageService.deleteMessage(req.params.id);
      res.json({ success: true });
    } catch (error: any) {
      res.status(500).json({ 
        error: 'Failed to delete message', 
        message: error.message 
      });
    }
  }
);

/**
 * POST /api/v1/messages/:id/read
 * Mark message as read
 */
router.post(
  '/messages/:id/read',
  authenticate,
  [param('id').isUUID()],
  handleValidationErrors,
  async (req: Request, res: Response) => {
    try {
      await messageService.markAsRead(req.params.id, req.user!.id);
      res.json({ success: true });
    } catch (error: any) {
      res.status(500).json({ 
        error: 'Failed to mark message as read', 
        message: error.message 
      });
    }
  }
);

export default router;


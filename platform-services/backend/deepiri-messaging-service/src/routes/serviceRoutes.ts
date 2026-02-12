import { Router, Request, Response } from 'express';
import { body, param, validationResult } from 'express-validator';
import { messageService } from '../services/messageService';
import { chatService } from '../services/chatService';
import { config } from '../config/environment';
import { handleValidationErrors } from './middleware/validation';

const router = Router();

/**
 * Service-to-service authentication middleware
 * Validates API key for service-to-service calls
 */
function authenticateService(req: Request, res: Response, next: Function): void {
  const apiKey = req.headers['x-api-key'] as string;
  const expectedKey = config.cyrex.apiKey;

  if (!apiKey || apiKey !== expectedKey) {
    res.status(401).json({ 
      error: 'Unauthorized',
      message: 'Invalid or missing API key for service-to-service call'
    });
    return;
  }

  next();
}

/**
 * POST /api/v1/service/chats/:chatRoomId/messages
 * Service-to-service endpoint for cyrex to send agent messages
 * Bypasses user authentication, uses API key instead
 */
router.post(
  '/chats/:chatRoomId/messages',
  authenticateService,
  [
    param('chatRoomId').isUUID(),
    body('content').notEmpty().trim(),
    body('messageType').optional().isIn(['TEXT', 'IMAGE', 'FILE', 'SYSTEM', 'TOOL_CALL', 'TOOL_RESULT']),
    body('agentInstanceId').optional().isString(),
    body('metadata').optional(),
  ],
  handleValidationErrors,
  async (req: Request, res: Response) => {
    try {
      const { chatRoomId } = req.params;
      const { content, messageType, agentInstanceId, metadata } = req.body;

      // Verify chat room exists
      const chatRoom = await chatService.getChatRoom(chatRoomId);

      // Create agent message (senderId is empty for agent messages)
      const message = await messageService.createMessage({
        chatRoomId,
        senderId: '', // Agent messages don't have a user sender
        senderType: 'AGENT',
        content,
        messageType: messageType || 'TEXT',
        agentInstanceId,
        metadata: metadata || {},
      });

      res.status(201).json({ success: true, data: message });
    } catch (error: any) {
      res.status(500).json({ 
        error: 'Failed to send agent message', 
        message: error.message 
      });
    }
  }
);

/**
 * PUT /api/v1/service/messages/:id
 * Service-to-service endpoint for cyrex to update messages
 * Useful for streaming updates
 */
router.put(
  '/messages/:id',
  authenticateService,
  [
    param('id').isUUID(),
    body('content').notEmpty().trim(),
  ],
  handleValidationErrors,
  async (req: Request, res: Response) => {
    try {
      const { id } = req.params;
      const { content } = req.body;

      const message = await messageService.updateMessage(id, content);

      res.json({ success: true, data: message });
    } catch (error: any) {
      res.status(500).json({ 
        error: 'Failed to update message', 
        message: error.message 
      });
    }
  }
);

export default router;


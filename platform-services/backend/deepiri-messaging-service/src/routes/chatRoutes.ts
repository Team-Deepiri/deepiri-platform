import { Router, Request, Response } from 'express';
import { body, param, query, validationResult } from 'express-validator';
import { chatService } from '../services/chatService';
import { authenticate } from './middleware/auth';
import { handleValidationErrors } from './middleware/validation';

const router = Router();

/**
 * POST /api/v1/chats
 * Create new chat room (agent or group)
 */
router.post(
  '/',
  authenticate,
  [
    body('type').isIn(['AGENT', 'GROUP', 'DIRECT']),
    body('name').optional().trim(),
    body('agentInstanceId').optional().trim(),
    body('userIds').optional().isArray(),
    body('agentIds').optional().isArray(),
  ],
  handleValidationErrors,
  async (req: Request, res: Response) => {
    try {
      const chat = await chatService.createChatRoom({
        type: req.body.type,
        name: req.body.name,
        agentInstanceId: req.body.agentInstanceId,
        userIds: req.body.userIds || [req.user!.id],
        agentIds: req.body.agentIds || [],
        createdBy: req.user!.id,
        metadata: req.body.metadata,
      });

      res.status(201).json({ success: true, data: chat });
    } catch (error: any) {
      res.status(500).json({ 
        error: 'Failed to create chat', 
        message: error.message 
      });
    }
  }
);

/**
 * GET /api/v1/chats
 * List all chat rooms for current user
 */
router.get(
  '/',
  authenticate,
  [
    query('type').optional().isIn(['AGENT', 'GROUP', 'DIRECT']),
    query('isArchived').optional().isBoolean(),
    query('skip').optional().isInt({ min: 0 }),
    query('take').optional().isInt({ min: 1, max: 100 }),
  ],
  handleValidationErrors,
  async (req: Request, res: Response) => {
    try {
      const { chatRooms, total } = await chatService.getChatRoomsForUser(
        req.user!.id,
        {
          type: req.query.type as any,
          isArchived: req.query.isArchived === 'true',
          skip: req.query.skip ? parseInt(req.query.skip as string) : undefined,
          take: req.query.take ? parseInt(req.query.take as string) : undefined,
        }
      );

      res.json({ 
        success: true, 
        data: chatRooms,
        total,
      });
    } catch (error: any) {
      res.status(500).json({ 
        error: 'Failed to fetch chats', 
        message: error.message 
      });
    }
  }
);

/**
 * GET /api/v1/chats/:id
 * Get chat room by ID
 */
router.get(
  '/:id',
  authenticate,
  [param('id').isUUID()],
  handleValidationErrors,
  async (req: Request, res: Response) => {
    try {
      const chat = await chatService.getChatRoom(req.params.id);
      res.json({ success: true, data: chat });
    } catch (error: any) {
      const statusCode = error.statusCode || 500;
      res.status(statusCode).json({ 
        error: 'Failed to fetch chat', 
        message: error.message 
      });
    }
  }
);

/**
 * PUT /api/v1/chats/:id
 * Update chat room
 */
router.put(
  '/:id',
  authenticate,
  [
    param('id').isUUID(),
    body('name').optional().trim(),
    body('metadata').optional(),
    body('isArchived').optional().isBoolean(),
  ],
  handleValidationErrors,
  async (req: Request, res: Response) => {
    try {
      const chat = await chatService.updateChatRoom(req.params.id, {
        name: req.body.name,
        metadata: req.body.metadata,
        isArchived: req.body.isArchived,
      });

      res.json({ success: true, data: chat });
    } catch (error: any) {
      const statusCode = error.statusCode || 500;
      res.status(statusCode).json({ 
        error: 'Failed to update chat', 
        message: error.message 
      });
    }
  }
);

/**
 * POST /api/v1/chats/:id/participants
 * Add participant to chat room
 */
router.post(
  '/:id/participants',
  authenticate,
  [
    param('id').isUUID(),
    body('userId').optional().isUUID(),
    body('agentInstanceId').optional().trim(),
    body('role').optional().isIn(['admin', 'member', 'viewer']),
  ],
  handleValidationErrors,
  async (req: Request, res: Response) => {
    try {
      const participant = await chatService.addParticipant(
        req.params.id,
        req.body.userId,
        req.body.agentInstanceId,
        req.body.role || 'member'
      );

      res.status(201).json({ success: true, data: participant });
    } catch (error: any) {
      res.status(500).json({ 
        error: 'Failed to add participant', 
        message: error.message 
      });
    }
  }
);

/**
 * DELETE /api/v1/chats/:id/participants/:userId
 * Remove participant from chat room
 */
router.delete(
  '/:id/participants/:userId',
  authenticate,
  [
    param('id').isUUID(),
    param('userId').isUUID(),
  ],
  handleValidationErrors,
  async (req: Request, res: Response) => {
    try {
      await chatService.removeParticipant(req.params.id, req.params.userId);
      res.json({ success: true });
    } catch (error: any) {
      res.status(500).json({ 
        error: 'Failed to remove participant', 
        message: error.message 
      });
    }
  }
);

export default router;


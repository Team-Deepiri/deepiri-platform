import { Request, Response } from 'express';
import { createLogger } from '@deepiri/shared-utils';
import prisma from '../db';
import { IObjective } from '../models/Objective';
import momentumService from './momentumService';

const logger = createLogger('objective-service');

class ObjectiveService {
  /**
   * Convert Prisma Task to IObjective
   */
  private taskToObjective(task: any): IObjective {
    return {
      userId: task.userId,
      title: task.title,
      description: task.description || undefined,
      status: task.status as 'draft' | 'active' | 'completed' | 'cancelled',
      momentumReward: task.momentumReward,
      deadline: task.dueDate || undefined,
      subtasks: (task.subtaskItems || []).map((st: any) => ({
        id: st.id,
        title: st.title,
        completed: st.completed,
        momentumReward: st.momentumReward
      })),
      aiSuggestions: (task.aiSuggestions as any[]) || [],
      completionData: {
        completedAt: task.completedAt || undefined,
        actualDuration: task.actualMinutes || undefined,
        momentumEarned: task.momentumReward,
        autoDetected: false
      },
      odysseyId: task.questId || undefined,
      seasonId: undefined, // Would need to join with quest
      metadata: (task.metadata as Record<string, any>) || undefined,
      createdAt: task.createdAt,
      updatedAt: task.updatedAt
    };
  }

  /**
   * Create a new objective (task)
   */
  async createObjective(
    userId: string,
    title: string,
    description?: string,
    momentumReward?: number,
    deadline?: Date,
    odysseyId?: string,
    seasonId?: string
  ): Promise<IObjective> {
    try {
      const task = await prisma.task.create({
        data: {
          userId,
          title,
          description,
          momentumReward: momentumReward || 10,
          dueDate: deadline,
          questId: odysseyId || undefined,
          status: 'todo',
          priority: 'medium',
          difficulty: 'medium',
          aiSuggestions: [],
          tags: [],
          metadata: {}
        },
        include: {
          subtaskItems: true
        }
      });
      
      return this.taskToObjective(task);
    } catch (error: any) {
      logger.error('Error creating objective:', error);
      throw error;
    }
  }

  /**
   * Complete an objective
   */
  async completeObjective(
    objectiveId: string,
    autoDetected: boolean = false,
    actualDuration?: number
  ): Promise<IObjective> {
    try {
      const task = await prisma.task.findUnique({
        where: { id: objectiveId },
        include: {
          subtaskItems: true
        }
      });
      
      if (!task) {
        throw new Error('Objective not found');
      }
      
      if (task.status === 'done') {
        return this.taskToObjective(task);
      }
      
      // Update task status
      const updatedTask = await prisma.task.update({
        where: { id: objectiveId },
        data: {
          status: 'done',
          completedAt: new Date(),
          actualMinutes: actualDuration
        },
        include: {
          subtaskItems: true
        }
      });
      
      // Create completion record
      await prisma.taskCompletion.create({
        data: {
          taskId: objectiveId,
          userId: task.userId,
          momentumEarned: task.momentumReward,
          timeTakenMinutes: actualDuration,
          autoDetected,
          completionMethod: autoDetected ? 'auto' : 'manual'
        }
      });
      
      // Award momentum
      await momentumService.awardMomentum(
        task.userId,
        task.momentumReward,
        'tasks'
      );
      
      // Emit objective completed event
      try {
        const axios = (await import('axios')).default;
        const REALTIME_GATEWAY_URL = process.env.REALTIME_GATEWAY_URL || 'http://realtime-gateway:5008';
        await axios.post(`${REALTIME_GATEWAY_URL}/emit/gamification`, {
          userId: task.userId,
          type: 'objective_completed',
          data: {
            objectiveId: task.id,
            title: task.title,
            momentumEarned: task.momentumReward
          }
        });
      } catch (error: any) {
        logger.error('Failed to emit objective completed event:', error.message);
      }
      
      return this.taskToObjective(updatedTask);
    } catch (error: any) {
      logger.error('Error completing objective:', error);
      throw error;
    }
  }

  /**
   * Create objective endpoint
   */
  async create(req: Request, res: Response): Promise<void> {
    try {
      const { userId, title, description, momentumReward, deadline, odysseyId, seasonId } = req.body;
      
      if (!userId || !title) {
        res.status(400).json({ error: 'userId and title are required' });
        return;
      }
      
      const objective = await this.createObjective(
        userId,
        title,
        description,
        momentumReward,
        deadline ? new Date(deadline) : undefined,
        odysseyId,
        seasonId
      );
      
      res.json({
        success: true,
        data: objective
      });
    } catch (error: any) {
      logger.error('Error creating objective:', error);
      res.status(500).json({ error: 'Failed to create objective' });
    }
  }

  /**
   * Get objectives for a user
   */
  async getObjectives(req: Request, res: Response): Promise<void> {
    try {
      const { userId } = req.params;
      const { status, odysseyId, seasonId } = req.query;
      
      if (!userId) {
        res.status(400).json({ error: 'userId is required' });
        return;
      }
      
      const where: any = { userId };
      
      if (status) {
        where.status = status;
      }
      if (odysseyId) {
        where.questId = odysseyId;
      }
      
      const tasks = await prisma.task.findMany({
        where,
        include: {
          subtaskItems: true
        },
        orderBy: {
          createdAt: 'desc'
        }
      });
      
      const objectives = tasks.map(task => this.taskToObjective(task));
      
      res.json({
        success: true,
        data: objectives
      });
    } catch (error: any) {
      logger.error('Error getting objectives:', error);
      res.status(500).json({ error: 'Failed to get objectives' });
    }
  }

  /**
   * Get single objective
   */
  async getObjective(req: Request, res: Response): Promise<void> {
    try {
      const { id } = req.params;
      
      const task = await prisma.task.findUnique({
        where: { id },
        include: {
          subtaskItems: true
        }
      });
      
      if (!task) {
        res.status(404).json({ error: 'Objective not found' });
        return;
      }
      
      res.json({
        success: true,
        data: this.taskToObjective(task)
      });
    } catch (error: any) {
      logger.error('Error getting objective:', error);
      res.status(500).json({ error: 'Failed to get objective' });
    }
  }

  /**
   * Complete objective endpoint
   */
  async complete(req: Request, res: Response): Promise<void> {
    try {
      const { id } = req.params;
      const { autoDetected, actualDuration } = req.body;
      
      const objective = await this.completeObjective(
        id,
        autoDetected || false,
        actualDuration
      );
      
      res.json({
        success: true,
        data: objective
      });
    } catch (error: any) {
      logger.error('Error completing objective:', error);
      res.status(400).json({ error: error.message || 'Failed to complete objective' });
    }
  }

  /**
   * Update objective
   */
  async update(req: Request, res: Response): Promise<void> {
    try {
      const { id } = req.params;
      const updates = req.body;
      
      // Map IObjective fields to Task fields
      const taskUpdates: any = {};
      if (updates.title) taskUpdates.title = updates.title;
      if (updates.description !== undefined) taskUpdates.description = updates.description;
      if (updates.status) taskUpdates.status = updates.status;
      if (updates.momentumReward !== undefined) taskUpdates.momentumReward = updates.momentumReward;
      if (updates.deadline) taskUpdates.dueDate = new Date(updates.deadline);
      if (updates.odysseyId) taskUpdates.questId = updates.odysseyId;
      
      const task = await prisma.task.update({
        where: { id },
        data: taskUpdates,
        include: {
          subtaskItems: true
        }
      });
      
      res.json({
        success: true,
        data: this.taskToObjective(task)
      });
    } catch (error: any) {
      logger.error('Error updating objective:', error);
      res.status(500).json({ error: 'Failed to update objective' });
    }
  }

  /**
   * Delete objective
   */
  async delete(req: Request, res: Response): Promise<void> {
    try {
      const { id } = req.params;
      
      await prisma.task.delete({
        where: { id }
      });
      
      res.json({
        success: true,
        message: 'Objective deleted'
      });
    } catch (error: any) {
      logger.error('Error deleting objective:', error);
      res.status(500).json({ error: 'Failed to delete objective' });
    }
  }
}

export default new ObjectiveService();

import { Request, Response } from 'express';
import mongoose, { Types } from 'mongoose';
import { createLogger } from '@deepiri/shared-utils';
import Objective, { IObjective } from '../models/Objective';
import momentumService from './momentumService';

const logger = createLogger('objective-service');

class ObjectiveService {
  /**
   * Create a new objective
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
      const objective = new Objective({
        userId: new Types.ObjectId(userId),
        title,
        description,
        momentumReward: momentumReward || 10, // Default reward
        deadline,
        status: 'draft',
        odysseyId: odysseyId ? new Types.ObjectId(odysseyId) : undefined,
        seasonId: seasonId ? new Types.ObjectId(seasonId) : undefined
      });
      
      await objective.save();
      
      return objective;
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
      const objective = await Objective.findById(objectiveId);
      
      if (!objective) {
        throw new Error('Objective not found');
      }
      
      if (objective.status === 'completed') {
        return objective;
      }
      
      objective.status = 'completed';
      objective.completionData = {
        completedAt: new Date(),
        actualDuration,
        momentumEarned: objective.momentumReward,
        autoDetected
      };
      
      // Award momentum
      await momentumService.awardMomentum(
        objective.userId.toString(),
        objective.momentumReward,
        'tasks'
      );
      
      await objective.save();
      
      // Emit objective completed event
      try {
        const axios = (await import('axios')).default;
        const REALTIME_GATEWAY_URL = process.env.REALTIME_GATEWAY_URL || 'http://realtime-gateway:5008';
        await axios.post(`${REALTIME_GATEWAY_URL}/emit/gamification`, {
          userId: objective.userId.toString(),
          type: 'objective_completed',
          data: {
            objectiveId: objective._id.toString(),
            title: objective.title,
            momentumEarned: objective.momentumReward
          }
        });
      } catch (error: any) {
        logger.error('Failed to emit objective completed event:', error.message);
      }
      
      return objective;
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
      
      const query: any = { userId: new Types.ObjectId(userId) };
      
      if (status) {
        query.status = status;
      }
      if (odysseyId) {
        query.odysseyId = new Types.ObjectId(odysseyId as string);
      }
      if (seasonId) {
        query.seasonId = new Types.ObjectId(seasonId as string);
      }
      
      const objectives = await Objective.find(query)
        .sort({ createdAt: -1 })
        .lean();
      
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
      
      const objective = await Objective.findById(id);
      
      if (!objective) {
        res.status(404).json({ error: 'Objective not found' });
        return;
      }
      
      res.json({
        success: true,
        data: objective
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
      
      const objective = await Objective.findByIdAndUpdate(
        id,
        { $set: updates },
        { new: true }
      );
      
      if (!objective) {
        res.status(404).json({ error: 'Objective not found' });
        return;
      }
      
      res.json({
        success: true,
        data: objective
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
      
      const objective = await Objective.findByIdAndDelete(id);
      
      if (!objective) {
        res.status(404).json({ error: 'Objective not found' });
        return;
      }
      
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


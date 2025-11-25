import { Request, Response } from 'express';
import mongoose, { Types } from 'mongoose';
import { createLogger } from '@deepiri/shared-utils';
import Odyssey, { IOdyssey, OdysseyScale } from '../models/Odyssey';
import Objective from '../models/Objective';

const logger = createLogger('odyssey-service');

class OdysseyService {
  /**
   * Create a new odyssey
   */
  async createOdyssey(
    userId: string,
    title: string,
    description?: string,
    scale: OdysseyScale = 'week',
    minimumHoursBeforeSelection?: number,
    organizationId?: string,
    seasonId?: string
  ): Promise<IOdyssey> {
    try {
      const odyssey = new Odyssey({
        userId: new Types.ObjectId(userId),
        title,
        description,
        scale,
        minimumHoursBeforeSelection,
        organizationId: organizationId ? new Types.ObjectId(organizationId) : undefined,
        seasonId: seasonId ? new Types.ObjectId(seasonId) : undefined,
        status: 'planning',
        progress: {
          objectivesCompleted: 0,
          totalObjectives: 0,
          milestonesCompleted: 0,
          totalMilestones: 0,
          progressPercentage: 0
        }
      });
      
      await odyssey.save();
      
      return odyssey;
    } catch (error: any) {
      logger.error('Error creating odyssey:', error);
      throw error;
    }
  }

  /**
   * Add objective to odyssey
   */
  async addObjective(odysseyId: string, objectiveId: string): Promise<IOdyssey> {
    try {
      const odyssey = await Odyssey.findById(odysseyId);
      
      if (!odyssey) {
        throw new Error('Odyssey not found');
      }
      
      if (!odyssey.objectives.includes(new Types.ObjectId(objectiveId))) {
        odyssey.objectives.push(new Types.ObjectId(objectiveId));
        odyssey.progress.totalObjectives += 1;
        
        // Update objective to link to odyssey
        await Objective.findByIdAndUpdate(objectiveId, {
          odysseyId: new Types.ObjectId(odysseyId)
        });
        
        await odyssey.save();
      }
      
      return odyssey;
    } catch (error: any) {
      logger.error('Error adding objective to odyssey:', error);
      throw error;
    }
  }

  /**
   * Add milestone to odyssey
   */
  async addMilestone(
    odysseyId: string,
    title: string,
    description?: string,
    momentumReward: number = 0
  ): Promise<IOdyssey> {
    try {
      const odyssey = await Odyssey.findById(odysseyId);
      
      if (!odyssey) {
        throw new Error('Odyssey not found');
      }
      
      const milestoneId = new Types.ObjectId().toString();
      odyssey.milestones.push({
        id: milestoneId,
        title,
        description,
        completed: false,
        momentumReward
      });
      
      odyssey.progress.totalMilestones += 1;
      await odyssey.save();
      
      return odyssey;
    } catch (error: any) {
      logger.error('Error adding milestone:', error);
      throw error;
    }
  }

  /**
   * Complete milestone
   */
  async completeMilestone(odysseyId: string, milestoneId: string): Promise<IOdyssey> {
    try {
      const odyssey = await Odyssey.findById(odysseyId);
      
      if (!odyssey) {
        throw new Error('Odyssey not found');
      }
      
      const milestone = odyssey.milestones.find(m => m.id === milestoneId);
      if (!milestone) {
        throw new Error('Milestone not found');
      }
      
      if (!milestone.completed) {
        milestone.completed = true;
        milestone.completedAt = new Date();
        odyssey.progress.milestonesCompleted += 1;
        
        // Award momentum if reward is set
        if (milestone.momentumReward > 0) {
          const momentumService = (await import('./momentumService')).default;
          await momentumService.awardMomentum(
            odyssey.userId.toString(),
            milestone.momentumReward,
            'tasks'
          );
          
          // Emit milestone completed event
          try {
            const axios = (await import('axios')).default;
            const REALTIME_GATEWAY_URL = process.env.REALTIME_GATEWAY_URL || 'http://realtime-gateway:5008';
            await axios.post(`${REALTIME_GATEWAY_URL}/emit/gamification`, {
              userId: odyssey.userId.toString(),
              type: 'milestone_completed',
              data: {
                odysseyId: odyssey._id.toString(),
                milestoneTitle: milestone.title,
                momentumEarned: milestone.momentumReward
              }
            });
          } catch (error: any) {
            logger.error('Failed to emit milestone completed event:', error.message);
          }
        }
        
        await odyssey.save();
      }
      
      return odyssey;
    } catch (error: any) {
      logger.error('Error completing milestone:', error);
      throw error;
    }
  }

  /**
   * Create odyssey endpoint
   */
  async create(req: Request, res: Response): Promise<void> {
    try {
      const { userId, title, description, scale, minimumHoursBeforeSelection, organizationId, seasonId } = req.body;
      
      if (!userId || !title) {
        res.status(400).json({ error: 'userId and title are required' });
        return;
      }
      
      const odyssey = await this.createOdyssey(
        userId,
        title,
        description,
        scale,
        minimumHoursBeforeSelection,
        organizationId,
        seasonId
      );
      
      res.json({
        success: true,
        data: odyssey
      });
    } catch (error: any) {
      logger.error('Error creating odyssey:', error);
      res.status(500).json({ error: 'Failed to create odyssey' });
    }
  }

  /**
   * Get odysseys for a user
   */
  async getOdysseys(req: Request, res: Response): Promise<void> {
    try {
      const { userId } = req.params;
      const { status, organizationId, seasonId } = req.query;
      
      if (!userId) {
        res.status(400).json({ error: 'userId is required' });
        return;
      }
      
      const query: any = { userId: new Types.ObjectId(userId) };
      
      if (status) {
        query.status = status;
      }
      if (organizationId) {
        query.organizationId = new Types.ObjectId(organizationId as string);
      }
      if (seasonId) {
        query.seasonId = new Types.ObjectId(seasonId as string);
      }
      
      const odysseys = await Odyssey.find(query)
        .populate('objectives')
        .sort({ createdAt: -1 })
        .lean();
      
      res.json({
        success: true,
        data: odysseys
      });
    } catch (error: any) {
      logger.error('Error getting odysseys:', error);
      res.status(500).json({ error: 'Failed to get odysseys' });
    }
  }

  /**
   * Get single odyssey
   */
  async getOdyssey(req: Request, res: Response): Promise<void> {
    try {
      const { id } = req.params;
      
      const odyssey = await Odyssey.findById(id)
        .populate('objectives')
        .lean();
      
      if (!odyssey) {
        res.status(404).json({ error: 'Odyssey not found' });
        return;
      }
      
      res.json({
        success: true,
        data: odyssey
      });
    } catch (error: any) {
      logger.error('Error getting odyssey:', error);
      res.status(500).json({ error: 'Failed to get odyssey' });
    }
  }

  /**
   * Add objective to odyssey endpoint
   */
  async addObjectiveEndpoint(req: Request, res: Response): Promise<void> {
    try {
      const { id } = req.params;
      const { objectiveId } = req.body;
      
      if (!objectiveId) {
        res.status(400).json({ error: 'objectiveId is required' });
        return;
      }
      
      const odyssey = await this.addObjective(id, objectiveId);
      
      res.json({
        success: true,
        data: odyssey
      });
    } catch (error: any) {
      logger.error('Error adding objective:', error);
      res.status(400).json({ error: error.message || 'Failed to add objective' });
    }
  }

  /**
   * Add milestone endpoint
   */
  async addMilestoneEndpoint(req: Request, res: Response): Promise<void> {
    try {
      const { id } = req.params;
      const { title, description, momentumReward } = req.body;
      
      if (!title) {
        res.status(400).json({ error: 'title is required' });
        return;
      }
      
      const odyssey = await this.addMilestone(id, title, description, momentumReward);
      
      res.json({
        success: true,
        data: odyssey
      });
    } catch (error: any) {
      logger.error('Error adding milestone:', error);
      res.status(400).json({ error: error.message || 'Failed to add milestone' });
    }
  }

  /**
   * Complete milestone endpoint
   */
  async completeMilestoneEndpoint(req: Request, res: Response): Promise<void> {
    try {
      const { id, milestoneId } = req.params;
      
      const odyssey = await this.completeMilestone(id, milestoneId);
      
      res.json({
        success: true,
        data: odyssey
      });
    } catch (error: any) {
      logger.error('Error completing milestone:', error);
      res.status(400).json({ error: error.message || 'Failed to complete milestone' });
    }
  }

  /**
   * Update odyssey
   */
  async update(req: Request, res: Response): Promise<void> {
    try {
      const { id } = req.params;
      const updates = req.body;
      
      const odyssey = await Odyssey.findByIdAndUpdate(
        id,
        { $set: updates },
        { new: true }
      );
      
      if (!odyssey) {
        res.status(404).json({ error: 'Odyssey not found' });
        return;
      }
      
      res.json({
        success: true,
        data: odyssey
      });
    } catch (error: any) {
      logger.error('Error updating odyssey:', error);
      res.status(500).json({ error: 'Failed to update odyssey' });
    }
  }
}

export default new OdysseyService();


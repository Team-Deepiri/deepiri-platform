import { Request, Response } from 'express';
import { createLogger } from '@deepiri/shared-utils';
import prisma from '../db';
import { IOdyssey, OdysseyScale } from '../models/Odyssey';

const logger = createLogger('odyssey-service');

class OdysseyService {
  /**
   * Convert Prisma Quest to IOdyssey
   */
  private questToOdyssey(quest: any): IOdyssey {
    const milestones = (quest.questMilestones || []).map((m: any) => ({
      id: m.id,
      title: m.title,
      description: m.description || undefined,
      completed: m.completed,
      completedAt: m.completedAt || undefined,
      momentumReward: m.momentumReward
    }));

    const objectives = (quest.tasks || []).map((t: any) => t.id);

    return {
      userId: quest.userId,
      title: quest.title,
      description: quest.description || undefined,
      scale: quest.scale as OdysseyScale,
      minimumHoursBeforeSelection: undefined, // Not in schema yet
      organizationId: undefined, // Not in schema yet
      seasonId: quest.seasonId || undefined,
      status: quest.status as 'planning' | 'active' | 'completed' | 'paused' | 'cancelled',
      objectives,
      milestones,
      progress: {
        objectivesCompleted: quest.objectivesCompleted,
        totalObjectives: quest.totalObjectives,
        milestonesCompleted: milestones.filter((m: any) => m.completed).length,
        totalMilestones: milestones.length,
        progressPercentage: quest.progressPercentage
      },
      aiGeneratedBrief: {
        animation: quest.aiAnimation || undefined,
        summary: quest.aiSummary || '',
        generatedAt: quest.createdAt
      },
      progressMap: {
        currentStage: quest.currentStage,
        stages: [] // Would need separate table or JSONB field
      },
      startDate: quest.startDate,
      endDate: quest.endDate || undefined,
      metadata: (quest.metadata as Record<string, any>) || undefined,
      createdAt: quest.createdAt,
      updatedAt: quest.updatedAt
    };
  }

  /**
   * Create a new odyssey (quest)
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
      const quest = await prisma.quest.create({
        data: {
          userId,
          title,
          description,
          scale,
          seasonId: seasonId || undefined,
          status: 'planning',
          objectivesCompleted: 0,
          totalObjectives: 0,
          progressPercentage: 0,
          currentStage: 'start',
          metadata: {
            minimumHoursBeforeSelection,
            organizationId
          }
        },
        include: {
          questMilestones: true,
          tasks: true
        }
      });
      
      return this.questToOdyssey(quest);
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
      // Update task to link to quest
      await prisma.task.update({
        where: { id: objectiveId },
        data: { questId: odysseyId }
      });

      // Update quest progress
      const quest = await prisma.quest.findUnique({
        where: { id: odysseyId },
        include: {
          questMilestones: true,
          tasks: true
        }
      });

      if (!quest) {
        throw new Error('Odyssey not found');
      }

      const updatedQuest = await prisma.quest.update({
        where: { id: odysseyId },
        data: {
          totalObjectives: quest.tasks.length + 1,
          progressPercentage: quest.totalObjectives > 0 
            ? (quest.objectivesCompleted / (quest.totalObjectives + 1)) * 100 
            : 0
        },
        include: {
          questMilestones: true,
          tasks: true
        }
      });
      
      return this.questToOdyssey(updatedQuest);
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
      await prisma.questMilestone.create({
        data: {
          questId: odysseyId,
          title,
          description,
          momentumReward,
          completed: false,
          sortOrder: 0
        }
      });

      const quest = await prisma.quest.findUnique({
        where: { id: odysseyId },
        include: {
          questMilestones: true,
          tasks: true
        }
      });

      if (!quest) {
        throw new Error('Odyssey not found');
      }

      return this.questToOdyssey(quest);
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
      const milestone = await prisma.questMilestone.findUnique({
        where: { id: milestoneId }
      });

      if (!milestone || milestone.questId !== odysseyId) {
        throw new Error('Milestone not found');
      }

      if (milestone.completed) {
        // Already completed, just return the quest
        const quest = await prisma.quest.findUnique({
          where: { id: odysseyId },
          include: {
            questMilestones: true,
            tasks: true
          }
        });
        if (!quest) throw new Error('Odyssey not found');
        return this.questToOdyssey(quest);
      }

      // Update milestone
      await prisma.questMilestone.update({
        where: { id: milestoneId },
        data: {
          completed: true,
          completedAt: new Date()
        }
      });

      // Award momentum if reward is set
      if (milestone.momentumReward > 0) {
        const quest = await prisma.quest.findUnique({
          where: { id: odysseyId }
        });
        if (quest) {
          const momentumService = (await import('./momentumService')).default;
          await momentumService.awardMomentum(
            quest.userId,
            milestone.momentumReward,
            'tasks'
          );
          
          // Emit milestone completed event
          try {
            const axios = (await import('axios')).default;
            const REALTIME_GATEWAY_URL = process.env.REALTIME_GATEWAY_URL || 'http://realtime-gateway:5008';
            await axios.post(`${REALTIME_GATEWAY_URL}/emit/gamification`, {
              userId: quest.userId,
              type: 'milestone_completed',
              data: {
                odysseyId: quest.id,
                milestoneTitle: milestone.title,
                momentumEarned: milestone.momentumReward
              }
            });
          } catch (error: any) {
            logger.error('Failed to emit milestone completed event:', error.message);
          }
        }
      }

      const quest = await prisma.quest.findUnique({
        where: { id: odysseyId },
        include: {
          questMilestones: true,
          tasks: true
        }
      });

      if (!quest) {
        throw new Error('Odyssey not found');
      }

      return this.questToOdyssey(quest);
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
      
      const where: any = { userId };
      
      if (status) {
        where.status = status;
      }
      if (seasonId) {
        where.seasonId = seasonId as string;
      }
      
      const quests = await prisma.quest.findMany({
        where,
        include: {
          questMilestones: true,
          tasks: true
        },
        orderBy: {
          createdAt: 'desc'
        }
      });
      
      const odysseys = quests.map(quest => this.questToOdyssey(quest));
      
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
      
      const quest = await prisma.quest.findUnique({
        where: { id },
        include: {
          questMilestones: true,
          tasks: true
        }
      });
      
      if (!quest) {
        res.status(404).json({ error: 'Odyssey not found' });
        return;
      }
      
      res.json({
        success: true,
        data: this.questToOdyssey(quest)
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
      
      // Map IOdyssey fields to Quest fields
      const questUpdates: any = {};
      if (updates.title) questUpdates.title = updates.title;
      if (updates.description !== undefined) questUpdates.description = updates.description;
      if (updates.status) questUpdates.status = updates.status;
      if (updates.scale) questUpdates.scale = updates.scale;
      if (updates.seasonId) questUpdates.seasonId = updates.seasonId;
      if (updates.endDate) questUpdates.endDate = new Date(updates.endDate);
      
      const quest = await prisma.quest.update({
        where: { id },
        data: questUpdates,
        include: {
          questMilestones: true,
          tasks: true
        }
      });
      
      res.json({
        success: true,
        data: this.questToOdyssey(quest)
      });
    } catch (error: any) {
      logger.error('Error updating odyssey:', error);
      res.status(500).json({ error: 'Failed to update odyssey' });
    }
  }
}

export default new OdysseyService();

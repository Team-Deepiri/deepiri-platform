import { Request, Response } from 'express';
import { createLogger } from '@deepiri/shared-utils';
import prisma from '../db';
import { ISeason } from '../models/Season';

const logger = createLogger('season-service');

class SeasonService {
  /**
   * Convert Prisma Season to ISeason
   */
  private seasonToInterface(season: any): ISeason {
    const odysseys = (season.quests || []).map((q: any) => q.id);

    return {
      userId: '', // Not in schema - would need to be added or derived
      name: season.name,
      description: season.description || undefined,
      startDate: season.startDate,
      endDate: season.endDate,
      sprintCycle: undefined, // Not in schema
      organizationId: undefined, // Not in schema
      status: season.isActive ? 'active' : 'upcoming',
      odysseys,
      seasonBoosts: {
        enabled: (season.seasonBoosts || []).length > 0,
        boostType: (season.seasonBoosts || [])[0]?.boostType,
        multiplier: (season.seasonBoosts || [])[0]?.boostMultiplier || 1.0,
        description: (season.seasonBoosts || [])[0]?.description
      },
      highlights: {
        totalMomentumEarned: 0, // Would need to calculate from quests
        objectivesCompleted: 0, // Would need to calculate from tasks
        odysseysCompleted: odysseys.length,
        topContributors: []
      },
      metadata: (season.metadata as Record<string, any>) || undefined,
      createdAt: season.createdAt,
      updatedAt: season.updatedAt
    };
  }

  /**
   * Create a new season
   */
  async createSeason(
    userId: string,
    name: string,
    startDate: Date,
    endDate: Date,
    description?: string,
    sprintCycle?: string,
    organizationId?: string
  ): Promise<ISeason> {
    try {
      const season = await prisma.season.create({
        data: {
          name,
          description,
          startDate,
          endDate,
          isActive: new Date() >= startDate,
          theme: {},
          rewards: {},
          metadata: {
            userId,
            sprintCycle,
            organizationId
          }
        },
        include: {
          quests: true,
          seasonBoosts: true
        }
      });
      
      return this.seasonToInterface(season);
    } catch (error: any) {
      logger.error('Error creating season:', error);
      throw error;
    }
  }

  /**
   * Add odyssey to season
   */
  async addOdyssey(seasonId: string, odysseyId: string): Promise<ISeason> {
    try {
      // Update quest to link to season
      await prisma.quest.update({
        where: { id: odysseyId },
        data: { seasonId }
      });

      const season = await prisma.season.findUnique({
        where: { id: seasonId },
        include: {
          quests: true,
          seasonBoosts: true
        }
      });

      if (!season) {
        throw new Error('Season not found');
      }

      return this.seasonToInterface(season);
    } catch (error: any) {
      logger.error('Error adding odyssey to season:', error);
      throw error;
    }
  }

  /**
   * Enable season boost
   */
  async enableSeasonBoost(
    seasonId: string,
    boostType: string,
    multiplier: number = 1.5,
    description?: string
  ): Promise<ISeason> {
    try {
      await prisma.seasonBoost.create({
        data: {
          seasonId,
          name: `${boostType} Boost`,
          description,
          boostType,
          boostMultiplier: multiplier,
          isActive: true
        }
      });

      const season = await prisma.season.findUnique({
        where: { id: seasonId },
        include: {
          quests: true,
          seasonBoosts: true
        }
      });

      if (!season) {
        throw new Error('Season not found');
      }

      return this.seasonToInterface(season);
    } catch (error: any) {
      logger.error('Error enabling season boost:', error);
      throw error;
    }
  }

  /**
   * Generate season highlights
   */
  async generateHighlights(seasonId: string): Promise<ISeason> {
    try {
      const season = await prisma.season.findUnique({
        where: { id: seasonId },
        include: {
          quests: {
            include: {
              tasks: {
                where: {
                  status: 'done'
                },
                include: {
                  taskCompletions: true
                }
              }
            }
          },
          seasonBoosts: true
        }
      });

      if (!season) {
        throw new Error('Season not found');
      }

      // Calculate totals
      let totalMomentum = 0;
      let objectivesCompleted = 0;
      let odysseysCompleted = 0;

      for (const quest of season.quests) {
        if (quest.status === 'completed') {
          odysseysCompleted += 1;
        }

        objectivesCompleted += quest.tasks.length;

        // Sum momentum from completed tasks
        for (const task of quest.tasks) {
          for (const completion of task.taskCompletions) {
            totalMomentum += completion.momentumEarned;
          }
        }
      }

      // Update season metadata with highlights
      const highlights = {
        totalMomentumEarned: totalMomentum,
        objectivesCompleted,
        odysseysCompleted,
        topContributors: [],
        generatedAt: new Date()
      };

      await prisma.season.update({
        where: { id: seasonId },
        data: {
          metadata: {
            ...(season.metadata as any || {}),
            highlights
          }
        }
      });

      const updatedSeason = await prisma.season.findUnique({
        where: { id: seasonId },
        include: {
          quests: true,
          seasonBoosts: true
        }
      });

      if (!updatedSeason) {
        throw new Error('Season not found');
      }

      const seasonInterface = this.seasonToInterface(updatedSeason);
      seasonInterface.highlights = highlights as any;

      return seasonInterface;
    } catch (error: any) {
      logger.error('Error generating highlights:', error);
      throw error;
    }
  }

  /**
   * Create season endpoint
   */
  async create(req: Request, res: Response): Promise<void> {
    try {
      const { userId, name, startDate, endDate, description, sprintCycle, organizationId } = req.body;
      
      if (!userId || !name || !startDate || !endDate) {
        res.status(400).json({ error: 'userId, name, startDate, and endDate are required' });
        return;
      }
      
      const season = await this.createSeason(
        userId,
        name,
        new Date(startDate),
        new Date(endDate),
        description,
        sprintCycle,
        organizationId
      );
      
      res.json({
        success: true,
        data: season
      });
    } catch (error: any) {
      logger.error('Error creating season:', error);
      res.status(500).json({ error: 'Failed to create season' });
    }
  }

  /**
   * Get seasons for a user/organization
   */
  async getSeasons(req: Request, res: Response): Promise<void> {
    try {
      const { userId, organizationId, status } = req.query;
      
      const where: any = {};
      
      // Note: userId and organizationId would need to be in metadata or separate table
      if (status) {
        where.isActive = status === 'active';
      }
      
      const seasons = await prisma.season.findMany({
        where,
        include: {
          quests: true,
          seasonBoosts: true
        },
        orderBy: {
          startDate: 'desc'
        }
      });
      
      const seasonInterfaces = seasons.map(season => this.seasonToInterface(season));
      
      res.json({
        success: true,
        data: seasonInterfaces
      });
    } catch (error: any) {
      logger.error('Error getting seasons:', error);
      res.status(500).json({ error: 'Failed to get seasons' });
    }
  }

  /**
   * Get single season
   */
  async getSeason(req: Request, res: Response): Promise<void> {
    try {
      const { id } = req.params;
      
      const season = await prisma.season.findUnique({
        where: { id },
        include: {
          quests: true,
          seasonBoosts: true
        }
      });
      
      if (!season) {
        res.status(404).json({ error: 'Season not found' });
        return;
      }
      
      res.json({
        success: true,
        data: this.seasonToInterface(season)
      });
    } catch (error: any) {
      logger.error('Error getting season:', error);
      res.status(500).json({ error: 'Failed to get season' });
    }
  }

  /**
   * Add odyssey to season endpoint
   */
  async addOdysseyEndpoint(req: Request, res: Response): Promise<void> {
    try {
      const { id } = req.params;
      const { odysseyId } = req.body;
      
      if (!odysseyId) {
        res.status(400).json({ error: 'odysseyId is required' });
        return;
      }
      
      const season = await this.addOdyssey(id, odysseyId);
      
      res.json({
        success: true,
        data: season
      });
    } catch (error: any) {
      logger.error('Error adding odyssey:', error);
      res.status(400).json({ error: error.message || 'Failed to add odyssey' });
    }
  }

  /**
   * Enable season boost endpoint
   */
  async enableBoost(req: Request, res: Response): Promise<void> {
    try {
      const { id } = req.params;
      const { boostType, multiplier, description } = req.body;
      
      if (!boostType) {
        res.status(400).json({ error: 'boostType is required' });
        return;
      }
      
      const season = await this.enableSeasonBoost(id, boostType, multiplier, description);
      
      res.json({
        success: true,
        data: season
      });
    } catch (error: any) {
      logger.error('Error enabling season boost:', error);
      res.status(400).json({ error: error.message || 'Failed to enable season boost' });
    }
  }

  /**
   * Generate highlights endpoint
   */
  async generateHighlightsEndpoint(req: Request, res: Response): Promise<void> {
    try {
      const { id } = req.params;
      
      const season = await this.generateHighlights(id);
      
      res.json({
        success: true,
        data: season
      });
    } catch (error: any) {
      logger.error('Error generating highlights:', error);
      res.status(400).json({ error: error.message || 'Failed to generate highlights' });
    }
  }
}

export default new SeasonService();

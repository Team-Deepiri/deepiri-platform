import { Request, Response } from 'express';
import mongoose, { Types } from 'mongoose';
import { createLogger } from '@deepiri/shared-utils';
import Season, { ISeason } from '../models/Season';
import Odyssey from '../models/Odyssey';
import Objective from '../models/Objective';

const logger = createLogger('season-service');

class SeasonService {
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
      const season = new Season({
        userId: new Types.ObjectId(userId),
        name,
        description,
        startDate,
        endDate,
        sprintCycle,
        organizationId: organizationId ? new Types.ObjectId(organizationId) : undefined,
        status: new Date() < startDate ? 'upcoming' : 'active',
        highlights: {
          totalMomentumEarned: 0,
          objectivesCompleted: 0,
          odysseysCompleted: 0,
          topContributors: []
        }
      });
      
      await season.save();
      
      return season;
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
      const season = await Season.findById(seasonId);
      
      if (!season) {
        throw new Error('Season not found');
      }
      
      if (!season.odysseys.includes(new Types.ObjectId(odysseyId))) {
        season.odysseys.push(new Types.ObjectId(odysseyId));
        
        // Update odyssey to link to season
        await Odyssey.findByIdAndUpdate(odysseyId, {
          seasonId: new Types.ObjectId(seasonId)
        });
        
        await season.save();
      }
      
      return season;
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
      const season = await Season.findById(seasonId);
      
      if (!season) {
        throw new Error('Season not found');
      }
      
      season.seasonBoosts = {
        enabled: true,
        boostType,
        multiplier,
        description
      };
      
      await season.save();
      
      return season;
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
      const season = await Season.findById(seasonId);
      
      if (!season) {
        throw new Error('Season not found');
      }
      
      // Calculate totals from odysseys
      const odysseys = await Odyssey.find({ seasonId: new Types.ObjectId(seasonId) });
      
      let totalMomentum = 0;
      let objectivesCompleted = 0;
      let odysseysCompleted = 0;
      
      for (const odyssey of odysseys) {
        if (odyssey.status === 'completed') {
          odysseysCompleted += 1;
        }
        
        const objectives = await Objective.find({ odysseyId: odyssey._id });
        const completed = objectives.filter(obj => obj.status === 'completed');
        objectivesCompleted += completed.length;
        
        // Sum momentum from completed objectives
        completed.forEach(obj => {
          totalMomentum += obj.completionData?.momentumEarned || 0;
        });
      }
      
      season.highlights = {
        totalMomentumEarned: totalMomentum,
        objectivesCompleted,
        odysseysCompleted,
        topContributors: [], // Would need to aggregate from momentum service
        generatedAt: new Date()
      };
      
      await season.save();
      
      return season;
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
      
      const query: any = {};
      
      if (userId) {
        query.userId = new Types.ObjectId(userId as string);
      }
      if (organizationId) {
        query.organizationId = new Types.ObjectId(organizationId as string);
      }
      if (status) {
        query.status = status;
      }
      
      const seasons = await Season.find(query)
        .populate('odysseys')
        .sort({ startDate: -1 })
        .lean();
      
      res.json({
        success: true,
        data: seasons
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
      
      const season = await Season.findById(id)
        .populate('odysseys')
        .lean();
      
      if (!season) {
        res.status(404).json({ error: 'Season not found' });
        return;
      }
      
      res.json({
        success: true,
        data: season
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


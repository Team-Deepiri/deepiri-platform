import { Request, Response } from 'express';
import mongoose, { Types } from 'mongoose';
import { createLogger } from '@deepiri/shared-utils';
import Boost, { IBoost, BoostType } from '../models/Boost';

const logger = createLogger('boost-service');

const BOOST_DURATIONS: Record<BoostType, number> = {
  focus: 60,      // 60 minutes
  velocity: 30,   // 30 minutes
  clarity: 45,    // 45 minutes
  debug: 20,      // 20 minutes
  cleanup: 30     // 30 minutes
};

const BOOST_CREDIT_COSTS: Record<BoostType, number> = {
  focus: 5,
  velocity: 3,
  clarity: 4,
  debug: 2,
  cleanup: 3
};

class BoostService {
  /**
   * Get or create boost profile for a user
   */
  async getOrCreateProfile(userId: string): Promise<IBoost> {
    try {
      let profile = await Boost.findOne({ userId: new Types.ObjectId(userId) });
      
      if (!profile) {
        profile = new Boost({
          userId: new Types.ObjectId(userId),
          boostCredits: 0
        });
        await profile.save();
      }
      
      return profile;
    } catch (error: any) {
      logger.error('Error getting boost profile:', error);
      throw error;
    }
  }

  /**
   * Activate a boost
   */
  async activateBoost(
    userId: string,
    boostType: BoostType,
    source: 'purchased' | 'streak_reward' | 'momentum_reward' | 'season_reward' = 'purchased',
    duration?: number
  ): Promise<IBoost> {
    try {
      const profile = await this.getOrCreateProfile(userId);
      
      // Check if user has reached max concurrent boosts
      if (profile.activeBoosts.length >= profile.settings.maxConcurrentBoosts) {
        throw new Error('Maximum concurrent boosts reached');
      }
      
      // Check autopilot time limit
      const boostDuration = duration || BOOST_DURATIONS[boostType];
      if (profile.settings.autopilotTimeUsedToday + boostDuration > profile.settings.maxAutopilotTimePerDay) {
        throw new Error('Daily autopilot time limit reached');
      }
      
      // Check if user has enough credits (if purchasing)
      if (source === 'purchased') {
        const cost = BOOST_CREDIT_COSTS[boostType];
        if (profile.boostCredits < cost) {
          throw new Error('Insufficient boost credits');
        }
        profile.boostCredits -= cost;
      }
      
      // Activate boost
      const now = new Date();
      const expiresAt = new Date(now.getTime() + boostDuration * 60 * 1000);
      
      profile.activeBoosts.push({
        boostType,
        activatedAt: now,
        expiresAt,
        duration: boostDuration,
        metadata: { source }
      });
      
      // Update autopilot time
      profile.settings.autopilotTimeUsedToday += boostDuration;
      
      await profile.save();
      
      logger.info(`Boost activated: ${boostType} for user ${userId}`);
      
      return profile;
    } catch (error: any) {
      logger.error('Error activating boost:', error);
      throw error;
    }
  }

  /**
   * Get active boosts for a user
   */
  async getActiveBoosts(userId: string): Promise<IBoost['activeBoosts']> {
    try {
      const profile = await this.getOrCreateProfile(userId);
      
      // Remove expired boosts (handled in pre-save, but check here too)
      const now = new Date();
      return profile.activeBoosts.filter(boost => boost.expiresAt > now);
    } catch (error: any) {
      logger.error('Error getting active boosts:', error);
      throw error;
    }
  }

  /**
   * Add boost credits
   */
  async addCredits(userId: string, amount: number): Promise<IBoost> {
    try {
      const profile = await this.getOrCreateProfile(userId);
      profile.boostCredits += amount;
      await profile.save();
      return profile;
    } catch (error: any) {
      logger.error('Error adding boost credits:', error);
      throw error;
    }
  }

  /**
   * Activate boost endpoint
   */
  async activate(req: Request, res: Response): Promise<void> {
    try {
      const { userId, boostType, source, duration } = req.body;
      
      if (!userId || !boostType) {
        res.status(400).json({ error: 'userId and boostType are required' });
        return;
      }
      
      const validTypes: BoostType[] = ['focus', 'velocity', 'clarity', 'debug', 'cleanup'];
      if (!validTypes.includes(boostType)) {
        res.status(400).json({ error: `Invalid boostType. Must be one of: ${validTypes.join(', ')}` });
        return;
      }
      
      const profile = await this.activateBoost(
        userId,
        boostType,
        source || 'purchased',
        duration
      );
      
      res.json({
        success: true,
        data: {
          activeBoosts: profile.activeBoosts,
          boostCredits: profile.boostCredits,
          autopilotTimeRemaining: profile.settings.maxAutopilotTimePerDay - profile.settings.autopilotTimeUsedToday
        }
      });
    } catch (error: any) {
      logger.error('Error activating boost:', error);
      res.status(400).json({ error: error.message || 'Failed to activate boost' });
    }
  }

  /**
   * Get boost profile
   */
  async getProfile(req: Request, res: Response): Promise<void> {
    try {
      const { userId } = req.params;
      
      if (!userId) {
        res.status(400).json({ error: 'userId is required' });
        return;
      }
      
      const profile = await this.getOrCreateProfile(userId);
      
      res.json({
        success: true,
        data: {
          activeBoosts: profile.activeBoosts,
          boostCredits: profile.boostCredits,
          settings: profile.settings,
          autopilotTimeRemaining: profile.settings.maxAutopilotTimePerDay - profile.settings.autopilotTimeUsedToday
        }
      });
    } catch (error: any) {
      logger.error('Error getting boost profile:', error);
      res.status(500).json({ error: 'Failed to get boost profile' });
    }
  }

  /**
   * Add boost credits endpoint
   */
  async addCreditsEndpoint(req: Request, res: Response): Promise<void> {
    try {
      const { userId, amount } = req.body;
      
      if (!userId || !amount) {
        res.status(400).json({ error: 'userId and amount are required' });
        return;
      }
      
      const profile = await this.addCredits(userId, amount);
      
      res.json({
        success: true,
        data: {
          boostCredits: profile.boostCredits
        }
      });
    } catch (error: any) {
      logger.error('Error adding boost credits:', error);
      res.status(500).json({ error: 'Failed to add boost credits' });
    }
  }

  /**
   * Get boost costs
   */
  async getCosts(req: Request, res: Response): Promise<void> {
    try {
      res.json({
        success: true,
        data: {
          costs: BOOST_CREDIT_COSTS,
          durations: BOOST_DURATIONS
        }
      });
    } catch (error: any) {
      logger.error('Error getting boost costs:', error);
      res.status(500).json({ error: 'Failed to get boost costs' });
    }
  }
}

export default new BoostService();


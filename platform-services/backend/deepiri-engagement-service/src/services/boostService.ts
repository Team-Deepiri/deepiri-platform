import { Request, Response } from 'express';
import { createLogger } from '@deepiri/shared-utils';
import prisma from '../db';

const logger = createLogger('boost-service');

type BoostType = 'focus' | 'velocity' | 'clarity' | 'debug' | 'cleanup';

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
  async getOrCreateProfile(userId: string) {
    try {
      let profile = await prisma.boost.findUnique({
        where: { userId },
        include: {
          activeBoosts: true,
          boostHistory: { orderBy: { activatedAt: 'desc' }, take: 50 }
        }
      });
      
      if (!profile) {
        profile = await prisma.boost.create({
          data: {
            userId,
            boostCredits: 0,
            maxConcurrentBoosts: 3,
            maxAutopilotTimePerDay: 0,
            autopilotTimeUsedToday: 0,
            lastAutopilotReset: new Date()
          },
          include: {
            activeBoosts: true,
            boostHistory: true
          }
        });
      }
      
      // Reset autopilot time if it's a new day
      const now = new Date();
      const lastReset = profile.lastAutopilotReset;
      if (lastReset) {
        const daysDiff = Math.floor((now.getTime() - lastReset.getTime()) / (1000 * 60 * 60 * 24));
        if (daysDiff >= 1) {
          profile = await prisma.boost.update({
            where: { userId },
            data: {
              autopilotTimeUsedToday: 0,
              lastAutopilotReset: now
            },
            include: {
              activeBoosts: true,
              boostHistory: { orderBy: { activatedAt: 'desc' }, take: 50 }
            }
          });
        }
      }
      
      // Remove expired boosts
      const nowTime = now.getTime();
      const activeBoosts = profile.activeBoosts || [];
      const expiredBoosts = activeBoosts.filter((boost) => 
        new Date(boost.expiresAt).getTime() <= nowTime
      );
      
      if (expiredBoosts.length > 0) {
        // Move expired boosts to history
        for (const boost of expiredBoosts) {
          await prisma.boostHistory.create({
            data: {
              boostId: profile.id,
              boostType: boost.boostType,
              activatedAt: boost.activatedAt,
              expiredAt: new Date(boost.expiresAt),
              durationMinutes: boost.durationMinutes,
              creditsUsed: 0,
              source: 'purchased'
            }
          });
        }
        
        // Delete expired active boosts
        await prisma.activeBoost.deleteMany({
          where: {
            id: { in: expiredBoosts.map((b) => b.id) }
          }
        });
        
        // Refresh profile
        profile = await prisma.boost.findUnique({
          where: { userId },
          include: {
            activeBoosts: true,
            boostHistory: { orderBy: { activatedAt: 'desc' }, take: 50 }
          }
        })!;
      }
      
      return profile!;
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
  ) {
    try {
      const profile = await this.getOrCreateProfile(userId);
      
      // Check if user has reached max concurrent boosts
      if (profile.activeBoosts.length >= profile.maxConcurrentBoosts) {
        throw new Error('Maximum concurrent boosts reached');
      }
      
      // Check autopilot time limit
      const boostDuration = duration || BOOST_DURATIONS[boostType];
      if (profile.autopilotTimeUsedToday + boostDuration > profile.maxAutopilotTimePerDay) {
        throw new Error('Daily autopilot time limit reached');
      }
      
      // Check if user has enough credits (if purchasing)
      let newCredits = profile.boostCredits;
      if (source === 'purchased') {
        const cost = BOOST_CREDIT_COSTS[boostType];
        if (profile.boostCredits < cost) {
          throw new Error('Insufficient boost credits');
        }
        newCredits = profile.boostCredits - cost;
      }
      
      // Activate boost
      const now = new Date();
      const expiresAt = new Date(now.getTime() + boostDuration * 60 * 1000);
      
      const activeBoost = await prisma.activeBoost.create({
        data: {
          boostId: profile.id,
          boostType,
          expiresAt,
          durationMinutes: boostDuration,
          multiplier: 1.0
        }
      });
      
      // Update boost profile
      const updated = await prisma.boost.update({
        where: { userId },
        data: {
          boostCredits: newCredits,
          autopilotTimeUsedToday: profile.autopilotTimeUsedToday + boostDuration
        },
        include: {
          activeBoosts: true,
          boostHistory: { orderBy: { activatedAt: 'desc' }, take: 50 }
        }
      });
      
      logger.info(`Boost activated: ${boostType} for user ${userId}`);
      
      return updated;
    } catch (error: any) {
      logger.error('Error activating boost:', error);
      throw error;
    }
  }

  /**
   * Get active boosts for a user
   */
  async getActiveBoosts(userId: string) {
    try {
      const profile = await this.getOrCreateProfile(userId);
      const now = new Date();
      return profile.activeBoosts.filter((boost) => new Date(boost.expiresAt) > now);
    } catch (error: any) {
      logger.error('Error getting active boosts:', error);
      throw error;
    }
  }

  /**
   * Add boost credits
   */
  async addCredits(userId: string, amount: number) {
    try {
      const profile = await this.getOrCreateProfile(userId);
      const updated = await prisma.boost.update({
        where: { userId },
        data: {
          boostCredits: { increment: amount }
        }
      });
      return updated;
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
          activeBoosts: profile.activeBoosts.map((ab) => ({
            boostType: ab.boostType,
            activatedAt: ab.activatedAt,
            expiresAt: ab.expiresAt,
            duration: ab.durationMinutes,
            metadata: ab.metadata
          })),
          boostCredits: profile.boostCredits,
          autopilotTimeRemaining: profile.maxAutopilotTimePerDay - profile.autopilotTimeUsedToday
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
          activeBoosts: profile.activeBoosts.map((ab) => ({
            boostType: ab.boostType,
            activatedAt: ab.activatedAt,
            expiresAt: ab.expiresAt,
            duration: ab.durationMinutes,
            metadata: ab.metadata
          })),
          boostCredits: profile.boostCredits,
          settings: {
            maxConcurrentBoosts: profile.maxConcurrentBoosts,
            maxAutopilotTimePerDay: profile.maxAutopilotTimePerDay,
            autopilotTimeUsedToday: profile.autopilotTimeUsedToday,
            lastAutopilotReset: profile.lastAutopilotReset
          },
          autopilotTimeRemaining: profile.maxAutopilotTimePerDay - profile.autopilotTimeUsedToday
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

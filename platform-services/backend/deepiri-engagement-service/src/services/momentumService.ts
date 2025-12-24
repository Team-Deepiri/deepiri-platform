import { Request, Response } from 'express';
import { createLogger } from '@deepiri/shared-utils';
import prisma from '../db';

const logger = createLogger('momentum-service');

type MomentumSource = 
  | 'commits' 
  | 'docs' 
  | 'tasks' 
  | 'reviews' 
  | 'comments' 
  | 'attendance' 
  | 'featuresShipped' 
  | 'designEdits';

class MomentumService {
  /**
   * Get or create momentum profile for a user
   */
  async getOrCreateProfile(userId: string) {
    try {
      let profile = await prisma.momentum.findUnique({
        where: { userId },
        include: {
          levelProgress: { orderBy: { reachedAt: 'desc' }, take: 10 },
          achievements: { orderBy: { unlockedAt: 'desc' } }
        }
      });
      
      if (!profile) {
        profile = await prisma.momentum.create({
          data: {
            userId,
            totalMomentum: 0,
            currentLevel: 1,
            momentumToNextLevel: 100,
            commits: 0,
            docs: 0,
            tasks: 0,
            reviews: 0,
            comments: 0,
            attendance: 0,
            featuresShipped: 0,
            designEdits: 0
          },
          include: {
            levelProgress: true,
            achievements: true
          }
        });
      }
      
      return profile;
    } catch (error: any) {
      logger.error('Error getting momentum profile:', error);
      throw error;
    }
  }

  /**
   * Calculate momentum to next level
   */
  private calculateMomentumToNextLevel(level: number): number {
    const baseMomentum = 100;
    const growthFactor = 1.5;
    return Math.floor(baseMomentum * Math.pow(growthFactor, level - 1));
  }

  /**
   * Award momentum to a user
   */
  async awardMomentum(
    userId: string, 
    amount: number, 
    source: MomentumSource,
    metadata?: Record<string, any>
  ) {
    try {
      const profile = await this.getOrCreateProfile(userId);
      
      // Map source to field name
      const sourceFieldMap: Record<MomentumSource, string> = {
        commits: 'commits',
        docs: 'docs',
        tasks: 'tasks',
        reviews: 'reviews',
        comments: 'comments',
        attendance: 'attendance',
        featuresShipped: 'featuresShipped',
        designEdits: 'designEdits'
      };

      const fieldName = sourceFieldMap[source];
      const previousLevel = profile.currentLevel;
      const newTotalMomentum = profile.totalMomentum + amount;
      const newMomentumToNextLevel = this.calculateMomentumToNextLevel(profile.currentLevel);
      
      // Check for level up
      let newLevel = profile.currentLevel;
      if (newTotalMomentum >= newMomentumToNextLevel) {
        newLevel = profile.currentLevel + 1;
      }

      // Update momentum
      const updated = await prisma.momentum.update({
        where: { userId },
        data: {
          totalMomentum: { increment: amount },
          [fieldName]: { increment: amount },
          currentLevel: newLevel,
          momentumToNextLevel: this.calculateMomentumToNextLevel(newLevel),
          metadata: metadata ? { ...(profile.metadata as any || {}), ...metadata } : profile.metadata
        },
        include: {
          levelProgress: { orderBy: { reachedAt: 'desc' }, take: 10 },
          achievements: { orderBy: { unlockedAt: 'desc' } }
        }
      });

      // Record level up if it occurred
      if (newLevel > previousLevel) {
        await prisma.levelProgress.create({
          data: {
            momentumId: updated.id,
            level: newLevel,
            totalMomentumAtTime: newTotalMomentum
          }
        });

        logger.info(`User ${userId} leveled up to level ${newLevel}`);
        
        // Emit level up event via realtime gateway
        try {
          const axios = (await import('axios')).default;
          const REALTIME_GATEWAY_URL = process.env.REALTIME_GATEWAY_URL || 'http://realtime-gateway:5008';
          await axios.post(`${REALTIME_GATEWAY_URL}/emit/gamification`, {
            userId,
            type: 'level_up',
            data: {
              newLevel,
              totalMomentum: newTotalMomentum
            }
          });
        } catch (error: any) {
          logger.error('Failed to emit level up event:', error.message);
        }
      }
      
      // Emit momentum awarded event
      try {
        const axios = (await import('axios')).default;
        const REALTIME_GATEWAY_URL = process.env.REALTIME_GATEWAY_URL || 'http://realtime-gateway:5008';
        await axios.post(`${REALTIME_GATEWAY_URL}/emit/gamification`, {
          userId,
          type: 'momentum_awarded',
          data: {
            amount,
            source,
            newTotal: newTotalMomentum,
            currentLevel: newLevel
          }
        });
      } catch (error: any) {
        logger.error('Failed to emit momentum event:', error.message);
      }
      
      return updated;
    } catch (error: any) {
      logger.error('Error awarding momentum:', error);
      throw error;
    }
  }

  /**
   * Get user momentum profile
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
          totalMomentum: profile.totalMomentum,
          currentLevel: profile.currentLevel,
          momentumToNextLevel: profile.momentumToNextLevel,
          skillMastery: {
            commits: profile.commits,
            docs: profile.docs,
            tasks: profile.tasks,
            reviews: profile.reviews,
            comments: profile.comments,
            attendance: profile.attendance,
            featuresShipped: profile.featuresShipped,
            designEdits: profile.designEdits
          },
          levelHistory: profile.levelProgress.map((lp: typeof profile.levelProgress[0]) => ({
            level: lp.level,
            reachedAt: lp.reachedAt,
            totalMomentum: lp.totalMomentumAtTime
          })),
          achievements: profile.achievements.map((a: typeof profile.achievements[0]) => ({
            achievementId: a.achievementId,
            name: a.name,
            description: a.description,
            unlockedAt: a.unlockedAt,
            showcaseable: a.showcaseable
          })),
          publicProfile: {
            displayMomentum: profile.displayMomentum,
            showcaseAchievements: profile.showcaseAchievements
          }
        }
      });
    } catch (error: any) {
      logger.error('Error getting profile:', error);
      res.status(500).json({ error: 'Failed to get momentum profile' });
    }
  }

  /**
   * Award momentum (POST endpoint)
   */
  async award(req: Request, res: Response): Promise<void> {
    try {
      const { userId, amount, source, metadata } = req.body;
      
      if (!userId || !amount || !source) {
        res.status(400).json({ error: 'userId, amount, and source are required' });
        return;
      }
      
      const validSources: MomentumSource[] = [
        'commits', 'docs', 'tasks', 'reviews', 
        'comments', 'attendance', 'featuresShipped', 'designEdits'
      ];
      
      if (!validSources.includes(source)) {
        res.status(400).json({ error: `Invalid source. Must be one of: ${validSources.join(', ')}` });
        return;
      }
      
      const profile = await this.awardMomentum(userId, amount, source, metadata);
      
      res.json({
        success: true,
        data: {
          totalMomentum: profile.totalMomentum,
          currentLevel: profile.currentLevel,
          momentumToNextLevel: profile.momentumToNextLevel,
          skillMastery: {
            commits: profile.commits,
            docs: profile.docs,
            tasks: profile.tasks,
            reviews: profile.reviews,
            comments: profile.comments,
            attendance: profile.attendance,
            featuresShipped: profile.featuresShipped,
            designEdits: profile.designEdits
          }
        }
      });
    } catch (error: any) {
      logger.error('Error awarding momentum:', error);
      res.status(500).json({ error: 'Failed to award momentum' });
    }
  }

  /**
   * Get leaderboard/ranking
   */
  async getRanking(req: Request, res: Response): Promise<void> {
    try {
      const { limit = 100, sortBy = 'totalMomentum' } = req.query;
      
      const orderBy = sortBy === 'level' 
        ? { currentLevel: 'desc' as const }
        : { totalMomentum: 'desc' as const };
      
      const profiles = await prisma.momentum.findMany({
        orderBy,
        take: parseInt(limit as string),
        select: {
          userId: true,
          totalMomentum: true,
          currentLevel: true,
          commits: true,
          docs: true,
          tasks: true,
          reviews: true,
          comments: true,
          attendance: true,
          featuresShipped: true,
          designEdits: true
        }
      });
      
      res.json({
        success: true,
        data: profiles.map((profile: typeof profiles[0], index: number) => ({
          rank: index + 1,
          userId: profile.userId,
          totalMomentum: profile.totalMomentum,
          currentLevel: profile.currentLevel,
          skillMastery: {
            commits: profile.commits,
            docs: profile.docs,
            tasks: profile.tasks,
            reviews: profile.reviews,
            comments: profile.comments,
            attendance: profile.attendance,
            featuresShipped: profile.featuresShipped,
            designEdits: profile.designEdits
          }
        }))
      });
    } catch (error: any) {
      logger.error('Error getting ranking:', error);
      res.status(500).json({ error: 'Failed to get ranking' });
    }
  }

  /**
   * Get user's rank
   */
  async getUserRank(req: Request, res: Response): Promise<void> {
    try {
      const { userId } = req.params;
      
      if (!userId) {
        res.status(400).json({ error: 'userId is required' });
        return;
      }
      
      const profile = await this.getOrCreateProfile(userId);
      
      // Count users with higher momentum
      const rank = await prisma.momentum.count({
        where: {
          OR: [
            { totalMomentum: { gt: profile.totalMomentum } },
            { 
              totalMomentum: profile.totalMomentum,
              userId: { lt: userId }
            }
          ]
        }
      }) + 1;
      
      res.json({
        success: true,
        data: {
          rank,
          totalMomentum: profile.totalMomentum,
          currentLevel: profile.currentLevel
        }
      });
    } catch (error: any) {
      logger.error('Error getting user rank:', error);
      res.status(500).json({ error: 'Failed to get user rank' });
    }
  }
}

export default new MomentumService();

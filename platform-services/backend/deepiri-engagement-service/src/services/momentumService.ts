import { Request, Response } from 'express';
import mongoose, { Types } from 'mongoose';
import { createLogger } from '@deepiri/shared-utils';
import Momentum, { IMomentum } from '../models/Momentum';

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
  async getOrCreateProfile(userId: string): Promise<IMomentum> {
    try {
      let profile = await Momentum.findOne({ userId: new Types.ObjectId(userId) });
      
      if (!profile) {
        profile = new Momentum({
          userId: new Types.ObjectId(userId),
          totalMomentum: 0,
          currentLevel: 1,
          momentumToNextLevel: 100
        });
        await profile.save();
      }
      
      return profile;
    } catch (error: any) {
      logger.error('Error getting momentum profile:', error);
      throw error;
    }
  }

  /**
   * Award momentum to a user
   */
  async awardMomentum(
    userId: string, 
    amount: number, 
    source: MomentumSource,
    metadata?: Record<string, any>
  ): Promise<IMomentum> {
    try {
      const profile = await this.getOrCreateProfile(userId);
      
      // Add to total momentum
      profile.totalMomentum += amount;
      
      // Add to specific skill mastery
      if (profile.skillMastery[source] !== undefined) {
        profile.skillMastery[source] += amount;
      }
      
      // Check for level up (handled in pre-save hook)
      const previousLevel = profile.currentLevel;
      await profile.save();
      
      if (profile.currentLevel > previousLevel) {
        logger.info(`User ${userId} leveled up to level ${profile.currentLevel}`);
        
        // Emit level up event via realtime gateway
        try {
          const axios = (await import('axios')).default;
          const REALTIME_GATEWAY_URL = process.env.REALTIME_GATEWAY_URL || 'http://realtime-gateway:5008';
          await axios.post(`${REALTIME_GATEWAY_URL}/emit/gamification`, {
            userId,
            type: 'level_up',
            data: {
              newLevel: profile.currentLevel,
              totalMomentum: profile.totalMomentum
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
            newTotal: profile.totalMomentum,
            currentLevel: profile.currentLevel
          }
        });
      } catch (error: any) {
        logger.error('Failed to emit momentum event:', error.message);
      }
      
      return profile;
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
          skillMastery: profile.skillMastery,
          levelHistory: profile.levelHistory,
          achievements: profile.achievements,
          publicProfile: profile.publicProfile
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
          skillMastery: profile.skillMastery
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
      
      const sortField = sortBy === 'level' ? 'currentLevel' : 'totalMomentum';
      
      const profiles = await Momentum.find()
        .sort({ [sortField]: -1 })
        .limit(parseInt(limit as string))
        .select('userId totalMomentum currentLevel skillMastery')
        .lean();
      
      res.json({
        success: true,
        data: profiles.map((profile, index) => ({
          rank: index + 1,
          userId: profile.userId,
          totalMomentum: profile.totalMomentum,
          currentLevel: profile.currentLevel,
          skillMastery: profile.skillMastery
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
      const rank = await Momentum.countDocuments({
        $or: [
          { totalMomentum: { $gt: profile.totalMomentum } },
          { 
            totalMomentum: profile.totalMomentum,
            _id: { $lt: profile._id }
          }
        ]
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


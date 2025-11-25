import { Request, Response } from 'express';
import mongoose, { Types } from 'mongoose';
import { createLogger } from '@deepiri/shared-utils';
import Streak, { IStreak } from '../models/Streak';

const logger = createLogger('streak-service');

type StreakType = 'daily' | 'weekly' | 'project' | 'pr' | 'healthy';

class StreakService {
  /**
   * Get or create streak profile for a user
   */
  async getOrCreateProfile(userId: string): Promise<IStreak> {
    try {
      let profile = await Streak.findOne({ userId: new Types.ObjectId(userId) });
      
      if (!profile) {
        profile = new Streak({
          userId: new Types.ObjectId(userId)
        });
        await profile.save();
      }
      
      return profile;
    } catch (error: any) {
      logger.error('Error getting streak profile:', error);
      throw error;
    }
  }

  /**
   * Update daily streak
   */
  async updateDailyStreak(userId: string): Promise<IStreak> {
    try {
      const profile = await this.getOrCreateProfile(userId);
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      
      const lastDate = profile.daily.lastDate 
        ? new Date(profile.daily.lastDate)
        : null;
      
      if (lastDate) {
        lastDate.setHours(0, 0, 0, 0);
        const daysDiff = Math.floor((today.getTime() - lastDate.getTime()) / (1000 * 60 * 60 * 24));
        
        if (daysDiff === 1) {
          // Consecutive day
          profile.daily.current += 1;
        } else if (daysDiff > 1) {
          // Streak broken
          profile.daily.current = 1;
        }
        // If daysDiff === 0, same day, don't update
      } else {
        // First time
        profile.daily.current = 1;
      }
      
      if (profile.daily.current > profile.daily.longest) {
        profile.daily.longest = profile.daily.current;
      }
      
      profile.daily.lastDate = today;
      await profile.save();
      
      return profile;
    } catch (error: any) {
      logger.error('Error updating daily streak:', error);
      throw error;
    }
  }

  /**
   * Update weekly streak
   */
  async updateWeeklyStreak(userId: string): Promise<IStreak> {
    try {
      const profile = await this.getOrCreateProfile(userId);
      const now = new Date();
      const weekStart = new Date(now);
      weekStart.setDate(now.getDate() - now.getDay());
      weekStart.setHours(0, 0, 0, 0);
      const weekKey = `${weekStart.getFullYear()}-W${this.getWeekNumber(weekStart)}`;
      
      if (profile.weekly.lastWeek !== weekKey) {
        const lastWeek = profile.weekly.lastWeek;
        
        if (lastWeek) {
          // Check if consecutive week
          const lastWeekDate = this.parseWeekKey(lastWeek);
          const weeksDiff = Math.floor((weekStart.getTime() - lastWeekDate.getTime()) / (1000 * 60 * 60 * 24 * 7));
          
          if (weeksDiff === 1) {
            profile.weekly.current += 1;
          } else if (weeksDiff > 1) {
            profile.weekly.current = 1;
          }
        } else {
          profile.weekly.current = 1;
        }
        
        if (profile.weekly.current > profile.weekly.longest) {
          profile.weekly.longest = profile.weekly.current;
        }
        
        profile.weekly.lastWeek = weekKey;
        await profile.save();
      }
      
      return profile;
    } catch (error: any) {
      logger.error('Error updating weekly streak:', error);
      throw error;
    }
  }

  /**
   * Update project streak
   */
  async updateProjectStreak(userId: string, projectId: string): Promise<IStreak> {
    try {
      const profile = await this.getOrCreateProfile(userId);
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      
      if (profile.project.projectId === projectId) {
        // Same project, check if consecutive day
        const lastDate = profile.project.lastProjectDate 
          ? new Date(profile.project.lastProjectDate)
          : null;
        
        if (lastDate) {
          lastDate.setHours(0, 0, 0, 0);
          const daysDiff = Math.floor((today.getTime() - lastDate.getTime()) / (1000 * 60 * 60 * 24));
          
          if (daysDiff === 1) {
            profile.project.current += 1;
          } else if (daysDiff > 1) {
            profile.project.current = 1;
          }
        } else {
          profile.project.current = 1;
        }
      } else {
        // Different project, reset or continue based on date
        profile.project.current = 1;
        profile.project.projectId = projectId;
      }
      
      if (profile.project.current > profile.project.longest) {
        profile.project.longest = profile.project.current;
      }
      
      profile.project.lastProjectDate = today;
      await profile.save();
      
      return profile;
    } catch (error: any) {
      logger.error('Error updating project streak:', error);
      throw error;
    }
  }

  /**
   * Update PR streak
   */
  async updatePRStreak(userId: string): Promise<IStreak> {
    try {
      const profile = await this.getOrCreateProfile(userId);
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      
      const lastDate = profile.pr.lastPRDate 
        ? new Date(profile.pr.lastPRDate)
        : null;
      
      if (lastDate) {
        lastDate.setHours(0, 0, 0, 0);
        const daysDiff = Math.floor((today.getTime() - lastDate.getTime()) / (1000 * 60 * 60 * 24));
        
        if (daysDiff === 1) {
          profile.pr.current += 1;
        } else if (daysDiff > 1) {
          profile.pr.current = 1;
        }
      } else {
        profile.pr.current = 1;
      }
      
      if (profile.pr.current > profile.pr.longest) {
        profile.pr.longest = profile.pr.current;
      }
      
      profile.pr.lastPRDate = today;
      await profile.save();
      
      return profile;
    } catch (error: any) {
      logger.error('Error updating PR streak:', error);
      throw error;
    }
  }

  /**
   * Update healthy streak (no burnout)
   */
  async updateHealthyStreak(userId: string, isHealthy: boolean = true): Promise<IStreak> {
    try {
      const profile = await this.getOrCreateProfile(userId);
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      
      if (isHealthy) {
        const lastDate = profile.healthy.lastHealthyDate 
          ? new Date(profile.healthy.lastHealthyDate)
          : null;
        
        if (lastDate) {
          lastDate.setHours(0, 0, 0, 0);
          const daysDiff = Math.floor((today.getTime() - lastDate.getTime()) / (1000 * 60 * 60 * 24));
          
          if (daysDiff === 1) {
            profile.healthy.current += 1;
            profile.healthy.consecutiveDaysWithoutBurnout += 1;
          } else if (daysDiff > 1) {
            profile.healthy.current = 1;
            profile.healthy.consecutiveDaysWithoutBurnout = 1;
          }
        } else {
          profile.healthy.current = 1;
          profile.healthy.consecutiveDaysWithoutBurnout = 1;
        }
        
        if (profile.healthy.current > profile.healthy.longest) {
          profile.healthy.longest = profile.healthy.current;
        }
        
        profile.healthy.lastHealthyDate = today;
      } else {
        // Burnout detected, reset streak
        profile.healthy.current = 0;
        profile.healthy.consecutiveDaysWithoutBurnout = 0;
      }
      
      await profile.save();
      
      return profile;
    } catch (error: any) {
      logger.error('Error updating healthy streak:', error);
      throw error;
    }
  }

  /**
   * Cash in a streak for boost credits
   */
  async cashInStreak(req: Request, res: Response): Promise<void> {
    try {
      const { userId, streakType } = req.body;
      
      if (!userId || !streakType) {
        res.status(400).json({ error: 'userId and streakType are required' });
        return;
      }
      
      const validTypes: StreakType[] = ['daily', 'weekly', 'project', 'pr', 'healthy'];
      if (!validTypes.includes(streakType)) {
        res.status(400).json({ error: `Invalid streakType. Must be one of: ${validTypes.join(', ')}` });
        return;
      }
      
      const profile = await this.getOrCreateProfile(userId);
      const streakData = (profile as any)[streakType] as IStreak['daily'];
      
      if (!streakData.canCashIn) {
        res.status(400).json({ error: 'This streak cannot be cashed in yet' });
        return;
      }
      
      // Calculate boost credits (1 credit per day/week of streak)
      const boostCredits = streakData.current;
      
      // Record the cash-in
      profile.cashedInStreaks.push({
        streakType,
        cashedAt: new Date(),
        streakValue: streakData.current,
        boostCreditsEarned: boostCredits
      });
      
      // Reset the streak
      streakData.current = 0;
      streakData.canCashIn = false;
      
      await profile.save();
      
      res.json({
        success: true,
        data: {
          boostCreditsEarned: boostCredits,
          streakType,
          streakValue: streakData.current
        }
      });
    } catch (error: any) {
      logger.error('Error cashing in streak:', error);
      res.status(500).json({ error: 'Failed to cash in streak' });
    }
  }

  /**
   * Get user streaks
   */
  async getStreaks(req: Request, res: Response): Promise<void> {
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
          daily: profile.daily,
          weekly: profile.weekly,
          project: profile.project,
          pr: profile.pr,
          healthy: profile.healthy,
          cashedInStreaks: profile.cashedInStreaks
        }
      });
    } catch (error: any) {
      logger.error('Error getting streaks:', error);
      res.status(500).json({ error: 'Failed to get streaks' });
    }
  }

  /**
   * Update streak (generic endpoint)
   */
  async updateStreak(req: Request, res: Response): Promise<void> {
    try {
      const { userId, streakType, projectId, isHealthy } = req.body;
      
      if (!userId || !streakType) {
        res.status(400).json({ error: 'userId and streakType are required' });
        return;
      }
      
      let profile: IStreak;
      
      switch (streakType) {
        case 'daily':
          profile = await this.updateDailyStreak(userId);
          break;
        case 'weekly':
          profile = await this.updateWeeklyStreak(userId);
          break;
        case 'project':
          if (!projectId) {
            res.status(400).json({ error: 'projectId is required for project streak' });
            return;
          }
          profile = await this.updateProjectStreak(userId, projectId);
          break;
        case 'pr':
          profile = await this.updatePRStreak(userId);
          break;
        case 'healthy':
          profile = await this.updateHealthyStreak(userId, isHealthy !== false);
          break;
        default:
          res.status(400).json({ error: 'Invalid streakType' });
          return;
      }
      
      res.json({
        success: true,
        data: (profile as any)[streakType]
      });
    } catch (error: any) {
      logger.error('Error updating streak:', error);
      res.status(500).json({ error: 'Failed to update streak' });
    }
  }

  // Helper methods
  private getWeekNumber(date: Date): number {
    const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
    const dayNum = d.getUTCDay() || 7;
    d.setUTCDate(d.getUTCDate() + 4 - dayNum);
    const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
    return Math.ceil((((d.getTime() - yearStart.getTime()) / 86400000) + 1) / 7);
  }

  private parseWeekKey(weekKey: string): Date {
    const [year, week] = weekKey.split('-W').map(Number);
    const date = new Date(year, 0, 1 + (week - 1) * 7);
    return date;
  }
}

export default new StreakService();


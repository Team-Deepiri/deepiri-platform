import { Request, Response } from 'express';
import { createLogger } from '@deepiri/shared-utils';
import prisma from '../db';

const logger = createLogger('streak-service');

type StreakType = 'daily' | 'weekly' | 'project' | 'pr' | 'healthy';

class StreakService {
  /**
   * Get or create streak profile for a user
   */
  async getOrCreateProfile(userId: string) {
    try {
      let profile = await prisma.streak.findUnique({
        where: { userId },
        include: {
          cashedInStreaks: { orderBy: { cashedAt: 'desc' }, take: 20 }
        }
      });
      
      if (!profile) {
        profile = await prisma.streak.create({
          data: {
            userId,
            dailyCurrent: 0,
            dailyLongest: 0,
            weeklyCurrent: 0,
            weeklyLongest: 0,
            projectCurrent: 0,
            projectLongest: 0,
            prCurrent: 0,
            prLongest: 0,
            healthyCurrent: 0,
            healthyLongest: 0
          },
          include: {
            cashedInStreaks: true
          }
        });
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
  async updateDailyStreak(userId: string) {
    try {
      const profile = await this.getOrCreateProfile(userId);
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      
      const lastDate = profile.dailyLastDate 
        ? new Date(profile.dailyLastDate)
        : null;
      
      let newCurrent = profile.dailyCurrent;
      let newCanCashIn = profile.dailyCanCashIn;
      
      if (lastDate) {
        lastDate.setHours(0, 0, 0, 0);
        const daysDiff = Math.floor((today.getTime() - lastDate.getTime()) / (1000 * 60 * 60 * 24));
        
        if (daysDiff === 1) {
          // Consecutive day
          newCurrent = profile.dailyCurrent + 1;
        } else if (daysDiff > 1) {
          // Streak broken
          newCurrent = 1;
        }
        // If daysDiff === 0, same day, don't update
      } else {
        // First time
        newCurrent = 1;
      }
      
      const newLongest = newCurrent > profile.dailyLongest ? newCurrent : profile.dailyLongest;
      newCanCashIn = newCurrent >= 7;
      
      const updated = await prisma.streak.update({
        where: { userId },
        data: {
          dailyCurrent: newCurrent,
          dailyLongest: newLongest,
          dailyLastDate: today,
          dailyCanCashIn: newCanCashIn
        }
      });
      
      return updated;
    } catch (error: any) {
      logger.error('Error updating daily streak:', error);
      throw error;
    }
  }

  /**
   * Update weekly streak
   */
  async updateWeeklyStreak(userId: string) {
    try {
      const profile = await this.getOrCreateProfile(userId);
      const now = new Date();
      const weekStart = new Date(now);
      weekStart.setDate(now.getDate() - now.getDay());
      weekStart.setHours(0, 0, 0, 0);
      const weekNumber = this.getWeekNumber(weekStart);
      const weekKey = weekNumber;
      
      let newCurrent = profile.weeklyCurrent;
      let newLongest = profile.weeklyLongest;
      let newCanCashIn = profile.weeklyCanCashIn;
      
      if (profile.weeklyLastWeek !== weekKey) {
        const lastWeek = profile.weeklyLastWeek;
        
        if (lastWeek) {
          // Check if consecutive week
          const weeksDiff = weekKey - lastWeek;
          
          if (weeksDiff === 1) {
            newCurrent = profile.weeklyCurrent + 1;
          } else if (weeksDiff > 1) {
            newCurrent = 1;
          }
        } else {
          newCurrent = 1;
        }
        
        newLongest = newCurrent > profile.weeklyLongest ? newCurrent : profile.weeklyLongest;
        newCanCashIn = newCurrent >= 2;
      }
      
      const updated = await prisma.streak.update({
        where: { userId },
        data: {
          weeklyCurrent: newCurrent,
          weeklyLongest: newLongest,
          weeklyLastWeek: weekKey,
          weeklyCanCashIn: newCanCashIn
        }
      });
      
      return updated;
    } catch (error: any) {
      logger.error('Error updating weekly streak:', error);
      throw error;
    }
  }

  /**
   * Update project streak
   */
  async updateProjectStreak(userId: string, projectId: string) {
    try {
      const profile = await this.getOrCreateProfile(userId);
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      
      let newCurrent = profile.projectCurrent;
      let newLongest = profile.projectLongest;
      let newCanCashIn = profile.projectCanCashIn;
      
      if (profile.projectId === projectId) {
        // Same project, check if consecutive day
        const lastDate = profile.projectLastDate 
          ? new Date(profile.projectLastDate)
          : null;
        
        if (lastDate) {
          lastDate.setHours(0, 0, 0, 0);
          const daysDiff = Math.floor((today.getTime() - lastDate.getTime()) / (1000 * 60 * 60 * 24));
          
          if (daysDiff === 1) {
            newCurrent = profile.projectCurrent + 1;
          } else if (daysDiff > 1) {
            newCurrent = 1;
          }
        } else {
          newCurrent = 1;
        }
      } else {
        // Different project, reset
        newCurrent = 1;
      }
      
      newLongest = newCurrent > profile.projectLongest ? newCurrent : profile.projectLongest;
      newCanCashIn = newCurrent >= 3;
      
      const updated = await prisma.streak.update({
        where: { userId },
        data: {
          projectCurrent: newCurrent,
          projectLongest: newLongest,
          projectId,
          projectLastDate: today,
          projectCanCashIn: newCanCashIn
        }
      });
      
      return updated;
    } catch (error: any) {
      logger.error('Error updating project streak:', error);
      throw error;
    }
  }

  /**
   * Update PR streak
   */
  async updatePRStreak(userId: string) {
    try {
      const profile = await this.getOrCreateProfile(userId);
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      
      const lastDate = profile.prLastDate 
        ? new Date(profile.prLastDate)
        : null;
      
      let newCurrent = profile.prCurrent;
      
      if (lastDate) {
        lastDate.setHours(0, 0, 0, 0);
        const daysDiff = Math.floor((today.getTime() - lastDate.getTime()) / (1000 * 60 * 60 * 24));
        
        if (daysDiff === 1) {
          newCurrent = profile.prCurrent + 1;
        } else if (daysDiff > 1) {
          newCurrent = 1;
        }
      } else {
        newCurrent = 1;
      }
      
      const newLongest = newCurrent > profile.prLongest ? newCurrent : profile.prLongest;
      const newCanCashIn = newCurrent >= 5;
      
      const updated = await prisma.streak.update({
        where: { userId },
        data: {
          prCurrent: newCurrent,
          prLongest: newLongest,
          prLastDate: today,
          prCanCashIn: newCanCashIn
        }
      });
      
      return updated;
    } catch (error: any) {
      logger.error('Error updating PR streak:', error);
      throw error;
    }
  }

  /**
   * Update healthy streak (no burnout)
   */
  async updateHealthyStreak(userId: string, isHealthy: boolean = true) {
    try {
      const profile = await this.getOrCreateProfile(userId);
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      
      let newCurrent = profile.healthyCurrent;
      let newConsecutiveDays = profile.healthyConsecutiveDaysWithoutBurnout;
      
      if (isHealthy) {
        const lastDate = profile.healthyLastDate 
          ? new Date(profile.healthyLastDate)
          : null;
        
        if (lastDate) {
          lastDate.setHours(0, 0, 0, 0);
          const daysDiff = Math.floor((today.getTime() - lastDate.getTime()) / (1000 * 60 * 60 * 24));
          
          if (daysDiff === 1) {
            newCurrent = profile.healthyCurrent + 1;
            newConsecutiveDays = profile.healthyConsecutiveDaysWithoutBurnout + 1;
          } else if (daysDiff > 1) {
            newCurrent = 1;
            newConsecutiveDays = 1;
          }
        } else {
          newCurrent = 1;
          newConsecutiveDays = 1;
        }
      } else {
        // Burnout detected, reset streak
        newCurrent = 0;
        newConsecutiveDays = 0;
      }
      
      const newLongest = newCurrent > profile.healthyLongest ? newCurrent : profile.healthyLongest;
      const newCanCashIn = newCurrent >= 7;
      
      const updated = await prisma.streak.update({
        where: { userId },
        data: {
          healthyCurrent: newCurrent,
          healthyLongest: newLongest,
          healthyLastDate: isHealthy ? today : profile.healthyLastDate,
          healthyCanCashIn: newCanCashIn,
          healthyConsecutiveDaysWithoutBurnout: newConsecutiveDays
        }
      });
      
      return updated;
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
      if (!validTypes.includes(streakType as StreakType)) {
        res.status(400).json({ error: `Invalid streakType. Must be one of: ${validTypes.join(', ')}` });
        return;
      }
      
      const profile = await this.getOrCreateProfile(userId);
      
      // Get streak data based on type
      const streakFieldMap: Record<StreakType, { current: number; canCashIn: boolean }> = {
        daily: { current: profile.dailyCurrent, canCashIn: profile.dailyCanCashIn },
        weekly: { current: profile.weeklyCurrent, canCashIn: profile.weeklyCanCashIn },
        project: { current: profile.projectCurrent, canCashIn: profile.projectCanCashIn },
        pr: { current: profile.prCurrent, canCashIn: profile.prCanCashIn },
        healthy: { current: profile.healthyCurrent, canCashIn: profile.healthyCanCashIn }
      };
      
      const streakData = streakFieldMap[streakType as StreakType];
      
      if (!streakData.canCashIn) {
        res.status(400).json({ error: 'This streak cannot be cashed in yet' });
        return;
      }
      
      // Calculate boost credits (1 credit per day/week of streak)
      const boostCredits = streakData.current;
      
      // Record the cash-in
      await prisma.cashedInStreak.create({
        data: {
          streakId: profile.id,
          streakType,
          streakValue: streakData.current,
          boostCreditsEarned: boostCredits
        }
      });
      
      // Reset the streak and update canCashIn
      const updateData: any = {
        [`${streakType}Current`]: 0,
        [`${streakType}CanCashIn`]: false
      };
      
      await prisma.streak.update({
        where: { userId },
        data: updateData
      });
      
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
          daily: {
            current: profile.dailyCurrent,
            longest: profile.dailyLongest,
            lastDate: profile.dailyLastDate,
            canCashIn: profile.dailyCanCashIn
          },
          weekly: {
            current: profile.weeklyCurrent,
            longest: profile.weeklyLongest,
            lastWeek: profile.weeklyLastWeek,
            canCashIn: profile.weeklyCanCashIn
          },
          project: {
            current: profile.projectCurrent,
            longest: profile.projectLongest,
            projectId: profile.projectId,
            lastDate: profile.projectLastDate,
            canCashIn: profile.projectCanCashIn
          },
          pr: {
            current: profile.prCurrent,
            longest: profile.prLongest,
            lastDate: profile.prLastDate,
            canCashIn: profile.prCanCashIn
          },
          healthy: {
            current: profile.healthyCurrent,
            longest: profile.healthyLongest,
            lastDate: profile.healthyLastDate,
            canCashIn: profile.healthyCanCashIn,
            consecutiveDaysWithoutBurnout: profile.healthyConsecutiveDaysWithoutBurnout
          },
          cashedInStreaks: profile.cashedInStreaks.map((cis: typeof profile.cashedInStreaks[0]) => ({
            streakType: cis.streakType,
            cashedAt: cis.cashedAt,
            streakValue: cis.streakValue,
            boostCreditsEarned: cis.boostCreditsEarned
          }))
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
      
      let profile;
      
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
        data: {
          current: (profile as any)[`${streakType}Current`],
          longest: (profile as any)[`${streakType}Longest`],
          canCashIn: (profile as any)[`${streakType}CanCashIn`]
        }
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
}

export default new StreakService();

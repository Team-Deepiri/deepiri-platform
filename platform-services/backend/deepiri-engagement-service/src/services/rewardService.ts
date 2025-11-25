import { Request, Response } from 'express';
import mongoose, { Types } from 'mongoose';
import { createLogger } from '@deepiri/shared-utils';
import Reward, { IReward, RewardType } from '../models/Reward';
import boostService from './boostService';
import momentumService from './momentumService';

const logger = createLogger('reward-service');

class RewardService {
  /**
   * Create a reward
   */
  async createReward(
    userId: string,
    rewardType: RewardType,
    amount: number,
    source: 'streak' | 'momentum' | 'season' | 'achievement' | 'manual',
    description: string,
    sourceId?: string,
    expiresAt?: Date
  ): Promise<IReward> {
    try {
      const reward = new Reward({
        userId: new Types.ObjectId(userId),
        rewardType,
        amount,
        source,
        sourceId,
        description,
        status: 'pending',
        expiresAt
      });
      
      await reward.save();
      
      return reward;
    } catch (error: any) {
      logger.error('Error creating reward:', error);
      throw error;
    }
  }

  /**
   * Claim a reward
   */
  async claimReward(rewardId: string): Promise<IReward> {
    try {
      const reward = await Reward.findById(rewardId);
      
      if (!reward) {
        throw new Error('Reward not found');
      }
      
      if (reward.status !== 'pending') {
        throw new Error('Reward already claimed or expired');
      }
      
      if (reward.expiresAt && new Date() > reward.expiresAt) {
        reward.status = 'expired';
        await reward.save();
        throw new Error('Reward has expired');
      }
      
      // Apply the reward based on type
      switch (reward.rewardType) {
        case 'boost_credits':
          await boostService.addCredits(reward.userId.toString(), reward.amount);
          break;
        case 'momentum_bonus':
          await momentumService.awardMomentum(
            reward.userId.toString(),
            reward.amount,
            'tasks' // Default source
          );
          break;
        case 'skip_day':
        case 'break_time':
        case 'custom':
          // These would be handled by other services
          break;
      }
      
      reward.status = 'claimed';
      reward.claimedAt = new Date();
      await reward.save();
      
      return reward;
    } catch (error: any) {
      logger.error('Error claiming reward:', error);
      throw error;
    }
  }

  /**
   * Get rewards for a user
   */
  async getRewards(userId: string, status?: 'pending' | 'claimed' | 'expired'): Promise<IReward[]> {
    try {
      const query: any = { userId: new Types.ObjectId(userId) };
      
      if (status) {
        query.status = status;
      }
      
      const rewards = await Reward.find(query)
        .sort({ createdAt: -1 })
        .lean();
      
      return rewards as unknown as IReward[];
    } catch (error: any) {
      logger.error('Error getting rewards:', error);
      throw error;
    }
  }

  /**
   * Create reward endpoint
   */
  async create(req: Request, res: Response): Promise<void> {
    try {
      const { userId, rewardType, amount, source, description, sourceId, expiresAt } = req.body;
      
      if (!userId || !rewardType || !amount || !source || !description) {
        res.status(400).json({ error: 'userId, rewardType, amount, source, and description are required' });
        return;
      }
      
      const validTypes: RewardType[] = ['boost_credits', 'momentum_bonus', 'skip_day', 'break_time', 'custom'];
      if (!validTypes.includes(rewardType)) {
        res.status(400).json({ error: `Invalid rewardType. Must be one of: ${validTypes.join(', ')}` });
        return;
      }
      
      const reward = await this.createReward(
        userId,
        rewardType,
        amount,
        source,
        description,
        sourceId,
        expiresAt ? new Date(expiresAt) : undefined
      );
      
      res.json({
        success: true,
        data: reward
      });
    } catch (error: any) {
      logger.error('Error creating reward:', error);
      res.status(500).json({ error: 'Failed to create reward' });
    }
  }

  /**
   * Get rewards endpoint
   */
  async getRewardsEndpoint(req: Request, res: Response): Promise<void> {
    try {
      const { userId } = req.params;
      const { status } = req.query;
      
      if (!userId) {
        res.status(400).json({ error: 'userId is required' });
        return;
      }
      
      const rewards = await this.getRewards(
        userId,
        status as 'pending' | 'claimed' | 'expired' | undefined
      );
      
      res.json({
        success: true,
        data: rewards
      });
    } catch (error: any) {
      logger.error('Error getting rewards:', error);
      res.status(500).json({ error: 'Failed to get rewards' });
    }
  }

  /**
   * Claim reward endpoint
   */
  async claim(req: Request, res: Response): Promise<void> {
    try {
      const { id } = req.params;
      
      const reward = await this.claimReward(id);
      
      res.json({
        success: true,
        data: reward
      });
    } catch (error: any) {
      logger.error('Error claiming reward:', error);
      res.status(400).json({ error: error.message || 'Failed to claim reward' });
    }
  }

  /**
   * Get pending rewards count
   */
  async getPendingCount(req: Request, res: Response): Promise<void> {
    try {
      const { userId } = req.params;
      
      if (!userId) {
        res.status(400).json({ error: 'userId is required' });
        return;
      }
      
      const count = await Reward.countDocuments({
        userId: new Types.ObjectId(userId),
        status: 'pending',
        $or: [
          { expiresAt: { $exists: false } },
          { expiresAt: { $gt: new Date() } }
        ]
      });
      
      res.json({
        success: true,
        data: { count }
      });
    } catch (error: any) {
      logger.error('Error getting pending count:', error);
      res.status(500).json({ error: 'Failed to get pending count' });
    }
  }
}

export default new RewardService();


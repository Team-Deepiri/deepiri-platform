import { Request, Response } from 'express';
import { createLogger } from '@deepiri/shared-utils';
import prisma from '../db';
import { IReward, RewardType } from '../models/Reward';
import boostService from './boostService';
import momentumService from './momentumService';

const logger = createLogger('reward-service');

class RewardService {
  /**
   * Convert Prisma Reward to IReward
   */
  private rewardToInterface(reward: any): IReward {
    return {
      userId: reward.userId,
      rewardType: reward.rewardType as RewardType,
      amount: reward.amount,
      source: reward.source as 'streak' | 'momentum' | 'season' | 'achievement' | 'manual',
      sourceId: reward.sourceId || undefined,
      description: reward.description,
      status: reward.status as 'pending' | 'claimed' | 'expired',
      claimedAt: reward.claimedAt || undefined,
      expiresAt: reward.expiresAt || undefined,
      metadata: (reward.metadata as Record<string, any>) || undefined,
      createdAt: reward.createdAt,
      updatedAt: reward.updatedAt
    };
  }

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
      const reward = await prisma.reward.create({
        data: {
          userId,
          rewardType,
          amount,
          source,
          sourceId: sourceId || undefined,
          description,
          status: 'pending',
          expiresAt: expiresAt || undefined,
          metadata: {}
        }
      });
      
      return this.rewardToInterface(reward);
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
      const reward = await prisma.reward.findUnique({
        where: { id: rewardId }
      });
      
      if (!reward) {
        throw new Error('Reward not found');
      }
      
      if (reward.status !== 'pending') {
        throw new Error('Reward already claimed or expired');
      }
      
      if (reward.expiresAt && new Date() > reward.expiresAt) {
        await prisma.reward.update({
          where: { id: rewardId },
          data: { status: 'expired' }
        });
        throw new Error('Reward has expired');
      }
      
      // Apply the reward based on type
      switch (reward.rewardType) {
        case 'boost_credits':
          await boostService.addCredits(reward.userId, reward.amount);
          break;
        case 'momentum_bonus':
          await momentumService.awardMomentum(
            reward.userId,
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
      
      const updatedReward = await prisma.reward.update({
        where: { id: rewardId },
        data: {
          status: 'claimed',
          claimedAt: new Date()
        }
      });
      
      return this.rewardToInterface(updatedReward);
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
      const where: any = { userId };
      
      if (status) {
        where.status = status;
      }
      
      const rewards = await prisma.reward.findMany({
        where,
        orderBy: {
          createdAt: 'desc'
        }
      });
      
      return rewards.map(reward => this.rewardToInterface(reward));
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
      
      const count = await prisma.reward.count({
        where: {
          userId,
          status: 'pending',
          OR: [
            { expiresAt: null },
            { expiresAt: { gt: new Date() } }
          ]
        }
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

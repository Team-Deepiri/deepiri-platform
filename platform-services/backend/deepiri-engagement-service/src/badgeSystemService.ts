import mongoose, { Schema, Document, Model, Types } from 'mongoose';
import { Request, Response } from 'express';
import { createLogger } from '@deepiri/shared-utils';

const logger = createLogger('badge-system-service');

type BadgeCategory = 'productivity' | 'skill' | 'social' | 'achievement' | 'special' | 'seasonal' | 'secret';
type BadgeRarity = 'common' | 'uncommon' | 'rare' | 'epic' | 'legendary' | 'mythic';

interface IBadge extends Document {
  badgeId: string;
  name: string;
  description: string;
  category: BadgeCategory;
  rarity: BadgeRarity;
  icon?: string;
  conditions: Record<string, any>;
  isSecret: boolean;
  isProgressive: boolean;
  tiers: Array<{
    tier: number;
    name: string;
    description: string;
    condition: Record<string, any>;
  }>;
  unlockable: boolean;
  createdAt: Date;
}

interface IUserBadge extends Document {
  userId: Types.ObjectId;
  badgeId: string;
  unlockedAt: Date;
  progress: number;
  tier: number;
  metadata?: Record<string, any>;
}

const BadgeSchema = new Schema<IBadge>({
  badgeId: { type: String, required: true, unique: true, index: true },
  name: { type: String, required: true },
  description: { type: String, required: true },
  category: {
    type: String,
    enum: ['productivity', 'skill', 'social', 'achievement', 'special', 'seasonal', 'secret'],
    required: true
  },
  rarity: {
    type: String,
    enum: ['common', 'uncommon', 'rare', 'epic', 'legendary', 'mythic'],
    default: 'common'
  },
  icon: { type: String },
  conditions: Schema.Types.Mixed,
  isSecret: { type: Boolean, default: false },
  isProgressive: { type: Boolean, default: false },
  tiers: [{
    tier: Number,
    name: String,
    description: String,
    condition: Schema.Types.Mixed
  }],
  unlockable: { type: Boolean, default: true },
  createdAt: { type: Date, default: Date.now }
}, {
  timestamps: true
});

const UserBadgeSchema = new Schema<IUserBadge>({
  userId: { type: Schema.Types.ObjectId, required: true, index: true },
  badgeId: { type: String, required: true, index: true },
  unlockedAt: { type: Date, default: Date.now },
  progress: { type: Number, default: 0 },
  tier: { type: Number, default: 1 },
  metadata: Schema.Types.Mixed
}, {
  timestamps: false
});

UserBadgeSchema.index({ userId: 1, badgeId: 1 }, { unique: true });

const Badge: Model<IBadge> = mongoose.model<IBadge>('Badge', BadgeSchema);
const UserBadge: Model<IUserBadge> = mongoose.model<IUserBadge>('UserBadge', UserBadgeSchema);

class BadgeSystemService {
  async getBadges(req: Request, res: Response): Promise<void> {
    try {
      const { userId } = req.params;
      const { category } = req.query;
      const badges = await this.getUserBadges(
        new Types.ObjectId(userId),
        category ? category as string : null
      );
      res.json(badges);
    } catch (error: any) {
      logger.error('Error getting badges:', error);
      res.status(500).json({ error: 'Failed to get badges' });
    }
  }

  async awardBadge(req: Request, res: Response): Promise<void> {
    try {
      const { userId, badgeId } = req.body;
      
      if (!userId || !badgeId) {
        res.status(400).json({ error: 'Missing userId or badgeId' });
        return;
      }

      const result = await this.checkAndAwardBadges(
        new Types.ObjectId(userId),
        'manual',
        { badgeId }
      );
      res.json(result);
    } catch (error: any) {
      logger.error('Error awarding badge:', error);
      res.status(500).json({ error: 'Failed to award badge' });
    }
  }

  private async getUserBadges(userId: Types.ObjectId, category: string | null = null) {
    try {
      const query: any = { userId };
      const userBadges = await UserBadge.find(query)
        .sort({ unlockedAt: -1 });

      const badgeIds = userBadges.map(ub => ub.badgeId);
      const badges = await Badge.find({ badgeId: { $in: badgeIds } });

      let result = userBadges.map(ub => {
        const badge = badges.find(b => b.badgeId === ub.badgeId);
        return {
          badge,
          unlockedAt: ub.unlockedAt,
          progress: ub.progress,
          tier: ub.tier,
          metadata: ub.metadata
        };
      });

      if (category) {
        result = result.filter(b => b.badge?.category === category);
      }

      return result;
    } catch (error) {
      logger.error('Error getting user badges:', error);
      throw error;
    }
  }

  private async checkAndAwardBadges(userId: Types.ObjectId, eventType: string, eventData: Record<string, any>) {
    try {
      const awardedBadges: any[] = [];

      const relevantBadges = await Badge.find({
        $or: [
          { 'conditions.eventType': eventType },
          { 'conditions.any': true }
        ]
      });

      for (const badge of relevantBadges) {
        const existing = await UserBadge.findOne({ userId, badgeId: badge.badgeId });
        
        if (existing && !badge.isProgressive) {
          continue;
        }

        if (await this._checkConditions(badge, userId, eventData)) {
          if (existing) {
            const newTier = await this._getNextTier(badge, existing.tier, eventData);
            if (newTier > existing.tier) {
              existing.tier = newTier;
              existing.progress = 100;
              existing.unlockedAt = new Date();
              await existing.save();
              awardedBadges.push({ badge, tier: newTier, upgraded: true });
            }
          } else {
            const userBadge = new UserBadge({
              userId,
              badgeId: badge.badgeId,
              tier: 1,
              progress: 100
            });
            await userBadge.save();
            awardedBadges.push({ badge, tier: 1, upgraded: false });
          }
        } else if (badge.isProgressive && existing) {
          const progress = await this._calculateProgress(badge, userId, eventData);
          existing.progress = progress;
          await existing.save();
        }
      }

      if (awardedBadges.length > 0) {
        logger.info('Badges awarded', { userId, count: awardedBadges.length });
      }

      return awardedBadges;
    } catch (error) {
      logger.error('Error checking badges:', error);
      throw error;
    }
  }

  private async _checkConditions(badge: IBadge, userId: Types.ObjectId, eventData: Record<string, any>): Promise<boolean> {
    try {
      const conditions = badge.conditions;
      
      if (conditions.tasksCompleted) {
        const taskCount = await this._getTaskCount(userId);
        return taskCount >= conditions.tasksCompleted;
      }

      if (conditions.challengesCompleted) {
        const challengeCount = await this._getChallengeCount(userId);
        return challengeCount >= conditions.challengesCompleted;
      }

      if (conditions.streak) {
        const streak = await this._getStreak(userId);
        return streak >= conditions.streak;
      }

      if (conditions.skillLevel) {
        const skillLevel = await this._getSkillLevel(userId, conditions.skillLevel.skill);
        return skillLevel >= conditions.skillLevel.level;
      }

      return false;
    } catch (error) {
      logger.error('Error checking conditions:', error);
      return false;
    }
  }

  private async _getTaskCount(userId: Types.ObjectId): Promise<number> {
    return 0;
  }

  private async _getChallengeCount(userId: Types.ObjectId): Promise<number> {
    return 0;
  }

  private async _getStreak(userId: Types.ObjectId): Promise<number> {
    return 0;
  }

  private async _getSkillLevel(userId: Types.ObjectId, skill: string): Promise<number> {
    return 1;
  }

  private async _calculateProgress(badge: IBadge, userId: Types.ObjectId, eventData: Record<string, any>): Promise<number> {
    return 0;
  }

  private async _getNextTier(badge: IBadge, currentTier: number, eventData: Record<string, any>): Promise<number> {
    return currentTier;
  }
}

export default new BadgeSystemService();


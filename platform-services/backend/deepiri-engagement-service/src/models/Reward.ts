export type RewardType = 'boost_credits' | 'momentum_bonus' | 'skip_day' | 'break_time' | 'custom';

export interface IReward {
  userId: string;
  rewardType: RewardType;
  amount: number; // Amount of credits, momentum, minutes, etc.
  source: 'streak' | 'momentum' | 'season' | 'achievement' | 'manual';
  sourceId?: string; // ID of the source (streak ID, achievement ID, etc.)
  description: string;
  status: 'pending' | 'claimed' | 'expired';
  claimedAt?: Date;
  expiresAt?: Date;
  metadata?: Record<string, any>;
  createdAt: Date;
  updatedAt: Date;
}

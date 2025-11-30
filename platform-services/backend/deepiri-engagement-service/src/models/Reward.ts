import mongoose, { Schema, Document, Model, Types } from 'mongoose';

export type RewardType = 'boost_credits' | 'momentum_bonus' | 'skip_day' | 'break_time' | 'custom';

export interface IReward extends Document {
  userId: Types.ObjectId;
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

const rewardSchema = new Schema<IReward>({
  userId: {
    type: Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  rewardType: {
    type: String,
    enum: ['boost_credits', 'momentum_bonus', 'skip_day', 'break_time', 'custom'],
    required: true
  },
  amount: {
    type: Number,
    required: true,
    min: 0
  },
  source: {
    type: String,
    enum: ['streak', 'momentum', 'season', 'achievement', 'manual'],
    required: true
  },
  sourceId: {
    type: String
  },
  description: {
    type: String,
    required: true
  },
  status: {
    type: String,
    enum: ['pending', 'claimed', 'expired'],
    default: 'pending'
  },
  claimedAt: {
    type: Date
  },
  expiresAt: {
    type: Date
  },
  metadata: Schema.Types.Mixed,
  createdAt: {
    type: Date,
    default: Date.now
  },
  updatedAt: {
    type: Date,
    default: Date.now
  }
});

rewardSchema.index({ userId: 1, status: 1 });
rewardSchema.index({ expiresAt: 1 });
rewardSchema.index({ source: 1, sourceId: 1 });

rewardSchema.pre('save', function(next) {
  this.updatedAt = new Date();
  
  // Auto-expire rewards if past expiration date
  if (this.expiresAt && new Date() > this.expiresAt && this.status === 'pending') {
    this.status = 'expired';
  }
  
  next();
});

const Reward: Model<IReward> = mongoose.model<IReward>('Reward', rewardSchema);
export default Reward;


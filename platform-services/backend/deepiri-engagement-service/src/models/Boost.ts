import mongoose, { Schema, Document, Model, Types } from 'mongoose';

export type BoostType = 
  | 'focus' 
  | 'velocity' 
  | 'clarity' 
  | 'debug' 
  | 'cleanup';

export interface IBoost extends Document {
  userId: Types.ObjectId;
  activeBoosts: Array<{
    boostType: BoostType;
    activatedAt: Date;
    expiresAt: Date;
    duration: number; // in minutes
    metadata?: Record<string, any>;
  }>;
  boostCredits: number;
  boostHistory: Array<{
    boostType: BoostType;
    activatedAt: Date;
    expiredAt: Date;
    duration: number;
    creditsUsed: number;
    source: 'purchased' | 'streak_reward' | 'momentum_reward' | 'season_reward';
  }>;
  settings: {
    maxConcurrentBoosts: number;
    maxAutopilotTimePerDay: number; // in minutes
    autopilotTimeUsedToday: number;
    lastAutopilotReset: Date;
  };
  createdAt: Date;
  updatedAt: Date;
}

const boostSchema = new Schema<IBoost>({
  userId: {
    type: Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    unique: true,
    index: true
  },
  activeBoosts: [{
    boostType: {
      type: String,
      enum: ['focus', 'velocity', 'clarity', 'debug', 'cleanup'],
      required: true
    },
    activatedAt: { type: Date, default: Date.now },
    expiresAt: { type: Date, required: true },
    duration: { type: Number, required: true }, // in minutes
    metadata: Schema.Types.Mixed
  }],
  boostCredits: {
    type: Number,
    default: 0,
    min: 0
  },
  boostHistory: [{
    boostType: {
      type: String,
      enum: ['focus', 'velocity', 'clarity', 'debug', 'cleanup'],
      required: true
    },
    activatedAt: { type: Date, required: true },
    expiredAt: { type: Date, required: true },
    duration: { type: Number, required: true },
    creditsUsed: { type: Number, required: true },
    source: {
      type: String,
      enum: ['purchased', 'streak_reward', 'momentum_reward', 'season_reward'],
      required: true
    }
  }],
  settings: {
    maxConcurrentBoosts: { type: Number, default: 1, min: 1, max: 3 },
    maxAutopilotTimePerDay: { type: Number, default: 60, min: 0 }, // 60 minutes default
    autopilotTimeUsedToday: { type: Number, default: 0, min: 0 },
    lastAutopilotReset: { type: Date, default: Date.now }
  },
  createdAt: {
    type: Date,
    default: Date.now
  },
  updatedAt: {
    type: Date,
    default: Date.now
  }
});

boostSchema.index({ userId: 1 });
boostSchema.index({ 'activeBoosts.expiresAt': 1 });

boostSchema.pre('save', function(next) {
  this.updatedAt = new Date();
  
  // Reset autopilot time if it's a new day
  const now = new Date();
  const lastReset = this.settings.lastAutopilotReset;
  if (lastReset) {
    const daysDiff = Math.floor((now.getTime() - lastReset.getTime()) / (1000 * 60 * 60 * 24));
    if (daysDiff >= 1) {
      this.settings.autopilotTimeUsedToday = 0;
      this.settings.lastAutopilotReset = now;
    }
  }
  
  // Remove expired boosts
  const nowTime = now.getTime();
  this.activeBoosts = this.activeBoosts.filter(boost => {
    if (boost.expiresAt.getTime() <= nowTime) {
      // Move to history
      this.boostHistory.push({
        boostType: boost.boostType,
        activatedAt: boost.activatedAt,
        expiredAt: boost.expiresAt,
        duration: boost.duration,
        creditsUsed: 0, // Will be calculated based on source
        source: 'purchased' // Default, should be set when activating
      });
      return false;
    }
    return true;
  });
  
  next();
});

const Boost: Model<IBoost> = mongoose.model<IBoost>('Boost', boostSchema);
export default Boost;


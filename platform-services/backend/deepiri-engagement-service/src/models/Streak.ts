import mongoose, { Schema, Document, Model, Types } from 'mongoose';

export interface IStreak extends Document {
  userId: Types.ObjectId;
  daily: {
    current: number;
    longest: number;
    lastDate: Date | null;
    canCashIn: boolean;
  };
  weekly: {
    current: number;
    longest: number;
    lastWeek: string | null;
    canCashIn: boolean;
  };
  project: {
    current: number;
    longest: number;
    projectId: string | null;
    lastProjectDate: Date | null;
    canCashIn: boolean;
  };
  pr: {
    current: number;
    longest: number;
    lastPRDate: Date | null;
    canCashIn: boolean;
  };
  healthy: {
    current: number;
    longest: number;
    lastHealthyDate: Date | null;
    canCashIn: boolean;
    consecutiveDaysWithoutBurnout: number;
  };
  cashedInStreaks: Array<{
    streakType: 'daily' | 'weekly' | 'project' | 'pr' | 'healthy';
    cashedAt: Date;
    streakValue: number;
    boostCreditsEarned: number;
  }>;
  createdAt: Date;
  updatedAt: Date;
}

const streakSchema = new Schema<IStreak>({
  userId: {
    type: Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    unique: true,
    index: true
  },
  daily: {
    current: { type: Number, default: 0, min: 0 },
    longest: { type: Number, default: 0, min: 0 },
    lastDate: { type: Date, default: null },
    canCashIn: { type: Boolean, default: false }
  },
  weekly: {
    current: { type: Number, default: 0, min: 0 },
    longest: { type: Number, default: 0, min: 0 },
    lastWeek: { type: String, default: null },
    canCashIn: { type: Boolean, default: false }
  },
  project: {
    current: { type: Number, default: 0, min: 0 },
    longest: { type: Number, default: 0, min: 0 },
    projectId: { type: String, default: null },
    lastProjectDate: { type: Date, default: null },
    canCashIn: { type: Boolean, default: false }
  },
  pr: {
    current: { type: Number, default: 0, min: 0 },
    longest: { type: Number, default: 0, min: 0 },
    lastPRDate: { type: Date, default: null },
    canCashIn: { type: Boolean, default: false }
  },
  healthy: {
    current: { type: Number, default: 0, min: 0 },
    longest: { type: Number, default: 0, min: 0 },
    lastHealthyDate: { type: Date, default: null },
    canCashIn: { type: Boolean, default: false },
    consecutiveDaysWithoutBurnout: { type: Number, default: 0, min: 0 }
  },
  cashedInStreaks: [{
    streakType: {
      type: String,
      enum: ['daily', 'weekly', 'project', 'pr', 'healthy'],
      required: true
    },
    cashedAt: { type: Date, default: Date.now },
    streakValue: { type: Number, required: true },
    boostCreditsEarned: { type: Number, required: true }
  }],
  createdAt: {
    type: Date,
    default: Date.now
  },
  updatedAt: {
    type: Date,
    default: Date.now
  }
});

streakSchema.index({ userId: 1 });
streakSchema.index({ 'daily.current': -1 });
streakSchema.index({ 'weekly.current': -1 });

streakSchema.pre('save', function(next) {
  this.updatedAt = new Date();
  
  // Enable cash-in if streak is >= 7 days/weeks
  if (this.daily.current >= 7) {
    this.daily.canCashIn = true;
  }
  if (this.weekly.current >= 2) {
    this.weekly.canCashIn = true;
  }
  if (this.project.current >= 3) {
    this.project.canCashIn = true;
  }
  if (this.pr.current >= 5) {
    this.pr.canCashIn = true;
  }
  if (this.healthy.current >= 7) {
    this.healthy.canCashIn = true;
  }
  
  next();
});

const Streak: Model<IStreak> = mongoose.model<IStreak>('Streak', streakSchema);
export default Streak;


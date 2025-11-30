import mongoose, { Schema, Document, Model, Types } from 'mongoose';

export interface ISeason extends Document {
  userId: Types.ObjectId;
  organizationId?: Types.ObjectId;
  name: string;
  description?: string;
  startDate: Date;
  endDate: Date;
  sprintCycle?: string; // e.g., "2 weeks", "1 month"
  status: 'upcoming' | 'active' | 'completed';
  odysseys: Types.ObjectId[];
  seasonBoosts: {
    enabled: boolean;
    boostType?: string;
    multiplier?: number;
    description?: string;
  };
  highlights: {
    totalMomentumEarned: number;
    objectivesCompleted: number;
    odysseysCompleted: number;
    topContributors: Array<{
      userId: Types.ObjectId;
      momentum: number;
      name?: string;
    }>;
    highlightsReel?: string; // URL or reference to auto-generated reel
    generatedAt?: Date;
  };
  metadata?: Record<string, any>;
  createdAt: Date;
  updatedAt: Date;
}

const seasonSchema = new Schema<ISeason>({
  userId: {
    type: Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  organizationId: {
    type: Schema.Types.ObjectId,
    ref: 'Organization',
    index: true
  },
  name: {
    type: String,
    required: true,
    trim: true,
    maxlength: 200
  },
  description: {
    type: String,
    trim: true,
    maxlength: 2000
  },
  startDate: {
    type: Date,
    required: true
  },
  endDate: {
    type: Date,
    required: true
  },
  sprintCycle: {
    type: String
  },
  status: {
    type: String,
    enum: ['upcoming', 'active', 'completed'],
    default: 'upcoming'
  },
  odysseys: [{
    type: Schema.Types.ObjectId,
    ref: 'Odyssey'
  }],
  seasonBoosts: {
    enabled: { type: Boolean, default: false },
    boostType: String,
    multiplier: { type: Number, default: 1, min: 1 },
    description: String
  },
  highlights: {
    totalMomentumEarned: { type: Number, default: 0, min: 0 },
    objectivesCompleted: { type: Number, default: 0, min: 0 },
    odysseysCompleted: { type: Number, default: 0, min: 0 },
    topContributors: [{
      userId: { type: Schema.Types.ObjectId, ref: 'User' },
      momentum: { type: Number, required: true },
      name: String
    }],
    highlightsReel: String,
    generatedAt: Date
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

seasonSchema.index({ userId: 1, status: 1 });
seasonSchema.index({ organizationId: 1, status: 1 });
seasonSchema.index({ startDate: 1, endDate: 1 });

seasonSchema.pre('save', function(next) {
  this.updatedAt = new Date();
  
  const now = new Date();
  
  // Update status based on dates
  if (now < this.startDate) {
    this.status = 'upcoming';
  } else if (now >= this.startDate && now <= this.endDate) {
    this.status = 'active';
  } else if (now > this.endDate) {
    this.status = 'completed';
    
    // Auto-generate highlights if not already generated
    if (!this.highlights.highlightsReel && this.highlights.totalMomentumEarned > 0) {
      this.highlights.generatedAt = now;
      // Highlights reel generation would be handled by a service
    }
  }
  
  next();
});

const Season: Model<ISeason> = mongoose.model<ISeason>('Season', seasonSchema);
export default Season;


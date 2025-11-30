import mongoose, { Schema, Document, Model, Types } from 'mongoose';

export type OdysseyScale = 'hours' | 'day' | 'week' | 'month' | 'custom';

export interface IOdyssey extends Document {
  userId: Types.ObjectId;
  organizationId?: Types.ObjectId;
  title: string;
  description?: string;
  scale: OdysseyScale;
  minimumHoursBeforeSelection?: number; // Set by team leader/moderator
  status: 'planning' | 'active' | 'completed' | 'paused' | 'cancelled';
  objectives: Types.ObjectId[];
  milestones: Array<{
    id: string;
    title: string;
    description?: string;
    completed: boolean;
    completedAt?: Date;
    momentumReward: number;
  }>;
  progress: {
    objectivesCompleted: number;
    totalObjectives: number;
    milestonesCompleted: number;
    totalMilestones: number;
    progressPercentage: number;
  };
  aiGeneratedBrief: {
    animation?: string; // URL or reference to animation
    summary: string;
    generatedAt: Date;
  };
  progressMap: {
    currentStage: string;
    stages: Array<{
      stageId: string;
      name: string;
      completed: boolean;
      completedAt?: Date;
    }>;
  };
  startDate: Date;
  endDate?: Date;
  seasonId?: Types.ObjectId;
  metadata?: Record<string, any>;
  createdAt: Date;
  updatedAt: Date;
}

const odysseySchema = new Schema<IOdyssey>({
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
  title: {
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
  scale: {
    type: String,
    enum: ['hours', 'day', 'week', 'month', 'custom'],
    default: 'week'
  },
  minimumHoursBeforeSelection: {
    type: Number,
    min: 0
  },
  status: {
    type: String,
    enum: ['planning', 'active', 'completed', 'paused', 'cancelled'],
    default: 'planning'
  },
  objectives: [{
    type: Schema.Types.ObjectId,
    ref: 'Objective'
  }],
  milestones: [{
    id: { type: String, required: true },
    title: { type: String, required: true },
    description: String,
    completed: { type: Boolean, default: false },
    completedAt: Date,
    momentumReward: { type: Number, default: 0, min: 0 }
  }],
  progress: {
    objectivesCompleted: { type: Number, default: 0, min: 0 },
    totalObjectives: { type: Number, default: 0, min: 0 },
    milestonesCompleted: { type: Number, default: 0, min: 0 },
    totalMilestones: { type: Number, default: 0, min: 0 },
    progressPercentage: { type: Number, default: 0, min: 0, max: 100 }
  },
  aiGeneratedBrief: {
    animation: String,
    summary: { type: String, default: '' },
    generatedAt: { type: Date, default: Date.now }
  },
  progressMap: {
    currentStage: { type: String, default: 'start' },
    stages: [{
      stageId: { type: String, required: true },
      name: { type: String, required: true },
      completed: { type: Boolean, default: false },
      completedAt: Date
    }]
  },
  startDate: {
    type: Date,
    default: Date.now
  },
  endDate: {
    type: Date
  },
  seasonId: {
    type: Schema.Types.ObjectId,
    ref: 'Season'
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

odysseySchema.index({ userId: 1, status: 1 });
odysseySchema.index({ organizationId: 1 });
odysseySchema.index({ seasonId: 1 });
odysseySchema.index({ startDate: 1, endDate: 1 });

odysseySchema.pre('save', function(next) {
  this.updatedAt = new Date();
  
  // Calculate progress percentage
  if (this.progress.totalObjectives > 0) {
    const objectiveProgress = (this.progress.objectivesCompleted / this.progress.totalObjectives) * 50;
    const milestoneProgress = this.progress.totalMilestones > 0 
      ? (this.progress.milestonesCompleted / this.progress.totalMilestones) * 50 
      : 0;
    this.progress.progressPercentage = Math.round(objectiveProgress + milestoneProgress);
  }
  
  // Auto-complete if all objectives and milestones are done
  if (
    this.progress.objectivesCompleted === this.progress.totalObjectives &&
    this.progress.milestonesCompleted === this.progress.totalMilestones &&
    this.status === 'active'
  ) {
    this.status = 'completed';
    this.endDate = new Date();
  }
  
  next();
});

const Odyssey: Model<IOdyssey> = mongoose.model<IOdyssey>('Odyssey', odysseySchema);
export default Odyssey;


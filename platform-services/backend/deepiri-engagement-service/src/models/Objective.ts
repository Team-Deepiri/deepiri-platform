import mongoose, { Schema, Document, Model, Types } from 'mongoose';

export interface IObjective extends Document {
  userId: Types.ObjectId;
  title: string;
  description?: string;
  status: 'draft' | 'active' | 'completed' | 'cancelled';
  momentumReward: number;
  deadline?: Date;
  subtasks: Array<{
    id: string;
    title: string;
    completed: boolean;
    momentumReward: number;
  }>;
  aiSuggestions: Array<{
    suggestion: string;
    type: 'task_breakdown' | 'optimization' | 'resource' | 'timeline';
    confidence: number;
  }>;
  completionData: {
    completedAt?: Date;
    actualDuration?: number;
    momentumEarned: number;
    autoDetected: boolean; // Detected via commits/edits
  };
  odysseyId?: Types.ObjectId;
  seasonId?: Types.ObjectId;
  metadata?: Record<string, any>;
  createdAt: Date;
  updatedAt: Date;
}

const objectiveSchema = new Schema<IObjective>({
  userId: {
    type: Schema.Types.ObjectId,
    ref: 'User',
    required: true,
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
  status: {
    type: String,
    enum: ['draft', 'active', 'completed', 'cancelled'],
    default: 'draft'
  },
  momentumReward: {
    type: Number,
    required: true,
    min: 0
  },
  deadline: {
    type: Date
  },
  subtasks: [{
    id: { type: String, required: true },
    title: { type: String, required: true },
    completed: { type: Boolean, default: false },
    momentumReward: { type: Number, default: 0, min: 0 }
  }],
  aiSuggestions: [{
    suggestion: { type: String, required: true },
    type: {
      type: String,
      enum: ['task_breakdown', 'optimization', 'resource', 'timeline'],
      required: true
    },
    confidence: { type: Number, default: 0.5, min: 0, max: 1 }
  }],
  completionData: {
    completedAt: Date,
    actualDuration: Number,
    momentumEarned: { type: Number, default: 0 },
    autoDetected: { type: Boolean, default: false }
  },
  odysseyId: {
    type: Schema.Types.ObjectId,
    ref: 'Odyssey'
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

objectiveSchema.index({ userId: 1, status: 1 });
objectiveSchema.index({ odysseyId: 1 });
objectiveSchema.index({ seasonId: 1 });
objectiveSchema.index({ deadline: 1 });

objectiveSchema.pre('save', function(next) {
  this.updatedAt = new Date();
  next();
});

const Objective: Model<IObjective> = mongoose.model<IObjective>('Objective', objectiveSchema);
export default Objective;


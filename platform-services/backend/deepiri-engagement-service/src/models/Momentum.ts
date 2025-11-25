import mongoose, { Schema, Document, Model, Types } from 'mongoose';

export interface IMomentum extends Document {
  userId: Types.ObjectId;
  totalMomentum: number;
  currentLevel: number;
  momentumToNextLevel: number;
  skillMastery: {
    commits: number;
    docs: number;
    tasks: number;
    reviews: number;
    comments: number;
    attendance: number;
    featuresShipped: number;
    designEdits: number;
  };
  levelHistory: Array<{
    level: number;
    reachedAt: Date;
    totalMomentum: number;
  }>;
  achievements: Array<{
    achievementId: string;
    name: string;
    description: string;
    unlockedAt: Date;
    showcaseable: boolean;
  }>;
  publicProfile: {
    displayMomentum: boolean;
    showcaseAchievements: string[];
    resumeReferences: string[];
  };
  createdAt: Date;
  updatedAt: Date;
}

const momentumSchema = new Schema<IMomentum>({
  userId: {
    type: Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    unique: true,
    index: true
  },
  totalMomentum: {
    type: Number,
    default: 0,
    min: 0
  },
  currentLevel: {
    type: Number,
    default: 1,
    min: 1
  },
  momentumToNextLevel: {
    type: Number,
    default: 100,
    min: 1
  },
  skillMastery: {
    commits: { type: Number, default: 0, min: 0 },
    docs: { type: Number, default: 0, min: 0 },
    tasks: { type: Number, default: 0, min: 0 },
    reviews: { type: Number, default: 0, min: 0 },
    comments: { type: Number, default: 0, min: 0 },
    attendance: { type: Number, default: 0, min: 0 },
    featuresShipped: { type: Number, default: 0, min: 0 },
    designEdits: { type: Number, default: 0, min: 0 }
  },
  levelHistory: [{
    level: { type: Number, required: true },
    reachedAt: { type: Date, default: Date.now },
    totalMomentum: { type: Number, required: true }
  }],
  achievements: [{
    achievementId: { type: String, required: true },
    name: { type: String, required: true },
    description: { type: String },
    unlockedAt: { type: Date, default: Date.now },
    showcaseable: { type: Boolean, default: false }
  }],
  publicProfile: {
    displayMomentum: { type: Boolean, default: true },
    showcaseAchievements: [{ type: String }],
    resumeReferences: [{ type: String }]
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

momentumSchema.index({ userId: 1 });
momentumSchema.index({ totalMomentum: -1 });
momentumSchema.index({ currentLevel: -1 });

momentumSchema.pre('save', function(next) {
  this.updatedAt = new Date();
  
  // Calculate momentum to next level (exponential growth)
  const baseMomentum = 100;
  const growthFactor = 1.5;
  this.momentumToNextLevel = Math.floor(baseMomentum * Math.pow(growthFactor, this.currentLevel - 1));
  
  // Check for level up
  if (this.totalMomentum >= this.momentumToNextLevel) {
    const previousLevel = this.currentLevel;
    this.currentLevel += 1;
    
    // Record level up in history
    this.levelHistory.push({
      level: this.currentLevel,
      reachedAt: new Date(),
      totalMomentum: this.totalMomentum
    });
    
    // Recalculate momentum to next level
    this.momentumToNextLevel = Math.floor(baseMomentum * Math.pow(growthFactor, this.currentLevel - 1));
  }
  
  next();
});

const Momentum: Model<IMomentum> = mongoose.model<IMomentum>('Momentum', momentumSchema);
export default Momentum;


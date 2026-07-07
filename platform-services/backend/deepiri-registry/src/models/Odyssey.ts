export type OdysseyScale = 'hours' | 'day' | 'week' | 'month' | 'custom';

export interface IOdyssey {
  userId: string;
  organizationId?: string;
  title: string;
  description?: string;
  scale: OdysseyScale;
  minimumHoursBeforeSelection?: number; // Set by team leader/moderator
  status: 'planning' | 'active' | 'completed' | 'paused' | 'cancelled';
  objectives: string[];
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
  seasonId?: string;
  metadata?: Record<string, any>;
  createdAt: Date;
  updatedAt: Date;
}

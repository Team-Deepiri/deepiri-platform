export interface IObjective {
  userId: string;
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
  odysseyId?: string;
  seasonId?: string;
  metadata?: Record<string, any>;
  createdAt: Date;
  updatedAt: Date;
}

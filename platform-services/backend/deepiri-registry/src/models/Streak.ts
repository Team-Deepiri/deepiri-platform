export interface IStreak {
  userId: string;
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

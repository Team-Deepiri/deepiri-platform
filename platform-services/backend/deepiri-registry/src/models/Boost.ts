export type BoostType = 
  | 'focus' 
  | 'velocity' 
  | 'clarity' 
  | 'debug' 
  | 'cleanup';

export interface IBoost {
  userId: string;
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


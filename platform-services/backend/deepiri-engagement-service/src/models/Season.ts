export interface ISeason {
  userId: string;
  organizationId?: string;
  name: string;
  description?: string;
  startDate: Date;
  endDate: Date;
  sprintCycle?: string; // e.g., "2 weeks", "1 month"
  status: 'upcoming' | 'active' | 'completed';
  odysseys: string[];
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
      userId: string;
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

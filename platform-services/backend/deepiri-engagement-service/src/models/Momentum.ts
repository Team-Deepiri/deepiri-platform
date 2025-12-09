export interface IMomentum {
  userId: string;
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

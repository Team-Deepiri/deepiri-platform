import { Server, Socket } from 'socket.io';
import winston from 'winston';

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [new winston.transports.Console({ format: winston.format.simple() })]
});

export interface GamificationEventData {
  userId: string;
  type: 'momentum_awarded' | 'level_up' | 'streak_updated' | 'boost_activated' | 'objective_completed' | 'milestone_completed' | 'reward_earned';
  data: any;
  timestamp: Date;
}

export class GamificationEventEmitter {
  private io: Server;

  constructor(io: Server) {
    this.io = io;
  }

  /**
   * Emit momentum awarded event
   */
  emitMomentumAwarded(userId: string, amount: number, source: string, newTotal: number, currentLevel: number): void {
    this.emitToUser(userId, {
      userId,
      type: 'momentum_awarded',
      data: {
        amount,
        source,
        newTotal,
        currentLevel
      },
      timestamp: new Date()
    });
  }

  /**
   * Emit level up event
   */
  emitLevelUp(userId: string, newLevel: number, totalMomentum: number): void {
    this.emitToUser(userId, {
      userId,
      type: 'level_up',
      data: {
        newLevel,
        totalMomentum,
        message: `Congratulations! You've reached Level ${newLevel}! 🎉`
      },
      timestamp: new Date()
    });
  }

  /**
   * Emit streak updated event
   */
  emitStreakUpdated(userId: string, streakType: string, currentStreak: number, longestStreak: number): void {
    this.emitToUser(userId, {
      userId,
      type: 'streak_updated',
      data: {
        streakType,
        currentStreak,
        longestStreak,
        isNewRecord: currentStreak > longestStreak
      },
      timestamp: new Date()
    });
  }

  /**
   * Emit boost activated event
   */
  emitBoostActivated(userId: string, boostType: string, duration: number, expiresAt: Date): void {
    this.emitToUser(userId, {
      userId,
      type: 'boost_activated',
      data: {
        boostType,
        duration,
        expiresAt,
        message: `${boostType} boost activated for ${duration} minutes! 🚀`
      },
      timestamp: new Date()
    });
  }

  /**
   * Emit objective completed event
   */
  emitObjectiveCompleted(userId: string, objectiveId: string, title: string, momentumEarned: number): void {
    this.emitToUser(userId, {
      userId,
      type: 'objective_completed',
      data: {
        objectiveId,
        title,
        momentumEarned,
        message: `Objective "${title}" completed! +${momentumEarned} momentum 🎯`
      },
      timestamp: new Date()
    });
  }

  /**
   * Emit milestone completed event
   */
  emitMilestoneCompleted(userId: string, odysseyId: string, milestoneTitle: string, momentumEarned: number): void {
    this.emitToUser(userId, {
      userId,
      type: 'milestone_completed',
      data: {
        odysseyId,
        milestoneTitle,
        momentumEarned,
        message: `Milestone "${milestoneTitle}" completed! +${momentumEarned} momentum 🏔️`
      },
      timestamp: new Date()
    });
  }

  /**
   * Emit reward earned event
   */
  emitRewardEarned(userId: string, rewardType: string, amount: number, description: string): void {
    this.emitToUser(userId, {
      userId,
      type: 'reward_earned',
      data: {
        rewardType,
        amount,
        description,
        message: `Reward earned: ${description} 🎁`
      },
      timestamp: new Date()
    });
  }

  /**
   * Emit event to specific user
   */
  private emitToUser(userId: string, eventData: GamificationEventData): void {
    const room = `user:${userId}`;
    this.io.to(room).emit('gamification:event', eventData);
    logger.info(`Gamification event emitted to ${userId}`, { type: eventData.type });
  }

  /**
   * Emit event to all users in an organization
   */
  emitToOrganization(organizationId: string, eventData: GamificationEventData): void {
    const room = `org:${organizationId}`;
    this.io.to(room).emit('gamification:event', eventData);
    logger.info(`Gamification event emitted to organization ${organizationId}`, { type: eventData.type });
  }
}

export function setupGamificationEvents(io: Server): GamificationEventEmitter {
  const emitter = new GamificationEventEmitter(io);

  // Setup socket handlers for gamification
  io.on('connection', (socket: Socket) => {
    const userId = (socket as any).userId; // Assuming userId is attached during auth

    if (userId) {
      // Join user's personal room
      socket.join(`user:${userId}`);
      logger.info(`User ${userId} joined gamification room`);

      // Join organization room if applicable
      const organizationId = (socket as any).organizationId;
      if (organizationId) {
        socket.join(`org:${organizationId}`);
      }
    }

    socket.on('disconnect', () => {
      if (userId) {
        logger.info(`User ${userId} left gamification room`);
      }
    });
  });

  return emitter;
}


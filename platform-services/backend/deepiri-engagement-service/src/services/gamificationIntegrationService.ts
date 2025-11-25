import axios from 'axios';
import { createLogger } from '@deepiri/shared-utils';
import momentumService from './momentumService';
import streakService from './streakService';
import objectiveService from './objectiveService';
import rewardService from './rewardService';

const logger = createLogger('gamification-integration-service');

const ENGAGEMENT_SERVICE_URL = process.env.ENGAGEMENT_SERVICE_URL || 'http://engagement-service:5003';

class GamificationIntegrationService {
  /**
   * Handle task completion - award momentum and update streaks
   */
  async handleTaskCompletion(
    userId: string,
    taskData: {
      taskId: string;
      title: string;
      type?: string;
      estimatedDuration?: number;
      actualDuration?: number;
    }
  ): Promise<void> {
    try {
      // Award momentum for task completion
      const momentumAmount = this.calculateTaskMomentum(taskData);
      await momentumService.awardMomentum(userId, momentumAmount, 'tasks', {
        taskId: taskData.taskId,
        taskType: taskData.type
      });

      // Update daily streak
      await streakService.updateDailyStreak(userId);

      // Check if this task is linked to an objective
      // If so, mark objective as complete
      // This would require querying objectives by taskId or title match
      
      logger.info(`Task completion handled for user ${userId}, task ${taskData.taskId}`);
    } catch (error: any) {
      logger.error('Error handling task completion:', error);
      // Don't throw - gamification failures shouldn't break task completion
    }
  }

  /**
   * Handle commit - award momentum and update PR streak
   */
  async handleCommit(
    userId: string,
    commitData: {
      commitId: string;
      message: string;
      filesChanged?: number;
      linesAdded?: number;
      linesDeleted?: number;
    }
  ): Promise<void> {
    try {
      // Award momentum based on commit size
      const momentumAmount = this.calculateCommitMomentum(commitData);
      await momentumService.awardMomentum(userId, momentumAmount, 'commits', {
        commitId: commitData.commitId,
        filesChanged: commitData.filesChanged
      });

      // Update PR streak
      await streakService.updatePRStreak(userId);

      logger.info(`Commit handled for user ${userId}`);
    } catch (error: any) {
      logger.error('Error handling commit:', error);
    }
  }

  /**
   * Handle document creation/update
   */
  async handleDocumentActivity(
    userId: string,
    docData: {
      docId: string;
      action: 'create' | 'update' | 'review';
      wordCount?: number;
    }
  ): Promise<void> {
    try {
      const momentumAmount = this.calculateDocumentMomentum(docData);
      await momentumService.awardMomentum(userId, momentumAmount, 'docs', {
        docId: docData.docId,
        action: docData.action
      });

      logger.info(`Document activity handled for user ${userId}`);
    } catch (error: any) {
      logger.error('Error handling document activity:', error);
    }
  }

  /**
   * Handle code review
   */
  async handleCodeReview(
    userId: string,
    reviewData: {
      reviewId: string;
      prId: string;
      commentsCount?: number;
      approved?: boolean;
    }
  ): Promise<void> {
    try {
      const momentumAmount = this.calculateReviewMomentum(reviewData);
      await momentumService.awardMomentum(userId, momentumAmount, 'reviews', {
        reviewId: reviewData.reviewId,
        prId: reviewData.prId,
        approved: reviewData.approved
      });

      logger.info(`Code review handled for user ${userId}`);
    } catch (error: any) {
      logger.error('Error handling code review:', error);
    }
  }

  /**
   * Handle feature shipped
   */
  async handleFeatureShipped(
    userId: string,
    featureData: {
      featureId: string;
      featureName: string;
      complexity?: 'low' | 'medium' | 'high';
    }
  ): Promise<void> {
    try {
      const momentumAmount = this.calculateFeatureMomentum(featureData);
      await momentumService.awardMomentum(userId, momentumAmount, 'featuresShipped', {
        featureId: featureData.featureId,
        featureName: featureData.featureName
      });

      // Check for milestone rewards
      await this.checkMilestoneRewards(userId);

      logger.info(`Feature shipped handled for user ${userId}`);
    } catch (error: any) {
      logger.error('Error handling feature shipped:', error);
    }
  }

  /**
   * Check and award milestone rewards
   */
  private async checkMilestoneRewards(userId: string): Promise<void> {
    try {
      const momentumProfile = await momentumService.getOrCreateProfile(userId);
      
      // Check for level milestones
      const level = momentumProfile.currentLevel;
      if (level % 10 === 0) {
        // Every 10 levels, award boost credits
        await rewardService.createReward(
          userId,
          'boost_credits',
          10,
          'momentum',
          `Level ${level} milestone reward!`,
          `level_${level}`
        );
      }

      // Check for momentum milestones
      const totalMomentum = momentumProfile.totalMomentum;
      if (totalMomentum >= 1000 && totalMomentum % 1000 === 0) {
        await rewardService.createReward(
          userId,
          'momentum_bonus',
          50,
          'momentum',
          `${totalMomentum} momentum milestone!`,
          `momentum_${totalMomentum}`
        );
      }
    } catch (error: any) {
      logger.error('Error checking milestone rewards:', error);
    }
  }

  // Momentum calculation helpers
  private calculateTaskMomentum(taskData: any): number {
    let base = 10;
    
    // Bonus for efficiency
    if (taskData.estimatedDuration && taskData.actualDuration) {
      const efficiency = taskData.estimatedDuration / taskData.actualDuration;
      if (efficiency > 1.2) base += 5; // Completed faster than estimated
    }
    
    // Bonus for task type
    if (taskData.type === 'code') base += 5;
    if (taskData.type === 'design') base += 3;
    
    return Math.round(base);
  }

  private calculateCommitMomentum(commitData: any): number {
    let base = 5;
    
    if (commitData.filesChanged) {
      base += Math.min(commitData.filesChanged * 0.5, 10);
    }
    
    if (commitData.linesAdded) {
      base += Math.min(commitData.linesAdded * 0.1, 15);
    }
    
    return Math.round(base);
  }

  private calculateDocumentMomentum(docData: any): number {
    let base = 3;
    
    if (docData.action === 'create') base += 2;
    if (docData.action === 'review') base += 1;
    
    if (docData.wordCount) {
      base += Math.min(docData.wordCount / 100, 5);
    }
    
    return Math.round(base);
  }

  private calculateReviewMomentum(reviewData: any): number {
    let base = 5;
    
    if (reviewData.approved) base += 3;
    if (reviewData.commentsCount) {
      base += Math.min(reviewData.commentsCount, 5);
    }
    
    return Math.round(base);
  }

  private calculateFeatureMomentum(featureData: any): number {
    let base = 20;
    
    if (featureData.complexity === 'high') base += 15;
    if (featureData.complexity === 'medium') base += 8;
    
    return Math.round(base);
  }
}

export default new GamificationIntegrationService();


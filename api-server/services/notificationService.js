const Notification = require('../models/Notification');
const logger = require('../utils/logger');

class NotificationService {
  constructor() {
    this.isRunning = false;
    this.intervalId = null;
  }

  async initialize() {
    try {
      // Start the notification processor
      this.startProcessor();
      logger.info('Notification service initialized');
    } catch (error) {
      logger.error('Failed to initialize notification service:', error);
    }
  }

  startProcessor() {
    if (this.isRunning) return;

    this.isRunning = true;
    this.intervalId = setInterval(async () => {
      await this.processPendingNotifications();
    }, 30000); // Process every 30 seconds

    logger.info('Notification processor started');
  }

  stopProcessor() {
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = null;
    }
    this.isRunning = false;
    logger.info('Notification processor stopped');
  }

  async processPendingNotifications() {
    try {
      const pendingNotifications = await Notification.findPending();
      
      for (const notification of pendingNotifications) {
        await this.sendNotification(notification);
      }

      if (pendingNotifications.length > 0) {
        logger.info(`Processed ${pendingNotifications.length} pending notifications`);
      }
    } catch (error) {
      logger.error('Error processing pending notifications:', error);
    }
  }

  async sendNotification(notification) {
    try {
      // Send notification based on channels
      for (const channel of notification.channels) {
        switch (channel) {
          case 'push':
            await this.sendPushNotification(notification);
            break;
          case 'email':
            await this.sendEmailNotification(notification);
            break;
          case 'sms':
            await this.sendSMSNotification(notification);
            break;
          case 'in_app':
            await this.sendInAppNotification(notification);
            break;
        }
      }

      // Mark as sent
      await notification.markAsSent();

    } catch (error) {
      logger.error(`Failed to send notification ${notification._id}:`, error);
      await notification.markAsFailed(error.message);
    }
  }

  async sendPushNotification(notification) {
    try {
      // TODO: Implement Firebase Cloud Messaging
      logger.info(`Sending push notification to user ${notification.userId}: ${notification.message}`);
      
      // Placeholder implementation
      return true;
    } catch (error) {
      logger.error('Push notification failed:', error);
      throw error;
    }
  }

  async sendEmailNotification(notification) {
    try {
      // TODO: Implement email service (SendGrid, AWS SES, etc.)
      logger.info(`Sending email notification to user ${notification.userId}: ${notification.message}`);
      
      // Placeholder implementation
      return true;
    } catch (error) {
      logger.error('Email notification failed:', error);
      throw error;
    }
  }

  async sendSMSNotification(notification) {
    try {
      // TODO: Implement SMS service (AWS SNS, etc.)
      logger.info(`Sending SMS notification to user ${notification.userId}: ${notification.message}`);
      
      // Placeholder implementation
      return true;
    } catch (error) {
      logger.error('SMS notification failed:', error);
      throw error;
    }
  }

  async sendInAppNotification(notification) {
    try {
      // Send real-time notification via Socket.IO
      if (global.io) {
        global.io.to(`user_${notification.userId}`).emit('notification', {
          id: notification._id,
          type: notification.type,
          title: notification.title,
          message: notification.message,
          data: notification.data,
          priority: notification.priority,
          timestamp: notification.scheduledFor
        });
      }

      logger.info(`Sent in-app notification to user ${notification.userId}`);
      return true;
    } catch (error) {
      logger.error('In-app notification failed:', error);
      throw error;
    }
  }

  async createAdventureNotification(userId, type, adventureId, message, scheduledFor = null) {
    try {
      const notification = await Notification.createAdventureNotification(
        userId,
        type,
        adventureId,
        message,
        scheduledFor
      );

      logger.info(`Created adventure notification for user ${userId}: ${type}`);
      return notification;
    } catch (error) {
      logger.error('Failed to create adventure notification:', error);
      throw error;
    }
  }

  async createEventNotification(userId, type, eventId, message, scheduledFor = null) {
    try {
      const notification = await Notification.createEventNotification(
        userId,
        type,
        eventId,
        message,
        scheduledFor
      );

      logger.info(`Created event notification for user ${userId}: ${type}`);
      return notification;
    } catch (error) {
      logger.error('Failed to create event notification:', error);
      throw error;
    }
  }

  async createFriendNotification(userId, type, friendId, message) {
    try {
      const notification = await Notification.createFriendNotification(
        userId,
        type,
        friendId,
        message
      );

      logger.info(`Created friend notification for user ${userId}: ${type}`);
      return notification;
    } catch (error) {
      logger.error('Failed to create friend notification:', error);
      throw error;
    }
  }

  async createGamificationNotification(userId, type, message, data = {}) {
    try {
      const notification = await Notification.createGamificationNotification(
        userId,
        type,
        message,
        data
      );

      logger.info(`Created gamification notification for user ${userId}: ${type}`);
      return notification;
    } catch (error) {
      logger.error('Failed to create gamification notification:', error);
      throw error;
    }
  }

  async scheduleAdventureReminders(adventure) {
    try {
      const userId = adventure.userId;
      const adventureId = adventure._id;

      // Schedule step reminders
      for (let i = 0; i < adventure.steps.length; i++) {
        const step = adventure.steps[i];
        const reminderTime = new Date(step.startTime.getTime() - 15 * 60000); // 15 minutes before

        if (reminderTime > new Date()) {
          await this.createAdventureNotification(
            userId,
            'step_reminder',
            adventureId,
            `Upcoming: ${step.name} in 15 minutes`,
            reminderTime
          );
        }
      }

      // Schedule completion reminder
      const completionTime = new Date(adventure.steps[adventure.steps.length - 1].endTime);
      await this.createAdventureNotification(
        userId,
        'adventure_completed',
        adventureId,
        'How was your adventure? Leave a review!',
        completionTime
      );

      logger.info(`Scheduled reminders for adventure ${adventureId}`);
    } catch (error) {
      logger.error('Failed to schedule adventure reminders:', error);
    }
  }

  async sendWeatherAlert(userId, adventureId, alert) {
    try {
      await this.createAdventureNotification(
        userId,
        'weather_alert',
        adventureId,
        `Weather Alert: ${alert}`,
        new Date()
      );

      logger.info(`Sent weather alert to user ${userId}`);
    } catch (error) {
      logger.error('Failed to send weather alert:', error);
    }
  }

  async sendVenueChangeAlert(userId, adventureId, oldVenue, newVenue) {
    try {
      const message = `Venue change: ${oldVenue} is now ${newVenue}`;
      await this.createAdventureNotification(
        userId,
        'venue_change',
        adventureId,
        message,
        new Date()
      );

      logger.info(`Sent venue change alert to user ${userId}`);
    } catch (error) {
      logger.error('Failed to send venue change alert:', error);
    }
  }

  async sendFriendJoinedNotification(userId, friendId, adventureId) {
    try {
      const message = `Your friend joined your adventure!`;
      await this.createAdventureNotification(
        userId,
        'friend_joined',
        adventureId,
        message,
        new Date()
      );

      logger.info(`Sent friend joined notification to user ${userId}`);
    } catch (error) {
      logger.error('Failed to send friend joined notification:', error);
    }
  }

  async sendBadgeEarnedNotification(userId, badge) {
    try {
      await this.createGamificationNotification(
        userId,
        'badge_earned',
        `Congratulations! You earned the "${badge}" badge!`,
        { badge }
      );

      logger.info(`Sent badge earned notification to user ${userId}`);
    } catch (error) {
      logger.error('Failed to send badge earned notification:', error);
    }
  }

  async sendPointsEarnedNotification(userId, points, reason) {
    try {
      await this.createGamificationNotification(
        userId,
        'points_earned',
        `You earned ${points} points for ${reason}!`,
        { points, reason }
      );

      logger.info(`Sent points earned notification to user ${userId}`);
    } catch (error) {
      logger.error('Failed to send points earned notification:', error);
    }
  }

  async sendStreakReminder(userId, streak) {
    try {
      await this.createGamificationNotification(
        userId,
        'streak_reminder',
        `You're on a ${streak} day adventure streak! Keep it going!`,
        { streak }
      );

      logger.info(`Sent streak reminder to user ${userId}`);
    } catch (error) {
      logger.error('Failed to send streak reminder:', error);
    }
  }

  async cleanupOldNotifications(daysOld = 30) {
    try {
      const result = await Notification.cleanup(daysOld);
      logger.info(`Cleaned up ${result.deletedCount} old notifications`);
      return result;
    } catch (error) {
      logger.error('Failed to cleanup old notifications:', error);
      throw error;
    }
  }

  async getNotificationStats() {
    try {
      const stats = await Notification.aggregate([
        {
          $group: {
            _id: '$status',
            count: { $sum: 1 }
          }
        }
      ]);

      const total = await Notification.countDocuments();
      const pending = await Notification.countDocuments({ status: 'pending' });
      const sent = await Notification.countDocuments({ status: 'sent' });
      const failed = await Notification.countDocuments({ status: 'failed' });

      return {
        total,
        pending,
        sent,
        failed,
        breakdown: stats
      };
    } catch (error) {
      logger.error('Failed to get notification stats:', error);
      throw error;
    }
  }
}

module.exports = new NotificationService();

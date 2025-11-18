import * as admin from 'firebase-admin';
import { createLogger } from '@deepiri/shared-utils';

const logger = createLogger('push-notification-service');

interface Notification {
  title: string;
  body: string;
  data?: Record<string, string>;
  badge?: number;
}

class PushNotificationService {
  private fcmInitialized: boolean = false;

  constructor() {
    this._initializeFCM();
  }

  private _initializeFCM(): void {
    try {
      if (process.env.FIREBASE_SERVICE_ACCOUNT) {
        const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
        admin.initializeApp({
          credential: admin.credential.cert(serviceAccount)
        });
        this.fcmInitialized = true;
        logger.info('FCM initialized');
      } else {
        logger.warn('FCM not configured - FIREBASE_SERVICE_ACCOUNT not set');
      }
    } catch (error) {
      logger.error('FCM initialization failed:', error);
    }
  }

  async sendPushNotification(userId: string, deviceToken: string, notification: Notification) {
    try {
      if (!this.fcmInitialized) {
        logger.warn('FCM not initialized, skipping push notification');
        return { success: false, reason: 'FCM not initialized' };
      }

      const message = {
        token: deviceToken,
        notification: {
          title: notification.title,
          body: notification.body
        },
        data: notification.data || {},
        android: {
          priority: 'high' as const,
          notification: {
            sound: 'default',
            channelId: 'deepiri_notifications'
          }
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: notification.badge || 0
            }
          }
        }
      };

      const response = await admin.messaging().send(message);
      logger.info('Push notification sent', { userId, messageId: response });
      
      return { success: true, messageId: response };
    } catch (error: any) {
      logger.error('Error sending push notification:', error);
      return { success: false, error: error.message };
    }
  }

  async sendToMultipleDevices(deviceTokens: string[], notification: Notification) {
    try {
      if (!this.fcmInitialized) {
        return { success: false, reason: 'FCM not initialized' };
      }

      const message = {
        notification: {
          title: notification.title,
          body: notification.body
        },
        data: notification.data || {},
        tokens: deviceTokens
      };

      const response = await admin.messaging().sendMulticast(message);
      logger.info('Multicast push notification sent', { 
        successCount: response.successCount,
        failureCount: response.failureCount 
      });

      return {
        success: true,
        successCount: response.successCount,
        failureCount: response.failureCount
      };
    } catch (error: any) {
      logger.error('Error sending multicast push:', error);
      return { success: false, error: error.message };
    }
  }

  async subscribeToTopic(deviceToken: string, topic: string) {
    try {
      if (!this.fcmInitialized) {
        return { success: false };
      }

      await admin.messaging().subscribeToTopic([deviceToken], topic);
      logger.info('Device subscribed to topic', { deviceToken, topic });
      return { success: true };
    } catch (error: any) {
      logger.error('Error subscribing to topic:', error);
      return { success: false, error: error.message };
    }
  }

  async sendToTopic(topic: string, notification: Notification) {
    try {
      if (!this.fcmInitialized) {
        return { success: false };
      }

      const message = {
        topic,
        notification: {
          title: notification.title,
          body: notification.body
        },
        data: notification.data || {}
      };

      const response = await admin.messaging().send(message);
      logger.info('Topic notification sent', { topic, messageId: response });
      return { success: true, messageId: response };
    } catch (error: any) {
      logger.error('Error sending topic notification:', error);
      return { success: false, error: error.message };
    }
  }

  async getUserNotifications(userId: string) {
    // Placeholder - would query notification database
    return [];
  }
}

export default new PushNotificationService();


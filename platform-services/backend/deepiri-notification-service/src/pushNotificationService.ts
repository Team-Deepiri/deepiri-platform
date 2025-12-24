import * as webpush from 'web-push';
import { createLogger } from '@deepiri/shared-utils';

const logger = createLogger('push-notification-service');

interface Notification {
  title: string;
  body: string;
  data?: Record<string, string>;
  badge?: number;
  icon?: string;
  url?: string;
}

interface PushSubscription {
  endpoint: string;
  keys: {
    p256dh: string;
    auth: string;
  };
}

class PushNotificationService {
  private webPushInitialized: boolean = false;

  constructor() {
    this._initializeWebPush();
  }

  private _initializeWebPush(): void {
    try {
      const vapidPublicKey = process.env.VAPID_PUBLIC_KEY;
      const vapidPrivateKey = process.env.VAPID_PRIVATE_KEY;
      const vapidEmail = process.env.VAPID_EMAIL || 'mailto:notifications@deepiri.com';

      if (vapidPublicKey && vapidPrivateKey) {
        webpush.setVapidDetails(
          vapidEmail,
          vapidPublicKey,
          vapidPrivateKey
        );
        this.webPushInitialized = true;
        logger.info('Web Push API initialized');
      } else {
        logger.warn('Web Push not configured - VAPID keys not set. Generate with: npm install -g web-push && web-push generate-vapid-keys');
      }
    } catch (error) {
      logger.error('Web Push initialization failed:', error);
    }
  }

  /**
   * Send push notification to a single device
   * @param userId - User ID
   * @param subscription - Web Push subscription object (from browser)
   * @param notification - Notification payload
   */
  async sendPushNotification(userId: string, subscription: PushSubscription, notification: Notification) {
    try {
      if (!this.webPushInitialized) {
        logger.warn('Web Push not initialized, skipping push notification');
        return { success: false, reason: 'Web Push not initialized' };
      }

      const payload = JSON.stringify({
        title: notification.title,
        body: notification.body,
        icon: notification.icon || '/icon-192x192.png',
        badge: notification.badge || 0,
        data: {
          ...notification.data,
          url: notification.url || '/'
        }
      });

      const options = {
        TTL: 3600, // Time to live in seconds
        urgency: 'high' as const
      };

      await webpush.sendNotification(subscription, payload, options);
      logger.info('Push notification sent', { userId });
      
      return { success: true };
    } catch (error: any) {
      logger.error('Error sending push notification:', error);
      
      // Handle specific error cases
      if (error.statusCode === 410) {
        // Subscription expired or invalid
        return { success: false, error: 'Subscription expired', shouldRemove: true };
      }
      
      return { success: false, error: error.message };
    }
  }

  /**
   * Send push notification to multiple devices
   * @param subscriptions - Array of Web Push subscriptions
   * @param notification - Notification payload
   */
  async sendToMultipleDevices(subscriptions: PushSubscription[], notification: Notification) {
    try {
      if (!this.webPushInitialized) {
        return { success: false, reason: 'Web Push not initialized' };
      }

      const payload = JSON.stringify({
        title: notification.title,
        body: notification.body,
        icon: notification.icon || '/icon-192x192.png',
        badge: notification.badge || 0,
        data: {
          ...notification.data,
          url: notification.url || '/'
        }
      });

      const options = {
        TTL: 3600,
        urgency: 'high' as const
      };

      const results = await Promise.allSettled(
        subscriptions.map(sub => webpush.sendNotification(sub, payload, options))
      );

      const successCount = results.filter(r => r.status === 'fulfilled').length;
      const failureCount = results.filter(r => r.status === 'rejected').length;

      logger.info('Multicast push notification sent', { 
        successCount,
        failureCount 
      });

      return {
        success: true,
        successCount,
        failureCount
      };
    } catch (error: any) {
      logger.error('Error sending multicast push:', error);
      return { success: false, error: error.message };
    }
  }

  /**
   * Validate a push subscription
   * @param subscription - Web Push subscription to validate
   */
  async validateSubscription(subscription: PushSubscription): Promise<boolean> {
    try {
      if (!subscription.endpoint || !subscription.keys?.p256dh || !subscription.keys?.auth) {
        return false;
      }
      return true;
    } catch (error) {
      logger.error('Error validating subscription:', error);
      return false;
    }
  }

  /**
   * Get VAPID public key (for client-side subscription)
   */
  getVapidPublicKey(): string | null {
    return process.env.VAPID_PUBLIC_KEY || null;
  }

  async getUserNotifications(userId: string) {
    // Placeholder - would query notification database
    return [];
  }
}

export default new PushNotificationService();


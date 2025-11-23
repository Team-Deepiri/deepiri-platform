import express, { Router, Request, Response } from 'express';
import websocketService from './websocketService';
import pushNotificationService from './pushNotificationService';

const router: Router = express.Router();

router.get('/websocket/status', (req: Request, res: Response) => {
  res.json({
    status: 'ok',
    connections: websocketService.connectedUsers?.size || 0,
    timestamp: new Date().toISOString()
  });
});

router.post('/push/send', async (req: Request, res: Response) => {
  try {
    const { userId, subscription, notification } = req.body;
    
    if (!subscription) {
      return res.status(400).json({ error: 'Subscription object is required' });
    }
    
    const result = await pushNotificationService.sendPushNotification(userId, subscription, notification);
    res.json(result);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

router.post('/push/send-multiple', async (req: Request, res: Response) => {
  try {
    const { subscriptions, notification } = req.body;
    
    if (!subscriptions || !Array.isArray(subscriptions)) {
      return res.status(400).json({ error: 'Subscriptions array is required' });
    }
    
    const result = await pushNotificationService.sendToMultipleDevices(subscriptions, notification);
    res.json(result);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

router.get('/push/vapid-key', (req: Request, res: Response) => {
  const publicKey = pushNotificationService.getVapidPublicKey();
  if (!publicKey) {
    return res.status(503).json({ error: 'VAPID keys not configured' });
  }
  res.json({ publicKey });
});

router.post('/push/validate', async (req: Request, res: Response) => {
  try {
    const { subscription } = req.body;
    if (!subscription) {
      return res.status(400).json({ error: 'Subscription object is required' });
    }
    
    const isValid = await pushNotificationService.validateSubscription(subscription);
    res.json({ valid: isValid });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

router.post('/push/subscribe', async (req: Request, res: Response) => {
  try {
    const { userId, subscription } = req.body;
    
    if (!userId || !subscription) {
      return res.status(400).json({ error: 'userId and subscription are required' });
    }
    
    // Validate subscription
    const isValid = await pushNotificationService.validateSubscription(subscription);
    if (!isValid) {
      return res.status(400).json({ error: 'Invalid subscription object' });
    }
    
    // TODO: Store subscription in database for this user
    // For now, we just validate and acknowledge
    // In a full implementation, you would store this subscription
    // in a database associated with the userId
    
    res.json({ 
      success: true, 
      message: 'Subscription registered successfully',
      userId,
      subscription: {
        endpoint: subscription.endpoint
      }
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

router.post('/push/unsubscribe', async (req: Request, res: Response) => {
  try {
    const { userId, subscription } = req.body;
    
    if (!userId || !subscription) {
      return res.status(400).json({ error: 'userId and subscription are required' });
    }
    
    // TODO: Remove subscription from database for this user
    // For now, we just acknowledge the unsubscribe request
    
    res.json({ 
      success: true, 
      message: 'Subscription removed successfully',
      userId
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

router.get('/push/:userId', async (req: Request, res: Response) => {
  try {
    const { userId } = req.params;
    const notifications = await pushNotificationService.getUserNotifications(userId);
    res.json(notifications);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

export { router, websocketService as websocket, pushNotificationService as push };


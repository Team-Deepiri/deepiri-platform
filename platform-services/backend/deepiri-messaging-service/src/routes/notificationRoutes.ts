import { Router, Request, Response } from 'express';
import {
  handleSend,
  handleSendBatch,
  handleRegisterTemplate,
  handleGetPreferences,
  handleSetPreferences,
} from '../services/communicationsHub';
import pushNotificationService from '../services/pushNotificationService';

const router = Router();

router.post('/send', handleSend);
router.post('/send-batch', handleSendBatch);
router.post('/template', handleRegisterTemplate);
router.get('/preferences', handleGetPreferences);
router.post('/preferences', handleSetPreferences);

router.get('/push/vapid-key', (_req: Request, res: Response) => {
  const publicKey = pushNotificationService.getVapidPublicKey();
  if (!publicKey) {
    return res.status(503).json({ error: 'VAPID keys not configured' });
  }
  res.json({ publicKey });
});

router.post('/push/subscribe', async (req: Request, res: Response) => {
  try {
    const { userId, subscription } = req.body;
    if (!userId || !subscription) {
      return res.status(400).json({ error: 'userId and subscription are required' });
    }
    const isValid = await pushNotificationService.validateSubscription(subscription);
    if (!isValid) {
      return res.status(400).json({ error: 'Invalid subscription object' });
    }
    await pushNotificationService.registerSubscription(userId, subscription);
    res.json({
      success: true,
      message: 'Subscription registered successfully',
      userId,
      subscription: { endpoint: subscription.endpoint },
    });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Subscription failed';
    res.status(500).json({ error: message });
  }
});

router.post('/push/unsubscribe', async (req: Request, res: Response) => {
  try {
    const { userId, subscription } = req.body;
    if (!userId || !subscription?.endpoint) {
      return res.status(400).json({ error: 'userId and subscription endpoint are required' });
    }
    await pushNotificationService.removeSubscription(userId, subscription.endpoint);
    res.json({ success: true, message: 'Subscription removed successfully', userId });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : 'Unsubscribe failed';
    res.status(500).json({ error: message });
  }
});

export default router;

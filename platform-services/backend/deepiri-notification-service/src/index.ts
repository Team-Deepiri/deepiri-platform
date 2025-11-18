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
    const { userId, deviceToken, notification } = req.body;
    const result = await pushNotificationService.sendPushNotification(userId, deviceToken, notification);
    res.json(result);
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

export { router, websocket: websocketService, push: pushNotificationService };


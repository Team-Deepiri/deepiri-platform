import express, { Router, Request, Response } from 'express';
import webhookService from './webhookService';

const router: Router = express.Router();

// Webhook routes
router.post('/webhooks/:provider', (req: Request, res: Response) => webhookService.receiveWebhook(req, res));
router.get('/webhooks/:provider/status', (req: Request, res: Response) => webhookService.getStatus(req, res));

// OAuth routes
router.get('/oauth/:provider/authorize', (req: Request, res: Response) => webhookService.initiateOAuth(req, res));
router.get('/oauth/:provider/callback', (req: Request, res: Response) => webhookService.handleOAuthCallback(req, res));

export default router;


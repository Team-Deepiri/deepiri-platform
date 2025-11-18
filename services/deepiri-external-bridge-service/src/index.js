const express = require('express');
const router = express.Router();

const webhookService = require('./webhookService');

const webhook = webhookService.WebhookService
  ? new webhookService.WebhookService()
  : webhookService;

// Webhook routes
router.post('/webhooks/:provider', (req, res) => webhook.receiveWebhook(req, res));
router.get('/webhooks/:provider/status', (req, res) => webhook.getStatus(req, res));

// OAuth routes
router.get('/oauth/:provider/authorize', (req, res) => webhook.initiateOAuth(req, res));
router.get('/oauth/:provider/callback', (req, res) => webhook.handleOAuthCallback(req, res));

module.exports = router;


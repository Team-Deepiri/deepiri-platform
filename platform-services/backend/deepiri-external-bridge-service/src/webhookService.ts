import crypto from 'crypto';
import { Request, Response } from 'express';
import { createLogger } from '@deepiri/shared-utils';

const logger = createLogger('webhook-service');

interface WebhookHandler {
  (payload: any, headers: Record<string, string>): Promise<any>;
}

interface WebhookHistoryEntry {
  provider: string;
  payload: any;
  result: any;
  timestamp: Date;
}

class WebhookService {
  private webhookHandlers: Map<string, WebhookHandler>;
  private webhookHistory: WebhookHistoryEntry[];

  constructor() {
    this.webhookHandlers = new Map();
    this.webhookHistory = [];
  }

  registerHandler(provider: string, handler: WebhookHandler): void {
    this.webhookHandlers.set(provider, handler);
    logger.info('Webhook handler registered', { provider });
  }

  async receiveWebhook(req: Request, res: Response): Promise<void> {
    try {
      const { provider } = req.params;
      const payload = req.body;
      const headers = req.headers as Record<string, string>;

      const result = await this.processWebhook(provider, payload, headers);
      res.json({ success: true, result });
    } catch (error: any) {
      logger.error('Error receiving webhook:', error);
      res.status(500).json({ error: error.message || 'Webhook processing failed' });
    }
  }

  async getStatus(req: Request, res: Response): Promise<void> {
    try {
      const { provider } = req.params;
      const history = this.getWebhookHistory(provider, 10);
      res.json({ provider, recentWebhooks: history });
    } catch (error: any) {
      logger.error('Error getting status:', error);
      res.status(500).json({ error: 'Failed to get status' });
    }
  }

  async initiateOAuth(req: Request, res: Response): Promise<void> {
    try {
      const { provider } = req.params;
      // OAuth initiation logic
      res.json({ message: `OAuth initiation for ${provider}`, url: `https://${provider}.com/oauth/authorize` });
    } catch (error: any) {
      logger.error('Error initiating OAuth:', error);
      res.status(500).json({ error: 'OAuth initiation failed' });
    }
  }

  async handleOAuthCallback(req: Request, res: Response): Promise<void> {
    try {
      const { provider } = req.params;
      const { code } = req.query;
      // OAuth callback handling
      res.json({ message: `OAuth callback for ${provider}`, code });
    } catch (error: any) {
      logger.error('Error handling OAuth callback:', error);
      res.status(500).json({ error: 'OAuth callback failed' });
    }
  }

  private async processWebhook(provider: string, payload: any, headers: Record<string, string> = {}): Promise<any> {
    try {
      if (headers['x-signature'] && !this._verifySignature(provider, payload, headers['x-signature'])) {
        throw new Error('Invalid webhook signature');
      }

      const handler = this.webhookHandlers.get(provider);
      if (!handler) {
        throw new Error(`No handler registered for provider: ${provider}`);
      }

      const result = await handler(payload, headers);

      this.webhookHistory.push({
        provider,
        payload,
        result,
        timestamp: new Date()
      });

      if (this.webhookHistory.length > 1000) {
        this.webhookHistory.shift();
      }

      logger.info('Webhook processed', { provider, success: !!result });
      return result;
    } catch (error) {
      logger.error('Error processing webhook:', error);
      throw error;
    }
  }

  async handleGitHubWebhook(payload: any, headers: Record<string, string>): Promise<any> {
    try {
      const event = headers['x-github-event'];
      
      switch (event) {
        case 'issues':
          return await this._handleGitHubIssue(payload);
        case 'pull_request':
          return await this._handleGitHubPR(payload);
        case 'push':
          return await this._handleGitHubPush(payload);
        default:
          logger.warn('Unhandled GitHub event', { event });
          return { processed: false, event };
      }
    } catch (error) {
      logger.error('Error handling GitHub webhook:', error);
      throw error;
    }
  }

  async handleNotionWebhook(payload: any, headers: Record<string, string>): Promise<any> {
    try {
      return {
        processed: true,
        type: payload.type,
        data: payload.data
      };
    } catch (error) {
      logger.error('Error handling Notion webhook:', error);
      throw error;
    }
  }

  async handleTrelloWebhook(payload: any, headers: Record<string, string>): Promise<any> {
    try {
      const action = payload.action;
      
      switch (action.type) {
        case 'createCard':
          return await this._handleTrelloCardCreate(action);
        case 'updateCard':
          return await this._handleTrelloCardUpdate(action);
        default:
          return { processed: false, type: action.type };
      }
    } catch (error) {
      logger.error('Error handling Trello webhook:', error);
      throw error;
    }
  }

  private _verifySignature(provider: string, payload: any, signature: string): boolean {
    const secret = process.env[`${provider.toUpperCase()}_WEBHOOK_SECRET`];
    if (!secret) return true;

    const hmac = crypto.createHmac('sha256', secret);
    const digest = hmac.update(JSON.stringify(payload)).digest('hex');
    const expectedSignature = `sha256=${digest}`;

    return crypto.timingSafeEqual(
      Buffer.from(signature),
      Buffer.from(expectedSignature)
    );
  }

  private async _handleGitHubIssue(payload: any): Promise<any> {
    return {
      type: 'task_created',
      source: 'github',
      sourceId: payload.issue.id,
      title: payload.issue.title,
      description: payload.issue.body,
      status: payload.issue.state === 'open' ? 'pending' : 'completed'
    };
  }

  private async _handleGitHubPR(payload: any): Promise<any> {
    return {
      type: 'task_created',
      source: 'github',
      sourceId: payload.pull_request.id,
      title: `PR: ${payload.pull_request.title}`,
      description: payload.pull_request.body,
      status: payload.pull_request.state
    };
  }

  private async _handleGitHubPush(payload: any): Promise<any> {
    return {
      type: 'activity',
      source: 'github',
      commits: payload.commits.length
    };
  }

  private async _handleTrelloCardCreate(action: any): Promise<any> {
    return {
      type: 'task_created',
      source: 'trello',
      sourceId: action.data.card.id,
      title: action.data.card.name,
      description: action.data.card.desc,
      status: 'pending'
    };
  }

  private async _handleTrelloCardUpdate(action: any): Promise<any> {
    return {
      type: 'task_updated',
      source: 'trello',
      sourceId: action.data.card.id,
      changes: action.data.old
    };
  }

  getWebhookHistory(provider: string | null = null, limit: number = 100): WebhookHistoryEntry[] {
    let history = this.webhookHistory;
    
    if (provider) {
      history = history.filter(h => h.provider === provider);
    }

    return history.slice(-limit).reverse();
  }
}

export default new WebhookService();


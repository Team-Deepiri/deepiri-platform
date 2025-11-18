/**
 * Webhook Service
 * Receives and processes webhooks from external services
 */
const crypto = require('crypto');
const logger = require('../utils/logger');

class WebhookService {
  constructor() {
    this.webhookHandlers = new Map();
    this.webhookHistory = [];
  }

  /**
   * Register webhook handler
   */
  registerHandler(provider, handler) {
    this.webhookHandlers.set(provider, handler);
    logger.info('Webhook handler registered', { provider });
  }

  /**
   * Process incoming webhook
   */
  async processWebhook(provider, payload, headers = {}) {
    try {
      // Verify webhook signature if available
      if (headers['x-signature'] && !this._verifySignature(provider, payload, headers['x-signature'])) {
        throw new Error('Invalid webhook signature');
      }

      const handler = this.webhookHandlers.get(provider);
      if (!handler) {
        throw new Error(`No handler registered for provider: ${provider}`);
      }

      // Process webhook
      const result = await handler(payload, headers);

      // Store in history
      this.webhookHistory.push({
        provider,
        payload,
        result,
        timestamp: new Date()
      });

      // Keep only last 1000 webhooks
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

  /**
   * GitHub webhook handler
   */
  async handleGitHubWebhook(payload, headers) {
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

  /**
   * Notion webhook handler
   */
  async handleNotionWebhook(payload, headers) {
    try {
      // Notion webhook processing
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

  /**
   * Trello webhook handler
   */
  async handleTrelloWebhook(payload, headers) {
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

  _verifySignature(provider, payload, signature) {
    // Verify webhook signature based on provider
    const secret = process.env[`${provider.toUpperCase()}_WEBHOOK_SECRET`];
    if (!secret) return true; // No secret configured, allow

    const hmac = crypto.createHmac('sha256', secret);
    const digest = hmac.update(JSON.stringify(payload)).digest('hex');
    const expectedSignature = `sha256=${digest}`;

    return crypto.timingSafeEqual(
      Buffer.from(signature),
      Buffer.from(expectedSignature)
    );
  }

  async _handleGitHubIssue(payload) {
    // Convert GitHub issue to task
    return {
      type: 'task_created',
      source: 'github',
      sourceId: payload.issue.id,
      title: payload.issue.title,
      description: payload.issue.body,
      status: payload.issue.state === 'open' ? 'pending' : 'completed'
    };
  }

  async _handleGitHubPR(payload) {
    // Convert GitHub PR to task
    return {
      type: 'task_created',
      source: 'github',
      sourceId: payload.pull_request.id,
      title: `PR: ${payload.pull_request.title}`,
      description: payload.pull_request.body,
      status: payload.pull_request.state
    };
  }

  async _handleGitHubPush(payload) {
    // Handle code push events
    return {
      type: 'activity',
      source: 'github',
      commits: payload.commits.length
    };
  }

  async _handleTrelloCardCreate(action) {
    return {
      type: 'task_created',
      source: 'trello',
      sourceId: action.data.card.id,
      title: action.data.card.name,
      description: action.data.card.desc,
      status: 'pending'
    };
  }

  async _handleTrelloCardUpdate(action) {
    return {
      type: 'task_updated',
      source: 'trello',
      sourceId: action.data.card.id,
      changes: action.data.old
    };
  }

  getWebhookHistory(provider = null, limit = 100) {
    let history = this.webhookHistory;
    
    if (provider) {
      history = history.filter(h => h.provider === provider);
    }

    return history.slice(-limit).reverse();
  }
}

module.exports = new WebhookService();


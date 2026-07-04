import { Request, Response } from 'express';
import { secureLog } from '@team-deepiri/shared-utils';
import axios from 'axios';

export type Channel = 'email' | 'push' | 'in-app' | 'webhook' | 'sms' | 'slack' | 'discord';

export interface MessageTemplate {
  id: string;
  name: string;
  channel: Channel;
  subject?: string;
  body: string;
  variables: string[];
  locale: string;
  version: number;
}

export interface MessagePayload {
  id: string;
  templateId?: string;
  channel: Channel;
  recipient: string;
  subject?: string;
  body: string;
  priority: 'low' | 'normal' | 'high' | 'critical';
  metadata?: Record<string, any>;
}

export interface DeliveryStatus {
  messageId: string;
  status: 'queued' | 'sent' | 'delivered' | 'opened' | 'failed';
  timestamp: string;
  channel: Channel;
  error?: string;
}

export interface PreferenceCenter {
  userId: string;
  channels: Record<Channel, boolean>;
  quietHours: {
    enabled: boolean;
    start: string;
    end: string;
    timezone: string;
  };
  frequency: 'immediate' | 'daily' | 'weekly';
}

export class CommunicationsHub {
  private templates: Map<string, MessageTemplate> = new Map();
  private queue: MessagePayload[] = [];

  async send(pPayload: MessagePayload): Promise<DeliveryStatus> {
    const existing = await this.checkIdempotency(pPayload.id);
    if (existing) {
      return existing;
    }

    const prefCheck = await this.checkPreferences(pPayload.recipient, pPayload.channel);
    if (!prefCheck.allowed) {
      return {
        messageId: pPayload.id,
        status: 'failed',
        timestamp: new Date().toISOString(),
        channel: pPayload.channel,
        error: 'Preferences blocked'
      };
    }

    this.queue.push(pPayload);

    let status: DeliveryStatus;
    switch (pPayload.channel) {
      case 'email':
        status = await this.sendEmail(pPayload);
        break;
      case 'push':
        status = await this.sendPush(pPayload);
        break;
      case 'webhook':
        status = await this.sendWebhook(pPayload);
        break;
      default:
        status = await this.sendInApp(pPayload);
    }

    await this.recordDeliveryStatus(status);
    return status;
  }

  async sendBatch(
    payloads: MessagePayload[],
    mode: 'parallel' | 'sequential' = 'parallel'
  ): Promise<DeliveryStatus[]> {
    if (mode === 'parallel') {
      return Promise.all(payloads.map(p => this.send(p)));
    }

    const results: DeliveryStatus[] = [];
    for (const p of payloads) {
      results.push(await this.send(p));
    }
    return results;
  }

  private async sendEmail(pPayload: MessagePayload): Promise<DeliveryStatus> {
    return {
      messageId: pPayload.id,
      status: 'sent',
      timestamp: new Date().toISOString(),
      channel: 'email'
    };
  }

  private async sendPush(pPayload: MessagePayload): Promise<DeliveryStatus> {
    return {
      messageId: pPayload.id,
      status: 'sent',
      timestamp: new Date().toISOString(),
      channel: 'push'
    };
  }

  private isPrivateOrLocalAddress(hostname: string): boolean {
    const normalized = hostname.trim().toLowerCase();
    if (normalized === 'localhost' || normalized === '::1') {
      return true;
    }

    const ipv4Match = normalized.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
    if (ipv4Match) {
      const octets = ipv4Match.slice(1).map(Number);
      if (octets.some(o => o < 0 || o > 255)) {
        return true;
      }

      const [a, b] = octets;
      return (
        a === 10 ||
        a === 127 ||
        (a === 169 && b === 254) ||
        (a === 172 && b >= 16 && b <= 31) ||
        (a === 192 && b === 168) ||
        a === 0
      );
    }

    return false;
  }

  private isAllowedWebhookUrl(rawUrl: string): boolean {
    let parsed: URL;
    try {
      parsed = new URL(rawUrl);
    } catch {
      return false;
    }

    if (!['http:', 'https:'].includes(parsed.protocol)) {
      return false;
    }

    if (parsed.username || parsed.password) {
      return false;
    }

    if (this.isPrivateOrLocalAddress(parsed.hostname)) {
      return false;
    }

    const rawAllowlist = process.env.WEBHOOK_HOST_ALLOWLIST;
    if (!rawAllowlist) {
      return false;
    }

    const allowedHosts = rawAllowlist
      .split(',')
      .map(h => h.trim().toLowerCase())
      .filter(Boolean);

    if (allowedHosts.length === 0) {
      return false;
    }

    return allowedHosts.includes(parsed.hostname.toLowerCase());
  }

  private async sendWebhook(pPayload: MessagePayload): Promise<DeliveryStatus> {
    try {
      if (!this.isAllowedWebhookUrl(pPayload.recipient)) {
        return {
          messageId: pPayload.id,
          status: 'failed',
          timestamp: new Date().toISOString(),
          channel: 'webhook',
          error: 'Invalid or disallowed webhook URL'
        };
      }

      await axios.post(pPayload.recipient, {
        message: pPayload.body,
        metadata: pPayload.metadata
      });
      return {
        messageId: pPayload.id,
        status: 'sent',
        timestamp: new Date().toISOString(),
        channel: 'webhook'
      };
    } catch (error: any) {
      return {
        messageId: pPayload.id,
        status: 'failed',
        timestamp: new Date().toISOString(),
        channel: 'webhook',
        error: error.message
      };
    }
  }

  private async sendInApp(pPayload: MessagePayload): Promise<DeliveryStatus> {
    return {
      messageId: pPayload.id,
      status: 'delivered',
      timestamp: new Date().toISOString(),
      channel: 'in-app'
    };
  }

  async registerTemplate(template: MessageTemplate): Promise<void> {
    this.templates.set(template.id, template);
    secureLog('info', 'Template registered', { templateId: template.id });
  }

  async getTemplate(templateId: string): Promise<MessageTemplate | null> {
    return this.templates.get(templateId) || null;
  }

  async checkPreferences(
    userId: string,
    channel: Channel
  ): Promise<{ allowed: boolean; reason?: string }> {
    const prefs = await this.getPreferenceCenter(userId);

    if (!prefs.channels[channel]) {
      return { allowed: false, reason: `Channel ${channel} disabled` };
    }

    if (prefs.quietHours.enabled) {
      const now = new Date();
      const hour = now.getHours();
      const start = parseInt(prefs.quietHours.start.split(':')[0]);
      const end = parseInt(prefs.quietHours.end.split(':')[0]);

      if (hour >= start && hour < end) {
        return { allowed: false, reason: 'Quiet hours active' };
      }
    }

    return { allowed: true };
  }

  async getPreferenceCenter(userId: string): Promise<PreferenceCenter> {
    return {
      userId,
      channels: {
        email: true,
        push: true,
        'in-app': true,
        webhook: true,
        sms: false,
        slack: false,
        discord: false
      },
      quietHours: {
        enabled: false,
        start: '22:00',
        end: '08:00',
        timezone: 'UTC'
      },
      frequency: 'immediate'
    };
  }

  async setPreferenceCenter(userId: string, prefs: PreferenceCenter): Promise<void> {
    secureLog('info', 'Preferences updated', { userId });
  }

  async checkIdempotency(messageId: string): Promise<DeliveryStatus | null> {
    return null;
  }

  async recordDeliveryStatus(status: DeliveryStatus): Promise<void> {
    secureLog('info', 'Delivery status recorded', { messageId: status.messageId, status: status.status });
  }

  async getDeliveryStatus(messageId: string): Promise<DeliveryStatus | null> {
    return null;
  }
}

export const communicationsHub = new CommunicationsHub();

export async function handleSend(req: Request, res: Response): Promise<void> {
  try {
    const payload = req.body;
    const status = await communicationsHub.send(payload);
    res.json(status);
  } catch (error: any) {
    secureLog('error', 'Send error:', error);
    res.status(500).json({ error: 'Failed to send message' });
  }
}

export async function handleSendBatch(req: Request, res: Response): Promise<void> {
  try {
    const { payloads, mode } = req.body;
    const results = await communicationsHub.sendBatch(payloads, mode);
    res.json(results);
  } catch (error: any) {
    secureLog('error', 'Batch send error:', error);
    res.status(500).json({ error: 'Failed to send batch' });
  }
}

export async function handleRegisterTemplate(req: Request, res: Response): Promise<void> {
  try {
    await communicationsHub.registerTemplate(req.body);
    res.json({ success: true });
  } catch (error: any) {
    secureLog('error', 'Template registration error:', error);
    res.status(500).json({ error: 'Failed to register template' });
  }
}

export async function handleGetPreferences(req: Request, res: Response): Promise<void> {
  try {
    const { userId } = req.body;
    const prefs = await communicationsHub.getPreferenceCenter(userId);
    res.json(prefs);
  } catch (error: any) {
    secureLog('error', 'Get preferences error:', error);
    res.status(500).json({ error: 'Failed to get preferences' });
  }
}

export async function handleSetPreferences(req: Request, res: Response): Promise<void> {
  try {
    const { userId, ...prefs } = req.body;
    await communicationsHub.setPreferenceCenter(userId, prefs);
    res.json({ success: true });
  } catch (error: any) {
    secureLog('error', 'Set preferences error:', error);
    res.status(500).json({ error: 'Failed to set preferences' });
  }
}
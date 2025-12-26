import axios from 'axios';
import { AuditLog } from '../storage/audit-log';

export interface NotificationConfig {
  email?: string;
  slackWebhook?: string;
  smsApiKey?: string;
}

export class NotificationService {
  private config: NotificationConfig;
  private auditLog: AuditLog;

  constructor(config: NotificationConfig, auditLog: AuditLog) {
    this.config = config;
    this.auditLog = auditLog;
  }

  async sendAlert(
    level: 'lock' | 'warn' | 'delete' | 'immediate',
    repo: string,
    risk: number,
    details?: Record<string, any>
  ): Promise<void> {
    const message = this.formatMessage(level, repo, risk, details);

    // Send to all configured channels
    const promises: Promise<void>[] = [];

    if (this.config.email) {
      promises.push(this.sendEmail(this.config.email, message, level));
    }

    if (this.config.slackWebhook) {
      promises.push(this.sendSlack(this.config.slackWebhook, message, level));
    }

    if (this.config.smsApiKey) {
      promises.push(this.sendSMS(this.config.smsApiKey, message, level));
    }

    await Promise.allSettled(promises);

    await this.auditLog.logAction('notification_sent', repo, risk, {
      level,
      channels: Object.keys(this.config).filter(k => this.config[k as keyof NotificationConfig]),
    });
  }

  private formatMessage(
    level: string,
    repo: string,
    risk: number,
    details?: Record<string, any>
  ): string {
    const levelEmoji = {
      lock: '🔒',
      warn: '⚠️',
      delete: '🗑️',
      immediate: '🚨',
    };

    return `
${levelEmoji[level as keyof typeof levelEmoji]} Sovereignty Enforcement Alert

Level: ${level.toUpperCase()}
Repository: ${repo}
Risk Score: ${risk}

${details ? `Details: ${JSON.stringify(details, null, 2)}` : ''}

Timestamp: ${new Date().toISOString()}
    `.trim();
  }

  private async sendEmail(email: string, message: string, level: string): Promise<void> {
    // Implementation would use email service (SendGrid, SES, etc.)
    // For now, just log
    console.log(`Email to ${email}: ${message}`);
  }

  private async sendSlack(webhook: string, message: string, level: string): Promise<void> {
    try {
      await axios.post(webhook, {
        text: message,
        username: 'Sovereignty Enforcement',
        icon_emoji: level === 'immediate' ? ':rotating_light:' : ':warning:',
      });
    } catch (error: any) {
      console.error('Failed to send Slack notification:', error);
    }
  }

  private async sendSMS(apiKey: string, message: string, level: string): Promise<void> {
    // Implementation would use SMS service (Twilio, etc.)
    // For now, just log
    console.log(`SMS: ${message}`);
  }
}


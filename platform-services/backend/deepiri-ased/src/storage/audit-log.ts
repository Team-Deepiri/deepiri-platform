import axios from 'axios';
import * as fs from 'fs';
import * as path from 'path';

export interface AuditLogEntry {
  timestamp: Date;
  action: string;
  repo?: string;
  risk?: number;
  details?: Record<string, any>;
  level: 'info' | 'warn' | 'error' | 'critical';
}

export class AuditLog {
  private storageUrl?: string;
  private storageKey?: string;
  private localPath: string;

  constructor(storageUrl?: string, storageKey?: string) {
    this.storageUrl = storageUrl;
    this.storageKey = storageKey;
    this.localPath = path.join(process.cwd(), 'data', 'audit.log');
    this.ensureDirectory();
  }

  private ensureDirectory(): void {
    const dir = path.dirname(this.localPath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
  }

  async log(entry: AuditLogEntry): Promise<void> {
    const logEntry = {
      ...entry,
      timestamp: entry.timestamp.toISOString(),
    };

    // Log locally
    const logLine = JSON.stringify(logEntry) + '\n';
    fs.appendFileSync(this.localPath, logLine, 'utf-8');

    // Log to external storage if configured
    if (this.storageUrl) {
      try {
        await axios.post(this.storageUrl, logEntry, {
          headers: {
            'Authorization': `Bearer ${this.storageKey}`,
            'Content-Type': 'application/json',
          },
        });
      } catch (error) {
        console.error('Failed to send audit log to external storage:', error);
      }
    }
  }

  async logAction(action: string, repo?: string, risk?: number, details?: Record<string, any>): Promise<void> {
    await this.log({
      timestamp: new Date(),
      action,
      repo,
      risk,
      details,
      level: risk && risk >= 10 ? 'critical' : risk && risk >= 6 ? 'warn' : 'info',
    });
  }
}


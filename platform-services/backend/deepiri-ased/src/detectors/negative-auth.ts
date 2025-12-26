import { GitHubClient } from '../github/github-client';
import { NegativeAuthEvent } from '../github/github-types';

export class NegativeAuthDetector {
  private githubClient: GitHubClient;
  private org: string;
  private lastCheckTime: Date = new Date(0);

  constructor(githubClient: GitHubClient, org: string) {
    this.githubClient = githubClient;
    this.org = org;
  }

  async check(): Promise<{ risk: number; events: NegativeAuthEvent[] }> {
    try {
      const events = await this.githubClient.fetchAuditLog(this.org, this.lastCheckTime);
      this.lastCheckTime = new Date();

      const negativeEvents: NegativeAuthEvent[] = [];
      let totalRisk = 0;

      for (const event of events) {
        const negativeEvent = this.parseEvent(event);
        if (negativeEvent) {
          negativeEvents.push(negativeEvent);
          totalRisk += negativeEvent.severity;
        }
      }

      return {
        risk: totalRisk,
        events: negativeEvents,
      };
    } catch (error: any) {
      return { risk: 0, events: [] };
    }
  }

  private parseEvent(event: any): NegativeAuthEvent | null {
    const eventType = event.type?.toLowerCase() || '';
    
    // Map GitHub event types to negative auth events
    if (eventType.includes('member') && event.payload?.action === 'removed') {
      return {
        type: 'admin_removed',
        timestamp: new Date(event.timestamp || event.created_at),
        severity: 5,
        repo: event.repo,
        details: event.payload,
      };
    }

    if (eventType.includes('repository') && event.payload?.action === 'transferred') {
      return {
        type: 'repo_transferred',
        timestamp: new Date(event.timestamp || event.created_at),
        severity: 10,
        repo: event.repo,
        details: event.payload,
      };
    }

    if (eventType.includes('repository') && event.payload?.action === 'archived') {
      return {
        type: 'permission_downgraded',
        timestamp: new Date(event.timestamp || event.created_at),
        severity: 4,
        repo: event.repo,
        details: event.payload,
      };
    }

    return null;
  }
}


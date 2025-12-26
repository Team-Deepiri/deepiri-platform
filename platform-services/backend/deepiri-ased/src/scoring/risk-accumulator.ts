import { SecurityEvent } from '../github/github-types';

export interface RiskScore {
  current: number;
  lastUpdate: Date;
  events: SecurityEvent[];
  repo?: string;
}

export class RiskAccumulator {
  private scores: Map<string, RiskScore> = new Map();

  addEvent(repo: string, event: SecurityEvent): void {
    let score = this.scores.get(repo);
    
    if (!score) {
      score = {
        current: 0,
        lastUpdate: new Date(),
        events: [],
        repo,
      };
      this.scores.set(repo, score);
    }

    score.current += event.severity;
    score.events.push(event);
    score.lastUpdate = new Date();
  }

  addRisk(repo: string, risk: number, eventType?: string): void {
    if (risk === 0) return;

    const event: SecurityEvent = {
      type: eventType || 'detection',
      timestamp: new Date(),
      severity: risk,
      repo,
    };

    this.addEvent(repo, event);
  }

  getScore(repo: string): number {
    const score = this.scores.get(repo);
    return score ? score.current : 0;
  }

  getScoreObject(repo: string): RiskScore | undefined {
    return this.scores.get(repo);
  }

  getAllScores(): Map<string, RiskScore> {
    return new Map(this.scores);
  }

  reset(repo: string): void {
    this.scores.delete(repo);
  }

  resetAll(): void {
    this.scores.clear();
  }
}


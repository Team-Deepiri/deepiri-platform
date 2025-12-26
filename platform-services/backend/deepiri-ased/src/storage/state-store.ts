import * as fs from 'fs';
import * as path from 'path';
import { RiskScore } from '../scoring/risk-accumulator';

export class StateStore {
  private filePath: string;

  constructor(filePath?: string) {
    this.filePath = filePath || path.join(process.cwd(), 'data', 'state.json');
    this.ensureDirectory();
  }

  private ensureDirectory(): void {
    const dir = path.dirname(this.filePath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
  }

  saveRiskScores(scores: Map<string, RiskScore>): void {
    const data = {
      scores: Array.from(scores.entries()).map(([repo, score]) => ({
        repo,
        current: score.current,
        lastUpdate: score.lastUpdate.toISOString(),
        events: score.events.map(e => ({
          type: e.type,
          timestamp: e.timestamp.toISOString(),
          severity: e.severity,
          repo: e.repo,
        })),
      })),
      updated: new Date().toISOString(),
    };

    fs.writeFileSync(this.filePath, JSON.stringify(data, null, 2), 'utf-8');
  }

  loadRiskScores(): Map<string, RiskScore> {
    if (!fs.existsSync(this.filePath)) {
      return new Map();
    }

    try {
      const data = JSON.parse(fs.readFileSync(this.filePath, 'utf-8'));
      const scores = new Map<string, RiskScore>();

      for (const item of data.scores || []) {
        scores.set(item.repo, {
          current: item.current,
          lastUpdate: new Date(item.lastUpdate),
          events: (item.events || []).map((e: any) => ({
            type: e.type,
            timestamp: new Date(e.timestamp),
            severity: e.severity,
            repo: e.repo,
          })),
          repo: item.repo,
        });
      }

      return scores;
    } catch (error) {
      console.error('Failed to load risk scores:', error);
      return new Map();
    }
  }
}


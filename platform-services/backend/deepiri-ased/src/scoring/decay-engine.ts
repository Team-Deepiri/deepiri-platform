import { RiskAccumulator, RiskScore } from './risk-accumulator';

export class DecayEngine {
  private decayRate: number; // per hour
  private minScore: number;

  constructor(decayRate: number = 1, minScore: number = 0) {
    this.decayRate = decayRate;
    this.minScore = minScore;
  }

  applyDecay(accumulator: RiskAccumulator): void {
    const now = new Date();
    const scores = accumulator.getAllScores();

    for (const [repo, score] of scores.entries()) {
      const hoursSinceUpdate = (now.getTime() - score.lastUpdate.getTime()) / (1000 * 60 * 60);
      const decay = Math.floor(hoursSinceUpdate) * this.decayRate;
      
      const newScore = Math.max(this.minScore, score.current - decay);
      
      if (newScore !== score.current) {
        score.current = newScore;
        score.lastUpdate = now;
        
        // If score reached minimum, remove old events
        if (newScore === this.minScore && score.events.length > 0) {
          score.events = score.events.filter(e => {
            const eventAge = (now.getTime() - e.timestamp.getTime()) / (1000 * 60 * 60);
            return eventAge < 24; // Keep events from last 24 hours
          });
        }
      }
    }
  }
}


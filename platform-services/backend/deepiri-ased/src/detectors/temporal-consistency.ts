interface FailureWindow {
  repo: string;
  startTime: Date;
  consecutiveFailures: number;
  lastSuccess: Date | null;
}

export class TemporalConsistencyDetector {
  private failureWindows: Map<string, FailureWindow> = new Map();
  private requiredFailures: number;
  private timeWindowHours: number;

  constructor(requiredFailures: number = 12, timeWindowHours: number = 6) {
    this.requiredFailures = requiredFailures;
    this.timeWindowHours = timeWindowHours;
  }

  check(repo: string, risk: number): { risk: number; window: FailureWindow } {
    let window = this.failureWindows.get(repo);

    if (!window) {
      window = {
        repo,
        startTime: new Date(),
        consecutiveFailures: 0,
        lastSuccess: null,
      };
      this.failureWindows.set(repo, window);
    }

    if (risk > 0) {
      // Failure detected
      window.consecutiveFailures++;
      window.lastSuccess = null;
    } else {
      // Success resets counter
      window.consecutiveFailures = 0;
      window.lastSuccess = new Date();
      window.startTime = new Date();
    }

    // Check if we meet the temporal consistency requirements
    const hoursSinceStart = (Date.now() - window.startTime.getTime()) / (1000 * 60 * 60);

    if (window.consecutiveFailures >= this.requiredFailures && hoursSinceStart >= this.timeWindowHours) {
      // Requirements met, return the risk
      return { risk, window };
    }

    // Requirements not met, return 0 risk
    return { risk: 0, window };
  }

  reset(repo: string): void {
    this.failureWindows.delete(repo);
  }

  getWindow(repo: string): FailureWindow | undefined {
    return this.failureWindows.get(repo);
  }
}


export interface Thresholds {
  lock: number;
  warn: number;
  delete: number;
  immediate: number;
}

export class ThresholdManager {
  private thresholds: Thresholds;

  constructor(thresholds: Thresholds) {
    this.thresholds = thresholds;
  }

  checkThresholds(risk: number): {
    level: 'none' | 'lock' | 'warn' | 'delete' | 'immediate';
    threshold: number;
  } {
    if (risk >= this.thresholds.immediate) {
      return { level: 'immediate', threshold: this.thresholds.immediate };
    }
    if (risk >= this.thresholds.delete) {
      return { level: 'delete', threshold: this.thresholds.delete };
    }
    if (risk >= this.thresholds.warn) {
      return { level: 'warn', threshold: this.thresholds.warn };
    }
    if (risk >= this.thresholds.lock) {
      return { level: 'lock', threshold: this.thresholds.lock };
    }
    return { level: 'none', threshold: 0 };
  }

  getGracePeriod(level: 'lock' | 'warn' | 'delete' | 'immediate', gracePeriods: {
    lock: number;
    warn: number;
    delete: number;
    immediate: number;
  }): number {
    return gracePeriods[level];
  }
}


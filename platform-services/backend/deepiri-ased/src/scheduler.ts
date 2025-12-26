import * as cron from 'node-cron';
import { Orchestrator } from './orchestrator';
import { loadConfig } from './config';
import { createLogger } from '@deepiri/shared-utils';

const logger = createLogger('scheduler');

export class Scheduler {
  private orchestrator: Orchestrator;
  private config: ReturnType<typeof loadConfig>;
  private jobs: cron.ScheduledTask[] = [];

  constructor(orchestrator: Orchestrator) {
    this.orchestrator = orchestrator;
    this.config = loadConfig();
  }

  start(): void {
    logger.info('Starting scheduler');

    // State invariant check (every 5-15 minutes based on config)
    const stateCheckInterval = this.config.detection.stateInvariant.checkInterval;
    const stateCheckCron = `*/${stateCheckInterval} * * * *`; // Every N minutes
    this.jobs.push(
      cron.schedule(stateCheckCron, async () => {
        logger.debug('Running state invariant check');
        await this.orchestrator.runDetectionCycle();
      })
    );

    // Write canary check (every hour by default)
    const canaryInterval = this.config.detection.writeCanary.interval;
    const canaryCron = `*/${canaryInterval} * * * *`; // Every N minutes
    this.jobs.push(
      cron.schedule(canaryCron, async () => {
        logger.debug('Running write canary check');
        await this.orchestrator.runDetectionCycle();
      })
    );

    // Audit log check (every 15 minutes by default)
    const auditInterval = this.config.detection.negativeAuth.auditLogInterval;
    const auditCron = `*/${auditInterval} * * * *`; // Every N minutes
    this.jobs.push(
      cron.schedule(auditCron, async () => {
        logger.debug('Running audit log check');
        await this.orchestrator.runDetectionCycle();
      })
    );

    // Risk score decay (every hour)
    this.jobs.push(
      cron.schedule('0 * * * *', async () => {
        logger.debug('Applying risk score decay');
        await this.orchestrator.runDetectionCycle();
      })
    );

    logger.info(`Scheduler started with ${this.jobs.length} jobs`);
  }

  stop(): void {
    logger.info('Stopping scheduler');
    for (const job of this.jobs) {
      job.stop();
    }
    this.jobs = [];
  }
}


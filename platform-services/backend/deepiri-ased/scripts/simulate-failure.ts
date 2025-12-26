import dotenv from 'dotenv';
import { Orchestrator } from '../src/orchestrator';
import { createLogger } from '@deepiri/shared-utils';

dotenv.config();

const logger = createLogger('simulate-failure');

async function main() {
  const repo = process.argv[2] || 'deepiri-platform';
  const risk = parseInt(process.argv[3] || '10', 10);

  try {
    logger.info(`Simulating failure for ${repo} with risk ${risk}`);

    const orchestrator = new Orchestrator();
    await orchestrator.initialize();

    // Manually add risk to simulate failure
    (orchestrator as any).scoring.accumulator.addRisk(repo, risk, 'simulated_failure');

    logger.info('Running detection cycle with simulated failure...');
    await orchestrator.runDetectionCycle();

    const score = (orchestrator as any).scoring.accumulator.getScore(repo);
    logger.info(`Current risk score for ${repo}: ${score}`);

    const threshold = (orchestrator as any).scoring.thresholds.checkThresholds(score);
    logger.info(`Threshold level: ${threshold.level}`);

    process.exit(0);
  } catch (error: any) {
    logger.error('Simulation failed:', error);
    process.exit(1);
  }
}

main();


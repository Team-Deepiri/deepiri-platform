import dotenv from 'dotenv';
import { Orchestrator } from '../src/orchestrator';
import { createLogger } from '@deepiri/shared-utils';

dotenv.config();

const logger = createLogger('test-detection');

async function main() {
  try {
    logger.info('Testing detection mechanisms...');

    const orchestrator = new Orchestrator();
    await orchestrator.initialize();

    logger.info('Running detection cycle...');
    await orchestrator.runDetectionCycle();

    const scores = (orchestrator as any).scoring.accumulator.getAllScores();
    
    if (scores.size === 0) {
      logger.info('No risk scores detected - all checks passed');
    } else {
      logger.warn(`Risk scores detected for ${scores.size} repositories:`);
      for (const [repo, score] of scores.entries()) {
        logger.warn(`  - ${repo}: ${score.current} (${score.events.length} events)`);
      }
    }

    process.exit(0);
  } catch (error: any) {
    logger.error('Test failed:', error);
    process.exit(1);
  }
}

main();


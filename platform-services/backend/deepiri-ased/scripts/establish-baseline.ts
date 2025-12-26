import dotenv from 'dotenv';
import { GitHubClient } from '../src/github/github-client';
import { BaselineManager } from '../src/baseline/baseline-manager';
import { BaselineStorage } from '../src/baseline/baseline-storage';
import { loadConfig } from '../src/config';
import { createLogger } from '@deepiri/shared-utils';

dotenv.config();

const logger = createLogger('establish-baseline');

async function main() {
  try {
    const config = loadConfig();
    
    logger.info('Establishing baseline configuration...');
    logger.info(`Critical repos: ${config.detection.crossRepo.criticalRepos.join(', ')}`);

    const githubClient = new GitHubClient(
      config.github.tokenA,
      config.github.tokenB,
      config.github.org
    );

    const baselineStorage = new BaselineStorage(
      config.storage.baselineUrl,
      config.storage.baselineKey
    );

    const baselineManager = new BaselineManager(githubClient, baselineStorage);

    const baseline = await baselineManager.establishBaseline(
      config.detection.crossRepo.criticalRepos
    );

    logger.info(`Baseline established successfully for ${Object.keys(baseline.repos).length} repositories`);
    logger.info(`Baseline version: ${baseline.version}`);
    logger.info(`Baseline timestamp: ${baseline.timestamp.toISOString()}`);

    for (const [repo, repoData] of Object.entries(baseline.repos)) {
      logger.info(`  - ${repo}: ${repoData.admins.length} admins, ${repoData.branchProtection.length} protected branches`);
    }

    process.exit(0);
  } catch (error: any) {
    logger.error('Failed to establish baseline:', error);
    process.exit(1);
  }
}

main();


import { loadConfig, ServiceConfig } from './config';
import { GitHubClient } from './github/github-client';
import { GitHubAppClient } from './github/github-app-client';
import { RepoDiscovery } from './github/repo-discovery';
import { GitHubAPI } from './github/github-api';
import { BaselineManager } from './baseline/baseline-manager';
import { BaselineStorage } from './baseline/baseline-storage';
import { StateInvariantDetector } from './detectors/state-invariant';
import { DualTokenDetector } from './detectors/dual-token';
import { NegativeAuthDetector } from './detectors/negative-auth';
import { WriteCanaryDetector } from './detectors/write-canary';
import { CrossRepoDetector } from './detectors/cross-repo';
import { TemporalConsistencyDetector } from './detectors/temporal-consistency';
import { RiskAccumulator } from './scoring/risk-accumulator';
import { DecayEngine } from './scoring/decay-engine';
import { ThresholdManager } from './scoring/threshold-manager';
import { LockServices } from './responders/lock-services';
import { BackupManager } from './responders/backup-manager';
import { NotificationService } from './responders/notify';
import { DeleteRepos } from './responders/delete-repos';
import { AuditLog } from './storage/audit-log';
import { StateStore } from './storage/state-store';
import { createLogger } from '@deepiri/shared-utils';

const logger = createLogger('sovereignty-enforcement');

export class Orchestrator {
  private config: ServiceConfig;
  private githubClient: GitHubClient | GitHubAppClient;
  private baselineManager: BaselineManager;
  private isGitHubApp: boolean = false;
  private detectors: {
    stateInvariant: StateInvariantDetector;
    dualToken: DualTokenDetector;
    negativeAuth: NegativeAuthDetector;
    writeCanary: WriteCanaryDetector;
    crossRepo: CrossRepoDetector;
    temporalConsistency: TemporalConsistencyDetector;
  };
  private scoring: {
    accumulator: RiskAccumulator;
    decay: DecayEngine;
    thresholds: ThresholdManager;
  };
  private responders: {
    lock: LockServices;
    backup: BackupManager;
    notify: NotificationService;
    delete: DeleteRepos;
  };
  private storage: {
    auditLog: AuditLog;
    stateStore: StateStore;
  };
  private responseStates: Map<string, {
    level: 'lock' | 'warn' | 'delete' | 'immediate';
    timestamp: Date;
  }> = new Map();

  constructor() {
    this.config = loadConfig();
    
    // Initialize GitHub client (GitHub App preferred, fallback to tokens)
    if (this.config.github.appId && this.config.github.installationId && this.config.github.privateKey) {
      // Use GitHub App
      const appClient = new GitHubAppClient(
        this.config.github.appId,
        this.config.github.installationId,
        this.config.github.privateKey,
        this.config.github.org
      );
      
      this.githubClient = appClient as any;
      this.isGitHubApp = true;
      
      // Auto-discover repos if enabled
      if (this.config.github.autoDiscoverRepos) {
        const discovery = new RepoDiscovery(appClient, this.config.github.repoPattern);
        discovery.getCriticalRepos().then(repos => {
          this.config.detection.crossRepo.criticalRepos = repos;
          logger.info(`Auto-discovered ${repos.length} repositories: ${repos.join(', ')}`);
        }).catch(err => {
          logger.warn('Auto-discovery failed, using configured repos:', err);
        });
      }
    } else if (this.config.github.tokenA && this.config.github.tokenB) {
      // Fallback to personal access tokens
      this.githubClient = new GitHubClient(
        this.config.github.tokenA,
        this.config.github.tokenB,
        this.config.github.org
      );
      this.isGitHubApp = false;
    } else {
      throw new Error('GitHub authentication not configured. Need either GitHub App credentials or personal access tokens.');
    }

    // Initialize baseline
    const baselineStorage = new BaselineStorage(
      this.config.storage.baselineUrl,
      this.config.storage.baselineKey
    );
    this.baselineManager = new BaselineManager(this.githubClient, baselineStorage);

    // Initialize storage
    this.storage = {
      auditLog: new AuditLog(
        this.config.storage.auditLogUrl,
        this.config.storage.auditLogKey
      ),
      stateStore: new StateStore(),
    };

    // Initialize detectors
    const stateInvariant = new StateInvariantDetector(this.githubClient, this.baselineManager);
    const dualToken = new DualTokenDetector(this.githubClient);
    const negativeAuth = new NegativeAuthDetector(this.githubClient, this.config.github.org);
    const writeCanary = new WriteCanaryDetector(this.githubClient);
    const crossRepo = new CrossRepoDetector(
      this.githubClient,
      stateInvariant,
      dualToken,
      writeCanary,
      this.config.detection.crossRepo.criticalRepos,
      this.config.detection.crossRepo.failureThreshold
    );
    const temporalConsistency = new TemporalConsistencyDetector(
      this.config.detection.temporalConsistency.requiredFailures,
      this.config.detection.temporalConsistency.timeWindow
    );

    this.detectors = {
      stateInvariant,
      dualToken,
      negativeAuth,
      writeCanary,
      crossRepo,
      temporalConsistency,
    };

    // Initialize scoring
    this.scoring = {
      accumulator: new RiskAccumulator(),
      decay: new DecayEngine(
        this.config.scoring.decay.rate,
        this.config.scoring.decay.minScore
      ),
      thresholds: new ThresholdManager(this.config.response.thresholds),
    };

    // Initialize responders
    const backupManager = new BackupManager(this.githubClient, this.storage.auditLog);
    this.responders = {
      lock: new LockServices(this.storage.auditLog),
      backup: backupManager,
      notify: new NotificationService(this.config.notifications, this.storage.auditLog),
      delete: new DeleteRepos(
        this.githubClient,
        this.storage.auditLog,
        backupManager,
        this.config.response.backupBeforeDelete
      ),
    };

    // Load persisted state
    this.loadState();
  }

  async initialize(): Promise<void> {
    try {
      // Try to load baseline, if it doesn't exist and we have GitHub auth, establish it
      const baseline = await this.baselineManager.loadBaseline();
      
      if (!baseline) {
        logger.warn('Baseline not found. Attempting to establish baseline...');
        
        // Get repos to baseline (from config or auto-discover)
        let repos = this.config.detection.crossRepo.criticalRepos;
        
        // If auto-discovery is enabled and we have GitHub App, discover repos
        if (this.config.github.autoDiscoverRepos && this.isGitHubApp) {
          try {
            const discovery = new RepoDiscovery(this.githubClient as any, this.config.github.repoPattern);
            repos = await discovery.getCriticalRepos();
            this.config.detection.crossRepo.criticalRepos = repos;
            logger.info(`Auto-discovered ${repos.length} repositories for baseline`);
          } catch (err: any) {
            logger.warn('Auto-discovery failed during initialization, using configured repos:', err.message);
          }
        }
        
        // Establish baseline
        if (repos.length > 0) {
          try {
            await this.baselineManager.establishBaseline(repos);
            logger.info(`Baseline established for ${repos.length} repositories`);
          } catch (err: any) {
            logger.error('Failed to establish baseline:', err);
            logger.warn('Service will start but state invariant detection will not work until baseline is established');
          }
        } else {
          logger.warn('No repositories configured for baseline establishment');
        }
      }
      
      // Initialize state invariant detector (will load baseline)
      await this.detectors.stateInvariant.initialize();
      logger.info('Orchestrator initialized successfully');
    } catch (error: any) {
      logger.error('Failed to initialize orchestrator:', error);
      // Don't throw - allow service to start even if baseline fails
      // It will retry on first detection cycle
    }
  }

  async runDetectionCycle(): Promise<void> {
    logger.info('Starting detection cycle');

    try {
      // Run all detectors
      const detectionResults: Map<string, number> = new Map();

      // State invariant checks
      if (this.config.detection.stateInvariant.enabled) {
        for (const repo of this.config.detection.crossRepo.criticalRepos) {
          const result = await this.detectors.stateInvariant.check(repo);
          detectionResults.set(`${repo}-state`, result.risk);
        }
      }

      // Dual token checks (skip if using GitHub App - App handles auth differently)
      if (this.config.detection.dualToken.enabled && !this.isGitHubApp) {
        for (const repo of this.config.detection.crossRepo.criticalRepos) {
          const risk = await this.detectors.dualToken.check(repo);
          detectionResults.set(`${repo}-token`, risk);
        }
      }

      // Write canary checks
      if (this.config.detection.writeCanary.enabled) {
        for (const repo of this.config.detection.crossRepo.criticalRepos) {
          const risk = await this.detectors.writeCanary.check(repo);
          detectionResults.set(`${repo}-canary`, risk);
        }
      }

      // Negative auth check (global, not per repo)
      if (this.config.detection.negativeAuth.enabled) {
        const negativeAuthResult = await this.detectors.negativeAuth.check();
        for (const event of negativeAuthResult.events) {
          if (event.repo) {
            detectionResults.set(`${event.repo}-negative`, event.severity);
          }
        }
      }

      // Cross-repo correlation
      if (this.config.detection.crossRepo.enabled) {
        const crossRepoRisk = await this.detectors.crossRepo.check();
        if (crossRepoRisk > 0) {
          for (const repo of this.config.detection.crossRepo.criticalRepos) {
            detectionResults.set(`${repo}-cross`, crossRepoRisk);
          }
        }
      }

      // Accumulate risks
      for (const [key, risk] of detectionResults.entries()) {
        const repo = key.split('-')[0];
        this.scoring.accumulator.addRisk(repo, risk, key);
      }

      // Apply decay
      this.scoring.decay.applyDecay(this.scoring.accumulator);

      // Check thresholds and respond
      await this.checkAndRespond();

      // Persist state
      this.saveState();

      logger.info('Detection cycle completed');
    } catch (error: any) {
      logger.error('Error in detection cycle:', error);
      await this.storage.auditLog.logAction('detection_cycle_error', undefined, undefined, {
        error: error.message,
      });
    }
  }

  private async checkAndRespond(): Promise<void> {
    const scores = this.scoring.accumulator.getAllScores();

    for (const [repo, score] of scores.entries()) {
      const threshold = this.scoring.thresholds.checkThresholds(score.current);
      
      if (threshold.level === 'none') {
        continue;
      }

      const responseState = this.responseStates.get(repo);
      const now = new Date();

      // Check if we've already responded at this level
      if (responseState && responseState.level === threshold.level) {
        // Check grace period
        const gracePeriod = this.config.response.gracePeriods[threshold.level];
        const hoursSinceResponse = (now.getTime() - responseState.timestamp.getTime()) / (1000 * 60 * 60);
        
        if (hoursSinceResponse < gracePeriod) {
          // Still within grace period
          continue;
        }
      }

      // New threshold breached or grace period expired
      await this.respond(threshold.level, repo, score.current);
      this.responseStates.set(repo, {
        level: threshold.level,
        timestamp: now,
      });
    }
  }

  private async respond(level: 'lock' | 'warn' | 'delete' | 'immediate', repo: string, risk: number): Promise<void> {
    logger.warn(`Responding to ${level} threshold breach for ${repo} (risk: ${risk})`);

    await this.responders.notify.sendAlert(level, repo, risk);

    switch (level) {
      case 'lock':
        await this.responders.lock.lockAll([repo]);
        break;
      
      case 'warn':
        // Already locked, just notify
        break;
      
      case 'delete':
      case 'immediate':
        await this.responders.delete.deleteRepositories([repo]);
        break;
    }
  }

  private saveState(): void {
    try {
      const scores = this.scoring.accumulator.getAllScores();
      this.storage.stateStore.saveRiskScores(scores);
    } catch (error: any) {
      logger.error('Failed to save state:', error);
    }
  }

  private loadState(): void {
    try {
      const scores = this.storage.stateStore.loadRiskScores();
      for (const [repo, score] of scores.entries()) {
        this.scoring.accumulator.addRisk(repo, score.current);
      }
    } catch (error: any) {
      logger.error('Failed to load state:', error);
    }
  }
}


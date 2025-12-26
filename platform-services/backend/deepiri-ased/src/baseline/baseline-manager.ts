import { GitHubClient } from '../github/github-client';
import { BaselineStorage } from './baseline-storage';
import { BaselineValidator } from './baseline-validator';
import { BaselineConfig, RepoState } from '../github/github-types';
import * as crypto from 'crypto';

export class BaselineManager {
  private githubClient: GitHubClient;
  private storage: BaselineStorage;
  private validator: BaselineValidator;

  constructor(githubClient: GitHubClient, storage: BaselineStorage) {
    this.githubClient = githubClient;
    this.storage = storage;
    this.validator = new BaselineValidator();
  }

  async establishBaseline(repos: string[]): Promise<BaselineConfig> {
    const baseline: BaselineConfig = {
      version: '1.0.0',
      timestamp: new Date(),
      repos: {},
    };

    for (const repo of repos) {
      try {
        const state = await this.githubClient.fetchRepoState(repo);
        const fingerprint = await this.githubClient.fetchRepoFingerprint(repo);
        const submodules = await this.githubClient.fetchSubmoduleConfig(repo);
        const workflows = await this.githubClient.fetchWorkflowFiles(repo);

        const stateHash = this.hashRepoState(state);
        const branchProtection = state.branchProtection;

        baseline.repos[repo] = {
          stateHash,
          fingerprint,
          submodules,
          workflows,
          admins: state.admins,
          branchProtection,
        };
      } catch (error: any) {
        throw new Error(`Failed to establish baseline for ${repo}: ${error.message}`);
      }
    }

    // Validate baseline
    const validation = this.validator.validate(baseline);
    if (!validation.valid) {
      throw new Error(`Baseline validation failed: ${validation.errors.join(', ')}`);
    }

    // Save baseline
    await this.storage.save(baseline);

    return baseline;
  }

  async loadBaseline(): Promise<BaselineConfig | null> {
    const baseline = await this.storage.load();
    if (!baseline) {
      return null;
    }

    // Validate loaded baseline
    const validation = this.validator.validate(baseline);
    if (!validation.valid) {
      throw new Error(`Loaded baseline validation failed: ${validation.errors.join(', ')}`);
    }

    return baseline;
  }

  hashRepoState(state: RepoState): string {
    const normalized = {
      owner: state.owner,
      admins: state.admins.sort(),
      branchProtection: state.branchProtection.map(bp => ({
        branch: bp.branch,
        requiredReviewers: bp.requiredReviewers,
        requiredStatusChecks: bp.requiredStatusChecks.sort(),
        enforceAdmins: bp.enforceAdmins,
        allowForcePush: bp.allowForcePush,
        allowDeletions: bp.allowDeletions,
      })),
      webhooks: state.webhooks.map(wh => ({
        url: wh.url,
        events: wh.events.sort(),
        active: wh.active,
      })),
      defaultBranch: state.defaultBranch,
      visibility: state.visibility,
      archived: state.archived,
      disabled: state.disabled,
    };

    return crypto.createHash('sha256')
      .update(JSON.stringify(normalized))
      .digest('hex');
  }

  computeStateDiff(baselineState: RepoState, currentState: RepoState): {
    changes: string[];
    severity: 'low' | 'medium' | 'high' | 'critical';
  } {
    const changes: string[] = [];
    let severity: 'low' | 'medium' | 'high' | 'critical' = 'low';

    if (baselineState.owner !== currentState.owner) {
      changes.push(`Owner changed from ${baselineState.owner} to ${currentState.owner}`);
      severity = 'critical';
    }

    const removedAdmins = baselineState.admins.filter(a => !currentState.admins.includes(a));
    if (removedAdmins.length > 0) {
      changes.push(`Admins removed: ${removedAdmins.join(', ')}`);
      severity = severity === 'low' ? 'high' : 'critical';
    }

    const addedAdmins = currentState.admins.filter(a => !baselineState.admins.includes(a));
    if (addedAdmins.length > 0) {
      changes.push(`Admins added: ${addedAdmins.join(', ')}`);
      severity = severity === 'low' ? 'medium' : severity;
    }

    if (baselineState.defaultBranch !== currentState.defaultBranch) {
      changes.push(`Default branch changed from ${baselineState.defaultBranch} to ${currentState.defaultBranch}`);
      severity = severity === 'low' ? 'medium' : severity;
    }

    if (baselineState.visibility !== currentState.visibility) {
      changes.push(`Visibility changed from ${baselineState.visibility} to ${currentState.visibility}`);
      severity = severity === 'low' ? 'high' : 'critical';
    }

    if (baselineState.archived !== currentState.archived) {
      changes.push(`Archive status changed: ${currentState.archived ? 'archived' : 'unarchived'}`);
      severity = severity === 'low' ? 'medium' : severity;
    }

    // Check branch protection changes
    const baselineProtection = baselineState.branchProtection[0];
    const currentProtection = currentState.branchProtection[0];
    if (baselineProtection && !currentProtection) {
      changes.push('Branch protection removed');
      severity = 'high';
    } else if (!baselineProtection && currentProtection) {
      changes.push('Branch protection added');
      severity = 'low';
    } else if (baselineProtection && currentProtection) {
      if (baselineProtection.requiredReviewers !== currentProtection.requiredReviewers) {
        changes.push(`Required reviewers changed from ${baselineProtection.requiredReviewers} to ${currentProtection.requiredReviewers}`);
        severity = severity === 'low' ? 'medium' : severity;
      }
      if (baselineProtection.enforceAdmins !== currentProtection.enforceAdmins) {
        changes.push(`Enforce admins changed: ${currentProtection.enforceAdmins}`);
        severity = severity === 'low' ? 'high' : severity;
      }
    }

    return { changes, severity };
  }
}


import { GitHubClient } from '../github/github-client';
import { BaselineManager } from '../baseline/baseline-manager';
import { BaselineConfig } from '../github/github-types';

export class StateInvariantDetector {
  private githubClient: GitHubClient;
  private baselineManager: BaselineManager;
  private baseline: BaselineConfig | null = null;

  constructor(githubClient: GitHubClient, baselineManager: BaselineManager) {
    this.githubClient = githubClient;
    this.baselineManager = baselineManager;
  }

  async initialize(): Promise<void> {
    this.baseline = await this.baselineManager.loadBaseline();
    if (!this.baseline) {
      // Don't throw - allow service to start, baseline will be established automatically
      // The orchestrator will handle baseline establishment
      return;
    }
  }

  async check(repo: string): Promise<{ risk: number; changes: string[] }> {
    if (!this.baseline) {
      await this.initialize();
    }

    if (!this.baseline || !this.baseline.repos[repo]) {
      return { risk: 0, changes: [] };
    }

    try {
      const currentState = await this.githubClient.fetchRepoState(repo);
      const baselineStateHash = this.baseline.repos[repo].stateHash;
      const currentStateHash = this.baselineManager.hashRepoState(currentState);

      if (currentStateHash === baselineStateHash) {
        return { risk: 0, changes: [] };
      }

      // State changed, calculate diff and risk
      // We need to fetch the baseline state to compare
      // For now, we'll use a simplified comparison based on stored baseline data
      const baselineRepoData = this.baseline.repos[repo];
      
      // Reconstruct baseline state from stored baseline data
      // Note: We need to fetch the actual baseline state, but for now we'll compare key fields
      const changes: string[] = [];
      let severity: 'low' | 'medium' | 'high' | 'critical' = 'high';
      
      // Compare admins
      const removedAdmins = baselineRepoData.admins.filter(a => !currentState.admins.includes(a));
      if (removedAdmins.length > 0) {
        changes.push(`Admins removed: ${removedAdmins.join(', ')}`);
        severity = 'critical';
      }
      
      // Compare branch protection
      if (baselineRepoData.branchProtection.length > 0 && currentState.branchProtection.length === 0) {
        changes.push('Branch protection removed');
        severity = severity === 'low' ? 'high' : severity;
      }
      
      // Compare default branch (if we can determine it from fingerprint)
      // This is a simplified check - full comparison would require storing full baseline state
      
      const diff = { changes, severity };
      
      let risk = 5; // Base risk for state change
      if (diff.severity === 'critical') risk = 10;
      else if (diff.severity === 'high') risk = 8;
      else if (diff.severity === 'medium') risk = 6;

      return {
        risk,
        changes: diff.changes,
      };
    } catch (error: any) {
      // If we can't fetch state, it might be an access issue
      return { risk: 0, changes: [`Failed to check state: ${error.message}`] };
    }
  }
}


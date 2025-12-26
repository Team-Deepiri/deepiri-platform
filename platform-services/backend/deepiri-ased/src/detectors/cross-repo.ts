import { GitHubClient } from '../github/github-client';
import { StateInvariantDetector } from './state-invariant';
import { DualTokenDetector } from './dual-token';
import { WriteCanaryDetector } from './write-canary';

export interface RepoCheckResult {
  repo: string;
  risk: number;
  passed: boolean;
}

export class CrossRepoDetector {
  private githubClient: GitHubClient;
  private stateInvariant: StateInvariantDetector;
  private dualToken: DualTokenDetector;
  private writeCanary: WriteCanaryDetector;
  private criticalRepos: string[];
  private failureThreshold: number;

  constructor(
    githubClient: GitHubClient,
    stateInvariant: StateInvariantDetector,
    dualToken: DualTokenDetector,
    writeCanary: WriteCanaryDetector,
    criticalRepos: string[],
    failureThreshold: number = 0.5
  ) {
    this.githubClient = githubClient;
    this.stateInvariant = stateInvariant;
    this.dualToken = dualToken;
    this.writeCanary = writeCanary;
    this.criticalRepos = criticalRepos;
    this.failureThreshold = failureThreshold;
  }

  async check(): Promise<number> {
    const results: RepoCheckResult[] = [];

    // Check all critical repos
    for (const repo of this.criticalRepos) {
      try {
        const [stateRisk, tokenRisk, canaryRisk] = await Promise.all([
          this.stateInvariant.check(repo).then(r => r.risk),
          this.dualToken.check(repo),
          this.writeCanary.check(repo),
        ]);

        const totalRisk = stateRisk + tokenRisk + canaryRisk;
        results.push({
          repo,
          risk: totalRisk,
          passed: totalRisk === 0,
        });
      } catch (error: any) {
        results.push({
          repo,
          risk: 0,
          passed: true, // Don't count errors as failures
        });
      }
    }

    // Calculate failure rate
    const failures = results.filter(r => !r.passed);
    const failureRate = failures.length / this.criticalRepos.length;

    if (failureRate >= this.failureThreshold) {
      // 50%+ of repos failing = systemic issue
      return failures.length * 2;
    }

    if (failureRate >= 0.25) {
      // 25-50% = potential issue
      return failures.length;
    }

    // < 25% = isolated issue, ignore
    return 0;
  }
}


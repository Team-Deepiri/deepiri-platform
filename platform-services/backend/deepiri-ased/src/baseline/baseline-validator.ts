import { BaselineConfig } from '../github/github-types';

export class BaselineValidator {
  validate(baseline: BaselineConfig): { valid: boolean; errors: string[] } {
    const errors: string[] = [];

    if (!baseline.version) {
      errors.push('Baseline missing version');
    }

    if (!baseline.timestamp) {
      errors.push('Baseline missing timestamp');
    }

    if (!baseline.repos || Object.keys(baseline.repos).length === 0) {
      errors.push('Baseline missing repositories');
    }

    for (const [repoName, repoData] of Object.entries(baseline.repos)) {
      if (!repoData.stateHash) {
        errors.push(`Repository ${repoName} missing stateHash`);
      }

      if (!repoData.fingerprint) {
        errors.push(`Repository ${repoName} missing fingerprint`);
      }

      if (!repoData.fingerprint.repoId) {
        errors.push(`Repository ${repoName} fingerprint missing repoId`);
      }

      if (!repoData.fingerprint.createdAt) {
        errors.push(`Repository ${repoName} fingerprint missing createdAt`);
      }
    }

    return {
      valid: errors.length === 0,
      errors,
    };
  }
}


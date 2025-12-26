import { GitHubClient } from '../github/github-client';
import { AuditLog } from '../storage/audit-log';
import * as fs from 'fs';
import * as path from 'path';

export class BackupManager {
  private githubClient: GitHubClient;
  private auditLog: AuditLog;
  private backupDir: string;

  constructor(githubClient: GitHubClient, auditLog: AuditLog) {
    this.githubClient = githubClient;
    this.auditLog = auditLog;
    this.backupDir = path.join(process.cwd(), 'data', 'backups');
    this.ensureDirectory();
  }

  private ensureDirectory(): void {
    if (!fs.existsSync(this.backupDir)) {
      fs.mkdirSync(this.backupDir, { recursive: true });
    }
  }

  async createBackup(repos: string[]): Promise<{ success: boolean; backups: string[]; failed: string[] }> {
    const backups: string[] = [];
    const failed: string[] = [];
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');

    for (const repo of repos) {
      try {
        const backupPath = path.join(this.backupDir, `${repo}-${timestamp}.json`);
        
        // Create backup metadata
        const backup = {
          repo,
          timestamp: new Date().toISOString(),
          state: await this.githubClient.fetchRepoState(repo),
          fingerprint: await this.githubClient.fetchRepoFingerprint(repo),
          submodules: await this.githubClient.fetchSubmoduleConfig(repo),
          workflows: await this.githubClient.fetchWorkflowFiles(repo),
        };

        fs.writeFileSync(backupPath, JSON.stringify(backup, null, 2), 'utf-8');
        backups.push(backupPath);

        await this.auditLog.logAction('backup_created', repo, undefined, {
          backupPath,
        });
      } catch (error: any) {
        failed.push(repo);
        await this.auditLog.logAction('backup_failed', repo, undefined, {
          error: error.message,
        });
      }
    }

    return { success: failed.length === 0, backups, failed };
  }

  async restoreBackup(repo: string, backupPath: string): Promise<boolean> {
    try {
      const backup = JSON.parse(fs.readFileSync(backupPath, 'utf-8'));
      
      // Restore logic would go here
      // This would involve recreating repos, restoring state, etc.
      
      await this.auditLog.logAction('backup_restored', repo, undefined, {
        backupPath,
      });

      return true;
    } catch (error: any) {
      await this.auditLog.logAction('backup_restore_failed', repo, undefined, {
        error: error.message,
      });
      return false;
    }
  }

  listBackups(repo?: string): string[] {
    if (!fs.existsSync(this.backupDir)) {
      return [];
    }

    const files = fs.readdirSync(this.backupDir);
    return files
      .filter(file => file.endsWith('.json'))
      .filter(file => !repo || file.startsWith(repo))
      .map(file => path.join(this.backupDir, file));
  }
}


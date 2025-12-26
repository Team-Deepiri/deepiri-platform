import { GitHubClient } from '../github/github-client';
import { AuditLog } from '../storage/audit-log';
import { BackupManager } from './backup-manager';

export class DeleteRepos {
  private githubClient: GitHubClient;
  private auditLog: AuditLog;
  private backupManager: BackupManager;
  private backupBeforeDelete: boolean;

  constructor(
    githubClient: GitHubClient,
    auditLog: AuditLog,
    backupManager: BackupManager,
    backupBeforeDelete: boolean = true
  ) {
    this.githubClient = githubClient;
    this.auditLog = auditLog;
    this.backupManager = backupManager;
    this.backupBeforeDelete = backupBeforeDelete;
  }

  async deleteRepositories(repos: string[]): Promise<{ success: boolean; deleted: string[]; failed: string[] }> {
    const deleted: string[] = [];
    const failed: string[] = [];

    // Create backups before deletion if configured
    if (this.backupBeforeDelete) {
      await this.backupManager.createBackup(repos);
    }

    for (const repo of repos) {
      try {
        await this.githubClient.deleteRepository(repo);
        deleted.push(repo);
        
        await this.auditLog.logAction('repository_deleted', repo, undefined, {
          timestamp: new Date().toISOString(),
        });
      } catch (error: any) {
        failed.push(repo);
        await this.auditLog.logAction('repository_delete_failed', repo, undefined, {
          error: error.message,
        });
      }
    }

    // Stop containers
    try {
      await this.stopContainers();
    } catch (error: any) {
      await this.auditLog.logAction('containers_stop_failed', undefined, undefined, {
        error: error.message,
      });
    }

    return { success: failed.length === 0, deleted, failed };
  }

  private async stopContainers(): Promise<void> {
    // Implementation would use Docker API or Kubernetes API
    // For now, this is a placeholder
    const dockerSocket = process.env.DOCKER_SOCKET || '/var/run/docker.sock';
    // Would implement Docker API calls to stop all deepiri-* containers
  }
}


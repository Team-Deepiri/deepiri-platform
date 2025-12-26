import axios from 'axios';
import { AuditLog } from '../storage/audit-log';

export class LockServices {
  private auditLog: AuditLog;
  private serviceUrls: string[];

  constructor(auditLog: AuditLog, serviceUrls: string[] = []) {
    this.auditLog = auditLog;
    this.serviceUrls = serviceUrls;
  }

  async lockAll(repos: string[]): Promise<{ success: boolean; locked: string[]; failed: string[] }> {
    const locked: string[] = [];
    const failed: string[] = [];

    // Lock all deepiri-* services
    for (const url of this.serviceUrls) {
      try {
        await axios.post(`${url}/lock`, {
          readOnly: true,
          reason: 'Sovereignty enforcement - risk threshold breached',
        });
        locked.push(url);
      } catch (error: any) {
        failed.push(url);
        await this.auditLog.logAction('lock_service_failed', undefined, undefined, {
          service: url,
          error: error.message,
        });
      }
    }

    // Lock via Docker/Kubernetes if available
    try {
      await this.lockContainers();
      locked.push('containers');
    } catch (error: any) {
      failed.push('containers');
      await this.auditLog.logAction('lock_containers_failed', undefined, undefined, {
        error: error.message,
      });
    }

    await this.auditLog.logAction('services_locked', undefined, undefined, {
      locked,
      failed,
      repos,
    });

    return { success: failed.length === 0, locked, failed };
  }

  async unlockAll(): Promise<{ success: boolean; unlocked: string[]; failed: string[] }> {
    const unlocked: string[] = [];
    const failed: string[] = [];

    for (const url of this.serviceUrls) {
      try {
        await axios.post(`${url}/unlock`);
        unlocked.push(url);
      } catch (error: any) {
        failed.push(url);
      }
    }

    try {
      await this.unlockContainers();
      unlocked.push('containers');
    } catch (error: any) {
      failed.push('containers');
    }

    await this.auditLog.logAction('services_unlocked', undefined, undefined, {
      unlocked,
      failed,
    });

    return { success: failed.length === 0, unlocked, failed };
  }

  private async lockContainers(): Promise<void> {
    // Implementation would use Docker API or Kubernetes API
    // For now, this is a placeholder
    const dockerSocket = process.env.DOCKER_SOCKET || '/var/run/docker.sock';
    // Would implement Docker API calls here
  }

  private async unlockContainers(): Promise<void> {
    // Implementation would use Docker API or Kubernetes API
  }
}


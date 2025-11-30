import { Request, Response } from 'express';
import { createLogger } from '@deepiri/shared-utils';
import prisma from './db';

const logger = createLogger('task-versioning-service');

type ChangeType = 'create' | 'update' | 'delete' | 'restore';

class TaskVersioningService {
  async getTasks(req: Request, res: Response): Promise<void> {
    try {
      // Placeholder - would query tasks
      res.json({ tasks: [] });
    } catch (error: any) {
      logger.error('Error getting tasks:', error);
      res.status(500).json({ error: 'Failed to get tasks' });
    }
  }

  async createTask(req: Request, res: Response): Promise<void> {
    try {
      const { taskId, userId, taskData } = req.body;
      
      if (!taskId || !userId || !taskData) {
        res.status(400).json({ error: 'Missing required fields' });
        return;
      }

      const version = await this.createInitialVersion(taskId, userId, taskData);
      res.json(version);
    } catch (error: any) {
      logger.error('Error creating task:', error);
      res.status(500).json({ error: 'Failed to create task' });
    }
  }

  async updateTask(req: Request, res: Response): Promise<void> {
    try {
      const { id } = req.params;
      const { userId, changes, changeReason } = req.body;
      
      if (!userId || !changes) {
        res.status(400).json({ error: 'Missing required fields' });
        return;
      }

      const version = await this.createVersion(id, userId, changes, changeReason);
      res.json(version);
    } catch (error: any) {
      logger.error('Error updating task:', error);
      res.status(500).json({ error: 'Failed to update task' });
    }
  }

  async getVersions(req: Request, res: Response): Promise<void> {
    try {
      const { id } = req.params;
      const { limit = 50 } = req.query;
      const versions = await this.getVersionHistory(id, parseInt(limit as string, 10));
      res.json(versions);
    } catch (error: any) {
      logger.error('Error getting versions:', error);
      res.status(500).json({ error: 'Failed to get versions' });
    }
  }

  private async createInitialVersion(taskId: string, userId: string, taskData: Record<string, any>) {
    try {
      const version = await prisma.taskVersion.create({
        data: {
          taskId,
          version: 1,
          title: taskData.title,
          description: taskData.description,
          status: taskData.status,
          priority: taskData.priority,
          changesSummary: 'Initial version',
          changedBy: userId,
          metadata: taskData as any
        }
      });

      logger.info('Initial task version created', { taskId, version: 1 });
      return version;
    } catch (error) {
      logger.error('Error creating initial version:', error);
      throw error;
    }
  }

  private async createVersion(
    taskId: string,
    userId: string,
    changes: Record<string, any>,
    changeReason: string | null = null
  ) {
    try {
      const currentVersion = await prisma.taskVersion.findFirst({
        where: { taskId },
        orderBy: { version: 'desc' }
      });

      const newVersionNumber = currentVersion ? currentVersion.version + 1 : 1;

      const version = await prisma.taskVersion.create({
        data: {
          taskId,
          version: newVersionNumber,
          title: changes.title,
          description: changes.description,
          status: changes.status,
          priority: changes.priority,
          changesSummary: changeReason || 'Task updated',
          changedBy: userId,
          metadata: changes as any
        },
        include: {
          changedByUser: {
            select: {
              id: true,
              name: true,
              email: true
            }
          }
        }
      });

      logger.info('Task version created', { taskId, version: newVersionNumber });
      return version;
    } catch (error) {
      logger.error('Error creating version:', error);
      throw error;
    }
  }

  private async getVersionHistory(taskId: string, limit: number = 50) {
    try {
      const versions = await prisma.taskVersion.findMany({
        where: { taskId },
        orderBy: { version: 'desc' },
        take: limit,
        include: {
          changedByUser: {
            select: {
              id: true,
              name: true,
              email: true
            }
          }
        }
      });

      return versions.map(v => ({
        version: v.version,
        changes: {
          title: v.title,
          description: v.description,
          status: v.status,
          priority: v.priority
        },
        changeType: 'update',
        changedBy: v.changedByUser,
        changeReason: v.changesSummary,
        createdAt: v.createdAt,
        metadata: v.metadata
      }));
    } catch (error) {
      logger.error('Error getting version history:', error);
      throw error;
    }
  }
}

export default new TaskVersioningService();

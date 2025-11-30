import { Request, Response } from 'express';
import { createLogger } from '@deepiri/shared-utils';
import prisma from './db';

const logger = createLogger('dependency-graph-service');

type DependencyType = 'blocks' | 'precedes' | 'related' | 'subtask';

class DependencyGraphService {
  async getDependencies(req: Request, res: Response): Promise<void> {
    try {
      const { taskId } = req.params;
      const dependencies = await this.getDependenciesForTask(taskId);
      res.json(dependencies);
    } catch (error: any) {
      logger.error('Error getting dependencies:', error);
      res.status(500).json({ error: 'Failed to get dependencies' });
    }
  }

  async addDependency(req: Request, res: Response): Promise<void> {
    try {
      const { taskId, dependsOn, dependencyType = 'blocks', userId } = req.body;
      
      if (!taskId || !dependsOn || !userId) {
        res.status(400).json({ error: 'Missing required fields' });
        return;
      }

      const dependency = await this.addDependencyToTask(taskId, dependsOn, dependencyType as DependencyType, userId);
      res.json(dependency);
    } catch (error: any) {
      logger.error('Error adding dependency:', error);
      res.status(500).json({ error: error.message || 'Failed to add dependency' });
    }
  }

  private async addDependencyToTask(
    taskId: string,
    dependsOn: string,
    dependencyType: DependencyType = 'blocks',
    userId: string
  ) {
    try {
      if (await this._wouldCreateCycle(taskId, dependsOn)) {
        throw new Error('Circular dependency detected');
      }

      const existing = await prisma.taskDependency.findUnique({
        where: {
          taskId_dependsOnTaskId: {
            taskId,
            dependsOnTaskId: dependsOn
          }
        }
      });

      if (existing) {
        return existing;
      }

      const dependency = await prisma.taskDependency.create({
        data: {
          taskId,
          dependsOnTaskId: dependsOn,
          dependencyType: dependencyType === 'precedes' ? 'blocks' : dependencyType // Map to DB enum
        },
        include: {
          dependsOnTask: {
            select: {
              id: true,
              title: true,
              status: true,
              priority: true,
              dueDate: true
            }
          }
        }
      });

      logger.info('Task dependency added', { taskId, dependsOn, dependencyType });
      return dependency;
    } catch (error) {
      logger.error('Error adding dependency:', error);
      throw error;
    }
  }

  private async getDependenciesForTask(taskId: string) {
    try {
      const dependencies = await prisma.taskDependency.findMany({
        where: { taskId },
        include: {
          dependsOnTask: {
            select: {
              id: true,
              title: true,
              status: true,
              priority: true,
              dueDate: true
            }
          }
        },
        orderBy: { createdAt: 'asc' }
      });

      return dependencies.map(dep => ({
        task: dep.dependsOnTask,
        type: dep.dependencyType,
        createdAt: dep.createdAt
      }));
    } catch (error) {
      logger.error('Error getting dependencies:', error);
      throw error;
    }
  }

  private async _wouldCreateCycle(taskId: string, dependsOn: string): Promise<boolean> {
    try {
      // Check for direct reverse dependency
      const reverseDependency = await prisma.taskDependency.findUnique({
        where: {
          taskId_dependsOnTaskId: {
            taskId: dependsOn,
            dependsOnTaskId: taskId
          }
        }
      });

      if (reverseDependency) {
        return true;
      }

      // Check for indirect cycles using DFS
      const visited = new Set<string>();
      const stack: string[] = [dependsOn];

      while (stack.length > 0) {
        const current = stack.pop()!;
        
        if (current === taskId) {
          return true;
        }

        if (visited.has(current)) {
          continue;
        }

        visited.add(current);

        const deps = await prisma.taskDependency.findMany({
          where: { taskId: current },
          select: { dependsOnTaskId: true }
        });
        
        deps.forEach(dep => {
          stack.push(dep.dependsOnTaskId);
        });
      }

      return false;
    } catch (error) {
      logger.error('Error checking for cycles:', error);
      return true; // Fail safe - assume cycle exists if we can't check
    }
  }
}

export default new DependencyGraphService();

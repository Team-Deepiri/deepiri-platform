import mongoose, { Schema, Document, Model, Types } from 'mongoose';
import { Request, Response } from 'express';
import { createLogger } from '@deepiri/shared-utils';

const logger = createLogger('dependency-graph-service');

type DependencyType = 'blocks' | 'precedes' | 'related' | 'subtask';

interface ITaskDependency extends Document {
  taskId: Types.ObjectId;
  dependsOn: Types.ObjectId;
  dependencyType: DependencyType;
  userId: Types.ObjectId;
  createdAt: Date;
}

const TaskDependencySchema = new Schema<ITaskDependency>({
  taskId: { type: Schema.Types.ObjectId, required: true, index: true },
  dependsOn: { type: Schema.Types.ObjectId, required: true, index: true },
  dependencyType: {
    type: String,
    enum: ['blocks', 'precedes', 'related', 'subtask'],
    default: 'blocks'
  },
  userId: { type: Schema.Types.ObjectId, required: true, index: true },
  createdAt: { type: Date, default: Date.now }
}, {
  timestamps: false
});

TaskDependencySchema.index({ taskId: 1, dependsOn: 1 }, { unique: true });

const TaskDependency: Model<ITaskDependency> = mongoose.model<ITaskDependency>('TaskDependency', TaskDependencySchema);

class DependencyGraphService {
  async getDependencies(req: Request, res: Response): Promise<void> {
    try {
      const { taskId } = req.params;
      const dependencies = await this.getDependenciesForTask(new Types.ObjectId(taskId));
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

      const dependency = await this.addDependencyToTask(
        new Types.ObjectId(taskId),
        new Types.ObjectId(dependsOn),
        dependencyType as DependencyType,
        new Types.ObjectId(userId)
      );
      res.json(dependency);
    } catch (error: any) {
      logger.error('Error adding dependency:', error);
      res.status(500).json({ error: error.message || 'Failed to add dependency' });
    }
  }

  private async addDependencyToTask(
    taskId: Types.ObjectId,
    dependsOn: Types.ObjectId,
    dependencyType: DependencyType = 'blocks',
    userId: Types.ObjectId
  ) {
    try {
      if (await this._wouldCreateCycle(taskId, dependsOn)) {
        throw new Error('Circular dependency detected');
      }

      const existing = await TaskDependency.findOne({ taskId, dependsOn });
      if (existing) {
        return existing;
      }

      const dependency = new TaskDependency({
        taskId,
        dependsOn,
        dependencyType,
        userId
      });

      await dependency.save();
      logger.info('Task dependency added', { taskId, dependsOn, dependencyType });
      return dependency;
    } catch (error) {
      logger.error('Error adding dependency:', error);
      throw error;
    }
  }

  private async getDependenciesForTask(taskId: Types.ObjectId) {
    try {
      const dependencies = await TaskDependency.find({ taskId })
        .populate('dependsOn', 'title status priority dueDate')
        .select('dependsOn dependencyType createdAt');

      return dependencies.map(dep => ({
        task: dep.dependsOn,
        type: dep.dependencyType,
        createdAt: dep.createdAt
      }));
    } catch (error) {
      logger.error('Error getting dependencies:', error);
      throw error;
    }
  }

  private async _wouldCreateCycle(taskId: Types.ObjectId, dependsOn: Types.ObjectId): Promise<boolean> {
    try {
      const reverseDependency = await TaskDependency.findOne({
        taskId: dependsOn,
        dependsOn: taskId
      });

      if (reverseDependency) {
        return true;
      }

      const visited = new Set<string>();
      const stack: Types.ObjectId[] = [dependsOn];

      while (stack.length > 0) {
        const current = stack.pop()!;
        
        if (current.toString() === taskId.toString()) {
          return true;
        }

        if (visited.has(current.toString())) {
          continue;
        }

        visited.add(current.toString());

        const deps = await TaskDependency.find({ taskId: current })
          .select('dependsOn');
        
        deps.forEach(dep => {
          stack.push(dep.dependsOn);
        });
      }

      return false;
    } catch (error) {
      logger.error('Error checking for cycles:', error);
      return true;
    }
  }
}

export default new DependencyGraphService();


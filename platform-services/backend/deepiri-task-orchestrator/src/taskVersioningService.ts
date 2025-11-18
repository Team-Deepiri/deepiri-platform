import mongoose, { Schema, Document, Model, Types } from 'mongoose';
import { Request, Response } from 'express';
import { createLogger } from '@deepiri/shared-utils';

const logger = createLogger('task-versioning-service');

type ChangeType = 'create' | 'update' | 'delete' | 'restore';

interface ITaskVersion extends Document {
  taskId: Types.ObjectId;
  version: number;
  userId: Types.ObjectId;
  changes: {
    title?: string;
    description?: string;
    status?: string;
    priority?: string;
    dueDate?: Date;
    tags?: string[];
    metadata?: Record<string, any>;
  };
  changeType: ChangeType;
  changedBy: Types.ObjectId;
  changeReason?: string;
  snapshot: Record<string, any>;
  createdAt: Date;
}

const TaskVersionSchema = new Schema<ITaskVersion>({
  taskId: { type: Schema.Types.ObjectId, required: true, index: true },
  version: { type: Number, required: true },
  userId: { type: Schema.Types.ObjectId, required: true, index: true },
  changes: {
    title: { type: String },
    description: { type: String },
    status: { type: String },
    priority: { type: String },
    dueDate: { type: Date },
    tags: [String],
    metadata: Schema.Types.Mixed
  },
  changeType: {
    type: String,
    enum: ['create', 'update', 'delete', 'restore'],
    required: true
  },
  changedBy: { type: Schema.Types.ObjectId, required: true },
  changeReason: { type: String },
  snapshot: Schema.Types.Mixed,
  createdAt: { type: Date, default: Date.now }
}, {
  timestamps: false
});

TaskVersionSchema.index({ taskId: 1, version: 1 }, { unique: true });

const TaskVersion: Model<ITaskVersion> = mongoose.model<ITaskVersion>('TaskVersion', TaskVersionSchema);

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

      const version = await this.createInitialVersion(
        new Types.ObjectId(taskId),
        new Types.ObjectId(userId),
        taskData
      );
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

      const version = await this.createVersion(
        new Types.ObjectId(id),
        new Types.ObjectId(userId),
        changes,
        changeReason
      );
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
      const versions = await this.getVersionHistory(
        new Types.ObjectId(id),
        parseInt(limit as string, 10)
      );
      res.json(versions);
    } catch (error: any) {
      logger.error('Error getting versions:', error);
      res.status(500).json({ error: 'Failed to get versions' });
    }
  }

  private async createInitialVersion(taskId: Types.ObjectId, userId: Types.ObjectId, taskData: Record<string, any>) {
    try {
      const version = new TaskVersion({
        taskId,
        version: 1,
        userId,
        changes: taskData,
        changeType: 'create',
        changedBy: userId,
        snapshot: taskData
      });

      await version.save();
      logger.info('Initial task version created', { taskId, version: 1 });
      return version;
    } catch (error) {
      logger.error('Error creating initial version:', error);
      throw error;
    }
  }

  private async createVersion(
    taskId: Types.ObjectId,
    userId: Types.ObjectId,
    changes: Record<string, any>,
    changeReason: string | null = null
  ) {
    try {
      const currentVersion = await TaskVersion.findOne({ taskId })
        .sort({ version: -1 })
        .limit(1);

      const newVersionNumber = currentVersion ? currentVersion.version + 1 : 1;
      const currentSnapshot = currentVersion?.snapshot || {};
      const newSnapshot = { ...currentSnapshot, ...changes };

      const version = new TaskVersion({
        taskId,
        version: newVersionNumber,
        userId,
        changes,
        changeType: 'update',
        changedBy: userId,
        changeReason: changeReason || undefined,
        snapshot: newSnapshot
      });

      await version.save();
      logger.info('Task version created', { taskId, version: newVersionNumber });
      return version;
    } catch (error) {
      logger.error('Error creating version:', error);
      throw error;
    }
  }

  private async getVersionHistory(taskId: Types.ObjectId, limit: number = 50) {
    try {
      const versions = await TaskVersion.find({ taskId })
        .sort({ version: -1 })
        .limit(limit)
        .populate('changedBy', 'name email')
        .select('version changes changeType changedBy changeReason createdAt snapshot');

      return versions;
    } catch (error) {
      logger.error('Error getting version history:', error);
      throw error;
    }
  }
}

export default new TaskVersioningService();


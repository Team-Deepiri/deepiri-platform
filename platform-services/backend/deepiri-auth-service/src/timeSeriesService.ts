import mongoose, { Schema, Document, Model, Types } from 'mongoose';
import { Request, Response } from 'express';
import { createLogger } from '@deepiri/shared-utils';

const logger = createLogger('time-series-service');

interface IProgressPoint extends Document {
  userId: Types.ObjectId;
  timestamp: Date;
  metric: string;
  value: number;
  metadata?: Record<string, any>;
}

const ProgressPointSchema = new Schema<IProgressPoint>({
  userId: { type: Schema.Types.ObjectId, required: true, index: true },
  timestamp: { type: Date, required: true, index: true },
  metric: { type: String, required: true, index: true },
  value: { type: Number, required: true },
  metadata: Schema.Types.Mixed
}, {
  timestamps: false
});

ProgressPointSchema.index({ timestamp: 1 }, { expireAfterSeconds: 63072000 });

const ProgressPoint: Model<IProgressPoint> = mongoose.model<IProgressPoint>('ProgressPoint', ProgressPointSchema);

class TimeSeriesService {
  async recordData(req: Request, res: Response): Promise<void> {
    try {
      const { userId, metric, value, metadata } = req.body;
      
      if (!userId || !metric || value === undefined) {
        res.status(400).json({ error: 'Missing required fields' });
        return;
      }

      const point = await this.recordProgress(
        new Types.ObjectId(userId),
        metric,
        value,
        metadata || {}
      );
      res.json(point);
    } catch (error) {
      logger.error('Error recording data:', error);
      res.status(500).json({ error: 'Failed to record data' });
    }
  }

  async getData(req: Request, res: Response): Promise<void> {
    try {
      const { userId } = req.params;
      const { metric, startDate, endDate } = req.query;
      
      if (!metric || !startDate || !endDate) {
        res.status(400).json({ error: 'Missing query parameters' });
        return;
      }

      const series = await this.getProgressSeries(
        new Types.ObjectId(userId),
        metric as string,
        new Date(startDate as string),
        new Date(endDate as string)
      );
      res.json(series);
    } catch (error) {
      logger.error('Error getting data:', error);
      res.status(500).json({ error: 'Failed to get data' });
    }
  }

  private async recordProgress(userId: Types.ObjectId, metric: string, value: number, metadata: Record<string, any> = {}): Promise<IProgressPoint> {
    try {
      const point = new ProgressPoint({
        userId,
        timestamp: new Date(),
        metric,
        value,
        metadata
      });

      await point.save();
      logger.debug('Progress point recorded', { userId, metric, value });
      return point;
    } catch (error) {
      logger.error('Error recording progress:', error);
      throw error;
    }
  }

  private async getProgressSeries(userId: Types.ObjectId, metric: string, startDate: Date, endDate: Date) {
    try {
      const query = {
        userId,
        metric,
        timestamp: {
          $gte: startDate,
          $lte: endDate
        }
      };

      const points = await ProgressPoint.find(query)
        .sort({ timestamp: 1 })
        .select('timestamp value metadata');

      return points;
    } catch (error) {
      logger.error('Error getting progress series:', error);
      throw error;
    }
  }
}

export default new TimeSeriesService();


/**
 * Time-Series Service
 * Tracks user progress over time using time-series database
 */
const mongoose = require('mongoose');
const logger = require('../utils/logger');

// Time-series schema for progress tracking
const ProgressPointSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
  timestamp: { type: Date, required: true, index: true },
  metric: { type: String, required: true, index: true },
  value: { type: Number, required: true },
  metadata: mongoose.Schema.Types.Mixed
}, {
  timestamps: false
});

// TTL index for automatic cleanup (optional - keep data for 2 years)
ProgressPointSchema.index({ timestamp: 1 }, { expireAfterSeconds: 63072000 });

const ProgressPoint = mongoose.model('ProgressPoint', ProgressPointSchema);

class TimeSeriesService {
  /**
   * Record a progress point
   */
  async recordProgress(userId, metric, value, metadata = {}) {
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

  /**
   * Get progress time series
   */
  async getProgressSeries(userId, metric, startDate, endDate) {
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

  /**
   * Get aggregated progress statistics
   */
  async getProgressStats(userId, metric, period = '7d') {
    try {
      const endDate = new Date();
      const startDate = this._getStartDate(period);

      const stats = await ProgressPoint.aggregate([
        {
          $match: {
            userId: new mongoose.Types.ObjectId(userId),
            metric,
            timestamp: { $gte: startDate, $lte: endDate }
          }
        },
        {
          $group: {
            _id: null,
            count: { $sum: 1 },
            sum: { $sum: '$value' },
            avg: { $avg: '$value' },
            min: { $min: '$value' },
            max: { $max: '$value' },
            first: { $first: '$value' },
            last: { $last: '$value' }
          }
        }
      ]);

      if (stats.length === 0) {
        return {
          count: 0,
          sum: 0,
          avg: 0,
          min: 0,
          max: 0,
          first: 0,
          last: 0,
          trend: 0
        };
      }

      const result = stats[0];
      result.trend = result.last - result.first;

      return result;
    } catch (error) {
      logger.error('Error getting progress stats:', error);
      throw error;
    }
  }

  /**
   * Get multiple metrics at once
   */
  async getMultipleMetrics(userId, metrics, startDate, endDate) {
    try {
      const query = {
        userId,
        metric: { $in: metrics },
        timestamp: {
          $gte: startDate,
          $lte: endDate
        }
      };

      const points = await ProgressPoint.find(query)
        .sort({ timestamp: 1 });

      // Group by metric
      const grouped = {};
      metrics.forEach(metric => {
        grouped[metric] = points
          .filter(p => p.metric === metric)
          .map(p => ({
            timestamp: p.timestamp,
            value: p.value,
            metadata: p.metadata
          }));
      });

      return grouped;
    } catch (error) {
      logger.error('Error getting multiple metrics:', error);
      throw error;
    }
  }

  /**
   * Get daily aggregates
   */
  async getDailyAggregates(userId, metric, days = 30) {
    try {
      const endDate = new Date();
      const startDate = new Date(endDate);
      startDate.setDate(startDate.getDate() - days);

      const aggregates = await ProgressPoint.aggregate([
        {
          $match: {
            userId: new mongoose.Types.ObjectId(userId),
            metric,
            timestamp: { $gte: startDate, $lte: endDate }
          }
        },
        {
          $group: {
            _id: {
              $dateToString: { format: '%Y-%m-%d', date: '$timestamp' }
            },
            count: { $sum: 1 },
            total: { $sum: '$value' },
            avg: { $avg: '$value' },
            min: { $min: '$value' },
            max: { $max: '$value' }
          }
        },
        { $sort: { _id: 1 } }
      ]);

      return aggregates.map(agg => ({
        date: agg._id,
        count: agg.count,
        total: agg.total,
        avg: agg.avg,
        min: agg.min,
        max: agg.max
      }));
    } catch (error) {
      logger.error('Error getting daily aggregates:', error);
      throw error;
    }
  }

  /**
   * Get trend analysis
   */
  async getTrendAnalysis(userId, metric, period = '30d') {
    try {
      const endDate = new Date();
      const startDate = this._getStartDate(period);

      const points = await this.getProgressSeries(userId, metric, startDate, endDate);
      
      if (points.length < 2) {
        return {
          trend: 'insufficient_data',
          slope: 0,
          rSquared: 0,
          forecast: null
        };
      }

      // Simple linear regression
      const n = points.length;
      const x = points.map((p, i) => i);
      const y = points.map(p => p.value);

      const sumX = x.reduce((a, b) => a + b, 0);
      const sumY = y.reduce((a, b) => a + b, 0);
      const sumXY = x.reduce((sum, xi, i) => sum + xi * y[i], 0);
      const sumXX = x.reduce((sum, xi) => sum + xi * xi, 0);

      const slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);
      const intercept = (sumY - slope * sumX) / n;

      // Calculate R-squared
      const yMean = sumY / n;
      const ssRes = y.reduce((sum, yi, i) => {
        const predicted = slope * x[i] + intercept;
        return sum + Math.pow(yi - predicted, 2);
      }, 0);
      const ssTot = y.reduce((sum, yi) => sum + Math.pow(yi - yMean, 2), 0);
      const rSquared = 1 - (ssRes / ssTot);

      // Forecast next value
      const forecast = slope * n + intercept;

      let trend;
      if (slope > 0.1) trend = 'increasing';
      else if (slope < -0.1) trend = 'decreasing';
      else trend = 'stable';

      return {
        trend,
        slope,
        intercept,
        rSquared,
        forecast: Math.max(0, forecast), // Ensure non-negative
        dataPoints: n
      };
    } catch (error) {
      logger.error('Error getting trend analysis:', error);
      throw error;
    }
  }

  _getStartDate(period) {
    const date = new Date();
    const periodMap = {
      '1d': 1,
      '7d': 7,
      '30d': 30,
      '90d': 90,
      '1y': 365
    };

    const days = periodMap[period] || 30;
    date.setDate(date.getDate() - days);
    return date;
  }
}

module.exports = new TimeSeriesService();


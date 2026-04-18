import { InfluxDB, Point, WriteApi, QueryApi } from '@influxdata/influxdb-client';
import { Request, Response } from 'express';
import { createLogger } from '@deepiri/shared-utils';
import { secureLog } from '@deepiri/shared-utils';

const logger = createLogger('time-series-analytics');

class TimeSeriesAnalyticsService {
  private client: InfluxDB | null = null;
  private writeApi: WriteApi | null = null;
  private queryApi: QueryApi | null = null;
  private bucket: string = '';
  private org: string = '';

  constructor() {
    this._initialize();
  }

  private _initialize(): void {
    try {
      const url = process.env.INFLUXDB_URL || 'http://localhost:8086';
      const token = process.env.INFLUXDB_TOKEN || '';
      const org = process.env.INFLUXDB_ORG || 'deepiri';
      const bucket = process.env.INFLUXDB_BUCKET || 'analytics';

      this.client = new InfluxDB({ url, token });
      this.writeApi = this.client.getWriteApi(org, bucket, 'ns');
      this.queryApi = this.client.getQueryApi(org);
      this.bucket = bucket;
      this.org = org;

      secureLog('info', 'InfluxDB initialized');
    } catch (error) {
      secureLog('error', 'InfluxDB initialization failed:', error);
    }
  }

  async recordData(req: Request, res: Response): Promise<void> {
    try {
      const { userId, metric, value, tags } = req.body;
      
      if (!userId || !metric || value === undefined) {
        res.status(400).json({ error: 'Missing required fields' });
        return;
      }

      await this.recordMetric(userId, metric, value, tags || {});
      res.json({ success: true });
    } catch (error: any) {
      secureLog('error', 'Error recording data:', error);
      res.status(500).json({ error: 'Failed to record data' });
    }
  }

  async getAnalytics(req: Request, res: Response): Promise<void> {
    try {
      const { userId } = req.params;
      const { metric, startTime, endTime } = req.query;
      
      if (!metric || !startTime || !endTime) {
        res.status(400).json({ error: 'Missing query parameters' });
        return;
      }

      const results = await this.queryMetrics(
        userId,
        metric as string,
        new Date(startTime as string),
        new Date(endTime as string)
      );
      res.json(results);
    } catch (error: any) {
      secureLog('error', 'Error getting analytics:', error);
      res.status(500).json({ error: 'Failed to get analytics' });
    }
  }

  async recordInferenceMetrics(data: {
    model_name?: string;
    version?: string;
    user_id?: string;
    latency_ms?: number;
    tokens_used?: number;
    confidence?: number;
  }): Promise<void> {
    const userId = data.user_id || 'anonymous';
    const tags: Record<string, string> = {
      model_name: data.model_name || 'unknown',
      version: data.version || 'unknown',
    };
    if (data.latency_ms !== undefined)
      await this.recordMetric(userId, 'inference_latency_ms', data.latency_ms, tags);
    if (data.tokens_used !== undefined)
      await this.recordMetric(userId, 'inference_tokens_used', data.tokens_used, tags);
    if (data.confidence !== undefined)
      await this.recordMetric(userId, 'inference_confidence', data.confidence, tags);
  }

  async recordTrainingMetrics(data: {
    experiment_id?: string;
    model_name?: string;
    status?: string;
    progress?: number;
    metrics?: Record<string, number>;
  }): Promise<void> {
    const tags: Record<string, string> = {
      experiment_id: data.experiment_id || 'unknown',
      model_name: data.model_name || 'unknown',
      status: data.status || 'unknown',
    };
    if (data.progress !== undefined)
      await this.recordMetric('system', 'training_progress', data.progress, tags);
    for (const [key, val] of Object.entries(data.metrics || {})) {
      if (typeof val === 'number')
        await this.recordMetric('system', `training_${key}`, val, tags);
    }
  }

  private async recordMetric(userId: string, metric: string, value: number, tags: Record<string, string> = {}) {
    try {
      if (!this.writeApi) {
        throw new Error('InfluxDB not initialized');
      }

      const point = new Point(metric)
        .tag('userId', userId.toString())
        .floatField('value', value);

      Object.keys(tags).forEach(key => {
        point.tag(key, tags[key].toString());
      });

      this.writeApi.writePoint(point);
      await this.writeApi.flush();

      logger.debug('Metric recorded', { userId, metric, value });
    } catch (error) {
      secureLog('error', 'Error recording metric:', error);
      throw error;
    }
  }

  private async queryMetrics(userId: string, metric: string, startTime: Date, endTime: Date) {
    try {
      if (!this.queryApi) {
        throw new Error('InfluxDB not initialized');
      }

      const query = `
        from(bucket: "${this.bucket}")
          |> range(start: ${startTime.toISOString()}, stop: ${endTime.toISOString()})
          |> filter(fn: (r) => r._measurement == "${metric}")
          |> filter(fn: (r) => r.userId == "${userId}")
          |> aggregateWindow(every: 1h, fn: mean, createEmpty: false)
      `;

      const results: any[] = [];
      await this.queryApi.collectRows(query, (row: any, tableMeta: any) => {
        results.push({
          time: row._time,
          value: row._value,
          field: row._field
        });
      });

      return results;
    } catch (error) {
      secureLog('error', 'Error querying metrics:', error);
      throw error;
    }
  }
}

export default new TimeSeriesAnalyticsService();


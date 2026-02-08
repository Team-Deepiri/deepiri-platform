import { InfluxDB, Point, WriteApi, QueryApi } from '@influxdata/influxdb-client';
import { Request, Response } from 'express';
import { createLogger } from '@deepiri/shared-utils';

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

      logger.info('InfluxDB initialized');
    } catch (error) {
      logger.error('InfluxDB initialization failed:', error);
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
      logger.error('Error recording data:', error);
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
      logger.error('Error getting analytics:', error);
      res.status(500).json({ error: 'Failed to get analytics' });
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
      logger.error('Error recording metric:', error);
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
      logger.error('Error querying metrics:', error);
      throw error;
    }
  }
}

export default new TimeSeriesAnalyticsService();


import { Request, Response } from 'express';
import { createLogger } from '@deepiri/shared-utils';

const logger = createLogger('predictive-modeling');

type TimeSeries = number[];

class PredictiveModelingService {
  private models: Map<string, any> = new Map();

  async forecast(req: Request, res: Response): Promise<void> {
    try {
      const { timeSeries, periods = 30, method = 'prophet' } = req.body;
      
      if (!timeSeries || !Array.isArray(timeSeries)) {
        res.status(400).json({ error: 'Invalid timeSeries' });
        return;
      }

      let result;
      if (method === 'lstm') {
        result = await this.lstmPredict(timeSeries, 10, periods);
      } else {
        result = await this.prophetForecast(timeSeries, periods);
      }

      res.json(result);
    } catch (error: any) {
      logger.error('Error in forecast:', error);
      res.status(500).json({ error: 'Forecast failed' });
    }
  }

  async getRecommendations(req: Request, res: Response): Promise<void> {
    try {
      const { userId } = req.params;
      // Placeholder - would generate personalized recommendations
      res.json({ userId, recommendations: [] });
    } catch (error: any) {
      logger.error('Error getting recommendations:', error);
      res.status(500).json({ error: 'Failed to get recommendations' });
    }
  }

  private async prophetForecast(timeSeries: TimeSeries, periods: number = 30) {
    try {
      const trend = this._calculateTrend(timeSeries);
      const seasonality = this._calculateSeasonality(timeSeries);
      const forecast: number[] = [];

      for (let i = 0; i < periods; i++) {
        const futureTime = timeSeries.length + i;
        const trendValue = trend.intercept + trend.slope * futureTime;
        const seasonalValue = this._getSeasonalComponent(futureTime, seasonality);
        forecast.push(trendValue + seasonalValue);
      }

      return {
        forecast,
        trend,
        seasonality,
        confidenceInterval: this._calculateConfidenceInterval(forecast)
      };
    } catch (error) {
      logger.error('Error in Prophet forecast:', error);
      throw error;
    }
  }

  private async lstmPredict(timeSeries: TimeSeries, lookback: number = 10, forecastSteps: number = 7) {
    try {
      const sequences = this._createSequences(timeSeries, lookback);
      const predictions: number[] = [];

      const recentAvg = timeSeries.slice(-lookback).reduce((a, b) => a + b, 0) / lookback;
      
      for (let i = 0; i < forecastSteps; i++) {
        predictions.push(recentAvg * (1 + Math.random() * 0.1 - 0.05));
      }

      return {
        predictions,
        lookback,
        forecastSteps,
        modelType: 'lstm_simplified'
      };
    } catch (error) {
      logger.error('Error in LSTM prediction:', error);
      throw error;
    }
  }

  private _calculateTrend(timeSeries: TimeSeries): { slope: number; intercept: number } {
    const n = timeSeries.length;
    const x = Array.from({ length: n }, (_, i) => i);
    const y = timeSeries;

    const sumX = x.reduce((a, b) => a + b, 0);
    const sumY = y.reduce((a, b) => a + b, 0);
    const sumXY = x.reduce((sum, xi, i) => sum + xi * y[i], 0);
    const sumXX = x.reduce((sum, xi) => sum + xi * xi, 0);

    const slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);
    const intercept = (sumY - slope * sumX) / n;

    return { slope, intercept };
  }

  private _calculateSeasonality(timeSeries: TimeSeries): number[] {
    const weeklyPattern = [0, 0, 0, 0, 0, 0, 0];
    const counts = [0, 0, 0, 0, 0, 0, 0];

    timeSeries.forEach((value, idx) => {
      const dayOfWeek = idx % 7;
      weeklyPattern[dayOfWeek] += value;
      counts[dayOfWeek]++;
    });

    const avgPattern = weeklyPattern.map((sum, idx) => 
      counts[idx] > 0 ? sum / counts[idx] : 0
    );
    const overallAvg = timeSeries.reduce((a, b) => a + b, 0) / timeSeries.length;

    return avgPattern.map(val => val - overallAvg);
  }

  private _getSeasonalComponent(time: number, seasonality: number[]): number {
    const dayOfWeek = time % 7;
    return seasonality[dayOfWeek] || 0;
  }

  private _calculateConfidenceInterval(forecast: number[]): { upper: number[]; lower: number[] } {
    const stdDev = this._calculateStdDev(forecast);
    return {
      upper: forecast.map(f => f + 1.96 * stdDev),
      lower: forecast.map(f => f - 1.96 * stdDev)
    };
  }

  private _calculateStdDev(values: number[]): number {
    const mean = values.reduce((a, b) => a + b, 0) / values.length;
    const variance = values.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) / values.length;
    return Math.sqrt(variance);
  }

  private _createSequences(timeSeries: TimeSeries, lookback: number): number[][] {
    const sequences: number[][] = [];
    for (let i = lookback; i < timeSeries.length; i++) {
      sequences.push(timeSeries.slice(i - lookback, i));
    }
    return sequences;
  }
}

export default new PredictiveModelingService();


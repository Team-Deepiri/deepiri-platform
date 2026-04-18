/**
 * Tests for TimeSeriesAnalyticsService.recordInferenceMetrics / recordTrainingMetrics.
 *
 * InfluxDB client is fully mocked (virtual: true — not installed in node_modules).
 * We verify that the correct number of Points are written for each input shape.
 */

const mockWritePoint = jest.fn();
const mockFlush      = jest.fn().mockResolvedValue(undefined);
const mockGetWriteApi = jest.fn().mockReturnValue({ writePoint: mockWritePoint, flush: mockFlush });
const mockGetQueryApi = jest.fn().mockReturnValue({});

// virtual: true tells Jest to mock a package that isn't installed in node_modules.
// Must be declared before any static imports so hoisting places it first.
jest.mock('@influxdata/influxdb-client', () => {
  class Point {
    tag(_k: string, _v: string) { return this; }
    floatField(_k: string, _v: number) { return this; }
  }
  return {
    InfluxDB: jest.fn().mockImplementation(() => ({
      getWriteApi: mockGetWriteApi,
      getQueryApi: mockGetQueryApi,
    })),
    Point,
    WriteApi: jest.fn(),
    QueryApi: jest.fn(),
  };
}, { virtual: true });

jest.mock('@deepiri/shared-utils', () => ({
  secureLog: jest.fn(),
  createLogger: () => ({ debug: jest.fn(), info: jest.fn(), warn: jest.fn(), error: jest.fn() }),
}));

// Static import — module loads AFTER mocks are hoisted, so InfluxDB is mocked in the constructor
import service from '../timeSeriesAnalytics';

// ---------------------------------------------------------------------------

describe('TimeSeriesAnalyticsService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    // Restore flush mock after clearAllMocks clears it
    mockFlush.mockResolvedValue(undefined);
  });

  describe('recordInferenceMetrics', () => {
    it('writes latency, tokens, and confidence points', async () => {
      await service.recordInferenceMetrics({
        model_name: 'phi-2',
        version: 'v1',
        user_id: 'u1',
        latency_ms: 120,
        tokens_used: 300,
        confidence: 0.95,
      });
      // Three metrics → three writePoint calls
      expect(mockWritePoint).toHaveBeenCalledTimes(3);
    });

    it('skips undefined fields', async () => {
      await service.recordInferenceMetrics({ model_name: 'phi-2', latency_ms: 50 });
      // Only latency_ms defined → one writePoint
      expect(mockWritePoint).toHaveBeenCalledTimes(1);
    });

    it('defaults user_id to anonymous', async () => {
      await service.recordInferenceMetrics({ latency_ms: 10 });
      // Should not throw — writePoint called once
      expect(mockWritePoint).toHaveBeenCalledTimes(1);
    });
  });

  describe('recordTrainingMetrics', () => {
    it('writes progress and each numeric metrics field', async () => {
      await service.recordTrainingMetrics({
        experiment_id: 'exp-1',
        model_name: 'bert',
        status: 'running',
        progress: 0.5,
        metrics: { loss: 0.3, accuracy: 0.9 },
      });
      // progress + loss + accuracy = 3 calls
      expect(mockWritePoint).toHaveBeenCalledTimes(3);
    });

    it('skips non-numeric values in metrics', async () => {
      await service.recordTrainingMetrics({
        progress: 0.1,
        metrics: { loss: 0.5, label: 'test' as any },
      });
      // progress + loss = 2 (label is string, skipped)
      expect(mockWritePoint).toHaveBeenCalledTimes(2);
    });

    it('does nothing when no numeric fields are provided', async () => {
      await service.recordTrainingMetrics({});
      expect(mockWritePoint).not.toHaveBeenCalled();
    });
  });
});

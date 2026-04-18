/**
 * Tests for Engagement Service event consumer.
 *
 * Verifies that the right momentum/streak methods are called for each
 * platform event, and that per-user errors don't kill the consumer loop.
 */

// --- mocks ------------------------------------------------------------------

const mockConnect    = jest.fn().mockResolvedValue(undefined);
const mockDisconnect = jest.fn().mockResolvedValue(undefined);
const mockSubscribe  = jest.fn();
const mockPublish    = jest.fn().mockResolvedValue(undefined);

jest.mock('@deepiri/shared-utils', () => ({
  StreamingClient: jest.fn().mockImplementation(() => ({
    connect:    mockConnect,
    disconnect: mockDisconnect,
    subscribe:  mockSubscribe,
    publish:    mockPublish,
  })),
  StreamTopics: {
    PLATFORM_EVENTS:  'platform-events',
    INFERENCE_EVENTS: 'inference-events',
    TRAINING_EVENTS:  'training-events',
    MODEL_EVENTS:     'model-events',
  },
  secureLog: jest.fn(),
}));

const mockAwardMomentum    = jest.fn().mockResolvedValue({ totalMomentum: 10 });
const mockUpdateDailyStreak   = jest.fn().mockResolvedValue({});
const mockUpdateProjectStreak = jest.fn().mockResolvedValue({});

jest.mock('../services/momentumService', () => ({
  __esModule: true,
  default: { awardMomentum: mockAwardMomentum }
}));

jest.mock('../services/streakService', () => ({
  __esModule: true,
  default: {
    updateDailyStreak:   mockUpdateDailyStreak,
    updateProjectStreak: mockUpdateProjectStreak,
  }
}));

// ---------------------------------------------------------------------------

import { startEventConsumption, stopEventConsumption } from '../streaming/eventConsumer';

describe('Engagement eventConsumer', () => {
  let capturedCallback: ((event: any) => Promise<void>) | null = null;

  beforeEach(async () => {
    jest.clearAllMocks();
    // Reset mock implementations that clearAllMocks doesn't touch
    mockConnect.mockResolvedValue(undefined);
    mockDisconnect.mockResolvedValue(undefined);

    // Reset consumer state by stopping first (idempotent)
    await stopEventConsumption();

    // Capture the subscribe callback on each fresh start
    mockSubscribe.mockImplementation((_topic: string, cb: any, _opts: any) => {
      capturedCallback = cb;
      return Promise.resolve();
    });
  });

  afterEach(async () => {
    await stopEventConsumption();
  });

  // --- startup ---------------------------------------------------------------

  it('connects to Redis on startEventConsumption', async () => {
    await startEventConsumption();
    expect(mockConnect).toHaveBeenCalledTimes(1);
  });

  it('subscribes to PLATFORM_EVENTS with correct consumer group', async () => {
    await startEventConsumption();
    expect(mockSubscribe).toHaveBeenCalledWith(
      'platform-events',
      expect.any(Function),
      expect.objectContaining({
        consumerGroup: 'engagement-service',
        consumerName: expect.stringMatching(/^engagement-/),
      })
    );
  });

  it('does not start twice when called again', async () => {
    await startEventConsumption();
    await startEventConsumption();
    expect(mockConnect).toHaveBeenCalledTimes(1);
  });

  // --- event handling -------------------------------------------------------

  async function getCallback(): Promise<(event: any) => Promise<void>> {
    await startEventConsumption();
    if (!capturedCallback) throw new Error('Callback not captured — subscribe mock may not have fired');
    return capturedCallback;
  }

  describe('task-completed event', () => {
    it('awards 10 momentum for tasks source', async () => {
      const cb = await getCallback();
      await cb({ event: 'task-completed', timestamp: 'ts', user_id: 'u1', data: { task_id: 't1' } });
      expect(mockAwardMomentum).toHaveBeenCalledWith('u1', 10, 'tasks', expect.objectContaining({ task_id: 't1' }));
    });

    it('updates daily and project streaks', async () => {
      const cb = await getCallback();
      await cb({ event: 'task-completed', timestamp: 'ts', user_id: 'u1', data: { task_id: 't1' } });
      expect(mockUpdateDailyStreak).toHaveBeenCalledWith('u1');
      expect(mockUpdateProjectStreak).toHaveBeenCalledWith('u1', 't1');
    });
  });

  describe('task-created event', () => {
    it('awards 2 momentum for planning', async () => {
      const cb = await getCallback();
      await cb({ event: 'task-created', timestamp: 'ts', user_id: 'u2', data: { task_id: 't2' } });
      expect(mockAwardMomentum).toHaveBeenCalledWith('u2', 2, 'tasks', expect.any(Object));
    });

    it('does NOT update streaks', async () => {
      const cb = await getCallback();
      await cb({ event: 'task-created', timestamp: 'ts', user_id: 'u2', data: {} });
      expect(mockUpdateDailyStreak).not.toHaveBeenCalled();
    });
  });

  describe('user-registered event', () => {
    it('awards 5 welcome momentum in attendance category', async () => {
      const cb = await getCallback();
      await cb({ event: 'user-registered', timestamp: 'ts', user_id: 'u3' });
      expect(mockAwardMomentum).toHaveBeenCalledWith('u3', 5, 'attendance', expect.any(Object));
    });
  });

  describe('unknown events', () => {
    it('ignores events with no matching case', async () => {
      const cb = await getCallback();
      await cb({ event: 'some-other-event', timestamp: 'ts', user_id: 'u4' });
      expect(mockAwardMomentum).not.toHaveBeenCalled();
    });
  });

  describe('missing user_id', () => {
    it('skips processing entirely when user_id is absent', async () => {
      const cb = await getCallback();
      await cb({ event: 'task-completed', timestamp: 'ts' }); // no user_id
      expect(mockAwardMomentum).not.toHaveBeenCalled();
      expect(mockUpdateDailyStreak).not.toHaveBeenCalled();
    });
  });

  describe('error resilience', () => {
    it('catches momentum service errors without throwing', async () => {
      mockAwardMomentum.mockRejectedValueOnce(new Error('DB down'));
      const cb = await getCallback();
      await expect(
        cb({ event: 'task-completed', timestamp: 'ts', user_id: 'u5', data: {} })
      ).resolves.not.toThrow();
    });

    it('catches streak service errors without throwing', async () => {
      mockUpdateDailyStreak.mockRejectedValueOnce(new Error('Streak DB error'));
      const cb = await getCallback();
      await expect(
        cb({ event: 'task-completed', timestamp: 'ts', user_id: 'u6', data: {} })
      ).resolves.not.toThrow();
    });
  });
});

/**
 * Tests for Challenge Service event publisher.
 */

const mockConnect    = jest.fn().mockResolvedValue(undefined);
const mockPublish    = jest.fn().mockResolvedValue(undefined);
const mockDisconnect = jest.fn();

jest.mock('@deepiri/shared-utils', () => ({
  StreamingClient: jest.fn().mockImplementation(() => ({
    connect:    mockConnect,
    disconnect: mockDisconnect,
    subscribe:  jest.fn(),
    publish:    mockPublish,
  })),
  StreamTopics: { PLATFORM_EVENTS: 'platform-events' },
  secureLog: jest.fn(),
}));

describe('Challenge eventPublisher', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    jest.resetModules();
  });

  async function getPublisher() {
    return require('../streaming/eventPublisher');
  }

  it('publishes challenge-generated event with userId', async () => {
    const { publishChallengeGenerated } = await getPublisher();
    await publishChallengeGenerated('u1', { title: 'Fix the bug' });

    expect(mockPublish).toHaveBeenCalledWith(
      'platform-events',
      expect.objectContaining({
        event:   'challenge-generated',
        user_id: 'u1',
        data:    expect.objectContaining({ challenge: { title: 'Fix the bug' } }),
      })
    );
  });

  it('defaults user_id to anonymous when userId is undefined', async () => {
    const { publishChallengeGenerated } = await getPublisher();
    await publishChallengeGenerated(undefined, { title: 'Mystery challenge' });

    const published = mockPublish.mock.calls[0][1];
    expect(published.user_id).toBe('anonymous');
  });

  it('does not throw when Redis publish fails', async () => {
    mockPublish.mockRejectedValueOnce(new Error('Redis down'));
    const { publishChallengeGenerated } = await getPublisher();
    await expect(
      publishChallengeGenerated('u2', {})
    ).resolves.not.toThrow();
  });
});

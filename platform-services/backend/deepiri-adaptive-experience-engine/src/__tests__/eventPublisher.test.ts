const mockConnect = jest.fn().mockResolvedValue(undefined);
const mockPublish = jest.fn().mockResolvedValue(undefined);
const mockDisconnect = jest.fn();

jest.mock('@team-deepiri/shared-utils', () => ({
  StreamingClient: jest.fn().mockImplementation(() => ({
    connect: mockConnect,
    disconnect: mockDisconnect,
    subscribe: jest.fn(),
    publish: mockPublish,
  })),
  StreamTopics: { PLATFORM_EVENTS: 'platform-events' },
  secureLog: jest.fn(),
}), { virtual: true });

describe('Adaptive Experience eventPublisher', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    jest.resetModules();
  });

  async function getPublisher() {
    return require('../streaming/eventPublisher');
  }

  it('publishes generated experiences with userId', async () => {
    const { publishAdaptiveExperienceGenerated } = await getPublisher();
    await publishAdaptiveExperienceGenerated('u1', 'mission', { title: 'Fix the bug' });

    expect(mockPublish).toHaveBeenCalledWith(
      'platform-events',
      expect.objectContaining({
        event: 'challenge-generated',
        source: 'adaptive-experience-engine',
        user_id: 'u1',
        data: expect.objectContaining({
          experience_type: 'mission',
          challenge: { title: 'Fix the bug' },
        }),
      })
    );
  });

  it('defaults user_id to anonymous when userId is undefined', async () => {
    const { publishAdaptiveExperienceGenerated } = await getPublisher();
    await publishAdaptiveExperienceGenerated(undefined, 'prompt', { title: 'Mystery prompt' });

    const published = mockPublish.mock.calls[0][1];
    expect(published.user_id).toBe('anonymous');
  });

  it('does not throw when Redis publish fails', async () => {
    mockPublish.mockRejectedValueOnce(new Error('Redis down'));
    const { publishAdaptiveExperienceGenerated } = await getPublisher();
    await expect(
      publishAdaptiveExperienceGenerated('u2', 'objective', {})
    ).resolves.not.toThrow();
  });
});

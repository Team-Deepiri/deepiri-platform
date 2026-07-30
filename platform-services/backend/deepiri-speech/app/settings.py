from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    SERVICE_NAME: str = "deepiri-speech"
    PORT: int = 5020
    LOG_LEVEL: str = "INFO"

    SPEECH_DEVICE: str = "auto"

    STT_PROVIDER: str = "mock"
    TTS_PROVIDER: str = "mock"
    STT_MODEL: str = "small.en"
    TTS_VOICE: str = "af_heart"
    OPENAI_API_KEY: str | None = None

    KOKORO_MODEL_DIR: str = "/models/kokoro"
    KOKORO_MODEL_PATH: str | None = None
    KOKORO_VOICES_PATH: str | None = None
    KOKORO_AUTO_DOWNLOAD: bool = False

    ENABLE_SILERO_VAD: bool = True
    SILERO_VAD_THRESHOLD: float = 0.5
    VAD_SKIP_EMPTY: bool = True

    # Pipecat — always on when package present (default True)
    PIPECAT_ENABLED: bool = True
    PIPECAT_AUTO_REPLY: bool = True

    CYREX_URL: str = "http://cyrex:8000"
    CYREX_API_KEY: str = "change-me"

    # LiveKit — always wired; worker on by default
    LIVEKIT_URL: str = "ws://livekit:7880"
    LIVEKIT_PUBLIC_URL: str = "ws://localhost:7880"
    LIVEKIT_API_KEY: str = "APIdeepirispeechdev"
    LIVEKIT_API_SECRET: str = "deepiri-speech-dev-secret-change-me"
    LIVEKIT_WORKER_ENABLED: bool = True
    LIVEKIT_AGENT_IDENTITY: str = "deepiri-speech-agent"
    LIVEKIT_DEFAULT_ROOM: str = "deepiri-voice"
    LIVEKIT_ROOM_EMPTY_TIMEOUT: int = 300
    LIVEKIT_ROOM_MAX_PARTICIPANTS: int = 20

    JOBS_URL: str = "http://jobs:5007"
    TRUSS_URL: str = "http://truss:5002"

    REDIS_HOST: str = "redis"
    REDIS_PORT: int = 6379
    REDIS_PASSWORD: str | None = "password"
    REDIS_DB: int = 0
    SPEECH_STREAM: str = "speech-events"
    SPEECH_CHANNEL_PREFIX: str = "speech"
    SYNAPSE_TRANSPORT: str = "redis"
    SYNAPSE_SIDECAR_URL: str = "http://synapse-sidecar:8081"


settings = Settings()

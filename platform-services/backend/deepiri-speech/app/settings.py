from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    SERVICE_NAME: str = "deepiri-speech"
    PORT: int = 5020
    LOG_LEVEL: str = "INFO"

    # Engines: mock | faster_whisper | openai (STT); mock | openai (TTS for now)
    STT_PROVIDER: str = "mock"
    TTS_PROVIDER: str = "mock"
    STT_MODEL: str = "small.en"
    TTS_VOICE: str = "default"
    OPENAI_API_KEY: str | None = None

    # Silero VAD (requires torch when ENABLE_SILERO_VAD=1 and SPEECH_EXTRAS=1)
    ENABLE_SILERO_VAD: bool = True
    SILERO_VAD_THRESHOLD: float = 0.5
    VAD_SKIP_EMPTY: bool = True

    # Cyrex LLM for agent voice turns (optional)
    CYREX_URL: str = "http://cyrex:8000"
    CYREX_API_KEY: str = "change-me"

    # LiveKit
    LIVEKIT_URL: str = "ws://livekit:7880"
    LIVEKIT_PUBLIC_URL: str = "ws://localhost:7880"
    LIVEKIT_API_KEY: str = "APIdeepirispeechdev"
    LIVEKIT_API_SECRET: str = "deepiri-speech-dev-secret-change-me"
    LIVEKIT_WORKER_ENABLED: bool = False

    # Jobs / Truss (workflow-orchestrator on this branch; jobs+truss on origin/dev)
    JOBS_URL: str = "http://workflow-orchestrator:5002"
    TRUSS_URL: str = "http://workflow-orchestrator:5002"

    # Redis / Synapse bus
    REDIS_HOST: str = "redis"
    REDIS_PORT: int = 6379
    REDIS_PASSWORD: str | None = "password"
    REDIS_DB: int = 0
    SPEECH_STREAM: str = "speech-events"
    SPEECH_CHANNEL_PREFIX: str = "speech"
    SYNAPSE_TRANSPORT: str = "redis"  # redis | sidecar
    SYNAPSE_SIDECAR_URL: str = "http://synapse-sidecar:8081"


settings = Settings()

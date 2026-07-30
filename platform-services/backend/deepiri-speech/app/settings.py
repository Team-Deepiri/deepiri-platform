from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    SERVICE_NAME: str = "deepiri-speech"
    PORT: int = 5020
    LOG_LEVEL: str = "INFO"

    # Device: auto | cuda | mps | cpu  (also SPEECH_DEVICE env)
    SPEECH_DEVICE: str = "auto"

    # STT: mock | faster_whisper | whisper_cpp | openai
    # TTS: mock | kokoro | openai  (never xtts for commercial product)
    STT_PROVIDER: str = "mock"
    TTS_PROVIDER: str = "mock"
    STT_MODEL: str = "small.en"
    TTS_VOICE: str = "af_heart"
    OPENAI_API_KEY: str | None = None

    # Kokoro-82M (kokoro-onnx)
    KOKORO_MODEL_DIR: str = "/models/kokoro"
    KOKORO_MODEL_PATH: str | None = None
    KOKORO_VOICES_PATH: str | None = None
    KOKORO_AUTO_DOWNLOAD: bool = False

    # Silero VAD (requires torch when ENABLE_SILERO_VAD=1)
    ENABLE_SILERO_VAD: bool = True
    SILERO_VAD_THRESHOLD: float = 0.5
    VAD_SKIP_EMPTY: bool = True

    # Pipecat orchestration (optional) — transport stays our FastAPI WS
    PIPECAT_ENABLED: bool = True

    # Cyrex LLM for agent voice turns (optional)
    CYREX_URL: str = "http://cyrex:8000"
    CYREX_API_KEY: str = "change-me"

    # LiveKit — OPTIONAL (WebRTC rooms / phone only; not required for WS duplex)
    LIVEKIT_URL: str = "ws://livekit:7880"
    LIVEKIT_PUBLIC_URL: str = "ws://localhost:7880"
    LIVEKIT_API_KEY: str = "APIdeepirispeechdev"
    LIVEKIT_API_SECRET: str = "deepiri-speech-dev-secret-change-me"
    LIVEKIT_WORKER_ENABLED: bool = False

    # Jobs / Truss
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

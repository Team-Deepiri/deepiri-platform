# deepiri-speech

Self-hosted realtime STT/TTS voice worker for Deepiri.

See `docs/architecture/DEEPIRI_SPEECH_INTEGRATION.md` (platform root).

## Stack

| Piece | Default |
|--------|---------|
| API | FastAPI + Poetry |
| Media | LiveKit (separate `livekit` compose service) |
| STT | mock → faster-whisper (`poetry install -E speech`) |
| TTS | mock → Piper/Kokoro (later) |
| VAD | stub → Silero |
| Bus | Redis Streams `speech-events` + pub/sub `speech:{session}` |

## Local

```bash
cd platform-services/backend/deepiri-speech
poetry install
poetry run uvicorn app.main:app --reload --port 5020
```

## Docker

```bash
# slim (mock STT/TTS)
docker compose -f docker-compose.dev.yml up -d --build redis livekit speech

# with faster-whisper + Silero + LiveKit agent libs
SPEECH_EXTRAS=1 SPEECH_STT_PROVIDER=faster_whisper \
  docker compose -f docker-compose.dev.yml up -d --build speech
```

| Check | URL |
|-------|-----|
| Speech | `http://localhost:5020/health` |
| Worker | `http://localhost:5020/v1/worker/status` |
| LiveKit | `http://localhost:7880/` |

Jobs/Truss: set `SPEECH_URL=http://speech:5020` and use orchestrator `/speech/*` proxies.

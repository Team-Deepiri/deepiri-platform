# deepiri-speech

Poetry FastAPI speech worker with **Pipecat always-on** (in-process) and **LiveKit WebRTC** (SFU + agent).

| Layer | Default |
|-------|---------|
| Orchestration | Pipecat (`pipecat-ai[websocket,livekit]` core dep) |
| WS JSON | `/v1/session/ws` |
| Pipecat media WS | `/v1/pipecat/ws` |
| WebRTC | LiveKit + Pipecat `LiveKitTransport` agent (auto) |
| STT/TTS | mock → faster-whisper / Kokoro (`-E engines`) |
| Device | `SPEECH_DEVICE=auto` (cuda→mps→cpu) |

## Poetry

```bash
poetry install                 # Pipecat + LiveKit API always
poetry install -E engines      # + faster-whisper, Kokoro, Silero, agents
poetry run uvicorn app.main:app --reload --port 5020
```

## Docker

```bash
docker compose -f docker-compose.dev.yml up -d --build redis livekit speech
# Engines:
SPEECH_EXTRAS=engines SPEECH_STT_PROVIDER=faster_whisper SPEECH_TTS_PROVIDER=kokoro \
  docker compose -f docker-compose.dev.yml up -d --build speech
```

| Check | |
|-------|--|
| Health | `GET /health` (includes `pipecat` + `livekit.worker`) |
| Pipeline | `GET /v1/pipeline/status` |
| Rooms | `GET /v1/livekit/rooms` |
| Token | `POST /v1/livekit/token` |

`LIVEKIT_WORKER_ENABLED=1` and `PIPECAT_ENABLED=1` by default.

# deepiri-speech

Self-hosted STT/TTS for Deepiri — **Poetry FastAPI** worker.

- **Pipecat**: optional **in-process** orchestrator (`poetry install -E pipecat`) — not a separate service
- **Transport (v1)**: WebSocket `/v1/session/ws`
- **LiveKit**: optional WebRTC rooms/phone only (`-E livekit` / compose profile `webrtc`)
- **Devices**: `SPEECH_DEVICE=auto|cuda|mps|cpu` (NVIDIA → Apple MPS → CPU)

## Poetry

```bash
cd platform-services/backend/deepiri-speech
poetry install                          # mock STT/TTS — all OS
poetry install -E speech                # faster-whisper + Kokoro + Silero + Pipecat
poetry install -E apple                 # whisper.cpp (Apple/edge)
poetry install -E livekit               # WebRTC rooms only
poetry install -E full                  # everything
poetry run uvicorn app.main:app --reload --port 5020
```

| Extra | What |
|-------|------|
| `stt` | faster-whisper (CUDA/CPU via CTranslate2) |
| `tts` | kokoro-onnx (Apache/MIT — not XTTS) |
| `vad` | torch (Silero) |
| `pipecat` | pipecat-ai in-process |
| `livekit` | livekit-api / agents |
| `apple` | pywhispercpp |
| `speech` | stt+tts+vad+pipecat |

## Docker

```bash
# WS duplex only (no LiveKit)
docker compose -f docker-compose.dev.yml up -d --build redis speech

# + LiveKit WebRTC
docker compose -f docker-compose.dev.yml --profile webrtc up -d livekit

# Engines
SPEECH_EXTRAS=speech SPEECH_STT_PROVIDER=faster_whisper SPEECH_TTS_PROVIDER=kokoro \
  SPEECH_DEVICE=auto docker compose -f docker-compose.dev.yml up -d --build speech
```

| Check | URL |
|-------|-----|
| Health | `http://localhost:5020/health` |
| Pipeline | `http://localhost:5020/v1/pipeline/status` |
| WS | `ws://localhost:5020/v1/session/ws?session_id=…` |

Jobs/Truss: `SPEECH_URL=http://speech:5020` → orchestrator `/speech/*`.

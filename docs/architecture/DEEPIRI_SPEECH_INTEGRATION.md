# deepiri-speech — Platform Integration

Self-hosted realtime STT/TTS as a **Poetry FastAPI** service (`speech`).  
**Pipecat is in-process** (optional Poetry extra) — **not** a separate container.  
**LiveKit is optional** (WebRTC rooms/phone only).

## Containers

| Compose service | Port | Role |
|-----------------|------|------|
| `speech` | 5020 | Voice worker: providers + WS duplex + optional Pipecat |
| `livekit` | 7880 | Optional SFU — profile `webrtc` / `full` |

Code: `platform-services/backend/deepiri-speech/`

## Architecture

```text
Browser / Jobs / Truss
        │
        ├─ WebSocket ──────────► speech (/v1/session/ws)
        │                           │
        │                           ├─ providers (faster-whisper / Kokoro / VAD)
        │                           ├─ pipeline: native OR Pipecat (in-process)
        │                           └─ Redis speech-events
        │
        ├─ HTTP batch ─────────► speech (/v1/stt, /v1/tts) ◄── Jobs/Truss
        │
        └─ WebRTC (optional) ──► livekit ──► speech worker (rooms/phone only)
```

| Piece | Role |
|-------|------|
| **speech** | Product boundary — FastAPI + providers |
| **Pipecat** | Optional orchestration **inside** speech — not a service |
| **livekit** | Optional WebRTC SFU |
| **Jobs / Truss** | Batch via REST |
| **realtime-gateway** | Product events only — **not** PCM |

## Engines (2026 defaults)

| Layer | Default | Notes |
|-------|---------|-------|
| STT | faster-whisper | CUDA/CPU; `whisper_cpp` extra for Apple/edge |
| TTS | Kokoro-82M (kokoro-onnx) | Apache/MIT — **avoid XTTS CPML** |
| VAD | Silero (torch) | passthrough if extras missing |
| Device | `SPEECH_DEVICE=auto` | cuda → mps → cpu |
| Orchestration | native WS pipeline | Pipecat when `-E pipecat` + `PIPECAT_ENABLED=1` |

## Poetry

```bash
poetry install                 # always works (mock)
poetry install -E speech       # production engines + Pipecat
poetry install -E livekit      # WebRTC only when needed
```

## Health

| Service | Probe |
|---------|-------|
| `speech` | `curl -f http://localhost:5020/health` |
| `livekit` | optional; `wget http://127.0.0.1:7880/` |

Speech does **not** depend on LiveKit healthy.

## Dev bring-up

```bash
docker compose -f docker-compose.dev.yml up -d --build redis speech
# optional WebRTC:
docker compose -f docker-compose.dev.yml --profile webrtc up -d livekit
```

AI team `start.sh` lists `livekit speech` (explicit service names enable the livekit profile).

## Out of scope for RTG

Do not put LiveKit, Whisper, TTS, or Pipecat inside `deepiri-realtime-gateway`.

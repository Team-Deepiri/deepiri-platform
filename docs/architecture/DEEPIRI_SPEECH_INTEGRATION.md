# deepiri-speech — Platform Integration

Poetry FastAPI **`speech`** service with **Pipecat always-on** (in-process) and
**LiveKit** as the WebRTC SFU + agent path.

## Containers

| Service | Port | Role |
|---------|------|------|
| `speech` | 5020 | Providers + Pipecat pipelines + LiveKit agent worker |
| `livekit` | 7880 | WebRTC SFU (always started with speech) |

## Architecture

```text
Clients
  ├─ JSON WS ──────────► /v1/session/ws     (Pipecat oneshot STT/TTS)
  ├─ Pipecat media WS ─► /v1/pipecat/ws     (FastAPIWebsocketTransport Pipeline)
  ├─ WebRTC ───────────► livekit ◄── speech agent (Pipecat LiveKitTransport)
  └─ HTTP batch ───────► /v1/stt /v1/tts    (Jobs/Truss)
```

Pipecat is **not** a separate service. LiveKit is the SFU; the agent runs inside `speech`.

## Always-on defaults

| Setting | Default |
|---------|---------|
| `PIPECAT_ENABLED` | `1` |
| `LIVEKIT_WORKER_ENABLED` | `1` |
| Core Poetry deps | `pipecat-ai[websocket,livekit]`, `livekit-api`, `livekit` |
| Engines | mock until `SPEECH_EXTRAS=engines` |

## LiveKit capabilities wired

- Room auto-create (`livekit.yaml` + `POST /v1/livekit/rooms`)
- Full access tokens (publish/subscribe/data/metadata/admin/agent)
- Default room `deepiri-voice` ensured on startup
- Agent worker: **Pipecat LiveKitTransport** → livekit-agents fallback
- Redis `speech-events` on session/STT

## Pipecat capabilities wired

- Provider STT/TTS/VAD as FrameProcessors
- Cyrex (or echo) LLM turn
- Interruptible Pipeline (`allow_interruptions=True`)
- FastAPI WebSocket transport + LiveKit transport

## Dev

```bash
docker compose -f docker-compose.dev.yml up -d --build redis livekit speech
curl -s localhost:5020/health | jq .pipecat,.livekit
curl -s localhost:5020/v1/pipeline/status | jq
curl -s localhost:5020/v1/livekit/rooms | jq
```

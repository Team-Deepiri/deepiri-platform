# deepiri-speech — Platform Integration

Self-hosted realtime STT/TTS (LiveKit + Python voice worker) as a **new** platform
service family. Not colocated in realtime-gateway. Encore is not used.

## Containers

| Compose service | Port | Role |
|-----------------|------|------|
| `livekit` | 7880 | WebRTC media gateway (Opus, rooms, reconnect) |
| `speech` | 5020 | Poetry/FastAPI **voice worker**: STT/TTS; duplex WS; LiveKit tokens |

Code: `platform-services/backend/deepiri-speech/`

## How it fits the platform

```text
Browser / cyrex-interface / web-frontend
        │
        ├─ WebRTC ──────────────► livekit ──► speech (VAD/STT/TTS)
        │                              │
        │                              └─► Cyrex (LLM / agents) when agent voice
        │
        ├─ Socket.IO ───────────► realtime-gateway   (product events / signaling only)
        │                              ▲
        │                              │ speech-events (lifecycle, not PCM)
        │                         sugar-glider / redis streams
        │
        └─ HTTP batch ──────────► jobs / truss ──► speech REST
```

| Platform piece | Relationship to speech |
|----------------|------------------------|
| **speech** | Owns live duplex + STT/TTS inference |
| **livekit** | Owns WebRTC media path (not Socket.IO) |
| **Cyrex** | LLM/agents; called by speech worker or Truss |
| **Jobs** | Batch: transcribe file / TTS document → POST speech |
| **Truss** | Workflows: jobStep(STT) → Cyrex → jobStep(TTS) → notify |
| **messaging** | Text chat rooms; may store transcript text |
| **realtime-gateway** | Socket.IO fan-out only (`speech-events` → UI toasts). **Not** PCM |
| **api-gateway** | Auth/session for speech control APIs if exposed publicly |
| **synapse / sugar-glider** | Bus for `speech-events` control plane |
| **Redis** | Pub/sub `speech:{session_id}` for partials across workers |

## Defaults (engines)

- STT: **mock** in slim image; **faster-whisper** when `SPEECH_EXTRAS=1` + `SPEECH_STT_PROVIDER=faster_whisper`
- VAD: **Silero** when extras+torch available (`SPEECH_ENABLE_SILERO_VAD=1`); else passthrough
- TTS: **mock** → Kokoro/Piper later (prefer Apache/MIT; avoid XTTS CPML for product)
- LiveKit worker: `LIVEKIT_WORKER_ENABLED=1` (stub until `livekit-agents` installed)
- LLM: Cyrex + Ollama (not a separate vLLM box in v1)

## Jobs / Truss → speech

Workflow orchestrator (Jobs/Truss stand-in on this branch) calls:

| Orchestrator route | Speech route |
|--------------------|--------------|
| `GET /speech/health` | `GET /health` |
| `POST /speech/transcribe` | `POST /v1/stt` |
| `POST /speech/synthesize` | `POST /v1/tts` |

Client: `deepiri-workflow-orchestrator/src/speechClient.ts` (`SPEECH_URL=http://speech:5020`).

## Health checks

| Service | Probe |
|---------|-------|
| `livekit` | `wget` `http://127.0.0.1:7880/` |
| `speech` | `curl -f http://localhost:5020/health` |

`speech` waits for `livekit` healthy before starting.

## Dev bring-up

Speech is listed directly in:

1. **AI team** `team_dev_environments/ai-team/{start,stop,build}.sh` (`SERVICES` includes `livekit` `speech`)
2. **Full / platform** stacks once services exist in `docker-compose.dev.yml`
   (`platform-engineers` uses `config --services` and picks them up automatically)
3. **`setup-deepiri-dev.sh`** — runs the team's `build.sh` + `start.sh` (no separate service list)
4. **`diri-cyrex/setup.sh --run`** — includes `livekit` `speech`  
   (`--run --headless` stays engine-only without LiveKit/speech)

Compose must define `livekit` and `speech` before those names will start successfully.

## Out of scope for RTG

Do not put LiveKit, Whisper, or TTS inside `deepiri-realtime-gateway`.
Media path ≠ Socket.IO product event path.

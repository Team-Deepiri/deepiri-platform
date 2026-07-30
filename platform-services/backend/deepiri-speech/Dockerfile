FROM python:3.11-slim-bookworm

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    build-essential \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir poetry==2.1.3 \
 && poetry config virtualenvs.create false

COPY pyproject.toml poetry.lock README.md ./

# Core always installs Pipecat + LiveKit API.
# SPEECH_EXTRAS: 0=core | 1|speech|engines = +whisper/kokoro/torch/agents | full=+apple
ARG SPEECH_EXTRAS=0
RUN set -e; \
    case "$SPEECH_EXTRAS" in \
      1|speech|engines) poetry install --no-ansi --no-interaction --extras engines --no-root ;; \
      full) poetry install --no-ansi --no-interaction --extras full --no-root ;; \
      *) poetry install --no-ansi --no-interaction --no-root ;; \
    esac

COPY app ./app

EXPOSE 5020

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:5020/health || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "5020"]

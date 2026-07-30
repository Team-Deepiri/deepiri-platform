FROM python:3.11-slim-bookworm

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    build-essential \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir poetry==2.1.3 \
 && poetry config virtualenvs.create false

COPY pyproject.toml README.md ./
# Install base deps only in image; -E speech pulls faster-whisper at build when SPEECH_EXTRAS=1
ARG SPEECH_EXTRAS=0
RUN if [ "$SPEECH_EXTRAS" = "1" ]; then \
      poetry install --no-ansi --no-interaction --extras speech --no-root; \
    else \
      poetry install --no-ansi --no-interaction --no-root; \
    fi

COPY app ./app

EXPOSE 5020

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
  CMD curl -f http://localhost:5020/health || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "5020"]

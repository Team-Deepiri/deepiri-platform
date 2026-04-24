# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Base image
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FROM ollama/ollama:latest AS base

LABEL org.opencontainers.image.source="https://github.com/deepiri/deepiri-platform"
LABEL org.opencontainers.image.description="Deepiri Ollama with automatic GPU/CPU detection"

WORKDIR /root

# Install dependencies
RUN apk add --no-cache curl jq || \
    (apt-get update && apt-get install -y curl jq && rm -rf /var/lib/apt/lists/*) || \
    (yum install -y curl jq && yum clean all) || \
    echo "curl/jq already installed"

# Build arguments
ARG PRE_PULL_MODELS=true
ARG MODELS="mistral:7b llama3:8b codellama:7b"


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Stage 1: Model downloader
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FROM base AS model-downloader

RUN if [ "$PRE_PULL_MODELS" = "true" ]; then \
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" && \
        echo "📦 Downloading models during build: $MODELS" && \
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" && \
        \
        # Start Ollama server \
        ollama serve & \
        OLLAMA_PID=$! && \
        \
        # Wait for server ready \
        for i in $(seq 1 60); do \
            if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then \
                echo "✅ Ollama ready"; \
                break; \
            fi; \
            if [ $i -eq 60 ]; then \
                echo "⚠️ Ollama not ready, skipping downloads"; \
                kill $OLLAMA_PID 2>/dev/null || true; \
                exit 0; \
            fi; \
            sleep 1; \
        done && \
        \
        # Pull models \
        for model in $MODELS; do \
            echo "⬇️ Pulling $model"; \
            ollama pull "$model" || echo "⚠️ Failed: $model"; \
        done && \
        \
        # Stop server \
        kill $OLLAMA_PID 2>/dev/null || true && \
        wait $OLLAMA_PID 2>/dev/null || true && \
        \
        echo "✅ Models baked into image"; \
    else \
        echo "ℹ️ Skipping model pre-pull"; \
    fi


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Final image
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FROM base

# Copy pre-downloaded models
COPY --from=model-downloader /root/.ollama /root/.ollama 2>/dev/null || true

# Copy entrypoint
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Expose port
EXPOSE 11434

# Start Ollama
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
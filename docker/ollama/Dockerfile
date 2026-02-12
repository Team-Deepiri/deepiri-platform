# Ollama Dockerfile with build-time model pre-pull
# Models are downloaded during build and baked into the image
FROM ollama/ollama:latest AS base

# Set working directory
WORKDIR /root

# Install curl and jq for model management
RUN apk add --no-cache curl jq || \
    (apt-get update && apt-get install -y curl jq && rm -rf /var/lib/apt/lists/*) || \
    (yum install -y curl jq && yum clean all) || \
    echo "curl/jq installation skipped (may already be installed)"

# Build arguments for model pre-pull
ARG PRE_PULL_MODELS=true
ARG MODELS="mistral:7b llama3:8b codellama:7b"

# Stage 1: Download models during build
FROM base AS model-downloader

# Only download if PRE_PULL_MODELS is true
RUN if [ "$PRE_PULL_MODELS" = "true" ]; then \
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" && \
        echo "Downloading models during build: $MODELS" && \
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" && \
        \
        # Start Ollama server in background for model downloads \
        echo "🚀 Starting Ollama server for model downloads..." && \
        ollama serve & \
        OLLAMA_PID=$! && \
        \
        # Wait for Ollama to be ready \
        echo "⏳ Waiting for Ollama server..." && \
        for i in $(seq 1 60); do \
            if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then \
                echo "✅ Ollama server ready" && \
                break; \
            fi; \
            if [ $i -eq 60 ]; then \
                echo "⚠️ Ollama server not ready after 60s, skipping model downloads" && \
                kill $OLLAMA_PID 2>/dev/null || true && \
                exit 0; \
            fi; \
            sleep 1; \
        done && \
        \
        # Download each model \
        for model in $MODELS; do \
            echo "" && \
            echo "📦 Downloading model: $model" && \
            if ollama pull "$model"; then \
                echo "✅ Successfully downloaded: $model"; \
            else \
                echo "⚠️ Model download failed for $model (will be available after manual pull)"; \
            fi; \
        done && \
        \
        # Stop Ollama server \
        kill $OLLAMA_PID 2>/dev/null || true && \
        wait $OLLAMA_PID 2>/dev/null || true && \
        \
        echo "" && \
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" && \
        echo "✅ Model download complete - models are baked into the image" && \
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
    else \
        echo "ℹ️ Model pre-pull disabled (PRE_PULL_MODELS=false)"; \
        echo "   Models will be installed at runtime via check-ollama-models.sh script"; \
    fi

# Stage 2: Final image with models
FROM base

# Copy models from downloader stage (if they were downloaded)
# Models are stored in /root/.ollama, so we copy that directory
COPY --from=model-downloader /root/.ollama /root/.ollama 2>/dev/null || true

# Copy entrypoint script (for runtime model management if needed)
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Expose Ollama port
EXPOSE 11434

# Use entrypoint script (handles runtime model pulls if models weren't pre-downloaded)
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

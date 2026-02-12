# Ollama Dockerfile with pre-pulled models
# This ensures models are baked into the image, eliminating runtime download overhead
FROM ollama/ollama:latest

# Set working directory
WORKDIR /root

# Pre-pull models during build (optional - can be disabled via build arg)
# This eliminates the 1.2-3.3s first-request penalty from model loading
# Models are baked into the image, so no runtime download is needed
# 
# To disable pre-pull and use check-ollama-models.sh script instead:
#   docker build --build-arg PRE_PULL_MODELS=false -t ollama-custom .
#
# To customize which models to pre-pull (space-separated):
#   docker build --build-arg MODELS="mistral:7b llama3:8b codellama:7b" -t ollama-custom .
# 
# Example with more models:
#   docker build --build-arg MODELS="mistral:7b llama3:8b codellama:7b gemma2:2b" -t ollama-custom .

ARG PRE_PULL_MODELS=true
ARG MODELS="mistral:7b llama3:8b codellama:7b"

# Only pre-pull if PRE_PULL_MODELS is true
# Supports multiple models (space-separated)
RUN if [ "$PRE_PULL_MODELS" = "true" ]; then \
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" && \
        echo "Pre-pulling models during build: $MODELS" && \
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" && \
        for model in $MODELS; do \
            echo "" && \
            echo "📦 Pre-pulling model: $model" && \
            ollama pull "$model" && \
            echo "✅ Successfully pre-pulled: $model" || \
            echo "⚠️  Model pull failed for $model (may need network access during build)"; \
        done && \
        echo "" && \
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" && \
        echo "✅ Model pre-pull complete" && \
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; \
    else \
        echo "ℹ️  Model pre-pull disabled (PRE_PULL_MODELS=false)"; \
        echo "   Models will be installed at runtime via check-ollama-models.sh script"; \
        echo "   This provides flexibility but first request may be slower (1.2-3.3s penalty)"; \
    fi

# Expose Ollama port
EXPOSE 11434

# Start Ollama server
CMD ["ollama", "serve"]


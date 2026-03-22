FROM ollama/ollama:latest

# The official ollama image already has full CUDA support
# GPU is automatically detected and used if available
# No configuration needed - it just works!

# Set labels for identification
LABEL org.opencontainers.image.source="https://github.com/deepiri/deepiri-platform"
LABEL org.opencontainers.image.description="Deepiri Ollama with automatic GPU/CPU detection"

# Set working directory
WORKDIR /root

# Install dependencies (for pre-pull script)
RUN apk add --no-cache curl jq || \
    (apt-get update && apt-get install -y curl jq && rm -rf /var/lib/apt/lists/*) || \
    (yum install -y curl jq && yum clean all) || \
    echo "curl/jq already installed"

# Build arguments
ARG PRE_PULL_MODELS=true
ARG MODELS="mistral:7b llama3:8b codellama:7b"

# Copy scripts
COPY pre_pull.sh /pre_pull.sh
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

# Make scripts executable
RUN chmod +x /pre_pull.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Run pre-pull during build (refactored logic)
RUN if [ "$PRE_PULL_MODELS" = "true" ]; then \
    MODELS="$MODELS" /pre_pull.sh; \
    else \
    echo "Skipping pre-pull"; \
    fi

# Expose Ollama port
EXPOSE 11434

# Start server
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
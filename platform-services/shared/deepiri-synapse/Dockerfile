FROM python:3.11-slim

WORKDIR /app

# Copy deepiri-modelkit first (needed for installation)
COPY deepiri-modelkit /app/deepiri-modelkit

# Copy requirements
COPY platform-services/shared/deepiri-synapse/requirements.txt /app/requirements.txt

# Remove deepiri-modelkit editable install from requirements.txt
RUN sed -i '/deepiri-modelkit/d' /app/requirements.txt && \
    sed -i '/^-e.*modelkit/d' /app/requirements.txt || true

# Install deepiri-modelkit as editable package (before other requirements)
RUN if [ -d "/app/deepiri-modelkit" ] && [ -f "/app/deepiri-modelkit/pyproject.toml" ]; then \
        echo "Installing deepiri-modelkit..." && \
        pip install --no-cache-dir -e /app/deepiri-modelkit || \
        (echo "Warning: deepiri-modelkit installation failed" && true); \
    else \
        echo "Warning: deepiri-modelkit not found, skipping installation"; \
    fi

# Install other requirements
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY platform-services/shared/deepiri-synapse/app /app/app

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8002"]


# MPS Full Setup Guide

## Overview

This guide walks through the complete setup process for running the Deepiri platform with Apple Metal Performance Shaders (MPS) acceleration on macOS.

**Requirements:**
- Python ≥ 3.11
- Ollama

## Creating the Virtual Environment

Open the directory containing `deepiri-platform` and create a virtual environment with MPS support.

```bash
python3 -m venv venv
source venv/bin/activate

pip install torch torchvision torchaudio

# Verify MPS is available
python -c "import torch; print(f'MPS available: {torch.backends.mps.is_available()}')"
```

## Pulling Submodules

Set up Git hooks and pull the required submodules.

```bash
cd deepiri-platform/team_submodule_commands/ai-team
./setup-hooks.sh
./pull_submodules.sh
```

## Installing Dependencies

Install the Deepiri model kit and Cyrex requirements.

```bash
cd deepiri-platform
pip install -e deepiri-modelkit

cd diri-cyrex
mkdir -p models/cache  # Required for modelkit to work locally
pip install -r requirements-mpsos.txt
```

## Running the MPS Configuration Script

Execute the MPS configuration script to set up macOS-specific GPU settings.

```bash
cd deepiri-platform/diri-cyrex/scripts/gpu
./configure-mps-macos.sh
```

## Environment Configuration

Configure the environment variables for local development. You can either copy the example file or manually create your `.env` in `diri-cyrex`.

### Option 1: Copy the Example File

```bash
cp .env.example.mpsmac .env
```

### Option 2: Manual Configuration

Create a `.env` file in `diri-cyrex` with the following contents:

```bash
# Local development - pointing to Docker services on host ports

# Model cache (local writable path instead of /app)
MODEL_CACHE_DIR=./models/cache

# Redis (Docker exposes on port 6380, requires password)
REDIS_HOST=localhost
REDIS_PORT=6380
REDIS_PASSWORD=redispassword

# MLflow (Docker exposes on port 5500)
MLFLOW_TRACKING_URI=http://localhost:5500

# Milvus (Docker exposes on port 19530)
MILVUS_HOST=localhost
MILVUS_PORT=19530

# PostgreSQL (Docker exposes on port 5432)
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=deepiri
POSTGRES_USER=deepiri
POSTGRES_PASSWORD=deepiripassword

# Ollama (Docker exposes on port 11435)
OLLAMA_BASE_URL=http://localhost:11435

# Synapse (Docker exposes on port 8002)
SYNAPSE_URL=http://localhost:8002

# MinIO/S3 (Docker exposes on port 9000)
S3_ENDPOINT_URL=http://localhost:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
```

## Starting Docker Services

Navigate to the AI team development scripts and start the Docker services.

```bash
cd deepiri-platform/team_dev_environments/ai-team
./start.sh
```

## Starting Ollama Locally

Open a **new terminal** and start the Ollama service.

```bash
ollama serve
ollama pull llama3:8b
```

## Starting Cyrex Locally

Open a **new terminal** and navigate to `diri-cyrex` to start the Cyrex service.

```bash
cd deepiri-platform/diri-cyrex
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## Stopping All Services

To shut down the environment:

- Press `Ctrl + C` in the terminal running Ollama
- Press `Ctrl + C` in the terminal running Cyrex
- Run the stop script to turn off Docker services:

```bash
cd deepiri-platform/team_dev_environments/ai-team
./stop.sh
```

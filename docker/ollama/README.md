# Ollama Docker Image with Model Pre-pull Support

This Dockerfile extends the official `ollama/ollama:latest` image to support model pre-pulling at container startup (not during build, to avoid build-time issues).

## Features

- ✅ **Pre-pull multiple models** at container startup
- ✅ **Flexible configuration** via environment variables
- ✅ **Fallback support** - can disable pre-pull and use `check-ollama-models.sh` script instead
- ✅ **No build-time issues** - models pulled when Ollama server is running

## Default Models

By default, the following models are pre-pulled at startup:

1. **mistral:7b** (4.1GB) - Default model, efficient and high quality
2. **llama3:8b** (4.7GB) - Alternative general-purpose model
3. **codellama:7b** (3.8GB) - Specialized for coding tasks

**Total size**: ~12.6GB

## How It Works

Models are pre-pulled at container startup using an entrypoint script. This means:

- ✅ Ollama server starts first
- ✅ Models are pulled after server is ready
- ✅ No build-time network issues
- ✅ Models stored in volume for persistence

## Usage

### Option 1: Use Default Models (Recommended)

The default configuration in `docker-compose.dev.yml` will automatically pre-pull the default models:

```bash
docker-compose up ollama
```

### Option 2: Customize Models via Environment Variables

Edit `docker-compose.dev.yml` or set environment variables:

```yaml
environment:
  PRE_PULL_MODELS: "true"
  MODELS: "mistral:7b llama3:8b codellama:7b gemma2:2b"
```

Or override via `.env` file:

```bash
# .env
PRE_PULL_MODELS=true
MODELS="mistral:7b llama3:8b codellama:7b"
```

### Option 3: Disable Pre-pull (Use Script Instead)

Set `PRE_PULL_MODELS=false` in environment variables:

```yaml
environment:
  PRE_PULL_MODELS: "false"
```

Then use the script to install models:

```bash
./scripts/llm/check-ollama-models.sh
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PRE_PULL_MODELS` | `true` | Enable/disable model pre-pull at startup |
| `MODELS` | `"mistral:7b llama3:8b codellama:7b"` | Space-separated list of models to pre-pull |

## Examples

### Minimal Setup (Just Default Model)

```yaml
environment:
  MODELS: "mistral:7b"
```

### Full Setup (Multiple Models)

```yaml
environment:
  MODELS: "mistral:7b llama3:8b codellama:7b gemma2:2b phi3:mini"
```

### Development Setup (No Pre-pull)

```yaml
environment:
  PRE_PULL_MODELS: "false"
```

## Model Recommendations

### Small & Fast (Good for CPU)
- `mistral:7b` (4.1GB) - Default, balanced
- `llama3.2:1b` (1.3GB) - Very fast, smaller
- `phi3:mini` (2.3GB) - Fast, efficient

### Balanced (GPU Recommended)
- `llama3:8b` (4.7GB) - General purpose
- `gemma2:9b` (5.4GB) - Google's model
- `qwen2.5:7b` (4.4GB) - Alibaba's model

### Coding Tasks
- `codellama:7b` (3.8GB) - General coding
- `codellama:13b` (7.3GB) - Larger, better quality
- `deepseek-coder:6.7b` (4.1GB) - Advanced coding

### Large & Powerful (Requires 16GB+ VRAM)
- `mistral-nemo:12b` (7.0GB) - Enhanced Mistral
- `llama3.1:8b` (4.7GB) - Latest Llama
- `gemma2:27b` (16GB) - Very large

## Notes

- **Startup Time**: Model downloads at startup can take 5-15 minutes depending on internet speed
- **Network Required**: Container startup requires internet access to download models
- **Volume Persistence**: Models are stored in the `ollama_dev_data` volume for persistence across container restarts
- **First Startup**: First container start will take longer due to model downloads
- **Subsequent Starts**: Models are cached in the volume, so subsequent starts are faster

## Troubleshooting

### Container Fails to Start

- Check logs: `docker logs deepiri-ollama-dev`
- Ensure internet access is available
- Verify model names are correct (e.g., `mistral:7b` not `mistral`)

### Models Not Pre-pulled

- Check `PRE_PULL_MODELS` environment variable is set to `"true"`
- Check `MODELS` environment variable is set correctly
- Check container logs for pull errors

### Want to Add Models Later

- Models can be added at runtime using `check-ollama-models.sh` script
- Or use `docker exec deepiri-ollama-dev ollama pull <model_name>`

### Slow Startup

- This is normal on first startup (models are being downloaded)
- Subsequent starts are faster (models cached in volume)
- To speed up, reduce number of models or use smaller models

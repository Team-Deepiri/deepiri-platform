# Ollama Docker Image with Pre-pulled Models

This Dockerfile extends the official `ollama/ollama:latest` image to pre-pull models during the build process, eliminating the first-request penalty (1.2-3.3s) from model loading.

## Features

- ✅ **Pre-pull multiple models** during Docker build
- ✅ **Flexible configuration** via build arguments
- ✅ **Fallback support** - can disable pre-pull and use `check-ollama-models.sh` script instead
- ✅ **Models baked into image** - no runtime download needed

## Default Models

By default, the following models are pre-pulled:

1. **mistral:7b** (4.1GB) - Default model, efficient and high quality
2. **llama3:8b** (4.7GB) - Alternative general-purpose model
3. **codellama:7b** (3.8GB) - Specialized for coding tasks

**Total size**: ~12.6GB

## Usage

### Option 1: Use Default Models (Recommended)

```bash
# Build with default models (mistral:7b, llama3:8b, codellama:7b)
docker-compose build ollama
```

### Option 2: Customize Models

```bash
# Pre-pull specific models (space-separated)
docker-compose build --build-arg MODELS="mistral:7b llama3:8b" ollama

# Or with more models
docker-compose build --build-arg MODELS="mistral:7b llama3:8b codellama:7b gemma2:2b" ollama
```

### Option 3: Disable Pre-pull (Use Script Instead)

```bash
# Disable pre-pull, install models at runtime via script
docker-compose build --build-arg PRE_PULL_MODELS=false ollama

# Then use the script to install models
./scripts/llm/check-ollama-models.sh
```

## Build Arguments

| Argument | Default | Description |
|----------|---------|-------------|
| `PRE_PULL_MODELS` | `true` | Enable/disable model pre-pull during build |
| `MODELS` | `"mistral:7b llama3:8b codellama:7b"` | Space-separated list of models to pre-pull |

## Examples

### Minimal Setup (Just Default Model)
```bash
docker build --build-arg MODELS="mistral:7b" -t ollama-custom .
```

### Full Setup (Multiple Models)
```bash
docker build --build-arg MODELS="mistral:7b llama3:8b codellama:7b gemma2:2b phi3:mini" -t ollama-custom .
```

### Development Setup (No Pre-pull)
```bash
docker build --build-arg PRE_PULL_MODELS=false -t ollama-custom .
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

- **Image Size**: Pre-pulling models increases the Docker image size significantly (~12GB+ for default models)
- **Build Time**: Model downloads during build can take 5-15 minutes depending on internet speed
- **Network Required**: Build process requires internet access to download models
- **Volume Persistence**: Models are also stored in the `ollama_dev_data` volume for persistence across container restarts

## Troubleshooting

### Build Fails with "Model pull failed"
- Ensure you have internet access during build
- Check that model names are correct (e.g., `mistral:7b` not `mistral`)
- Some models may not be available in Ollama registry

### Image Too Large
- Reduce number of models: `--build-arg MODELS="mistral:7b"`
- Use smaller models: `--build-arg MODELS="llama3.2:1b phi3:mini"`
- Disable pre-pull and use script: `--build-arg PRE_PULL_MODELS=false`

### Want to Add Models Later
- Models can be added at runtime using `check-ollama-models.sh` script
- Or use `docker exec deepiri-ollama-dev ollama pull <model_name>`


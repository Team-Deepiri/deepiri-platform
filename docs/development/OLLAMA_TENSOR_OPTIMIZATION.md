# Ollama Tensor Loading Optimization Guide

## Overview

This guide explains how to speed up tensor initialization on first use for Ollama models. The slow "loading model tensors" phase you see in logs is caused by:

1. **Disk I/O**: Reading large model files from disk
2. **Memory mapping overhead**: First access to mmap'd tensors triggers page faults
3. **Kernel compilation**: First inference compiles optimized CUDA/CPU kernels
4. **Layer initialization**: Model layers are initialized on first access

## Implemented Optimizations

### 1. Environment Variables (Docker Compose)

Add to both `docker-compose.yml` and `docker-compose.dev.yml`:

```yaml
environment:
  OLLAMA_NUM_PARALLEL: "1"          # Reduce contention during loading
  OLLAMA_KEEP_ALIVE: "24h"          # Keep models loaded longer (reduces reload overhead)
  OLLAMA_MAX_LOADED_MODELS: "2"     # Limit concurrent models to reduce memory pressure
```

**Benefits:**
- `OLLAMA_NUM_PARALLEL=1`: Prevents multiple parallel loads from competing for resources
- `OLLAMA_KEEP_ALIVE=24h`: Keeps models in memory for 24 hours, avoiding reload overhead
- `OLLAMA_MAX_LOADED_MODELS=2`: Prevents memory pressure from too many loaded models

### 2. Model Warmup Function

Added `warmup_ollama_model()` function in `app/integrations/ollama_container.py`:

- Runs a minimal inference (1 token) to trigger tensor loading
- Pre-compiles kernels and initializes layers
- Can be called on startup or manually

**Usage:**
```python
from app.integrations.ollama_container import warmup_ollama_model

# Warmup a specific model
await warmup_ollama_model("llama3:8b")
```

### 3. Automatic Startup Warmup

Enabled via `OLLAMA_WARMUP_ENABLED` setting (default: `False`):

```python
# In settings.py
OLLAMA_WARMUP_ENABLED: bool = False  # Set to True to enable
```

Or via environment variable:
```bash
OLLAMA_WARMUP_ENABLED=true
```

When enabled, the model is automatically warmed up in the background during application startup.

## Additional Optimization Techniques

### 1. Use Quantized Models

Quantized models (Q4_K_M, Q5_K_M) load faster than full-precision:
- Smaller file size = faster disk I/O
- Less memory = faster allocation
- Example: `llama3:8b-q4_0` instead of `llama3:8b`

### 2. Fast Storage

Ensure `ollama_data` volume is on fast storage:
- **Best**: NVMe SSD
- **Good**: SATA SSD
- **Avoid**: HDD or network storage

### 3. Keep Container Running

Ollama keeps models loaded between requests. Avoid restarting the container unnecessarily.

### 4. Preload Models

Manually preload models after container starts:
```bash
docker exec deepiri-ollama-dev ollama pull llama3:8b
docker exec deepiri-ollama-dev ollama run llama3:8b "test"
```

## Performance Expectations

**Before optimization:**
- First inference: 10-30 seconds (tensor loading + kernel compilation)
- Subsequent inferences: 1-3 seconds

**After optimization:**
- First inference (with warmup): 1-3 seconds (warmup already done)
- Subsequent inferences: 1-3 seconds (model stays loaded)

**Warmup cost:**
- One-time cost: ~10-30 seconds on startup
- Benefit: Eliminates first-request delay for users

## Configuration Examples

### Enable Warmup in Development

Add to `.env` or `docker-compose.dev.yml`:
```yaml
environment:
  OLLAMA_WARMUP_ENABLED: "true"
```

### Production Configuration

For production, you may want to:
1. Enable warmup if you have predictable traffic patterns
2. Disable warmup if you want faster startup times
3. Use a health check endpoint that triggers warmup on first request

## Monitoring

Check warmup status in logs:
```
INFO: Warming up Ollama model: llama3:8b (this may take a moment on first use)
INFO: Ollama warmup initiated in background
INFO: Model warmup completed: llama3:8b (load_duration: 1234ms, total_duration: 5678ms)
```

## Troubleshooting

### Warmup Times Out

If warmup times out (>300s), check:
1. Ollama container is running: `docker ps | grep ollama`
2. Model is available: `docker exec deepiri-ollama-dev ollama list`
3. Network connectivity between services

### Model Not Staying Loaded

If models unload frequently:
1. Increase `OLLAMA_KEEP_ALIVE` (e.g., `48h` or `72h`)
2. Check available memory: `docker stats deepiri-ollama-dev`
3. Reduce `OLLAMA_MAX_LOADED_MODELS` if memory constrained

### Still Slow First Request

If first request is still slow after warmup:
1. Verify warmup completed: Check logs for "Model warmup completed"
2. Check if model was unloaded: `docker exec deepiri-ollama-dev ollama ps`
3. Consider using quantized models for faster loading

## References

- [Ollama Environment Variables](https://github.com/ollama/ollama/blob/main/docs/faq.md)
- [Fast Model Loading Research](https://arxiv.org/abs/2505.23072)
- [Model Loading Best Practices](https://docs.nvidia.com/deeplearning/tensorrt/latest/performance/best-practices.html)


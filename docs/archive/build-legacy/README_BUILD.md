# Build Guide - GPU Detection & CPU Fallback

## Quick Start

### Automatic GPU Detection (Recommended)

The build system automatically detects your GPU and chooses the best base image:

**Windows (PowerShell):**
```powershell
cd deepiri
.\scripts\build-cyrex-auto.ps1
```

**Linux/Mac:**
```bash
cd deepiri
./scripts/build-cyrex-auto.sh
```

This will:
- ✅ Detect if you have a GPU with ≥4GB VRAM
- ✅ Use CUDA image if GPU is good enough
- ✅ Fall back to CPU image if no GPU or insufficient
- ✅ Build much faster (no 1.5GB CUDA downloads on CPU builds)

### Manual Build

**Force CPU (fastest, no GPU downloads):**
```bash
BASE_IMAGE=pytorch/pytorch:2.0.0-cpu docker compose -f docker-compose.dev.yml build cyrex
```

**Force GPU:**
```bash
BASE_IMAGE=pytorch/pytorch:2.0.0-cuda12.1-cudnn8-runtime docker compose -f docker-compose.dev.yml build cyrex
```

## How It Works

1. **GPU Detection**: Scripts check `nvidia-smi` and GPU memory
2. **Smart Selection**: 
   - GPU ≥4GB → CUDA image (with GPU acceleration)
   - No GPU or <4GB → CPU image (faster builds, no CUDA downloads)
3. **Build Args**: Docker Compose uses `BASE_IMAGE` build arg
4. **Runtime Detection**: Container detects CUDA at runtime and installs GPU packages only if available

## Benefits

- **No More Freezing**: CPU builds skip 1.5GB CUDA downloads
- **Faster Builds**: Prebuilt PyTorch images (already cached)
- **Automatic**: Detects GPU and chooses best option
- **Flexible**: Can override with environment variable

## Troubleshooting

**Build still slow?** Use CPU build:
```bash
BASE_IMAGE=pytorch/pytorch:2.0.0-cpu docker compose build cyrex
```

**GPU not detected?** Check:
```bash
nvidia-smi  # Should show your GPU
```

**Want to adjust GPU requirements?** Edit:
- `diri-cyrex/detect_gpu.sh` (Linux/Mac)
- `diri-cyrex/detect_gpu.ps1` (Windows)

Change `MIN_GPU_MEMORY_GB=4` to your preferred minimum.


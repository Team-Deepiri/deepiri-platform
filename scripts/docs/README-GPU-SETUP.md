# Ollama GPU/CPU - Automatic Detection

## **Just Works - No Configuration Needed!**

```bash
docker compose -f docker-compose.dev.yml up -d ollama
```

The official `ollama/ollama` image **automatically detects GPU** and uses it if available. Falls back to CPU if not.

---

## How It Works

1. **Ollama image has built-in CUDA support**
2. **If GPU is available** → Ollama uses it automatically
3. **If no GPU** → Ollama uses CPU automatically
4. **You don't need to do anything** - it just works!

---

## For GPU Users (One-Time Setup)

If you have an NVIDIA GPU and want Docker to **automatically pass GPU to all containers**:

### Linux / WSL2:

```bash
# Install NVIDIA Container Toolkit (if not installed)
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

# Configure Docker to use nvidia as default runtime
sudo nvidia-ctk runtime configure --runtime=docker --set-as-default

# Restart Docker
sudo systemctl restart docker
```

**That's it!** After this one-time setup, all Docker containers (including Ollama) automatically have GPU access.

### Verify GPU Works:

```bash
# Test GPU access
docker run --rm nvidia/cuda:12.0.0-base-ubuntu20.04 nvidia-smi

# Check Ollama is using GPU
docker logs deepiri-ollama-dev | grep -i "cuda\|gpu"
```

---

## Verify Ollama Compute Mode

```bash
docker logs deepiri-ollama-dev
```

**GPU Mode** - Look for:
```
library=cuda
```

**CPU Mode** - Look for:
```
library=cpu
```

---

## Performance

| Mode | Speed | Memory |
|------|-------|--------|
| **GPU (CUDA)** | 20-100+ tokens/sec | Uses VRAM |
| **CPU** | 2-5 tokens/sec | Uses RAM |

---

## Troubleshooting

### Container shows `library=cpu` but I have a GPU

1. **Check nvidia-smi works on host:**
   ```bash
   nvidia-smi
   ```

2. **Check Docker can access GPU:**
   ```bash
   docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu20.04 nvidia-smi
   ```

3. **If step 2 fails, install NVIDIA Container Toolkit:**
   ```bash
   sudo apt-get install -y nvidia-container-toolkit
   sudo nvidia-ctk runtime configure --runtime=docker --set-as-default
   sudo systemctl restart docker
   ```

4. **Restart Ollama:**
   ```bash
   docker compose -f docker-compose.dev.yml restart ollama
   ```

### Windows with WSL2

Make sure:
1. **NVIDIA GPU drivers** are installed on Windows (from nvidia.com)
2. **WSL2 GPU support** is enabled (comes with latest Windows 10/11)
3. **NVIDIA Container Toolkit** is installed **inside WSL** (see commands above)

---

## Summary

- **No scripts needed** - just `docker compose up`
- **Ollama auto-detects** GPU or CPU at runtime
- **One-time setup** for GPU: `sudo nvidia-ctk runtime configure --runtime=docker --set-as-default`
- **Works everywhere** - GPU users get acceleration, CPU users get fallback

# Port Conflict Prevention Guide

## Quick Summary

**Root Cause**: Port 11434 was hardcoded in docker-compose, conflicting with local Ollama installations or failed containers.

**Solution**: 
1. ✅ Environment variable for port configuration
2. ✅ Pre-startup port conflict detection
3. ✅ Automatic cleanup of failed containers
4. ✅ Smart startup script

---

## Root Causes (Detailed)

### 1. **Hardcoded Port Mapping** ✅ FIXED
- **Problem**: `docker-compose.dev.yml` had `"11434:11434"` hardcoded
- **Impact**: No way to change port without editing compose file
- **Fix**: Changed to `${OLLAMA_PORT:-11435}:11434`
  - External port configurable via `.env` file
  - Defaults to 11435 to avoid common conflicts
  - Internal port stays 11434 (no code changes needed)

### 2. **No Pre-Startup Checks** ✅ FIXED
- **Problem**: Docker-compose starts without checking ports
- **Impact**: Fails at container creation, leaves container in "Created" state
- **Fix**: Created `start-services.ps1` / `start-services.sh`
  - Checks ports before starting
  - Cleans up failed containers
  - Provides clear error messages

### 3. **Failed Container Cleanup** ✅ FIXED
- **Problem**: Containers in "Created" state block future startups
- **Impact**: Manual cleanup required each time
- **Fix**: Startup script automatically removes failed containers

### 4. **WSL Port Forwarding Confusion** ✅ FIXED
- **Problem**: `wslrelay` shows as using ports (false positive)
- **Impact**: Confusing error messages
- **Fix**: Port checker now ignores `wslrelay` (it's just WSL forwarding)

---

## How to Use

### Option 1: Use Smart Startup Script (Recommended)

**Windows (PowerShell)**:
```powershell
.\scripts\start-services.ps1
```

**Linux/Mac (Bash)**:
```bash
./scripts/start-services.sh
```

**What it does**:
1. ✅ Checks for failed containers and removes them
2. ✅ Checks for port conflicts
3. ✅ Starts docker-compose if all checks pass
4. ✅ Provides clear error messages if issues found

### Option 2: Manual Port Check

Before starting services manually:
```powershell
# Check for conflicts
.\scripts\check-port-conflicts.ps1

# If conflicts found, kill them automatically
.\scripts\check-port-conflicts.ps1 --kill

# Then start services normally
docker compose -f docker-compose.dev.yml up -d
```

### Option 3: Configure Port via Environment Variable

Create or edit `.env` file in project root:
```bash
# Use different external port for Ollama
OLLAMA_PORT=11435

# Or any other port you prefer
OLLAMA_PORT=11440
```

Then start services:
```bash
docker compose -f docker-compose.dev.yml up -d
```

---

## Prevention Checklist

Before starting services, ensure:

- [ ] Run `start-services.ps1` (or `start-services.sh`) instead of direct `docker compose up`
- [ ] Check `.env` file for port configurations
- [ ] If you have local Ollama installed, set `OLLAMA_PORT` to different value
- [ ] If conflicts persist, use `check-port-conflicts.ps1 --kill`

---

## Troubleshooting

### Error: "address already in use"

1. **Check what's using the port**:
   ```powershell
   .\scripts\check-port-conflicts.ps1
   ```

2. **Kill conflicting processes**:
   ```powershell
   .\scripts\check-port-conflicts.ps1 --kill
   ```

3. **Or use different port**:
   - Edit `.env`: `OLLAMA_PORT=11440`
   - Restart services

### Error: Container in "Created" state

The startup script automatically handles this, but if you see it manually:

```powershell
# Remove failed container
docker rm -f deepiri-ollama-dev

# Or use the startup script (it does this automatically)
.\scripts\start-services.ps1
```

### WSL Port Forwarding (wslrelay)

**This is normal!** `wslrelay` is WSL2's port forwarding mechanism. The port checker now ignores it.

If you see:
```
✅ Port 11434 (Ollama) is forwarded by WSL (available for Docker)
```

This means the port is available for Docker - no action needed.

---

## Files Changed

1. **`docker-compose.dev.yml`**: Changed Ollama port to use environment variable
2. **`scripts/check-port-conflicts.ps1`**: Updated to ignore wslrelay, return proper exit codes
3. **`scripts/check-port-conflicts.sh`**: Same updates for Linux/Mac
4. **`scripts/start-services.ps1`**: New smart startup script (Windows)
5. **`scripts/start-services.sh`**: New smart startup script (Linux/Mac)
6. **`docs/PORT_CONFLICT_ROOT_CAUSE_ANALYSIS.md`**: Detailed root cause analysis

---

## Best Practices

1. **Always use environment variables** for ports in docker-compose
2. **Use the startup script** instead of direct `docker compose up`
3. **Check ports before starting** if you're unsure
4. **Document port requirements** for each service
5. **Use different ports** for development vs production

---

## Future Improvements

- [ ] Automatic port range allocation (try next available port)
- [ ] Port conflict detection in docker-compose itself
- [ ] Health checks with automatic retry
- [ ] Port reservation system (prevent conflicts proactively)


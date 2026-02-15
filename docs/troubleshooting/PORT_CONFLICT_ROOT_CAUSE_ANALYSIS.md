# Port Conflict Root Cause Analysis

## The Problem

Port 11434 conflict when starting Ollama container:
```
Error: failed to bind host port 0.0.0.0:11434/tcp: address already in use
```

## Root Causes Identified

### 1. **Hardcoded Port Mapping** (Primary Cause)
**Problem**: Docker-compose had hardcoded port `11434:11434`
- No flexibility to use alternative ports
- Conflicts with local Ollama installations
- No environment variable override

**Evidence**: 
- `docker-compose.dev.yml` had: `ports: - "11434:11434"`
- Many users install Ollama locally on Windows (uses port 11434 by default)
- No way to change port without editing docker-compose file

**Fix Applied**: ✅ Changed to `${OLLAMA_PORT:-11435}:11434`
- External port now configurable via environment variable
- Defaults to 11435 to avoid common conflicts
- Internal port (11434) stays the same (no code changes needed)

---

### 2. **No Pre-Startup Port Conflict Detection**
**Problem**: Docker-compose starts without checking if ports are available
- Fails at container creation time
- Leaves container in "Created" state
- Subsequent attempts fail with same error

**Evidence**:
- Container found in "Created" state: `deepiri-ollama-dev - Created`
- No script runs before `docker compose up` to check ports
- Error only discovered after startup attempt fails

**Fix Needed**: ⚠️ Add pre-startup port checking

---

### 3. **Failed Container Cleanup**
**Problem**: Containers that fail to start remain in "Created" state
- Docker doesn't auto-remove failed containers
- They block future startup attempts
- Manual cleanup required

**Evidence**:
- Container `deepiri-ollama-dev` was in "Created" state
- Had to manually run: `docker rm -f deepiri-ollama-dev`
- No automatic cleanup mechanism

**Fix Needed**: ⚠️ Add automatic cleanup of failed containers

---

### 4. **WSL Port Forwarding Confusion**
**Problem**: `wslrelay` process shows up as using ports, but it's just forwarding
- Not a real conflict
- Can mask actual conflicts
- Confusing error messages

**Evidence**:
- Port checker showed `wslrelay` (PID 38764) using port 11434
- This is normal WSL2 port forwarding behavior
- Real conflict was likely a local Ollama or failed container

**Fix Applied**: ✅ Updated port conflict checker to ignore `wslrelay`

---

### 5. **No Fallback Port Mechanism**
**Problem**: If port is in use, startup fails completely
- No automatic retry with different port
- No port range allocation
- Manual intervention required

**Fix Needed**: ⚠️ Add automatic port fallback

---

## Preventive Solutions

### Solution 1: Pre-Startup Port Check (Recommended)
Create a wrapper script that checks ports before starting docker-compose:

```powershell
# Before: docker compose up
# After: .\scripts\start-services.ps1

# This script:
# 1. Checks for port conflicts
# 2. Cleans up failed containers
# 3. Suggests alternative ports if conflicts found
# 4. Then starts docker-compose
```

### Solution 2: Automatic Failed Container Cleanup
Add to docker-compose startup:
- Check for containers in "Created" state
- Remove them before starting
- Prevents blocking issues

### Solution 3: Port Conflict Detection in docker-compose
Use docker-compose's health checks and retry logic:
- Detect port conflicts early
- Report clear error messages
- Suggest solutions

### Solution 4: Environment Variable Defaults
Already implemented for Ollama:
- ✅ `${OLLAMA_PORT:-11435}` - Configurable external port
- Should apply to other services too

### Solution 5: Port Range Allocation
For development, use port ranges:
- Ollama: 11435-11439 (try next available)
- Other services: Similar ranges
- Prevents conflicts automatically

---

## Recommended Implementation Priority

1. **HIGH**: Pre-startup port check script
2. **HIGH**: Automatic cleanup of failed containers
3. **MEDIUM**: Port conflict detection in all docker-compose files
4. **MEDIUM**: Environment variable defaults for all services
5. **LOW**: Automatic port range allocation

---

## Current Status

✅ **Fixed**:
- Ollama port now uses environment variable
- Port conflict checker ignores wslrelay
- Documentation created

⚠️ **Needs Implementation**:
- Pre-startup port checking
- Automatic failed container cleanup
- Port conflict prevention for other services

---

## How to Prevent Future Conflicts

1. **Always use environment variables for ports** in docker-compose
2. **Run port conflict checker** before starting services
3. **Clean up failed containers** automatically
4. **Document port requirements** for each service
5. **Use different default ports** for development vs production


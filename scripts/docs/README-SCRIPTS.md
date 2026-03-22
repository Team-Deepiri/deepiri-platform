# Deepiri Scripts Guide

> **👷 Platform Engineers:** See `README-PLATFORM-ENGINEERING.md` for workspace guidelines and maintenance procedures.

## 🎯 Quick Start - Most Common Tasks

### **Fresh Rebuild (Delete Everything & Rebuild)**
When you have ~50GB of old images and want a clean start:
```bash
# From WSL:
./rebuild-fresh.sh

# From Windows (double-click):
rebuild-fresh.bat
```
**What it does:** Stops → Deletes old images → Cleans cache → Rebuilds → Starts

---

## 📁 Script Organization

### **Main Scripts (Root Directory)**

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `rebuild-fresh.sh` / `.bat` | **Complete rebuild** - Delete old images, rebuild, start | When you have 50GB+ of old images and want a fresh start |
| `stop-and-cleanup.sh` | Stop containers and clean up resources | When you want to free space but keep some images |
| `dev-docker.sh` | Development helper | Daily development tasks |

---

### **Scripts Directory (`deepiri/scripts/`)**

#### **Docker Management**
| Script | Purpose |
|--------|---------|
| `docker-cleanup.sh` | Clean build cache and unused images (keeps active ones) |
| `docker-manager.sh` | General Docker management utilities |

#### **WSL Disk Management** (Windows only)
| Script | Purpose |
|--------|---------|
| `compact-wsl-disk.bat` | **Compact WSL virtual disk** to reclaim Windows disk space |
| `compact-wsl-disk.ps1` | PowerShell version of disk compaction |
| `compact-wsl-disk.sh` | WSL helper script |

#### **Database**
| Script | Purpose |
|--------|---------|
| `mongo-backup.sh` | Backup MongoDB database |
| `mongo-restore.sh` | Restore MongoDB database |

#### **Development**
| Script | Purpose |
|--------|---------|
| `dev-utils.sh` | Development utilities |
| `fix-dependencies.sh` | Fix npm/node dependencies |
| `setup.sh` | Initial project setup |
| `test-runner.sh` | Run tests |

---

## 🔧 Common Workflows

### **Scenario 1: Fresh Start After Many Builds**
You've built containers many times and have 50GB+ of old images:
```bash
./rebuild-fresh.sh
```
This is your **one-stop solution** - it does everything.

### **Scenario 2: Just Free Up Space**
You want to free space but keep current images running:
```bash
./scripts/docker-cleanup.sh
```

### **Scenario 3: WSL Disk is Too Large**
Windows shows low disk space but WSL has free space inside:
1. Exit WSL
2. Double-click: `scripts/compact-wsl-disk.bat`
3. Restart WSL

### **Scenario 4: Stop Everything**
```bash
docker-compose -f docker-compose.dev.yml down
```

### **Scenario 5: Rebuild One Service**
```bash
docker-compose -f docker-compose.dev.yml build --no-cache challenge-service
docker-compose -f docker-compose.dev.yml up -d challenge-service
```

---

## 📊 Understanding Disk Usage

### Check Docker Disk Usage
```bash
docker system df
```

**What you'll see:**
- **Images**: Your container images (30-50GB for all services)
- **Containers**: Running/stopped containers (usually <1GB)
- **Volumes**: Data volumes (MongoDB, Redis - **keep these!**)
- **Build Cache**: Build layers (10-50GB - **safe to remove**)

### Check WSL Disk Usage (from WSL)
```bash
df -h
```

### Check Windows Disk Usage
The WSL virtual disk doesn't automatically shrink. Use `compact-wsl-disk.bat` to reclaim space.

---

## 🗑️ What Gets Deleted?

### `rebuild-fresh.sh` Deletes:
- ✅ All `deepiri-dev-*` images (your project images)
- ✅ All build cache
- ❌ **Keeps**: Base images (node, mongo, redis, etc.)
- ❌ **Keeps**: Data volumes (your database data)

### `docker-cleanup.sh` Deletes:
- ✅ Build cache
- ✅ Unused/dangling images
- ❌ **Keeps**: Images currently in use
- ❌ **Keeps**: All volumes

### `stop-and-cleanup.sh` Deletes:
- ✅ All Deepiri containers
- ✅ All Deepiri images (optional)
- ✅ All Deepiri volumes (optional)
- ✅ Build cache

---

## ⚠️ Important Notes

1. **Data Volumes**: Most scripts **preserve** your database volumes. Only `stop-and-cleanup.sh --no-keep-volumes` will delete them.

2. **Base Images**: Scripts keep base images (node:18-alpine, mongo:7.0, etc.) to speed up rebuilds.

3. **WSL Disk**: The WSL virtual disk file doesn't shrink automatically. Use `compact-wsl-disk.bat` periodically.

4. **Build Cache**: Safe to delete - Docker will rebuild it as needed, but it speeds up builds.

---

## 🐛 Troubleshooting

### "dumb-init: executable file not found"
**Solution:** Rebuild with `--no-cache`:
```bash
./rebuild-fresh.sh
```

### "No space left on device"
**Solution:** 
1. Run `./rebuild-fresh.sh` to clean everything
2. Run `scripts/compact-wsl-disk.bat` to compact WSL disk

### "Container keeps restarting"
**Solution:** Check logs:
```bash
docker-compose -f docker-compose.dev.yml logs [service-name]
```

---

## 📝 Script Maintenance

**To add a new script:**
1. Place in appropriate directory (root or `scripts/`)
2. Add description to this README
3. Make executable: `chmod +x script.sh`

**To remove old scripts:**
Check if they're still needed, then delete and update this README.



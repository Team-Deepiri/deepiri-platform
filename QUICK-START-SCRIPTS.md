# 🚀 Quick Start - Which Script Do I Use?

## ⭐ **MOST COMMON: Fresh Rebuild (Delete 50GB+ Images & Rebuild)**

**When:** You have lots of old Docker images (~50GB) and want a clean rebuild

**From WSL:**
```bash
./rebuild-fresh.sh
```

**From Windows (double-click):**
```
rebuild-fresh.bat
```

**What it does:**
1. ✅ Stops all containers
2. ✅ Deletes all old `deepiri-dev-*` images (~50GB)
3. ✅ Cleans build cache
4. ✅ Rebuilds everything fresh (no cache)
5. ✅ Starts all services

**Time:** 10-30 minutes (depending on your internet speed)

---

## 📋 Other Common Tasks

### Just Free Up Space (Keep Current Images)
```bash
./scripts/docker-cleanup.sh
```

### Stop Everything
```bash
docker-compose -f docker-compose.dev.yml down
```

### Start Everything
```bash
docker-compose -f docker-compose.dev.yml up -d
```

### WSL Disk Too Large (Windows showing low space)
1. Exit WSL
2. Double-click: `scripts/compact-wsl-disk.bat`

---

## 📖 Full Documentation

See `scripts/README-SCRIPTS.md` for complete documentation of all scripts.

---

## 🆘 Need Help?

- **"dumb-init not found"** → Run `./rebuild-fresh.sh`
- **"No space left"** → Run `./rebuild-fresh.sh` then `scripts/compact-wsl-disk.bat`
- **Container won't start** → Check logs: `docker-compose -f docker-compose.dev.yml logs [service-name]`



# Makefile Explanation

## Why is the Makefile included?

The **Makefile** is an **optional convenience tool** for developers who prefer using `make` commands instead of typing long docker-compose commands. It's not required - you can use the rebuild scripts or docker-compose directly.

## Do I need it?

**No, it's completely optional!** You have three options to clean and remove those unused Docker Images!

### Option 1: Rebuild Scripts (Recommended) ✅
```bash
# Linux/Mac
./rebuild.sh

# Windows PowerShell
.\rebuild.ps1
```

### Option 2: Docker Compose Directly
```bash
docker compose -f docker-compose.dev.yml down --rmi local
docker builder prune -af
docker compose -f docker-compose.dev.yml build --no-cache
docker compose -f docker-compose.dev.yml up -d
```

### Option 3: Makefile (If you have `make` installed)
```bash
make rebuild
```

## Installing Make (Optional)

### Windows
```powershell
# Using Chocolatey
choco install make

# Or use WSL (Windows Subsystem for Linux)
wsl
# Then make is usually pre-installed
```

### Mac
```bash
# Usually pre-installed, or via Homebrew
brew install make
```

### Linux
```bash
# Usually pre-installed
# If not:
sudo apt-get install make  # Debian/Ubuntu
sudo yum install make      # RHEL/CentOS
```

## Makefile Commands

If you have `make` installed, you can use:

```bash
# Normal operations (NO rebuild)
make up                   # Start services (uses existing images - fast!)
make down                 # Stop services
make logs                 # View logs
make df                   # Show Docker disk usage

# Rebuilding (ONLY use when code changes)
make rebuild              # Full clean rebuild (removes old images, rebuilds, starts)
make rebuild-service SERVICE=cyrex  # Rebuild one service
make build                # Normal build (with cache, only if needed)

# Cleanup
make clean                # Clean everything (containers, images, volumes, cache)
```

**Important:** `make up` does NOT rebuild - it uses existing images. Only `make rebuild` rebuilds images.

## Which Should I Use?

### Normal Daily Operation (No Rebuild)
- **Most users**: `docker compose -f docker-compose.dev.yml up -d` ✅
- **Make users**: `make up`
- **Fast and efficient** - uses existing images

### When You Need to Rebuild
- **Most users**: Use `rebuild.sh` / `rebuild.ps1` ✅
- **Make users**: `make rebuild`
- **Full control**: Manual docker compose commands

**Key Point:** Normal `docker compose up` or `make up` does NOT rebuild - it's fast! Only rebuild when code changes.



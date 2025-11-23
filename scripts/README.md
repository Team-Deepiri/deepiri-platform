# Scripts Directory

## 🚀 Main Scripts (Use These)

### Build Scripts
| Script | Description | Usage |
|--------|-------------|-------|
| **[../build.sh](../build.sh)** | **Smart build** (Linux/Mac/WSL) | `cd deepiri && ./build.sh` |
| **[../build.ps1](../build.ps1)** | **Smart build** (Windows) | `cd deepiri && .\build.ps1` |
| `remove-dangling-images.sh` | Manual cleanup (Linux/Mac/WSL) | `./remove-dangling-images.sh` |
| `remove-dangling-images.ps1` | Manual cleanup (Windows) | `.\remove-dangling-images.ps1` |
| `auto-cleanup-after-build.sh` | Auto-cleanup helper | Called by build scripts |

### Cleanup Scripts
| Script | Description | Usage |
|--------|-------------|-------|
| `cleanup-and-compact.ps1` | **Full cleanup + WSL compact** (Windows Admin) | `.\cleanup-and-compact.ps1` |
| `remove-dangling-images.*` | Remove dangling images only | `./remove-dangling-images.sh` |

### Storage Management
| Script | Description | Usage |
|--------|-------------|-------|
| [STORAGE-TROUBLESHOOTING.md](STORAGE-TROUBLESHOOTING.md) | Disk space troubleshooting guide | Read when having disk issues |
| `compact-wsl-disk.ps1` | Compact WSL VHDX (Windows Admin) | `.\compact-wsl-disk.ps1` |

## 🗂️ Legacy/Specialized Scripts

Most scripts in this directory are legacy or for specialized use cases. They've been replaced by the main build scripts above.

### Development Environment
- `setup-dev-venv.sh/ps1` - Set up Python virtual environment
- `activate-dev-venv.sh/ps1` - Activate Python venv
- `setup-docker-wsl2.sh` - WSL2 Docker setup

### Database Management
- `mongo-backup.sh` - MongoDB backup
- `mongo-restore.sh` - MongoDB restore
- `mongo-init.js` - MongoDB initialization

### Legacy Build Scripts (Deprecated)
- `force-rebuild-all.sh` - Use `../build.sh --no-cache` instead
- `build-cyrex-auto.*` - Use `../build.sh cyrex` instead
- `rebuild.sh/ps1` - Use `../build.sh` instead
- `BUILD_RUN_STOP.sh/ps1` - Use `../build.sh` + docker compose instead
- All `skaffold-*` scripts - Deprecated, use Docker Compose workflow

### Archive
- `archive/` - Very old scripts kept for reference only

## 🎯 Recommended Workflow

### Daily Development
```bash
# 1. Build (from project root)
cd deepiri
./build.sh                    # Linux/Mac/WSL
.\build.ps1                   # Windows

# 2. Run
docker compose -f docker-compose.dev.yml up -d

# 3. Check logs
docker compose -f docker-compose.dev.yml logs -f
```

### Disk Space Issues
```bash
# Quick cleanup (no admin)
./scripts/remove-dangling-images.sh        # Linux/Mac/WSL
.\scripts\remove-dangling-images.ps1       # Windows

# Full cleanup + WSL compact (Windows Admin required)
.\scripts\cleanup-and-compact.ps1
```

### Clean Rebuild
```bash
# Stop containers
docker compose -f docker-compose.dev.yml down

# Clean build
./build.sh --no-cache         # Linux/Mac/WSL
.\build.ps1 -NoCache          # Windows

# Start fresh
docker compose -f docker-compose.dev.yml up -d
```

## 📝 Notes

- **Use the main build scripts** in project root (`build.sh` / `build.ps1`)
- Most scripts here are legacy or specialized
- See [../HOW_TO_BUILD.md](../HOW_TO_BUILD.md) for the complete build guide
- Old Skaffold scripts are deprecated - use Docker Compose workflow

## 🔍 Finding the Right Script

- **Want to build?** → Use `../build.sh` or `../build.ps1`
- **Out of disk space?** → Use `remove-dangling-images.*`
- **Windows storage issues?** → Use `cleanup-and-compact.ps1` (as Admin)
- **Need to setup environment?** → Use `setup-dev-venv.*`
- **Database backup/restore?** → Use `mongo-backup.sh` / `mongo-restore.sh`

Everything else is likely legacy and has been replaced.

# Scripts Directory

This directory contains all utility scripts for the Deepiri platform, organized by category for easy navigation.

## 📁 Directory Structure

```
scripts/
├── archive/          # Deprecated/archived scripts (kept for reference)
├── build/            # Build and rebuild scripts
├── database/         # Database backup, restore, and initialization
├── dev/              # Development environment setup and utilities
├── docker/           # Docker image and container management
├── docs/             # Documentation files
├── git/              # Git hooks and submodule management
├── services/         # Service start/stop and management
├── storage/          # Storage cleanup and WSL disk management
├── testing/          # Test scripts and utilities
└── utils/            # General utility scripts
```

## 🚀 Quick Reference

### Build Scripts (`build/`)
- `smart-build.sh/ps1` - Smart build with caching
- `rebuild.sh/ps1` - Full rebuild
- `build-cyrex.sh/ps1` - Build Cyrex service
- `force-rebuild-all.sh` - Force rebuild all services
- `auto-cleanup-after-build.sh` - Auto-cleanup after builds

### Docker Management (`docker/`)
- `docker-cleanup.sh` - Clean build cache and unused images
- `docker-manager.sh` - General Docker management utilities
- `remove-dangling-images.sh/ps1` - Remove dangling Docker images
- `check-images.sh` - Check Docker images
- `verify-all-images.sh` - Verify all Docker images
- `clear-docker-logs.sh/ps1` - Clear Docker logs
- `check-port-conflicts.sh/ps1` - Check for port conflicts

### Database (`database/`)
- `mongo-backup.sh` - Backup MongoDB
- `mongo-restore.sh` - Restore MongoDB
- `mongo-init.js` - MongoDB initialization script
- `postgres-backup.sh` - Backup PostgreSQL
- `postgres-restore.sh` - Restore PostgreSQL
- `postgres-init.sql` - PostgreSQL initialization
- `postgres-seed.sql` - PostgreSQL seed data

### Development Environment (`dev/`)
- `setup-dev-venv.sh/ps1` - Set up Python virtual environment
- `activate-dev-venv.sh/ps1` - Activate Python venv
- `ensure-dev-venv-packages.sh/ps1` - Ensure required packages are installed
- `export-venv-packages.sh/ps1` - Export venv package list
- `setup-docker-wsl2.sh` - WSL2 Docker setup
- `setup.sh` - Initial project setup
- `dev-utils.sh` - Development utilities
- `dev-docker.sh` - Development Docker helper
- `dev-start.js` - Development start script
- `fix-dependencies.sh` - Fix npm/node dependencies

### Git Management (`git/`)
- `install-git-hooks.sh` - Install git hooks
- `install-all-git-hooks.sh` - Install all git hooks
- `setup-all-git-hooks.sh/ps1` - Set up all git hooks
- `fix-all-git-hooks.sh` - Fix all git hooks
- `fix-submodule-hooks.sh` - Fix submodule hooks
- `sync-hooks-to-submodules.sh` - Sync hooks to submodules
- `verify-submodule-hooks.sh` - Verify submodule hooks
- `commit_all_submodules.sh` - Commit changes in all submodules
- `switch_and_update_submodules.sh` - Switch and update submodules
- `sync-gitconfig-to-submodules.sh` - Sync git config to submodules

### Service Management (`services/`)
- `start-services.sh/ps1` - Start all services
- `start-docker-dev.sh/ps1` - Start Docker development environment
- `stop-and-cleanup.sh/ps1` - Stop services and cleanup
- `BUILD_RUN_STOP.sh/ps1` - Build, run, and stop services
- `minio_update_and_configure.sh` - Update and configure MinIO

### Storage Management (`storage/`)
- `cleanup-and-compact.ps1` - Full cleanup + WSL compact (Windows Admin)
- `cleanup-and-compact-mac.sh` - Full cleanup for Mac
- `compact-wsl-disk.sh/ps1/bat` - Compact WSL virtual disk
- `compact-vhdx-files.ps1` - Compact VHDX files
- `find-storage-hogs.ps1` - Find storage-consuming files
- `nuke_volumes.sh/bat` - Remove all volumes
- `run-cleanup-as-admin.bat` - Run cleanup as admin
- `run-cleanup-direct.ps1` - Run cleanup directly
- `setup-auto-compact.ps1` - Set up auto-compaction

### Testing (`testing/`)
- `test-runner.sh` - Run tests
- `test_gateways.sh/ps1/js` - Test gateway services
- `test-logger-path.sh` - Test logger path configuration

### Utilities (`utils/`)
- `run.py` - Main runner script
- `utils_docker.py` - Docker utilities
- `send_document_email.py` - Send document email
- `generate-team-compose-files.py` - Generate team compose files
- `count-loc.sh` - Count lines of code
- `quick-workflow.sh` - Quick workflow helper
- `pull_landing_page.sh` - Pull landing page
- `collect_gateway_logs.ps1` - Collect gateway logs
- `rename-api-server.ps1` - Rename API server
- `fix-ollama-port.ps1` - Fix Ollama port configuration
- `verify-team-compose.sh` - Verify team compose files

### Documentation (`docs/`)
- `README.md` - This file
- `README-SCRIPTS.md` - Detailed scripts guide
- `README-DOCKER-CLEANUP.md` - Docker cleanup guide
- `README-FOR-PLATFORM-ENGINEERS.md` - Platform engineers guide
- `README-GPU-SETUP.md` - GPU setup guide
- `README-POSTGRES.md` - PostgreSQL guide
- `STORAGE-TROUBLESHOOTING.md` - Storage troubleshooting guide

## 🎯 Common Workflows

### Daily Development
```bash
# 1. Build (from project root)
cd deepiri-platform
./build.sh                    # Linux/Mac/WSL
.\build.ps1                   # Windows

# 2. Start services
./scripts/services/start-services.sh
# or
docker compose -f docker-compose.dev.yml up -d

# 3. Check logs
docker compose -f docker-compose.dev.yml logs -f
```

### Disk Space Issues
```bash
# Quick cleanup (no admin)
./scripts/docker/remove-dangling-images.sh        # Linux/Mac/WSL
.\scripts\docker\remove-dangling-images.ps1       # Windows

# Full cleanup + WSL compact (Windows Admin required)
.\scripts\storage\cleanup-and-compact.ps1
```

### Database Backup/Restore
```bash
# Backup MongoDB
./scripts/database/mongo-backup.sh

# Restore MongoDB
./scripts/database/mongo-restore.sh

# Backup PostgreSQL
./scripts/database/postgres-backup.sh

# Restore PostgreSQL
./scripts/database/postgres-restore.sh
```

### Clean Rebuild
```bash
# Stop containers
docker compose -f docker-compose.dev.yml down

# Clean build
./scripts/build/rebuild.sh --no-cache         # Linux/Mac/WSL
.\scripts\build\rebuild.ps1 -NoCache          # Windows

# Start fresh
docker compose -f docker-compose.dev.yml up -d
```

## 📝 Notes

- **Script Naming**: Scripts follow the pattern `name.sh` (Linux/Mac/WSL), `name.ps1` (PowerShell), or `name.bat` (Windows batch)
- **Permissions**: Most shell scripts need execute permissions: `chmod +x script.sh`
- **Documentation**: See `docs/` folder for detailed guides on specific topics
- **Archive**: Old/deprecated scripts are in `archive/` for reference only

## 🔍 Finding the Right Script

- **Want to build?** → `build/`
- **Docker issues?** → `docker/`
- **Database operations?** → `database/`
- **Out of disk space?** → `storage/`
- **Need to setup environment?** → `dev/`
- **Git hooks/submodules?** → `git/`
- **Start/stop services?** → `services/`
- **Run tests?** → `testing/`
- **General utilities?** → `utils/`


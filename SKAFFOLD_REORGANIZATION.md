# Skaffold Files Reorganization

All Skaffold configuration files have been reorganized into a dedicated `skaffold/` directory for better organization and maintainability.

## What Changed

### Files Moved
All Skaffold configuration files have been moved from the root directory to `skaffold/`:

- ✅ `skaffold.yaml` → `skaffold/skaffold.yaml`
- ✅ `skaffold-local.yaml` → `skaffold/skaffold-local.yaml`
- ✅ `skaffold-ai-team.yaml` → `skaffold/skaffold-ai-team.yaml`
- ✅ `skaffold-ml-team.yaml` → `skaffold/skaffold-ml-team.yaml`
- ✅ `skaffold-backend-team.yaml` → `skaffold/skaffold-backend-team.yaml`
- ✅ `skaffold-frontend-team.yaml` → `skaffold/skaffold-frontend-team.yaml`
- ✅ `skaffold-infrastructure-team.yaml` → `skaffold/skaffold-infrastructure-team.yaml`
- ✅ `skaffold-platform-engineers.yaml` → `skaffold/skaffold-platform-engineers.yaml`
- ✅ `skaffold-qa-team.yaml` → `skaffold/skaffold-qa-team.yaml`
- ✅ `skaffold-prod-cloud.yaml` → `skaffold/skaffold-prod-cloud.yaml`
- ✅ `skaffold.log` → `skaffold/skaffold.log`

### Scripts Updated
The following scripts have been updated to use the new paths:

- ✅ `scripts/quick-workflow.sh`
- ✅ `scripts/BUILD_RUN_STOP.sh`
- ✅ `scripts/BUILD_RUN_STOP.ps1`
- ✅ `scripts/delete-docker-images.sh`
- ✅ `scripts/check_docker_images.sh`
- ✅ `scripts/verify-all-images.sh`
- ✅ `scripts/check-images.sh`

### Documentation Updated
- ✅ `docs/QUICK_FIX_MINIKUBE.md`
- ✅ `SETUP_COMPLETE.md`

## New Usage

### Before
```bash
skaffold build -f skaffold-local.yaml -p dev-compose
```

### After
```bash
skaffold build -f skaffold/skaffold-local.yaml -p dev-compose
```

## Benefits

1. **Better Organization**: All Skaffold files are now in one dedicated directory
2. **Cleaner Root**: The project root is less cluttered
3. **Easier Maintenance**: All Kubernetes/Skaffold configs are grouped together
4. **Clear Structure**: Makes it obvious where to find Skaffold configurations

## Archive Files

Note: Archive documentation files in `docs/archive/` still reference the old paths for historical accuracy. These are not actively used and don't need updating.

## See Also

- `skaffold/README.md` - Detailed information about each Skaffold configuration file


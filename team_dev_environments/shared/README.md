# Shared Utilities for Team Environments

This folder contains shared utilities used by all team `run.py` scripts.

## Files

### `k8s_env_loader.py`

Shared module for loading environment variables from Kubernetes ConfigMaps and Secrets.

**What it does:**
1. Reads all YAML files in `ops/k8s/configmaps/`
2. Reads all YAML files in `ops/k8s/secrets/` (except `.example` files)
3. Extracts environment variables from `data:` and `stringData:` sections
4. Returns them as a Python dictionary

**Used by:**
- All `team_dev_environments/<team>/run.py` scripts

**Functions:**
- `load_k8s_config(yaml_file)` - Load vars from a single YAML file
- `load_all_configmaps_and_secrets(project_root=None)` - Load all k8s config

## Usage

```python
import sys
from pathlib import Path

# Add shared utilities to path
sys.path.insert(0, str(Path(__file__).parent.parent / 'shared'))

from k8s_env_loader import load_all_configmaps_and_secrets

# Load all environment variables from k8s config
env_vars = load_all_configmaps_and_secrets()

# Inject into environment
import os
os.environ.update(env_vars)
```

## Benefits

✅ **DRY** - Don't Repeat Yourself (single shared implementation)  
✅ **Maintainable** - Update in one place, works everywhere  
✅ **Professional** - Mimics how K8s injects secrets into pods  
✅ **No `.env` files** - All config in k8s YAML format  

---

**This is the professional microservices way!** 🚀


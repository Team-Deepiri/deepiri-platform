# Setup Python Environment Startup Scripts

## Prerequisites

Install PyYAML:

```bash
pip install pyyaml
```

Or using the requirements file:

```bash
pip install -r py_environment_startup_scripts/requirements.txt
```

## Quick Start

1. **Copy secrets template:**
   ```bash
   cp ops/k8s/secrets/secrets.yaml.example ops/k8s/secrets/secrets.yaml
   ```

2. **Edit secrets.yaml with your values** (optional for local dev):
   ```bash
   # Use default values for local dev, or add your API keys
   code ops/k8s/secrets/secrets.yaml
   ```

3. **Run your team's environment:**
   ```bash
   python py_environment_startup_scripts/run_backend_team.py
   ```

## What Happens

1. Script reads all `ops/k8s/configmaps/*.yaml` files
2. Script reads all `ops/k8s/secrets/*.yaml` files  
3. Extracts environment variables from YAML
4. Injects them into `os.environ`
5. Runs `docker compose` with injected environment

**Result:** Your containers have all the environment variables from k8s config!

## No .env Files Needed!

This is exactly how professional microservices teams work:
- ✅ Single source of truth (k8s YAML files)
- ✅ Mimics production Kubernetes environment
- ✅ No manual `.env` file management
- ✅ No drift between local and production config

## Testing

To test that it loads the config correctly (without starting containers):

```python
from k8s_env_loader import load_all_configmaps_and_secrets

env_vars = load_all_configmaps_and_secrets()
print(f"Loaded {len(env_vars)} variables")
for key in sorted(env_vars.keys()):
    print(f"  {key}")
```

## Make Scripts Executable (Unix/Linux/Mac)

```bash
chmod +x py_environment_startup_scripts/run_*.py
```

Then you can run them directly:

```bash
./py_environment_startup_scripts/run_backend_team.py
```

---

**You now have a professional-grade local development environment that mirrors production! 🚀**


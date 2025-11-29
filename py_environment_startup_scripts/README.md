# Python Environment Startup Scripts

🎯 **Professional microservices workflow** - these scripts mimic Kubernetes by reading ConfigMaps and Secrets YAMLs and injecting them directly into the environment.

**No `.env` files needed!** Just like in production Kubernetes.

---

## 🚀 Quick Start

```bash
# Backend Team
python py_environment_startup_scripts/run_backend_team.py

# AI Team
python py_environment_startup_scripts/run_ai_team.py

# Platform Engineers (Full Stack)
python py_environment_startup_scripts/run_platform_engineers.py

# Other teams...
python py_environment_startup_scripts/run_<team>.py
```

---

## 📋 Available Scripts

| Script | Team | Services |
|--------|------|----------|
| `run_backend_team.py` | Backend | Frontend + All backend microservices |
| `run_ai_team.py` | AI | Cyrex, MLflow, Jupyter, Challenge Service |
| `run_frontend_team.py` | Frontend | Frontend + API Gateway |
| `run_ml_team.py` | ML | Cyrex, MLflow, Jupyter, Platform Analytics |
| `run_infrastructure_team.py` | Infrastructure | MongoDB, Redis, InfluxDB, etc. |
| `run_platform_engineers.py` | Platform Engineers | Everything (full stack) |
| `run_qa_team.py` | QA | Everything (for testing) |

---

## 🔧 How It Works

Each script:

1. **Reads k8s ConfigMaps** from `ops/k8s/configmaps/*.yaml`
2. **Reads k8s Secrets** from `ops/k8s/secrets/*.yaml`
3. **Extracts environment variables** from `data:` and `stringData:` sections
4. **Injects them into `os.environ`** (mimics Kubernetes pod injection)
5. **Runs `docker compose`** with those environment variables

**This mimics exactly how Kubernetes works in production!**

---

## ✨ Advantages Over `.env` Files

✅ **No `.env` files** - secrets stay in k8s YAML format  
✅ **Single source of truth** - same config for local dev and k8s  
✅ **Production-like** - mimics Kubernetes secret injection  
✅ **No drift** - local dev matches production exactly  
✅ **Cleaner** - no scattered `.env` files to maintain  

---

## 📝 Example Workflow

```bash
# 1. Edit your k8s config
vim ops/k8s/configmaps/auth-service-configmap.yaml
vim ops/k8s/secrets/secrets.yaml

# 2. Run the script - it auto-loads your changes
python py_environment_startup_scripts/run_backend_team.py

# 3. That's it! Your containers have the updated config
```

**No manual syncing. No `.env` file generation. Just works.**

---

## 🔒 Security

- ✅ `secrets.yaml` is gitignored (never committed)
- ✅ `secrets.yaml.example` is committed (safe template)
- ✅ Scripts skip `*.example` files when loading secrets
- ✅ Same security model as production Kubernetes

---

## 🆚 vs Other Methods

### This approach (Python scripts + k8s YAMLs):
```bash
python py_environment_startup_scripts/run_backend_team.py
```
- ✅ No `.env` files
- ✅ Mimics Kubernetes exactly
- ✅ Single source of truth
- ✅ Professional microservices workflow

### Old approach (shell wrappers):
```bash
./docker-compose-k8s.sh -f docker-compose.backend-team.yml up -d
```
- ⚠️ Shell-specific (bash/powershell)
- ⚠️ Platform-dependent
- ✅ Still works, but Python is cleaner

### Manual approach (plain docker-compose):
```bash
docker compose -f docker-compose.backend-team.yml up -d
```
- ❌ No k8s config loaded
- ❌ Requires manual `.env` files
- ❌ Easy to get out of sync

---

## 🔄 Stopping Services

```bash
# Stop services (same for all teams)
docker compose -f docker-compose.backend-team.yml down
docker compose -f docker-compose.ai-team.yml down
# etc...
```

---

## 📦 Requirements

- Python 3.7+
- PyYAML (`pip install pyyaml`)
- Docker & Docker Compose

---

## 🎯 This Is How Professional Teams Do It

This workflow matches how modern microservices teams work:

1. **ConfigMaps & Secrets** as YAML (k8s format)
2. **Python bootstrap script** reads them
3. **Injects into environment**
4. **Runs containers** with injected config

**No `.env` files. No manual syncing. Production-like from day one.** 🚀

---

**For more info, see:** [ENVIRONMENT_VARIABLES.md](../ENVIRONMENT_VARIABLES.md)

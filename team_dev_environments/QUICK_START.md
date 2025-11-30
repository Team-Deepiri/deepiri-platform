# Quick Start - Team Development Environments

## Professional K8s-Like Local Development (No `.env` Files!)

### 1️⃣ One-Time Setup

```bash
# Install Python dependency
pip install pyyaml

# Get the secrets off of a secured source from the organization

# For local dev, you can use minimal defaults - see README for template
# Or just run with empty secrets.yaml for now
```

### 2️⃣ Run Your Team Environment

```bash
# Navigate to your team folder
cd team_dev_environments/backend-team

# Run Python script - it auto-loads k8s config!
python run.py
```


### What Happens?

1. **Script reads k8s ConfigMaps** from `ops/k8s/configmaps/*.yaml`
2. **Script reads k8s Secrets** from `ops/k8s/secrets/*.yaml`
3. **Injects them into environment** (mimics Kubernetes!)
4. **Starts Docker containers** with environment loaded

**No `.env` files. Just like production Kubernetes!**

---

## 📋 All Teams

| Team | Command | Services |
|------|---------|----------|
| **Backend** | `cd team_dev_environments/backend-team && python run.py` | Frontend + All backend services |
| **AI** | `cd team_dev_environments/ai-team && python run.py` | Cyrex, MLflow, Jupyter |
| **Frontend** | `cd team_dev_environments/frontend-team && python run.py` | Frontend + API Gateway |
| **Infrastructure** | `cd team_dev_environments/infrastructure-team && python run.py` | PostgreSQL, Redis, InfluxDB |
| **ML** | `cd team_dev_environments/ml-team && python run.py` | Cyrex, MLflow, Analytics |
| **Platform** | `cd team_dev_environments/platform-engineers && python run.py` | Everything (full stack) |
| **QA** | `cd team_dev_environments/qa-team && python run.py` | Everything (for testing) |

---

## 🔧 Alternative: Shell Scripts

If you prefer shell scripts:

```bash
cd team_dev_environments/backend-team
./start.sh        # Linux/Mac
.\start.ps1       # Windows
```

**But Python is recommended!** It loads k8s config automatically.

---

## 📁 Project Structure

```
team_dev_environments/
├── shared/
│   └── k8s_env_loader.py      # Shared k8s loader (used by all teams)
│
├── backend-team/
│   ├── run.py                  # ⭐ Python runner (recommended)
│   ├── start.sh / start.ps1    # Shell alternatives
│   ├── build.sh                # Build script
│   └── stop.sh                 # Stop script
│
├── ai-team/
│   └── run.py                  # (same structure)
│
└── ... (other teams)
```

---

## ✨ Why This Approach?

✅ **No `.env` files** - All config in k8s YAML format  
✅ **Mimics production** - Same as Kubernetes secret injection  
✅ **Single source of truth** - `ops/k8s/` configmaps & secrets  
✅ **Professional workflow** - How enterprise teams work  
✅ **No drift** - Local dev matches production exactly  

---

## 📝 Example Output

```bash
$ python run.py

🚀 Starting Backend Team Environment...
   (Loading k8s ConfigMaps & Secrets from ops/k8s/)

   ✓ Loaded 11 vars from api-gateway-configmap.yaml
   ✓ Loaded 6 vars from auth-service-configmap.yaml
   ✓ Loaded 37 vars from secrets.yaml
   ... (loading all k8s config)

📦 Loaded 126 environment variables

✅ Backend Team Environment Started!

Access your services:
  - Frontend:        http://localhost:5173
  - API Gateway:     http://localhost:5100
  - Auth Service:    http://localhost:5001
  - pgAdmin: http://localhost:5050
```

---

**This is the professional microservices way!** 🚀


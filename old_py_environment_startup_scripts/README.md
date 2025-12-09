# ⚠️ MOVED: Python Environment Startup Scripts

**These scripts have been reorganized and moved to a better location!**

## 📍 New Location

Python startup scripts are now organized by team in:

```
team_dev_environments/
├── shared/
│   └── k8s_env_loader.py      # Shared k8s config loader
├── backend-team/
│   └── run.py                  # Backend team runner
├── ai-team/
│   └── run.py                  # AI team runner
├── frontend-team/
│   └── run.py                  # Frontend team runner
├── infrastructure-team/
│   └── run.py                  # Infrastructure team runner
├── ml-team/
│   └── run.py                  # ML team runner
├── platform-engineers/
│   └── run.py                  # Platform engineers runner
└── qa-team/
    └── run.py                  # QA team runner
```

## 🚀 How to Use (New Way)

```bash
# Navigate to your team folder
cd team_dev_environments/backend-team

# Run the Python script
python run.py
```

**Benefits:**
- ✅ Better organized (each team has their own folder)
- ✅ Shared utilities in one place (`team_dev_environments/shared/`)
- ✅ No duplicate code
- ✅ Easier to maintain

## 📚 Documentation

See the updated documentation:
- [team_dev_environments/README.md](../team_dev_environments/README.md) - Main documentation
- [team_dev_environments/shared/README.md](../team_dev_environments/shared/README.md) - Shared utilities

---

**This folder will be deprecated in a future update. Please use the new structure!**

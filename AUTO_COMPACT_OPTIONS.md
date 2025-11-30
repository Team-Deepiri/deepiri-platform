# Automatic VHDX Compaction Options

**The Problem:** WSL2 VHDX files never auto-shrink. You have to compact them manually.

**Reality:** Most developers just live with it and compact monthly.

---

## Option 1: Scheduled Task (Recommended)

**Setup once, runs automatically every week:**

```powershell
# Run as Administrator (one time setup)
cd deepiri\scripts
.\setup-auto-compact.ps1
```

This creates a Windows Scheduled Task that runs every Sunday at 3 AM.

**Pros:**
- ✅ Fully automatic
- ✅ Runs in background
- ✅ No manual intervention needed

**Cons:**
- ⚠️ Runs at fixed time (3 AM Sunday)
- ⚠️ Requires admin to set up once

---

## Option 2: Docker Desktop for Windows

**Switch from Docker in WSL to Docker Desktop for Windows.**

Docker Desktop has better disk space management and can automatically compact.

**To switch:**
1. Uninstall Docker from WSL
2. Install Docker Desktop for Windows
3. Enable WSL2 backend in Docker Desktop settings

**Pros:**
- ✅ Better disk management
- ✅ Built-in space reclamation
- ✅ Better UI

**Cons:**
- ⚠️ Requires reinstall
- ⚠️ Different configuration

---

## Option 3: WSL2 Auto-Compact (Experimental)

**Some newer WSL versions support automatic compaction.**

Add to `C:\Users\josep\.wslconfig`:

```ini
[wsl2]
# Enable experimental sparse VHD
sparseVhd=true

# Set memory limits to reduce VHDX growth
memory=8GB
swap=2GB
```

Then restart WSL:
```powershell
wsl --shutdown
```

**Pros:**
- ✅ Built into WSL
- ✅ No scripts needed

**Cons:**
- ⚠️ Experimental feature
- ⚠️ Not available in all WSL versions
- ⚠️ May not work consistently

---

## Option 4: Manual Monthly Compaction

**Just run it yourself once a month.**

```powershell
# As Administrator
cd deepiri\scripts
.\GET_SPACE_BACK.ps1
```

Set a calendar reminder for the 1st of each month.

**Pros:**
- ✅ Simple
- ✅ Full control
- ✅ No automation setup

**Cons:**
- ⚠️ Manual work required
- ⚠️ Easy to forget

---

## Option 5: Run After Big Cleanups

**Add to cleanup script so it runs when you clean up Docker.**

Already done in `scripts/cleanup-and-compact.ps1` - it does Docker cleanup + VHDX compact in one go.

```powershell
# Run this when you do major cleanup (as Admin)
.\scripts\cleanup-and-compact.ps1
```

**Pros:**
- ✅ Only runs when needed
- ✅ Combined with Docker cleanup

**Cons:**
- ⚠️ Still manual
- ⚠️ Requires admin

---

## What Most Developers Actually Do

**Reality check:**

1. **Docker Desktop users** - Let Docker Desktop handle it
2. **WSL Docker users** - Compact monthly or when disk space gets low
3. **Automation nerds** - Set up scheduled tasks
4. **Everyone else** - Ignore it until disk is full, then panic and compact

---

## Recommendation

### For You (Daily Development)

**Option 1: Scheduled Task**
```powershell
# One-time setup (as Admin)
cd deepiri\scripts
.\setup-auto-compact.ps1
```

Runs every Sunday at 3 AM automatically. Set it and forget it.

---

### Alternative: WSL Config

Add to `C:\Users\josep\.wslconfig`:
```ini
[wsl2]
sparseVhd=true
memory=8GB
```

Then restart:
```powershell
wsl --shutdown
```

Try this first. If it doesn't work well, use Option 1 (Scheduled Task).

---

## Check If It's Working

```powershell
# Check VHDX size
$vhdx = "C:\Users\josep\AppData\Local\Packages\CanonicalGroupLimited.Ubuntu_79rhkp1fndgsc\LocalState\ext4.vhdx"
$size = (Get-Item $vhdx).Length / 1GB
Write-Host "VHDX: $([math]::Round($size, 2)) GB"

# Check actual usage in WSL
wsl df -h / | tail -1
```

If VHDX size is close to actual usage, it's working.  
If VHDX is way bigger (like 118 GB vs 29 GB), you need to compact.

---

## TL;DR

**Best solution:**
1. Try `.wslconfig` with `sparseVhd=true` (2 minutes)
2. If that doesn't work, set up scheduled task (5 minutes)
3. Forget about it

**Quick fix for now:**
```powershell
cd deepiri\scripts
.\GET_SPACE_BACK.ps1  # Run as Admin
```


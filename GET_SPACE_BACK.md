# GET YOUR 60GB BACK

**Your problem:** Docker is clean (0 images), but Windows still shows 60GB missing.

**Why:** The WSL2 virtual disk (VHDX file) doesn't automatically shrink when you delete data inside it.

**Solution:** Compact the VHDX file.

---

## Quick Fix (Windows)

### 1. Open PowerShell as Administrator
- Right-click PowerShell
- Click "Run as Administrator"

### 2. Run the Compact Script
```powershell
cd C:\Users\josep\Documents\AIToolWebsite\Deepiri\deepiri\scripts
.\GET_SPACE_BACK.ps1
```

This will:
1. Shutdown WSL
2. Compact the VHDX file (takes 2-5 minutes)
3. Reclaim ~90GB of space
4. Leave WSL shut down (start it again with `wsl`)

---

## Manual Method

If the script doesn't work:

### 1. Shutdown WSL
```powershell
wsl --shutdown
```

### 2. Open PowerShell as Admin and run:
```powershell
# Find the VHDX
$vhdxPath = "C:\Users\josep\AppData\Local\Packages\CanonicalGroupLimited.Ubuntu_79rhkp1fndgsc\LocalState\ext4.vhdx"

# Compact it
Optimize-VHD -Path $vhdxPath -Mode Full
```

### 3. Restart WSL
```powershell
wsl
```

---

## What's Happening

```
BEFORE COMPACT:
- VHDX file size: 118.94 GB (Windows disk usage)
- Data inside WSL: 29 GB (actual usage)
- Wasted space: 90 GB (trapped in VHDX)

AFTER COMPACT:
- VHDX file size: ~30 GB (Windows disk usage)
- Data inside WSL: 29 GB (actual usage)  
- Wasted space: 0 GB
- Space reclaimed: 90 GB ✓
```

---

## Why This Happens

1. WSL2 uses a virtual disk (VHDX file)
2. The VHDX grows automatically when you add data
3. **The VHDX does NOT shrink** when you delete data
4. You must manually compact it to reclaim space

---

## Prevent This in the Future

The build scripts (`build.sh` / `build.ps1`) now prevent Docker bloat.

But you still need to compact the VHDX occasionally:

```powershell
# Monthly or when disk space is low:
wsl --shutdown
Optimize-VHD -Path "C:\Users\josep\AppData\Local\Packages\CanonicalGroupLimited.Ubuntu_79rhkp1fndgsc\LocalState\ext4.vhdx" -Mode Full
```

Or use the full cleanup script:
```powershell
.\scripts\cleanup-and-compact.ps1  # Run as Admin
```

---

## Check Your Space

```powershell
# Check VHDX size on Windows
$vhdxPath = "C:\Users\josep\AppData\Local\Packages\CanonicalGroupLimited.Ubuntu_79rhkp1fndgsc\LocalState\ext4.vhdx"
$size = (Get-Item $vhdxPath).Length / 1GB
Write-Host "VHDX Size: $([math]::Round($size, 2)) GB"

# Check actual usage inside WSL
wsl df -h / | tail -1
```

If VHDX size >> actual usage, you need to compact.

---

## TL;DR

**Run this as Admin:**
```powershell
cd deepiri\scripts
.\GET_SPACE_BACK.ps1
```

**Gets you back ~90GB in 5 minutes.**


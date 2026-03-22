# Storage Troubleshooting Guide

## The Problem: "Storage Not Freed After Cleanup"

If you ran `cleanup-and-compact.ps1` and it showed space was reclaimed, but Windows still shows the same disk usage, here's what's happening:

### Why This Happens

1. **VHDX files are sparse files** - Windows shows the "logical" size, not actual disk usage
2. **WSL/Docker might not be fully shut down** - Compaction fails if files are in use
3. **Multiple VHDX files** - Docker Desktop can have multiple VHDX files (data, distro, etc.)
4. **Windows caching** - Disk space info might need a refresh

## Solution: Use the Improved Scripts

### Step 1: Diagnose the Problem

Run the diagnostic script to find ALL storage hogs:

```powershell
.\scripts\find-storage-hogs.ps1
```

This will show you:
- All VHDX files and their sizes
- Docker storage locations
- WSL distributions
- Where your space is actually being used

### Step 2: Run the Improved Cleanup Script

The improved `cleanup-and-compact.ps1` now:

1. **Finds ALL VHDX files** (not just the first one)
2. **Ensures WSL is completely shut down** (waits and retries)
3. **Uses both Optimize-VHD and DiskPart** (fallback if one fails)
4. **Verifies compaction worked** (shows before/after sizes)
5. **Compacts Docker AND Ubuntu VHDX files**

Run it as Administrator:

```powershell
.\scripts\cleanup-and-compact.ps1
```

### Step 3: Verify Space Was Freed

After running the script:

1. **Wait a few minutes** - Windows needs time to refresh disk usage
2. **Check File Explorer** - Right-click C: drive → Properties to see free space
3. **Run the diagnostic again** - Compare VHDX file sizes:

```powershell
.\scripts\find-storage-hogs.ps1
```

## Manual Compaction (If Script Fails)

If the script still doesn't work, try manual compaction:

### 1. Shut Down Everything

```powershell
# Stop Docker Desktop (close it completely)
# Then run:
wsl --shutdown

# Wait 30 seconds, then verify:
wsl --list --running
# Should show nothing
```

### 2. Find VHDX Files

```powershell
Get-ChildItem -Path $env:LOCALAPPDATA -Recurse -Filter "*.vhdx" -ErrorAction SilentlyContinue | Select-Object FullName, @{Name="SizeGB";Expression={[math]::Round($_.Length/1GB,2)}}
```

### 3. Compact Each VHDX

**Method 1: Optimize-VHD (Recommended)**

```powershell
Import-Module Hyper-V
Optimize-VHD -Path "C:\path\to\ext4.vhdx" -Mode Full
```

**Method 2: DiskPart (Fallback)**

```powershell
diskpart
select vdisk file="C:\path\to\ext4.vhdx"
attach vdisk readonly
compact vdisk
detach vdisk
exit
```

### 4. Restart Docker Desktop and WSL

```powershell
# Start Docker Desktop manually
# Then:
wsl
```

## Common Issues

### "VHDX file is in use"

**Solution:** Make sure:
- Docker Desktop is completely closed (not just minimized)
- All WSL distributions are shut down: `wsl --shutdown`
- Wait 30 seconds after shutdown
- Check Task Manager for `vmmem.exe` or `wslhost.exe` processes

### "No space reclaimed"

**Possible causes:**
1. VHDX was already compacted
2. Compaction failed silently
3. Space is being used by other files

**Solution:** Run `find-storage-hogs.ps1` to see actual file sizes

### "Optimize-VHD not found"

**Solution:** Install Hyper-V feature:

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
```

Or use DiskPart method instead.

## Expected Results

After successful compaction:
- Docker VHDX files should shrink significantly (50-80% reduction is common)
- Ubuntu VHDX should shrink based on free space inside WSL
- Windows disk usage should reflect the freed space within a few minutes

## Still Not Working?

1. **Check Windows Storage Sense** - Settings → System → Storage → Clean up now
2. **Check Recycle Bin** - Empty it
3. **Check Temp files** - Run Disk Cleanup
4. **Check other drives** - Maybe space is on a different drive
5. **Restart Windows** - Sometimes needed to refresh disk usage

## Quick Reference

```powershell
# Find storage hogs
.\scripts\find-storage-hogs.ps1

# Cleanup and compact (run as Admin)
.\scripts\cleanup-and-compact.ps1

# Check Docker disk usage
docker system df

# Shut down WSL completely
wsl --shutdown

# List WSL distributions
wsl --list --verbose
```


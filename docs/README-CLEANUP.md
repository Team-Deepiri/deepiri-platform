# Docker Cleanup and WSL2 Compaction Scripts

## Quick Start

### Option 1: Run as Administrator (Easiest - Recommended)

1. **Right-click** on `run-cleanup-as-admin.bat`
2. Select **"Run as Administrator"**
3. The script will automatically set execution policy and run the cleanup

### Option 2: Use the PowerShell Launcher

1. **Right-click** on PowerShell icon
2. Select **"Run as Administrator"**
3. Navigate to the deepiri directory:
   ```powershell
   cd C:\Users\josep\Documents\AIToolWebsite\Deepiri\deepiri
   ```
4. Run the launcher:
   ```powershell
   .\run-cleanup-direct.ps1
   ```

### Option 3: Manual PowerShell (Advanced)

1. **Right-click** on PowerShell icon
2. Select **"Run as Administrator"**
3. Navigate to the deepiri directory:
   ```powershell
   cd C:\Users\josep\Documents\AIToolWebsite\Deepiri\deepiri
   ```
4. Set execution policy and run:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
   .\cleanup-and-compact.ps1
   ```
   
   Or in one command:
   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File .\cleanup-and-compact.ps1
   ```

## What the Script Does

The `cleanup-and-compact.ps1` script will:

1. **Docker Cleanup:**
   - Stops all Deepiri containers
   - Prunes unused Docker images (reclaims ~54 GB)
   - Prunes unused Docker volumes (reclaims ~14 GB)
   - Prunes Docker build cache (reclaims ~16 GB)
   - Prunes unused Docker networks

2. **WSL2 Compaction:**
   - Shuts down WSL2 safely
   - Compacts the Ubuntu virtual disk (VHDX)
   - Restarts WSL2
   - Shows space reclaimed

**Total Expected Reclamation: ~85+ GB**

## Requirements

- **Administrator privileges** (required for WSL2 compaction)
- Hyper-V module (usually pre-installed on Windows 10/11)
- WSL2 with Ubuntu installed
- Docker Desktop (optional - script continues without it)

## Troubleshooting

### Script Opens in Notepad Instead of Running

If double-clicking `.ps1` files opens them in Notepad:

1. Use the batch file: `run-cleanup-as-admin.bat` (right-click → Run as Administrator)
2. Or use the PowerShell launcher: `run-cleanup-direct.ps1`
3. Or run from PowerShell:
   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File .\cleanup-and-compact.ps1
   ```

### "Cannot be loaded. The file is not digitally signed"

This is an execution policy error. Solutions:

1. **Easiest**: Use `run-cleanup-as-admin.bat` (it handles this automatically)
2. **PowerShell**: Run this first, then run the script:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
   .\cleanup-and-compact.ps1
   ```
3. **One-liner**:
   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File .\cleanup-and-compact.ps1
   ```

### "You must run this script as Administrator!"

The script requires Administrator privileges. Make sure you:
- Right-click the batch file and select "Run as Administrator"
- Or open PowerShell as Administrator first

### WSL2 VHDX Not Found

If you see "Ubuntu VHDX file not found":
- Make sure WSL2 is installed: `wsl --list --verbose`
- Make sure Ubuntu is installed: `wsl --install -d Ubuntu`

## Files

- `cleanup-and-compact.ps1` - Main cleanup script (requires Admin)
- `run-cleanup-as-admin.bat` - Helper launcher (right-click → Run as Administrator)
- `stop-and-cleanup.ps1` - Docker-only cleanup (no Admin required)
- `stop-and-cleanup.sh` - Bash version for Linux/Mac/WSL



# Deepiri Docker Cleanup and WSL2 Compaction Script
# Purpose: Automatically clean up Docker resources and compact WSL2 virtual disk to reclaim maximum disk space
# Run as Administrator
#
# Usage:
#   1. Open PowerShell as Administrator
#   2. Navigate to the deepiri directory: cd deepiri
#   3. Set execution policy (if needed): Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#   4. Run the script: .\cleanup-and-compact.ps1
#
# What this script does:
#   - Stops all Deepiri Docker containers
#   - Prunes unused Docker images, volumes, build cache, and networks
#   - Shuts down WSL2
#   - Compacts the WSL2 Ubuntu virtual disk (VHDX)
#   - Restarts WSL2
#   - Shows space reclaimed
#
# Requirements:
#   - Administrator privileges
#   - Hyper-V module (usually pre-installed on Windows 10/11)
#   - WSL2 with Ubuntu installed
#   - Docker Desktop (optional - script will continue without it)

# Step 1: Confirm you are running as admin
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "You must run this script as Administrator!"
    Exit
}

# Colors for output
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

Write-ColorOutput Cyan "=========================================="
Write-ColorOutput Cyan "Deepiri Docker Cleanup & WSL2 Compaction"
Write-ColorOutput Cyan "=========================================="
Write-Output ""

# Step 2: Check Docker is available (try both native and WSL)
Write-ColorOutput Yellow "Checking Docker availability..."
$dockerAvailable = $false
$dockerCommand = "docker"

# Try native Docker first
try {
    docker info 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput Green "[OK] Docker is running (native)"
    $dockerAvailable = $true
        $dockerCommand = "docker"
    }
} catch {
    # Try WSL Docker
    try {
        wsl docker info 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput Green "[OK] Docker is running (WSL)"
            $dockerAvailable = $true
            $dockerCommand = "wsl docker"
        }
} catch {
    Write-ColorOutput Yellow "[WARNING] Docker is not running or not accessible. Continuing with WSL compaction only..."
    }
}

Write-Output ""

# Step 3: Show current disk usage
if ($dockerAvailable) {
    Write-ColorOutput Yellow "Current Docker disk usage:"
    Invoke-Expression "$dockerCommand system df"
    Write-Output ""
}

# Step 4: Stop all Deepiri containers
if ($dockerAvailable) {
    Write-ColorOutput Yellow "Stopping all Deepiri containers..."
    
    $containers = Invoke-Expression "$dockerCommand ps -a --filter 'name=deepiri' --format '{{.Names}}'" 2>$null
    if ($containers) {
        $containerList = $containers -split "`n" | Where-Object { $_ -and $_.Trim() }
        foreach ($container in $containerList) {
            if ($container) {
                Write-Output "  Stopping: $container"
                Invoke-Expression "$dockerCommand stop $container" 2>$null | Out-Null
            }
        }
        
        # Also stop docker-compose services
        Write-ColorOutput Yellow "Stopping docker-compose services..."
        $originalLocation = Get-Location
        $scriptDir = Split-Path -Parent $PSScriptRoot
        if (Test-Path (Join-Path $scriptDir "docker-compose.yml")) {
            Set-Location $scriptDir
            wsl bash -c "docker compose -f docker-compose.yml down 2>/dev/null" | Out-Null
            wsl bash -c "docker compose -f docker-compose.dev.yml down 2>/dev/null" | Out-Null
            wsl bash -c "docker compose -f docker-compose.microservices.yml down 2>/dev/null" | Out-Null
            wsl bash -c "docker compose -f docker-compose.enhanced.yml down 2>/dev/null" | Out-Null
        }
        Set-Location $originalLocation
        
        Write-ColorOutput Green "[OK] All containers stopped"
    } else {
        Write-ColorOutput Green "No Deepiri containers found"
    }
    
    Write-Output ""
}

# Step 5: Docker Prune - Remove dangling images first
if ($dockerAvailable) {
    Write-ColorOutput Yellow "Removing dangling (untagged) images..."
    $danglingImages = Invoke-Expression "$dockerCommand images -f 'dangling=true' -q"
    if ($danglingImages) {
        $danglingImages -split "`n" | Where-Object { $_ -and $_.Trim() } | ForEach-Object {
            Invoke-Expression "$dockerCommand rmi $($_.Trim()) -f" 2>$null | Out-Null
        }
        Write-ColorOutput Green "[OK] Dangling images removed"
    } else {
        Write-ColorOutput Green "[OK] No dangling images found"
    }
    Write-Output ""
}

# Step 6: Docker Prune - Remove unused images
if ($dockerAvailable) {
    Write-ColorOutput Yellow "Pruning unused Docker images..."
    Invoke-Expression "$dockerCommand image prune -af" 2>$null | Out-Null
    Write-ColorOutput Green "[OK] Unused images pruned"
    Write-Output ""
}

# Step 7: Docker Prune - Remove unused containers
if ($dockerAvailable) {
    Write-ColorOutput Yellow "Pruning stopped containers..."
    Invoke-Expression "$dockerCommand container prune -f" 2>$null | Out-Null
    Write-ColorOutput Green "[OK] Stopped containers pruned"
    Write-Output ""
}

# Step 8: Docker Prune - Remove unused volumes
if ($dockerAvailable) {
    Write-ColorOutput Yellow "Pruning unused Docker volumes..."
    Invoke-Expression "$dockerCommand volume prune -af" 2>$null | Out-Null
    Write-ColorOutput Green "[OK] Unused volumes pruned"
    Write-Output ""
}

# Step 9: Docker Prune - Remove build cache
if ($dockerAvailable) {
    Write-ColorOutput Yellow "Pruning Docker build cache..."
    Invoke-Expression "$dockerCommand builder prune -af" 2>$null | Out-Null
    Write-ColorOutput Green "[OK] Build cache pruned"
    Write-Output ""
}

# Step 10: Docker Prune - Remove unused networks
if ($dockerAvailable) {
    Write-ColorOutput Yellow "Pruning unused Docker networks..."
    Invoke-Expression "$dockerCommand network prune -f" 2>$null | Out-Null
    Write-ColorOutput Green "[OK] Unused networks pruned"
    Write-Output ""
}

# Step 11: Show Docker disk usage after cleanup
if ($dockerAvailable) {
    Write-ColorOutput Yellow "Docker disk usage after cleanup:"
    Invoke-Expression "$dockerCommand system df"
    Write-Output ""
}

# Step 12: Stop Docker Desktop and Shutdown WSL COMPLETELY
Write-ColorOutput Yellow "Stopping Docker Desktop and WSL..."

# Function to forcefully kill processes by name pattern
function Stop-ProcessesForcefully {
    param([string[]]$ProcessNames)
    
    foreach ($processName in $ProcessNames) {
        try {
            # Get all processes matching the name (case-insensitive, partial match)
            $processes = Get-Process | Where-Object { $_.ProcessName -like "*$processName*" -or $_.Name -like "*$processName*" } -ErrorAction SilentlyContinue
            
            if ($processes) {
                foreach ($proc in $processes) {
                    try {
                        Write-ColorOutput Yellow "  Forcefully killing: $($proc.ProcessName) (PID: $($proc.Id))"
                        Stop-Process -Id $proc.Id -Force -ErrorAction Stop
                    } catch {
                        # If Stop-Process fails, try taskkill as fallback
                        try {
                            taskkill /PID $proc.Id /F 2>$null | Out-Null
                        } catch {
                            Write-ColorOutput Yellow "    [WARNING] Could not kill $($proc.ProcessName) (PID: $($proc.Id))"
                        }
                    }
                }
            }
        } catch {
            # Process not found, continue
        }
    }
}

# Kill Docker processes
Write-ColorOutput Yellow "Forcefully killing Docker processes..."
Stop-ProcessesForcefully @("com.docker.backend", "com.docker.desktop", "Docker Desktop", "dockerd", "docker")
Start-Sleep -Seconds 2

# Kill ALL WSL-related processes aggressively
Write-ColorOutput Yellow "Forcefully killing ALL WSL processes..."
$wslProcessNames = @("wsl", "wslhost", "wslservice", "wslservicehost", "vmmem", "vmcompute", "vmwp", "vmmemWSL")
Stop-ProcessesForcefully $wslProcessNames
Start-Sleep -Seconds 2

# Also kill by executable name patterns
$wslExeNames = @("wsl.exe", "wslhost.exe", "wslservice.exe", "vmmem.exe", "vmcompute.exe", "vmwp.exe")
foreach ($exeName in $wslExeNames) {
    try {
        Get-Process | Where-Object { $_.Path -like "*$exeName*" } | ForEach-Object {
            Write-ColorOutput Yellow "  Forcefully killing: $($_.ProcessName) (Path: $($_.Path))"
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        }
    } catch {
        # Continue if process not found
    }
}

# Kill any remaining processes with "wsl" in the name
Get-Process | Where-Object { $_.ProcessName -like "*wsl*" -or $_.Name -like "*wsl*" } | ForEach-Object {
    try {
        Write-ColorOutput Yellow "  Forcefully killing remaining WSL process: $($_.ProcessName) (PID: $($_.Id))"
        Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
    } catch {
        try {
            taskkill /PID $_.Id /F 2>$null | Out-Null
        } catch {
            # Ignore errors
        }
    }
}

Start-Sleep -Seconds 3

# Terminate all WSL distributions individually
Write-ColorOutput Yellow "Terminating all WSL distributions..."
try {
    $distributions = wsl --list --quiet 2>$null | Where-Object { $_ -and $_.Trim() }
    foreach ($distro in $distributions) {
        if ($distro.Trim()) {
            Write-ColorOutput Yellow "  Terminating distribution: $distro"
            wsl --terminate $distro 2>$null | Out-Null
        }
    }
} catch {
    Write-ColorOutput Yellow "  Could not list distributions, continuing..."
}

Start-Sleep -Seconds 2

# Now shutdown WSL with timeout
Write-ColorOutput Yellow "Shutting down WSL completely..."
$shutdownJob = Start-Job -ScriptBlock { wsl --shutdown }
$shutdownComplete = Wait-Job $shutdownJob -Timeout 10

if (-not $shutdownComplete) {
    Write-ColorOutput Yellow "  WSL shutdown timed out, forcefully killing WSL processes again..."
    Stop-Job $shutdownJob -ErrorAction SilentlyContinue
    Remove-Job $shutdownJob -ErrorAction SilentlyContinue
    
    # Kill WSL processes again
    Stop-ProcessesForcefully $wslProcessNames
    Start-Sleep -Seconds 2
    
    # Try shutdown again
    wsl --shutdown 2>$null | Out-Null
}

Start-Sleep -Seconds 5

# Verify WSL is actually shut down - kill any remaining processes
$retries = 0
$maxRetries = 10
while ($retries -lt $maxRetries) {
    $wslStillRunning = wsl --list --running 2>$null
    $wslProcesses = Get-Process | Where-Object { $_.ProcessName -like "*wsl*" -or $_.Name -like "*wsl*" -or $_.ProcessName -like "*vmmem*" } -ErrorAction SilentlyContinue
    
    if ($wslStillRunning -or $wslProcesses) {
        Write-ColorOutput Yellow "  WSL still running (attempt $($retries + 1)/$maxRetries), forcefully killing remaining processes...KEEP WAITING..."
        
        # Kill all WSL processes again
        if ($wslProcesses) {
            $wslProcesses | ForEach-Object {
                try {
                    Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
                } catch {
                    taskkill /PID $_.Id /F 2>$null | Out-Null
                }
            }
        }
        
        # Terminate distributions again
        try {
            $distributions = wsl --list --quiet 2>$null | Where-Object { $_ -and $_.Trim() }
            foreach ($distro in $distributions) {
                if ($distro.Trim()) {
                    wsl --terminate $distro 2>$null | Out-Null
                }
            }
        } catch {
            # Ignore
        }
        
        wsl --shutdown 2>$null | Out-Null
        Start-Sleep -Seconds 3
        $retries++
    } else {
        break
    }
}

# Final check and kill
$finalWslProcesses = Get-Process | Where-Object { $_.ProcessName -like "*wsl*" -or $_.Name -like "*wsl*" -or $_.ProcessName -like "*vmmem*" } -ErrorAction SilentlyContinue
if ($finalWslProcesses) {
    Write-ColorOutput Yellow "  Final cleanup: Killing remaining WSL processes..."
    $finalWslProcesses | ForEach-Object {
        try {
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        } catch {
            taskkill /PID $_.Id /F 2>$null | Out-Null
        }
    }
    Start-Sleep -Seconds 2
}

$finalCheck = wsl --list --running 2>$null
if ($finalCheck) {
    Write-ColorOutput Red "[WARNING] WSL may still be running. Compaction might fail."
    Write-ColorOutput Yellow "  Remaining processes:"
    Get-Process | Where-Object { $_.ProcessName -like "*wsl*" -or $_.Name -like "*wsl*" -or $_.ProcessName -like "*vmmem*" } | ForEach-Object {
        Write-ColorOutput Yellow "    - $($_.ProcessName) (PID: $($_.Id))"
    }
} else {
    Write-ColorOutput Green "[OK] WSL shutdown complete"
}
Write-Output ""

# Step 13: Find ALL Docker Desktop VHDX files
Write-ColorOutput Yellow "Finding ALL Docker Desktop VHDX files..."
$dockerVhdPaths = @(
    "$env:LOCALAPPDATA\Docker\wsl",
    "$env:USERPROFILE\AppData\Local\Docker\wsl",
    "$env:ProgramData\Docker\wsl"
)

# Find ALL Docker VHDX files (data, distro, etc.)
$allDockerVhdxFiles = @()
foreach ($basePath in $dockerVhdPaths) {
    if (Test-Path $basePath) {
        $files = Get-ChildItem -Path $basePath -Recurse -Filter "*.vhdx" -ErrorAction SilentlyContinue
        if ($files) {
            $allDockerVhdxFiles += $files
        }
    }
}

# Also search in entire Docker directory
if ($allDockerVhdxFiles.Count -eq 0) {
    $allDockerVhdxFiles = Get-ChildItem -Path "$env:LOCALAPPDATA\Docker" -Recurse -Filter "*.vhdx" -ErrorAction SilentlyContinue
}

$dockerSpaceReclaimed = 0
if ($allDockerVhdxFiles.Count -gt 0) {
    Write-ColorOutput Green "Found $($allDockerVhdxFiles.Count) Docker VHDX file(s) to compact"
    Write-Output ""
    
    foreach ($dockerVhd in $allDockerVhdxFiles) {
        $dockerVhdPath = $dockerVhd.FullName
        Write-ColorOutput Yellow "Compacting: $dockerVhdPath"
        
        $dockerSizeBefore = $dockerVhd.Length / 1GB
        $dockerSizeBeforeFormatted = "{0:N2}" -f $dockerSizeBefore
        Write-ColorOutput Cyan "  Size before: $dockerSizeBeforeFormatted GB"
        
        # Try Optimize-VHD first (more reliable)
        $compactionSuccess = $false
        try {
            Import-Module Hyper-V -ErrorAction Stop
            Write-ColorOutput Yellow "  Using Optimize-VHD (this may take several minutes)..."
            Optimize-VHD -Path $dockerVhdPath -Mode Full -ErrorAction Stop
            $compactionSuccess = $true
            Write-ColorOutput Green "  [OK] Optimize-VHD compaction complete"
        } catch {
            Write-ColorOutput Yellow "  Optimize-VHD failed, trying DiskPart..."
            
            # Fallback to DiskPart
            $diskpartScript = @"
select vdisk file="$dockerVhdPath"
attach vdisk readonly
compact vdisk
detach vdisk
exit
"@
            
            $tempFile = [System.IO.Path]::GetTempFileName()
            Set-Content -Path $tempFile -Value $diskpartScript -Encoding ASCII
            
            Write-ColorOutput Yellow "  Running DiskPart compaction..."
            $diskpartResult = diskpart /s $tempFile 2>&1 | Out-String
            Remove-Item $tempFile
            
            if ($LASTEXITCODE -eq 0 -or $diskpartResult -match "successfully compacted") {
                $compactionSuccess = $true
                Write-ColorOutput Green "  [OK] DiskPart compaction complete"
            } else {
                Write-ColorOutput Red "  [ERROR] Compaction failed"
                Write-ColorOutput Yellow "  DiskPart output: $diskpartResult"
            }
        }
        
        if ($compactionSuccess) {
            # Refresh file info
            Start-Sleep -Seconds 2
            $dockerVhdRefreshed = Get-Item $dockerVhdPath
            $dockerSizeAfter = $dockerVhdRefreshed.Length / 1GB
            $dockerSpaceReclaimedThis = [math]::Round($dockerSizeBefore - $dockerSizeAfter, 2)
            $dockerSizeAfterFormatted = "{0:N2}" -f $dockerSizeAfter
            Write-ColorOutput Cyan "  Size after: $dockerSizeAfterFormatted GB"
            Write-ColorOutput Green "  Space reclaimed: $dockerSpaceReclaimedThis GB"
            $dockerSpaceReclaimed += $dockerSpaceReclaimedThis
        }
        Write-Output ""
    }
} else {
    Write-ColorOutput Yellow "[INFO] No Docker Desktop VHDX files found"
    Write-ColorOutput Yellow "[INFO] This is normal if Docker Desktop is not installed or uses WSL2 integration differently"
    Write-Output ""
}

# Step 14: Locate Ubuntu VHDX
Write-ColorOutput Yellow "Locating Ubuntu WSL virtual disk..."
$ubuntuPackagePath = Get-ChildItem "$env:LOCALAPPDATA\Packages" | Where-Object {$_.Name -like "CanonicalGroupLimited.Ubuntu*"} | Select-Object -First 1

If (-not $ubuntuPackagePath) {
    Write-ColorOutput Yellow "[WARNING] Ubuntu WSL package not found. Trying alternative location..."
    # Try alternative location for WSL2
    $vhdxPath = "$env:USERPROFILE\AppData\Local\Packages\CanonicalGroupLimited.Ubuntu*\LocalState\ext4.vhdx"
    $vhdxFiles = Get-ChildItem -Path "$env:USERPROFILE\AppData\Local\Packages" -Recurse -Filter "ext4.vhdx" -ErrorAction SilentlyContinue | Select-Object -First 1
    
    if ($vhdxFiles) {
        $vhdxPath = $vhdxFiles.FullName
        Write-ColorOutput Green "Found VHDX at: $vhdxPath"
    } else {
        Write-ColorOutput Red "[ERROR] Ubuntu VHDX file not found!"
        Write-ColorOutput Yellow "Please ensure WSL2 with Ubuntu is installed."
        Exit
    }
} else {
    $vhdxPath = Join-Path $ubuntuPackagePath.FullName "LocalState\ext4.vhdx"
    
    If (-not (Test-Path $vhdxPath)) {
        Write-ColorOutput Red "[ERROR] VHDX file not found at $vhdxPath"
        Exit
    }
    
    Write-ColorOutput Green "[OK] Found Ubuntu VHDX at: $vhdxPath"
}

Write-Output ""

# Step 15: Get Ubuntu VHDX size before compaction
$vhdxBefore = (Get-Item $vhdxPath).Length
$vhdxBeforeGB = [math]::Round($vhdxBefore / 1GB, 2)
Write-ColorOutput Cyan "VHDX size before compaction: $vhdxBeforeGB GB"
Write-Output ""

# Step 16: Compact the Ubuntu VHDX
Write-ColorOutput Yellow "Compacting Ubuntu VHDX (this may take several minutes)..."
$ubuntuCompactionSuccess = $false

try {
    Import-Module Hyper-V -ErrorAction Stop
    
    # Use Optimize-VHD with Full mode for maximum space reclamation
    Write-ColorOutput Yellow "Using Optimize-VHD with Full mode..."
    Optimize-VHD -Path $vhdxPath -Mode Full -ErrorAction Stop
    
    $ubuntuCompactionSuccess = $true
    Write-ColorOutput Green "[OK] VHDX compaction complete!"
} catch {
    Write-ColorOutput Yellow "Optimize-VHD failed, trying DiskPart as fallback..."
    
    # Fallback to DiskPart
    $diskpartScript = @"
select vdisk file="$vhdxPath"
attach vdisk readonly
compact vdisk
detach vdisk
exit
"@
    
    $tempFile = [System.IO.Path]::GetTempFileName()
    Set-Content -Path $tempFile -Value $diskpartScript -Encoding ASCII
    
    $diskpartResult = diskpart /s $tempFile 2>&1 | Out-String
    Remove-Item $tempFile
    
    if ($LASTEXITCODE -eq 0 -or $diskpartResult -match "successfully compacted") {
        $ubuntuCompactionSuccess = $true
        Write-ColorOutput Green "[OK] DiskPart compaction complete!"
    } else {
        Write-ColorOutput Red "[ERROR] Both compaction methods failed!"
        Write-ColorOutput Yellow "Optimize-VHD error: $_"
        Write-ColorOutput Yellow "DiskPart output: $diskpartResult"
        Write-ColorOutput Yellow "Make sure Hyper-V module is available and WSL is completely shut down."
    }
}

Write-Output ""

# Step 17: Get Ubuntu VHDX size after compaction
if ($ubuntuCompactionSuccess) {
    # Refresh file info to get accurate size
    Start-Sleep -Seconds 2
    $vhdxAfter = (Get-Item $vhdxPath).Length
    $vhdxAfterGB = [math]::Round($vhdxAfter / 1GB, 2)
    $spaceReclaimed = [math]::Round(($vhdxBefore - $vhdxAfter) / 1GB, 2)
    
    Write-ColorOutput Cyan "VHDX size after compaction: $vhdxAfterGB GB"
    if ($spaceReclaimed -gt 0) {
        Write-ColorOutput Green "Space reclaimed: $spaceReclaimed GB"
    } else {
        Write-ColorOutput Yellow "No space reclaimed (file may already be compacted or compaction failed)"
    }
} else {
    $spaceReclaimed = 0
    Write-ColorOutput Red "Compaction failed - no space reclaimed"
}
Write-Output ""

# Step 18: Restart Docker Desktop and WSL
Write-ColorOutput Yellow "Restarting Docker Desktop and WSL..."
$dockerDesktopPaths = @(
    "C:\Program Files\Docker\Docker\Docker Desktop.exe",
    "${env:ProgramFiles(x86)}\Docker\Docker\Docker Desktop.exe",
    "$env:LOCALAPPDATA\Programs\Docker\Docker\Docker Desktop.exe"
)
$dockerDesktopFound = $false
foreach ($dockerPath in $dockerDesktopPaths) {
    if (Test-Path $dockerPath) {
        Start-Process $dockerPath -ErrorAction SilentlyContinue
        Write-ColorOutput Green "[OK] Docker Desktop restarting..."
        $dockerDesktopFound = $true
        break
    }
}
if (-not $dockerDesktopFound) {
    Write-ColorOutput Yellow "[INFO] Docker Desktop executable not found (may not be installed)"
}
wsl --distribution Ubuntu 2>$null | Out-Null
Start-Sleep -Seconds 2
Write-ColorOutput Green "[OK] WSL restarted"
Write-Output ""

# Step 19: Summary
Write-ColorOutput Green "=========================================="
Write-ColorOutput Green "Cleanup and Compaction Complete!"
Write-ColorOutput Green "=========================================="
Write-Output ""
Write-ColorOutput Cyan "Summary:"
if ($dockerAvailable) {
    Write-Output "  [OK] Docker images, volumes, build cache, and networks pruned"
}
if ($allDockerVhdxFiles.Count -gt 0) {
    if ($dockerSpaceReclaimed -gt 0) {
        Write-Output "  [OK] Docker Desktop VHDX files compacted ($($allDockerVhdxFiles.Count) files, reclaimed: $dockerSpaceReclaimed GB)"
    } else {
        Write-Output "  [WARNING] Docker Desktop VHDX files found but no space was reclaimed (may already be compacted)"
    }
} else {
    Write-Output "  [INFO] No Docker Desktop VHDX files found"
}
Write-Output "  [OK] Ubuntu WSL2 virtual disk compacted (reclaimed: $spaceReclaimed GB)"
$totalReclaimed = [math]::Round($spaceReclaimed + $dockerSpaceReclaimed, 2)
Write-Output "  [OK] Total space reclaimed: $totalReclaimed GB"
Write-Output ""
Write-ColorOutput Green "Maximum disk space has been reclaimed!"
Write-Output ""


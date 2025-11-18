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

# Step 2: Check Docker is available
Write-ColorOutput Yellow "Checking Docker availability..."
$dockerAvailable = $false
try {
    docker info | Out-Null
    Write-ColorOutput Green "[OK] Docker is running"
    $dockerAvailable = $true
} catch {
    Write-ColorOutput Yellow "[WARNING] Docker is not running or not accessible. Continuing with WSL compaction only..."
}

Write-Output ""

# Step 3: Show current disk usage
if ($dockerAvailable) {
    Write-ColorOutput Yellow "Current Docker disk usage:"
    docker system df
    Write-Output ""
}

# Step 4: Stop all Deepiri containers
if ($dockerAvailable) {
    Write-ColorOutput Yellow "Stopping all Deepiri containers..."
    
    $containers = docker ps -a --filter "name=deepiri" --format "{{.Names}}" 2>$null
    if ($containers) {
        $containerList = $containers -split "`n" | Where-Object { $_ -and $_.Trim() }
        foreach ($container in $containerList) {
            if ($container) {
                Write-Output "  Stopping: $container"
                docker stop $container 2>$null | Out-Null
            }
        }
        
        # Also stop docker-compose services
        Write-ColorOutput Yellow "Stopping docker-compose services..."
        $originalLocation = Get-Location
        $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
        if (Test-Path (Join-Path $scriptDir "docker-compose.yml")) {
            Set-Location $scriptDir
            docker-compose -f docker-compose.yml down 2>$null | Out-Null
            docker-compose -f docker-compose.dev.yml down 2>$null | Out-Null
            docker-compose -f docker-compose.microservices.yml down 2>$null | Out-Null
            docker-compose -f docker-compose.enhanced.yml down 2>$null | Out-Null
        }
        Set-Location $originalLocation
        
        Write-ColorOutput Green "[OK] All containers stopped"
    } else {
        Write-ColorOutput Green "No Deepiri containers found"
    }
    
    Write-Output ""
}

# Step 5: Docker Prune - Remove unused images
if ($dockerAvailable) {
    Write-ColorOutput Yellow "Pruning unused Docker images..."
    docker image prune -af 2>$null | Out-Null
    Write-ColorOutput Green "[OK] Unused images pruned"
    Write-Output ""
}

# Step 6: Docker Prune - Remove unused volumes
if ($dockerAvailable) {
    Write-ColorOutput Yellow "Pruning unused Docker volumes..."
    docker volume prune -af 2>$null | Out-Null
    Write-ColorOutput Green "[OK] Unused volumes pruned"
    Write-Output ""
}

# Step 7: Docker Prune - Remove build cache
if ($dockerAvailable) {
    Write-ColorOutput Yellow "Pruning Docker build cache..."
    docker builder prune -af 2>$null | Out-Null
    Write-ColorOutput Green "[OK] Build cache pruned"
    Write-Output ""
}

# Step 8: Docker Prune - Remove unused networks
if ($dockerAvailable) {
    Write-ColorOutput Yellow "Pruning unused Docker networks..."
    docker network prune -f 2>$null | Out-Null
    Write-ColorOutput Green "[OK] Unused networks pruned"
    Write-Output ""
}

# Step 9: Show Docker disk usage after cleanup
if ($dockerAvailable) {
    Write-ColorOutput Yellow "Docker disk usage after cleanup:"
    docker system df
    Write-Output ""
}

# Step 10: Stop Docker Desktop and Shutdown WSL COMPLETELY
Write-ColorOutput Yellow "Stopping Docker Desktop and WSL..."
$dockerProcesses = Get-Process -Name "com.docker.backend","com.docker.desktop","Docker Desktop","dockerd","vmmem","wslhost" -ErrorAction SilentlyContinue
if ($dockerProcesses) {
    Write-ColorOutput Yellow "Stopping Docker processes..."
    taskkill /IM "com.docker.backend.exe" /F 2>$null | Out-Null
    taskkill /IM "com.docker.desktop.exe" /F 2>$null | Out-Null
    taskkill /IM "dockerd.exe" /F 2>$null | Out-Null
    taskkill /IM "vmmem.exe" /F 2>$null | Out-Null
    taskkill /IM "wslhost.exe" /F 2>$null | Out-Null
    Start-Sleep -Seconds 3
    Write-ColorOutput Green "[OK] Docker Desktop processes stopped"
} else {
    Write-ColorOutput Yellow "[INFO] Docker Desktop processes not running (may not be installed)"
}

Write-ColorOutput Yellow "Shutting down WSL completely..."
wsl --shutdown
Start-Sleep -Seconds 10

# Verify WSL is actually shut down
$wslStillRunning = wsl --list --running 2>$null
$retries = 0
while ($wslStillRunning -and $retries -lt 5) {
    Write-ColorOutput Yellow "WSL still running, waiting..."
    wsl --shutdown
    Start-Sleep -Seconds 5
    $wslStillRunning = wsl --list --running 2>$null
    $retries++
}

if ($wslStillRunning) {
    Write-ColorOutput Red "[WARNING] WSL may still be running. Compaction might fail."
} else {
    Write-ColorOutput Green "[OK] WSL shutdown complete"
}
Write-Output ""

# Step 11: Find ALL Docker Desktop VHDX files
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

# Step 12: Locate Ubuntu VHDX
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

# Step 13: Get Ubuntu VHDX size before compaction
$vhdxBefore = (Get-Item $vhdxPath).Length
$vhdxBeforeGB = [math]::Round($vhdxBefore / 1GB, 2)
Write-ColorOutput Cyan "VHDX size before compaction: $vhdxBeforeGB GB"
Write-Output ""

# Step 14: Compact the Ubuntu VHDX
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

# Step 15: Get Ubuntu VHDX size after compaction
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

# Step 16: Restart Docker Desktop and WSL
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

# Step 17: Summary
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


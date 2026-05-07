# Deepiri Docker Cleanup and WSL2 Compaction Script
# cleanup-and-compact.ps1
#
# Docker cleanup touches ONLY resources whose names/repos contain "deepiri"
# (containers, images by repository, volumes, networks). Build cache is optional
# and documented as Docker-wide when selected.
#
# Run as Administrator (required for WSL compact and aggressive WSL shutdown).
#
# Usage:
#   .\cleanup-and-compact.ps1                         # Full Deepiri cleanup + WSL compact
#   .\cleanup-and-compact.ps1 -Interactive          # Prompt for what to delete
#   .\cleanup-and-compact.ps1 -Targets Images,Volumes
#
param(
    [switch]$Interactive,
    [ValidateSet('Images', 'Volumes', 'Containers', 'Networks', 'BuildCache', 'WslCompact', 'All')]
    [string[]]$Targets = @('All')
)

If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "You must run this script as Administrator!"
    Exit 1
}

function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

$DeepiriPattern = 'deepiri'

function Test-StringHasDeepiri([string]$s) {
    return $s -and ($s.ToLowerInvariant().Contains($DeepiriPattern))
}

# --- Interactive target selection ---
$DoImages = $false
$DoVolumes = $false
$DoContainers = $false
$DoNetworks = $false
$DoBuildCache = $false
$DoWslCompact = $false

if ($Interactive) {
    Write-ColorOutput Cyan "=========================================="
    Write-ColorOutput Cyan "Select what to clean (Deepiri-scoped)"
    Write-ColorOutput Cyan "=========================================="
    Write-Output ""
    Write-Output "  [1] Deepiri Docker images (repository name contains '$DeepiriPattern')"
    Write-Output "  [2] Deepiri Docker volumes (name contains '$DeepiriPattern')"
    Write-Output "  [3] Deepiri containers (name contains '$DeepiriPattern')"
    Write-Output "  [4] Deepiri Docker networks (name contains '$DeepiriPattern')"
    Write-Output "  [5] Docker build cache — UNUSED CACHE ONLY but NOT filtered by project (Docker-wide)"
    Write-Output "  [6] WSL shutdown + compact Ubuntu VHDX + Docker Desktop VHDX (if present)"
    Write-Output "  [7] All of the above (1–4 + 6; build cache only if you add 5 explicitly)"
    Write-Output ""
    $choice = Read-Host "Enter numbers separated by commas (default: 7)"
    if ([string]::IsNullOrWhiteSpace($choice)) { $choice = '7' }
    $nums = $choice -split '[,\s]+' | Where-Object { $_ -match '^\d+$' }
    foreach ($n in $nums) {
        switch ($n) {
            '1' { $DoImages = $true }
            '2' { $DoVolumes = $true }
            '3' { $DoContainers = $true }
            '4' { $DoNetworks = $true }
            '5' { $DoBuildCache = $true }
            '6' { $DoWslCompact = $true }
            '7' {
                $DoImages = $true; $DoVolumes = $true; $DoContainers = $true; $DoNetworks = $true
                $DoWslCompact = $true
            }
        }
    }
    Write-Output ""
} else {
    $t = $Targets
    if ($t -contains 'All') {
        $DoImages = $true; $DoVolumes = $true; $DoContainers = $true; $DoNetworks = $true
        # Build cache is Docker-wide; omit from All — use -Targets BuildCache or -Interactive [5]
        $DoBuildCache = $false
        $DoWslCompact = $true
    } else {
        if ($t -contains 'Images') { $DoImages = $true }
        if ($t -contains 'Volumes') { $DoVolumes = $true }
        if ($t -contains 'Containers') { $DoContainers = $true }
        if ($t -contains 'Networks') { $DoNetworks = $true }
        if ($t -contains 'BuildCache') { $DoBuildCache = $true }
        if ($t -contains 'WslCompact') { $DoWslCompact = $true }
    }
}

$AnyDockerWork = $DoImages -or $DoVolumes -or $DoContainers -or $DoNetworks -or $DoBuildCache

Write-ColorOutput Cyan "=========================================="
Write-ColorOutput Cyan "Deepiri Docker Cleanup & WSL2 Compaction"
Write-ColorOutput Cyan "=========================================="
Write-Output ""

# --- Docker availability ---
Write-ColorOutput Yellow "Checking Docker availability..."
$dockerAvailable = $false
$dockerUseWsl = $false

try {
    docker info 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput Green "[OK] Docker is running (native)"
        $dockerAvailable = $true
    }
} catch {
    # continue to WSL attempt
}

if (-not $dockerAvailable) {
    try {
        wsl docker info 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput Green "[OK] Docker is running (WSL)"
            $dockerAvailable = $true
            $dockerUseWsl = $true
        }
    } catch {
        Write-ColorOutput Yellow "[WARNING] Docker is not running or not accessible."
    }
}

if (-not $dockerAvailable -and $AnyDockerWork) {
    Write-ColorOutput Yellow "[WARNING] Skipping Docker cleanup steps (Docker unavailable)."
    $AnyDockerWork = $false
}

function Invoke-DockerCmd {
    param([Parameter(Mandatory)][string[]]$Arguments)
    if ($dockerUseWsl) {
        & wsl docker @Arguments
    } else {
        & docker @Arguments
    }
}

if ($dockerAvailable -and $AnyDockerWork) {
    Write-ColorOutput Yellow "Note: 'docker system df' below is Docker-wide (informational). Cleanup operations only affect names/repos matching '$DeepiriPattern'."
    Invoke-DockerCmd @('system', 'df')
    Write-Output ""
}

# --- Stop Deepiri containers (when removing containers/images; needed before image rm) ---
if ($dockerAvailable -and ($DoContainers -or $DoImages)) {
    Write-ColorOutput Yellow "Stopping Deepiri containers (name filter)..."
    $containers = Invoke-DockerCmd @('ps', '-a', '--filter', 'name=deepiri', '--format', '{{.Names}}')
    if ($containers) {
        $containerList = @($containers) | Where-Object { $_ -and $_.Trim() }
        foreach ($container in $containerList) {
            Write-Output "  Stopping: $container"
            Invoke-DockerCmd @('stop', $container) 2>$null | Out-Null
        }
        $originalLocation = Get-Location
        $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        if (Test-Path (Join-Path $repoRoot "docker-compose.yml")) {
            Write-ColorOutput Yellow "Stopping docker-compose services (repo root)..."
            Set-Location $repoRoot
            wsl bash -c "docker compose -f docker-compose.yml down 2>/dev/null" | Out-Null
            wsl bash -c "docker compose -f docker-compose.dev.yml down 2>/dev/null" | Out-Null
            wsl bash -c "docker compose -f docker-compose.microservices.yml down 2>/dev/null" | Out-Null
            wsl bash -c "docker compose -f docker-compose.enhanced.yml down 2>/dev/null" | Out-Null
        }
        Set-Location $originalLocation
        Write-ColorOutput Green "[OK] Deepiri containers stopped"
    } else {
        Write-ColorOutput Green "[OK] No Deepiri-named containers found"
    }
    Write-Output ""
}

# --- Remove stopped Deepiri containers ---
if ($dockerAvailable -and $DoContainers) {
    Write-ColorOutput Yellow "Removing stopped Deepiri containers..."
    $ids = Invoke-DockerCmd @('ps', '-a', '-q', '--filter', 'name=deepiri')
    if ($ids) {
        @($ids) | Where-Object { $_ } | ForEach-Object {
            Invoke-DockerCmd @('rm', '-f', $_.Trim()) 2>$null | Out-Null
        }
        Write-ColorOutput Green "[OK] Deepiri containers removed"
    } else {
        Write-ColorOutput Green "[OK] No Deepiri containers to remove"
    }
    Write-Output ""
}

# --- Deepiri images only ---
if ($dockerAvailable -and $DoImages) {
    Write-ColorOutput Yellow "Removing Deepiri images (repository contains '$DeepiriPattern')..."
    $lines = Invoke-DockerCmd @('images', '--format', '{{.Repository}}:{{.Tag}}')
    $removed = 0
    if ($lines) {
        foreach ($line in @($lines)) {
            if (-not $line) { continue }
            $repo = ($line -split ':')[0]
            if (Test-StringHasDeepiri $repo) {
                Write-Output "  Removing image: $line"
                Invoke-DockerCmd @('rmi', '-f', $line.Trim()) 2>$null | Out-Null
                $removed++
            }
        }
    }
    Write-ColorOutput Green "[OK] Deepiri image removal finished ($removed matched)"
    Write-Output ""
}

# --- Deepiri volumes only ---
if ($dockerAvailable -and $DoVolumes) {
    Write-ColorOutput Yellow "Removing Deepiri volumes (name contains '$DeepiriPattern')..."
    $vols = Invoke-DockerCmd @('volume', 'ls', '-q')
    $removedV = 0
    if ($vols) {
        foreach ($v in @($vols)) {
            if (-not $v) { continue }
            if (Test-StringHasDeepiri $v) {
                Write-Output "  Removing volume: $v"
                Invoke-DockerCmd @('volume', 'rm', '-f', $v.Trim()) 2>$null | Out-Null
                $removedV++
            }
        }
    }
    Write-ColorOutput Green "[OK] Deepiri volume removal finished ($removedV matched)"
    Write-Output ""
}

# --- Deepiri networks only (never touch bridge/host/none) ---
if ($dockerAvailable -and $DoNetworks) {
    Write-ColorOutput Yellow "Removing Deepiri networks..."
    $netLines = Invoke-DockerCmd @('network', 'ls', '--format', '{{.Name}}')
    $skipped = @('bridge', 'host', 'none')
    $removedN = 0
    if ($netLines) {
        foreach ($nn in @($netLines)) {
            if (-not $nn) { continue }
            if ($skipped -contains $nn) { continue }
            if (Test-StringHasDeepiri $nn) {
                Write-Output "  Removing network: $nn"
                Invoke-DockerCmd @('network', 'rm', $nn.Trim()) 2>$null | Out-Null
                $removedN++
            }
        }
    }
    Write-ColorOutput Green "[OK] Deepiri network removal finished ($removedN matched)"
    Write-Output ""
}

# --- Build cache (Docker-wide) ---
if ($dockerAvailable -and $DoBuildCache) {
    Write-ColorOutput Yellow "Pruning Docker build cache (Docker-wide unused layers)..."
    Invoke-DockerCmd @('builder', 'prune', '-af') 2>$null | Out-Null
    Write-ColorOutput Green "[OK] Build cache pruned"
    Write-Output ""
}

if ($dockerAvailable -and $AnyDockerWork) {
    Write-ColorOutput Yellow "Docker disk usage after Deepiri-targeted cleanup:"
    Invoke-DockerCmd @('system', 'df')
    Write-Output ""
}

# ========== WSL shutdown + compaction ==========
$dockerSpaceReclaimed = 0
$spaceReclaimed = 0
$ubuntuCompactionSuccess = $false
$allDockerVhdxFiles = @()

function Stop-ProcessesForcefully {
    param([string[]]$ProcessNames)

    foreach ($processName in $ProcessNames) {
        try {
            $processes = Get-Process | Where-Object { $_.ProcessName -like "*$processName*" -or $_.Name -like "*$processName*" } -ErrorAction SilentlyContinue

            if ($processes) {
                foreach ($proc in $processes) {
                    try {
                        Write-ColorOutput Yellow "  Forcefully killing: $($proc.ProcessName) (PID: $($proc.Id))"
                        Stop-Process -Id $proc.Id -Force -ErrorAction Stop
                    } catch {
                        try {
                            & taskkill.exe /PID $proc.Id /F 2>$null | Out-Null
                        } catch {
                            Write-ColorOutput Yellow "    [WARNING] Could not kill $($proc.ProcessName) (PID: $($proc.Id))"
                        }
                    }
                }
            }
        } catch {
            # continue
        }
    }
}

function Stop-WslViaServiceFallback {
    Write-ColorOutput Yellow "[Fallback] Attempting to stop WSL via LxssManager service..."
    $ok = $false
    try {
        $svc = Get-Service -Name LxssManager -ErrorAction Stop
        if ($svc.Status -eq 'Running') {
            Stop-Service -Name LxssManager -Force -ErrorAction Stop
            $ok = $true
        }
    } catch {
        Write-ColorOutput Yellow "  Stop-Service LxssManager: $($_.Exception.Message)"
    }
    if (-not $ok) {
        try {
            & sc.exe stop LxssManager 2>&1 | Out-Null
            Start-Sleep -Seconds 2
            $ok = $true
        } catch { }
    }
    if (-not $ok) {
        try {
            cmd.exe /c "echo y| net stop LxssManager" 2>&1 | Out-Null
            Start-Sleep -Seconds 2
            $ok = $true
        } catch { }
    }
    Start-Sleep -Seconds 3
    return $ok
}

function Invoke-TaskKillByImage {
    param([string[]]$ImageNames)
    foreach ($im in $ImageNames) {
        try {
            Write-ColorOutput Yellow "[Fallback] taskkill /IM $im /F /T ..."
            & taskkill.exe /IM $im /F /T 2>&1 | Out-Null
        } catch { }
    }
}

function Test-WslProcessesRemain {
    $runningLines = @(wsl --list --running 2>$null | Where-Object { $_ -and $_.Trim() -ne '' })
    if ($runningLines.Count -gt 0) { return $true }

    $interesting = @('wsl', 'wslhost', 'wslservice', 'vmmem', 'vmmemWSL', 'vmwp')
    foreach ($p in Get-Process -ErrorAction SilentlyContinue) {
        foreach ($n in $interesting) {
            if ($p.ProcessName -like "*$n*") { return $true }
        }
    }
    return $false
}

function Show-RemainingWslProcesses {
    Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -like "*wsl*" -or $_.Name -like "*wsl*" -or $_.ProcessName -like "*vmmem*" -or $_.ProcessName -like "*vmwp*"
    } | ForEach-Object {
        Write-ColorOutput Yellow "    - $($_.ProcessName) (PID: $($_.Id))"
    }
}

function Invoke-WslShutdownSequence {
    Write-ColorOutput Yellow "Stopping Docker Desktop and WSL..."

    Write-ColorOutput Yellow "Forcefully killing Docker processes..."
    Stop-ProcessesForcefully @("com.docker.backend", "com.docker.desktop", "Docker Desktop", "dockerd", "docker")
    Start-Sleep -Seconds 2

    Write-ColorOutput Yellow "Forcefully killing WSL-related processes..."
    $wslProcessNames = @("wsl", "wslhost", "wslservice", "wslservicehost", "vmmem", "vmcompute", "vmwp", "vmmemWSL")
    Stop-ProcessesForcefully $wslProcessNames
    Start-Sleep -Seconds 2

    $wslExeNames = @("wsl.exe", "wslhost.exe", "wslservice.exe", "vmmem.exe", "vmcompute.exe", "vmwp.exe")
    foreach ($exeName in $wslExeNames) {
        try {
            Get-Process | Where-Object { $_.Path -like "*$exeName*" } | ForEach-Object {
                Write-ColorOutput Yellow "  Forcefully killing: $($_.ProcessName) (Path: $($_.Path))"
                Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
            }
        } catch { }
    }

    Get-Process | Where-Object { $_.ProcessName -like "*wsl*" -or $_.Name -like "*wsl*" } | ForEach-Object {
        try {
            Write-ColorOutput Yellow "  Forcefully killing remaining WSL process: $($_.ProcessName) (PID: $($_.Id))"
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        } catch {
            & taskkill.exe /PID $_.Id /F 2>$null | Out-Null
        }
    }

    Start-Sleep -Seconds 3

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

    Write-ColorOutput Yellow "Shutting down WSL completely..."
    $shutdownJob = Start-Job -ScriptBlock { wsl --shutdown }
    $shutdownComplete = Wait-Job $shutdownJob -Timeout 15
    if (-not $shutdownComplete) {
        Write-ColorOutput Yellow "  WSL shutdown timed out; stopping job and retrying kills..."
        Stop-Job $shutdownJob -ErrorAction SilentlyContinue
        Remove-Job $shutdownJob -ErrorAction SilentlyContinue
        Stop-ProcessesForcefully $wslProcessNames
        Start-Sleep -Seconds 2
        wsl --shutdown 2>$null | Out-Null
    }

    Start-Sleep -Seconds 5

    $retries = 0
    $maxRetries = 10
    while ($retries -lt $maxRetries -and (Test-WslProcessesRemain)) {
        Write-ColorOutput Yellow "  WSL still running (attempt $($retries + 1)/$maxRetries), retrying..."
        Stop-ProcessesForcefully $wslProcessNames
        Get-Process | Where-Object { $_.ProcessName -like "*wsl*" -or $_.ProcessName -like "*vmmem*" } | ForEach-Object {
            try { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue } catch { & taskkill.exe /PID $_.Id /F 2>$null | Out-Null }
        }
        try {
            $distributions = wsl --list --quiet 2>$null | Where-Object { $_ -and $_.Trim() }
            foreach ($distro in $distributions) {
                if ($distro.Trim()) { wsl --terminate $distro 2>$null | Out-Null }
            }
        } catch { }
        wsl --shutdown 2>$null | Out-Null
        Start-Sleep -Seconds 3
        $retries++
    }

    if (Test-WslProcessesRemain) {
        Write-ColorOutput Yellow "[Fallback] Escalating: LxssManager + taskkill on stubborn images..."
        Stop-WslViaServiceFallback | Out-Null
        Invoke-TaskKillByImage @('wslservice.exe', 'wslhost.exe', 'wsl.exe', 'vmmemWSL.exe', 'vmwp.exe')
        Start-Sleep -Seconds 4
        wsl --shutdown 2>$null | Out-Null
        Start-Sleep -Seconds 3
    }

    if (Test-WslProcessesRemain) {
        Write-ColorOutput Yellow "[Fallback] Second pass: LxssManager + taskkill..."
        Stop-WslViaServiceFallback | Out-Null
        Invoke-TaskKillByImage @('wslservice.exe', 'wslhost.exe', 'vmmemWSL.exe')
        Start-Sleep -Seconds 5
        wsl --shutdown 2>$null | Out-Null
    }

    $finalWslProcesses = Get-Process | Where-Object { $_.ProcessName -like "*wsl*" -or $_.Name -like "*wsl*" -or $_.ProcessName -like "*vmmem*" } -ErrorAction SilentlyContinue
    if ($finalWslProcesses) {
        Write-ColorOutput Yellow "  Final cleanup: Killing remaining WSL processes..."
        $finalWslProcesses | ForEach-Object {
            try { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue } catch { & taskkill.exe /PID $_.Id /F 2>$null | Out-Null }
        }
        Start-Sleep -Seconds 2
    }

    $finalCheck = wsl --list --running 2>$null
    if ($finalCheck -or (Test-WslProcessesRemain)) {
        Write-ColorOutput Red "[WARNING] WSL may still be running. Compaction might fail."
        Write-ColorOutput Yellow "  Remaining processes:"
        Show-RemainingWslProcesses
        Write-ColorOutput Yellow "  If compaction fails, reboot Windows or run: Start-Service LxssManager then wsl --shutdown, then re-run this script."
    } else {
        Write-ColorOutput Green "[OK] WSL shutdown complete"
    }
    Write-Output ""
}

if ($DoWslCompact) {
    Invoke-WslShutdownSequence

    # Docker Desktop VHDX
    Write-ColorOutput Yellow "Finding ALL Docker Desktop VHDX files..."
    $dockerVhdPaths = @(
        "$env:LOCALAPPDATA\Docker\wsl",
        "$env:USERPROFILE\AppData\Local\Docker\wsl",
        "$env:ProgramData\Docker\wsl"
    )

    foreach ($basePath in $dockerVhdPaths) {
        if (Test-Path $basePath) {
            $files = Get-ChildItem -Path $basePath -Recurse -Filter "*.vhdx" -ErrorAction SilentlyContinue
            if ($files) { $allDockerVhdxFiles += $files }
        }
    }
    if ($allDockerVhdxFiles.Count -eq 0) {
        $extra = Get-ChildItem -Path "$env:LOCALAPPDATA\Docker" -Recurse -Filter "*.vhdx" -ErrorAction SilentlyContinue
        if ($extra) { $allDockerVhdxFiles = @($extra) }
    }

    if ($allDockerVhdxFiles.Count -gt 0) {
        Write-ColorOutput Green "Found $($allDockerVhdxFiles.Count) Docker VHDX file(s) to compact"
        Write-Output ""

        foreach ($dockerVhd in $allDockerVhdxFiles) {
            $dockerVhdPath = $dockerVhd.FullName
            Write-ColorOutput Yellow "Compacting: $dockerVhdPath"

            $dockerSizeBefore = $dockerVhd.Length / 1GB
            Write-ColorOutput Cyan "  Size before: $('{0:N2}' -f $dockerSizeBefore) GB"

            $compactionSuccess = $false
            try {
                Import-Module Hyper-V -ErrorAction Stop
                Write-ColorOutput Yellow "  Using Optimize-VHD..."
                Optimize-VHD -Path $dockerVhdPath -Mode Full -ErrorAction Stop
                $compactionSuccess = $true
                Write-ColorOutput Green "  [OK] Optimize-VHD compaction complete"
            } catch {
                Write-ColorOutput Yellow "  Optimize-VHD failed, trying DiskPart..."
                $diskpartScript = @"
select vdisk file="$dockerVhdPath"
attach vdisk readonly
compact vdisk
detach vdisk
exit
"@
                $tempFile = [System.IO.Path]::GetTempFileName()
                Set-Content -Path $tempFile -Value $diskpartScript -Encoding ASCII
                $diskpartResult = & diskpart.exe /s $tempFile 2>&1 | Out-String
                Remove-Item $tempFile -ErrorAction SilentlyContinue

                if ($LASTEXITCODE -eq 0 -or $diskpartResult -match "successfully compacted") {
                    $compactionSuccess = $true
                    Write-ColorOutput Green "  [OK] DiskPart compaction complete"
                } else {
                    Write-ColorOutput Red "  [ERROR] Compaction failed"
                    Write-ColorOutput Yellow "  DiskPart output: $diskpartResult"
                }
            }

            if ($compactionSuccess) {
                Start-Sleep -Seconds 2
                $dockerVhdRefreshed = Get-Item $dockerVhdPath
                $dockerSizeAfter = $dockerVhdRefreshed.Length / 1GB
                $dockerSpaceReclaimedThis = [math]::Round($dockerSizeBefore - $dockerSizeAfter, 2)
                Write-ColorOutput Cyan "  Size after: $('{0:N2}' -f $dockerSizeAfter) GB"
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

    # Ubuntu VHDX
    Write-ColorOutput Yellow "Locating Ubuntu WSL virtual disk (authoritative)..."

    $lxssKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss"
    $ubuntuDistro = Get-ChildItem $lxssKey -ErrorAction SilentlyContinue | ForEach-Object {
        $props = Get-ItemProperty $_.PSPath
        if ($props.DistributionName -match "^Ubuntu") {
            [PSCustomObject]@{
                Name     = $props.DistributionName
                BasePath = $props.BasePath
            }
        }
    } | Select-Object -First 1

    if (-not $ubuntuDistro) {
        Write-ColorOutput Red "[ERROR] No Ubuntu WSL distribution found."
    } else {
        $vhdxPath = Join-Path $ubuntuDistro.BasePath "ext4.vhdx"

        if (-not (Test-Path $vhdxPath)) {
            Write-ColorOutput Red "[ERROR] VHDX file not found at $vhdxPath"
        } else {
            Write-ColorOutput Green "[OK] Found Ubuntu VHDX at: $vhdxPath"
            Write-Output ""

            $vhdxBefore = (Get-Item $vhdxPath).Length
            $vhdxBeforeGB = [math]::Round($vhdxBefore / 1GB, 2)
            Write-ColorOutput Cyan "VHDX size before compaction: $vhdxBeforeGB GB"
            Write-Output ""

            Write-ColorOutput Yellow "Compacting Ubuntu VHDX (this may take several minutes)..."

            try {
                Import-Module Hyper-V -ErrorAction Stop
                Write-ColorOutput Yellow "Using Optimize-VHD with Full mode..."
                Optimize-VHD -Path $vhdxPath -Mode Full -ErrorAction Stop

                $ubuntuCompactionSuccess = $true
                Write-ColorOutput Green "[OK] VHDX compaction complete!"
            } catch {
                Write-ColorOutput Yellow "Optimize-VHD failed, trying DiskPart as fallback..."
                $diskpartScript = @"
select vdisk file="$vhdxPath"
attach vdisk readonly
compact vdisk
detach vdisk
exit
"@
                $tempFile = [System.IO.Path]::GetTempFileName()
                Set-Content -Path $tempFile -Value $diskpartScript -Encoding ASCII

                $diskpartResult = & diskpart.exe /s $tempFile 2>&1 | Out-String
                Remove-Item $tempFile -ErrorAction SilentlyContinue

                if ($LASTEXITCODE -eq 0 -or $diskpartResult -match "successfully compacted") {
                    $ubuntuCompactionSuccess = $true
                    Write-ColorOutput Green "[OK] DiskPart compaction complete!"
                } else {
                    Write-ColorOutput Red "[ERROR] Both compaction methods failed!"
                    Write-ColorOutput Yellow "Optimize-VHD error: $_"
                    Write-ColorOutput Yellow "DiskPart output: $diskpartResult"
                    Write-ColorOutput Yellow "Try rebooting Windows, or ensure WSL is fully stopped (LxssManager stopped)."
                }
            }

            Write-Output ""

            if ($ubuntuCompactionSuccess) {
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
        }
    }
}

Write-ColorOutput Yellow "=========================================="
Write-ColorOutput Yellow "Manual Restart Required"
Write-ColorOutput Yellow "=========================================="
Write-Output ""
Write-ColorOutput Cyan "When using WSL compact: Docker Desktop and WSL were shut down."
Write-ColorOutput Cyan "Restart manually when ready:"
Write-Output ""
Write-ColorOutput Yellow "Docker Desktop:"
Write-Output "  Start-Process 'C:\Program Files\Docker\Docker\Docker Desktop.exe'"
Write-Output ""
Write-ColorOutput Yellow "WSL / LxssManager (if LxssManager was stopped by fallback):"
Write-Output "  Start-Service LxssManager   # elevated PowerShell"
Write-Output "  wsl --distribution Ubuntu"
Write-Output ""

Write-ColorOutput Green "=========================================="
Write-ColorOutput Green "Cleanup finished"
Write-ColorOutput Green "=========================================="
Write-Output ""
Write-ColorOutput Cyan "Summary:"
if ($dockerAvailable -and $AnyDockerWork) {
    Write-Output "  [OK] Ran Deepiri-scoped Docker steps as selected"
}
if ($DoWslCompact) {
    if ($allDockerVhdxFiles.Count -gt 0) {
        Write-Output "  [INFO] Docker Desktop VHDX: reclaimed ~ $dockerSpaceReclaimed GB"
    }
    Write-Output "  [INFO] Ubuntu WSL2 VHDX: reclaimed ~ $spaceReclaimed GB"
}
Write-Output ""

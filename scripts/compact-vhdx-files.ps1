# Compact VHDX Files Script
# This script compacts all Docker and WSL VHDX files to reclaim disk space
# Run as Administrator
#
# Usage:
#   .\compact-vhdx-files.ps1 [-VhdxFiles <FileInfo[]>] [-AutoShutdown]
#
# Parameters:
#   -VhdxFiles: Array of VHDX file objects to compact (optional, will find all if not provided)
#   -AutoShutdown: Automatically shut down WSL/Docker before compaction (default: true)

param(
    [Parameter(Mandatory=$false)]
    [System.IO.FileInfo[]]$VhdxFiles,
    
    [Parameter(Mandatory=$false)]
    [switch]$AutoShutdown = $true
)

# Colors for output
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

# Check if running as Administrator
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-ColorOutput Red "[ERROR] You must run this script as Administrator!"
    Write-ColorOutput Yellow "Right-click PowerShell and select 'Run as Administrator'"
    Exit 1
}

Write-ColorOutput Cyan "=========================================="
Write-ColorOutput Cyan "VHDX Compaction Tool"
Write-ColorOutput Cyan "=========================================="
Write-Output ""

# Step 1: Shut down WSL and Docker if requested
if ($AutoShutdown) {
    Write-ColorOutput Yellow "Stopping Docker Desktop and WSL..."
    
    # Function to kill processes by name
    function Stop-ProcessByName {
        param([string[]]$ProcessNames)
        foreach ($procName in $ProcessNames) {
            $processes = Get-Process -Name $procName -ErrorAction SilentlyContinue
            if ($processes) {
                foreach ($proc in $processes) {
                    try {
                        Stop-Process -Id $proc.Id -Force -ErrorAction Stop
                        Write-ColorOutput Yellow "  Killed: $procName (PID: $($proc.Id))"
                    } catch {
                        # Try taskkill as fallback
                        taskkill /PID $proc.Id /F 2>$null | Out-Null
                    }
                }
            }
        }
    }
    
    # Stop Docker Desktop processes
    Write-ColorOutput Yellow "Stopping Docker Desktop processes..."
    Stop-ProcessByName @("com.docker.backend", "com.docker.desktop", "Docker Desktop", "dockerd")
    Start-Sleep -Seconds 2
    
    # Stop WSL processes aggressively
    Write-ColorOutput Yellow "Stopping WSL processes..."
    
    # Step 1: Terminate all running distributions explicitly
    Write-ColorOutput Yellow "  Step 1: Terminating all running distributions..."
    $runningDistrosOutput = wsl --list --running 2>$null
    if ($runningDistrosOutput -and -not ($runningDistrosOutput -match "There are no running distributions")) {
        # Parse distribution names from output
        $distroLines = $runningDistrosOutput -split "`r?`n" | Where-Object { 
            $_ -and 
            $_ -notmatch "^NAME" -and 
            $_ -notmatch "^---" -and
            $_ -notmatch "There are no" -and
            $_.Trim().Length -gt 0
        }
        
        foreach ($line in $distroLines) {
            # Remove leading/trailing whitespace and get first word (distribution name)
            $line = $line.Trim()
            if ($line) {
                # Split on whitespace and take first non-empty element
                $parts = $line -split '\s+', 2
                $distroName = $parts[0]
                
                # Skip if it looks like a header or error message
                if ($distroName -and 
                    $distroName -ne "NAME" -and 
                    $distroName -ne "There" -and
                    $distroName.Length -gt 0 -and
                    $distroName -notmatch "^---") {
                    Write-ColorOutput Yellow "    Terminating: $distroName"
                    wsl --terminate $distroName 2>$null | Out-Null
                }
            }
        }
        Start-Sleep -Seconds 3
    }
    
    # Step 2: Force shutdown all WSL
    Write-ColorOutput Yellow "  Step 2: Forcing WSL shutdown..."
    wsl --shutdown 2>$null | Out-Null
    Start-Sleep -Seconds 5
    
    # Step 3: Stop the WSL service (this prevents wslservice from respawning)
    Write-ColorOutput Yellow "  Step 3: Stopping WSL service..."
    try {
        # Try WSLService first (common name)
        $wslService = Get-Service -Name "WSLService" -ErrorAction SilentlyContinue
        if (-not $wslService) {
            # Try LxssManager (alternative name)
            $wslService = Get-Service -Name "LxssManager" -ErrorAction SilentlyContinue
        }
        
        if ($wslService -and $wslService.Status -eq 'Running') {
            Stop-Service -Name $wslService.Name -Force -ErrorAction Stop
            Write-ColorOutput Green "    [OK] WSL service ($($wslService.Name)) stopped"
        } else {
            Write-ColorOutput Yellow "    [INFO] WSL service already stopped"
        }
    } catch {
        # Try using sc command as fallback
        sc stop WSLService 2>$null | Out-Null
        sc stop LxssManager 2>$null | Out-Null
        Start-Sleep -Seconds 2
    }
    
    # Step 4: Kill any remaining WSL processes
    Write-ColorOutput Yellow "  Step 4: Killing remaining WSL processes..."
    $criticalWslProcesses = @("vmmem", "vmmemWSL", "wslhost")
    Stop-ProcessByName $criticalWslProcesses
    
    # Kill wslservice processes
    $wslServiceProcs = Get-Process -Name "wslservice" -ErrorAction SilentlyContinue
    if ($wslServiceProcs) {
        foreach ($proc in $wslServiceProcs) {
            try {
                Stop-Process -Id $proc.Id -Force -ErrorAction Stop
            } catch {
                taskkill /PID $proc.Id /F 2>$null | Out-Null
            }
        }
    }
    
    Start-Sleep -Seconds 5
    
    # Step 5: Verify WSL is shut down using wsl --list --verbose
    Write-ColorOutput Yellow "Verifying WSL is shut down..."
    $wslShutDown = $false
    $maxRetries = 6
    
    for ($i = 0; $i -lt $maxRetries; $i++) {
        # Check using wsl --list --verbose (shows status: Running or Stopped)
        $verboseOutput = wsl --list --verbose 2>$null
        $allStopped = $true
        
        if ($verboseOutput) {
            $distroLines = $verboseOutput -split "`r?`n" | Where-Object { 
                $_ -and 
                $_ -notmatch "^NAME" -and 
                $_ -notmatch "^---" -and
                $_ -notmatch "^STATE" -and
                $_.Trim().Length -gt 0
            }
            
            foreach ($line in $distroLines) {
                if ($line -match "Running") {
                    $allStopped = $false
                    # Parse distribution name (first column)
                    $line = $line.Trim()
                    $parts = $line -split '\s+', 2
                    $distroName = $parts[0]
                    
                    if ($distroName -and 
                        $distroName -ne "NAME" -and 
                        $distroName -ne "There" -and
                        $distroName.Length -gt 0) {
                        Write-ColorOutput Yellow "    Still running: $distroName - terminating..."
                        wsl --terminate $distroName 2>$null | Out-Null
                    }
                }
            }
        }
        
        # Also check for vmmem processes (definitive indicator of running VMs)
        $vmmemProcs = Get-Process -Name "vmmem","vmmemWSL" -ErrorAction SilentlyContinue
        if ($vmmemProcs) {
            $allStopped = $false
            Write-ColorOutput Yellow "    Killing vmmem processes (VMs still running)..."
            foreach ($proc in $vmmemProcs) {
                try {
                    Stop-Process -Id $proc.Id -Force -ErrorAction Stop
                    Write-ColorOutput Yellow "      Killed: vmmem (PID: $($proc.Id))"
                } catch {
                    taskkill /PID $proc.Id /F 2>$null | Out-Null
                }
            }
        }
        
        # Check wslhost processes
        $wslhostProcs = Get-Process -Name "wslhost" -ErrorAction SilentlyContinue
        if ($wslhostProcs) {
            $allStopped = $false
            Write-ColorOutput Yellow "    Killing wslhost processes..."
            foreach ($proc in $wslhostProcs) {
                try {
                    Stop-Process -Id $proc.Id -Force -ErrorAction Stop
                } catch {
                    taskkill /PID $proc.Id /F 2>$null | Out-Null
                }
            }
        }
        
        if ($allStopped -and -not $vmmemProcs -and -not $wslhostProcs) {
            # Final verification with wsl --list --verbose
            $finalCheck = wsl --list --verbose 2>$null
            $finalAllStopped = $true
            if ($finalCheck) {
                $finalLines = $finalCheck -split "`r?`n" | Where-Object { 
                    $_ -and 
                    $_ -notmatch "^NAME" -and 
                    $_ -notmatch "^---" -and
                    $_ -notmatch "^STATE" -and
                    $_.Trim().Length -gt 0
                }
                foreach ($line in $finalLines) {
                    if ($line -match "Running") {
                        $finalAllStopped = $false
                        break
                    }
                }
            }
            
            if ($finalAllStopped) {
                $wslShutDown = $true
                Write-ColorOutput Green "  [OK] All WSL distributions are Stopped"
                break
            }
        }
        
        if (-not $wslShutDown) {
            Write-ColorOutput Yellow "  Still shutting down... (attempt $($i+1)/$maxRetries)"
            # Force shutdown again
            wsl --shutdown 2>$null | Out-Null
            Start-Sleep -Seconds 5
            
            # Stop service again if needed
            try {
                $wslService = Get-Service -Name "WSLService" -ErrorAction SilentlyContinue
                if (-not $wslService) {
                    $wslService = Get-Service -Name "LxssManager" -ErrorAction SilentlyContinue
                }
                if ($wslService -and $wslService.Status -eq 'Running') {
                    Stop-Service -Name $wslService.Name -Force -ErrorAction Stop
                }
            } catch {
                sc stop WSLService 2>$null | Out-Null
                sc stop LxssManager 2>$null | Out-Null
            }
            Start-Sleep -Seconds 3
        }
    }
    
    if (-not $wslShutDown) {
        Write-ColorOutput Red "[ERROR] Could not shut down WSL completely!"
        Write-Output ""
        
        # Show current status using wsl --list --verbose
        Write-ColorOutput Yellow "Current WSL status:"
        $statusOutput = wsl --list --verbose 2>$null
        if ($statusOutput) {
            Write-Output $statusOutput
            Write-Output ""
        }
        
        $vmmemProcs = Get-Process -Name "vmmem","vmmemWSL" -ErrorAction SilentlyContinue
        if ($vmmemProcs) {
            Write-ColorOutput Yellow "vmmem processes (WSL VMs still running):"
            foreach ($proc in $vmmemProcs) {
                Write-Output "  - $($proc.ProcessName) (PID: $($proc.Id))"
            }
            Write-Output ""
        }
        
        Write-ColorOutput Yellow "Please try manually:"
        Write-Output "  1. Close all terminal windows with WSL sessions"
        Write-Output "  2. Run: wsl --shutdown"
        Write-Output "  3. Run: Stop-Service -Name 'LxssManager' -Force"
        Write-Output "  4. Wait 30 seconds"
        Write-Output "  5. Verify: wsl --list --verbose (all should show 'Stopped')"
        Write-Output "  6. Run this script again"
        Write-Output ""
        Exit 1
    } else {
        Write-ColorOutput Green "[OK] WSL shutdown complete - all distributions are Stopped"
    }
    Write-Output ""
}

# Step 2: Find VHDX files if not provided
if (-not $VhdxFiles -or $VhdxFiles.Count -eq 0) {
    Write-ColorOutput Yellow "Finding VHDX files..."
    
    $vhdxLocations = @(
        "$env:LOCALAPPDATA\Packages",
        "$env:LOCALAPPDATA\Docker",
        "$env:USERPROFILE\AppData\Local\Packages",
        "$env:USERPROFILE\AppData\Local\Docker",
        "$env:ProgramData\Docker"
    )
    
    $allVhdxFiles = @()
    foreach ($location in $vhdxLocations) {
        if (Test-Path $location) {
            $files = Get-ChildItem -Path $location -Recurse -Filter "*.vhdx" -ErrorAction SilentlyContinue
            if ($files) {
                $allVhdxFiles += $files
            }
        }
    }
    
    # Also search in entire Docker directory if nothing found
    if ($allVhdxFiles.Count -eq 0) {
        $allVhdxFiles = Get-ChildItem -Path "$env:LOCALAPPDATA\Docker" -Recurse -Filter "*.vhdx" -ErrorAction SilentlyContinue
    }
    
    $VhdxFiles = $allVhdxFiles
}

if ($VhdxFiles.Count -eq 0) {
    Write-ColorOutput Red "[ERROR] No VHDX files found to compact!"
    Exit 1
}

Write-ColorOutput Green "Found $($VhdxFiles.Count) VHDX file(s) to compact"
Write-Output ""

# Function to ensure VHDX file is unlocked (defined before loop)
function Unlock-VhdxFile {
        param([string]$FilePath)
        
        Write-ColorOutput Yellow "  Ensuring VHDX file is unlocked..."
        
        # Wait a bit for any operations to complete
        Start-Sleep -Seconds 3
        
        # Kill any processes that might be locking the file
        $lockingProcesses = @("diskpart", "vmmem", "vmmemWSL", "wslhost")
        foreach ($procName in $lockingProcesses) {
            $procs = Get-Process -Name $procName -ErrorAction SilentlyContinue
            if ($procs) {
                foreach ($proc in $procs) {
                    try {
                        Stop-Process -Id $proc.Id -Force -ErrorAction Stop
                        Write-ColorOutput Yellow "    Killed: $procName (PID: $($proc.Id))"
                    } catch {
                        taskkill /PID $proc.Id /F 2>$null | Out-Null
                    }
                }
            }
        }
        
        # Try to detach the disk using DiskPart (in case it's still attached)
        # Try multiple times in case it's stubborn
        for ($detachAttempt = 1; $detachAttempt -le 3; $detachAttempt++) {
            $detachScript = @"
select vdisk file="$FilePath"
detach vdisk
exit
"@
            
            $tempFile = [System.IO.Path]::GetTempFileName()
            Set-Content -Path $tempFile -Value $detachScript -Encoding ASCII
            $detachResult = diskpart /s $tempFile 2>&1 | Out-String
            Remove-Item $tempFile
            
            if ($detachResult -match "successfully detached" -or $detachResult -match "not attached" -or $detachResult -match "not found") {
                Write-ColorOutput Yellow "    Disk detached (attempt $detachAttempt)"
                break
            } elseif ($detachResult -match "already attached" -or $detachResult -match "already in use") {
                Write-ColorOutput Yellow "    Disk still attached, retrying (attempt $detachAttempt/3)..."
                Start-Sleep -Seconds 3
            } else {
                # No error or different error, assume it worked
                break
            }
        }
        
        Start-Sleep -Seconds 2
        
        # Verify file is accessible (not locked)
        try {
            $testFile = [System.IO.File]::Open($FilePath, 'Open', 'Read', 'ReadWrite')
            $testFile.Close()
            Write-ColorOutput Green "    [OK] VHDX file is unlocked"
            return $true
        } catch {
            Write-ColorOutput Yellow "    [WARNING] File may still be locked, waiting..."
            Start-Sleep -Seconds 5
            return $false
        }
    }

# Step 3: Compact each VHDX file
$totalSpaceReclaimed = 0
$successCount = 0
$failCount = 0

foreach ($vhdx in $VhdxFiles) {
    $vhdxPath = $vhdx.FullName
    Write-ColorOutput Yellow "Compacting: $vhdxPath"
    
    $sizeBefore = $vhdx.Length / 1GB
    $sizeBeforeFormatted = "{0:N2}" -f $sizeBefore
    Write-ColorOutput Cyan "  Size before: $sizeBeforeFormatted GB"
    
    # First, ensure the VHDX is detached and unlocked BEFORE compaction
    Write-ColorOutput Yellow "  Preparing VHDX file (detaching if needed)..."
    Unlock-VhdxFile -FilePath $vhdxPath | Out-Null
    Start-Sleep -Seconds 2
    
    # Try Optimize-VHD first (more reliable)
    $compactionSuccess = $false
    try {
        Import-Module Hyper-V -ErrorAction Stop
        Write-ColorOutput Yellow "  Using Optimize-VHD (this may take several minutes)..."
        Optimize-VHD -Path $vhdxPath -Mode Full -ErrorAction Stop
        $compactionSuccess = $true
        Write-ColorOutput Green "  [OK] Optimize-VHD compaction complete"
        
        # Ensure file is unlocked after Optimize-VHD
        Unlock-VhdxFile -FilePath $vhdxPath | Out-Null
        
    } catch {
        Write-ColorOutput Yellow "  Optimize-VHD failed, trying DiskPart..."
        
        # Fallback to DiskPart
        # First, make sure disk is detached
        Write-ColorOutput Yellow "  Detaching disk before compaction..."
        $detachScript = @"
select vdisk file="$vhdxPath"
detach vdisk
exit
"@
        
        $tempFile = [System.IO.Path]::GetTempFileName()
        Set-Content -Path $tempFile -Value $detachScript -Encoding ASCII
        diskpart /s $tempFile 2>&1 | Out-Null
        Remove-Item $tempFile
        Start-Sleep -Seconds 2
        
        # Now try to compact
        $diskpartScript = @"
select vdisk file="$vhdxPath"
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
        
        # Check if compaction succeeded
        if ($diskpartResult -match "successfully compacted" -or $diskpartResult -match "100 percent completed") {
            $compactionSuccess = $true
            Write-ColorOutput Green "  [OK] DiskPart compaction complete"
        } elseif ($diskpartResult -match "already attached") {
            # Disk was still attached, try detaching and retry
            Write-ColorOutput Yellow "  Disk was still attached, detaching and retrying..."
            $detachScript = @"
select vdisk file="$vhdxPath"
detach vdisk
exit
"@
            $tempFile = [System.IO.Path]::GetTempFileName()
            Set-Content -Path $tempFile -Value $detachScript -Encoding ASCII
            diskpart /s $tempFile 2>&1 | Out-Null
            Remove-Item $tempFile
            Start-Sleep -Seconds 3
            
            # Retry compaction
            $tempFile = [System.IO.Path]::GetTempFileName()
            Set-Content -Path $tempFile -Value $diskpartScript -Encoding ASCII
            $diskpartResult = diskpart /s $tempFile 2>&1 | Out-String
            Remove-Item $tempFile
            
            if ($diskpartResult -match "successfully compacted" -or $diskpartResult -match "100 percent completed") {
                $compactionSuccess = $true
                Write-ColorOutput Green "  [OK] DiskPart compaction complete (after retry)"
            } else {
                Write-ColorOutput Red "  [ERROR] Compaction failed after retry"
                Write-ColorOutput Yellow "  DiskPart output: $diskpartResult"
            }
        } else {
            Write-ColorOutput Red "  [ERROR] Compaction failed"
            Write-ColorOutput Yellow "  DiskPart output: $diskpartResult"
        }
        
        # Ensure file is unlocked after DiskPart (double-check detach worked)
        if ($compactionSuccess) {
            $unlocked = Unlock-VhdxFile -FilePath $vhdxPath
            if (-not $unlocked) {
                Write-ColorOutput Yellow "  [WARNING] File may still be locked, but compaction succeeded"
            }
        } else {
            # Still try to unlock the file even if compaction failed
            Unlock-VhdxFile -FilePath $vhdxPath | Out-Null
        }
    }
    
    if ($compactionSuccess) {
        # Refresh file info
        Start-Sleep -Seconds 2
        $vhdxRefreshed = Get-Item $vhdxPath
        $sizeAfter = $vhdxRefreshed.Length / 1GB
        $spaceReclaimed = [math]::Round($sizeBefore - $sizeAfter, 2)
        $sizeAfterFormatted = "{0:N2}" -f $sizeAfter
        
        Write-ColorOutput Cyan "  Size after: $sizeAfterFormatted GB"
        if ($spaceReclaimed -gt 0) {
            Write-ColorOutput Green "  Space reclaimed: $spaceReclaimed GB"
            $totalSpaceReclaimed += $spaceReclaimed
        } else {
            Write-ColorOutput Yellow "  No space reclaimed (file may already be compacted)"
        }
        $successCount++
    } else {
        Write-ColorOutput Red "  [FAILED] Could not compact this file"
        $failCount++
    }
    Write-Output ""
}

# Step 4: Summary
Write-ColorOutput Green "=========================================="
Write-ColorOutput Green "Compaction Complete!"
Write-ColorOutput Green "=========================================="
Write-Output ""
Write-ColorOutput Cyan "Summary:"
Write-Output "  Files processed: $($VhdxFiles.Count)"
Write-Output "  Successful: $successCount"
Write-Output "  Failed: $failCount"
if ($totalSpaceReclaimed -gt 0) {
    Write-ColorOutput Green "  Total space reclaimed: $totalSpaceReclaimed GB"
} else {
    Write-ColorOutput Yellow "  No space reclaimed (files may already be compacted)"
}
Write-Output ""

# Step 5: Restart Docker Desktop and WSL
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

# Restart WSL service (if we stopped it)
Write-ColorOutput Yellow "Restarting WSL service..."
try {
    # Try WSLService first (common name)
    $wslService = Get-Service -Name "WSLService" -ErrorAction SilentlyContinue
    if (-not $wslService) {
        # Try LxssManager (alternative name)
        $wslService = Get-Service -Name "LxssManager" -ErrorAction SilentlyContinue
    }
    
    if ($wslService) {
        if ($wslService.Status -ne 'Running') {
            # Service is stopped, start it
            Start-Service -Name $wslService.Name -ErrorAction Stop
            Write-ColorOutput Green "  [OK] WSL service ($($wslService.Name)) started"
        } else {
            # Service is running, restart it to ensure clean state
            Restart-Service -Name $wslService.Name -Force -ErrorAction Stop
            Write-ColorOutput Green "  [OK] WSL service ($($wslService.Name)) restarted"
        }
        Start-Sleep -Seconds 3
    } else {
        Write-ColorOutput Yellow "  [WARNING] WSL service not found - WSL may not be properly installed"
    }
} catch {
    # Try using sc command as fallback
    sc start WSLService 2>$null | Out-Null
    sc start LxssManager 2>$null | Out-Null
    Start-Sleep -Seconds 2
}

# Wait a bit longer and ensure VHDX files are released
Write-ColorOutput Yellow "Waiting for VHDX files to be released..."
Start-Sleep -Seconds 5

# Kill any remaining vmmem processes that might be locking files
$vmmemProcs = Get-Process -Name "vmmem","vmmemWSL" -ErrorAction SilentlyContinue
if ($vmmemProcs) {
    Write-ColorOutput Yellow "  Killing remaining vmmem processes..."
    foreach ($proc in $vmmemProcs) {
        try {
            Stop-Process -Id $proc.Id -Force -ErrorAction Stop
        } catch {
            # Try taskkill as admin fallback
            taskkill /PID $proc.Id /F 2>$null | Out-Null
        }
    }
    Start-Sleep -Seconds 3
}

# Restart WSL (this will start the default distribution)
Write-ColorOutput Yellow "Starting WSL..."
try {
    wsl --distribution Ubuntu 2>$null | Out-Null
    Start-Sleep -Seconds 2
    Write-ColorOutput Green "[OK] WSL restarted"
} catch {
    Write-ColorOutput Yellow "[WARNING] Could not start WSL automatically"
    Write-ColorOutput Yellow "You may need to restart your computer or manually run: wsl"
}
Write-Output ""

Write-ColorOutput Green "All done! Check your disk space - it should be freed up now."
Write-Output ""


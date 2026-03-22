# Find Storage Hogs - Diagnostic Script
# This script finds ALL VHDX files and large Docker/WSL storage locations
# Run as Administrator

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
Write-ColorOutput Cyan "Storage Diagnostic Tool"
Write-ColorOutput Cyan "=========================================="
Write-Output ""

# Step 1: Find ALL VHDX files
Write-ColorOutput Yellow "Searching for ALL VHDX files..."
Write-Output ""

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
            if ($files -is [Array]) {
                $allVhdxFiles += $files
            } else {
                $allVhdxFiles += @($files)
            }
        }
    }
}

if ($allVhdxFiles.Count -eq 0) {
    Write-ColorOutput Red "[ERROR] No VHDX files found in standard locations!"
    Write-ColorOutput Yellow "Searching entire AppData directory..."
    $foundFiles = Get-ChildItem -Path "$env:LOCALAPPDATA" -Recurse -Filter "*.vhdx" -ErrorAction SilentlyContinue
    if ($foundFiles) {
        if ($foundFiles -is [Array]) {
            $allVhdxFiles = $foundFiles
        } else {
            $allVhdxFiles = @($foundFiles)
        }
    }
}

if ($allVhdxFiles.Count -gt 0) {
    Write-ColorOutput Green "Found $($allVhdxFiles.Count) VHDX file(s):"
    Write-Output ""
    
    $totalSize = 0
    foreach ($vhdx in $allVhdxFiles) {
        $sizeGB = [math]::Round($vhdx.Length / 1GB, 2)
        $totalSize += $sizeGB
        Write-ColorOutput Cyan "  File: $($vhdx.FullName)"
        Write-Output "     Size: $sizeGB GB"
        Write-Output ""
    }
    
    Write-ColorOutput Yellow "Total VHDX size: $totalSize GB"
    Write-Output ""
} else {
    Write-ColorOutput Red "[ERROR] No VHDX files found anywhere!"
    Write-Output ""
}

# Step 2: Check Docker storage
Write-ColorOutput Yellow "Checking Docker storage..."
Write-Output ""

$dockerAvailable = $false
try {
    docker info | Out-Null
    $dockerAvailable = $true
    Write-ColorOutput Green "[OK] Docker is running"
    
    Write-Output ""
    Write-ColorOutput Cyan "Docker disk usage:"
    docker system df
    
    Write-Output ""
    Write-ColorOutput Cyan "Docker images:"
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | Select-Object -First 20
    
} catch {
    Write-ColorOutput Yellow "[WARNING] Docker is not running or not accessible"
}

Write-Output ""

# Step 3: Find large Docker directories
Write-ColorOutput Yellow "Checking Docker directories..."
Write-Output ""

$dockerDirs = @(
    "$env:LOCALAPPDATA\Docker",
    "$env:USERPROFILE\AppData\Local\Docker",
    "$env:ProgramData\Docker"
)

foreach ($dir in $dockerDirs) {
    if (Test-Path $dir) {
        Write-ColorOutput Cyan "Checking: $dir"
        try {
            $size = (Get-ChildItem -Path $dir -Recurse -ErrorAction SilentlyContinue | 
                     Measure-Object -Property Length -Sum).Sum
            $sizeGB = [math]::Round($size / 1GB, 2)
            Write-Output "  Total size: $sizeGB GB"
            
            # Find largest subdirectories
            $subdirs = Get-ChildItem -Path $dir -Directory -ErrorAction SilentlyContinue | 
                       ForEach-Object {
                           $subSize = (Get-ChildItem -Path $_.FullName -Recurse -ErrorAction SilentlyContinue | 
                                      Measure-Object -Property Length -Sum).Sum
                           [PSCustomObject]@{
                               Path = $_.FullName
                               Size = $subSize
                           }
                       } | 
                       Sort-Object -Property Size -Descending | 
                       Select-Object -First 5
            
            if ($subdirs) {
                Write-Output "  Largest subdirectories:"
                foreach ($subdir in $subdirs) {
                    $subSizeGB = [math]::Round($subdir.Size / 1GB, 2)
                    Write-Output "    $([math]::Round($subSizeGB, 2)) GB - $($subdir.Path)"
                }
            }
        } catch {
            Write-Output "  (Could not calculate size)"
        }
        Write-Output ""
    }
}

# Step 4: Check WSL distributions
Write-ColorOutput Yellow "Checking WSL distributions..."
Write-Output ""

try {
    $wslDistros = wsl --list --verbose 2>$null
    if ($wslDistros) {
        Write-ColorOutput Cyan "WSL Distributions:"
        Write-Output $wslDistros
        Write-Output ""
    } else {
        Write-ColorOutput Yellow "[INFO] No WSL distributions found or WSL not accessible"
        Write-Output ""
    }
} catch {
    Write-ColorOutput Yellow "[WARNING] Could not query WSL"
    Write-Output ""
}

# Step 5: Summary and recommendations
Write-ColorOutput Green "=========================================="
Write-ColorOutput Green "Summary"
Write-ColorOutput Green "=========================================="
Write-Output ""
Write-ColorOutput Yellow "Recommendations:"
Write-Output ""
Write-Output "1. If VHDX files are large, they need to be compacted while WSL/Docker is SHUT DOWN"
Write-Output "2. Run this command to shut down WSL completely:"
Write-ColorOutput Cyan "   wsl --shutdown"
Write-Output ""
Write-Output "3. Then compact VHDX files using:"
Write-ColorOutput Cyan "   Optimize-VHD -Path <VHDX_PATH> -Mode Full"
Write-Output ""
Write-Output "4. For Docker Desktop VHDX, use DiskPart:"
Write-ColorOutput Cyan "   diskpart"
Write-Output "   select vdisk file=`"<VHDX_PATH>`""
Write-Output "   attach vdisk readonly"
Write-Output "   compact vdisk"
Write-Output "   detach vdisk"
Write-Output ""
Write-Output "5. After compaction, restart Docker Desktop and WSL"
Write-Output ""

# Step 6: Prompt user to run compaction automatically
if ($allVhdxFiles.Count -gt 0) {
    Write-ColorOutput Cyan "=========================================="
    Write-ColorOutput Cyan "Automatic Compaction Available"
    Write-ColorOutput Cyan "=========================================="
    Write-Output ""
    Write-ColorOutput Yellow "Would you like to compact the VHDX files now to reclaim disk space?"
    Write-Output ""
    Write-Output "This will:"
    Write-Output "  - Shut down WSL and Docker Desktop"
    Write-Output "  - Compact all $($allVhdxFiles.Count) VHDX file(s) found"
    Write-Output "  - Restart Docker Desktop and WSL"
    Write-Output ""
    Write-ColorOutput Yellow "WARNING: This requires Administrator privileges and will stop all WSL/Docker processes!"
    Write-Output ""
    
    $response = Read-Host "Run compaction now? (Y/N)"
    
    if ($response -eq 'Y' -or $response -eq 'y' -or $response -eq 'Yes' -or $response -eq 'yes') {
        Write-Output ""
        Write-ColorOutput Green "Starting automatic compaction..."
        Write-Output ""
        
        # Get the script directory
        $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
        $compactScript = Join-Path $scriptDir "compact-vhdx-files.ps1"
        
        if (Test-Path $compactScript) {
            # Check if running as Administrator
            $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
            
            if (-not $isAdmin) {
                Write-ColorOutput Red "[ERROR] Administrator privileges required for compaction!"
                Write-ColorOutput Yellow "Please run this script as Administrator, or run the compaction script manually:"
                Write-ColorOutput Cyan "   .\scripts\compact-vhdx-files.ps1"
                Write-Output ""
            } else {
                # Import and call the compaction script
                try {
                    & $compactScript -VhdxFiles $allVhdxFiles -AutoShutdown
                } catch {
                    Write-ColorOutput Red "[ERROR] Failed to run compaction script: $_"
                    Write-ColorOutput Yellow "You can run it manually:"
                    Write-ColorOutput Cyan "   .\scripts\compact-vhdx-files.ps1"
                }
            }
        } else {
            Write-ColorOutput Red "[ERROR] Compaction script not found at: $compactScript"
            Write-ColorOutput Yellow "Please ensure compact-vhdx-files.ps1 is in the scripts directory"
        }
    } else {
        Write-Output ""
        Write-ColorOutput Yellow "Compaction skipped. You can run it manually later:"
        Write-ColorOutput Cyan "   .\scripts\compact-vhdx-files.ps1"
        Write-Output ""
    }
} else {
    Write-ColorOutput Yellow "[INFO] No VHDX files found, so no compaction is needed."
    Write-Output ""
}


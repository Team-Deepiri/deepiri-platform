# Deepiri Docker Stop and Cleanup Script (PowerShell)
# This script stops all containers and cleans up Docker resources
# Usage: .\stop-and-cleanup.ps1 [-KeepVolumes] [-KeepImages]

param(
    [switch]$KeepVolumes,
    [switch]$KeepImages
)

# Colors for output
function Write-ColorOutput {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ForegroundColor,
        [Parameter(ValueFromRemainingArguments=$true)]
        [string[]]$Message
    )
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($Message) {
        Write-Output ($Message -join " ")
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

# Function to check if Docker is running
function Test-Docker {
    try {
        $null = docker info 2>&1
        return $true
    } catch {
        Write-ColorOutput Red "Error: Docker is not running or not accessible"
        exit 1
    }
}

# Function to stop all containers
function Stop-Containers {
    Write-ColorOutput Yellow "Stopping all Deepiri containers..."
    
    $containers = docker ps -a --filter "name=deepiri" --format "{{.Names}}" 2>&1
    
    if ([string]::IsNullOrWhiteSpace($containers)) {
        Write-ColorOutput Green "No Deepiri containers found"
    } else {
        $containerList = $containers -split "`n" | Where-Object { $_ -and $_.Trim() }
        foreach ($container in $containerList) {
            if ($container) {
                Write-Output "  Stopping: $container"
                $null = docker stop $container 2>&1
            }
        }
        
        # Also stop any containers started by docker-compose
        Write-ColorOutput Yellow "Stopping docker-compose services..."
        $null = docker-compose -f docker-compose.yml down 2>&1
        $null = docker-compose -f docker-compose.dev.yml down 2>&1
        $null = docker-compose -f docker-compose.microservices.yml down 2>&1
        $null = docker-compose -f docker-compose.enhanced.yml down 2>&1
        
        Write-ColorOutput Green "[OK] All containers stopped"
    }
}

# Function to remove containers
function Remove-Containers {
    Write-ColorOutput Yellow "Removing all Deepiri containers..."
    
    $containers = docker ps -a --filter "name=deepiri" --format "{{.Names}}" 2>&1
    
    if ([string]::IsNullOrWhiteSpace($containers)) {
        Write-ColorOutput Green "No Deepiri containers to remove"
    } else {
        $containerList = $containers -split "`n" | Where-Object { $_ -and $_.Trim() }
        foreach ($container in $containerList) {
            if ($container) {
                Write-Output "  Removing: $container"
                $null = docker rm -f $container 2>&1
            }
        }
        
        Write-ColorOutput Green "[OK] All containers removed"
    }
}

# Function to remove images
function Remove-Images {
    if ($KeepImages) {
        Write-ColorOutput Yellow "Skipping image removal (-KeepImages flag set)"
        return
    }
    
    Write-ColorOutput Yellow "Removing Deepiri images..."
    
    $images = docker images --filter "reference=*deepiri*" --format "{{.Repository}}:{{.Tag}}" 2>&1
    
    if ([string]::IsNullOrWhiteSpace($images)) {
        Write-ColorOutput Green "No Deepiri images found"
    } else {
        $imageList = $images -split "`n" | Where-Object { $_ -and $_.Trim() }
        foreach ($image in $imageList) {
            if ($image) {
                Write-Output "  Removing: $image"
                $null = docker rmi -f $image 2>&1
            }
        }
        
        Write-ColorOutput Green "[OK] Images removed"
    }
    
    # Also remove dangling images
    Write-ColorOutput Yellow "Removing dangling images..."
    $dangling = docker images -f "dangling=true" -q 2>&1
    if ($dangling -and $dangling.Trim()) {
        $null = docker rmi -f $dangling 2>&1
        Write-ColorOutput Green "[OK] Dangling images removed"
    } else {
        Write-ColorOutput Green "No dangling images found"
    }
}

# Function to remove volumes
function Remove-Volumes {
    if ($KeepVolumes) {
        Write-ColorOutput Yellow "Skipping volume removal (-KeepVolumes flag set)"
        return
    }
    
    Write-ColorOutput Yellow "Removing unused volumes..."
    
    $volumes = docker volume ls --filter "name=deepiri" --format "{{.Name}}" 2>&1
    
    if ([string]::IsNullOrWhiteSpace($volumes)) {
        Write-ColorOutput Green "No Deepiri volumes found"
    } else {
        $volumeList = $volumes -split "`n" | Where-Object { $_ -and $_.Trim() }
        foreach ($volume in $volumeList) {
            if ($volume) {
                Write-Output "  Removing: $volume"
                $null = docker volume rm $volume 2>&1
            }
        }
        
        Write-ColorOutput Green "[OK] Volumes removed"
    }
    
    # Remove all unused volumes
    Write-ColorOutput Yellow "Removing all unused volumes..."
    $null = docker volume prune -f 2>&1
    Write-ColorOutput Green "[OK] Unused volumes pruned"
}

# Function to clean build cache
function Clear-BuildCache {
    Write-ColorOutput Yellow "Cleaning Docker build cache..."
    $null = docker builder prune -af 2>&1
    Write-ColorOutput Green "[OK] Build cache cleaned"
}

# Function to remove networks
function Remove-Networks {
    Write-ColorOutput Yellow "Removing Deepiri networks..."
    
    $networks = docker network ls --filter "name=deepiri" --format "{{.Name}}" 2>&1
    
    if ([string]::IsNullOrWhiteSpace($networks)) {
        Write-ColorOutput Green "No Deepiri networks found"
    } else {
        $networkList = $networks -split "`n" | Where-Object { $_ -and $_.Trim() }
        foreach ($network in $networkList) {
            if ($network -and $network -ne "deepiri-network" -and $network -ne "deepiri-dev-network") {
                Write-Output "  Removing: $network"
                $null = docker network rm $network 2>&1
            }
        }
        
        # Remove the main networks if no containers are using them
        foreach ($network in @("deepiri-network", "deepiri-dev-network")) {
            try {
                $networkInfo = docker network inspect $network 2>&1
                if ($networkInfo -and -not ($networkInfo -match "Error")) {
                    $containers = docker network inspect $network --format '{{len .Containers}}' 2>&1
                    if ($containers -eq "0") {
                        Write-Output "  Removing: $network"
                        $null = docker network rm $network 2>&1
                    }
                }
            } catch {
                # Network doesn't exist, skip
            }
        }
        
        Write-ColorOutput Green "[OK] Networks removed"
    }
}

# Function to show disk usage
function Show-DiskUsage {
    Write-Output ""
    Write-ColorOutput Cyan "Docker Disk Usage:"
    docker system df
    Write-Output ""
}

# Main execution
function Main {
    Write-ColorOutput Cyan "========================================"
    Write-ColorOutput Cyan "Deepiri Docker Stop and Cleanup Script"
    Write-ColorOutput Cyan "========================================"
    Write-Output ""
    
    Test-Docker | Out-Null
    
    Write-ColorOutput Yellow "Current Docker disk usage:"
    Show-DiskUsage
    
    # Confirm before proceeding
    if (-not $KeepVolumes -or -not $KeepImages) {
        Write-ColorOutput Red "WARNING: This will remove Docker resources!"
        if (-not $KeepVolumes) {
            Write-ColorOutput Red "  - All volumes will be removed"
        }
        if (-not $KeepImages) {
            Write-ColorOutput Red "  - All images will be removed"
        }
        Write-ColorOutput Red "  - Build cache will be cleared"
        Write-Output ""
        $confirmation = Read-Host "Continue? (y/N)"
        if ($confirmation -ne "y" -and $confirmation -ne "Y") {
            Write-ColorOutput Yellow "Aborted"
            exit 0
        }
    }
    
    Write-Output ""
    
    # Execute cleanup steps
    Stop-Containers
    Remove-Containers
    Remove-Images
    Remove-Volumes
    Clear-BuildCache
    Remove-Networks
    
    Write-Output ""
    Write-ColorOutput Green "========================================"
    Write-ColorOutput Green "Cleanup Complete!"
    Write-ColorOutput Green "========================================"
    Write-Output ""
    
    Write-ColorOutput Yellow "Final Docker disk usage:"
    Show-DiskUsage
    
    Write-ColorOutput Green "All Deepiri Docker resources have been cleaned up!"
}

# Run main function
Main


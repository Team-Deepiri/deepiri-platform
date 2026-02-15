# Deepiri Clean Rebuild Script (PowerShell)
# Removes old images BEFORE rebuilding to prevent storage bloat
# Usage: .\rebuild-clean.ps1 [docker-compose-file] [-Service service-name]

param(
    [string]$ComposeFile = "docker-compose.dev.yml",
    [string]$Service = "",
    [switch]$NoCache
)

# Colors
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

Write-ColorOutput Cyan "========================================"
Write-ColorOutput Cyan "Deepiri Clean Rebuild Script"
Write-ColorOutput Cyan "========================================"
Write-Output ""

# Check Docker
try {
    docker info | Out-Null
} catch {
    Write-ColorOutput Red "❌ Docker is not running!"
    exit 1
}

# Show disk usage before
Write-ColorOutput Yellow "📊 Docker disk usage BEFORE:"
docker system df
Write-Output ""

# Step 1: Stop containers
Write-ColorOutput Yellow "[1/4] Stopping containers..."
Set-Location $PSScriptRoot
docker-compose -f $ComposeFile down 2>$null | Out-Null
Write-ColorOutput Green "✅ Containers stopped"
Write-Output ""

# Step 2: Remove old images (by name pattern)
Write-ColorOutput Yellow "[2/4] Removing old Deepiri images..."

# Get all images that match deepiri patterns
$allImages = docker images --format "{{.Repository}}:{{.Tag}} {{.ID}}" 2>$null

$removedCount = 0
if ($allImages) {
    $imageList = $allImages -split "`n" | Where-Object { $_ -and $_.Trim() }
    foreach ($imageLine in $imageList) {
        if ($imageLine) {
            $parts = $imageLine -split " "
            $imageName = $parts[0]
            $imageId = $parts[1]
            
            # Remove images that match deepiri patterns but skip base images
            if ($imageName -match "deepiri" -and 
                $imageName -notmatch "^(node|python|mongo|redis|influxdb|prometheus|grafana|mlflow|mongo-express|ghcr\.io)") {
                Write-Output "  Removing: $imageName"
                docker rmi -f $imageId 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    $removedCount++
                }
            }
        }
    }
}

# Also remove dangling images
Write-ColorOutput Yellow "  Removing dangling images..."
$dangling = docker images -f "dangling=true" -q 2>$null
if ($dangling) {
    docker rmi -f $dangling 2>$null | Out-Null
}

Write-ColorOutput Green "✅ Removed $removedCount old images"
Write-Output ""

# Step 3: Clean build cache
Write-ColorOutput Yellow "[3/4] Cleaning Docker build cache..."
docker builder prune -af 2>$null | Out-Null
Write-ColorOutput Green "✅ Build cache cleaned"
Write-Output ""

# Step 4: Rebuild
Write-ColorOutput Yellow "[4/4] Rebuilding containers..."
$buildArgs = @("-f", $ComposeFile, "build")

if ($NoCache) {
    $buildArgs += "--no-cache"
    Write-ColorOutput Cyan "  Using --no-cache flag"
}

if ($Service) {
    $buildArgs += $Service
    Write-ColorOutput Cyan "  Building service: $Service"
} else {
    Write-ColorOutput Cyan "  Building all services"
}

docker-compose $buildArgs

if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput Red "❌ Build failed!"
    exit 1
}

Write-ColorOutput Green "✅ Containers rebuilt"
Write-Output ""

# Clean build cache again after build
Write-ColorOutput Yellow "Cleaning build cache after build..."
docker builder prune -af 2>$null | Out-Null
Write-Output ""

# Show final disk usage
Write-ColorOutput Yellow "📊 Docker disk usage AFTER:"
docker system df
Write-Output ""

Write-ColorOutput Green "========================================"
Write-ColorOutput Green "✅ Clean Rebuild Complete!"
Write-ColorOutput Green "========================================"
Write-Output ""
Write-ColorOutput Cyan "To start services:"
Write-Output "  docker-compose -f $ComposeFile up -d"
Write-Output ""


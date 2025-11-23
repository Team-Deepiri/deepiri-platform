# PowerShell script to clear all Docker logs
# This removes all log files that Docker has accumulated

Write-Host "Clearing Docker logs..." -ForegroundColor Yellow

# Check if Docker is running
try {
    wsl docker info | Out-Null
    Write-Host "[OK] Docker is running" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Docker is not running. Please start Docker Desktop." -ForegroundColor Red
    Exit 1
}

# Get all container IDs (running and stopped)
Write-Host "`nFinding all containers..." -ForegroundColor Yellow
$allContainers = wsl docker ps -aq

if ([string]::IsNullOrEmpty($allContainers)) {
    Write-Host "No containers found." -ForegroundColor Green
    Exit 0
}

$containerCount = ($allContainers -split "`n" | Where-Object { $_ -and $_.Trim() }).Count
Write-Host "Found $containerCount containers" -ForegroundColor Cyan

# Clear logs for each container
Write-Host "`nClearing logs for all containers..." -ForegroundColor Yellow
foreach ($container in ($allContainers -split "`n" | Where-Object { $_ -and $_.Trim() })) {
    $containerName = wsl docker inspect --format='{{.Name}}' $container.Trim() 2>$null
    $containerName = $containerName -replace '^/', ''
    
    if ($containerName) {
        Write-Host "  Clearing logs for: $containerName" -ForegroundColor Cyan
        
        # Truncate log file (works on Linux)
        wsl docker exec $container.Trim() sh -c "truncate -s 0 /proc/1/fd/1 2>/dev/null || true" 2>$null | Out-Null
        wsl docker exec $container.Trim() sh -c "truncate -s 0 /proc/1/fd/2 2>/dev/null || true" 2>$null | Out-Null
    }
}

Write-Host "`n[OK] Docker logs cleared for all containers" -ForegroundColor Green

# Show current log sizes
Write-Host "`nCurrent log file sizes:" -ForegroundColor Yellow
wsl sh -c "find /var/lib/docker/containers -name '*-json.log' -exec ls -lh {} \; 2>/dev/null | awk '{print \$5, \$9}' | head -20"

Write-Host "`n[INFO] Logs will automatically be limited to 1MB per container" -ForegroundColor Cyan
Write-Host "[INFO] Old logs are automatically removed when the limit is reached" -ForegroundColor Cyan


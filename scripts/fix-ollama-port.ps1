# Fix Ollama port conflict
# Removes existing Ollama containers and checks for local Ollama installations

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Fixing Ollama Port Conflict" -ForegroundColor Cyan
Write-Host "=========================================="
Write-Host ""

# Check for existing Ollama containers
Write-Host "Checking for existing Ollama containers..." -ForegroundColor Yellow
$containers = wsl docker ps -a --filter "name=ollama" --format "{{.Names}}|{{.Status}}" 2>$null
if ($containers) {
    Write-Host "Found existing Ollama containers:" -ForegroundColor Yellow
    foreach ($container in $containers) {
        $parts = $container -split '\|'
        Write-Host "  - $($parts[0]): $($parts[1])" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "Removing existing Ollama containers..." -ForegroundColor Yellow
    wsl docker rm -f $(wsl docker ps -a --filter "name=ollama" -q) 2>$null
    Write-Host "[OK] Containers removed" -ForegroundColor Green
} else {
    Write-Host "[OK] No existing Ollama containers found" -ForegroundColor Green
}
Write-Host ""

# Check for local Ollama process
Write-Host "Checking for local Ollama installation..." -ForegroundColor Yellow
$ollamaProcess = Get-Process | Where-Object {$_.ProcessName -like "*ollama*"} -ErrorAction SilentlyContinue
if ($ollamaProcess) {
    Write-Host "Warning: Found local Ollama process:" -ForegroundColor Yellow
    $ollamaProcess | ForEach-Object {
        Write-Host "  - $($_.ProcessName) (PID: $($_.Id))" -ForegroundColor Yellow
        Write-Host "    Path: $($_.Path)" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Cyan
    Write-Host "  1. Stop local Ollama: Stop-Process -Id $($ollamaProcess.Id) -Force" -ForegroundColor White
    Write-Host "  2. Use different port: Set OLLAMA_PORT=11435 in .env file" -ForegroundColor White
    Write-Host "  3. Use local Ollama instead of Docker: Comment out ollama service in docker-compose.dev.yml" -ForegroundColor White
} else {
    Write-Host "[OK] No local Ollama process found" -ForegroundColor Green
}
Write-Host ""

# Check port 11434
Write-Host "Checking port 11434..." -ForegroundColor Yellow
$port11434 = Get-NetTCPConnection -LocalPort 11434 -ErrorAction SilentlyContinue
if ($port11434) {
    $proc = Get-Process -Id $port11434.OwningProcess -ErrorAction SilentlyContinue
    if ($proc) {
        if ($proc.ProcessName -eq "wslrelay") {
            Write-Host "Info: Port 11434 is forwarded by WSL (likely from a Docker container)" -ForegroundColor Cyan
            Write-Host "      This is normal if Docker containers are running" -ForegroundColor Gray
        } else {
            Write-Host "Warning: Port 11434 is in use by: $($proc.ProcessName) (PID: $($proc.Id))" -ForegroundColor Yellow
            Write-Host "         Path: $($proc.Path)" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "[OK] Port 11434 is available" -ForegroundColor Green
}
Write-Host ""

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "=========================================="
Write-Host ""
Write-Host "The docker-compose.dev.yml has been updated to use port 11435 externally" -ForegroundColor Green
Write-Host "by default (internal port 11434 remains the same)." -ForegroundColor Green
Write-Host ""
Write-Host "To start Ollama container:" -ForegroundColor Cyan
Write-Host "  docker compose -f docker-compose.dev.yml up -d ollama" -ForegroundColor White
Write-Host ""
Write-Host "Or use the updated port mapping:" -ForegroundColor Cyan
Write-Host "  Set OLLAMA_PORT=11435 in your .env file" -ForegroundColor White
Write-Host ""

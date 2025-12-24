param(
    [string]$ComposeFile = "c:\Users\jban9\Deepiri\deepiri-platform\docker-compose.dev.yml",
    [int]$Tail = 500
)

$outDir = Join-Path -Path (Split-Path $ComposeFile -Parent) -ChildPath 'logs'
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$outFile = Join-Path $outDir 'gateway-logs.txt'

Write-Host "Collecting logs from compose file: $ComposeFile" -ForegroundColor Cyan
try {
    docker compose -f $ComposeFile logs --no-color --tail $Tail api-gateway realtime-gateway 2>&1 | Tee-Object -FilePath $outFile -Encoding utf8
    Write-Host "Saved logs to: $outFile" -ForegroundColor Green
} catch {
    Write-Host "Failed to collect compose logs: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "Attempting per-container docker logs by container name..." -ForegroundColor Cyan

    $containers = @('deepiri-api-gateway-dev','deepiri-realtime-gateway-dev')
    foreach ($c in $containers) {
        try {
            Write-Host "\n--- Container: $c ---" -ForegroundColor Cyan
            docker logs --tail $Tail $c 2>&1 | Tee-Object -FilePath $outFile -Append -Encoding utf8
        } catch {
            Write-Host "  Container $c not found or logs not available: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    Write-Host "Logs (partial) saved to: $outFile" -ForegroundColor Yellow
}

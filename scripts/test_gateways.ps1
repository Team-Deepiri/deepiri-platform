param(
  [string]$ApiGateway = $(if ($env:API_GATEWAY_URL) { $env:API_GATEWAY_URL } else { 'http://localhost:5100' }),
  [string]$RealtimeGateway = $(if ($env:REALTIME_GATEWAY_URL) { $env:REALTIME_GATEWAY_URL } else { 'http://localhost:5008' })
)

$failed = $false

$endpoints = @(
  @{ name = 'api-gateway: /health'; url = "$ApiGateway/health" },
  @{ name = 'realtime-gateway: /health'; url = "$RealtimeGateway/health" }
)

Write-Host "Testing API Gateway: $ApiGateway"
Write-Host "Testing Realtime Gateway: $RealtimeGateway"

foreach ($ep in $endpoints) {
  Write-Host "`n--> GET $($ep.url)" -ForegroundColor Cyan
  try {
    $resp = Invoke-RestMethod -Uri $ep.url -Method Get -TimeoutSec 10 -ErrorAction Stop
    $json = $resp | ConvertTo-Json -Depth 5
    Write-Host "  ✅  $($ep.name) responded." -ForegroundColor Green
    Write-Host "  Response: $json"
  } catch {
    Write-Host "  ❌  $($ep.name) failed: $($_.Exception.Message)" -ForegroundColor Red
    $failed = $true
  }
}

if ($failed) {
  Write-Host "`nOne or more tests failed." -ForegroundColor Red
  exit 1
}

Write-Host "`nAll middleware health checks passed." -ForegroundColor Green
exit 0

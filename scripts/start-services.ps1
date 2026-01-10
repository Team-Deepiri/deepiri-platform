# Smart Docker Compose Startup Script
# Checks for port conflicts and cleans up failed containers before starting
# Usage: .\start-services.ps1 [--compose-file docker-compose.dev.yml] [--skip-checks]

param(
    [string]$ComposeFile = "docker-compose.dev.yml",
    [switch]$SkipChecks = $false
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

Write-ColorOutput Cyan "=========================================="
Write-ColorOutput Cyan "Smart Docker Services Startup"
Write-ColorOutput Cyan "=========================================="
Write-Output ""

# Get script directory and repo root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$ComposePath = Join-Path $RepoRoot $ComposeFile

if (-not (Test-Path $ComposePath)) {
    Write-ColorOutput Red "[ERROR] Compose file not found: $ComposePath"
    exit 1
}

if (-not $SkipChecks) {
    # Step 1: Check for failed containers (Created but not running)
    Write-ColorOutput Yellow "Step 1: Checking for failed containers..."
    $failedContainers = wsl docker ps -a --filter "status=created" --filter "name=deepiri" --format "{{.Names}}" 2>$null
    if ($failedContainers) {
        Write-ColorOutput Yellow "Found failed containers (Created but not running):"
        $failedContainers -split "`n" | Where-Object { $_ -and $_.Trim() } | ForEach-Object {
            Write-Output "  - $_"
        }
        Write-Output ""
        Write-ColorOutput Yellow "Removing failed containers..."
        $failedContainers -split "`n" | Where-Object { $_ -and $_.Trim() } | ForEach-Object {
            wsl docker rm -f $_ 2>$null | Out-Null
            Write-ColorOutput Green "  [OK] Removed $_"
        }
        Write-Output ""
    } else {
        Write-ColorOutput Green "[OK] No failed containers found"
        Write-Output ""
    }

    # Step 2: Check for port conflicts (excluding wslrelay)
    Write-ColorOutput Yellow "Step 2: Checking for port conflicts..."
    $portCheckScript = Join-Path $ScriptDir "check-port-conflicts.ps1"
    if (Test-Path $portCheckScript) {
        try {
            & $portCheckScript 2>&1 | Out-String | Write-Output
            if ($LASTEXITCODE -ne 0) {
                Write-ColorOutput Red "[ERROR] Port conflicts detected!"
                Write-Output ""
                Write-ColorOutput Yellow "Please resolve port conflicts before starting services."
                Write-ColorOutput Cyan "Run: .\check-port-conflicts.ps1 --kill"
                exit 1
            } else {
                Write-ColorOutput Green "[OK] No port conflicts detected"
            }
        } catch {
            Write-ColorOutput Yellow "[WARNING] Port check failed: $_"
            Write-ColorOutput Yellow "Continuing anyway..."
        }
        Write-Output ""
    } else {
        Write-ColorOutput Yellow "[WARNING] Port conflict checker not found, skipping port check"
        Write-Output ""
    }
} else {
    Write-ColorOutput Yellow "[SKIP] Pre-startup checks skipped (--skip-checks specified)"
    Write-Output ""
}

# Step 3: Start services
Write-ColorOutput Yellow "Step 3: Starting Docker services..."
Write-Output ""

Push-Location $RepoRoot
try {
    $startCmd = "docker compose -f `"$ComposeFile`" up -d"
    Write-ColorOutput Cyan "Executing: $startCmd"
    Write-Output ""
    
    Invoke-Expression $startCmd
    
    if ($LASTEXITCODE -eq 0) {
        Write-Output ""
        Write-ColorOutput Green "=========================================="
        Write-ColorOutput Green "Services started successfully!"
        Write-ColorOutput Green "=========================================="
        Write-Output ""
        Write-ColorOutput Cyan "To view logs:"
        Write-Output "  docker compose -f $ComposeFile logs -f"
        Write-Output ""
        Write-ColorOutput Cyan "To check status:"
        Write-Output "  docker compose -f $ComposeFile ps"
    } else {
        Write-ColorOutput Red "[ERROR] Failed to start services (exit code: $LASTEXITCODE)"
        Write-Output ""
        Write-ColorOutput Yellow "Troubleshooting:"
        Write-Output "  1. Check for port conflicts: .\check-port-conflicts.ps1"
        Write-Output "  2. Check Docker logs: docker compose -f $ComposeFile logs"
        Write-Output "  3. Try starting individual services: docker compose -f $ComposeFile up -d <service-name>"
        exit $LASTEXITCODE
    }
} finally {
    Pop-Location
}


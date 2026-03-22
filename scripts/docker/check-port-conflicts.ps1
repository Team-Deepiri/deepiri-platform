# Check and resolve port conflicts for Docker services
# Usage: .\check-port-conflicts.ps1 [--kill]

param(
    [switch]$Kill = $false
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
Write-ColorOutput Cyan "Docker Port Conflict Checker"
Write-ColorOutput Cyan "=========================================="
Write-Output ""

# Common ports used by Deepiri services
$ports = @{
    "11434" = "Ollama (Local LLM)"
    "5432" = "PostgreSQL"
    "6379" = "Redis"
    "6380" = "Redis (dev)"
    "8000" = "Cyrex API"
    "8080" = "Adminer"
    "8086" = "InfluxDB"
    "5100" = "API Gateway"
    "5173" = "Frontend"
    "5175" = "Cyrex Interface"
    "19530" = "Milvus"
    "9000" = "MinIO API"
    "9001" = "MinIO Console"
    "5500" = "MLflow"
    "8888" = "Jupyter"
}

$conflicts = @()

foreach ($port in $ports.Keys) {
    $serviceName = $ports[$port]
    
    # Check if port is in use
    $connection = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
    
    if ($connection) {
        $process = Get-Process -Id $connection.OwningProcess -ErrorAction SilentlyContinue
        $processName = if ($process) { $process.ProcessName } else { "Unknown" }
        
        # Ignore wslrelay - it's just WSL port forwarding (not a real conflict)
        if ($processName -eq "wslrelay") {
            # Check if there's actually a Docker container using this port
            $dockerContainer = docker ps --filter "publish=$port" --format "{{.Names}}" 2>$null
            if ($dockerContainer) {
                Write-ColorOutput Cyan "ℹ️  Port $port ($serviceName) is forwarded by WSL (Docker container: $dockerContainer)"
            } else {
                Write-ColorOutput Green "✅ Port $port ($serviceName) is forwarded by WSL (available for Docker)"
            }
            continue
        }
        
        # Check if it's a Docker container
        $dockerContainer = docker ps --filter "publish=$port" --format "{{.Names}}" 2>$null
        if ($dockerContainer) {
            Write-ColorOutput Cyan "ℹ️  Port $port ($serviceName) is in use by Docker container: $dockerContainer"
            continue
        }
        
        # Real conflict - non-Docker process using the port
        Write-ColorOutput Yellow "⚠️  Port $port ($serviceName) is in use by non-Docker process"
        Write-Output "    Process: $processName (PID: $($connection.OwningProcess))"
        Write-Output "    State: $($connection.State)"
        
        $conflicts += @{
            Port = $port
            Service = $serviceName
            ProcessId = $connection.OwningProcess
            ProcessName = $processName
        }
    } else {
        Write-ColorOutput Green "✅ Port $port ($serviceName) is available"
    }
}

Write-Output ""

if ($conflicts.Count -eq 0) {
    Write-ColorOutput Green "No port conflicts detected!"
    Write-Output ""
    Write-ColorOutput Cyan "Note: Ports showing 'wslrelay' are just WSL port forwarding - this is normal."
    Write-ColorOutput Cyan "      Docker containers in WSL2 use wslrelay to forward ports to Windows."
    exit 0
}

Write-ColorOutput Yellow "Found $($conflicts.Count) real port conflict(s) (non-Docker processes)"
Write-Output ""

if ($Kill) {
    Write-ColorOutput Yellow "Killing processes using conflicting ports..."
    $killedCount = 0
    foreach ($conflict in $conflicts) {
        try {
            $proc = Get-Process -Id $conflict.ProcessId -ErrorAction Stop
            Write-ColorOutput Yellow "  Killing $($conflict.ProcessName) (PID: $($conflict.ProcessId)) on port $($conflict.Port)..."
            Stop-Process -Id $conflict.ProcessId -Force -ErrorAction Stop
            Write-ColorOutput Green "    [OK] Process killed"
            $killedCount++
        } catch {
            Write-ColorOutput Red "    [ERROR] Could not kill process: $_"
        }
    }
    Write-Output ""
    if ($killedCount -eq $conflicts.Count) {
        Write-ColorOutput Green "Port conflicts resolved. You can now start Docker services."
        exit 0
    } else {
        Write-ColorOutput Yellow "Some conflicts could not be resolved automatically."
        exit 1
    }
} else {
    Write-ColorOutput Cyan "To automatically kill conflicting processes, run:"
    Write-Output "  .\check-port-conflicts.ps1 --kill"
    Write-Output ""
    Write-ColorOutput Cyan "Or manually kill processes:"
    foreach ($conflict in $conflicts) {
        Write-Output "  Stop-Process -Id $($conflict.ProcessId) -Force  # $($conflict.Service) on port $($conflict.Port)"
    }
    Write-Output ""
    Write-ColorOutput Yellow "Note: If you see 'wslrelay' processes, those are just WSL port forwarding."
    Write-ColorOutput Yellow "      They're not conflicts - Docker containers use them to forward ports."
    exit 1
}


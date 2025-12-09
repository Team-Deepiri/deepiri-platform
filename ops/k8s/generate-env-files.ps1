# Script to generate .env files from Kubernetes ConfigMaps and Secrets
# This allows docker-compose to use the same configuration as Kubernetes

$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_ROOT = Split-Path -Parent (Split-Path -Parent $SCRIPT_DIR)
$ENV_DIR = Join-Path $PROJECT_ROOT ".env-k8s"

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  Syncing K8s ConfigMaps & Secrets → Docker Compose .env   ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

# Create .env-k8s directory if it doesn't exist
if (-not (Test-Path $ENV_DIR)) {
    New-Item -ItemType Directory -Path $ENV_DIR | Out-Null
}

# Function to extract data from ConfigMap YAML
function Extract-ConfigMap {
    param (
        [string]$ConfigMapFile,
        [string]$OutputFile
    )
    
    if (-not (Test-Path $ConfigMapFile)) {
        Write-Host "⚠️  ConfigMap file not found: $ConfigMapFile" -ForegroundColor Yellow
        return $false
    }
    
    $content = Get-Content $ConfigMapFile -Raw
    $lines = $content -split "`n"
    
    $inDataSection = $false
    $envVars = @()
    
    foreach ($line in $lines) {
        if ($line -match "^data:") {
            $inDataSection = $true
            continue
        }
        if ($inDataSection -and $line -match "^[^ ]") {
            $inDataSection = $false
        }
        if ($inDataSection -and $line -match '^\s{2}([A-Z_]+):\s*"?(.+?)"?\s*$') {
            $key = $matches[1]
            $value = $matches[2].Trim('"')
            $envVars += "$key=$value"
        }
    }
    
    $envVars | Out-File -FilePath $OutputFile -Encoding utf8
    return $true
}

# Function to extract ALL secrets from the shared secrets.yaml file
function Extract-SharedSecrets {
    param (
        [string]$OutputFile
    )
    
    $secretFile = Join-Path $SCRIPT_DIR "secrets\secrets.yaml"
    
    if (-not (Test-Path $secretFile)) {
        Write-Host "⚠️  Shared secrets file not found: $secretFile" -ForegroundColor Yellow
        return $false
    }
    
    $content = Get-Content $secretFile -Raw
    $lines = $content -split "`n"
    
    $inStringDataSection = $false
    $envVars = @()
    
    foreach ($line in $lines) {
        if ($line -match "^stringData:") {
            $inStringDataSection = $true
            continue
        }
        if ($inStringDataSection -and $line -match "^[^ ]") {
            $inStringDataSection = $false
        }
        if ($inStringDataSection -and $line -match '^\s{2}([A-Z_]+):\s*"?(.+?)"?\s*$') {
            $key = $matches[1]
            $value = $matches[2].Trim('"')
            $envVars += "$key=$value"
        }
    }
    
    $envVars | Out-File -FilePath $OutputFile -Append -Encoding utf8
    return $true
}

# List of services
$SERVICES = @(
    "api-gateway",
    "auth-service",
    "task-orchestrator",
    "engagement-service",
    "platform-analytics-service",
    "notification-service",
    "external-bridge-service",
    "challenge-service",
    "realtime-gateway",
    "cyrex",
    "frontend-dev"
)

# Generate .env files for each service
foreach ($service in $SERVICES) {
    $configMapFile = Join-Path $SCRIPT_DIR "configmaps\$service-configmap.yaml"
    $envFile = Join-Path $ENV_DIR "$service.env"
    
    Write-Host "📦 $service" -ForegroundColor Green
    
    # Start with ConfigMap (public vars)
    if (Test-Path $configMapFile) {
        Extract-ConfigMap -ConfigMapFile $configMapFile -OutputFile $envFile
        Write-Host "   ✓ ConfigMap synced" -ForegroundColor Gray
    } else {
        Write-Host "   ⚠️  No ConfigMap found" -ForegroundColor Yellow
        New-Item -ItemType File -Path $envFile -Force | Out-Null
    }
    
    # Append shared secrets (all services get all secrets - they use what they need)
    Extract-SharedSecrets -OutputFile $envFile
    Write-Host "   ✓ Secrets synced" -ForegroundColor Gray
    
    # Count variables
    if (Test-Path $envFile) {
        $varCount = (Get-Content $envFile | Where-Object { $_ -match "=" }).Count
        Write-Host "   → $varCount variables" -ForegroundColor Green
    }
    Write-Host ""
}

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  ✓ Sync Complete: $ENV_DIR" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "💡 Tip: Run this script whenever you update k8s configmaps/secrets" -ForegroundColor Yellow
Write-Host "💡 Tip: Add to git hooks for automatic sync" -ForegroundColor Yellow
Write-Host ""


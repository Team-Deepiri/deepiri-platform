# Script to generate .env files from Kubernetes ConfigMaps and Secrets
# Cloud portal services only — see configmaps/README.md

$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_ROOT = Split-Path -Parent (Split-Path -Parent $SCRIPT_DIR)
$ENV_DIR = Join-Path $PROJECT_ROOT ".env-k8s"

Write-Host "Syncing cloud-portal K8s ConfigMaps & Secrets -> .env-k8s" -ForegroundColor Green

if (-not (Test-Path $ENV_DIR)) {
    New-Item -ItemType Directory -Path $ENV_DIR | Out-Null
}

function Extract-ConfigMap {
    param ([string]$ConfigMapFile, [string]$OutputFile)
    if (-not (Test-Path $ConfigMapFile)) { return $false }
    $content = Get-Content $ConfigMapFile -Raw
    $lines = $content -split "`n"
    $inDataSection = $false
    $envVars = @()
    foreach ($line in $lines) {
        if ($line -match "^data:") { $inDataSection = $true; continue }
        if ($inDataSection -and $line -match "^[^ ]") { $inDataSection = $false }
        if ($inDataSection -and $line -match '^\s{2}([A-Z_]+):\s*"?(.+?)"?\s*$') {
            $envVars += "$($matches[1])=$($matches[2].Trim('"'))"
        }
    }
    $envVars | Out-File -FilePath $OutputFile -Encoding utf8
    return $true
}

function Extract-ServiceSecrets {
    param ([string]$Service, [string]$OutputFile)
    $secretFile = Join-Path $SCRIPT_DIR "secrets\$Service-secret.yaml"
    if (-not (Test-Path $secretFile)) { return $false }
    $content = Get-Content $secretFile -Raw
    $lines = $content -split "`n"
    $inSection = $false
    $envVars = @()
    foreach ($line in $lines) {
        if ($line -match "^stringData:") { $inSection = $true; continue }
        if ($inSection -and $line -match "^[^ ]") { $inSection = $false }
        if ($inSection -and $line -match '^\s{2}([A-Z_]+):\s*"?(.+?)"?\s*$') {
            $envVars += "$($matches[1])=$($matches[2].Trim('"'))"
        }
    }
    $envVars | Out-File -FilePath $OutputFile -Append -Encoding utf8
    return $true
}

$CLOUD_SERVICES = @(
    "api-gateway",
    "auth-service",
    "registry",
    "external-bridge-service",
    "jobs",
    "platform-frontend"
)

foreach ($service in $CLOUD_SERVICES) {
    $configMapFile = Join-Path $SCRIPT_DIR "configmaps\$service-configmap.yaml"
    $envFile = Join-Path $ENV_DIR "$service.env"
    Write-Host "  $service" -ForegroundColor Green
    if (Test-Path $configMapFile) {
        Extract-ConfigMap -ConfigMapFile $configMapFile -OutputFile $envFile
    } else {
        New-Item -ItemType File -Path $envFile -Force | Out-Null
    }
    Extract-ServiceSecrets -Service $service -OutputFile $envFile
}

Write-Host "Done: $ENV_DIR" -ForegroundColor Green

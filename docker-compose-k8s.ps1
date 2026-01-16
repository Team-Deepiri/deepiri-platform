# Wrapper script to run docker-compose with k8s configmaps and secrets
# Usage: .\docker-compose-k8s.ps1 [compose-file] [command]
# Example: .\docker-compose-k8s.ps1 -f docker-compose.backend-team.yml up -d

param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$DockerComposeArgs
)

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$K8S_DIR = Join-Path $SCRIPT_DIR "ops\k8s"

# Function to extract env vars from k8s YAML and set them
function Load-K8sEnv {
    param([string]$YamlFile)
    
    if (-not (Test-Path $YamlFile)) {
        return
    }
    
    $content = Get-Content $YamlFile -Raw
    $lines = $content -split "`n"
    
    $inDataSection = $false
    
    foreach ($line in $lines) {
        if ($line -match "^(data|stringData):") {
            $inDataSection = $true
            continue
        }
        if ($inDataSection -and $line -match "^[^ ]") {
            $inDataSection = $false
        }
        if ($inDataSection -and $line -match '^\s{2}([A-Z_]+):\s*"?(.+?)"?\s*$') {
            $key = $matches[1]
            $value = $matches[2].Trim('"')
            [Environment]::SetEnvironmentVariable($key, $value, "Process")
        }
    }
}

# Load all configmaps
Get-ChildItem -Path (Join-Path $K8S_DIR "configmaps\*.yaml") -ErrorAction SilentlyContinue | ForEach-Object {
    Load-K8sEnv -YamlFile $_.FullName
}

# Load all secrets
Get-ChildItem -Path (Join-Path $K8S_DIR "secrets\*.yaml") -ErrorAction SilentlyContinue | ForEach-Object {
    Load-K8sEnv -YamlFile $_.FullName
}

# Run docker-compose with all arguments passed through
& docker-compose $DockerComposeArgs


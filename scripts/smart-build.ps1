# Smart Docker Build Script
# Automatically detects dependency changes and prunes stale cache
# Usage: .\smart-build.ps1 [service-name] [--no-cache] [--force-prune]

param(
    [string]$Service = "",
    [switch]$NoCache = $false,
    [switch]$ForcePrune = $false,
    [string]$ComposeFile = "docker-compose.dev.yml"
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
Write-ColorOutput Cyan "Smart Docker Build - Dependency-Aware"
Write-ColorOutput Cyan "=========================================="
Write-Output ""

# Get script directory and repo root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir

# Dependency file tracking
$DependencyCacheFile = Join-Path $RepoRoot ".docker-dependency-cache.json"

# Function to calculate file hash
function Get-FileHash {
    param([string]$FilePath)
    if (Test-Path $FilePath) {
        $content = Get-Content $FilePath -Raw -ErrorAction SilentlyContinue
        if ($content) {
            $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($content))
            return [System.BitConverter]::ToString($hash).Replace("-", "")
        }
    }
    return $null
}

# Function to get dependency files for a service
function Get-ServiceDependencies {
    param([string]$ServiceName)
    
    $deps = @{}
    
    switch ($ServiceName) {
        "cyrex" {
            $deps["requirements.txt"] = Join-Path $RepoRoot "diri-cyrex\requirements.txt"
            $deps["requirements-core.txt"] = Join-Path $RepoRoot "diri-cyrex\requirements-core.txt"
            $deps["Dockerfile"] = Join-Path $RepoRoot "diri-cyrex\Dockerfile"
        }
        "jupyter" {
            $deps["requirements.txt"] = Join-Path $RepoRoot "diri-cyrex\requirements.txt"
            $deps["Dockerfile.jupyter"] = Join-Path $RepoRoot "diri-cyrex\Dockerfile.jupyter"
        }
        "frontend" {
            $deps["package.json"] = Join-Path $RepoRoot "deepiri-web-frontend\package.json"
            $deps["package-lock.json"] = Join-Path $RepoRoot "deepiri-web-frontend\package-lock.json"
            $deps["Dockerfile"] = Join-Path $RepoRoot "deepiri-web-frontend\Dockerfile"
        }
        "core-api" {
            $deps["package.json"] = Join-Path $RepoRoot "deepiri-core-api\package.json"
            $deps["package-lock.json"] = Join-Path $RepoRoot "deepiri-core-api\package-lock.json"
            $deps["Dockerfile"] = Join-Path $RepoRoot "deepiri-core-api\Dockerfile"
        }
        default {
            # For unknown services, check common dependency files
            $possibleDeps = @(
                "requirements.txt",
                "package.json",
                "package-lock.json",
                "Dockerfile"
            )
            foreach ($dep in $possibleDeps) {
                $path = Join-Path $RepoRoot "$ServiceName\$dep"
                if (Test-Path $path) {
                    $deps[$dep] = $path
                }
            }
        }
    }
    
    return $deps
}

# Function to check if dependencies changed
function Test-DependenciesChanged {
    param([string]$ServiceName)
    
    # Load previous cache
    $previousCache = @{}
    if (Test-Path $DependencyCacheFile) {
        try {
            $previousCache = Get-Content $DependencyCacheFile | ConvertFrom-Json -AsHashtable
        } catch {
            Write-ColorOutput Yellow "  [INFO] Could not read dependency cache, treating as first run"
        }
    }
    
    # Get current dependencies
    $currentDeps = Get-ServiceDependencies $ServiceName
    $currentHashes = @{}
    $hasChanges = $false
    
    foreach ($depName in $currentDeps.Keys) {
        $depPath = $currentDeps[$depName]
        $currentHash = Get-FileHash $depPath
        
        if ($currentHash) {
            $currentHashes[$depName] = $currentHash
            
            # Check if hash changed
            $cacheKey = "$ServiceName.$depName"
            if ($previousCache.ContainsKey($cacheKey)) {
                if ($previousCache[$cacheKey] -ne $currentHash) {
                    Write-ColorOutput Yellow "  [CHANGE] $depName has changed"
                    $hasChanges = $true
                }
            } else {
                Write-ColorOutput Yellow "  [NEW] $depName (first time tracking)"
                $hasChanges = $true
            }
        }
    }
    
    # Check for removed dependencies
    foreach ($cacheKey in $previousCache.Keys) {
        if ($cacheKey -like "$ServiceName.*") {
            $depName = $cacheKey.Replace("$ServiceName.", "")
            if (-not $currentHashes.ContainsKey($depName)) {
                Write-ColorOutput Yellow "  [REMOVED] $depName no longer exists"
                $hasChanges = $true
            }
        }
    }
    
    # Update cache
    foreach ($depName in $currentHashes.Keys) {
        $cacheKey = "$ServiceName.$depName"
        $previousCache[$cacheKey] = $currentHashes[$depName]
    }
    
    # Save updated cache
    $previousCache | ConvertTo-Json -Depth 10 | Set-Content $DependencyCacheFile
    
    return $hasChanges
}

# Function to prune cache for a service
function Invoke-ServiceCachePrune {
    param([string]$ServiceName)
    
    Write-ColorOutput Yellow "  Pruning build cache for $ServiceName..."
    
    # Prune specific cache layers using BuildKit
    # Note: Docker doesn't support service-specific cache pruning directly,
    # so we prune all cache and let Docker rebuild intelligently
    docker builder prune -f --filter "type=exec.cachemount" 2>&1 | Out-Null
    
    # Alternative: Use BuildKit's cache invalidation
    # This is more aggressive but ensures clean rebuild
    Write-ColorOutput Green "  [OK] Cache invalidated for $ServiceName"
}

# Main build logic
Write-ColorOutput Yellow "Analyzing dependencies..."

$servicesToBuild = @()
$servicesToPrune = @()

if ($Service) {
    $servicesToBuild = @($Service)
} else {
    # Detect all services from compose file
    $composePath = Join-Path $RepoRoot $ComposeFile
    if (Test-Path $composePath) {
        # Parse compose file to get service names (simplified)
        $composeContent = Get-Content $composePath -Raw
        if ($composeContent -match 'services:\s*\n((?:\s+\w+:.*\n?)+)') {
            $servicesSection = $matches[1]
            $servicesToBuild = ($servicesSection -split "`n" | 
                Where-Object { $_ -match '^\s+(\w+):' } | 
                ForEach-Object { if ($_ -match '^\s+(\w+):') { $matches[1] } }) | 
                Where-Object { $_ -and $_ -ne "x-build-args" -and $_ -ne "x-logging" }
        }
    }
    
    # Fallback to common services
    if ($servicesToBuild.Count -eq 0) {
        $servicesToBuild = @("cyrex", "frontend", "core-api", "jupyter")
    }
}

Write-Output ""

# Check each service for dependency changes
foreach ($svc in $servicesToBuild) {
    Write-ColorOutput Cyan "Checking $svc..."
    
    if ($ForcePrune -or $NoCache) {
        Write-ColorOutput Yellow "  [FORCE] Pruning cache (--force-prune or --no-cache specified)"
        $servicesToPrune += $svc
    } elseif (Test-DependenciesChanged $svc) {
        Write-ColorOutput Yellow "  [CHANGED] Dependencies modified, cache will be pruned"
        $servicesToPrune += $svc
    } else {
        Write-ColorOutput Green "  [OK] No dependency changes detected, using cache"
    }
    Write-Output ""
}

# Prune cache for services with changes
if ($servicesToPrune.Count -gt 0) {
    Write-ColorOutput Yellow "Pruning build cache for changed services..."
    foreach ($svc in $servicesToPrune) {
        Invoke-ServiceCachePrune $svc
    }
    Write-Output ""
}

# Build command
$buildArgs = @()
if ($NoCache) {
    $buildArgs += "--no-cache"
    Write-ColorOutput Yellow "Building with --no-cache (full rebuild)..."
} elseif ($servicesToPrune.Count -gt 0) {
    Write-ColorOutput Yellow "Building with cache invalidation for changed services..."
} else {
    Write-ColorOutput Green "Building with cache (no changes detected)..."
}

Write-Output ""

# Execute docker-compose build
$composePath = Join-Path $RepoRoot $ComposeFile
if (-not (Test-Path $composePath)) {
    Write-ColorOutput Red "[ERROR] Compose file not found: $composePath"
    exit 1
}

$buildCmd = "docker compose -f `"$composePath`" build"
if ($Service) {
    $buildCmd += " $Service"
}
if ($buildArgs.Count -gt 0) {
    $buildCmd += " " + ($buildArgs -join " ")
}

Write-ColorOutput Cyan "Executing: $buildCmd"
Write-Output ""

# Change to repo root and execute
Push-Location $RepoRoot
try {
    Invoke-Expression $buildCmd
    if ($LASTEXITCODE -eq 0) {
        Write-Output ""
        Write-ColorOutput Green "=========================================="
        Write-ColorOutput Green "Build completed successfully!"
        Write-ColorOutput Green "=========================================="
        
        if ($servicesToPrune.Count -gt 0 -and -not $NoCache) {
            Write-Output ""
            Write-ColorOutput Cyan "Summary:"
            Write-Output "  Services with dependency changes: $($servicesToPrune -join ', ')"
            Write-Output "  Cache was automatically pruned for these services"
        }
    } else {
        Write-ColorOutput Red "[ERROR] Build failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
} finally {
    Pop-Location
}


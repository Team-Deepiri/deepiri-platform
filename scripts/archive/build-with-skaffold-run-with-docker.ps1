# Hybrid workflow: Build with Skaffold, Run with Docker Compose
# This gives you the best of both worlds:
# - Skaffold builds using Minikube's Docker daemon (consistent with K8s)
# - Docker Compose runs containers (fastest startup)

Write-Host "🔨 Hybrid Workflow: Build with Skaffold, Run with Docker Compose" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check prerequisites
Write-Host "📋 Step 1: Checking prerequisites..." -ForegroundColor Cyan

# Check kubectl
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host "❌ kubectl is not installed." -ForegroundColor Red
    Write-Host "   Please install kubectl first:" -ForegroundColor Yellow
    Write-Host "   curl -LO `"https://dl.k8s.io/release/`$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl`"" -ForegroundColor Yellow
    Write-Host "   sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "✅ kubectl is installed" -ForegroundColor Green
    kubectl version --client
}

# Check Minikube
if (-not (Get-Command minikube -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Minikube is not installed. Please install it first." -ForegroundColor Red
    exit 1
}

# Check if Minikube is running
$minikubeStatus = minikube status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️  Minikube is not running. Starting Minikube..." -ForegroundColor Yellow
    minikube start --driver=docker --cpus=4 --memory=8192
} else {
    Write-Host "✅ Minikube is running" -ForegroundColor Green
    minikube status
}

# Check Skaffold
if (-not (Get-Command skaffold -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Skaffold is not installed. Please install it first." -ForegroundColor Red
    exit 1
}

# Check Docker Compose
$composeCmd = $null
if (Get-Command docker -ErrorAction SilentlyContinue) {
    $dockerCompose = docker compose version 2>&1
    if ($LASTEXITCODE -eq 0) {
        $composeCmd = "docker compose"
    } else {
        if (Get-Command docker-compose -ErrorAction SilentlyContinue) {
            $composeCmd = "docker-compose"
        }
    }
}

if (-not $composeCmd) {
    Write-Host "❌ Docker Compose is not installed. Please install it first." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ All prerequisites met!" -ForegroundColor Green
Write-Host ""

# Step 2: Configure Docker to use Minikube's Docker daemon
Write-Host "📋 Step 2: Configuring Docker to use Minikube's Docker daemon..." -ForegroundColor Cyan
$dockerEnv = minikube docker-env
Invoke-Expression $dockerEnv

# Verify Docker is pointing to Minikube
try {
    docker ps | Out-Null
    Write-Host "✅ Docker is using Minikube's Docker daemon" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker is not accessible after switching to Minikube's Docker daemon." -ForegroundColor Red
    Write-Host "   Try running: minikube start" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Step 3: Build with Skaffold
Write-Host "📋 Step 3: Building images with Skaffold..." -ForegroundColor Cyan
Write-Host "   This builds images in Minikube's Docker daemon (consistent with K8s)" -ForegroundColor Yellow
Write-Host "   Using 'dev-compose' profile to build images with Docker Compose naming" -ForegroundColor Yellow
Write-Host ""

$configFile = "skaffold-local.yaml"
if (-not (Test-Path $configFile)) {
    Write-Host "⚠️  $configFile not found, falling back to skaffold.yaml" -ForegroundColor Yellow
    $configFile = "skaffold.yaml"
}

# Use dev-compose profile to build images with names Docker Compose expects
skaffold build -f $configFile -p dev-compose

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Skaffold build failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ Images built successfully!" -ForegroundColor Green
Write-Host ""

# Step 3.5: Tag images for Docker Compose compatibility
Write-Host "📋 Step 3.5: Tagging images for Docker Compose compatibility..." -ForegroundColor Cyan
Write-Host "   Skaffold builds images in Minikube's Docker daemon" -ForegroundColor Yellow
Write-Host "   Tagging them so Docker Compose can use them" -ForegroundColor Yellow
Write-Host ""

# Tag images: Skaffold name -> Docker Compose name
$tagMappings = @(
    @{Source="deepiri-cyrex:latest"; Target="deepiri-dev-cyrex:latest"}
    @{Source="deepiri-frontend:latest"; Target="deepiri-dev-frontend:latest"}
    @{Source="deepiri-api-gateway:latest"; Target="deepiri-dev-api-gateway:latest"}
    @{Source="deepiri-auth-service:latest"; Target="deepiri-dev-auth-service:latest"}
    @{Source="deepiri-task-orchestrator:latest"; Target="deepiri-dev-task-orchestrator:latest"}
    @{Source="deepiri-challenge-service:latest"; Target="deepiri-dev-challenge-service:latest"}
    @{Source="deepiri-engagement-service:latest"; Target="deepiri-dev-engagement-service:latest"}
    @{Source="deepiri-platform-analytics-service:latest"; Target="deepiri-dev-platform-analytics-service:latest"}
    @{Source="deepiri-external-bridge-service:latest"; Target="deepiri-dev-external-bridge-service:latest"}
    @{Source="deepiri-notification-service:latest"; Target="deepiri-dev-notification-service:latest"}
    @{Source="deepiri-realtime-gateway:latest"; Target="deepiri-dev-realtime-gateway:latest"}
)

$taggedCount = 0
foreach ($mapping in $tagMappings) {
    $source = $mapping.Source
    $target = $mapping.Target
    
    # Check if source image exists
    $imageExists = docker images --format "{{.Repository}}:{{.Tag}}" | Select-String -Pattern "^$source$"
    if ($imageExists) {
        docker tag $source $target 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   ✅ Tagged: $source -> $target" -ForegroundColor Green
            $taggedCount++
        } else {
            Write-Host "   ⚠️  Could not tag: $source" -ForegroundColor Yellow
        }
    } else {
        # Try without :latest
        $sourceNoTag = $source -replace ':latest$', ''
        $images = docker images --format "{{.Repository}}:{{.Tag}}" | Select-String -Pattern "^$sourceNoTag"
        if ($images) {
            $actualTag = $images[0].Line
            docker tag $actualTag $target 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "   ✅ Tagged: $actualTag -> $target" -ForegroundColor Green
                $taggedCount++
            }
        }
    }
}

if ($taggedCount -gt 0) {
    Write-Host "   ✅ Tagged $taggedCount images for Docker Compose" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  No images tagged (checking available images)..." -ForegroundColor Yellow
    Write-Host "   Available images:" -ForegroundColor Yellow
    docker images --format "  - {{.Repository}}:{{.Tag}}" | Select-String "deepiri" | Select-Object -First 10
}

Write-Host ""

# Step 4: Keep using Minikube's Docker daemon (images are already there!)
Write-Host "📋 Step 4: Keeping Docker pointing to Minikube's Docker daemon..." -ForegroundColor Cyan
Write-Host "   This allows Docker Compose to use the images Skaffold just built" -ForegroundColor Yellow
Write-Host "   (No need to switch - images are already in Minikube's Docker)" -ForegroundColor Yellow
Write-Host ""

# Verify Docker is still accessible
try {
    docker ps | Out-Null
    Write-Host "✅ Docker is using Minikube's Docker daemon (images available)" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Warning: Docker is not accessible. Reconfiguring..." -ForegroundColor Yellow
    $dockerEnv = minikube docker-env
    Invoke-Expression $dockerEnv
}

Write-Host ""

# Step 5: Run with Docker Compose (fastest!)
Write-Host "📋 Step 5: Starting services with Docker Compose (fastest!)..." -ForegroundColor Cyan
Write-Host ""

$composeFile = "docker-compose.dev.yml"
if (-not (Test-Path $composeFile)) {
    Write-Host "❌ $composeFile not found" -ForegroundColor Red
    exit 1
}

# Start services
$args = @("-f", $composeFile, "up", "-d")
& docker compose $args

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Services started with Docker Compose!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 Useful commands:" -ForegroundColor Cyan
    Write-Host "   View logs:        $composeCmd -f $composeFile logs -f"
    Write-Host "   View status:      $composeCmd -f $composeFile ps"
    Write-Host "   Stop services:    $composeCmd -f $composeFile down"
    Write-Host ""
    Write-Host "🌐 Services available:" -ForegroundColor Cyan
    Write-Host "   Backend API:      http://localhost:5000"
    Write-Host "   Cyrex AI:         http://localhost:8000"
    Write-Host "   MongoDB:          localhost:27017"
    Write-Host "   Redis:            localhost:6379"
    Write-Host ""
    Write-Host "💡 Note: Images were built with Minikube's Docker daemon" -ForegroundColor Yellow
    Write-Host "   but are running with Docker Compose (fastest startup!)" -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host "❌ Failed to start services" -ForegroundColor Red
    exit 1
}


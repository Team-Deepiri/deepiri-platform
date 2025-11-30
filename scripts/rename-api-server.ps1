# Rename api-server to deepiri-core-api
# This script handles the rename even if files are locked

Write-Host "Renaming api-server to deepiri-core-api..." -ForegroundColor Yellow

# Check if api-server exists
if (-not (Test-Path "api-server")) {
    Write-Host "api-server directory not found!" -ForegroundColor Red
    exit 1
}

# Check if deepiri-core-api already exists
if (Test-Path "deepiri-core-api") {
    Write-Host "deepiri-core-api already exists!" -ForegroundColor Red
    exit 1
}

# Method 1: Try simple rename first
try {
    Rename-Item -Path "api-server" -NewName "deepiri-core-api" -Force -ErrorAction Stop
    Write-Host "[OK] Directory renamed successfully!" -ForegroundColor Green
    exit 0
} catch {
    Write-Host "Simple rename failed, trying alternative method..." -ForegroundColor Yellow
}

# Method 2: Copy everything except node_modules, then delete original
Write-Host "Copying files (excluding node_modules)..." -ForegroundColor Yellow

# Create destination directory
New-Item -ItemType Directory -Path "deepiri-core-api" -Force | Out-Null

# Copy all files and folders except node_modules
Get-ChildItem -Path "api-server" -Exclude "node_modules" | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination "deepiri-core-api\$($_.Name)" -Recurse -Force -ErrorAction SilentlyContinue
}

# Copy node_modules separately (might fail, that's OK)
Write-Host "Attempting to copy node_modules..." -ForegroundColor Yellow
if (Test-Path "api-server\node_modules") {
    try {
        Copy-Item -Path "api-server\node_modules" -Destination "deepiri-core-api\node_modules" -Recurse -Force -ErrorAction Stop
        Write-Host "[OK] node_modules copied" -ForegroundColor Green
    } catch {
        Write-Host "[WARNING] Could not copy node_modules - you may need to run npm install in the new directory" -ForegroundColor Yellow
    }
}

Write-Host "[OK] Files copied. You can now delete api-server manually if needed." -ForegroundColor Green
Write-Host "Note: If node_modules wasn't copied, run: cd deepiri-core-api && npm install" -ForegroundColor Yellow


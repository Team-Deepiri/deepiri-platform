@echo off
REM Deepiri Complete Rebuild Script (Windows/WSL2)
REM This script: Stops containers → Removes old images → Rebuilds → Starts everything

echo ========================================
echo Deepiri Complete Rebuild Script
echo ========================================
echo.
echo This will:
echo   1. Stop all containers
echo   2. Remove old Deepiri images (~50GB)
echo   3. Clean build cache
echo   4. Rebuild everything fresh
echo   5. Start all services
echo.
echo WARNING: This will delete all your Deepiri Docker images!
echo.
set /p confirm="Continue? (y/N): "
if /i not "%confirm%"=="y" (
    echo Aborted.
    exit /b 1
)

REM Get the current directory and convert to WSL path
set "CURRENT_DIR=%~dp0"
set "CURRENT_DIR=%CURRENT_DIR:~0,-1%"
for %%i in ("%CURRENT_DIR%") do set "CURRENT_DIR=%%~fi"
set "CURRENT_DIR=%CURRENT_DIR:\=/%"
set "CURRENT_DIR=%CURRENT_DIR:C:=/mnt/c%"
set "CURRENT_DIR=%CURRENT_DIR:c:=/mnt/c%"

echo.
echo [1/5] Stopping containers...
wsl bash -c "cd '%CURRENT_DIR%' && docker-compose -f docker-compose.dev.yml down"
if errorlevel 1 (
    echo Warning: Some containers may not have stopped
)

echo.
echo [2/5] Removing old Deepiri images...
wsl bash -c "docker images --filter 'reference=deepiri-dev-*' --format '{{.ID}}' | xargs -r docker rmi -f 2>/dev/null || true"
if errorlevel 1 (
    echo Warning: Some images may not have been removed
)

echo.
echo [3/5] Cleaning build cache...
wsl bash -c "docker builder prune -a -f"
if errorlevel 1 (
    echo Error cleaning build cache
    pause
    exit /b 1
)

echo.
echo [4/5] Rebuilding all containers (this will take 10-30 minutes)...
wsl bash -c "cd '%CURRENT_DIR%' && docker-compose -f docker-compose.dev.yml build --no-cache"
if errorlevel 1 (
    echo Error rebuilding containers
    pause
    exit /b 1
)

echo.
echo [5/5] Starting all services...
wsl bash -c "cd '%CURRENT_DIR%' && docker-compose -f docker-compose.dev.yml up -d"
if errorlevel 1 (
    echo Error starting services
    pause
    exit /b 1
)

echo.
echo ========================================
echo Rebuild Complete!
echo ========================================
echo.
echo View logs: wsl bash -c "cd '%CURRENT_DIR%' && docker-compose -f docker-compose.dev.yml logs -f"
echo.
pause


@echo off
REM Nuke All Docker Volumes Script (Windows/WSL2)
REM WARNING: This will delete ALL Docker volumes, including your database data!

echo ========================================
echo   NUKE ALL DOCKER VOLUMES
echo ========================================
echo.
echo WARNING: This will delete ALL Docker volumes!
echo This includes:
echo   - MongoDB data
echo   - Redis data
echo   - InfluxDB data
echo   - MLflow data
echo   - All other volume data
echo.

wsl bash -c "docker volume ls"

echo.
set /p confirm="Are you absolutely sure? Type NUKE to confirm: "
if /i not "%confirm%"=="NUKE" (
    echo Aborted.
    exit /b 0
)

echo.
echo Removing all volumes...
wsl bash -c "docker volume ls -q | xargs -r docker volume rm"

echo.
echo ========================================
echo All volumes deleted!
echo ========================================
echo.
wsl bash -c "docker volume ls"
echo.
pause


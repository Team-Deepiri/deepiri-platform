@echo off
:: Deepiri Cleanup and Compaction Script Launcher
:: Right-click this file and select "Run as Administrator"

echo ==========================================
echo Deepiri Cleanup and Compaction Launcher
echo ==========================================
echo.
echo This will run the cleanup script with Administrator privileges.
echo.
pause

:: Check for admin privileges
net session >nul 2>&1
if %errorLevel% == 0 (
    echo [OK] Running with Administrator privileges...
    echo.
    echo Setting execution policy for this session...
    powershell.exe -Command "Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force"
    echo.
    echo Running cleanup script...
    echo.
    powershell.exe -ExecutionPolicy Bypass -File "%~dp0cleanup-and-compact.ps1"
) else (
    echo [ERROR] This script requires Administrator privileges!
    echo.
    echo Please right-click this file and select "Run as Administrator"
    echo.
    pause
    exit /b 1
)

pause


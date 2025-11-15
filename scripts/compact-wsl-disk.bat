@echo off
REM WSL2 Disk Compaction Script
REM Run this from Windows (double-click or run from Command Prompt)

echo ========================================
echo WSL2 Disk Compaction Tool
echo ========================================
echo.
echo This will:
echo 1. Shut down WSL
echo 2. Compact the WSL virtual disk to reclaim space
echo 3. Show you how much space was freed
echo.
echo WARNING: Make sure all your work in WSL is saved!
echo.
pause

echo.
echo [1/3] Shutting down WSL...
wsl --shutdown
timeout /t 3 /nobreak >nul

echo.
echo [2/3] Finding WSL virtual disk...
set "VHDX_PATH="

REM Try to find Ubuntu WSL disk
for /d %%i in ("%LOCALAPPDATA%\Packages\CanonicalGroupLimited.Ubuntu*") do (
    if exist "%%i\LocalState\ext4.vhdx" (
        set "VHDX_PATH=%%i\LocalState\ext4.vhdx"
        goto :found
    )
)

REM Try Docker Desktop location
if exist "%LOCALAPPDATA%\Docker\wsl\data\ext4.vhdx" (
    set "VHDX_PATH=%LOCALAPPDATA%\Docker\wsl\data\ext4.vhdx"
    goto :found
)

echo ERROR: Could not find WSL virtual disk!
echo.
echo Please find it manually:
echo 1. Look in: %LOCALAPPDATA%\Packages\CanonicalGroupLimited.Ubuntu*\LocalState\ext4.vhdx
echo 2. Or: %LOCALAPPDATA%\Docker\wsl\data\ext4.vhdx
pause
exit /b 1

:found
echo Found: %VHDX_PATH%

echo.
echo [3/3] Compacting disk (this may take a few minutes)...
echo.

REM Get size before
for %%A in ("%VHDX_PATH%") do set SIZE_BEFORE=%%~zA
set /a SIZE_BEFORE_GB=%SIZE_BEFORE:~0,-9%

REM Create diskpart script
set "DISKPART_SCRIPT=%TEMP%\compact_wsl.txt"
(
    echo select vdisk file="%VHDX_PATH%"
    echo attach vdisk readonly
    echo compact vdisk
    echo detach vdisk
) > "%DISKPART_SCRIPT%"

REM Run diskpart
diskpart /s "%DISKPART_SCRIPT%"

REM Clean up
del "%DISKPART_SCRIPT%"

echo.
echo ========================================
echo Compaction complete!
echo ========================================
echo.
echo You can now restart WSL with: wsl
echo.
pause


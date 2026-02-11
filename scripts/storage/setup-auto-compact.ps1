# Setup Automatic VHDX Compaction (Windows Scheduled Task)
# Run this ONCE as Administrator to set up automatic weekly compaction

# Check admin
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: Must run as Administrator!" -ForegroundColor Red
    Exit 1
}

Write-Host "Setting up automatic VHDX compaction..." -ForegroundColor Cyan
Write-Host ""

# Create the compact script
$compactScript = @'
# Auto-compact script (runs weekly)
$vhdxPath = "C:\Users\josep\AppData\Local\Packages\CanonicalGroupLimited.Ubuntu_79rhkp1fndgsc\LocalState\ext4.vhdx"

# Shutdown WSL
wsl --shutdown
Start-Sleep -Seconds 10

# Compact
try {
    Optimize-VHD -Path $vhdxPath -Mode Full -ErrorAction Stop
    Write-Output "$(Get-Date): VHDX compacted successfully"
} catch {
    Write-Output "$(Get-Date): Compaction failed: $_"
}
'@

$scriptPath = "$env:TEMP\auto-compact-wsl.ps1"
Set-Content -Path $scriptPath -Value $compactScript

# Create scheduled task (runs every Sunday at 3 AM)
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 3am
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

# Register the task
$taskName = "WSL2-VHDX-Auto-Compact"
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($existingTask) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "Automatically compact WSL2 VHDX file to reclaim disk space"

Write-Host "SUCCESS!" -ForegroundColor Green
Write-Host ""
Write-Host "Automatic compaction is now set up:" -ForegroundColor Cyan
Write-Host "  - Runs: Every Sunday at 3:00 AM" -ForegroundColor Yellow
Write-Host "  - Task Name: $taskName" -ForegroundColor Yellow
Write-Host ""
Write-Host "To disable:" -ForegroundColor Cyan
Write-Host "  Disable-ScheduledTask -TaskName '$taskName'" -ForegroundColor Yellow
Write-Host ""
Write-Host "To run manually now:" -ForegroundColor Cyan
Write-Host "  Start-ScheduledTask -TaskName '$taskName'" -ForegroundColor Yellow
Write-Host ""


#requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$targetDir = Join-Path $env:LOCALAPPDATA 'YearProgressWallpaper'
if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir | Out-Null
}

$source = Join-Path $PSScriptRoot 'Update-Wallpaper.ps1'
if (-not (Test-Path $source)) {
    throw "Update-Wallpaper.ps1 not found next to install.ps1 at $source"
}
$dest = Join-Path $targetDir 'Update-Wallpaper.ps1'
Copy-Item -Path $source -Destination $dest -Force

$argString = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $dest + '"'
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argString
$trigger = New-ScheduledTaskTrigger -Daily -At 12:00am
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

Register-ScheduledTask -TaskName 'YearProgressWallpaper' `
    -Description 'Renders a black wallpaper showing day-of-year and percent progress through the year.' `
    -Action $action -Trigger $trigger -Settings $settings -User "$env:USERDOMAIN\$env:USERNAME" -Force | Out-Null

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $dest

Write-Host "Installed. Scheduled task 'YearProgressWallpaper' will refresh daily at 00:00."
Write-Host "Output: $dest"
Write-Host "To uninstall, run: .\uninstall.ps1"

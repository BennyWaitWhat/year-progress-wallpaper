#requires -Version 5.1
[CmdletBinding()]
param()

try {
    Unregister-ScheduledTask -TaskName 'YearProgressWallpaper' -Confirm:$false -ErrorAction Stop
    Write-Host "Removed scheduled task 'YearProgressWallpaper'."
} catch {
    Write-Warning "Scheduled task 'YearProgressWallpaper' not found (already removed?)."
}

$targetDir = Join-Path $env:LOCALAPPDATA 'YearProgressWallpaper'
if (Test-Path $targetDir) {
    Remove-Item -Path $targetDir -Recurse -Force
    Write-Host "Removed $targetDir."
}

Write-Host ""
Write-Host "Note: the desktop wallpaper and lock screen will still point at the (now-deleted) image."
Write-Host "Open Settings > Personalization to pick replacements."

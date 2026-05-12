Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$now = Get-Date
$year = $now.Year
$startOfYear = Get-Date -Year $year -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0
$startOfNext = Get-Date -Year ($year + 1) -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0
$daysInYear = [int]($startOfNext - $startOfYear).TotalDays
$dayOfYear = $now.DayOfYear
$percent = ($dayOfYear / $daysInYear) * 100

$primary = [System.Windows.Forms.Screen]::PrimaryScreen
if ($primary) {
    $width = $primary.Bounds.Width
    $height = $primary.Bounds.Height
} else {
    $width = 1920
    $height = 1080
}

# Tunable knobs:
#   $scale - element size. 1.0 = bold/default, 0.5 = half-size, 0.34 = subtle.
#   $alpha - ink opacity 0-255. 255 = solid white, 128 = half-transparent, 64 = faint.
$scale = 1.0
$alpha = 255

$resScale = $height / 1200.0

$bmp = New-Object System.Drawing.Bitmap $width, $height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::Black)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias

$inkColor = [System.Drawing.Color]::FromArgb($alpha, 255, 255, 255)
$brush = New-Object System.Drawing.SolidBrush $inkColor
$pen = New-Object System.Drawing.Pen $inkColor, 2

$dayFont = New-Object System.Drawing.Font 'Segoe UI', ([Math]::Max(130 * $scale * $resScale, 1)), ([System.Drawing.FontStyle]::Bold)
$pctFont = New-Object System.Drawing.Font 'Segoe UI', ([Math]::Max(80 * $scale * $resScale, 1)), ([System.Drawing.FontStyle]::Regular)

$dayText = "DAY $dayOfYear / $daysInYear"
$pctText = "{0:F1}%" -f $percent

$fmt = New-Object System.Drawing.StringFormat
$fmt.Alignment = [System.Drawing.StringAlignment]::Center
$fmt.LineAlignment = [System.Drawing.StringAlignment]::Center

$centerY = $height / 2

$dayRect = New-Object System.Drawing.RectangleF 0, ($centerY - 260 * $scale * $resScale), $width, (240 * $scale * $resScale)
$pctRect = New-Object System.Drawing.RectangleF 0, ($centerY - 20 * $scale * $resScale), $width, (160 * $scale * $resScale)

$g.DrawString($dayText, $dayFont, $brush, $dayRect, $fmt)
$g.DrawString($pctText, $pctFont, $brush, $pctRect, $fmt)

$barWidth = [int]($width * 0.6 * $scale)
$barHeight = [int](32 * $scale * $resScale)
$barX = ($width - $barWidth) / 2
$barY = $centerY + (200 * $scale * $resScale)
$g.DrawRectangle($pen, $barX, $barY, $barWidth, $barHeight)
$filledWidth = [int]($barWidth * $percent / 100)
if ($filledWidth -gt 0) {
    $g.FillRectangle($brush, $barX, $barY, $filledWidth, $barHeight)
}

$outDir = Join-Path $env:LOCALAPPDATA 'YearProgressWallpaper'
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$outPath = Join-Path $outDir 'wallpaper.png'

$g.Dispose()
$bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

if (-not ('Wallpaper' -as [type])) {
    Add-Type @'
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet=CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
'@
}

Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value '10'
Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -Value '0'

$SPI_SETDESKWALLPAPER = 0x14
$SPIF_UPDATEINIFILE = 0x01
$SPIF_SENDCHANGE = 0x02
[Wallpaper]::SystemParametersInfo($SPI_SETDESKWALLPAPER, 0, $outPath, ($SPIF_UPDATEINIFILE -bor $SPIF_SENDCHANGE)) | Out-Null

try {
    [Windows.System.UserProfile.LockScreen, Windows.System.UserProfile, ContentType = WindowsRuntime] | Out-Null
    [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime] | Out-Null
    Add-Type -AssemblyName System.Runtime.WindowsRuntime

    $asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
    })[0]
    $asTaskAction = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction'
    })[0]

    $getFileOp = [Windows.Storage.StorageFile]::GetFileFromPathAsync($outPath)
    $getFileTask = $asTaskGeneric.MakeGenericMethod([Windows.Storage.StorageFile]).Invoke($null, @($getFileOp))
    $getFileTask.Wait(-1) | Out-Null
    $storageFile = $getFileTask.Result

    $setOp = [Windows.System.UserProfile.LockScreen]::SetImageFileAsync($storageFile)
    $setTask = $asTaskAction.Invoke($null, @($setOp))
    $setTask.Wait(-1) | Out-Null
} catch {
    Write-Warning "Lock screen update failed: $($_.Exception.Message)"
}

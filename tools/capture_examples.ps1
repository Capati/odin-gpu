<#
.SYNOPSIS
Captures one screenshot per odin-gpu example via the DWM-composed desktop.

.DESCRIPTION
Builds each target with examples\build.bat, launches it from examples\build
(so relative asset paths resolve), waits for first frames, foregrounds its
window, captures the window rect with Graphics.CopyFromScreen, and saves a
PNG. CopyFromScreen sees DWM-composed output, so Vulkan-presented frames are
captured (per-window PrintWindow would return black for swapchains).

Each fresh capture is then optimized in place (pngquant + optipng -o7) when
those tools are on PATH; otherwise captures are kept unoptimized with a
warning. Only files this run captured are modified — existing images
elsewhere are never touched.

Outputs to examples\build\screenshots\ (ignored build output, like harness
logs). A tiny PNG (< 6 KB) is reported as a warning: usually a blank or
clear-color-only frame.

.PARAMETER Targets
Example names to capture. Defaults to every directory under examples\ declaring
a main procedure.

.PARAMETER WarmupSeconds
Seconds to wait after launch before capturing (first frames + window setup).

.PARAMETER OutDir
Where to write PNGs. Defaults to examples\build\screenshots. Ignored when
-PerExampleDir is set.

.PARAMETER PerExampleDir
Write each screenshot as examples\<name>\<name>.png instead of using OutDir.

.PARAMETER SkipBuild
Reuse existing binaries instead of rebuilding.

.PARAMETER MinBytesWarn
PNGs smaller than this warn as possibly-blank. Default 6144.

.EXAMPLE
.\tests\capture_examples.ps1 -Targets minimal,triangle,cube
Capture three examples.
#>
[CmdletBinding()]
param(
    [string[]]$Targets = @(),
    [int]$WarmupSeconds = 5,
    [string]$OutDir = '',
    [switch]$SkipBuild,
    [switch]$PerExampleDir,
    [int]$MinBytesWarn = 6144
)

$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class Win32Capture {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr hWnd, ref POINT lpPoint);
    [StructLayout(LayoutKind.Sequential)] public struct RECT {
        public int Left; public int Top; public int Right; public int Bottom;
    }
    [StructLayout(LayoutKind.Sequential)] public struct POINT {
        public int X; public int Y;
    }
}
"@

$repoRoot = Split-Path -Parent $PSScriptRoot
$examplesDir = Join-Path $repoRoot 'examples'
$buildDir = Join-Path $examplesDir 'build'
if ($OutDir -eq '') { $OutDir = Join-Path $buildDir 'screenshots' }
if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir | Out-Null
}

# JS-only demos and self-exiting runners don't fit the capture loop.
$exclude = @('build', 'framework', 'temp', 'assets', 'layout', 'surface_stress', 'screenshots')

if ($Targets.Count -eq 0) {
    $Targets = Get-ChildItem -LiteralPath $examplesDir -Directory |
        Where-Object { $exclude -notcontains $_.Name } |
        Where-Object {
            $files = Get-ChildItem -LiteralPath $_.FullName -Filter *.odin -File -ErrorAction SilentlyContinue
            $files -and (Select-String -Path $files.FullName -Pattern '^main\s*::' -Quiet)
        } |
        ForEach-Object { $_.Name } |
        Sort-Object
}

if ($Targets.Count -eq 0) {
    Write-Host "No runnable examples found under $examplesDir" -ForegroundColor Red
    exit 1
}

$failures = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]
$script:optToolsWarned = $false

# Best-effort in-place optimization of one fresh capture. Never touches
# anything but the given path; keeps the original on any tool failure.
function Optimize-Capture {
    param([string]$Path)
    $pngquant = Get-Command pngquant -ErrorAction SilentlyContinue
    $optipng = Get-Command optipng -ErrorAction SilentlyContinue
    if (-not $pngquant -or -not $optipng) {
        if (-not $script:optToolsWarned) {
            $script:optToolsWarned = $true
            Write-Host "  WARN  pngquant/optipng not on PATH; keeping unoptimized captures" -ForegroundColor Yellow
        }
        return
    }
    & pngquant --quality=65-80 --force $Path -o $Path 2>$null
    if ($LASTEXITCODE -ne 0) {
        # Some files reject quality bounds; retry unbounded before giving up.
        & pngquant --force $Path -o $Path 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host ("  WARN  {0} : pngquant failed, keeping unoptimized" -f (Split-Path $Path -Leaf)) -ForegroundColor Yellow
            return
        }
    }
    & optipng -o7 -quiet $Path 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host ("  WARN  {0} : optipng failed, keeping pngquant output" -f (Split-Path $Path -Leaf)) -ForegroundColor Yellow
    }
}

function Get-MainWindowHandle {
    param([System.Diagnostics.Process]$Proc, [int]$TimeoutSeconds = 15)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $Proc.Refresh()
        if ($Proc.HasExited) { return [IntPtr]::Zero }
        if ($Proc.MainWindowHandle -ne [IntPtr]::Zero) { return $Proc.MainWindowHandle }
        Start-Sleep -Milliseconds 300
    }
    return [IntPtr]::Zero
}

foreach ($t in $Targets) {
    $exe = Join-Path $buildDir "$t.exe"

    if (-not $SkipBuild) {
        $src = Join-Path $examplesDir $t
        if (-not (Test-Path -LiteralPath $src)) {
            $failures.Add("$t : no such example directory")
            Write-Host ("  FAIL  {0} : no such example directory" -f $t) -ForegroundColor Red
            continue
        }
        Push-Location -LiteralPath $examplesDir
        try {
            $out = cmd /c "build.bat $t" 2>&1
            $code = $LASTEXITCODE
        }
        finally {
            Pop-Location
        }
        if ($code -ne 0 -or -not (Test-Path -LiteralPath $exe)) {
            $failures.Add("$t : build failed (exit $code)")
            Write-Host ("  FAIL  {0} : build failed (exit {1})" -f $t, $code) -ForegroundColor Red
            continue
        }
    }
    elseif (-not (Test-Path -LiteralPath $exe)) {
        $failures.Add("$t : no executable at $exe (use without -SkipBuild first)")
        Write-Host ("  FAIL  {0} : no executable" -f $t) -ForegroundColor Red
        continue
    }

    $proc = Start-Process -FilePath $exe -WorkingDirectory $buildDir -PassThru
    Start-Sleep -Seconds $WarmupSeconds
    $proc.Refresh()
    if ($proc.HasExited) {
        $failures.Add("$t : exited during warmup (exit $($proc.ExitCode))")
        Write-Host ("  FAIL  {0} : exited during warmup" -f $t) -ForegroundColor Red
        continue
    }

    $hwnd = Get-MainWindowHandle -Proc $proc
    if ($hwnd -eq [IntPtr]::Zero) {
        $failures.Add("$t : no window handle appeared")
        Write-Host ("  FAIL  {0} : no window handle" -f $t) -ForegroundColor Red
        if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
        continue
    }

    [void][Win32Capture]::SetForegroundWindow($hwnd)
    Start-Sleep -Milliseconds 500

    $rect = New-Object Win32Capture+RECT
    $clientX = 0
    $clientY = 0
    $clientW = 0
    $clientH = 0
    $pt = New-Object Win32Capture+POINT
    if ([Win32Capture]::GetClientRect($hwnd, [ref]$rect) -and
        [Win32Capture]::ClientToScreen($hwnd, [ref]$pt)) {
        # Client area only: no titlebar or borders.
        $clientX = $pt.X
        $clientY = $pt.Y
        $clientW = $rect.Right - $rect.Left
        $clientH = $rect.Bottom - $rect.Top
    }
    if ($clientW -le 0 -or $clientH -le 0) {
        # Fallback: full window rect including decorations.
        if (-not [Win32Capture]::GetWindowRect($hwnd, [ref]$rect)) {
            $failures.Add("$t : GetWindowRect failed")
            Write-Host ("  FAIL  {0} : GetWindowRect failed" -f $t) -ForegroundColor Red
            if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
            continue
        }
        $clientX = $rect.Left
        $clientY = $rect.Top
        $clientW = $rect.Right - $rect.Left
        $clientH = $rect.Bottom - $rect.Top
    }
    $w = $clientW
    $h = $clientH
    if ($w -le 0 -or $h -le 0) {
        $failures.Add("$t : window has no area (${w}x${h})")
        Write-Host ("  FAIL  {0} : window has no area" -f $t) -ForegroundColor Red
        if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
        continue
    }

    $png = if ($PerExampleDir) {
        Join-Path (Join-Path $examplesDir $t) "$t.png"
    } else {
        Join-Path $OutDir "$t.png"
    }
    try {
        $bmp = New-Object System.Drawing.Bitmap($w, $h)
        $gfx = [System.Drawing.Graphics]::FromImage($bmp)
        $gfx.CopyFromScreen(
            (New-Object System.Drawing.Point($clientX, $clientY)),
            [System.Drawing.Point]::Empty,
            (New-Object System.Drawing.Size($w, $h)))
        $bmp.Save($png, [System.Drawing.Imaging.ImageFormat]::Png)
        $gfx.Dispose()
        $bmp.Dispose()
    }
    catch {
        $failures.Add("$t : capture failed : $_")
        Write-Host ("  FAIL  {0} : capture failed" -f $t) -ForegroundColor Red
        if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
        continue
    }

    if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Milliseconds 300

    Optimize-Capture -Path $png

    $bytes = (Get-Item -LiteralPath $png).Length
    if ($bytes -lt $MinBytesWarn) {
        $warnings.Add("$t : $png is only $bytes bytes (possibly blank)")
        Write-Host ("  WARN  {0,-24} {1} ({2} bytes, possibly blank)" -f $t, $png, $bytes) -ForegroundColor Yellow
    }
    else {
        Write-Host ("  ok    {0,-24} {1} ({2} bytes, {3}x{4})" -f $t, $png, $bytes, $w, $h) -ForegroundColor Green
    }
}

Write-Host ''
Write-Host ("  captured: {0}  failures: {1}  warnings: {2}  out: {3}" -f
    ($Targets.Count - $failures.Count), $failures.Count, $warnings.Count, $OutDir)
if ($failures.Count -gt 0) {
    Write-Host ''
    Write-Host 'FAILURES:' -ForegroundColor Red
    foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor Red }
    exit 1
}
Write-Host 'Capture pass complete.' -ForegroundColor Green
exit 0

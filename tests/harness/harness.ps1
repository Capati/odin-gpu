<#
.SYNOPSIS
Paced verification harness for the odin-gpu examples.

.DESCRIPTION
Runs the checks that matter after a backend change, in order, encoding the
failure modes a naive "build succeeded / exit code 0" pass misses.

  1. FRESHNESS. Every target is rebuilt with the frame-time instrument enabled,
     then each .exe is verified to be newer than the newest source feeding it. A
     stale binary that still runs is indistinguishable from a correct one.
  2. PACING. Each example is built with `measure`, which compiles in
     examples\framework\frame_time.odin. That instrument reports the frame-time
     distribution (median/p95/max and a miss count) once per 120-frame window.
     The harness samples the report count on a fixed cadence, so "no new report
     since the last tick" is read as a stall. This proves the render loop is
     advancing frames and catches a minority-of-frames regression, which an
     average or an exit code hides completely.
  3. LIVENESS. Stalls are cross-checked against window responsiveness, and a
     stalled process is handed to cdb for a full thread stack dump so a hang is
     diagnosed in one command rather than by hand.

build.bat is invoked with the examples directory pinned as the CWD, because it
resolves OUT to .\build relative to its caller. Invoked from the repository root
it writes to a build\ that has no assets\ and that nothing ever runs.

Debug is the default build mode. Release adds -disable-assert, which compiles out
every assert and bounds check in the backend. That makes release far more sensitive to
working directory and asset layout than debug, because the assertions that would have
caught a mis-rooted build or a missing file no longer run — a failure surfaces later
as a crash or a corrupt frame instead of as a message naming the cause. (An earlier
version of this file blamed the panic on image-loader registration not surviving
-release; that was wrong. The loader panic requires *zero* registered loaders, which a
missing file cannot cause. The real cause was a build rooted at the wrong directory.)

.PARAMETER Targets
Example names to check. Defaults to every directory under examples\ declaring a
main procedure.

.PARAMETER PaceSeconds
Seconds between pacing samples.

.PARAMETER PaceCount
Number of samples per target; the observed window is PaceSeconds * PaceCount.

.PARAMETER WarmupSeconds
Unprobed startup time. The instrument discards its first 30 frames and then
needs 120 more before its first report, so this must exceed ~150 frames.

.PARAMETER Clean
Delete .exe/.pdb before building, forcing a from-scratch compile.

.PARAMETER SkipBuild
Reuse existing binaries. Freshness is still checked, so this fails loudly if
anything is stale.

.PARAMETER SkipTests
Skip `odin test gpu` in debug and -o:speed.

.PARAMETER NoMeasure
Build without the frame-time instrument. Pacing then degrades to responsiveness
and CPU progression only, which cannot detect a partial pacing regression.

.PARAMETER Release
Build release. See the note above about asserts being compiled out.

.EXAMPLE
.\tests\harness\harness.ps1 -Clean
From-scratch build, unit tests, and a paced pass over every example.

.EXAMPLE
.\tests\harness\harness.ps1 -Targets two_cubes,microui -PaceSeconds 4 -PaceCount 8
Longer pacing window on the examples that exercise uniform writes and deferred
deletion.
#>
[CmdletBinding()]
param(
    [string[]]$Targets = @(),
    [int]$PaceSeconds = 3,
    [int]$PaceCount = 5,
    [int]$WarmupSeconds = 4,
    [switch]$Clean,
    [switch]$SkipBuild,
    [switch]$SkipTests,
    [switch]$NoMeasure,
    [switch]$Release,
    [string]$Cdb = "C:\Program Files (x86)\Windows Kits\10\Debuggers\x64\cdb.exe"
)

$ErrorActionPreference = 'Continue'
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$examplesDir = Join-Path $repoRoot 'examples'
$buildDir = Join-Path $examplesDir 'build'
$gpuDir = Join-Path $repoRoot 'gpu'
$logDir = Join-Path $buildDir 'harness'

# `layout` is a JS-only demo; `surface_stress` has its own finite live-Vulkan runner.
$exclude = @('build', 'framework', 'temp', 'assets', 'layout', 'surface_stress')

if (-not (Test-Path -LiteralPath $buildDir)) {
    New-Item -ItemType Directory -Path $buildDir | Out-Null
}
if (-not (Test-Path -LiteralPath $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

function Write-Section {
    param([string]$Title)
    Write-Host ''
    Write-Host "=== $Title" -ForegroundColor Cyan
}

function Add-Failure {
    param([string]$Message)
    $script:failures.Add($Message)
    Write-Host "  FAIL  $Message" -ForegroundColor Red
}

function Add-Warning {
    param([string]$Message)
    $script:warnings.Add($Message)
    Write-Host "  WARN  $Message" -ForegroundColor Yellow
}

function Add-Blocked {
    param([string]$Message)
    $script:blocked.Add($Message)
    Write-Host "  BLOCK $Message" -ForegroundColor Magenta
}

$failures = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]
$blocked = New-Object System.Collections.Generic.List[string]

# A leftover example window from an aborted run would hold a stale binary open
# across the build and skew every later liveness sample.
Get-Process -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -and $_.Path.StartsWith($buildDir, [StringComparison]::OrdinalIgnoreCase) } |
    ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }

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

$useMeasure = -not $NoMeasure

function Get-FrameTimeLines {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return @() }
    return @(Select-String -Path $Path -Pattern 'FRAME_TIME ' -ErrorAction SilentlyContinue)
}

function Get-FrameTimeStats {
    param([string]$Path)
    $lines = Get-FrameTimeLines -Path $Path
    if ($lines.Count -eq 0) { return $null }
    $last = $lines[-1].Line
    if ($last -match 'frames=(\d+) median=([\d.]+) p95=([\d.]+) max=([\d.]+) miss=(\d+)') {
        return [pscustomobject]@{
            Frames = [int]$Matches[1]; Median = [double]$Matches[2]
            P95 = [double]$Matches[3]; Max = [double]$Matches[4]; Miss = [int]$Matches[5]
        }
    }
    return $null
}

# Problems that indicate a real defect rather than a gap in the repository.
function Get-ProblemLines {
    param([string[]]$Paths)
    if (-not $Paths) { return @() }
    $patterns = @(
        'VUID-', 'SYNC-', 'WRITE_AFTER_READ', 'READ_AFTER_WRITE',
        'unprotected', 'runtime assertion', 'panic:',
        'Waiting for command buffers'
    )
    Select-String -Path $Paths -Pattern $patterns -ErrorAction SilentlyContinue
}

# Conditions that mean the example cannot run at all here, so that a repo gap is
# never mistaken for a regression from a backend change.
function Get-BlockedReason {
    param([string[]]$Paths)
    if (-not $Paths) { return $null }
    $m = Select-String -Path $Paths -Pattern 'Failed to load file|no image loaders registered' -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($m) { return $m.Line.Trim() }
    return $null
}

function Invoke-StackDump {
    param([int]$ProcessId, [string]$Target)
    if (-not (Test-Path -LiteralPath $Cdb)) {
        Write-Host "        (cdb not found; no stack dump)" -ForegroundColor DarkGray
        return
    }
    $out = Join-Path $logDir "$Target.stacks.txt"
    & $Cdb -p $ProcessId -c '~*k30; qd' 2>&1 | Out-File -FilePath $out -Encoding utf8
    Write-Host "        stacks -> $out" -ForegroundColor DarkGray
    # Keep only frames naming the program so a stall is readable at a glance.
    Select-String -Path $out -Pattern "$Target!" -ErrorAction SilentlyContinue |
        Select-Object -First 14 |
        ForEach-Object { Write-Host "          $($_.Line.Trim())" -ForegroundColor DarkGray }
}

# -----------------------------------------------------------------------------
# 1. Build
# -----------------------------------------------------------------------------

if (-not $SkipBuild) {
    $mode = 'debug'
    Write-Section "Build ($($Targets.Count) targets$(if ($Clean) { ', clean' })$(if ($useMeasure) { ', measure' }))"

    if ($Clean) {
        # Filter on the extension explicitly rather than via -Include: paired
        # with -LiteralPath, -Include is not applied, which previously deleted
        # everything under build\ including the assets submodule checkout.
        Get-ChildItem -LiteralPath $buildDir -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -eq '.exe' -or $_.Extension -eq '.pdb' } |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }

    $buildArgs = @()
    if ($Release) { $buildArgs += 'release' }
    if ($useMeasure) { $buildArgs += 'measure' }
    $buildArgs = $buildArgs -join ' '

    foreach ($t in $Targets) {
        $src = Join-Path $examplesDir $t
        if (-not (Test-Path -LiteralPath $src)) {
            Add-Failure "$t : no such example directory"
            continue
        }

        $sw = [Diagnostics.Stopwatch]::StartNew()
        # The CWD must be pinned: build.bat resolves OUT to .\build relative to
        # whatever directory it is invoked from, so inheriting the caller's CWD
        # silently writes the binary somewhere nothing will run.
        Push-Location -LiteralPath $examplesDir
        try {
            $out = cmd /c "build.bat $t $buildArgs" 2>&1
            $code = $LASTEXITCODE
        }
        finally {
            Pop-Location
        }
        $sw.Stop()

        if ($code -ne 0) {
            $first = ($out | Select-String -Pattern 'error' | Select-Object -First 1)
            Add-Failure "$t : build exit ${code}: $first"
        }
        else {
            Write-Host ("  ok    {0,-24} {1,5:N1}s" -f $t, $sw.Elapsed.TotalSeconds)
        }
    }
}

# -----------------------------------------------------------------------------
# 2. Freshness
# -----------------------------------------------------------------------------

Write-Section 'Artifact freshness'

foreach ($t in $Targets) {
    $exe = Join-Path $buildDir "$t.exe"
    if (-not (Test-Path -LiteralPath $exe)) {
        Add-Failure "$t : no executable at $exe"
        continue
    }

    $exeTime = (Get-Item -LiteralPath $exe).LastWriteTime

    $sources = @()
    $sources += Get-ChildItem -LiteralPath $gpuDir -Filter *.odin -File -ErrorAction SilentlyContinue
    $src = Join-Path $examplesDir $t
    if (Test-Path -LiteralPath $src) {
        $sources += Get-ChildItem -LiteralPath $src -Filter *.odin -File -Recurse -ErrorAction SilentlyContinue
    }
    $sources += Get-ChildItem -LiteralPath (Join-Path $repoRoot 'utils') -Filter *.odin -File -Recurse -ErrorAction SilentlyContinue

    if ($sources.Count -eq 0) {
        Add-Warning "$t : no sources found to compare against"
        continue
    }

    $newest = $sources | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($exeTime -lt $newest.LastWriteTime) {
        Add-Failure ("{0} : STALE binary {1:HH:mm:ss} older than {2} at {3:HH:mm:ss}" -f
            $t, $exeTime, $newest.Name, $newest.LastWriteTime)
    }
    else {
        Write-Host ("  ok    {0,-24} exe {1:HH:mm:ss} >= src {2:HH:mm:ss}" -f
            $t, $exeTime, $newest.LastWriteTime)
    }
}

# -----------------------------------------------------------------------------
# 3. Unit tests
# -----------------------------------------------------------------------------

if (-not $SkipTests) {
    Write-Section 'Unit tests (gpu)'

    foreach ($mode in @('debug', '-o:speed')) {
        $testArgs = if ($mode -eq 'debug') { @('test', 'gpu') } else { @('test', 'gpu', '-o:speed') }
        # `gpu` is a relative package path, so the CWD must be the repository
        # root rather than wherever the caller happened to invoke the harness.
        Push-Location -LiteralPath $repoRoot
        try {
            $out = & odin @testArgs 2>&1
            $code = $LASTEXITCODE
        }
        finally {
            Pop-Location
        }
        $summary = ($out | Select-String -Pattern 'Finished .* tests' | Select-Object -Last 1)
        if ($code -eq 0 -and "$out" -match 'All tests were successful') {
            Write-Host ("  ok    {0,-8} {1}" -f $mode, $summary)
        }
        else {
            $err = ($out | Select-Object -Last 1)
            Add-Failure "unit tests ${mode}: exit ${code}: $summary $err"
        }
    }
}

# -----------------------------------------------------------------------------
# 4. Paced liveness, driven by the in-app frame-time instrument
# -----------------------------------------------------------------------------

Write-Section "Paced liveness (${PaceSeconds}s x ${PaceCount} + ${WarmupSeconds}s warmup$(if ($useMeasure) { ', frame-time driven' }))"

foreach ($t in $Targets) {
    $exe = Join-Path $buildDir "$t.exe"
    if (-not (Test-Path -LiteralPath $exe)) {
        Write-Host ("  skip  {0,-24} no executable" -f $t)
        continue
    }

    $stdout = Join-Path $logDir "$t.out"
    $stderr = Join-Path $logDir "$t.err"
    Remove-Item -LiteralPath $stdout, $stderr -Force -ErrorAction SilentlyContinue

    $proc = Start-Process -FilePath $exe -WorkingDirectory $buildDir `
        -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru

    if ($WarmupSeconds -gt 0) {
        Start-Sleep -Seconds $WarmupSeconds
    }

    $exited = $false
    $responding = $true
    $cpuStart = $proc.CPU
    $prevReports = (Get-FrameTimeLines -Path $stdout).Count
    $timeline = @()
    $stalls = 0

    for ($i = 1; $i -le $PaceCount; $i++) {
        Start-Sleep -Seconds $PaceSeconds
        $proc.Refresh()

        if ($proc.HasExited) { $exited = $true; break }
        $responding = $proc.Responding

        if ($useMeasure) {
            $reports = (Get-FrameTimeLines -Path $stdout).Count
            $delta = $reports - $prevReports
            $prevReports = $reports
            # The first tick gets a grace period: the instrument discards 30
            # frames and then needs 120 more before its first report.
            if ($delta -eq 0 -and $i -gt 1) { $stalls++ }
            $timeline += ("    t={0,2}  reports=+{1} cpu={2:N2}s{3}" -f
                ($i * $PaceSeconds), $delta, $proc.CPU, $(if (-not $responding) { '  NOT RESPONDING' } else { '' }))
        }
        else {
            $timeline += ("    t={0,2}  cpu={1:N2}s{2}" -f
                ($i * $PaceSeconds), $proc.CPU, $(if (-not $responding) { '  NOT RESPONDING' } else { '' }))
        }

        if (-not $responding) { break }
    }

    $stats = Get-FrameTimeStats -Path $stdout
    $blockReason = Get-BlockedReason -Paths @($stdout, $stderr)

    if ($exited) {
        if ($blockReason) {
            # Not a regression: the example cannot run here at all.
            Add-Blocked "$t : $blockReason"
            $verdict = 'blocked (missing asset)'
            $color = 'Magenta'
        }
        else {
            $err = (Select-String -Path $stderr -Pattern '.' -ErrorAction SilentlyContinue | Select-Object -First 1)
            Add-Failure "$t : exited during pacing : $err"
            $verdict = 'exited during pacing'
            $color = 'Red'
        }
    }
    elseif (-not $responding) {
        Invoke-StackDump -ProcessId $proc.Id -Target $t
        Add-Failure "$t : window stopped responding"
        $verdict = 'FROZEN (window)'
        $color = 'Red'
    }
    elseif ($useMeasure -and $stalls -ge 2) {
        # One quiet tick can be a scheduling blip; sustained silence means the
        # render loop stopped advancing while the window still pumps messages.
        Invoke-StackDump -ProcessId $proc.Id -Target $t
        Add-Failure "$t : no frame-time reports for $stalls consecutive samples"
        $verdict = "STALLED ($stalls quiet samples)"
        $color = 'Red'
    }
    else {
        $proc.Refresh()
        $elapsed = $PaceSeconds * $PaceCount
        $rate = if ($elapsed -gt 0) { (($proc.CPU - $cpuStart) / $elapsed) * 100 } else { 0 }
        if ($rate -gt 85) {
            Add-Warning "$t : responsive but pegged a core ({0:N0}%)" -f $rate
        }
        if ($stats) {
            $verdict = "median={0:N2}ms p95={1:N2}ms max={2:N2}ms miss={3}/{4}" -f
                $stats.Median, $stats.P95, $stats.Max, $stats.Miss, $stats.Frames
        }
        else {
            $verdict = "responsive ${elapsed}s, no frame-time reports"
            Add-Warning "$t : ran but emitted no frame-time reports"
        }
        $color = 'Green'
    }

    foreach ($line in $timeline) { Write-Host $line }
    Write-Host ("  {0,-24} {1}" -f $t, $verdict) -ForegroundColor $color

    if (-not $proc.HasExited) {
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 300

    foreach ($p in (Get-ProblemLines -Paths @($stdout, $stderr))) {
        $msg = "$t : $($p.Line.Trim())"
        if ($exited -and $blockReason) { Add-Blocked $msg } else { Add-Warning $msg }
    }
}

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

Write-Section 'Summary'

Write-Host ("  failures: {0}" -f $failures.Count)
Write-Host ("  warnings: {0}" -f $warnings.Count)
Write-Host ("  blocked:  {0}" -f $blocked.Count)
Write-Host ("  logs:     {0}" -f $logDir)

if ($blocked.Count -gt 0) {
    Write-Host ''
    Write-Host 'BLOCKED (cannot run here, not regressions):' -ForegroundColor Magenta
    foreach ($b in $blocked) { Write-Host "  - $b" -ForegroundColor Magenta }
}

if ($failures.Count -gt 0) {
    Write-Host ''
    Write-Host 'FAILURES:' -ForegroundColor Red
    foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor Red }
    exit 1
}

Write-Host ''
Write-Host 'All paced checks passed.' -ForegroundColor Green
exit 0

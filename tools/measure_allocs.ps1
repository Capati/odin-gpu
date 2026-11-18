<#
.SYNOPSIS
Counts Odin heap allocations per measured frame for the Vulkan backend.

.DESCRIPTION
Builds `tests/bench` in release mode and runs the benchmark suites with
`--track-allocs 1`, which installs a counting allocator before the GPU instance
is created. The backend captures that allocator, so every Odin heap allocation
it makes is attributed to its call site, including command-buffer tracker
metadata, pass arenas, deferred-write batches and staging.

Counting starts on the first frame after warm-up (`--frames / 4`), so setup and
warm-up are excluded. Run with a large `-Frames` value: the first measured frames
also cover one-time growth to the high-water mark (resource metadata, handle map,
bitsets). What this script chases is the *steady-state* remainder. A steady state
of zero is the goal; anything that scales with frames is per-frame churn.

Two runs per suite are taken by default and the lower allocation count is
reported. Allocation counts are otherwise stable; the exception is
`queue_write_buffer`, which falls back from a direct host write to a staged
deferred write depending on whether the queue is still busy, so the first run
after a build can show the staged path. The minimum is the steady floor.

The suites here are the steady-state recording/submit paths. Per-call resource
creation is measured separately, because it is proportional to creation rather
than to frames:

    tests/build/vk_bench.exe --bench churn --op bind_group    --count 32 --frames 400 --track-allocs 1
    tests/build/vk_bench.exe --bench churn --op bundle        --count 32 --frames 400 --track-allocs 1
    tests/build/vk_bench.exe --bench churn --op view          --count 32 --frames 400 --track-allocs 1
    tests/build/vk_bench.exe --bench churn --op texture_write --count 32 --frames 400 --track-allocs 1
    tests/build/vk_bench.exe --bench churn --op map_readback  --count 32 --frames 400 --track-allocs 1

.PARAMETER FailOnAllocs
Exit 2 when any suite's allocations per frame exceed `-MaxAllocsPerFrame`.

.EXAMPLE
tools/measure_allocs.ps1
tools/measure_allocs.ps1 -Suite bundle,write_buffer -Frames 400 -Runs 1
tools/measure_allocs.ps1 -FailOnAllocs
#>
param(
    [string[]]$Suite = @('bundle', 'bundle_shared', 'manual', 'manual_shared', 'write_buffer', 'dyn_offset', 'multipass', 'compute', 'parallel'),
    [int]$Runs = 2,
    [int]$Frames = 1200,
    [int]$Count = 5000,
    [int]$Passes = 8,
    [int]$Threads = 4,
    [int]$Top = 6,
    [double]$MaxAllocsPerFrame = 0.25,
    [switch]$FailOnAllocs,
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$prevCulture = [Globalization.CultureInfo]::CurrentCulture
[Globalization.CultureInfo]::CurrentCulture = [Globalization.CultureInfo]::InvariantCulture

$repoRoot = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $repoRoot 'tests\build'
if (-not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

$exe = Join-Path $outDir 'vk_bench.exe'

$workloads = @{
    bundle        = @{ Args = @('--bench', 'draw_overhead', '--count', "$Count", '--bundle', '1', '--shared', '0', '--frames', "$Frames"); Label = "draw_overhead [bundle, n=$Count]" }
    bundle_shared = @{ Args = @('--bench', 'draw_overhead', '--count', "$Count", '--bundle', '1', '--shared', '1', '--frames', "$Frames"); Label = "draw_overhead [bundle+shared, n=$Count]" }
    manual        = @{ Args = @('--bench', 'draw_overhead', '--count', "$Count", '--bundle', '0', '--shared', '0', '--frames', "$Frames"); Label = "draw_overhead [manual, n=$Count]" }
    manual_shared = @{ Args = @('--bench', 'draw_overhead', '--count', "$Count", '--bundle', '0', '--shared', '1', '--frames', "$Frames"); Label = "draw_overhead [manual+shared, n=$Count]" }
    write_buffer  = @{ Args = @('--bench', 'dynamic_uniforms', '--count', '2000', '--shared', '0', '--frames', "$Frames"); Label = 'dynamic_uniforms [write_buffer, n=2000]' }
    dyn_offset    = @{ Args = @('--bench', 'dynamic_uniforms', '--count', '2000', '--shared', '1', '--frames', "$Frames"); Label = 'dynamic_uniforms [dyn_offset, n=2000]' }
    multipass     = @{ Args = @('--bench', 'multipass', '--passes', "$Passes", '--count', '500', '--frames', "$Frames"); Label = "multipass [passes=$Passes x 500 draws]" }
    compute       = @{ Args = @('--bench', 'compute', '--count', '1000', '--frames', "$Frames"); Label = 'compute [1000 dispatches/pass]' }
    parallel      = @{ Args = @('--bench', 'parallel_encode', '--threads', "$Threads", '--count', '4000', '--frames', "$Frames"); Label = "parallel_encode [threads=$Threads, n=4000]" }
}

if (-not $SkipBuild) {
    Write-Host '=== Build vk_bench (release) ===' -ForegroundColor Cyan
    $flags = @('build', (Join-Path $repoRoot 'tests\bench'), "-out:$exe", '-o:speed', '-disable-assert', '-no-bounds-check')
    & odin @flags
    if ($LASTEXITCODE -ne 0) {
        throw "build failed with exit code $LASTEXITCODE"
    }
}

if (-not (Test-Path -LiteralPath $exe)) {
    throw "missing benchmark executable: $exe"
}

function Invoke-Bench {
    param([string[]]$ProgramArgs)
    $output = & $exe @ProgramArgs 2>&1 | Out-String
    return $output
}

function Get-Sites {
    param([string]$Output, [int]$Limit)
    $sites = @()
    $pattern = 'MEASURE-GPU-ALLOC-SITE allocs=(\d+) resizes=(\d+) bytes=(\d+)\s+(\S+):(\d+)'
    foreach ($match in [regex]::Matches($Output, $pattern)) {
        $sites += [pscustomobject]@{
            Allocs  = [int64]$match.Groups[1].Value
            Resizes = [int64]$match.Groups[2].Value
            Bytes   = [int64]$match.Groups[3].Value
            File    = $match.Groups[4].Value
            Line    = [int]$match.Groups[5].Value
        }
    }
    return $sites | Select-Object -First $Limit
}

# Calibration: the tracker must see the one allocation its self-test performs.
# A silent zero here means the instrument, not the code under test.
Write-Host '=== calibration (alloc-selftest) ===' -ForegroundColor Cyan
$calibration = Invoke-Bench @('--bench', 'draw_overhead', '--count', '100', '--frames', '24', '--track-allocs', '1', '--alloc-selftest', '1', '--alloc-top', '1')
$selfTest = [regex]::Match($calibration, 'ALLOC-SELFTEST after allocs=(\d+) sites=(\d+)')
if (-not $selfTest.Success -or [int]$selfTest.Groups[1].Value -lt 1) {
    throw 'allocation tracker calibration failed: the self-test allocation was not counted'
}
Write-Host '  tracker is live and counting' -ForegroundColor Green

$failed = $false

foreach ($name in $Suite) {
    if (-not $workloads.ContainsKey($name)) {
        throw "unknown suite '$name'"
    }
    $workload = $workloads[$name]
    Write-Host "=== $($workload.Label) ($Runs runs) ===" -ForegroundColor Cyan

    $best = $null
    for ($run = 0; $run -lt $Runs; $run++) {
        $runArgs = @()
        $runArgs += $workload.Args
        $runArgs += @('--track-allocs', '1', '--alloc-top', "$Top")
        $output = Invoke-Bench $runArgs

        $match = [regex]::Match($output, 'MEASURE-GPU-ALLOC suite=(\S+) frames=(\d+) allocs=(\d+) allocs_per_frame=([0-9.]+) alloc_bytes=(\d+) frees=(\d+) resizes=(\d+)')
        if (-not $match.Success) {
            throw "no MEASURE-GPU-ALLOC line for suite '$name'"
        }

        $record = [pscustomobject]@{
            Frames   = [int]$match.Groups[2].Value
            Allocs   = [int64]$match.Groups[3].Value
            PerFrame = [double]::Parse($match.Groups[4].Value, [Globalization.CultureInfo]::InvariantCulture)
            Bytes    = [int64]$match.Groups[5].Value
            Frees    = [int64]$match.Groups[6].Value
            Resizes  = [int64]$match.Groups[7].Value
            Sites    = @(Get-Sites -Output $output -Limit $Top)
        }
        if ($null -eq $best -or $record.Allocs -lt $best.Allocs) {
            $best = $record
        }
    }

    $status = 'ok'
    if ($best.PerFrame -gt $MaxAllocsPerFrame) {
        $status = 'CHURN'
        $failed = $true
    }

    Write-Host ("  allocs={0} over {1} frames  per_frame={2:F2}  bytes={3}  resizes={4}  [{5}]" -f `
        $best.Allocs, $best.Frames, $best.PerFrame, $best.Bytes, $best.Resizes, $status)

    foreach ($site in $best.Sites) {
        Write-Host ("    {0,6} allocs {1,6} resizes {2,10} bytes  {3}:{4}" -f `
            $site.Allocs, $site.Resizes, $site.Bytes, $site.File, $site.Line)
    }
}

if ($FailOnAllocs -and $failed) {
    Write-Host "=== FAIL: allocations per frame exceeded $MaxAllocsPerFrame ===" -ForegroundColor Red
    exit 2
}

Write-Host 'Done.' -ForegroundColor Green

[Globalization.CultureInfo]::CurrentCulture = $prevCulture

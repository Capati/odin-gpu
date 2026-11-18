<#
.SYNOPSIS
Headless Vulkan backend benchmark runner with optional paired interleaved A/B comparison.

.DESCRIPTION
Builds `tests/bench` in release mode (`-o:speed -disable-assert -no-bounds-check`)
and runs either a full suite of Vulkan backend benchmarks or a specific benchmark
workload (`draw_overhead`, `dynamic_uniforms`, `multipass`, `compute`, `parallel_encode`),
reporting median-of-medians, spread, and paired A/B speedup when `-BaselineExe` is supplied.
#>
param(
    [string[]]$Suite = @('bundle', 'bundle_shared', 'manual', 'manual_shared', 'write_buffer', 'dyn_offset', 'multipass', 'compute', 'parallel'),
    [int]$Runs = 5,
    [int]$Frames = 400,
    [int]$Count = 5000,
    [int]$Passes = 8,
    [int]$Threads = 4,
    [string]$BaselineExe = '',
    [switch]$SaveBaseline,
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
$baselineDefault = Join-Path $outDir 'vk_bench_baseline.exe'

if (-not $SkipBuild) {
    Write-Host '=== Build vk_bench (release) ===' -ForegroundColor Cyan
    $flags = @('build', (Join-Path $repoRoot 'tests\bench'), "-out:$exe", '-o:speed', '-disable-assert', '-no-bounds-check')
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $buildOut = & odin @flags 2>&1
    $ErrorActionPreference = $prevEap
    if ($LASTEXITCODE -ne 0) {
        throw "build failed:`n$($buildOut | Out-String)"
    }
    Write-Host "  ok  $exe" -ForegroundColor Green
    if ($SaveBaseline) {
        Copy-Item -LiteralPath $exe -Destination $baselineDefault -Force
        Write-Host "  saved baseline -> $baselineDefault" -ForegroundColor Green
    }
    Write-Host ''
}

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

function Invoke-BenchOnce {
    param([string]$Binary, [string[]]$RunArgs)
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = & $Binary @RunArgs 2>&1 | Out-String
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
    if ($code -ne 0) {
        throw "vk_bench failed ($Binary):`n$out"
    }
    $m = [regex]::Match($out, 'MEASURE-GPU (\S+) (\d+) ([0-9.,]+) ([0-9.,]+) (\d+)')
    if (-not $m.Success) {
        throw "missing MEASURE-GPU line:`n$out"
    }
    $median = [double]::Parse(($m.Groups[3].Value -replace ',', '.'), [Globalization.CultureInfo]::InvariantCulture)
    $p95 = [double]::Parse(($m.Groups[4].Value -replace ',', '.'), [Globalization.CultureInfo]::InvariantCulture)
    $s = [regex]::Match($out, 'MEASURE-GPU-QUARTERS[^\r\n]*?(\S+)\s*$', 'Multiline')
    $settled = ($s.Success -and $s.Groups[1].Value -eq 'settled')
    return [pscustomobject]@{
        Median  = $median
        P95     = $p95
        Settled = $settled
    }
}

function Get-StatsSummary {
    param([object[]]$RunList)
    $meds = @($RunList | ForEach-Object { $_.Median } | Sort-Object)
    $mid = $meds[[int]($meds.Count / 2)]
    $min = $meds[0]
    $max = $meds[$meds.Count - 1]
    $spread = if ($min -gt 0) { ($max - $min) / $min * 100.0 } else { 0.0 }
    return [pscustomobject]@{
        Median = $mid
        Min    = $min
        Max    = $max
        Spread = $spread
    }
}

$hasBaseline = ($BaselineExe -ne '' -and (Test-Path -LiteralPath $BaselineExe))

foreach ($key in $Suite) {
    $w = $workloads[$key]
    if (-not $w) { throw "unknown suite item '$key'" }

    Write-Host ("=== {0} ({1} runs) ===" -f $w.Label, $Runs) -ForegroundColor Cyan
    $curSamples = New-Object System.Collections.Generic.List[object]
    $baseSamples = New-Object System.Collections.Generic.List[object]

    for ($r = 1; $r -le $Runs; $r++) {
        if ($hasBaseline) {
            if ($r % 2 -eq 1) {
                $bRes = Invoke-BenchOnce -Binary $BaselineExe -RunArgs $w.Args
                $cRes = Invoke-BenchOnce -Binary $exe -RunArgs $w.Args
            } else {
                $cRes = Invoke-BenchOnce -Binary $exe -RunArgs $w.Args
                $bRes = Invoke-BenchOnce -Binary $BaselineExe -RunArgs $w.Args
            }
            $baseSamples.Add($bRes)
            $curSamples.Add($cRes)
            $delta = ($cRes.Median - $bRes.Median) / $bRes.Median * 100.0
            Write-Host ("  run {0}/{1}  base={2,8:F1} us  curr={3,8:F1} us  delta={4,6:F2}%" -f
                $r, $Runs, $bRes.Median, $cRes.Median, $delta)
        } else {
            $cRes = Invoke-BenchOnce -Binary $exe -RunArgs $w.Args
            $curSamples.Add($cRes)
            Write-Host ("  run {0}/{1}  median={2,8:F1} us  p95={3,8:F1} us  {4}" -f
                $r, $Runs, $cRes.Median, $cRes.P95, ($(if ($cRes.Settled) { 'settled' } else { 'NOT-SETTLED' })))
        }
    }

    $cSum = Get-StatsSummary -RunList $curSamples.ToArray()
    if ($hasBaseline) {
        $bSum = Get-StatsSummary -RunList $baseSamples.ToArray()
        $pct = ($cSum.Median - $bSum.Median) / $bSum.Median * 100.0
        $color = if ($pct -lt -1.0) { 'Green' } elseif ($pct -gt 1.0) { 'Yellow' } else { 'White' }
        Write-Host ("  SUMMARY: base={0,8:F1} us (spread {1:F1}%) -> curr={2,8:F1} us (spread {3:F1}%)  [{4,6:F2}%]" -f
            $bSum.Median, $bSum.Spread, $cSum.Median, $cSum.Spread, $pct) -ForegroundColor $color
    } else {
        Write-Host ("  SUMMARY: median={0,8:F1} us  min={1,8:F1}  max={2,8:F1}  spread={3:F1}%" -f
            $cSum.Median, $cSum.Min, $cSum.Max, $cSum.Spread) -ForegroundColor Green
    }
    Write-Host ''
}

[Globalization.CultureInfo]::CurrentCulture = $prevCulture

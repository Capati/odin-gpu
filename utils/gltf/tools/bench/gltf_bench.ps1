<#
.SYNOPSIS
Builds and runs the glTF initial-load benchmark: vendor:cgltf vs utils/gltf.

.DESCRIPTION
Compiles utils/gltf/tools/bench in release (odin -o:size -disable-assert -no-bounds-check),
then runs it against a model file. The benchmark loads the model with both
parsers N times (one warmup load per parser is discarded) and reports
min/median/mean/max per phase: parse, load_buffers, and the two combined.

.PARAMETER Model
Path to the .glb/.gltf to load. Defaults to the DamagedHelmet model used by
gltf_compare.

.PARAMETER Iterations
Timed iterations per parser (default 30).

.PARAMETER SkipBuild
Reuse an existing tests\build\gltf_bench.exe.

.EXAMPLE
.\utils\gltf\tools\bench\gltf_bench.ps1
Release build, 30 iterations against DamagedHelmet.

.EXAMPLE
.\utils\gltf\tools\bench\gltf_bench.ps1 -Model examples\build\assets\models\Sponza.glb -Iterations 100
#>
[CmdletBinding()]
param(
    [string]$Model = 'examples/build/assets/models/DamagedHelmet.glb',
    [int]$Iterations = 30,
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Continue'
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$outDir = Join-Path $repoRoot 'tests/build'
$exe = Join-Path $outDir 'gltf_bench.exe'

if (-not $SkipBuild) {
    Write-Host "=== Build (release)" -ForegroundColor Cyan
    if (-not (Test-Path -LiteralPath $outDir)) {
        New-Item -ItemType Directory -Path $outDir | Out-Null
    }
    # CWD must be the repository root: the default model path is resolved from there.
    Push-Location -LiteralPath $repoRoot
    try {
        $out = & odin build (Join-Path 'utils/gltf/tools' 'bench') `
            -o:size -disable-assert -no-bounds-check `
            -out:$exe 2>&1
        $code = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }
    if ($code -ne 0) {
        $out | ForEach-Object { Write-Host $_ }
        Write-Host "build failed (exit $code)" -ForegroundColor Red
        exit $code
    }
    Write-Host "  ok    $exe" -ForegroundColor Green
}
elseif (-not (Test-Path -LiteralPath $exe)) {
    Write-Host "SkipBuild set but $exe does not exist" -ForegroundColor Red
    exit 1
}

Write-Host ''
Write-Host "=== Benchmark" -ForegroundColor Cyan
# The model path is relative to the repository root, so run from there.
Push-Location -LiteralPath $repoRoot
try {
    & $exe $Model $Iterations
    $code = $LASTEXITCODE
}
finally {
    Pop-Location
}

if ($code -ne 0) {
    Write-Host "benchmark failed (exit $code)" -ForegroundColor Red
}
exit $code

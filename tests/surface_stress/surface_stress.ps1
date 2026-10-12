<#
.SYNOPSIS
Builds and runs the multi-threaded Vulkan surface lifecycle stress test.

.DESCRIPTION
Standalone test under tests/surface_stress (no example framework): it creates
its own window, device and surface directly. Worker threads repeatedly
unconfigure and reconfigure the Vulkan surface while the main thread acquires,
renders, submits, and presents frames. The app exits on its own and reports an
explicit PASS line.
#>
[CmdletBinding()]
param(
    [int]$TimeoutSeconds = 120
)

$ErrorActionPreference = 'Continue'
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$testDir = $PSScriptRoot
$buildDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'build'
$target = 'surface_stress'
$exe = Join-Path $buildDir "$target.exe"
$stdout = Join-Path $buildDir "$target.stdout.txt"
$stderr = Join-Path $buildDir "$target.stderr.txt"

New-Item -ItemType Directory -Path $buildDir -Force | Out-Null

Write-Host '=== Build Vulkan surface stress target'
Push-Location -LiteralPath $repoRoot
try {
    # Package path, not a file: tests/surface_stress is its own package.
    $buildOutput = & odin build (Join-Path 'tests' 'surface_stress') -debug -out:$exe 2>&1
    $buildCode = $LASTEXITCODE
    $buildOutput | ForEach-Object { Write-Host $_ }
}
finally {
    Pop-Location
}
if ($buildCode -ne 0 -or -not (Test-Path -LiteralPath $exe)) {
    throw "Failed to build $target (exit $buildCode)"
}

Remove-Item -LiteralPath $stdout, $stderr -Force -ErrorAction SilentlyContinue
Write-Host "=== Run $target (timeout ${TimeoutSeconds}s)"
$process = Start-Process -FilePath $exe -WorkingDirectory $repoRoot -PassThru `
    -RedirectStandardOutput $stdout -RedirectStandardError $stderr
if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    throw "$target timed out; logs: $stdout, $stderr"
}
$process.Refresh()
$exitCode = $process.ExitCode

$output = @()
if (Test-Path -LiteralPath $stdout) { $output += Get-Content -LiteralPath $stdout }
if (Test-Path -LiteralPath $stderr) { $output += Get-Content -LiteralPath $stderr }
$output | ForEach-Object { Write-Host $_ }
if ($null -ne $exitCode -and $exitCode -ne 0) {
    throw "$target exited with code $exitCode; logs: $stdout, $stderr"
}
if (-not ($output -match 'SURFACE_STRESS PASS frames=\d+ operations=\d+ no_draws=\d+ abandoned_encoders=\d+ abandoned_command_buffers=\d+')) {
    throw "$target exited without its PASS marker; logs: $stdout, $stderr"
}
if ($output -match 'VUID-|SYNC-|runtime assertion|panic:') {
    throw "$target emitted a Vulkan validation/runtime error; logs: $stdout, $stderr"
}

Write-Host 'SURFACE STRESS PASSED' -ForegroundColor Green

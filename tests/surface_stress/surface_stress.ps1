<#
.SYNOPSIS
Builds and runs the multi-threaded Vulkan surface lifecycle stress test.

.DESCRIPTION
Runs a real window/swapchain test. Worker threads repeatedly unconfigure and
reconfigure the Vulkan surface while the main thread acquires, renders, submits,
and presents frames. The app exits on its own and reports an explicit PASS line.
#>
[CmdletBinding()]
param(
    [int]$TimeoutSeconds = 120
)

$ErrorActionPreference = 'Continue'
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$examplesDir = Join-Path $repoRoot 'examples'
$buildDir = Join-Path $examplesDir 'build'
$logDir = Join-Path $buildDir 'harness'
$target = 'surface_stress'
$exe = Join-Path $buildDir "$target.exe"
$stdout = Join-Path $logDir "$target.stdout.txt"
$stderr = Join-Path $logDir "$target.stderr.txt"

New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
New-Item -ItemType Directory -Path $logDir -Force | Out-Null

Write-Host '=== Build Vulkan surface stress target'
Push-Location -LiteralPath $examplesDir
try {
    $buildOutput = cmd /c "build.bat $target" 2>&1
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
$process = Start-Process -FilePath $exe -WorkingDirectory $buildDir -PassThru `
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

# Insomnia Tweaks launcher
# Builds the customised WinUtil single-file script from the included source,
# then launches it. Run this from an Administrator PowerShell session.

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$compileScript = Join-Path $repoRoot 'Compile.ps1'
$compiledScript = Join-Path $repoRoot 'winutil.ps1'

if (-not (Test-Path -LiteralPath $compileScript -PathType Leaf)) {
    throw "Compile.ps1 was not found. Keep this launcher in the Insomnia-Tweaks repository root."
}

Push-Location $repoRoot
try {
    Write-Host "Building Insomnia Tweaks..." -ForegroundColor Magenta
    & $compileScript

    if (-not (Test-Path -LiteralPath $compiledScript -PathType Leaf)) {
        throw "Build failed: winutil.ps1 was not generated."
    }

    Write-Host "Starting Insomnia Tweaks..." -ForegroundColor Magenta
    & $compiledScript
}
finally {
    Pop-Location
}

# Insomnia Tweaks bootstrap installer
# Run from an elevated PowerShell window:
# irm https://raw.githubusercontent.com/glockinhand394/Insomnia-Tweaks/main/Install-InsomniaTweaks.ps1 | iex

$ErrorActionPreference = "Stop"

$repoZip = "https://github.com/glockinhand394/Insomnia-Tweaks/archive/refs/heads/main.zip"
$workRoot = Join-Path $env:TEMP "Insomnia-Tweaks-Setup"
$zipPath = Join-Path $workRoot "Insomnia-Tweaks-main.zip"
$extractPath = Join-Path $workRoot "Extracted"

try {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        throw "Please open PowerShell as Administrator, then run the install command again."
    }

    Write-Host ""
    Write-Host "  INSOMNIA TWEAKS" -ForegroundColor Magenta
    Write-Host "  Downloading the latest version from GitHub..." -ForegroundColor Gray

    if (Test-Path $workRoot) {
        Remove-Item $workRoot -Recurse -Force
    }

    New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
    Invoke-WebRequest -Uri $repoZip -OutFile $zipPath
    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force

    $launcher = Get-ChildItem -LiteralPath $extractPath -Filter "InsomniaTweaks.ps1" -Recurse -File |
        Select-Object -First 1

    if (-not $launcher) {
        throw "InsomniaTweaks.ps1 was not found in the downloaded repository. Check that the launcher is committed to the main branch."
    }

    Write-Host "  Download complete. Starting Insomnia Tweaks..." -ForegroundColor Green
    & $launcher.FullName
}
catch {
    Write-Host ""
    Write-Host "[Insomnia Tweaks] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "If the repository is private, make it public or use an authenticated download method." -ForegroundColor Yellow
}

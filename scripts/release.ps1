# One-command release: bump version -> commit -> tag -> push -> GitHub Actions builds APK + Release.
# Usage:
#   .\scripts\release.ps1 -Version 0.1.6 -Notes "修复某某问题"
#   .\scripts\release.ps1 -Version 0.1.5 -Notes "补发 v0.1.5" -SkipVersionBump  # re-tag existing version

param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [string]$Notes = "",

    [switch]$SkipVersionBump
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Pubspec = Join-Path $Root "mobile\pubspec.yaml"
$Tag = "v$Version"

Set-Location $Root

if (-not (Test-Path $Pubspec)) {
    throw "pubspec not found: $Pubspec"
}

function Get-PubspecVersion {
    $line = Select-String -Path $Pubspec -Pattern '^version:' | Select-Object -First 1
    if (-not $line) { throw "version line missing in pubspec.yaml" }
    $raw = ($line.Line -replace '^version:\s*', '').Trim()
    $parts = $raw -split '\+'
    return @{ Name = $parts[0]; Build = [int]$parts[1] }
}

function Set-PubspecVersion {
    param([string]$Name, [int]$Build)
    $content = Get-Content $Pubspec -Raw
    $updated = $content -replace '(?m)^version:.*$', "version: ${Name}+${Build}"
    Set-Content -Path $Pubspec -Value $updated -NoNewline
}

$current = Get-PubspecVersion
$build = if ($SkipVersionBump -and $current.Name -eq $Version) { $current.Build } else { $current.Build + 1 }

if (-not $SkipVersionBump) {
    Set-PubspecVersion -Name $Version -Build $build
    Write-Host "pubspec -> ${Version}+${build}" -ForegroundColor Cyan
}

$commitMsg = if ($Notes) { "Release ${Tag}: ${Notes}" } else { "Release ${Tag}" }
git diff --cached --quiet
$hasStaged = $LASTEXITCODE -ne 0
if ($hasStaged) {
    $env:GIT_AUTHOR_NAME = "Th1ry"
    $env:GIT_AUTHOR_EMAIL = "Th1ry@users.noreply.github.com"
    $env:GIT_COMMITTER_NAME = "Th1ry"
    $env:GIT_COMMITTER_EMAIL = "Th1ry@users.noreply.github.com"
    git commit -m $commitMsg
}

Write-Host "Pushing main..." -ForegroundColor Cyan
git push origin main

if (git rev-parse $Tag 2>$null) {
    Write-Host "Tag $Tag exists locally, deleting..." -ForegroundColor Yellow
    git tag -d $Tag | Out-Null
}
if (git ls-remote --tags origin $Tag 2>$null | Select-String $Tag) {
    Write-Host "Remote tag $Tag exists. Delete on GitHub first or use a new version." -ForegroundColor Red
    exit 1
}

git tag -a $Tag -m $(if ($Notes) { $Notes } else { "Release $Version" })
Write-Host "Pushing tag $Tag -> GitHub Actions will build APK + create Release..." -ForegroundColor Cyan
git push origin $Tag

Write-Host ""
Write-Host "Done. Open Actions to watch:" -ForegroundColor Green
Write-Host "https://github.com/Th1ry/alpaca.app/actions"
Write-Host ""
Write-Host "When finished, OTA manifest updates automatically on main."

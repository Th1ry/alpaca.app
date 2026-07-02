# One-command release: bump version -> commit -> tag -> push -> GitHub Actions builds APK + Release.
# Usage:
#   .\scripts\release.ps1 -Version 0.1.6 -Notes "修复某某问题"
#   .\scripts\release.ps1 -Version 0.1.5 -Notes "补发 v0.1.5" -SkipVersionBump

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

function Invoke-Git {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
    & git @Args
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Args -join ' ') failed (exit $LASTEXITCODE)"
    }
}

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

$env:GIT_AUTHOR_NAME = "Th1ry"
$env:GIT_AUTHOR_EMAIL = "Th1ry@users.noreply.github.com"
$env:GIT_COMMITTER_NAME = "Th1ry"
$env:GIT_COMMITTER_EMAIL = "Th1ry@users.noreply.github.com"

$current = Get-PubspecVersion
$build = if ($SkipVersionBump -and $current.Name -eq $Version) { $current.Build } else { $current.Build + 1 }

if (-not $SkipVersionBump) {
    Set-PubspecVersion -Name $Version -Build $build
    Write-Host "pubspec -> ${Version}+${build}" -ForegroundColor Cyan
    Invoke-Git add $Pubspec
    $commitMsg = if ($Notes) { "Release ${Tag}: ${Notes}" } else { "Release ${Tag}" }
    Invoke-Git commit -m $commitMsg
    Write-Host "Pushing main..." -ForegroundColor Cyan
    Invoke-Git push origin main
} else {
    Write-Host "SkipVersionBump: main push skipped (no code change)." -ForegroundColor Yellow
}

$remoteTag = git ls-remote --tags origin "refs/tags/$Tag" 2>$null
if ($remoteTag) {
    throw "Remote tag $Tag already exists on GitHub. Use a new version or delete the tag first."
}

if (git rev-parse $Tag 2>$null) {
    Write-Host "Removing local tag $Tag..." -ForegroundColor Yellow
    Invoke-Git tag -d $Tag
}

$tagMsg = if ($Notes) { $Notes } else { "Release $Version" }
Write-Host "Creating tag $Tag..." -ForegroundColor Cyan
Invoke-Git tag -a $Tag -m $tagMsg

Write-Host "Pushing tag $Tag (this triggers GitHub Actions)..." -ForegroundColor Cyan
Invoke-Git push origin $Tag

Write-Host ""
Write-Host "Done. Watch build progress:" -ForegroundColor Green
Write-Host "https://github.com/Th1ry/alpaca.app/actions"
Write-Host ""
Write-Host "Release + OTA manifest update in ~5-10 min."

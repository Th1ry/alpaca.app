# Install Visual Studio 2022 Build Tools with C++ workload (for flutter run -d windows)
$ErrorActionPreference = "Continue"

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vswhere) {
    $existing = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
    if ($existing) {
        Write-Host "Visual Studio C++ tools already installed: $existing"
        exit 0
    }
}

Write-Host "Installing VS 2022 Build Tools (C++ workload). This may take 10-20 minutes..."
$winget = Get-Command winget -ErrorAction SilentlyContinue
if ($winget) {
    winget install --id Microsoft.VisualStudio.2022.BuildTools -e --accept-package-agreements --accept-source-agreements --override "--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
} else {
  Write-Host "winget not found. Install manually: https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022"
  Write-Host "Select: Desktop development with C++"
  exit 1
}

Write-Host "VS Build Tools install finished (or already present)."

# Install Android SDK command-line tools for Flutter (no full Android Studio required)
$ErrorActionPreference = "Stop"
$SdkRoot = "$env:LOCALAPPDATA\Android\Sdk"
$ZipUrl = "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"
$ZipPath = "$env:TEMP\cmdline-tools.zip"
$ToolsDir = "$SdkRoot\cmdline-tools\latest"

# JDK required by Android SDK / Flutter
$java = Get-Command java -ErrorAction SilentlyContinue
if (-not $java) {
    Write-Host "Installing Microsoft OpenJDK 17..."
    winget install --id Microsoft.OpenJDK.17 -e --accept-package-agreements --accept-source-agreements
}

Write-Host "Android SDK root: $SdkRoot"
New-Item -ItemType Directory -Force -Path $SdkRoot | Out-Null

if (-not (Test-Path "$ToolsDir\bin\sdkmanager.bat")) {
    Write-Host "Downloading command-line tools..."
    if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
    curl.exe -L $ZipUrl -o $ZipPath
    if (-not (Test-Path $ZipPath)) { throw "Download failed: $ZipPath" }
    $Extract = "$env:TEMP\android-cmdline"
    if (Test-Path $Extract) { Remove-Item -Recurse -Force $Extract }
    Expand-Archive -Path $ZipPath -DestinationPath $Extract -Force
    New-Item -ItemType Directory -Force -Path (Split-Path $ToolsDir) | Out-Null
    if (Test-Path $ToolsDir) { Remove-Item -Recurse -Force $ToolsDir }
    Move-Item "$Extract\cmdline-tools" $ToolsDir
    Remove-Item -Recurse -Force $Extract
    Remove-Item $ZipPath -Force -ErrorAction SilentlyContinue
}

$env:ANDROID_HOME = $SdkRoot
$env:ANDROID_SDK_ROOT = $SdkRoot
$sdkmanager = "$ToolsDir\bin\sdkmanager.bat"

Write-Host "Installing SDK packages (may take several minutes)..."
$yes = ("y`n" * 30)
$yes | & $sdkmanager --sdk_root=$SdkRoot "platform-tools" "platforms;android-35" "build-tools;35.0.0" "cmdline-tools;latest" 2>&1 | Write-Host

# User env vars
[Environment]::SetEnvironmentVariable("ANDROID_HOME", $SdkRoot, "User")
[Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $SdkRoot, "User")
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$platformTools = "$SdkRoot\platform-tools"
if ($userPath -notlike "*$platformTools*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$platformTools", "User")
}

$flutterBin = "C:\Users\XOS\flutter\bin"
if (Test-Path "$flutterBin\flutter.bat") {
    & "$flutterBin\flutter.bat" config --android-sdk $SdkRoot
    Write-Host "Flutter android-sdk configured."
}

Write-Host "Done. Open a NEW terminal and run: flutter doctor --android-licenses"

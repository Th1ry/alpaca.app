# Generate a release keystore for GitHub Actions OTA signing.
# Run once, then add the printed secrets to GitHub repo Settings -> Secrets -> Actions.

$ErrorActionPreference = "Stop"
$androidDir = Join-Path $PSScriptRoot "..\mobile\android" | Resolve-Path
$keystore = Join-Path $androidDir "release.keystore"
$keytool = Get-Command keytool -ErrorAction SilentlyContinue
if (-not $keytool) {
    $jdkKeytool = Get-ChildItem "C:\Program Files\Microsoft\jdk-*\bin\keytool.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($jdkKeytool) { $keytool = $jdkKeytool.FullName } else { throw "keytool not found. Install JDK 17 first." }
} else {
    $keytool = $keytool.Source
}

$storePass = Read-Host "Keystore password (remember this)"
$keyPass = Read-Host "Key password (Enter to reuse keystore password)" 
if ([string]::IsNullOrWhiteSpace($keyPass)) { $keyPass = $storePass }
$alias = "alpaca-release"

if (Test-Path $keystore) {
    throw "Already exists: $keystore"
}

& $keytool -genkeypair -v `
    -keystore $keystore `
    -alias $alias `
    -keyalg RSA -keysize 2048 -validity 10000 `
    -storepass $storePass -keypass $keyPass `
    -dname "CN=Alpaca Options, OU=Mobile, O=Alpaca, C=US"

Write-Host ""
Write-Host "Keystore created: $keystore"
Write-Host ""
Write-Host "Add these GitHub Actions secrets (repo Settings -> Secrets -> Actions):"
Write-Host "  ANDROID_KEYSTORE_PASSWORD = $storePass"
Write-Host "  ANDROID_KEY_PASSWORD      = $keyPass"
Write-Host "  ANDROID_KEY_ALIAS         = $alias"
Write-Host "  ANDROID_KEYSTORE_BASE64   = (copy the line below)"
Write-Host ""
[Convert]::ToBase64String([IO.File]::ReadAllBytes($keystore))

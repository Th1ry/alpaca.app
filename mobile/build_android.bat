@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo 正在编译 Android APK（直连 Alpaca，无需本地后端）...
flutter build apk --release
if errorlevel 1 (
  echo 编译失败
  pause
  exit /b 1
)

echo.
echo 完成: build\app\outputs\flutter-apk\app-release.apk
echo 安装到手机后，在 App 设置里填写 Alpaca API Key 即可使用。
pause

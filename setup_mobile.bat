@echo off
cd /d "%~dp0mobile"
where flutter >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Flutter SDK not found.
  echo Install from https://docs.flutter.dev/get-started/install/windows
  pause
  exit /b 1
)
if not exist android (
  echo Creating Flutter platform folders...
  flutter create . --org com.alpaca.options --platforms android,ios,windows,web
)
flutter pub get
echo.
echo Run on device/emulator:
echo   flutter run
echo.
echo API URL for physical device: use your PC LAN IP in Settings
pause

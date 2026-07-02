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
if not exist "..\releases" mkdir "..\releases"
for /f "tokens=2 delims=:+" %%v in ('findstr /r "^version:" pubspec.yaml') do set VER=%%v
copy /y "build\app\outputs\flutter-apk\app-release.apk" "..\releases\alpaca-options-app-v%VER%.apk" >nul
echo 已复制: ..\releases\alpaca-options-app-v%VER%.apk
echo.
echo 重要: 必须重新安装 APK 到手机，仅关闭再打开 App 不会更新界面。
echo 安装后可在 设置 页底部查看版本号确认是否为新版本。
pause

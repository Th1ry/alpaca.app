@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo ========================================
echo  Alpaca Options App - Full Setup
echo ========================================
echo.

echo [1/4] Backend Python deps...
cd backend
if not exist .env (
    if exist .env.example copy .env.example .env
    echo Created backend\.env - add your Alpaca keys if missing.
)
py -3 -m pip install -q -r requirements.txt
cd ..

echo [2/4] Flutter pub get...
cd mobile
call C:\Users\XOS\flutter\bin\flutter.bat pub get
cd ..

echo [3/4] Android SDK (command-line tools)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\install_android_sdk.ps1"
if errorlevel 1 echo Android SDK install had issues - see output above.

echo [4/4] Visual Studio Build Tools (C++ for Windows desktop)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\install_vs_build_tools.ps1"
if errorlevel 1 echo VS Build Tools install had issues - see output above.

echo.
echo Accepting Android licenses...
set "ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk"
set "ANDROID_SDK_ROOT=%ANDROID_HOME%"
echo y| C:\Users\XOS\flutter\bin\flutter.bat doctor --android-licenses >nul 2>&1

echo.
C:\Users\XOS\flutter\bin\flutter.bat doctor
echo.
echo Setup complete. Run start_all.bat to launch backend + app.
pause

@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo 编译前端（UI 改动需重新编译）...
cd /d "%~dp0mobile"
C:\Users\XOS\flutter\bin\flutter.bat build windows --release
if errorlevel 1 (
  echo 编译失败
  pause
  exit /b 1
)
cd /d "%~dp0"

echo 重启后端...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":8000 " ^| findstr "LISTENING"') do (
  taskkill /PID %%a /F >nul 2>&1
)
start "Alpaca Backend" cmd /k "cd /d "%~dp0backend" && py -3 run.py"
ping 127.0.0.1 -n 3 >nul

set EXE=%~dp0mobile\build\windows\x64\runner\Release\alpaca_options_app.exe
taskkill /IM alpaca_options_app.exe /F >nul 2>&1
start "" "%EXE%"
echo 已启动（已重新编译 + 后端）

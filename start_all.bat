@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo 检查后端...
netstat -ano | findstr ":8000 " | findstr "LISTENING" >nul
if errorlevel 1 (
  echo 启动后端...
  start "Alpaca Backend" cmd /k "cd /d "%~dp0backend" && py -3 run.py"
  timeout /t 3 /nobreak >nul
) else (
  echo 后端已在运行
)

set EXE=%~dp0mobile\build\windows\x64\runner\Release\alpaca_options_app.exe
if not exist "%EXE%" (
  echo 首次运行，正在编译（约 30 秒）...
  cd /d "%~dp0mobile"
  C:\Users\XOS\flutter\bin\flutter.bat build windows --release
  cd /d "%~dp0"
)

if not exist "%EXE%" (
  echo.
  echo 桌面版编译失败，尝试用 Chrome 打开...
  cd /d "%~dp0mobile"
  start "Alpaca Web" cmd /k "C:\Users\XOS\flutter\bin\flutter.bat run -d chrome"
  pause
  exit /b 1
)

echo 启动应用...
start "" "%EXE%"
echo 完成。若窗口未出现，请双击 start_app.bat 重试。
timeout /t 3 /nobreak >nul

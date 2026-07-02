@echo off
chcp 65001 >nul
cd /d "%~dp0mobile"
C:\Users\XOS\flutter\bin\flutter.bat build windows --release
if errorlevel 1 (
  echo 编译失败
  pause
  exit /b 1
)
echo 编译完成
pause

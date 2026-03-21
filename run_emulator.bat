@echo off
title Hunting Signals - Emulator

echo ================================
echo  Hunting Signals - Android Run
echo ================================
echo.

SET FLUTTER=D:\flutter\bin\flutter.bat
SET ANDROID_SDK=C:\Users\hp\AppData\Local\Android\Sdk
SET JAVA_HOME=C:\Program Files\Android\Android Studio\jbr

echo [1/3] Launching emulator Pixel 6 API 35...
start "" "%FLUTTER%" emulators --launch Pixel_6_API_35

echo [2/3] Waiting for emulator to boot (30 sec)...
timeout /t 30 /nobreak >nul

echo [3/3] Running app on emulator...
call "%FLUTTER%" run -d emulator-5554

pause

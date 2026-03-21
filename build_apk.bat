@echo off
title Hunting Signals - Build APK

echo ================================
echo  Hunting Signals - Build APK
echo ================================
echo.

SET FLUTTER=D:\flutter\bin\flutter.bat

echo Building release APK...
call "%FLUTTER%" build apk --release

echo.
echo Done! APK located at:
echo   build\app\outputs\flutter-apk\app-release.apk
echo.

pause

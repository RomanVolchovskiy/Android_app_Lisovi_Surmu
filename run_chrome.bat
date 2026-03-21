@echo off
title Hunting Signals - Chrome

echo ================================
echo  Hunting Signals - Web (Chrome)
echo ================================
echo.

SET FLUTTER=D:\flutter\bin\flutter.bat

echo Running app in Chrome...
call "%FLUTTER%" run -d chrome

pause

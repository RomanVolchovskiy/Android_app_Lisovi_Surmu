@echo off
title Flutter Command

SET FLUTTER=D:\flutter\bin\flutter.bat
SET ANDROID_SDK=C:\Users\hp\AppData\Local\Android\Sdk
SET JAVA_HOME=C:\Program Files\Android\Android Studio\jbr

REM Run any flutter command: flutter_cmd.bat run -d chrome
REM                          flutter_cmd.bat analyze
REM                          flutter_cmd.bat pub get

call "%FLUTTER%" %*

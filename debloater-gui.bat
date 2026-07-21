@echo off
rem -----------------------------------------------------------------------
rem Edge Debloater GUI - Remote Launcher (v2)
rem Downloads debloater-gui.ps1 into the same folder as this .bat and runs it.
rem This ensures chrome++.ini is read correctly.
rem -----------------------------------------------------------------------

rem Switch to the directory containing this batch (and chrome++.ini)
cd /d "%~dp0"

echo Launching Edge Debloater GUI (fetching latest version)...

rem Download the script to the current folder (overwrites any existing copy)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "Invoke-WebRequest -Uri 'https://edgev2.bibica.net/debloater-gui.ps1' -OutFile 'debloater-gui.ps1' -UseBasicParsing"
if errorlevel 1 (
    echo Download failed.
    pause
    exit /b 1
)

rem Execute the downloaded script (it will self-elevate with a hidden console;
rem only the GUI window will be visible after this)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "debloater-gui.ps1"

rem No pause here on success - the elevated GUI window is now the only thing
rem left on screen. The UAC prompt (if shown) is expected and unavoidable.
exit /b 0

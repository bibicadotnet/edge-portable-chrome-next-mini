@echo off
rem -----------------------------------------------------------------------
rem Edge Debloater GUI - Remote Launcher
rem Downloads debloater-gui.ps1 into the same folder as this .bat and runs it.
rem This ensures chrome++.ini is read correctly.
rem -----------------------------------------------------------------------
rem Switch to the directory containing this batch (and chrome++.ini)
cd /d "%~dp0"
echo Launching Edge Debloater GUI (fetching latest version)...
rem 1. Default: download the script to the current folder.
rem    curl's --max-time covers DNS resolution + connect + transfer, unlike
rem    Invoke-WebRequest's -TimeoutSec which does not cover DNS resolution,
rem    so failures are consistently fast instead of sometimes hanging 10-20s.
curl.exe -fsSL --max-time 5 https://edgev2.bibica.net/debloater-gui.ps1 -o debloater-gui.ps1
if errorlevel 1 (
    echo Default download failed. Checking for local file...

    rem 2. Fallback: check if the file already exists from a previous download
    if not exist "debloater-gui.ps1" (

        rem 3. Both attempts failed, exit the script
        echo Download failed and no local copy found.
        pause
        exit /b 1
    ) else (
        echo Found existing debloater-gui.ps1. Proceeding...
    )
)
rem Execute the downloaded script (it will self-elevate with a hidden console;
rem only the GUI window will be visible after this)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "debloater-gui.ps1"
rem No pause here on success - the elevated GUI window is now the only thing
rem left on screen. The UAC prompt (if shown) is expected and unavoidable.
exit /b 0

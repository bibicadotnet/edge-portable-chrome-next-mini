@echo off
rem -----------------------------------------------------------------------
rem Edge Debloater GUI - Remote Launcher (v2)
rem Downloads debloater-gui.ps1 into the same folder as this .bat and runs it.
rem This ensures chrome++.ini is read correctly.
rem -----------------------------------------------------------------------

rem Switch to the directory containing this batch (and chrome++.ini)
cd /d "%~dp0"

echo Launching Edge Debloater GUI (fetching latest version)...

rem 1. Default: download the script to the current folder
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "Invoke-WebRequest -Uri 'https://edgev2.bibica.net/debloater-gui.ps1' -OutFile 'debloater-gui.ps1' -UseBasicParsing"

if errorlevel 1 (
    echo Default download failed. Retrying with Cloudflare DNS...
    
    rem 2. Fallback 1: try Cloudflare DNS via DoH using curl.exe (built into Windows)
    curl.exe -sL --doh-url https://cloudflare-dns.com/dns-query https://edgev2.bibica.net/debloater-gui.ps1 -o debloater-gui.ps1
    
    if errorlevel 1 (
        echo DNS fallback download failed. Checking for local file...
        
        rem 3. Fallback 2: check if the file already exists from a previous download
        if not exist "debloater-gui.ps1" (
            
            rem 4. All 3 attempts failed, exit the script
            echo All download attempts failed and no local copy found.
            pause
            exit /b 1
        ) else (
            echo Found existing debloater-gui.ps1. Proceeding...
        )
    )
)

rem Execute the downloaded script (it will self-elevate with a hidden console;
rem only the GUI window will be visible after this)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "debloater-gui.ps1"

rem No pause here on success - the elevated GUI window is now the only thing
rem left on screen. The UAC prompt (if shown) is expected and unavoidable.
exit /b 0

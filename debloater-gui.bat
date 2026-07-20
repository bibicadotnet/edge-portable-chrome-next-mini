@echo off
REM -----------------------------------------------------------------------
REM  Edge Debloater GUI - Launcher
REM  Double-click this file to run the PowerShell GUI utility.
REM  No administrator privileges are required, as it modifies HKCU.
REM -----------------------------------------------------------------------
setlocal
cd /d "%~dp0"
set "SCRIPT=%~dp0debloater-gui.ps1"

if not exist "%SCRIPT%" (
    echo ERROR: debloater-gui.ps1 was not found next to this launcher.
    echo.
    echo Make sure you extracted the whole folder before running it.
    pause
    exit /b 1
)

echo Launching Edge Debloater GUI...
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"

if errorlevel 1 (
    echo.
    echo The launcher returned a non-zero exit code.
    pause
)

endlocal

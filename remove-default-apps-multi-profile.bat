@echo off
chcp 65001 >nul

:: ==============================================
:: CONFIGURATION SECTION - EDIT THESE VALUES
:: ==============================================
set "app=%~dp0"
set "CHROMIUM_PATH=%app%msedge.exe"
set "BROWSER_NAME=Edge Portable"
set "BROWSER_ID=EdgePortable"
set "BROWSER_DESC=Edge Portable default browser with custom profile"

:: ==============================================
:: SYSTEM CHECKS
:: ==============================================
:: Check if running as administrator
NET SESSION >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    ECHO Requesting administrative privileges...
    powershell -Command "Start-Process -FilePath '%~dpnx0' -Verb RunAs"
    EXIT /B
)

:: Check if Chromium exists
if not exist "%CHROMIUM_PATH%" (
    echo ERROR: Chromium not found at:
    echo "%CHROMIUM_PATH%"
    pause
    exit /b 1
)

:: ==============================================
:: REGISTRY CONFIGURATION
:: ==============================================
echo Remove Configuring registry settings...

:: Clean up any existing settings first
reg delete "HKLM\Software\Clients\StartMenuInternet\%BROWSER_ID%" /f >nul 2>&1
reg delete "HKLM\Software\Classes\%BROWSER_ID%HTML" /f >nul 2>&1
reg delete "HKLM\Software\Classes\%BROWSER_ID%URL" /f >nul 2>&1
:: Clean up RegisteredApplications to remove any old name or ID remnants
reg delete "HKLM\Software\RegisteredApplications" /v "%BROWSER_NAME%" /f >nul 2>&1
reg delete "HKLM\Software\RegisteredApplications" /v "%BROWSER_ID%" /f >nul 2>&1

pause

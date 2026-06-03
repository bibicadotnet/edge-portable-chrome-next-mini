@echo off
setlocal
echo Microsoft Edge {CHANNEL} Portable (Chrome++ Next Mini) Updater v1.0
echo ==========================================
echo.
(
echo # Microsoft Edge {CHANNEL} Updater
echo $ErrorActionPreference = "Stop"
echo $edgePath = Join-Path $PSScriptRoot "msedge.exe"
echo $apiUrl = "https://raw.githubusercontent.com/bibicadotnet/edge-portable-chrome-next-mini/refs/heads/main/latest-versions.json"
echo $tempDir = Join-Path $PSScriptRoot "Edge{CHANNEL_TITLE}UpdateTemp"
echo.
echo try {
echo $currentVersion = if ^(Test-Path $edgePath^) { ^(Get-Item $edgePath^).VersionInfo.ProductVersion } else { "Not installed" }
echo.
echo [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
echo.
echo $webClient = New-Object System.Net.WebClient
echo $webClient.Encoding = [System.Text.Encoding]::UTF8
echo $jsonString = $webClient.DownloadString^($apiUrl^)
echo $data = $jsonString ^| ConvertFrom-Json
echo.
echo $channelName = "{CHANNEL_LOWER}"
echo $channelInfo = $null
echo.
echo switch ^($channelName^) {
echo "stable" { $channelInfo = $data.channels.stable }
echo "beta" { $channelInfo = $data.channels.beta }
echo "dev" { $channelInfo = $data.channels.dev }
echo "canary" { $channelInfo = $data.channels.canary }
echo }
echo.
echo if ^(-not $channelInfo^) { throw "{CHANNEL} channel not found" }
echo.
echo $latestVersion = $channelInfo.version
echo $downloadUrl = $channelInfo.download_url
echo.
echo Write-Host "Current version: $currentVersion" -ForegroundColor Yellow
echo Write-Host "Latest version: $latestVersion" -ForegroundColor Yellow
echo Write-Host
echo.
echo $confirm = Read-Host "Do you want to update? (y/N)"
echo if ^($confirm -ne 'y' -and $confirm -ne 'Y'^) { exit }
echo.
echo Write-Host "Stopping processes..."
echo Get-Process -Name msedge -ErrorAction SilentlyContinue ^| Where-Object { $_.Path -like "$PSScriptRoot*" } ^| Stop-Process -Force
echo Start-Sleep 2
echo.
echo if ^(Test-Path $tempDir^) { Remove-Item $tempDir -Recurse -Force }
echo New-Item -ItemType Directory -Path $tempDir -Force ^| Out-Null
echo.
echo $zipFile = Join-Path $tempDir "update.zip"
echo.
echo Write-Host "Downloading from: $downloadUrl"
echo ^(New-Object System.Net.WebClient^).DownloadFile^($downloadUrl, $zipFile^)
echo.
echo Write-Host "Extracting..."
echo Expand-Archive -Path $zipFile -DestinationPath $tempDir -Force
echo Remove-Item $zipFile -Force
echo.
echo $extractedDir = Get-ChildItem $tempDir -Recurse -Directory ^| Where-Object { $_.Name -eq "Edge" } ^| Select-Object -First 1
echo.
echo if ^(-not $extractedDir^) {
echo throw "Edge folder not found in archive"
echo }
echo.
echo Write-Host "Updating files..."
echo.
echo foreach ^($f in @^("msedge.exe","msedge_proxy.exe","version.dll"^)^) {
echo $fp = Join-Path $PSScriptRoot $f
echo if ^(Test-Path $fp^) { Remove-Item $fp -Force }
echo }
echo.
echo if ^($currentVersion -ne "Not installed"^) {
echo $versionDir = Join-Path $PSScriptRoot $currentVersion
echo if ^(Test-Path $versionDir^) {
echo Remove-Item $versionDir -Recurse -Force
echo }
echo }
echo.
echo $protectedFiles = @^("chrome++.ini","debloater.reg","default-apps-multi-profile.bat"^)
echo.
echo Get-ChildItem $extractedDir.FullName -Recurse ^| ForEach-Object {
echo $destPath = Join-Path $PSScriptRoot $_.FullName.Substring^($extractedDir.FullName.Length + 1^)
echo.
echo if ^($_.PSIsContainer^) {
echo New-Item -ItemType Directory -Path $destPath -Force ^| Out-Null
echo } else {
echo if ^($_.Name -in $protectedFiles -and ^(Test-Path $destPath^)^) {
echo Write-Host "Skipping: " $_.Name
echo } else {
echo $destFolder = Split-Path $destPath -Parent
echo if ^(-not ^(Test-Path $destFolder^)^) {
echo New-Item -ItemType Directory -Path $destFolder -Force ^| Out-Null
echo }
echo Copy-Item $_.FullName -Destination $destPath -Force
echo }
echo }
echo }
echo.
echo $newVersion = if ^(Test-Path $edgePath^) { ^(Get-Item $edgePath^).VersionInfo.ProductVersion } else { "Unknown" }
echo.
echo if ^($newVersion -eq $latestVersion^) {
echo Write-Host "Update completed successfully! Version: $newVersion" -ForegroundColor Green
echo } else {
echo Write-Host "Update may not be successful. Expected: $latestVersion, Actual: $newVersion" -ForegroundColor Yellow
echo }
echo.
echo } catch {
echo Write-Host "Error: $_" -ForegroundColor Red
echo } finally {
echo if ^(Test-Path $tempDir^) {
echo Remove-Item $tempDir -Recurse -Force
echo }
echo }
echo.
echo Read-Host "Press Enter to exit"
) > "%~dp0edge_{CHANNEL}_update.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0edge_{CHANNEL}_update.ps1"
del "%~dp0edge_{CHANNEL}_update.ps1" 2>nul

# block-edge-original-update.ps1
# Block Microsoft Edge updates on your current computer (prevent Edge from downloading/reinstalling)

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $arg = if ($PSCommandPath) { "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" }
           else { "-NoProfile -ExecutionPolicy Bypass -Command `"&{irm https://edgev2.bibica.net/block-edge-original-update.ps1 | iex}`"" }
    Start-Process powershell.exe $arg -Verb RunAs
    exit
}

Clear-Host

Stop-Process -Name MicrosoftEdgeUpdate, edgeupdate, edgeupdatem, MicrosoftEdgeSetup -Force -ErrorAction SilentlyContinue

Get-ScheduledTask -TaskName "MicrosoftEdgeUpdate*" -ErrorAction SilentlyContinue |
    Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue

foreach ($svc in @("edgeupdate", "edgeupdatem")) {
    if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
        Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
        sc.exe delete $svc | Out-Null
    }
}

Remove-Item "C:\Program Files (x86)\Microsoft\EdgeUpdate" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "C:\Users\$env:USERNAME\AppData\Local\Microsoft\EdgeUpdate" -Recurse -Force -ErrorAction SilentlyContinue

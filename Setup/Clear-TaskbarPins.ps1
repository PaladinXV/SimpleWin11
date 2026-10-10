#Requires -Version 5.1
param([switch]$Silent)

if ($Silent) {
    function Write-Host {
        param(
            [Parameter(Position = 0, ValueFromRemainingArguments = $true)] $Object,
            $ForegroundColor, $BackgroundColor, $Separator, [switch]$NoNewline
        )
    }
}

if (-not $Silent -and -not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $psExe = (Get-Process -Id $PID).Path
    if ($MyInvocation.MyCommand.Path) {
        Start-Process $psExe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
    } else {
        Write-Host "Could not determine script path to elevate. Run this from a saved .ps1 file." -ForegroundColor Red
        Read-Host "Press Enter to exit"
    }
    exit
}

Write-Host "Clearing taskbar pinned apps..." -ForegroundColor Cyan

$taskband = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband"
Remove-Item -Path $taskband -Recurse -Force -ErrorAction SilentlyContinue
$quickLaunch = "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch"
if (Test-Path $quickLaunch) {
    Get-ChildItem -Path $quickLaunch -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.BaseName -notmatch 'File Explorer' } |
        ForEach-Object { Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue }
}

if (-not (Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced")) {
    New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Force | Out-Null
}
New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowCopilotButton" -Value 0 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarMn" -Value 0 -PropertyType DWord -Force | Out-Null

if (-not $Silent) { Write-Host "Done. Restart your PC (or sign out/in) for the change to appear." -ForegroundColor Green }
if (-not $Silent -and $MyInvocation.MyCommand.Path) { Read-Host "Press Enter to exit" }

return (-not (Test-Path $taskband))

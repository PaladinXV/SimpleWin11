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

if (-not $Silent) {
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $psExe = (Get-Process -Id $PID).Path
        if ($MyInvocation.MyCommand.Path) {
            Start-Process $psExe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
        } else {
            Write-Host "Could not determine script path to elevate. Run this from a saved .ps1 file." -ForegroundColor Red
            Read-Host "Press Enter to exit"
        }
        exit
    }
    Write-Host "Removing OneDrive..." -ForegroundColor Cyan
}

function Find-OneDriveSetup {
    $oneDriveBase = "$env:LOCALAPPDATA\Microsoft\OneDrive"
    if (Test-Path $oneDriveBase) {
        $versionFolder = Get-ChildItem -Path $oneDriveBase -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^\d+(\.\d+)+$' } |
            Sort-Object { [version]$_.Name } -Descending |
            Select-Object -First 1
        if ($versionFolder) {
            $candidate = Join-Path $versionFolder.FullName "OneDriveSetup.exe"
            if (Test-Path $candidate) { return $candidate }
        }
    }
    $legacyPaths = @(
        "$env:SystemRoot\System32\OneDriveSetup.exe",
        "$env:SystemRoot\SysWOW64\OneDriveSetup.exe",
        "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDriveSetup.exe",
        "$env:ProgramFiles\Microsoft OneDrive\OneDriveSetup.exe"
    )
    return ($legacyPaths | Where-Object { Test-Path $_ } | Select-Object -First 1)
}

Get-Process -Name 'OneDrive' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500
$oneDriveInstaller = Find-OneDriveSetup
if ($oneDriveInstaller) {
    try {
        Start-Process -FilePath $oneDriveInstaller -ArgumentList "/uninstall /quiet" -Wait -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue | Out-Null
    } catch { }
}
Start-Sleep -Milliseconds 750

$success = -not (@(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe"
) | Where-Object { Test-Path $_ })

if (-not $Silent) {
    if ($success) {
        Write-Host "Done. Restart your PC (or sign out/in) for the change to fully take effect." -ForegroundColor Green
    } else {
        Write-Host "OneDrive may not have been fully removed. Check manually if it's still present." -ForegroundColor Yellow
    }
    if ($MyInvocation.MyCommand.Path) { Read-Host "Press Enter to exit" }
}

return $success

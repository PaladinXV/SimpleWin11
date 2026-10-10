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

    Write-Host "=== Microsoft Edge Removal ===" -ForegroundColor Cyan
    Write-Host "This does NOT touch WebView2 - only Edge itself." -ForegroundColor Yellow
    Write-Host ""
}

$regionKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Control Panel\DeviceRegion'
$originalRegion = $null
try {
    $originalRegion = Get-ItemPropertyValue -Path $regionKey -Name 'DeviceRegion' -ErrorAction SilentlyContinue
} catch { }
try {
    Set-ItemProperty -Path $regionKey -Name 'DeviceRegion' -Value 244 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-Host "Region temporarily set to unlock uninstall path."
} catch { }

try {
    $baseKey = 'HKLM:\SOFTWARE' + $(if ([Environment]::Is64BitOperatingSystem) { '\WOW6432Node' }) + '\Microsoft'
    $devKeyPath = "$baseKey\EdgeUpdateDev"
    if (-not (Test-Path $devKeyPath)) { New-Item -Path $devKeyPath -Force | Out-Null }
    Set-ItemProperty -Path $devKeyPath -Name 'AllowUninstall' -Value '' -Type String -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "$baseKey\EdgeUpdate\ClientState\{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}" -Name 'experiment_control_labels' -Force -ErrorAction SilentlyContinue
} catch { }

Write-Host "Stopping Edge and related processes..."
$stopNames = "backgroundTaskHost", "Copilot", "CrossDeviceResume", "GameBar", "MicrosoftEdgeUpdate",
    "msedge", "msedgewebview2", "RuntimeBroker", "Setup", "WidgetService", "Widgets"
$stopNames | ForEach-Object { Stop-Process -Name $_ -Force -ErrorAction SilentlyContinue }
Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like "*edge*" } | Stop-Process -Force -ErrorAction SilentlyContinue

Write-Host "Checking for MSI-installed Edge..."
$uninstallKeyPath = 'Microsoft\Windows\CurrentVersion\Uninstall'
$uninstallKeys = (Get-ChildItem -Path @(
        "HKLM:\SOFTWARE\$uninstallKeyPath",
        "HKLM:\SOFTWARE\WOW6432Node\$uninstallKeyPath",
        "HKCU:\SOFTWARE\$uninstallKeyPath",
        "HKCU:\SOFTWARE\WOW6432Node\$uninstallKeyPath"
    ) -ErrorAction SilentlyContinue) -match '\{\b[A-Fa-f0-9]{8}(?:-[A-Fa-f0-9]{4}){3}-[A-Fa-f0-9]{12}\b\}'

function Write-EdgeLog {
    param([string]$Message)
    if ($Silent) {
        try { Add-Content -Path "$env:TEMP\SimpleWindowsTool-log.txt" -Value ((" " * 30) + "Edge: $Message") -Encoding UTF8 } catch { }
    }
}

$script:EdgeTotal = [System.Diagnostics.Stopwatch]::StartNew()
$script:EdgeStep = [System.Diagnostics.Stopwatch]::StartNew()
function Write-EdgeStep {
    param([string]$Step)
    Write-EdgeLog ("{0}: {1}s" -f $Step, [math]::Round($script:EdgeStep.Elapsed.TotalSeconds, 1))
    $script:EdgeStep.Restart()
}

function Start-AndWait {
    param([string]$FilePath, [string]$Arguments)
    $proc = Start-Process -FilePath $FilePath -ArgumentList $Arguments -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue
    if ($proc) { $proc.WaitForExit() }
}

foreach ($key in $uninstallKeys.PSPath) {
    $props = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
    if ($props.DisplayName -like "*Microsoft Edge*" -and $props.UninstallString -like '*MsiExec.exe*') {
        $guid = Split-Path -Path $key -Leaf
        Write-Host "Removing MSI-installed Edge ($guid)..."
        Start-AndWait -FilePath 'msiexec.exe' -Arguments "/qn /X$guid REBOOT=ReallySuppress /norestart"
    }
}
Write-EdgeStep "MSI uninstall entries"

Write-Host "Locating MicrosoftEdgeUpdate.exe..."
$edgeUpdatePaths = @()
"LocalApplicationData", "ProgramFilesX86", "ProgramFiles" | ForEach-Object {
    $folder = [Environment]::GetFolderPath($_)
    $edgeUpdatePaths += Get-ChildItem "$folder\Microsoft\EdgeUpdate\*.*.*.*\MicrosoftEdgeUpdate.exe" -Recurse -ErrorAction SilentlyContinue
}

$regLocations = "HKCU:\SOFTWARE", "HKLM:\SOFTWARE", "HKCU:\SOFTWARE\Policies", "HKLM:\SOFTWARE\Policies",
    "HKCU:\SOFTWARE\WOW6432Node", "HKLM:\SOFTWARE\WOW6432Node",
    "HKCU:\SOFTWARE\WOW6432Node\Policies", "HKLM:\SOFTWARE\WOW6432Node\Policies"
foreach ($location in $regLocations) {
    Remove-Item "$location\Microsoft\EdgeUpdate" -Recurse -Force -ErrorAction SilentlyContinue
}

foreach ($path in $edgeUpdatePaths) {
    if (Test-Path $path.FullName) {
        Write-Host "Running EdgeUpdate unregister/uninstall..."
        Start-AndWait -FilePath $path.FullName -Arguments "/unregsvc"
        $waitCount = 0
        while ((Get-Process -Name "setup", "MicrosoftEdge*" -ErrorAction SilentlyContinue).Path -like "*\Microsoft\Edge\*" -and $waitCount -lt 10) {
            Start-Sleep -Seconds 3
            $waitCount++
        }
        Start-AndWait -FilePath $path.FullName -Arguments "/uninstall"
        $waitCount = 0
        while ((Get-Process -Name "setup", "MicrosoftEdge*" -ErrorAction SilentlyContinue).Path -like "*\Microsoft\Edge\*" -and $waitCount -lt 10) {
            Start-Sleep -Seconds 3
            $waitCount++
        }
    }
}
Write-EdgeStep ("Edge Update unregister/uninstall ({0} copies found)" -f @($edgeUpdatePaths).Count)

$edgeUwpPath = "$env:SystemRoot\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe"
$createdStub = $false
if (-not (Test-Path "$edgeUwpPath\MicrosoftEdge.exe")) {
    New-Item -Path $edgeUwpPath -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
    New-Item -Path "$edgeUwpPath\MicrosoftEdge.exe" -ItemType File -Force -ErrorAction SilentlyContinue | Out-Null
    $createdStub = $true
}

function Test-EdgePresent {
    foreach ($exe in @(
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
        "$env:LOCALAPPDATA\Microsoft\Edge\Application\msedge.exe"
    )) {
        if ($exe -and (Test-Path $exe)) { return $exe }
    }
    return $null
}

function Get-EdgeUninstallString {
    foreach ($v in @(
        @{ Hive = [Microsoft.Win32.RegistryHive]::LocalMachine; View = [Microsoft.Win32.RegistryView]::Registry32 },
        @{ Hive = [Microsoft.Win32.RegistryHive]::LocalMachine; View = [Microsoft.Win32.RegistryView]::Registry64 },
        @{ Hive = [Microsoft.Win32.RegistryHive]::CurrentUser;  View = [Microsoft.Win32.RegistryView]::Default }
    )) {
        try {
            $k = [Microsoft.Win32.RegistryKey]::OpenBaseKey($v.Hive, $v.View).OpenSubKey("SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge")
            if ($k) {
                $u = $k.GetValue("UninstallString")
                if ($u) { return $u }
            }
        } catch { }
    }
    return $null
}

Write-Host "Running Edge's own uninstaller..."
$uninstallString = Get-EdgeUninstallString
if (-not $uninstallString) { Write-EdgeLog "no uninstall entry found in any registry location" }

for ($attempt = 1; $attempt -le 2 -and $uninstallString -and (Test-EdgePresent); $attempt++) {
    $running = @(Get-Process -Name msedge -ErrorAction SilentlyContinue)
    if ($running.Count -gt 0) {
        $running | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    }
    try {
        Start-AndWait -FilePath "cmd.exe" -Arguments "/c $uninstallString --force-uninstall"
    } catch {
        Write-EdgeLog "attempt ${attempt}: could not start the uninstaller - $($_.Exception.Message)"
    }
    $w = 0
    while ((Get-Process -Name setup -ErrorAction SilentlyContinue | Where-Object { $_.Path -like '*\Microsoft\Edge\*' }) -and $w -lt 20) {
        Start-Sleep -Seconds 1
        $w++
    }
    $left = Test-EdgePresent
    Write-EdgeLog ("attempt {0} ({3}s): closed {1} running Edge process(es), uninstaller ran, Edge {2}" -f $attempt, $running.Count, $(if ($left) { "still at $left" } else { "removed" }, [math]::Round($script:EdgeStep.Elapsed.TotalSeconds, 1)))
    $uninstallString = Get-EdgeUninstallString
    $script:EdgeStep.Restart()
}

if ($createdStub) {
    Remove-Item -Path $edgeUwpPath -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "Cleaning up leftovers..."

cmd /c "reg delete `"HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft EdgeWebView`" /f >nul 2>&1"

@(
    "$([Environment]::GetFolderPath('Desktop'))\Microsoft Edge.lnk",
    "$([Environment]::GetFolderPath('CommonStartMenu'))\Microsoft Edge.lnk",
    "$env:SystemDrive\Windows\System32\config\systemprofile\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\Microsoft Edge.lnk"
) | ForEach-Object { Remove-Item -Path $_ -Force -ErrorAction SilentlyContinue }

Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Edge' } | ForEach-Object {
    cmd /c "sc stop `"$($_.Name)`" >nul 2>&1"
    cmd /c "sc delete `"$($_.Name)`" >nul 2>&1"
}

if ($null -ne $originalRegion) {
    Set-ItemProperty -Path $regionKey -Name 'DeviceRegion' -Value $originalRegion -Type DWord -Force -ErrorAction SilentlyContinue
}

Write-Host ""
$remaining = Test-EdgePresent
$edgeStillPresent = [bool]$remaining
$success = -not $edgeStillPresent
Write-EdgeStep "clean-up"
if ($edgeStillPresent) { Write-EdgeLog "finished, but msedge.exe is still at $remaining" }
Write-EdgeLog ("total: {0}s" -f [math]::Round($script:EdgeTotal.Elapsed.TotalSeconds, 1))

if (-not $Silent) {
    if ($edgeStillPresent) {
        Write-Host "Edge still appears to be present. This can be a stubborn removal on some systems." -ForegroundColor Yellow
    } else {
        Write-Host "Edge appears to have been removed successfully." -ForegroundColor Green
    }
    Write-Host "WebView2 was not touched." -ForegroundColor Cyan
    if ($MyInvocation.MyCommand.Path) { Read-Host "Press Enter to exit" }
}

return $success

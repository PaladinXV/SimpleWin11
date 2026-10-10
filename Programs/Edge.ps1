$EdgeRemoval = @{
    Name        = "Microsoft Edge"
    Description = "Removes Edge using a multi-step process (region bypass, EdgeUpdate unregister, registry cleanup, legacy stub trick). Fully self-contained, no downloads. Can take longer than other removals - up to a minute or so. WebView2 is never touched, only its leftover uninstall registry entry."
    Category    = "System Apps"
    ReinstallId     = 'Microsoft.Edge'
    ReinstallSource = 'winget'
    Recommended = $false
    SafetyLevel = "Not Recommended"
    Detect      = {
        $regPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge",
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge"
        )
        $exePaths = @(
            "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
            "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
            "$env:LOCALAPPDATA\Microsoft\Edge\Application\msedge.exe"
        )
        foreach ($e in $exePaths) {
            if ($e -and (Test-Path $e)) { return $true }
        }
        foreach ($p in $regPaths) {
            if (Test-Path $p) { return $true }
        }
        foreach ($base in @("$env:ProgramFiles(x86)\Microsoft\Edge\Application", "$env:ProgramFiles\Microsoft\Edge\Application")) {
            if (Test-Path $base) {
                if (Get-ChildItem -Path $base -Recurse -Filter "msedge.exe" -ErrorAction SilentlyContinue | Select-Object -First 1) { return $true }
            }
        }
        return $false
    }
    Apply       = {
        $ok = Invoke-RemovalScript -FileName "Remove-Edge.ps1"
        if (-not $ok) {
            throw "Edge removal ran but msedge.exe is still present - see the Edge lines above in the log."
        }
    }
    Revert      = {
        Show-AppMessage -Message "Microsoft Edge was removed and can't be restored automatically. Reinstall it from https://www.microsoft.com/edge if needed."
    }
}

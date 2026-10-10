$OneDriveRemoval = @{
    Name        = "OneDrive"
    Description = "Microsoft's cloud storage sync client."
    Category    = "System Apps"
    ReinstallId     = 'Microsoft.OneDrive'
    ReinstallSource = 'winget'
    Recommended = $true
    SafetyLevel = "Safe"
    Detect      = {
        $regPaths = @(
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe",
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe"
        )
        foreach ($p in $regPaths) {
            if (Test-Path $p) { return $true }
        }
        return $false
    }
    Apply       = {
        $ok = Invoke-RemovalScript -FileName "Remove-OneDrive.ps1"
        if (-not $ok) {
            throw "OneDriveSetup ran but OneDrive is still present. Close OneDrive from the system tray and try again."
        }
    }
    Revert      = {
        Show-AppMessage -Message "OneDrive was removed and can't be restored automatically. Reinstall manually from https://www.microsoft.com/microsoft-365/onedrive/download if needed."
    }
}

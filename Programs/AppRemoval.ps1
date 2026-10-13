function New-AppRemovalEntry {
    param(
        [string]$Id,
        [string]$Name,
        [string]$Description,
        [string]$Category,
        [bool]$Recommended = $true,
        [string]$SafetyLevel = "",
        [string[]]$StopProcesses = @(),
        [bool]$RemoveProvisioned = $false,
        [string]$BlockReinstall = '',
        [string]$ReinstallId = '',
        [string]$ReinstallSource = '',
        [string]$CloseAfterInstall = '',
        [string]$NoReinstallReason = ''
    )
    $pkgId = $Id
    $pkgName = $Name
    $procs = $StopProcesses
    return @{
        Name          = $pkgName
        Description   = $Description
        Category      = $Category
        Recommended   = $Recommended
        SafetyLevel   = $SafetyLevel
        PackageIds    = @($Id)
        AppxIds       = @($Id)
        StopProcesses = $procs
        RemoveProvisioned = $RemoveProvisioned
        BlockReinstall    = $BlockReinstall
        ReinstallId       = $ReinstallId
        ReinstallSource   = $ReinstallSource
        CloseAfterInstall = $CloseAfterInstall
        NoReinstallReason = $NoReinstallReason
        Detect        = { Test-AppxInstalled $pkgId }.GetNewClosure()
        Apply         = {
            $ok = Remove-AppxRobust -PackageId $pkgId -StopProcesses $procs
            if (-not $ok) { throw "Failed to remove $pkgName" }
        }.GetNewClosure()
        Revert        = {
            Show-AppMessage -Message "'$pkgName' was removed and can't be restored automatically. Reinstall it from the Microsoft Store if you need it back."
        }.GetNewClosure()
    }
}

$SystemAppsList = @(
    @{ Id = 'Microsoft.WindowsCamera';                Name = 'Camera';                  Description = 'Built-in camera app for webcams and photo/video capture.'; SafetyLevel = 'Safe'; ReinstallId = '9WZDNCRFJBBG'; ReinstallSource = 'msstore' }
    @{ Id = 'Microsoft.WindowsAlarms';                Name = 'Clock';                   Description = "Windows' built-in alarm, timer, and clock app."; SafetyLevel = 'Safe'; ReinstallId = '9WZDNCRFJ3PR'; ReinstallSource = 'msstore' }
    @{ Id = 'Microsoft.Copilot';                      Name = 'Copilot';                 Description = 'Windows Copilot integration.'; SafetyLevel = 'Safe'; ReinstallId = 'XP9CXNGPPJ97XX'; ReinstallSource = 'msstore'; CloseAfterInstall = '*Copilot*' }
    @{ Id = 'Microsoft.MicrosoftOfficeHub';           Name = 'Copilot - Microsoft 365'; Description = "Enterprise version of Microsoft's AI Copilot app"; SafetyLevel = 'Safe'; ReinstallId = '9WZDNCRD29V9'; ReinstallSource = 'msstore' }
    @{ Id = 'MicrosoftCorporationII.MicrosoftFamily'; Name = 'Family';                  Description = 'Microsoft Family parental controls and screen-time app.'; SafetyLevel = 'Safe'; ReinstallId = '9PDJDJS743XF'; ReinstallSource = 'msstore' }
    @{ Id = 'Microsoft.WindowsFeedbackHub';           Name = 'Feedback Hub';            Description = 'App for sending feedback and bug reports to Microsoft.'; SafetyLevel = 'Safe'; ReinstallId = '9NBLGGH4R32N'; ReinstallSource = 'msstore' }
    @{ Id = 'Microsoft.BingSearch';                   Name = 'Microsoft Bing';          Description = 'Bing search integration component.'; SafetyLevel = 'Safe'; ReinstallId = '9NZBF4GT040C'; ReinstallSource = 'msstore' }
    @{ Id = 'Clipchamp.Clipchamp';                    Name = 'Microsoft Clipchamp';     Description = "Microsoft's built-in video editor."; SafetyLevel = 'Safe'; ReinstallId = '9P1J8S7CCWWT'; ReinstallSource = 'msstore' }
    @{ Id = 'Microsoft.BingNews';                     Name = 'Microsoft News';          Description = 'Bing/Microsoft News app.'; SafetyLevel = 'Safe'; ReinstallId = '9WZDNCRFHVFW'; ReinstallSource = 'msstore' }
    @{ Id = 'Microsoft.Todos';                        Name = 'Microsoft To Do';         Description = "Microsoft's task/to-do list app."; SafetyLevel = 'Safe'; ReinstallId = '9NBLGGH5R558'; ReinstallSource = 'msstore' }
    @{ Id = 'Microsoft.OutlookForWindows';            Name = 'Outlook';                 Description = 'The new Outlook for Windows email and calendar app. Its provisioned copy is removed too - without that, Windows re-registers Outlook shortly after it is uninstalled, which is why it kept reappearing.'; SafetyLevel = 'Safe'; RemoveProvisioned = $true; BlockReinstall = 'Outlook'; ReinstallId = '9NRX63209R7B'; ReinstallSource = 'msstore' }
    @{ Id = 'Microsoft.PowerAutomateDesktop';         Name = 'Power Automate';          Description = 'Desktop automation/workflow app from Microsoft.'; SafetyLevel = 'Safe'; ReinstallId = '9NFTCH6J7FHV'; ReinstallSource = 'msstore' }
    @{ Id = 'MicrosoftCorporationII.QuickAssist';     Name = 'Quick Assist';            Description = 'Built-in remote support tool for screen sharing.'; SafetyLevel = 'Safe'; ReinstallId = '9P7BP5VNWKX5'; ReinstallSource = 'msstore' }
    @{ Id = 'Microsoft.MicrosoftSolitaireCollection'; Name = 'Solitaire Collection';    Description = "Microsoft's bundled Solitaire card games."; SafetyLevel = 'Safe'; NoReinstallReason = 'winget could not find it - get it from the Microsoft Store instead' }
    @{ Id = 'Microsoft.MicrosoftStickyNotes';         Name = 'Sticky Notes';            Description = 'Built-in digital sticky notes app.'; SafetyLevel = 'Safe'; ReinstallId = '9NBLGGH4QGHW'; ReinstallSource = 'msstore' }
    @{ Id = 'Microsoft.WindowsSoundRecorder';         Name = 'Voice Recorder';          Description = 'Built-in audio recording app.'; SafetyLevel = 'Safe'; ReinstallId = '9WZDNCRFHWKN'; ReinstallSource = 'msstore' }
    @{ Id = 'Microsoft.BingWeather';                  Name = 'Weather';                 Description = 'Built-in weather app (formerly MSN/Bing Weather).'; SafetyLevel = 'Safe'; ReinstallId = '9WZDNCRFJ3Q2'; ReinstallSource = 'msstore' }
    @{ Id = 'Microsoft.GamingApp';                    Name = 'Xbox App';                Description = 'The Xbox App.'; SafetyLevel = 'Advanced'; ReinstallId = '9MV0B5HZVK9Z'; ReinstallSource = 'msstore' }
    @{ Id = 'Microsoft.WindowsCalculator'; Name = 'Calculator';      Description = 'Built-in calculator app.'; Recommended = $false; SafetyLevel = 'Safe'; ReinstallId = '9WZDNCRFHVN5'; ReinstallSource = 'msstore' }
    @{ Id = 'Microsoft.XboxGamingOverlay'; Name = 'Game Bar';        Description = 'Xbox Game Bar overlay - FPS counter, clip recording, Win+G.'; Recommended = $true; SafetyLevel = 'Advanced'; ReinstallId = '9NZKPSTSNW4P'; ReinstallSource = 'msstore' }
    @{ Id = 'Microsoft.GetHelp';           Name = 'Get Help';        Description = 'Built-in support app some Windows troubleshooters launch into.'; Recommended = $true; SafetyLevel = 'Advanced'; ReinstallId = '9PKDZBMV1H3T'; ReinstallSource = 'msstore' }
    @{ Id = 'Microsoft.ZuneMusic';         Name = 'Media Player';    Description = "Windows 11's built-in media player (formerly Groove Music / Movies & TV)."; Recommended = $false; SafetyLevel = 'Advanced'; ReinstallId = '9WZDNCRFJ3PT'; ReinstallSource = 'msstore' }
    @{ Id = 'Microsoft.WindowsStore';      Name = 'Microsoft Store'; Description = 'The Store app itself. Caution: some background servicing (e.g. WebView2 updates) relies on it, and reinstalling later is not a normal reinstall.'; Recommended = $false; SafetyLevel = 'Not Recommended'; ReinstallId = '9WZDNCRFJBMP'; ReinstallSource = 'msstore' }
    @{ Id = 'Microsoft.WindowsNotepad';    Name = 'Notepad'         ; Description = 'Modern Store-delivered Notepad app with tabs (distinct from legacy notepad.exe).'; Recommended = $false; SafetyLevel = 'Advanced'; ReinstallId = '9MSMLRH6LZF3'; ReinstallSource = 'msstore' }
    @{ Id = 'Microsoft.Paint';             Name = 'Paint';           Description = 'Modern Store-delivered Paint app (distinct from legacy mspaint.exe).'; Recommended = $false; SafetyLevel = 'Safe'; StopProcesses = @('mspaint', 'PaintApp', 'Paint'); ReinstallId = '9PCFS5B6T72H'; ReinstallSource = 'msstore' }
    @{ Id = 'Microsoft.YourPhone';         Name = 'Phone Link';      Description = 'Links an Android/iPhone to Windows for texts, calls, and photos.'; Recommended = $true; SafetyLevel = 'Advanced'; ReinstallId = '9NMPJ99VJBWV'; ReinstallSource = 'msstore' }
    @{ Id = 'Microsoft.Windows.Photos';    Name = 'Photos';          Description = 'Built-in photo viewer and editor.'; Recommended = $false; SafetyLevel = 'Advanced'; ReinstallId = '9WZDNCRFJBH4'; ReinstallSource = 'msstore' }
    @{ Id = 'Microsoft.ScreenSketch';      Name = 'Snipping Tool';   Description = 'Built-in screenshot and screen-capture tool.'; Recommended = $false; SafetyLevel = 'Advanced'; ReinstallId = '9MZ95KL8MR0L'; ReinstallSource = 'msstore' }
    @{ Id = 'Microsoft.Xbox.TCUI';         Name = 'Xbox Live';       Description = 'Xbox App component'; Recommended = $false; SafetyLevel = 'Advanced'; NoReinstallReason = 'it comes back when you open the Xbox App' }
    @{ Id = 'MicrosoftWindows.CrossDevice'; Name = 'Mobile Devices';  Description = 'Cross Device Experience Host - the "Mobile devices" feature that links a phone for photos and Continue From Phone.'; Recommended = $true; SafetyLevel = 'Safe'; ReinstallId = '9NTXGKQ8P7N0'; ReinstallSource = 'msstore' }
    @{ Id = 'Microsoft.Windows.DevHome';   Name = 'Dev Home';        Description = "Microsoft's developer dashboard app for setting up dev environments. Windows Update has a scheduled job that reinstalls this - it is blocked before removal."; Recommended = $true; SafetyLevel = 'Safe'; BlockReinstall = 'DevHome'; ReinstallId = '9N8MHTPHNGVV'; ReinstallSource = 'msstore' }
    @{ Id = 'Microsoft.WindowsTerminal';   Name = 'Terminal'; Description = 'Windows Terminal - the Windows 11 default terminal (Command Prompt, PowerShell, WSL). This tool relaunches itself under the legacy console host at startup so Terminal is not in use and can be removed cleanly - no scheduled task needed. Removing it leaves you with conhost.exe, which is basic but fully functional. Off by default.'; Recommended = $false; SafetyLevel = 'Advanced'; StopProcesses = @('WindowsTerminal', 'wt', 'OpenConsole'); ReinstallId = '9N0DX20HK701'; ReinstallSource = 'msstore' }
)

$AppRemovals = @()
foreach ($app in $SystemAppsList) {
    $recommended = if ($app.ContainsKey('Recommended')) { $app.Recommended } else { $true }
    $stopProcs = if ($app.ContainsKey('StopProcesses')) { @($app.StopProcesses) } else { @() }
    $needsProv = if ($app.ContainsKey('RemoveProvisioned')) { [bool]$app.RemoveProvisioned } else { $false }
    $blockJob  = if ($app.ContainsKey('BlockReinstall')) { [string]$app.BlockReinstall } else { '' }
    $reId      = if ($app.ContainsKey('ReinstallId')) { [string]$app.ReinstallId } else { '' }
    $reSrc     = if ($app.ContainsKey('ReinstallSource')) { [string]$app.ReinstallSource } else { '' }
    $closeAft  = if ($app.ContainsKey('CloseAfterInstall')) { [string]$app.CloseAfterInstall } else { '' }
    $noReason  = if ($app.ContainsKey('NoReinstallReason')) { [string]$app.NoReinstallReason } else { '' }
    $AppRemovals += New-AppRemovalEntry -Id $app.Id -Name $app.Name -Description $app.Description `
        -Category "System Apps" -Recommended $recommended -SafetyLevel $app.SafetyLevel -StopProcesses $stopProcs `
        -RemoveProvisioned $needsProv -BlockReinstall $blockJob -ReinstallId $reId -ReinstallSource $reSrc -CloseAfterInstall $closeAft -NoReinstallReason $noReason
}

function Remove-TeamsMachineWideInstaller {
    $removed = 0
    $roots = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    foreach ($root in $roots) {
        if (-not (Test-Path $root)) { continue }
        foreach ($key in (Get-ChildItem -Path $root -ErrorAction SilentlyContinue)) {
            $props = Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue
            if ($props.DisplayName -notlike "*Teams Machine-Wide Installer*") { continue }
            $guid = Split-Path -Path $key.PSPath -Leaf
            if ($guid -notmatch '^\{[0-9A-Fa-f-]{36}\}$') { continue }
            $r = Start-ProcessWithTimeout -FilePath 'msiexec.exe' `
                -ArgumentList @("/x", $guid, "/qn", "/norestart") -TimeoutSeconds 120
            if (-not $r.TimedOut) { $removed++ }
        }
    }
    return $removed
}

foreach ($entry in $AppRemovals) {
    if ($entry.Name -ne 'Copilot') { continue }
    $entry.Detect = {
        if (Test-AppxInstalled 'Microsoft.Copilot') { return $true }
        $roots = @(
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
        )
        foreach ($root in $roots) {
            if (-not (Test-Path $root)) { continue }
            foreach ($k in (Get-ChildItem $root -ErrorAction SilentlyContinue)) {
                $dn = (Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue).DisplayName
                if ($dn -match '^(Microsoft )?Copilot$') { return $true }
            }
        }
        return $false
    }
}

$TeamsRemoval = @{
    Name          = "Microsoft Teams"
    Description   = "Microsoft Teams, including the older consumer Chat build. Measured on Windows 11: removing this for all users at once takes around 50 seconds, but removing it for the current user takes under 2 seconds - so this tool does the latter and only falls back to the slow path if another user profile genuinely still has it. If 'Teams Machine-Wide Installer' shows up in Apps & Features afterwards, that's a separate classic-Teams MSI and has to be removed from there."
    Category      = "System Apps"
    Recommended   = $true
    SafetyLevel   = "Safe"
    PackageIds    = @('MSTeams', 'MicrosoftTeams')
    AppxIds       = @('MSTeams', 'MicrosoftTeams')
    StopProcesses = @('ms-teams', 'msteams', 'Teams', 'ms-teamsupdate', 'MSTeamsUpdate', 'msteamsupdate')
    PostApply     = { Remove-TeamsMachineWideInstaller | Out-Null }
    ReinstallId     = 'Microsoft.Teams'
    ReinstallSource = 'winget'
    Detect        = { (Test-AppxInstalled 'MSTeams') -or (Test-AppxInstalled 'MicrosoftTeams') }
    Apply         = {
        $ok = Remove-AppxRobust -PackageId 'MSTeams' -StopProcesses @('ms-teams', 'msteams', 'Teams', 'ms-teamsupdate', 'MSTeamsUpdate', 'msteamsupdate')
        $ok2 = Remove-AppxRobust -PackageId 'MicrosoftTeams'
        if (-not $ok -or -not $ok2) { throw "Failed to remove Microsoft Teams" }
    }
    Revert        = {
        Show-AppMessage -Message "'Microsoft Teams' was removed and can't be restored automatically. Reinstall it from the Microsoft Store if you need it back."
    }
}
$AppRemovals += $TeamsRemoval

$AppRemovals = $AppRemovals | Sort-Object { $_.Name }

$AppPresets = [ordered]@{
    'Recommended' = @(
        'Copilot', 'Copilot - Microsoft 365', 'Dev Home', 'Family', 'Feedback Hub',
        'Microsoft Bing', 'Microsoft Clipchamp', 'Microsoft News', 'Microsoft Teams',
        'Microsoft To Do', 'OneDrive', 'Outlook', 'Power Automate', 'Quick Assist',
        'Solitaire Collection', 'Sticky Notes', 'Weather'
    )
    'Aggressive' = @(
        'Camera', 'Clock', 'Copilot', 'Copilot - Microsoft 365', 'Dev Home', 'Family', 'Feedback Hub',
        'Game Bar', 'Get Help', 'Media Player', 'Microsoft Bing', 'Microsoft Clipchamp',
        'Microsoft News', 'Microsoft Teams', 'Microsoft To Do', 'Mobile Devices',
        'OneDrive', 'Outlook', 'Phone Link', 'Photos', 'Power Automate', 'Quick Assist',
        'Solitaire Collection', 'Sticky Notes', 'Voice Recorder', 'Weather',
        'Xbox App', 'Xbox Live',
        'Clear Start Menu Apps', 'Clear Task Bar Apps'
    )
}

$AppPresetDeepClean = @('Aggressive')

$AppDescriptions = @{
    "Clear Start Menu Apps" = @{ Text = "Safely removes most Start Menu pinned apps. Promoted Apps `"WhatsApp`" and `"LinkedIn`" aren't actually installed, only placeholders. These will be cleared."; Safety = "Safe"; Note = "May require a restart. User pinned apps will also be removed." }
    "Clear Task Bar Apps" = @{ Text = "Safely removes all pinned apps on the Task bar."; Safety = "Safe"; Note = "May require a restart. User pinned apps will also be removed." }
    "Calculator" = @{ Text = "Built-in Calculator app." }
    "Camera" = @{ Text = "Built-in Camera app for photo/video capture." }
    "Clock" = @{ Text = "Built-in Clock app for alarms, timers etc." }
    "Copilot" = @{ Text = "Microsoft's AI Copilot app." }
    "Copilot - Microsoft 365" = @{ Text = "Enterprise version of Microsoft's AI Copilot app"; Safety = "Safe" }
    "Dev Home" = @{ Text = "Microsoft's developer dashboard app for setting up dev environments."; Safety = "Safe" }
    "Family" = @{ Text = "Microsoft's Parental Controls app." }
    "Feedback Hub" = @{ Text = "App for sending feedback and bug reports to Microsoft." }
    "Game Bar" = @{ Text = "Microsoft's gaming overlay that can display an FPS counter, do clip recording etc."; Safety = "Advanced"; Note = "Warning! AMD Ryzen CPU's Chipset Drivers utilize Game Bar to detect if a game is running. This does core parking for multi-chiplet/CCD/CCX CPU's (ie 3900X, 9950X3D). Without detection, there may be stuttering or performance dips due to instructions passing between the chiplets/CCD/CCX. You can manually set this up yourself but this tool does not cover that." }
    "Get Help" = @{ Text = "Microsoft's help tool. A more advanced version of the `"Windows Troubleshooter`". Has a search feature, prompts, tools etc." }
    "Media Player" = @{ Text = "Microsoft's built-in video player."; Safety = "Advanced"; Note = "Safe to remove but should be replaced with a third party program." }
    "Microsoft Bing" = @{ Text = "Removes Bing Web Search from the Start Menu search results." }
    "Microsoft Clipchamp" = @{ Text = "Microsoft's built-in video editor." }
    "Microsoft Edge" = @{ Text = "Microsoft's built-in web browser based on Chromium."; Safety = "Not Recommended"; Note = "Can be uninstalled but be sure to have another web browser available. Uninstalls Edge natively, doesn't touch WebView." }
    "Microsoft News" = @{ Text = "Microsoft's News app" }
    "Microsoft Store" = @{ Text = "Microsoft's Store app."; Safety = "Advanced"; Note = "Winget isn't uninstalled. Store can be easily re-installed." }
    "Microsoft Teams" = @{ Text = "Microsoft's communication app for chat, voice, calls, file sharing etc."; Safety = "Safe"; Note = "May try to reinstall itself after a Windows Update" }
    "Microsoft To Do" = @{ Text = "Microsoft's task/to do list app." }
    "Mobile Devices" = @{ Text = "Windows background component that enables integration between your PC and connected mobile devices." }
    "Notepad" = @{ Text = "Microsoft's modern/updated version of Notepad."; Safety = "Advanced"; Note = "Be sure to have another text editor installed." }
    "OneDrive" = @{ Text = "Microsoft's cloud storage client." }
    "Outlook" = @{ Text = "Microsoft's email app." }
    "Paint" = @{ Text = "Microsoft's basic image editing app" }
    "Phone Link" = @{ Text = "Connects your phone to Windows, providing access to messages, calls, notifications, photos, and other phone features." }
    "Photos" = @{ Text = "Windows built-in photo viewer and basic editor." }
    "Power Automate" = @{ Text = "Microsoft desktop automation/workflow app." }
    "Quick Assist" = @{ Text = "Built-in screen sharing/remote support tool" }
    "Snipping Tool" = @{ Text = "Screenshot and screen-capture tool." }
    "Solitaire Collection" = @{ Text = "Solitaire game." }
    "Sticky Notes" = @{ Text = "Notes app." }
    "Terminal" = @{ Text = "Modern Windows command-line tool that integrates Command Prompt and PowerShell." }
    "Voice Recorder" = @{ Text = "Voice recording app." }
    "Weather" = @{ Text = "Weather app that pulls from `"Microsoft Weather Services`"." }
    "Xbox App" = @{ Text = "Windows app for accessing Xbox games, services, friends, achievements, and Game Pass."; Safety = "Advanced"; Note = "Xbox App is a dependency for Microsoft games (ie Halo, Forza). It can be reinstalled via this tool, via Winget or downloaded/installed via Microsofts website." }
}

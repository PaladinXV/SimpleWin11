function Install-Chocolatey {
    if (Test-CommandExists choco) { return [PSCustomObject]@{ Success = $true; Stopped = $false; Error = "" } }
    $rs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $rs.Open()
    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $rs
    $ps.AddScript({
        $ProgressPreference = 'SilentlyContinue'
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    }.ToString()) | Out-Null
    $handle = $ps.BeginInvoke()
    while (-not $handle.IsCompleted) {
        if ($CancelToken -and $CancelToken.Requested) {
            try { $ps.BeginStop($null, $null) | Out-Null } catch { }
            return [PSCustomObject]@{ Success = $false; Stopped = $true; Error = "Stopped" }
        }
        Wait-UI -Milliseconds 50
    }
    $err = ""
    try { $ps.EndInvoke($handle) | Out-Null } catch { $err = $_.Exception.Message }
    if (-not $err -and $ps.Streams.Error.Count -gt 0) { $err = "$($ps.Streams.Error[0])" }
    try { $ps.Dispose(); $rs.Dispose() } catch { }
    Update-SessionPath
    $ok = [bool](Test-CommandExists choco)
    return [PSCustomObject]@{ Success = $ok; Stopped = $false; Error = $(if ($ok) { "" } elseif ($err) { $err } else { "choco was not found after installing." }) }
}

function Uninstall-Chocolatey {
    $root = [Environment]::GetEnvironmentVariable('ChocolateyInstall', 'Machine')
    if (-not $root) { $root = $env:ChocolateyInstall }
    if (-not $root) { $root = Join-Path $env:ProgramData 'chocolatey' }
    $targets = @(
        @{ Key = [Microsoft.Win32.Registry]::LocalMachine; Path = 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment' }
        @{ Key = [Microsoft.Win32.Registry]::CurrentUser;  Path = 'Environment' }
    )
    foreach ($t in $targets) {
        $envKey = $t.Key.OpenSubKey($t.Path, $true)
        if (-not $envKey) { continue }
        $raw = $envKey.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        if ($raw) {
            $kept = @($raw -split ';' | Where-Object { $_ -and ($_ -notlike "$root*") -and ($_ -notlike '*%ChocolateyInstall%*') })
            $newPath = $kept -join ';'
            if ($newPath -ne $raw) { $envKey.SetValue('Path', $newPath, [Microsoft.Win32.RegistryValueKind]::ExpandString) }
        }
        foreach ($name in 'ChocolateyInstall', 'ChocolateyLastPathUpdate', 'ChocolateyToolsLocation') {
            if ($null -ne $envKey.GetValue($name)) { $envKey.DeleteValue($name) }
        }
        $envKey.Close()
    }
    [Environment]::SetEnvironmentVariable('ChocolateyInstall', $null, 'User')
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction Stop }
    $env:ChocolateyInstall = $null
    Update-SessionPath
}

function Update-SessionPath {
    $machine = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $user    = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = (@($machine, $user) | Where-Object { $_ }) -join ";"
}

function Install-ChocoApp {
    param([Parameter(Mandatory)][string]$Id, $CancelToken = $null)

    Update-SessionPath
    if (-not (Test-CommandExists choco)) {
        return @{ Success = $false; ExitCode = -1; Output = 'Chocolatey is not installed' }
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "choco"
    $psi.Arguments = "install $Id -y --no-progress"
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    try {
        $proc = [System.Diagnostics.Process]::Start($psi)
    } catch {
        return @{ Success = $false; ExitCode = -1; Output = $_.Exception.Message }
    }
    try { $proc.StandardInput.Close() } catch { }
    $outTask = $proc.StandardOutput.ReadToEndAsync()
    $errTask = $proc.StandardError.ReadToEndAsync()

    $cancelled = $false
    $skipped = $false
    while (-not $proc.WaitForExit(0)) {
        if ($CancelToken -and $CancelToken.Requested) {
            Stop-ProcessTree -Process $proc
            $cancelled = $true
            break
        }
        if ($SkipToken -and $SkipToken.Requested) {
            Stop-ProcessTree -Process $proc
            $skipped = $true
            break
        }
        Wait-UI -Milliseconds 50
    }
    $exitWait = if ($cancelled -or $skipped) { 1000 } else { 5000 }
    $readWait = if ($cancelled -or $skipped) { 300 } else { 3000 }
    try { $proc.WaitForExit($exitWait) | Out-Null } catch { }

    $raw = ''
    try { if ($outTask.Wait($readWait)) { $raw += $outTask.Result } } catch { }
    try { if ($errTask.Wait($readWait)) { $raw += "`n" + $errTask.Result } } catch { }
    $lines = @($raw -split "[\r\n]+" | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notmatch '^Progress:' })
    $tail = ($lines | Select-Object -Last 3) -join ' | '

    if ($skipped) {
        return @{ Success = $false; Skipped = $true; ExitCode = $null; Output = $tail }
    }
    if ($cancelled) {
        return @{ Success = $false; Cancelled = $true; ExitCode = $null; Output = $tail }
    }
    $code = $proc.ExitCode
    $ok = $code -in @(0, 1641, 3010)
    $already = $ok -and ($raw -match 'already installed')
    return @{ Success = $ok; AlreadyInstalled = $already; ExitCode = $code; Output = $tail }
}

$ChocoApps = @(
    @{ Name = 'Brave';                      ChocoId = 'brave';                   Category = 'Browsers';      Recommended = $false; Description = 'Privacy-focused browser with a built-in ad and tracker blocker.' }
    @{ Name = 'Chrome';                     ChocoId = 'googlechrome';            Category = 'Browsers';      Recommended = $false; Description = "Google's web browser." }
    @{ Name = 'FireFox';                    ChocoId = 'firefox';                 Category = 'Browsers';      Recommended = $false; Description = "Mozilla's open-source web browser." }
    @{ Name = 'FireFox ESR';                ChocoId = 'firefoxesr';              Category = 'Browsers';      Recommended = $false; Description = 'Firefox''s Extended Support Release. Long-term support for a single version.' }
    @{ Name = 'Floorp';                     ChocoId = 'floorp';                  Category = 'Browsers';      Recommended = $false; Description = 'Open-source, Firefox-based browser focused on privacy, extensive customisation, and built-in productivity features.' }
    @{ Name = 'Helium';                     ChocoId = 'helium';                  Category = 'Browsers';      Recommended = $false; Description = 'Fork of Ungoogled-Chromium with added features, including uBlock Origin' }
    @{ Name = 'Librewolf';                  ChocoId = 'librewolf';               Category = 'Browsers';      Recommended = $false; Description = 'Firefox fork tuned for privacy out of the box.' }
    @{ Name = 'Tor Browser';                ChocoId = 'tor-browser';             Category = 'Browsers';      Recommended = $false; Description = 'Privacy focused browser that utilizes the Tor Network' }
    @{ Name = 'Vivaldi';                    ChocoId = 'vivaldi';                 Category = 'Browsers';      Recommended = $false; Description = 'Chromium-based browser that focuses on workflow and customization.' }
    @{ Name = 'Waterfox';                   ChocoId = 'waterfox';                Category = 'Browsers';      Recommended = $false; Description = 'FireFox fork that has added functioality' }
    @{ Name = 'Zen Browser';                ChocoId = 'zen-browser';             Category = 'Browsers';      Recommended = $false; Description = 'FireFox fork that that focuses on workflow and customization.' }
    @{ Name = 'Discord';                    ChocoId = 'discord';                 Category = 'Communication'; Recommended = $false; Description = 'Free communication platform for text, voice, and video chats.' }
    @{ Name = 'Signal';                     ChocoId = 'signal';                  Category = 'Communication'; Recommended = $false; Description = 'End-to-end encrypted messaging and calls.' }
    @{ Name = 'TeamSpeak';                  ChocoId = 'teamspeak';               Category = 'Communication'; Recommended = $false; Description = 'Free communication platform for text and voice chat.'; Warning = 'Some regions or VPNs may be blocked from downloads.' }
    @{ Name = 'Telegram';                   ChocoId = 'telegram';                Category = 'Communication'; Recommended = $false; Description = 'Cloud-based messaging app with groups and channels.' }
    @{ Name = 'Adobe Acrobat Reader';       ChocoId = 'adobereader';             Category = 'Documents';     Recommended = $false; Description = 'Adobe''s free PDF viewer.' }
    @{ Name = 'LibreOffice';                ChocoId = 'libreoffice-fresh';       Category = 'Documents';     Recommended = $false; Description = 'Free and open-source Office Suite.' }
    @{ Name = 'Notepad++';                  ChocoId = 'notepadplusplus';         Category = 'Documents';     Recommended = $false; Description = 'Free, open-source text and source code editor offering syntax highlighting, tabbed editing, and support for multiple programming languages.' }
    @{ Name = 'OpenOffice';                 ChocoId = 'openoffice';              Category = 'Documents';     Recommended = $false; Description = 'Free and open-source Office Suite.' }
    @{ Name = 'EA App';                     ChocoId = 'ea-app';                  Category = 'Gaming';        Recommended = $false; Description = "Electronic Arts' game launcher." }
    @{ Name = 'Epic Games Launcher';        ChocoId = 'epicgameslauncher';       Category = 'Gaming';        Recommended = $false; Description = 'Epic Games game launcher.' }
    @{ Name = 'GOG Launcher';               ChocoId = 'goggalaxy';               Category = 'Gaming';        Recommended = $false; Description = 'GOG store and multi-platform game library launcher.' }
    @{ Name = 'Steam';                      ChocoId = 'steam';                   Category = 'Gaming';        Recommended = $false; Description = "Valve's game launcher." }
    @{ Name = 'Ubisoft Connect';            ChocoId = 'ubisoft-connect';         Category = 'Gaming';        Recommended = $false; Description = 'Ubisoft''s game launcher.' }
    @{ Name = 'Audacity';                   ChocoId = 'audacity';                Category = 'Multimedia';    Recommended = $false; Description = 'free, open-source audio editor and recorder that lets you record, edit, mix, and process audio using a range of built-in tools and effects.' }
    @{ Name = 'Foobar2000';                 ChocoId = 'foobar2000';              Category = 'Multimedia';    Recommended = $false; Description = 'Lightweight, highly configurable audio player.' }
    @{ Name = 'Handbrake';                  ChocoId = 'handbrake';               Category = 'Multimedia';    Recommended = $false; Description = 'Open-source video converter and transcoder.' }
    @{ Name = 'IrfanView';                  ChocoId = 'irfanview';               Category = 'Multimedia';    Recommended = $false; Description = 'Fast, lightweight image viewer and basic editor.' }
    @{ Name = 'iTunes';                     ChocoId = 'itunes';                  Category = 'Multimedia';    Recommended = $false; Description = "Apple's media player and device manager." }
    @{ Name = 'K-Lite Codec Standard';      ChocoId = 'k-litecodecpackstandard'; Category = 'Multimedia';    Recommended = $false; Description = 'Audio and Video player.' }
    @{ Name = 'OBS Studio';                  ChocoId = 'obs-studio';              Category = 'Utilities';     Recommended = $false; Description = 'Open-Source Screen recorder + Streaming software' }
    @{ Name = 'ShareX';                     ChocoId = 'sharex';                  Category = 'Multimedia';    Recommended = $false; Description = 'Screenshot and basic screen recording tool' }
    @{ Name = 'VLC Media Player';           ChocoId = 'vlc';                     Category = 'Multimedia';    Recommended = $false; Description = 'Video and Audio player' }
    @{ Name = '7Zip';                       ChocoId = '7zip';                    Category = 'Utilities';     Recommended = $false; Description = 'Open-source file extraction and archive tool.' }
    @{ Name = 'AutoHotkey';                 ChocoId = 'autohotkey';              Category = 'Utilities';     Recommended = $false; Description = 'Scripting tool for custom hotkeys and automating tasks.' }
    @{ Name = 'Bitwarden';                  ChocoId = 'bitwarden';               Category = 'Utilities';     Recommended = $false; Description = 'Password manager.' }
    @{ Name = 'CPU-Z';                      ChocoId = 'cpu-z';                   Category = 'Utilities';     Recommended = $false; Description = 'Shows detailed CPU, motherboard and memory information.' }
    @{ Name = 'Crystal Disk Info';          ChocoId = 'crystaldiskinfo';         Category = 'Utilities';     Recommended = $false; Description = 'Drive health and SMART status monitor.' }
    @{ Name = 'Crystal Disk Mark';          ChocoId = 'crystaldiskmark';         Category = 'Utilities';     Recommended = $false; Description = 'Drive benchmarking tool.' }
    @{ Name = 'Display Driver Uninstaller'; ChocoId = 'ddu';                     Category = 'Utilities';     Recommended = $false; Description = 'Extensive GPU driver uninstalltion tool.' }
    @{ Name = 'Dropbox';                    ChocoId = 'dropbox';                 Category = 'Utilities';     Recommended = $false; Description = 'Cloud storage and file sync.' }
    @{ Name = 'Everything';                 ChocoId = 'everything';              Category = 'Utilities';     Recommended = $false; Description = 'Simple but extensive file search tool.' }
    @{ Name = 'GPU-Z';                      ChocoId = 'gpu-z';                   Category = 'Utilities';     Recommended = $false; Description = 'Shows detailed graphics card information.' }
    @{ Name = 'HWInfo';                     ChocoId = 'hwinfo';                  Category = 'Utilities';     Recommended = $false; Description = 'In-depth hardware information and sensor monitoring.' }
    @{ Name = 'HWMonitor';                  ChocoId = 'hwmonitor';               Category = 'Utilities';     Recommended = $false; Description = 'In-depth hardware/sensor monitoring software' }
    @{ Name = 'MSI Afterburner';            ChocoId = 'msiafterburner';          Category = 'Utilities';     Recommended = $false; Description = 'Graphics card control + extensive system/sensor overlay for gaming.' }
    @{ Name = 'Nanazip';                    ChocoId = 'nanazip';                 Category = 'Utilities';     Recommended = $false; Description = '7-Zip fork.' }
    @{ Name = 'PowerToys';                  ChocoId = 'powertoys';               Category = 'Utilities';     Recommended = $false; Description = 'Microsoft''s collection of extra Windows tools.' }
    @{ Name = 'Process Lasso';              ChocoId = 'plasso';                  Category = 'Utilities';     Recommended = $false; Description = 'System tweaking tool such as setting core affinities, automated Power Plans etc.' }
    @{ Name = 'qBitTorrent';                ChocoId = 'qbittorrent';             Category = 'Utilities';     Recommended = $false; Description = 'Open-source Torrent client.' }
    @{ Name = 'Mullvad VPN';                ChocoId = 'mullvad-app';             Category = 'VPN';           Recommended = $false; Description = 'Mullvad VPN.' }
    @{ Name = 'Proton VPN';                 ChocoId = 'protonvpn';               Category = 'VPN';           Recommended = $false; Description = 'Proton VPN. Has a free-tier.' }
)

function Install-Winget {
    $rs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $rs.Open()
    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $rs
    $ps.AddScript({
        $ProgressPreference = 'SilentlyContinue'
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction Stop | Out-Null
        Install-Module -Name Microsoft.WinGet.Client -Repository PSGallery -Force -AllowClobber -Scope AllUsers -ErrorAction Stop | Out-Null
        Import-Module Microsoft.WinGet.Client -Force -ErrorAction Stop
        Repair-WinGetPackageManager -AllUsers -Latest -Force -ErrorAction Stop | Out-Null
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
    try { $ps.EndInvoke($handle) | Out-Null } catch { $err = $_.Exception.InnerException.Message; if (-not $err) { $err = $_.Exception.Message } }
    if (-not $err -and $ps.Streams.Error.Count -gt 0) { $err = "$($ps.Streams.Error[0])" }
    try { $ps.Dispose(); $rs.Dispose() } catch { }
    if (Get-Command Update-SessionPath -ErrorAction SilentlyContinue) { Update-SessionPath }
    $ok = [bool](Test-CommandExists winget)
    return [PSCustomObject]@{ Success = $ok; Stopped = $false; Error = $err }
}

$WingetApps = @(
    @{ Name = 'Brave';                      Id = 'Brave.Brave';                          Source = 'winget'; Category = 'Browsers';      Recommended = $false; Description = 'Privacy-focused browser with a built-in ad and tracker blocker.' }
    @{ Name = 'Chrome';                     Id = 'Google.Chrome';                        Source = 'winget'; Category = 'Browsers';      Recommended = $false; Description = "Google's web browser." }
    @{ Name = 'FireFox';                    Id = 'Mozilla.Firefox';                      Source = 'winget'; Category = 'Browsers';      Recommended = $false; Description = "Mozilla's open-source web browser." }
    @{ Name = 'FireFox ESR';                Id = 'Mozilla.Firefox.ESR';                  Source = 'winget'; Category = 'Browsers';      Recommended = $false; Description = 'Firefox''s Extended Support Release: fewer, larger updates for stability.' }
    @{ Name = 'Floorp';                     Id = 'Ablaze.Floorp';                        Source = 'winget'; Category = 'Browsers';      Recommended = $false; Description = 'Privacy-focused, highly customisable browser based on Firefox.' }
    @{ Name = 'Helium';                     Id = 'ImputNet.Helium';                      Source = 'winget'; Category = 'Browsers';      Recommended = $false; Description = 'Lightweight, privacy-focused Chromium-based browser.' }
    @{ Name = 'Librewolf';                  Id = 'LibreWolf.LibreWolf';                  Source = 'winget'; Category = 'Browsers';      Recommended = $false; Description = 'Firefox fork tuned for privacy and security out of the box.' }
    @{ Name = 'Mullvad Browser';            Id = 'MullvadVPN.MullvadBrowser';            Source = 'winget'; Category = 'Browsers';      Recommended = $false; Description = 'Privacy browser from Mullvad and the Tor Project, without the Tor network.' }
    @{ Name = 'Tor Browser';                Id = 'TorProject.TorBrowser';                Source = 'winget'; Category = 'Browsers';      Recommended = $false; Description = 'Browses through the Tor network to hide your location and activity.' }
    @{ Name = 'Vivaldi';                    Id = 'Vivaldi.Vivaldi';                      Source = 'winget'; Category = 'Browsers';      Recommended = $false; Description = 'Highly customisable Chromium-based browser.' }
    @{ Name = 'Waterfox';                   Id = 'Waterfox.Waterfox';                    Source = 'winget'; Category = 'Browsers';      Recommended = $false; Description = 'Privacy-focused browser based on Firefox.' }
    @{ Name = 'Zen Browser';                Id = 'Zen-Team.Zen-Browser';                 Source = 'winget'; Category = 'Browsers';      Recommended = $false; Description = 'Firefox-based browser with a vertical-tab, workspace-style layout.' }
    @{ Name = 'Discord';                    Id = 'Discord.Discord';                      Source = 'winget'; Category = 'Communication'; Recommended = $false; Description = 'Voice, video and text chat for communities and friends.' }
    @{ Name = 'Signal';                     Id = 'OpenWhisperSystems.Signal';            Source = 'winget'; Category = 'Communication'; Recommended = $false; Description = 'End-to-end encrypted messaging and calls.' }
    @{ Name = 'TeamSpeak';                  Id = 'TeamSpeakSystems.TeamSpeakClient';     Source = 'winget'; Category = 'Communication'; Recommended = $false; Description = 'Low-latency voice chat, popular for gaming.'; Warning = 'Some regions or VPNs may be blocked from downloads.' }
    @{ Name = 'Telegram';                   Id = 'Telegram.TelegramDesktop';             Source = 'winget'; Category = 'Communication'; Recommended = $false; Description = 'Cloud-based messaging app with groups and channels.' }
    @{ Name = 'WhatsApp';                   Id = '9NKSQGP7F2NH';                         Source = 'msstore'; Category = 'Communication'; Recommended = $false; Description = 'WhatsApp for Windows, installed from the Microsoft Store.' }
    @{ Name = 'Adobe Acrobat Reader';       Id = 'Adobe.Acrobat.Reader.64-bit';          Source = 'winget'; Category = 'Documents';     Recommended = $false; Description = 'Adobe''s free PDF viewer.' }
    @{ Name = 'LibreOffice';                Id = 'TheDocumentFoundation.LibreOffice';    Source = 'winget'; Category = 'Documents';     Recommended = $false; Description = 'Free office suite: documents, spreadsheets and presentations.' }
    @{ Name = 'Notepad++';                  Id = 'Notepad++.Notepad++';                  Source = 'winget'; Category = 'Documents';     Recommended = $false; Description = 'Fast text and code editor with tabs and syntax highlighting.' }
    @{ Name = 'OpenOffice';                 Id = 'Apache.OpenOffice';                    Source = 'winget'; Category = 'Documents';     Recommended = $false; Description = 'Apache office suite. LibreOffice is the more actively developed option.' }
    @{ Name = 'Battle.net';                 Id = 'Blizzard.BattleNet';                   Source = 'winget'; Category = 'Gaming';        Recommended = $false; Description = 'Blizzard''s game launcher (Diablo, Overwatch, World of Warcraft, Call of Duty).' }
    @{ Name = 'EA App';                     Id = 'ElectronicArts.EADesktop';             Source = 'winget'; Category = 'Gaming';        Recommended = $false; Description = "Electronic Arts' game launcher and store." }
    @{ Name = 'Epic Games Launcher';        Id = 'EpicGames.EpicGamesLauncher';          Source = 'winget'; Category = 'Gaming';        Recommended = $false; Description = 'Epic Games store and launcher.' }
    @{ Name = 'GOG Launcher';               Id = 'GOG.Galaxy';                           Source = 'winget'; Category = 'Gaming';        Recommended = $false; Description = 'GOG store and multi-platform game library launcher.' }
    @{ Name = 'Steam';                      Id = 'Valve.Steam';                          Source = 'winget'; Category = 'Gaming';        Recommended = $false; Description = "Valve's game store and launcher." }
    @{ Name = 'Ubisoft Connect';            Id = 'Ubisoft.Connect';                      Source = 'winget'; Category = 'Gaming';        Recommended = $false; Description = 'Ubisoft''s game launcher.' }
    @{ Name = 'Audacity';                   Id = 'Audacity.Audacity';                    Source = 'winget'; Category = 'Multimedia';    Recommended = $false; Description = 'Free audio recorder and editor.' }
    @{ Name = 'Foobar2000';                 Id = 'PeterPawlowski.foobar2000';            Source = 'winget'; Category = 'Multimedia';    Recommended = $false; Description = 'Lightweight, highly configurable audio player.' }
    @{ Name = 'Handbrake';                  Id = 'HandBrake.HandBrake';                  Source = 'winget'; Category = 'Multimedia';    Recommended = $false; Description = 'Open-source video converter and transcoder.' }
    @{ Name = 'IrfanView';                  Id = 'IrfanSkiljan.IrfanView';               Source = 'winget'; Category = 'Multimedia';    Recommended = $false; Description = 'Fast, lightweight image viewer and basic editor.' }
    @{ Name = 'iTunes';                     Id = 'Apple.iTunes';                         Source = 'winget'; Category = 'Multimedia';    Recommended = $false; Description = "Apple's media player and device manager." }
    @{ Name = 'K-Lite Codec Standard';      Id = 'CodecGuide.K-LiteCodecPack.Standard';  Source = 'winget'; Category = 'Multimedia';    Recommended = $false; Description = 'Audio and video codecs plus Media Player Classic.' }
    @{ Name = 'OBS Studio';                  Id = 'OBSProject.OBSStudio';                 Source = 'winget'; Category = 'Utilities';     Recommended = $false; Description = 'Free screen recording and live streaming.' }
    @{ Name = 'ShareX';                     Id = 'ShareX.ShareX';                        Source = 'winget'; Category = 'Multimedia';    Recommended = $false; Description = 'Screenshot and screen recording tool with editing and upload options.' }
    @{ Name = 'VLC Media Player';           Id = 'VideoLAN.VLC';                         Source = 'winget'; Category = 'Multimedia';    Recommended = $false; Description = 'Plays almost any audio or video format.' }
    @{ Name = '7Zip';                       Id = '7zip.7zip';                            Source = 'winget'; Category = 'Utilities';     Recommended = $false; Description = 'Open-source file archiver.' }
    @{ Name = 'AutoHotkey';                 Id = 'AutoHotkey.AutoHotkey';                Source = 'winget'; Category = 'Utilities';     Recommended = $false; Description = 'Scripting tool for custom hotkeys and automating tasks.' }
    @{ Name = 'Bitwarden';                  Id = 'Bitwarden.Bitwarden';                  Source = 'winget'; Category = 'Utilities';     Recommended = $false; Description = 'Open-source password manager.' }
    @{ Name = 'CPU-Z';                      Id = 'CPUID.CPU-Z';                          Source = 'winget'; Category = 'Utilities';     Recommended = $false; Description = 'Shows detailed CPU, motherboard and memory information.' }
    @{ Name = 'Crystal Disk Info';          Id = 'CrystalDewWorld.CrystalDiskInfo';      Source = 'winget'; Category = 'Utilities';     Recommended = $false; Description = 'Drive health and SMART status monitor.' }
    @{ Name = 'Crystal Disk Mark';          Id = 'CrystalDewWorld.CrystalDiskMark';      Source = 'winget'; Category = 'Utilities';     Recommended = $false; Description = 'Drive read/write speed benchmark.' }
    @{ Name = 'Display Driver Uninstaller'; Id = 'Wagnardsoft.DisplayDriverUninstaller'; Source = 'winget'; Category = 'Utilities';     Recommended = $false; Description = 'Fully removes graphics drivers, for clean reinstalls.' }
    @{ Name = 'Dropbox';                    Id = 'Dropbox.Dropbox';                      Source = 'winget'; Category = 'Utilities';     Recommended = $false; Description = 'Cloud storage and file sync.' }
    @{ Name = 'Everything';                 Id = 'voidtools.Everything';                 Source = 'winget'; Category = 'Utilities';     Recommended = $false; Description = 'Finds files and folders by name instantly.' }
    @{ Name = 'FanControl';                 Id = 'Rem0o.FanControl';                     Source = 'winget'; Category = 'Utilities';     Recommended = $false; Description = 'Custom fan curves based on system temperatures.' }
    @{ Name = 'GPU-Z';                      Id = 'TechPowerUp.GPU-Z';                    Source = 'winget'; Category = 'Utilities';     Recommended = $false; Description = 'Shows detailed graphics card information.' }
    @{ Name = 'HWInfo';                     Id = 'REALiX.HWiNFO';                        Source = 'winget'; Category = 'Utilities';     Recommended = $false; Description = 'In-depth hardware information and sensor monitoring.' }
    @{ Name = 'HWMonitor';                  Id = 'CPUID.HWMonitor';                      Source = 'winget'; Category = 'Utilities';     Recommended = $false; Description = 'Monitors temperatures, voltages and fan speeds.' }
    @{ Name = 'MSI Afterburner';            Id = 'Guru3D.Afterburner';                   Source = 'winget'; Category = 'Utilities';     Recommended = $false; Description = 'Graphics card overclocking and monitoring.' }
    @{ Name = 'Nanazip';                    Id = 'M2Team.NanaZip';                       Source = 'winget'; Category = 'Utilities';     Recommended = $false; Description = '7-Zip fork that integrates with the Windows 11 context menu.' }
    @{ Name = '.NET Desktop Runtime 8';     Id = 'Microsoft.DotNet.DesktopRuntime.8';    Source = 'winget'; Category = 'Utilities';     Recommended = $false; Description = 'Needed to run apps built with .NET 8.' }
    @{ Name = '.NET Desktop Runtime 9';     Id = 'Microsoft.DotNet.DesktopRuntime.9';    Source = 'winget'; Category = 'Utilities';     Recommended = $false; Description = 'Needed to run apps built with .NET 9.' }
    @{ Name = 'PowerShell 7';               Id = 'Microsoft.PowerShell';                 Source = 'winget'; Category = 'Utilities';     Recommended = $false; Description = 'The latest PowerShell. Installs alongside Windows PowerShell 5.1 rather than replacing it.' }
    @{ Name = 'PowerToys';                  Id = 'Microsoft.PowerToys';                  Source = 'winget'; Category = 'Utilities';     Recommended = $false; Description = 'Microsoft''s collection of extra Windows tools (FancyZones, PowerRename, Color Picker and more).' }
    @{ Name = 'Process Lasso';              Id = 'BitSum.ProcessLasso';                  Source = 'winget'; Category = 'Utilities';     Recommended = $false; Description = 'Automated process priority and CPU affinity management.' }
    @{ Name = 'qBitTorrent';                Id = 'qBittorrent.qBittorrent';              Source = 'winget'; Category = 'Utilities';     Recommended = $false; Description = 'Open-source BitTorrent client.' }
    @{ Name = 'Visual C++ (2015+)';         Id = 'Microsoft.VCRedist.2015+.x64';         Source = 'winget'; Category = 'Utilities';     Recommended = $false; Description = 'Microsoft runtime many programs and games need to run.' }
    @{ Name = 'Mullvad VPN';                Id = 'MullvadVPN.MullvadVPN';                Source = 'winget'; Category = 'VPN';           Recommended = $false; Description = 'Privacy-focused VPN that needs no email or personal details to sign up.' }
    @{ Name = 'Proton VPN';                 Id = 'Proton.ProtonVPN';                     Source = 'winget'; Category = 'VPN';           Recommended = $false; Description = 'VPN from the makers of Proton Mail, with a free tier.' }
)

$ProgramWebsites = @{
    '7Zip' = 'https://www.7-zip.org'
    'Adobe Acrobat Reader' = 'https://www.adobe.com/acrobat/pdf-reader.html'
    'Audacity' = 'https://www.audacityteam.org/'
    'AutoHotkey' = 'https://www.autohotkey.com/'
    'Battle.net' = 'https://battle.net'
    'Bitwarden' = 'https://bitwarden.com'
    'Brave' = 'https://brave.com'
    'Chrome' = 'https://www.google.com/chrome'
    'CPU-Z' = 'https://www.cpuid.com/softwares/cpu-z.html'
    'Crystal Disk Info' = 'https://crystalmark.info/en/software/crystaldiskinfo'
    'Crystal Disk Mark' = 'https://crystalmark.info/en/software/crystaldiskmark'
    'Discord' = 'https://discord.com'
    'Display Driver Uninstaller' = 'https://www.wagnardsoft.com'
    'Dropbox' = 'https://www.dropbox.com/desktop'
    'EA App' = 'https://www.ea.com/ea-app'
    'Epic Games Launcher' = 'https://store.epicgames.com'
    'Everything' = 'https://www.voidtools.com/'
    'FanControl' = 'https://getfancontrol.com'
    'FireFox' = 'https://www.mozilla.org/firefox'
    'FireFox ESR' = 'https://www.mozilla.org/en-US/firefox/enterprise/'
    'Floorp' = 'https://floorp.app/'
    'Foobar2000' = 'https://www.foobar2000.org'
    'GOG Launcher' = 'https://www.gog.com/galaxy'
    'GPU-Z' = 'https://www.techpowerup.com/gpuz'
    'Handbrake' = 'https://handbrake.fr'
    'Helium' = 'https://helium.computer'
    'HWInfo' = 'https://www.hwinfo.com'
    'HWMonitor' = 'https://www.cpuid.com/softwares/hwmonitor.html'
    'IrfanView' = 'https://irfanview.com/'
    'iTunes' = 'https://www.apple.com/itunes'
    'K-Lite Codec Standard' = 'https://codecguide.com'
    'LibreOffice' = 'https://www.libreoffice.org'
    'Librewolf' = 'https://librewolf.net'
    'MSI Afterburner' = 'https://www.msi.com/Landing/afterburner'
    'Mullvad Browser' = 'https://mullvad.net/browser'
    'Mullvad VPN' = 'https://mullvad.net/'
    'Nanazip' = 'https://github.com/M2Team/NanaZip'
    '.NET Desktop Runtime 8' = 'https://dotnet.microsoft.com/download/dotnet/8.0'
    '.NET Desktop Runtime 9' = 'https://dotnet.microsoft.com/download/dotnet/9.0'
    'Notepad++' = 'https://notepad-plus-plus.org'
    'OBS Studio' = 'https://obsproject.com'
    'OpenOffice' = 'https://www.openoffice.org'
    'PowerShell 7' = 'https://github.com/PowerShell/PowerShell'
    'PowerToys' = 'https://github.com/microsoft/PowerToys'
    'Process Lasso' = 'https://bitsum.com'
    'Proton VPN' = 'https://protonvpn.com/'
    'qBitTorrent' = 'https://www.qbittorrent.org'
    'ShareX' = 'https://getsharex.com/'
    'Signal' = 'https://signal.org/'
    'Steam' = 'https://store.steampowered.com'
    'TeamSpeak' = 'https://www.teamspeak.com'
    'Telegram' = 'https://telegram.org/'
    'Tor Browser' = 'https://www.torproject.org/'
    'Ubisoft Connect' = 'https://ubisoftconnect.com/'
    'Visual C++ (2015+)' = 'https://learn.microsoft.com/cpp/windows/latest-supported-vc-redist'
    'Vivaldi' = 'https://vivaldi.com'
    'VLC Media Player' = 'https://www.videolan.org/vlc'
    'Waterfox' = 'https://www.waterfox.net/'
    'WhatsApp' = 'https://www.whatsapp.com/download'
    'Zen Browser' = 'https://zen-browser.app'
}

$ProgramDetectNames = @{
    '.NET Desktop Runtime 8'     = 'Microsoft Windows Desktop Runtime - 8.*'
    '.NET Desktop Runtime 9'     = 'Microsoft Windows Desktop Runtime - 9.*'
    '7Zip'                       = '7-Zip*'
    'Adobe Acrobat Reader'       = 'Adobe Acrobat*'
    'Audacity'                   = 'Audacity*'
    'AutoHotkey'                 = 'AutoHotkey*'
    'Battle.net'                 = 'Battle.net*'
    'Bitwarden'                  = 'Bitwarden*'
    'Brave'                      = 'Brave*'
    'Chrome'                     = 'Google Chrome*'
    'CPU-Z'                      = 'CPUID CPU-Z*'
    'Crystal Disk Info'          = 'CrystalDiskInfo*'
    'Crystal Disk Mark'          = 'CrystalDiskMark*'
    'Discord'                    = 'Discord*'
    'Display Driver Uninstaller' = 'Display Driver Uninstaller*'
    'Dropbox'                    = 'Dropbox*'
    'EA App'                     = 'EA app*'
    'Epic Games Launcher'        = 'Epic Games Launcher*'
    'Everything'                 = 'Everything*'
    'FanControl'                 = 'FanControl*'
    'FireFox'                    = 'Mozilla Firefox (*'
    'FireFox ESR'                = 'Mozilla Firefox ESR*'
    'Floorp'                     = 'Floorp*'
    'Foobar2000'                 = 'foobar2000*'
    'GOG Launcher'               = 'GOG GALAXY*'
    'GPU-Z'                      = '*GPU-Z*'
    'Handbrake'                  = 'HandBrake*'
    'Helium'                     = 'Helium*'
    'HWInfo'                     = 'HWiNFO*'
    'HWMonitor'                  = 'CPUID HWMonitor*'
    'IrfanView'                  = 'IrfanView*'
    'iTunes'                     = 'iTunes'
    'K-Lite Codec Standard'      = 'K-Lite Codec Pack*'
    'LibreOffice'                = 'LibreOffice*'
    'Librewolf'                  = 'LibreWolf*'
    'MSI Afterburner'            = 'MSI Afterburner*'
    'Mullvad Browser'            = 'Mullvad Browser*'
    'Mullvad VPN'                = 'Mullvad VPN*'
    'Nanazip'                    = 'appx:M2Team.NanaZip*'
    'Notepad++'                  = 'Notepad++*'
    'OBS Studio'                 = 'OBS Studio*'
    'OpenOffice'                 = 'OpenOffice*'
    'PowerShell 7'               = 'PowerShell 7*'
    'PowerToys'                  = 'PowerToys*'
    'Process Lasso'              = 'Process Lasso*'
    'Proton VPN'                 = 'Proton VPN*'
    'qBitTorrent'                = 'qBittorrent*'
    'ShareX'                     = 'ShareX*'
    'Signal'                     = 'Signal*'
    'Steam'                      = 'Steam'
    'TeamSpeak'                  = 'TeamSpeak*'
    'Telegram'                   = 'Telegram Desktop*'
    'Tor Browser'                = 'Tor Browser*'
    'Ubisoft Connect'            = 'Ubisoft Connect*'
    'Visual C++ (2015+)'         = 'Microsoft Visual C++ 2015-20* Redistributable (x64)*'
    'Vivaldi'                    = 'Vivaldi*'
    'VLC Media Player'           = 'VLC media player*'
    'Waterfox'                   = 'Waterfox*'
    'WhatsApp'                   = 'appx:5319275A.WhatsAppDesktop*'
    'Zen Browser'                = 'Zen Browser*'
}

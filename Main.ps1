param([switch]$NoConhostRelaunch)

if ($PSVersionTable.PSEdition -ne 'Desktop') {
    Write-Host ""
    Write-Host "  This tool requires Windows PowerShell 5.1." -ForegroundColor Red
    Write-Host "  It is currently running under $($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion)." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Relaunch it with powershell.exe, not pwsh.exe. For example:" -ForegroundColor Cyan
    Write-Host "      powershell.exe -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`"" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

if ($env:WT_SESSION -and -not $NoConhostRelaunch -and $MyInvocation.MyCommand.Path) {
    Start-Process conhost.exe -WindowStyle Hidden -ArgumentList "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`" -NoConhostRelaunch"
    exit
}

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $psExe = (Get-Process -Id $PID).Path
    if ($MyInvocation.MyCommand.Path) {

        Start-Process conhost.exe -Verb RunAs -WindowStyle Hidden -ArgumentList "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`" -NoConhostRelaunch"
    } else {
        $tmp = Join-Path $env:TEMP "WinConfigTool.ps1"
        Invoke-WebRequest -UseBasicParsing -Uri $MyInvocation.MyCommand.Definition -OutFile $tmp -ErrorAction SilentlyContinue
        if (-not (Test-Path $tmp)) {
            $MyInvocation.MyCommand.ScriptBlock.Ast.Extent.Text | Out-File -FilePath $tmp -Encoding UTF8
        }
        Start-Process $psExe -Verb RunAs -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tmp`""
    }
    exit
}

$ProgressPreference = 'SilentlyContinue'

Add-Type -Namespace SWT -Name Win32 -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
[DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);
'@
function Hide-ConsoleWindow {
    $h = [SWT.Win32]::GetConsoleWindow()
    if ($h -ne [IntPtr]::Zero) { [SWT.Win32]::ShowWindow($h, 0) | Out-Null }
}
Hide-ConsoleWindow

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

$RepoBase = "https://raw.githubusercontent.com/PaladinXV/Simple-Windows-11-Setup-Debloat-Tool/main"

$ToolRoot = $PSScriptRoot
$ModuleFiles = @(
    @{ Folder = "Modules";  File = "Helpers.ps1" }
    @{ Folder = "Programs"; File = "Winget.ps1" }
    @{ Folder = "Programs"; File = "Chocolatey.ps1" }
    @{ Folder = "Programs"; File = "OneDrive.ps1" }
    @{ Folder = "Programs"; File = "Edge.ps1" }
    @{ Folder = "Programs"; File = "AppRemoval.ps1" }
    @{ Folder = "Setup";    File = "Personalization.ps1" }
    @{ Folder = "Setup";    File = "StartMenu.ps1" }
    @{ Folder = "Setup";    File = "Privacy.ps1" }
    @{ Folder = "Setup";    File = "Miscellaneous.ps1" }
    @{ Folder = "Setup";    File = "WindowsUpdates.ps1" }
    @{ Folder = "Setup";    File = "Defender.ps1" }
    @{ Folder = "Setup";    File = "EdgeTweaks.ps1" }
    @{ Folder = "Setup";    File = "FolderOptions.ps1" }
    @{ Folder = "Setup";    File = "Mouse.ps1" }
    @{ Folder = "Setup";    File = "Sound.ps1" }
    @{ Folder = "Setup";    File = "Taskbar.ps1" }
    @{ Folder = "Setup";    File = "Gaming.ps1" }
    @{ Folder = "Setup";    File = "Power.ps1" }
    @{ Folder = "Setup";    File = "Laptop.ps1" }
    @{ Folder = "Setup";    File = "Notifications.ps1" }
    @{ Folder = "Setup";    File = "DNS.ps1" }
    @{ Folder = "Setup";    File = "ConfigPresets.ps1" }
    @{ Folder = "Setup";    File = "UnpinApps.ps1" }
    @{ Folder = "UI";       File = "Dialogs.ps1" }
    @{ Folder = "UI";       File = "Overlay.ps1" }
    @{ Folder = "UI";       File = "Sections.ps1" }
    @{ Folder = "Core";     File = "ConfigState.ps1" }
    @{ Folder = "Core";     File = "RunLog.ps1" }
    @{ Folder = "Core";     File = "Apply.ps1" }
    @{ Folder = "Core";     File = "UserConfig.ps1" }
    @{ Folder = "Core";     File = "Shortcuts.ps1" }
)

foreach ($m in $ModuleFiles) {
    $localPath = if ($PSScriptRoot) { Join-Path $PSScriptRoot (Join-Path $m.Folder $m.File) } else { $null }
    $repoIsConfigured = $RepoBase -notlike "*<yourusername>*"

    if ($localPath -and (Test-Path $localPath)) {
        . $localPath
    } elseif ($repoIsConfigured) {
        try {
            Invoke-Expression (Invoke-RestMethod -Uri "$RepoBase/$($m.Folder)/$($m.File)")
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Could not load module '$($m.Folder)\$($m.File)'.`n`nExpected locally at:`n$localPath`n`nAlso failed to fetch from:`n$RepoBase/$($m.Folder)/$($m.File)`n`n$_",
                "Simple Windows Tool - Module Load Error"
            ) | Out-Null
            exit
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show(
            "Missing module file: $($m.Folder)\$($m.File)`n`nExpected at:`n$localPath`n`nMake sure this file exists in that exact folder next to Main.ps1.",
            "Simple Windows Tool - Module Load Error"
        ) | Out-Null
        exit
    }
}

$AppRemovals += $OneDriveRemoval
$AppRemovals += $EdgeRemoval
$AppRemovals = $AppRemovals | Sort-Object { $_.Name }

foreach ($entry in (@($AppRemovals) + @($UnpinTweaks))) {
    if ($AppDescriptions.ContainsKey($entry.Name)) {
        $entry.Description = $AppDescriptions[$entry.Name].Text
        if ($AppDescriptions[$entry.Name].Safety) { $entry.SafetyLevel = $AppDescriptions[$entry.Name].Safety }
        $entry.SafetyNote = $AppDescriptions[$entry.Name].Note
    }
}

$Tweaks = @() + $PersonalizationTweaks + $StartMenuTweaks + $PrivacyTweaks + $MiscellaneousTweaks + $WindowsUpdateTweaks + $DefenderTweaks + $EdgeTweaks + $FolderOptionsTweaks + $MouseTweaks + $SoundTweaks + $TaskbarTweaks + $GamingTweaks + $PowerTweaks + $LaptopTweaks + $NotificationsTweaks + $DnsTweaks

$layoutPath = if ($PSScriptRoot) { Join-Path $PSScriptRoot "UI\Layout.xaml" } else { $null }
$layoutText = $null
if ($layoutPath -and (Test-Path -LiteralPath $layoutPath)) {
    $layoutText = Get-Content -LiteralPath $layoutPath -Raw -Encoding UTF8
} elseif ($repoIsConfigured) {
    try { $layoutText = (Invoke-WebRequest -UseBasicParsing -Uri "$RepoBase/UI/Layout.xaml" -ErrorAction Stop).Content } catch { }
}
if (-not $layoutText) {
    [System.Windows.Forms.MessageBox]::Show("The window layout (UI\Layout.xaml) could not be found. Please make sure all of the tool's files are present.", "Simple Windows Tool") | Out-Null
    exit 1
}
[xml]$xaml = $layoutText

$reader = New-Object System.Xml.XmlNodeReader $xaml
try {
    $window = [Windows.Markup.XamlReader]::Load($reader)
} catch {
    [System.Windows.Forms.MessageBox]::Show(
        "The UI failed to load. This is the actual error - please share this if reporting the issue:`n`n$($_.Exception.Message)`n`n$($_.Exception.InnerException.Message)",
        "Simple Windows Tool - XAML Load Error"
    ) | Out-Null
    exit
}

$Pages = @{
    Info       = $window.FindName("PageInfo")
    Restore    = $window.FindName("PageRestore")
    Apps       = $window.FindName("PageApps")
    Config     = $window.FindName("PageConfig")
    Programs   = $window.FindName("PagePrograms")
    Shortcuts  = $window.FindName("PageShortcuts")
}

$NavButtons = @{
    Info       = $window.FindName("NavInfo")
    Restore    = $window.FindName("NavRestore")
    Apps       = $window.FindName("NavApps")
    Config     = $window.FindName("NavConfig")
    Programs   = $window.FindName("NavPrograms")
    Shortcuts  = $window.FindName("NavShortcuts")
}

$AppsUninstallList = $window.FindName("AppsUninstallList")
$AppsInstallList   = $window.FindName("AppsInstallList")
$AppsDescTitle = $window.FindName("AppsDescTitle")
$AppsDescBody = $window.FindName("AppsDescBody")
$AppsDescSafetyRow = $window.FindName("AppsDescSafetyRow")
$AppsDescSafetyDot = $window.FindName("AppsDescSafetyDot")
$AppsDescSafetyText = $window.FindName("AppsDescSafetyText")
$ConfigTweaksCol = $window.FindName("ConfigTweaksCol")
$ConfigDescTitle = $window.FindName("ConfigDescTitle")
$ConfigDescBody = $window.FindName("ConfigDescBody")
$ConfigDescSafetyRow = $window.FindName("ConfigDescSafetyRow")
$ConfigDescSafetyDot = $window.FindName("ConfigDescSafetyDot")
$ConfigDescSafetyText = $window.FindName("ConfigDescSafetyText")
$ProgramsWingetList = $window.FindName("ProgramsWingetList")
$ProgramsChocoList  = $window.FindName("ProgramsChocoList")
$ProgramsWingetTool = $window.FindName("ProgramsWingetTool")
$ProgramsChocoTool  = $window.FindName("ProgramsChocoTool")
$ProgramsDescTitle  = $window.FindName("ProgramsDescTitle")
$ProgramsDescBody   = $window.FindName("ProgramsDescBody")
$BtnSourceWinget    = $window.FindName("BtnSourceWinget")
$BtnSourceChoco     = $window.FindName("BtnSourceChoco")
$StatusText    = $window.FindName("StatusText")
$ProgressBar   = $window.FindName("ProgressBar")
$BusyOverlay     = $window.FindName("BusyOverlay")
$Spinner         = $window.FindName("Spinner")
$OverlayTitle    = $window.FindName("OverlayTitle")
$OverlaySummary  = $window.FindName("OverlaySummary")
$OverlayDetail   = $window.FindName("OverlayDetail")
$OverlayNote     = $window.FindName("OverlayNote")
$BtnOverlayClose = $window.FindName("BtnOverlayClose")
$BtnOverlayCancel = $window.FindName("BtnOverlayCancel")
$BtnOverlaySkip = $window.FindName("BtnOverlaySkip")
$OverlayRunButtons = $window.FindName("OverlayRunButtons")

$CancelToken = [hashtable]::Synchronized(@{ Requested = $false })
$SkipToken = [hashtable]::Synchronized(@{ Requested = $false })

$ConfigToggles = New-Object System.Collections.Generic.List[object]
$ConfigCombos = New-Object System.Collections.Generic.List[object]

function Start-PageAnimation {
    param($Page)
    $shift = New-Object System.Windows.Media.TranslateTransform
    $Page.RenderTransform = $shift
    $ease = New-Object System.Windows.Media.Animation.CubicEase
    $ease.EasingMode = "EaseOut"
    $fade = New-Object System.Windows.Media.Animation.DoubleAnimation(0.0, 1.0, [TimeSpan]::FromMilliseconds(180))
    $fade.EasingFunction = $ease
    $slide = New-Object System.Windows.Media.Animation.DoubleAnimation(10.0, 0.0, [TimeSpan]::FromMilliseconds(180))
    $slide.EasingFunction = $ease
    $Page.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $fade)
    $shift.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, $slide)
}

function Show-Page {
    param([string]$Key)
    $alreadyShowing = ($Pages[$Key].Visibility -eq "Visible")
    foreach ($k in $Pages.Keys) {
        $Pages[$k].Visibility = if ($k -eq $Key) { "Visible" } else { "Collapsed" }
        $NavButtons[$k].Background = if ($k -eq $Key) { $window.Resources["NavActive"] } else { "Transparent" }
    }
    $SearchPanel = $window.FindName("SearchPanel")
    if ($Key -in @("Apps", "Config", "Programs")) {
        $SearchPanel.Visibility = "Visible"
    } else {
        $SearchPanel.Visibility = "Collapsed"
        $searchBoxRef = $window.FindName("SearchBox")
        if ($searchBoxRef.Text) { $searchBoxRef.Text = "" }
    }

    if (-not $alreadyShowing) { Start-PageAnimation -Page $Pages[$Key] }
    if ($Key -eq "Programs" -and (Get-Command Update-ProgramStatuses -ErrorAction SilentlyContinue)) { Update-ProgramStatuses }
    if ($Key -eq "Restore" -and (Get-Command Update-RestorePointList -ErrorAction SilentlyContinue)) { Update-RestorePointList }
    if (Get-Command Update-BottomBar -ErrorAction SilentlyContinue) { Update-BottomBar }
}

foreach ($k in $NavButtons.Keys) {
    $key = $k
    $NavButtons[$key].Add_Click({ Show-Page -Key $key }.GetNewClosure())
}

Show-Page -Key "Info"

$BtnRestorePoint = $window.FindName("BtnRestorePoint")
$RestorePointStatus = $window.FindName("RestorePointStatus")
$RestorePointList = $window.FindName("RestorePointList")

function Get-RestorePointList {
    try { $points = @(Get-ComputerRestorePoint -ErrorAction Stop) } catch { return @() }
    $list = foreach ($p in $points) {
        $when = $null
        try { $when = [System.Management.ManagementDateTimeConverter]::ToDateTime($p.CreationTime) } catch { }
        if (-not $when -and "$($p.CreationTime)" -match '^(\d{14})\.\d+([+-]\d{3})$') {
            $stamp = [datetime]::ParseExact($Matches[1], "yyyyMMddHHmmss", [System.Globalization.CultureInfo]::InvariantCulture)
            $when = [datetime]::SpecifyKind($stamp.AddMinutes(-[int]$Matches[2]), [System.DateTimeKind]::Utc).ToLocalTime()
        }
        [PSCustomObject]@{
            Created     = $when
            Description = [string]$p.Description
        }
    }
    return @($list | Sort-Object Created -Descending)
}

function New-RestorePointRow {
    param([string[]]$Cells, [switch]$Header)
    $row = New-Object System.Windows.Controls.Grid
    $row.Margin = "0,0,0,4"
    foreach ($w in 170, 0) {
        $col = New-Object System.Windows.Controls.ColumnDefinition
        $col.Width = if ($w -eq 0) { [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) } else { [System.Windows.GridLength]::new($w) }
        $row.ColumnDefinitions.Add($col) | Out-Null
    }
    for ($i = 0; $i -lt 2; $i++) {
        $t = New-Object System.Windows.Controls.TextBlock
        $t.Text = $Cells[$i]
        $t.TextTrimming = "CharacterEllipsis"
        $t.Margin = "0,0,12,0"
        $t.Foreground = if ($Header) { $window.Resources["SubText"] } else { $window.Resources["Text"] }
        if ($Header) { $t.FontWeight = "SemiBold" }
        [System.Windows.Controls.Grid]::SetColumn($t, $i)
        $row.Children.Add($t) | Out-Null
    }
    return $row
}

function Update-RestorePointList {
    $RestorePointList.Children.Clear()
    $points = @(Get-RestorePointList)
    if ($points.Count -eq 0) {
        $none = New-Object System.Windows.Controls.TextBlock
        $none.Text = "No restore points found. If you expected some, System Protection may be turned off - use the Restore Point shortcut to check."
        $none.TextWrapping = "Wrap"
        $none.Foreground = $window.Resources["SubText"]
        $RestorePointList.Children.Add($none) | Out-Null
        return
    }
    $RestorePointList.Children.Add((New-RestorePointRow -Cells @("Created", "Description") -Header)) | Out-Null
    foreach ($p in @($points | Select-Object -First 10)) {
        $when = if ($p.Created) { $p.Created.ToString("d MMM yyyy, HH:mm") } else { "Unknown" }
        $RestorePointList.Children.Add((New-RestorePointRow -Cells @($when, $p.Description))) | Out-Null
    }
    if ($points.Count -gt 10) {
        $more = New-Object System.Windows.Controls.TextBlock
        $more.Text = "Showing the 10 most recent of $($points.Count) restore points."
        $more.Foreground = $window.Resources["SubText"]
        $more.FontSize = 12
        $more.Margin = "0,6,0,0"
        $RestorePointList.Children.Add($more) | Out-Null
    }
}

function Invoke-RestorePointCreation {
    $BtnRestorePoint.IsEnabled = $false
    $RestorePointStatus.Text = "Creating restore point..."
    Update-UI
    $result = New-SystemRestorePoint
    $RestorePointStatus.Text = $result.Message
    Update-RestorePointList
    if ($result.LimitHit) {
        Show-AppMessage -Message "Windows only allows one restore point every 24 hours, and one already exists. No new restore point was created."
    }
    $BtnRestorePoint.IsEnabled = $true
}

$BtnRestorePoint.Add_Click({ Invoke-RestorePointCreation })
$window.FindName("BtnCheckRestorePoints").Add_Click({
    try { Start-Process -FilePath "$env:SystemRoot\System32\rstrui.exe" -ErrorAction Stop }
    catch { Show-AppMessage -Message ("Couldn't open System Restore.`n`n" + $_.Exception.Message) }
})

$ZoomCombo = $window.FindName("ZoomCombo")
$RootScale = $window.FindName("RootScale")
$BaseWidth = 1040
$BaseHeight = 720
$ZoomCombo.Add_SelectionChanged({
    if (-not $ZoomCombo.SelectedItem) { return }
    $scale = [double]([regex]::Match($ZoomCombo.SelectedItem.Content.ToString(), '\d+').Value) / 100
    $RootScale.ScaleX = $scale
    $RootScale.ScaleY = $scale
    $window.Width = $BaseWidth * $scale
    $window.Height = $BaseHeight * $scale
})

$AllCheckboxes = New-Object System.Collections.Generic.List[System.Windows.Controls.CheckBox]
$AllOptionSelectors = New-Object System.Collections.Generic.List[System.Windows.Controls.ComboBox]
$AllGroups = New-Object System.Collections.Generic.List[PSCustomObject]
$AllHeaderSyncs = New-Object System.Collections.Generic.List[scriptblock]

$script:ApplyAllScopes = $false
$script:ProgressExtraDone = 0
$script:ProgressExtraTotal = 0

Get-AppxSnapshot -Refresh | Out-Null

New-CategorySection -Title "Apps list" -Items $AppRemovals -TargetCol $AppsUninstallList -DescTitleEl $AppsDescTitle -DescBodyEl $AppsDescBody -Scope "AppsUninstall"
New-CategorySection -Title "Unpin apps" -Items $UnpinTweaks -TargetCol $AppsUninstallList -DescTitleEl $AppsDescTitle -DescBodyEl $AppsDescBody -NoStatus -Scope "AppsUninstall"

$script:DeepClean = $false
$deepCard = New-Object System.Windows.Controls.Border
$deepCard.Background = $window.Resources["CardBg"]
$deepCard.CornerRadius = 6
$deepCard.Padding = "18,14,18,14"
$deepCard.Margin = "0,0,0,20"
$deepGrid = New-Object System.Windows.Controls.Grid
$deepGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition)) | Out-Null
$deepToggleCol = New-Object System.Windows.Controls.ColumnDefinition
$deepToggleCol.Width = [System.Windows.GridLength]::Auto
$deepGrid.ColumnDefinitions.Add($deepToggleCol) | Out-Null
$deepText = New-Object System.Windows.Controls.StackPanel
$deepTitle = New-Object System.Windows.Controls.TextBlock
$deepTitle.Text = "Deep Clean"
$deepTitle.FontSize = 16
$deepTitle.FontWeight = "SemiBold"
$deepTitle.Foreground = $window.Resources["Text"]
$deepDesc = New-Object System.Windows.Controls.TextBlock
$deepDesc.Text = "Selected apps are removed from the system entirely rather than the current user. This prevents Windows Update from reinstalling them. The down side is that a deep clean will take much longer and re-installing the apps will require the full version."
$deepDesc.Foreground = $window.Resources["SubText"]
$deepDesc.TextWrapping = "Wrap"
$deepDesc.Margin = "0,4,16,0"
$deepText.Children.Add($deepTitle) | Out-Null
$deepText.Children.Add($deepDesc) | Out-Null
$deepToggle = New-Object System.Windows.Controls.CheckBox
$deepToggle.Style = $window.Resources["ToggleSwitch"]
$deepToggle.VerticalAlignment = "Center"
[System.Windows.Controls.Grid]::SetColumn($deepToggle, 1)
$deepGrid.Children.Add($deepText) | Out-Null
$deepGrid.Children.Add($deepToggle) | Out-Null
$deepCard.Child = $deepGrid
$AppsUninstallList.Children.Add($deepCard) | Out-Null
$deepToggle.Add_Checked({ $script:DeepClean = $true })
$deepToggle.Add_Unchecked({ $script:DeepClean = $false })

$ReinstallApps = @()
$ordered = @($AppRemovals | Sort-Object { $_.Name })
foreach ($app in $ordered) {
    if (-not ($app.ContainsKey('ReinstallId') -and $app.ReinstallId)) { continue }
    $ReinstallApps += @{
        Name        = $app.Name
        Id          = $app.ReinstallId
        Source      = $app.ReinstallSource
        Category    = "Reinstall"
        Recommended = $false
        Description = $app.Description
        SafetyLevel = $(if ($app.ContainsKey('SafetyLevel')) { $app.SafetyLevel } else { '' })
        SafetyNote  = $(if ($app.ContainsKey('SafetyNote')) { $app.SafetyNote } else { '' })
        Detect      = $app.Detect
        AppxIds     = $(if ($app.ContainsKey('AppxIds')) { @($app.AppxIds) } else { @() })
        CloseAfterInstall = $(if ($app.ContainsKey('CloseAfterInstall')) { $app.CloseAfterInstall } else { '' })
    }
}

$installNote = New-Object System.Windows.Controls.TextBlock
$installNote.Text = "If Deep Clean was used, apps will have to be downloaded via Winget and will take some time."
$installNote.Foreground = "#FF9500"
$installNote.TextWrapping = "Wrap"
$installNote.Margin = "0,0,0,14"
$AppsInstallList.Children.Add($installNote) | Out-Null

New-CategorySection -Title "Apps list" -Items $ReinstallApps -TargetCol $AppsInstallList -DescTitleEl $AppsDescTitle -DescBodyEl $AppsDescBody -Scope "AppsInstall"

$BtnDetectApps = $window.FindName("BtnDetectApps")
$BtnDetectApps.Add_Click({
    $StatusText.Text = "Scanning installed packages..."
    Update-UI
    Get-AppxSnapshot -Refresh | Out-Null
    Update-AllStatuses
    $StatusText.Text = "Status refreshed."
})

$BtnAppsUninstall = $window.FindName("BtnAppsUninstall")
$BtnAppsInstall   = $window.FindName("BtnAppsInstall")

function Update-BottomBar {
    $onAppsUninstall = ($Pages["Apps"].Visibility -eq "Visible") -and
                       ($AppsInstallList.Visibility -ne "Visible")
    $onConfig = ($Pages["Config"].Visibility -eq "Visible")
    $onAppsInstall = ($Pages["Apps"].Visibility -eq "Visible") -and ($AppsInstallList.Visibility -eq "Visible")
    $window.FindName("SafetyLegend").Visibility   = if ($onAppsUninstall -or $onAppsInstall -or $onConfig) { "Visible" } else { "Collapsed" }
    $showAggressive = $onAppsUninstall -or $onAppsInstall -or ($onConfig -and @($ConfigPresets["Aggressive"]).Count -gt 0)
    $window.FindName("BtnAggressive").Visibility  = if ($showAggressive) { "Visible" } else { "Collapsed" }
    $window.FindName("BtnRecommended").Visibility = if ($onAppsUninstall -or $onAppsInstall -or $onConfig) { "Visible" } else { "Collapsed" }
    $noApply = ($Pages["Info"].Visibility -eq "Visible") -or ($Pages["Restore"].Visibility -eq "Visible")
    $onShortcuts = ($Pages["Shortcuts"].Visibility -eq "Visible")
    $window.FindName("BtnApply").Visibility = if ($noApply -or $onShortcuts) { "Collapsed" } else { "Visible" }
    $window.FindName("BtnNone").Visibility = if ($noApply -or $onShortcuts) { "Collapsed" } else { "Visible" }
    $window.FindName("BtnAll").Visibility = if ($noApply -or $onConfig -or $onShortcuts) { "Collapsed" } else { "Visible" }
    $window.FindName("BtnBasic").Visibility = if ($Pages["Programs"].Visibility -eq "Visible") { "Visible" } else { "Collapsed" }
    $window.FindName("BtnClearPreset").Visibility = if ($Pages["Info"].Visibility -eq "Visible") { "Visible" } else { "Collapsed" }
    $window.FindName("BtnOpenLog").Visibility = if ($Pages["Info"].Visibility -eq "Visible") { "Visible" } else { "Collapsed" }
    $window.FindName("BtnApplyConfig").Visibility = if ($Pages["Info"].Visibility -eq "Visible") { "Visible" } else { "Collapsed" }
}

function Show-AppsSubView {
    param([string]$View)
    if ($View -eq "Uninstall") {
        if ($AppsUninstallList.Visibility -ne "Visible") { Start-PageAnimation -Page $AppsUninstallList }
        $AppsUninstallList.Visibility = "Visible"
        $AppsInstallList.Visibility = "Collapsed"

        $BtnAppsUninstall.BorderBrush = $window.Resources["Accent"]
        $BtnAppsInstall.BorderBrush   = $window.Resources["CardBg"]
    } else {
        if ($AppsInstallList.Visibility -ne "Visible") { Start-PageAnimation -Page $AppsInstallList }
        $AppsUninstallList.Visibility = "Collapsed"
        $AppsInstallList.Visibility = "Visible"
        $BtnAppsInstall.BorderBrush   = $window.Resources["Accent"]
        $BtnAppsUninstall.BorderBrush = $window.Resources["CardBg"]
    }
    Update-BottomBar
}
$BtnAppsUninstall.Add_Click({ Show-AppsSubView -View "Uninstall" })
$BtnAppsInstall.Add_Click({ Show-AppsSubView -View "Install" })
Show-AppsSubView -View "Uninstall"

$excludedFromConfig = @("System Apps")
$configCategoryOrder = @("Folder Options", "Personalization", "Start Menu", "Taskbar", "Notifications", "Privacy & Security", "Miscellaneous", "Microsoft Edge", "Defender", "Windows Updates", "Power", "Laptop", "Mouse", "Sound", "Gaming", "DNS")
$allConfigCategories = $Tweaks | ForEach-Object { $_.Category } | Where-Object { $_ -notin $excludedFromConfig } | Sort-Object -Unique

$configCategories = @($configCategoryOrder | Where-Object { $_ -in $allConfigCategories }) + @($allConfigCategories | Where-Object { $_ -notin $configCategoryOrder } | Sort-Object)

foreach ($cat in $configCategories) {
    $items = Sort-SectionItems -Items @($Tweaks | Where-Object { $_.Category -eq $cat })
    New-CategorySection -Title $cat -Items $items -TargetCol $ConfigTweaksCol -DescTitleEl $ConfigDescTitle -DescBodyEl $ConfigDescBody -Toggles -Scope "Config"
}

$BtnDetectTweaks = $window.FindName("BtnDetectTweaks")
$BtnDetectTweaks.Add_Click({
    Sync-ConfigToSystem
    Update-AllStatuses
    $StatusText.Text = "Status refreshed."
})

$BtnRevertAll = $window.FindName("BtnRevertAll")
$BtnRevertAll.Add_Click({
    foreach ($e in $ConfigToggles) { if (-not (Test-ToggleLocked -Entry $e)) { $e.Cb.IsChecked = $false } }
    foreach ($e in $ConfigCombos) {
        $def = Get-DefaultOptionIndex -Item $e.Item
        $e.Combo.SelectedIndex = if ($def -ge 1) { $def - 1 } else { $e.Baseline - 1 }
    }
    Set-RunInProgress -Running $true
    Show-OverlayComplete -Title "Warning!" -Message "This will set all changes to the Windows default"
    $OverlayNote.Text = 'Close this pop-up and click "Apply Selected" to apply.'
    $OverlayNote.Visibility = [System.Windows.Visibility]::Visible
})

$SearchBox = $window.FindName("SearchBox")

$SearchBox.Add_TextChanged({ Update-ItemVisibility })

$wingetLabel = New-Object System.Windows.Controls.TextBlock
$wingetPrefixRun = New-Object System.Windows.Documents.Run -ArgumentList "Check/Install Winget - "
$wingetStateRun = New-Object System.Windows.Documents.Run
$wingetStateRun.FontWeight = "SemiBold"
$wingetLabel.Inlines.Add($wingetPrefixRun) | Out-Null
$wingetLabel.Inlines.Add($wingetStateRun) | Out-Null

function Update-WingetButton {
    $hasWinget = [bool](Test-CommandExists winget)
    $wingetStateRun.Text = if ($hasWinget) { "Installed" } else { "Not installed" }
    $wingetStateRun.Foreground = if ($hasWinget) { "#34C759" } else { "#FF3B30" }
}
$btnInstallWinget = New-Object System.Windows.Controls.Button
$btnInstallWinget.Content = $wingetLabel
Update-WingetButton
$btnInstallWinget.VerticalAlignment = "Center"
$btnInstallWinget.Add_Click({
    if (Test-CommandExists winget) {
        $version = ""
        $working = $true
        try {
            $output = @(& winget --version 2>$null)
            $exitCode = $LASTEXITCODE
            $version = if ($output.Count -gt 0) { "$($output[0])".Trim() } else { "" }
            if ($exitCode -ne 0 -or -not $version) { $working = $false }
        } catch { $working = $false }
        $confirmed = if ($working) {
            Show-ConfirmDialog -Question "Are you sure you want to repair / update Winget?" -Detail "Winget is already installed and working (version $version)."
        } else {
            Show-ConfirmDialog -Question "Are you sure you want to repair Winget?" -Detail "Winget is installed but isn't responding properly."
        }
        if (-not $confirmed) { return }
    }
    Invoke-OverlayTask -Working "Installing Winget" -Note "This may take some time depending on your connection speed." -Work {
        $r = Install-Winget
        if ($r.Stopped) { @{ Title = "Stopped"; Message = "The Winget install was stopped. It may be partly installed - click Check/Install Winget again to finish or repair it." } }
        elseif ($r.Success) { @{ Title = "Winget installed"; Message = "Winget is installed and up to date." } }
        elseif (-not $r.Error) { @{ Title = "Almost done"; Message = "Winget was installed, but Windows hasn't made it available to this window yet. Close and reopen the tool and it will show as installed." } }
        else { @{ Title = "Winget install failed"; Message = "Winget could not be installed: $($r.Error)" } }
    }
    Update-WingetButton
})
$ProgramsWingetTool.Children.Add($btnInstallWinget) | Out-Null

function Wait-Brief {
    if (Get-Command Wait-UI -ErrorAction SilentlyContinue) { Wait-UI -Milliseconds 50 } else { Update-UI; Start-Sleep -Milliseconds 50 }
}

function Invoke-WingetCommand {
    param([string]$Arguments, [string]$FileName = "winget")
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FileName
    $psi.Arguments = $Arguments
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.RedirectStandardInput = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    try { $proc.StandardInput.Close() } catch { }
    $outTask = $proc.StandardOutput.ReadToEndAsync()
    $null = $proc.StandardError.ReadToEndAsync()
    $stopped = ""
    while (-not $proc.WaitForExit(0)) {
        if ($CancelToken.Requested) { $stopped = "Cancelled"; break }
        if ($SkipToken.Requested) { $stopped = "Skipped"; break }
        Wait-Brief
    }
    if ($stopped) {
        Stop-ProcessTree -Process $proc
        return @{ Stopped = $stopped; ExitCode = $null; Output = "" }
    }
    $out = ""
    try { if ($outTask.Wait(3000)) { $out = $outTask.Result } } catch { }
    return @{ Stopped = ""; ExitCode = $proc.ExitCode; Output = $out }
}

function ConvertFrom-WingetUpgradeList {
    param([string]$Output)
    $lines = @($Output -split "`n" | ForEach-Object { ($_ -split "`r")[-1].TrimEnd() })
    $sep = -1
    for ($n = 1; $n -lt $lines.Count; $n++) { if ($lines[$n] -match '^-{10,}$') { $sep = $n; break } }
    if ($sep -lt 1) { return @() }
    $header = $lines[$sep - 1]
    $starts = @([regex]::Matches($header, '\S+') | ForEach-Object { $_.Index })
    if ($starts.Count -lt 4) { return @() }
    $apps = @()
    for ($n = $sep + 1; $n -lt $lines.Count; $n++) {
        $line = $lines[$n]
        if (-not $line.Trim() -or $line -match '^\d+ ') { break }
        if ($line.Length -le $starts[2]) { continue }
        $id = $line.Substring($starts[1], $starts[2] - $starts[1]).Trim()
        if (-not $id) { continue }
        $apps += [PSCustomObject]@{
            Name      = $line.Substring(0, $starts[1]).Trim()
            Id        = $id
            Available = $(if ($line.Length -gt $starts[3]) { ($line.Substring($starts[3]) -split '\s+')[0] } else { "" })
        }
    }
    return $apps
}

function Invoke-WingetUpdates {
    if (-not (Test-CommandExists winget)) {
        Show-AppMessage -Message "Winget isn't installed.`n`nClick Check/Install Winget first."
        return
    }
    Set-RunInProgress -Running $true
    $OverlayTitle.Text = "Checking for updates..."
    $ProgressBar.Visibility = [System.Windows.Visibility]::Collapsed
    $BtnOverlaySkip.Visibility = [System.Windows.Visibility]::Collapsed
    Update-UI
    $check = Invoke-WingetCommand -Arguments "upgrade --accept-source-agreements --disable-interactivity"
    if ($CancelToken.Requested) { Set-RunInProgress -Running $false; return }
    $apps = @(ConvertFrom-WingetUpgradeList -Output $check.Output)
    if ($apps.Count -eq 0) {
        Show-OverlayComplete -Title "No Updates Required" -Message ""
        return
    }
    $script:RunLogLabel = "User Apps - Updates"
    "=== Run started ===" | Write-RunLog
    $OverlayTitle.Text = "Updating Apps"
    $OverlaySummary.Text = ($apps.Name -join ", ")
    $OverlaySummary.Visibility = [System.Windows.Visibility]::Visible
    $ProgressBar.Visibility = [System.Windows.Visibility]::Visible
    $BtnOverlaySkip.Visibility = [System.Windows.Visibility]::Visible
    $updated = @(); $failed = @(); $skipped = @()
    for ($n = 0; $n -lt $apps.Count; $n++) {
        if ($CancelToken.Requested) { break }
        $app = $apps[$n]
        $SkipToken.Requested = $false
        $BtnOverlaySkip.IsEnabled = $true
        $ProgressBar.Value = [math]::Round(($n / $apps.Count) * 100)
        $OverlayDetail.Text = "Updating $($app.Name) ($($n + 1) of $($apps.Count))"
        $start = Get-Date
        $r = Invoke-WingetCommand -Arguments "upgrade --id `"$($app.Id)`" -e --silent --accept-package-agreements --accept-source-agreements --disable-interactivity"
        $secs = [math]::Round(((Get-Date) - $start).TotalSeconds, 1)
        if ($r.Stopped -eq "Cancelled") { "Cancelled update: $($app.Name)" | Write-RunLog; break }
        if ($r.Stopped -eq "Skipped") { $skipped += $app.Name; "Skipped update: $($app.Name) - skipped with the Skip button" | Write-RunLog; continue }
        if ($r.ExitCode -eq 0) {
            $updated += $app.Name
            "Finished update: $($app.Name) [${secs}s] to $($app.Available)" | Write-RunLog
        } else {
            $hex = "0x{0:X8}" -f ([int64]$r.ExitCode -band 0xFFFFFFFF)
            $failed += $app.Name
            "Failed update: $($app.Name) [${secs}s] - winget error $hex" | Write-RunLog
        }
    }
    "=== Run completed ===" | Write-RunLog
    if ($CancelToken.Requested) { Set-RunInProgress -Running $false; return }
    $ProgressBar.Value = 100
    $lines = @()
    if ($updated.Count) { $lines += "Updated: " + ($updated -join ", ") }
    if ($skipped.Count) { $lines += "Skipped: " + ($skipped -join ", ") }
    if ($failed.Count) { $lines += "Failed: " + ($failed -join ", ") + " - see the log" }
    Show-OverlayComplete -Title $(if ($failed.Count) { "Updates Finished" } else { "Apps Updated!" }) -Message ($lines -join "`n")
}

function Set-ProgramRowStatus {
    param($Row, [string]$Text, [string]$Color)
    $Row.Label.Text = $Text
    $Row.Label.Foreground = $Color
}

function Get-InstalledAppNames {
    $paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    return @(Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName } | ForEach-Object { [string]$_.DisplayName })
}

function Update-ProgramStatuses {
    $installedNames = @(Get-InstalledAppNames)
    $chocoRoot = if ($env:ChocolateyInstall) { $env:ChocolateyInstall } elseif ($env:ProgramData) { Join-Path $env:ProgramData "chocolatey" } else { "" }
    $found = @{}
    foreach ($row in $ProgramStatusRows) {
        $name = $row.Item.Name
        if (-not $found.ContainsKey($name)) {
            $hit = $false
            $pattern = if ($ProgramDetectNames.ContainsKey($name)) { [string]$ProgramDetectNames[$name] } else { "" }
            if ($pattern -like "appx:*") {
                try { $hit = [bool](Get-AppxPackage -Name $pattern.Substring(5) -ErrorAction SilentlyContinue) } catch { }
            } elseif ($pattern) {
                $hit = [bool]($installedNames | Where-Object { $_ -like $pattern } | Select-Object -First 1)
            }
            $found[$name] = $hit
        }
        if (-not $found[$name] -and $row.Item.ContainsKey("ChocoId") -and $chocoRoot -and (Test-Path -LiteralPath (Join-Path $chocoRoot "lib\$($row.Item.ChocoId)"))) { $found[$name] = $true }
    }
    foreach ($row in $ProgramStatusRows) {
        if ($found[$row.Item.Name]) { Set-ProgramRowStatus -Row $row -Text "Installed" -Color "#34C759" }
        else { Set-ProgramRowStatus -Row $row -Text "Not Installed" -Color "Gray" }
    }
}

$btnDetectApps = New-Object System.Windows.Controls.Button
$btnDetectApps.Content = "Detect Apps"
$btnDetectApps.VerticalAlignment = "Center"
$btnDetectApps.Margin = "8,0,0,0"
$btnDetectApps.Add_Click({ Update-ProgramStatuses })
$ProgramsWingetTool.Children.Add($btnDetectApps) | Out-Null

$btnCheckUpdates = New-Object System.Windows.Controls.Button
$btnCheckUpdates.Content = "Check for App Updates"
$btnCheckUpdates.VerticalAlignment = "Center"
$btnCheckUpdates.Margin = "8,0,8,0"
$btnCheckUpdates.Add_Click({ Invoke-WingetUpdates })
$ProgramsWingetTool.Children.Add($btnCheckUpdates) | Out-Null

$chocoButtons = New-Object System.Windows.Controls.StackPanel
$chocoButtons.Orientation = "Horizontal"
$chocoButtons.VerticalAlignment = "Center"
$chocoLabel = New-Object System.Windows.Controls.TextBlock
$chocoPrefixRun = New-Object System.Windows.Documents.Run -ArgumentList "Check/Install Chocolatey - "
$chocoStateRun = New-Object System.Windows.Documents.Run
$chocoStateRun.FontWeight = "SemiBold"
$chocoLabel.Inlines.Add($chocoPrefixRun) | Out-Null
$chocoLabel.Inlines.Add($chocoStateRun) | Out-Null
$btnInstallChoco = New-Object System.Windows.Controls.Button
$btnInstallChoco.Content = $chocoLabel
$btnUninstallChoco = New-Object System.Windows.Controls.Button
$btnUninstallChoco.Content = "Uninstall Chocolatey"
$chocoButtons.Children.Add($btnInstallChoco) | Out-Null
$chocoButtons.Children.Add($btnUninstallChoco) | Out-Null
$btnDetectAppsChoco = New-Object System.Windows.Controls.Button
$btnDetectAppsChoco.Content = "Detect Apps"
$btnDetectAppsChoco.Add_Click({ Update-ProgramStatuses })
$chocoButtons.Children.Add($btnDetectAppsChoco) | Out-Null

function Invoke-ChocoUpdates {
    if (-not (Test-CommandExists choco)) {
        Show-AppMessage -Message "Chocolatey isn't installed.`n`nClick Check/Install Chocolatey first."
        return
    }
    Set-RunInProgress -Running $true
    $OverlayTitle.Text = "Checking for updates..."
    $ProgressBar.Visibility = [System.Windows.Visibility]::Collapsed
    $BtnOverlaySkip.Visibility = [System.Windows.Visibility]::Collapsed
    Update-UI
    $check = Invoke-WingetCommand -FileName "choco" -Arguments "outdated -r --no-color"
    if ($CancelToken.Requested) { Set-RunInProgress -Running $false; return }
    $names = @{}
    foreach ($app in $ChocoApps) { $names[$app.ChocoId.ToLower()] = $app.Name }
    $apps = @(foreach ($line in @($check.Output -split "`r?`n")) {
        if ($line -match '^([^|\s]+)\|([^|]*)\|([^|]*)\|(true|false)$' -and $Matches[4] -eq "false") {
            [PSCustomObject]@{ Id = $Matches[1]; Name = $(if ($names.ContainsKey($Matches[1].ToLower())) { $names[$Matches[1].ToLower()] } else { $Matches[1] }); Available = $Matches[3] }
        }
    })
    if ($apps.Count -eq 0) {
        Show-OverlayComplete -Title "No Updates Required" -Message ""
        return
    }
    $script:RunLogLabel = "User Apps - Chocolatey Updates"
    "=== Run started ===" | Write-RunLog
    $OverlayTitle.Text = "Updating Apps"
    $OverlaySummary.Text = ($apps.Name -join ", ")
    $OverlaySummary.Visibility = [System.Windows.Visibility]::Visible
    $ProgressBar.Visibility = [System.Windows.Visibility]::Visible
    $BtnOverlaySkip.Visibility = [System.Windows.Visibility]::Visible
    $updated = @(); $failed = @(); $skipped = @()
    for ($n = 0; $n -lt $apps.Count; $n++) {
        if ($CancelToken.Requested) { break }
        $app = $apps[$n]
        $SkipToken.Requested = $false
        $BtnOverlaySkip.IsEnabled = $true
        $ProgressBar.Value = [math]::Round(($n / $apps.Count) * 100)
        $OverlayDetail.Text = "Updating $($app.Name) ($($n + 1) of $($apps.Count))"
        $start = Get-Date
        $r = Invoke-WingetCommand -FileName "choco" -Arguments "upgrade $($app.Id) -y --no-progress --no-color"
        $secs = [math]::Round(((Get-Date) - $start).TotalSeconds, 1)
        if ($r.Stopped -eq "Cancelled") { "Cancelled update: $($app.Name)" | Write-RunLog; break }
        if ($r.Stopped -eq "Skipped") { $skipped += $app.Name; "Skipped update: $($app.Name) - skipped with the Skip button" | Write-RunLog; continue }
        if ($r.ExitCode -in @(0, 1641, 3010)) {
            $updated += $app.Name
            "Finished update: $($app.Name) [${secs}s] to $($app.Available)" | Write-RunLog
        } else {
            $failed += $app.Name
            "Failed update: $($app.Name) [${secs}s] - choco exit code $($r.ExitCode)" | Write-RunLog
        }
    }
    "=== Run completed ===" | Write-RunLog
    if ($CancelToken.Requested) { Set-RunInProgress -Running $false; return }
    $ProgressBar.Value = 100
    $lines = @()
    if ($updated.Count) { $lines += "Updated: " + ($updated -join ", ") }
    if ($skipped.Count) { $lines += "Skipped: " + ($skipped -join ", ") }
    if ($failed.Count) { $lines += "Failed: " + ($failed -join ", ") + " - see the log" }
    Show-OverlayComplete -Title $(if ($failed.Count) { "Updates Finished" } else { "Apps Updated!" }) -Message ($lines -join "`n")
}

$btnUpgradeChoco = New-Object System.Windows.Controls.Button
$btnUpgradeChoco.Content = "Check for App Updates"
$btnUpgradeChoco.Add_Click({ Invoke-ChocoUpdates })
$chocoButtons.Children.Add($btnUpgradeChoco) | Out-Null

function Update-ChocoCard {
    $hasChoco = [bool](Test-CommandExists choco)
    $chocoStateRun.Text = if ($hasChoco) { "Installed" } else { "Not installed" }
    $chocoStateRun.Foreground = if ($hasChoco) { "#34C759" } else { "#FF3B30" }
    $btnUninstallChoco.IsEnabled = $hasChoco
}

$btnInstallChoco.Add_Click({
    if (Test-CommandExists choco) {
        Show-AppMessage -Message "Chocolatey is already installed."
        return
    }
    Invoke-OverlayTask -Working "Installing Chocolatey" -Work {
        $r = Install-Chocolatey
        if ($r.Stopped) { @{ Title = "Stopped"; Message = "The Chocolatey install was stopped. It may be partly installed - click Install Chocolatey again to finish it." } }
        elseif ($r.Success) { @{ Title = "Chocolatey has been installed"; Message = "" } }
        else { @{ Title = "Install failed"; Message = "Chocolatey could not be installed: $($r.Error)" } }
    }
    Update-ChocoCard
})

$btnUninstallChoco.Add_Click({
    if (-not (Show-ConfirmDialog -Question "Are you sure you want to uninstall Chocolatey?" -Detail "Apps you installed with it stay installed, but Chocolatey will no longer update or remove them.")) { return }
    Invoke-OverlayTask -Working "Uninstalling Chocolatey" -Work {
        try {
            Uninstall-Chocolatey
            @{ Title = "Chocolatey removed"; Message = "Chocolatey has been removed. Programs you installed with it are still installed." }
        } catch {
            @{ Title = "Uninstall failed"; Message = "Chocolatey could not be fully removed: $($_.Exception.Message)" }
        }
    }
    Update-ChocoCard
})

$ProgramsChocoTool.Children.Add($chocoButtons) | Out-Null
Update-ChocoCard

$ShortcutsList = $window.FindName("ShortcutsList")
foreach ($groupName in $ShortcutGroups.Keys) {
    $wrap = New-Object System.Windows.Controls.Primitives.UniformGrid
    $wrap.Columns = 2
    $wrap.HorizontalAlignment = "Left"
    foreach ($sc in @($ShortcutGroups[$groupName] | Sort-Object { $_.Name })) {
        $btn = New-Object System.Windows.Controls.Button
        $btn.Width = 260
        $btn.Height = 36
        $btn.Margin = "0,0,10,8"
        $btn.HorizontalAlignment = "Left"
        $btn.HorizontalContentAlignment = "Left"
        $btn.Padding = "12,0,12,0"
        $btn.Content = $sc.Name
        $target = $sc
        $btn.Add_Click({
            if ($target.Confirm) {
                if (-not (Show-ConfirmDialog -Question $target.Confirm -Detail $target.ConfirmDetail)) { return }
            }
            if ($target.Action) {
                try { & $target.Action } catch { Show-AppMessage -Message ("Couldn't do $($target.Name):`n`n$($_.Exception.Message)") }
                return
            }
            try {
                if ($target.Args) { Start-Process -FilePath $target.File -ArgumentList $target.Args -ErrorAction Stop }
                else { Start-Process -FilePath $target.File -ErrorAction Stop }
            } catch {
                Show-AppMessage -Message ("Couldn't open $($target.Name):`n`n$($_.Exception.Message)")
            }
        }.GetNewClosure())
        $wrap.Children.Add($btn) | Out-Null
    }
    New-CardSection -Parent $ShortcutsList -Title $groupName -Content $wrap
}

function Add-ProgramColumns {
    param($Target, $Programs, [string]$Scope = "")
    $cats = @($Programs | ForEach-Object { $_.Category } | Select-Object -Unique)
    foreach ($cat in $cats) {
        $inCat = @($Programs | Where-Object { $_.Category -eq $cat } | Sort-Object { $_.Name })
        New-CategorySection -Title $cat -Items $inCat -TargetCol $Target -DescTitleEl $ProgramsDescTitle -DescBodyEl $ProgramsDescBody -NoDots -ProgramStatus -Scope $Scope
    }
}

$ProgramStatusRows = New-Object System.Collections.Generic.List[object]
Add-ProgramColumns -Target $ProgramsWingetList -Programs $WingetApps -Scope "ProgramsWinget"
Add-ProgramColumns -Target $ProgramsChocoList -Programs $ChocoApps -Scope "ProgramsChoco"

function Show-ProgramsSource {
    param([string]$Source)
    $useWinget = ($Source -eq 'Winget')
    $showing = if ($useWinget) { $ProgramsWingetList } else { $ProgramsChocoList }
    if ($showing.Visibility -ne "Visible") { Start-PageAnimation -Page $showing }
    $ProgramsWingetList.Visibility = if ($useWinget) { "Visible" } else { "Collapsed" }
    $ProgramsChocoList.Visibility  = if ($useWinget) { "Collapsed" } else { "Visible" }
    $ProgramsWingetTool.Visibility = if ($useWinget) { "Visible" } else { "Collapsed" }
    $ProgramsChocoTool.Visibility  = if ($useWinget) { "Collapsed" } else { "Visible" }
    $BtnSourceWinget.BorderBrush = if ($useWinget) { $window.Resources["Accent"] } else { $window.Resources["CardBg"] }
    $BtnSourceChoco.BorderBrush  = if ($useWinget) { $window.Resources["CardBg"] } else { $window.Resources["Accent"] }
}
$BtnSourceWinget.Add_Click({ Show-ProgramsSource -Source 'Winget' })
$BtnSourceChoco.Add_Click({ Show-ProgramsSource -Source 'Chocolatey' })
Show-ProgramsSource -Source 'Winget'

$BtnRecommended = $window.FindName("BtnRecommended")
$BtnAggressive = $window.FindName("BtnAggressive")
$BtnAll         = $window.FindName("BtnAll")
$BtnNone        = $window.FindName("BtnNone")
$BtnApply       = $window.FindName("BtnApply")
$ActionButtons  = @($BtnRecommended, $BtnAggressive, $BtnAll, $BtnNone, $BtnApply)

function Select-InstallPreset {
    param([string]$Name)
    $wanted = @($AppPresets[$Name])
    $picked = 0
    foreach ($cb in $AllCheckboxes) {
        if ($ControlScope[$cb] -ne "AppsInstall") { continue }
        $item = $cb.Tag
        $installed = $false
        if ($item.Detect) { try { $installed = [bool](& $item.Detect) } catch { } }
        else { foreach ($id in @($item.AppxIds)) { if ($id -and (Test-AppxInstalled $id)) { $installed = $true } } }
        $cb.IsChecked = ($wanted -contains $item.Name) -and -not $installed
        if ($cb.IsChecked) { $picked++ }
    }
    $StatusText.Text = "$Name preset: $picked removed app(s) selected to reinstall."
}

$BtnRecommended.Add_Click({ if ($Pages["Apps"].Visibility -eq "Visible" -and $AppsInstallList.Visibility -eq "Visible") { Select-InstallPreset -Name 'Recommended' } else { Select-AppPreset -Name 'Recommended' } })
$BtnAggressive.Add_Click({ if ($Pages["Apps"].Visibility -eq "Visible" -and $AppsInstallList.Visibility -eq "Visible") { Select-InstallPreset -Name 'Aggressive' } else { Select-AppPreset -Name 'Aggressive' } })

$BtnAll.Add_Click({
    foreach ($cb in ($AllCheckboxes | Where-Object { $_.IsVisible })) { $cb.IsChecked = $true }
    $StatusText.Text = "All items selected."
})

$BtnNone.Add_Click({
    if ($Pages["Apps"].Visibility -eq "Visible") { $deepToggle.IsChecked = $false }
    $toggleCbs = @($ConfigToggles | ForEach-Object { $_.Cb })
    $configCbx = @($ConfigCombos | ForEach-Object { $_.Combo })
    foreach ($cb in ($AllCheckboxes | Where-Object { $_.IsVisible -and $toggleCbs -notcontains $_ })) { $cb.IsChecked = $false }
    foreach ($combo in ($AllOptionSelectors | Where-Object { $_.IsVisible -and $configCbx -notcontains $_ })) { $combo.SelectedIndex = -1 }
    foreach ($e in ($ConfigToggles | Where-Object { $_.Cb.IsVisible })) { if (-not (Test-ToggleLocked -Entry $e)) { $e.Cb.IsChecked = $false } }
    foreach ($e in ($ConfigCombos | Where-Object { $_.Combo.IsVisible })) {
        $def = Get-DefaultOptionIndex -Item $e.Item
        $e.Combo.SelectedIndex = if ($def -ge 1) { $def - 1 } else { $e.Baseline - 1 }
    }
})

$BtnOverlaySkip.Add_Click({
    $SkipToken.Requested = $true
    $BtnOverlaySkip.IsEnabled = $false
    $OverlayDetail.Text = "Skipping..."
})

$BtnOverlayCancel.Add_Click({
    $BtnOverlaySkip.IsEnabled = $false
    $BusyOverlay.Visibility = [System.Windows.Visibility]::Collapsed

    $CancelToken.Requested = $true
    $BtnOverlayCancel.IsEnabled = $false
    $OverlayTitle.Text = if ($script:OverlayTaskRunning) { "Stopping..." } else { "Stopping after the current item..." }
})

$BtnOverlayClose.Add_Click({ Set-RunInProgress -Running $false })

$BtnApply.Add_Click($ApplyAction)
$BtnApply.Add_Click({ if ($Pages["Programs"].Visibility -eq "Visible") { Update-ProgramStatuses } })
function Reset-DeepCleanIfIdle {
    $anyUninstall = @($AllCheckboxes | Where-Object { $ControlScope[$_] -eq "AppsUninstall" -and $_.IsChecked }).Count -gt 0
    if (-not $anyUninstall) { $deepToggle.IsChecked = $false }
}
$BtnApply.Add_Click({ Reset-DeepCleanIfIdle })

$script:WindowHandle = [IntPtr]::Zero

function Set-TitleBarTheme {
    if ($script:WindowHandle -eq [IntPtr]::Zero) { return }
    $darkMode = 1
    $captionColor = 0x001E1E1E
    $textColor = 0x00FFFFFF
    [SWT.Win32]::DwmSetWindowAttribute($script:WindowHandle, 20, [ref]$darkMode, 4) | Out-Null
    [SWT.Win32]::DwmSetWindowAttribute($script:WindowHandle, 35, [ref]$captionColor, 4) | Out-Null
    [SWT.Win32]::DwmSetWindowAttribute($script:WindowHandle, 36, [ref]$textColor, 4) | Out-Null
}

foreach ($link in @(@("InfoGoApps", "Apps"), @("InfoGoConfig", "Config"), @("InfoGoPrograms", "Programs"), @("InfoGoShortcuts", "Shortcuts"), @("InfoGoRestore", "Restore"))) {
    $target = $link[1]
    $window.FindName($link[0]).Add_Click({ Show-Page -Key $target }.GetNewClosure())
}

$window.FindName("BtnExportConfig").Add_Click({ Export-UserConfig })
$window.FindName("BtnImportConfig").Add_Click({ Import-UserConfig })
$window.FindName("BtnApplyConfig").Add_Click({
    if (-not (Show-ConfirmDialog -Question "Are you sure you want to apply your selections?" -Detail "This applies every selection on every page at once: Windows Apps, Configuration and User Apps.")) { return }
    $script:ApplyAllScopes = $true
    try { & $ApplyAction } finally { $script:ApplyAllScopes = $false }
})
$window.FindName("BtnApplyConfig").Add_Click({ Reset-DeepCleanIfIdle })
function Set-QuickPresetHighlight {
    param([string]$Name)
    foreach ($pair in @(@("BtnQuickRecommended", "Recommended"), @("BtnQuickAggressive", "Aggressive"))) {
        $window.FindName($pair[0]).BorderBrush = if ($pair[1] -eq $Name) { $window.Resources["Accent"] } else { $window.Resources["CardBg"] }
    }
}

$UserAppsBasic = @("7Zip", "HWInfo", "Visual C++ (2015+)", "FireFox", "Notepad++", "VLC Media Player")
$window.FindName("BtnBasic").Add_Click({
    $picked = 0
    foreach ($cb in $AllCheckboxes) {
        if ($ControlScope[$cb] -notin @("ProgramsWinget", "ProgramsChoco") -or -not $cb.IsVisible) { continue }
        $cb.IsChecked = ($UserAppsBasic -contains $cb.Tag.Name)
        if ($cb.IsChecked) { $picked++ }
    }
    $StatusText.Text = "Basic preset selected ($picked apps)."
})

$window.FindName("BtnClearPreset").Add_Click({
    $StatusText.Text = "Clearing selections..."
    Update-UI
    $configBoxes = @($ConfigToggles | ForEach-Object { $_.Cb })
    foreach ($cb in $AllCheckboxes) { if ($configBoxes -notcontains $cb) { $cb.IsChecked = $false } }
    $deepToggle.IsChecked = $false
    Sync-ConfigToSystem
    Set-QuickPresetHighlight -Name ""
    $StatusText.Text = "Preset cleared. Every page now matches your PC's current settings."
})

$window.FindName("BtnQuickRecommended").Add_Click({
    Select-AppPreset -Name "Recommended" -AllItems
    Set-QuickPresetHighlight -Name "Recommended"
    $StatusText.Text = "Recommended preset selected on Windows Apps and Configuration. Press Apply to apply it."
})
$window.FindName("BtnQuickAggressive").Add_Click({
    Select-AppPreset -Name "Aggressive" -AllItems
    Set-QuickPresetHighlight -Name "Aggressive"
    $StatusText.Text = "Aggressive preset selected on Windows Apps and Configuration. Press Apply to apply it."
})
$window.FindName("BtnOpenLog").Add_Click({
    $log = Join-Path $env:TEMP "SimpleWindowsTool-log.txt"
    if (Test-Path -LiteralPath $log) { Start-Process -FilePath "notepad.exe" -ArgumentList "`"$log`"" }
    else { Show-AppMessage -Message ("There's no log yet. It's created the first time you apply changes.") }
})

$logoBytes = $null
$logoPath = if ($ToolRoot) { Join-Path $ToolRoot "Assets\logo.png" } else { $null }
if ($logoPath -and (Test-Path -LiteralPath $logoPath)) {
    try { $logoBytes = [System.IO.File]::ReadAllBytes($logoPath) } catch { }
} elseif ($repoIsConfigured) {
    try { $logoBytes = (Invoke-WebRequest -UseBasicParsing -Uri "$RepoBase/Assets/logo.png" -TimeoutSec 10 -ErrorAction Stop).Content } catch { }
}
if ($logoBytes) {
    try {
        $logo = New-Object System.Windows.Media.Imaging.BitmapImage
        $logo.BeginInit()
        $logo.StreamSource = New-Object System.IO.MemoryStream(, [byte[]]$logoBytes)
        $logo.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $logo.EndInit()
        $sidebarLogo = $window.FindName("SidebarLogo")
        $sidebarLogo.Source = $logo
        $sidebarLogo.Visibility = "Visible"
        $window.FindName("SidebarTitleText").Visibility = "Collapsed"
    } catch { }
}

$window.Add_SourceInitialized({
    $script:WindowHandle = (New-Object System.Windows.Interop.WindowInteropHelper($window)).Handle
    Set-TitleBarTheme
})
$window.Add_Closing({ if ($script:DeepCleanProcess -and -not $script:DeepCleanProcess.HasExited) { Stop-ProcessTree -Process $script:DeepCleanProcess } })
$window.Add_Loaded({ Hide-ConsoleWindow })
$window.ShowDialog() | Out-Null

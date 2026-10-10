function Set-Progress {
    param([int]$Current, [int]$Total, [string]$Message)
    if (-not $SkipToken.Requested -and -not $CancelToken.Requested) { $BtnOverlaySkip.IsEnabled = $true }
    $barTotal = $Total + $script:ProgressExtraTotal
    $ProgressBar.Value = if ($barTotal -le 0) { 0 } else { [math]::Round((($Current + $script:ProgressExtraDone) / $barTotal) * 100) }
    $StatusText.Text = $Message
    if ($OverlayDetail -and $Message -match '^(Uninstalling|Installing|Applying|Deep Clean:|Restoring default:) (.+?)(?: - \d+%)?(?: \(\d+ of \d+\))?$') {
        $OverlayDetail.Text = "$($Matches[1]) $($Matches[2])"
    }

    Update-UI
}

function Invoke-OverlayTask {
    param([string]$Working, [scriptblock]$Work, [string]$Note = "")
    Set-RunInProgress -Running $true
    $OverlayTitle.Text = $Working
    $script:OverlayTaskRunning = $true
    $titleRow = $window.FindName("OverlayTitleRow")
    $titleRow.Margin = $(if ($Note) { "0,0,0,4" } else { "0" })
    $BtnOverlaySkip.Visibility = [System.Windows.Visibility]::Collapsed
    $ProgressBar.Visibility = [System.Windows.Visibility]::Collapsed
    $OverlayDetail.Visibility = [System.Windows.Visibility]::Collapsed
    $savedNote = $OverlayNote.Text
    if ($Note) {
        $OverlayNote.Text = $Note
        $OverlayNote.Visibility = [System.Windows.Visibility]::Visible
    }
    Update-UI
    $result = & $Work
    if ($CancelToken.Requested) {
        $script:OverlayTaskRunning = $false
        $titleRow.Margin = "0,0,0,18"
        $OverlayNote.Text = $savedNote
        Set-RunInProgress -Running $false
        return
    }
    $script:OverlayTaskRunning = $false
    $titleRow.Margin = "0,0,0,18"
    $OverlayNote.Text = $savedNote
    Show-OverlayComplete -Message $result.Message -Title $result.Title
}

function Show-OverlayComplete {

    param([string]$Message, [string]$Title = "Complete!")
    $Spinner.Visibility         = [System.Windows.Visibility]::Collapsed
    $ProgressBar.Visibility     = [System.Windows.Visibility]::Collapsed
    $OverlayDetail.Visibility   = [System.Windows.Visibility]::Collapsed
    $OverlayNote.Visibility     = [System.Windows.Visibility]::Collapsed
    $OverlayTitle.Text          = $(if ($CancelToken.Requested) { "Stopped" } else { $Title })
    $OverlayTitle.FontSize      = 20
    $OverlayRunButtons.Visibility = [System.Windows.Visibility]::Collapsed
    $OverlaySummary.Text        = $Message
    $OverlaySummary.Visibility  = $(if ($Message) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed })
    $BtnOverlayClose.Visibility = [System.Windows.Visibility]::Visible
    Update-UI
}

function Set-RunInProgress {

    param([bool]$Running)
    if (-not $Running) {
        $script:ProgressExtraDone = 0
        $script:ProgressExtraTotal = 0
    }
    $BusyOverlay.Visibility = if ($Running) {
        [System.Windows.Visibility]::Visible
    } else {
        [System.Windows.Visibility]::Collapsed
    }
    if ($Running) {

        $Spinner.Visibility         = [System.Windows.Visibility]::Visible
        $ProgressBar.Visibility     = [System.Windows.Visibility]::Visible
        $OverlayTitle.Text          = "Processing Selected Items"
        $OverlayTitle.FontSize      = 16
        $OverlayDetail.Text         = ""
        $OverlayDetail.Visibility   = [System.Windows.Visibility]::Visible
        $OverlayNote.Visibility     = [System.Windows.Visibility]::Collapsed
        $OverlaySummary.Visibility  = [System.Windows.Visibility]::Collapsed
        $BtnOverlayClose.Visibility = [System.Windows.Visibility]::Collapsed
        $OverlayRunButtons.Visibility = [System.Windows.Visibility]::Visible
        $BtnOverlayCancel.IsEnabled  = $true
        $BtnOverlaySkip.Visibility   = [System.Windows.Visibility]::Visible
        $BtnOverlaySkip.IsEnabled    = $true
        $SkipToken.Requested         = $false
        $ProgressBar.Value          = 0
        $CancelToken.Requested      = $false
    }
    foreach ($b in $ActionButtons) { $b.IsEnabled = -not $Running }
    foreach ($k in $NavButtons.Keys) { $NavButtons[$k].IsEnabled = -not $Running }
    $BtnAppsUninstall.IsEnabled = -not $Running
    $BtnAppsInstall.IsEnabled   = -not $Running
    $BtnDetectApps.IsEnabled    = -not $Running
    $BtnDetectTweaks.IsEnabled  = -not $Running
    $BtnRevertAll.IsEnabled     = -not $Running
    $SearchBox.IsEnabled        = -not $Running
}

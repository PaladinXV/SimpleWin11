$UnpinTweaks = @(
    @{
        Name        = "Clear Start Menu Apps"
        Description = "Removes every pinned tile from the Start menu, including promoted placeholders for apps that were never installed (WhatsApp, LinkedIn and similar). Replaces the pin data file with a genuinely empty one - deleting it alone makes Windows rebuild it with the pins intact. Takes effect after a restart or sign out/in."
        Category    = "Unpin apps"
        Recommended = $true
        SafetyLevel = "Safe"
        RunLast     = $true
        Apply       = {
            $ok = Invoke-RemovalScript -FileName "Clear-StartMenuPins.ps1" -Folder "Setup"
            if (-not $ok) { throw "Could not clear Start menu pins." }
        }
        Revert      = {
            Show-AppMessage -Message "Start menu pins can't be restored automatically - you'd need to pin your apps again by hand."
        }
    }
    @{
        Name        = "Clear Task Bar Apps"
        Description = "Removes every pinned app from the taskbar, including the Copilot and Chat buttons, which use a separate mechanism from ordinary pins. Note: File Explorer's pin is not guaranteed to survive. Takes effect after a restart or sign out/in."
        Category    = "Unpin apps"
        Recommended = $true
        SafetyLevel = "Safe"
        RunLast     = $true
        Apply       = {
            $ok = Invoke-RemovalScript -FileName "Clear-TaskbarPins.ps1" -Folder "Setup"
            if (-not $ok) { throw "Could not clear taskbar pins." }
        }
        Revert      = {
            Show-AppMessage -Message "Taskbar pins can't be restored automatically - you'd need to pin your apps again by hand."
        }
    }
)

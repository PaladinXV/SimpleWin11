$TaskbarTweaks = @(
    @{
        Name        = 'Hide "Task view button"'
        SubCategory = "Taskbar items"
        Category    = "Taskbar"
        Recommended = $false
        Description = "Removes the Task View button from the taskbar."
        SafetyLevel = "Safe"
        Location    = "Located in `"Settings`" -> `"Personalization`" -> `"Taskbar`" -> `"Taskbar items`" `"Task view`""
        Apply       = { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 0 }
        Detect      = { Test-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 0 }
        Revert      = { Remove-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" }
    }
    @{
        Name        = 'Enable "Small Taskbar Icons"'
        SubCategory = "Taskbar behaviors"
        Category    = "Taskbar"
        Recommended = $false
        Description = "Sets small taskbar icons."
        SafetyLevel = "Safe"
        Location    = "Located in `"Settings`" -> `"Personalization`" -> `"Taskbar`" -> `"Taskbar behaviors`" `"Show smaller taskbar buttons`""
        Apply       = { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "IconSizePreference" 0 }
        Detect      = { Test-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "IconSizePreference" 0 }
        Revert      = { Remove-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "IconSizePreference" }
    }
    @{
        Name        = 'Enable "Never combine icons and labels"'
        SubCategory = "Taskbar behaviors"
        Category    = "Taskbar"
        Recommended = $false
        Description = "Shows separate taskbar buttons with both icons and labels instead of combining them into a single button."
        SafetyLevel = "Safe"
        Location    = "Located in `"Settings`" -> `"Personalization`" -> `"Taskbar`" -> `"Taskbar behaviors`" `"Combine taskbar buttons and hide labels`""
        Apply       = { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarGlomLevel" 2 }
        Detect      = { Test-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarGlomLevel" 2 }
        Revert      = { Remove-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarGlomLevel" }
    }
    @{
        Name        = 'Enable "Automatically hide the taskbar"'
        SubCategory = "Taskbar behaviors"
        Category    = "Taskbar"
        Recommended = $false
        Description = "Hides the taskbar."
        SafetyLevel = "Safe"
        Location    = "Located in `"Settings`" -> `"Personalization`" -> `"Taskbar`" -> `"Taskbar behaviors`" `"Automatically hide the taskbar`""
        Apply       = { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3" "Settings" ([byte[]](0x28,0x00,0x00,0x00,0xff,0xff,0xff,0xff,0x03,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)) "Binary" }
        Revert      = { Remove-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3" "Settings" }
        Detect      = {
            $prop = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3" -Name "Settings" -ErrorAction SilentlyContinue
            if (-not $prop) { return $false }
            $bytes = $prop.Settings
            $bytes.Count -ge 9 -and $bytes[8] -eq 0x03
        }
    }
    @{
        Name        = "Taskbar Alignment"
        SubCategory = "Taskbar behaviors"
        Category    = "Taskbar"
        Type        = "Option"
        Description = "Choose where taskbar icons are aligned."
        SafetyLevel = "Safe"
        Location    = "Located in `"Settings`" -> `"Personalization`" -> `"Taskbar`" -> `"Taskbar behaviors`" `"Taskbar alignment`""
        Options     = @(
            @{ Label = "Center (Default)"; Apply = { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAl" 1 } }
            @{ Label = "Left";              Apply = { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAl" 0 } }
        )
        DetectIndex = {
            $prop = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -ErrorAction SilentlyContinue
            if (-not $prop) { return 1 }
            switch ($prop.TaskbarAl) {
                1 { return 1 }; 0 { return 2 }
                default { return 0 }
            }
        }
    }
    @{
        Name        = "Taskbar Search Box"
        SubCategory = "Taskbar items"
        Category    = "Taskbar"
        Type        = "Option"
        Description = "Choose how the search box appears on the taskbar."
        SafetyLevel = "Safe"
        Location    = "Located in `"Settings`" -> `"Personalization`" -> `"Taskbar`" -> `"Taskbar items`" `"Search`""
        Options     = @(
            @{ Label = "Search Box (Default)"; Apply = { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 2 } }
            @{ Label = "Icon Only";             Apply = { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 1 } }
            @{ Label = "Hidden";                Apply = { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 0 } }
        )
        DetectIndex = {
            $prop = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -ErrorAction SilentlyContinue
            if (-not $prop) { return 1 }
            switch ($prop.SearchboxTaskbarMode) {
                2 { return 1 }; 1 { return 2 }; 0 { return 3 }
                default { return 0 }
            }
        }
    }
    @{
        Name        = 'Disable "Widgets"'
        SubCategory = "Taskbar items"
        Category    = "Taskbar"
        Recommended = $true
        Description = "Disables Widgets on the taskbar and sets `"Lock screen weather and more`" to `"None`"."
        SafetyLevel = "Safe"
        Location    = "Located in `"Settings`" -> `"Personalization`" -> `"Taskbar`" -> `"Taskbar items`" `"Widgets`""
        Apply       = { Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests" 0 }
        Detect      = { Test-RegValue "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests" 0 }
        Revert      = { Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests" }
    }
)

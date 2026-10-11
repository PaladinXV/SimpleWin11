## Simple Windows 11 Setup Tool

[![Last Commit](https://img.shields.io/github/last-commit/PaladinXV/Simple-Windows-11-Setup-Debloat-Tool)](https://github.com/PaladinXV/Simple-Windows-11-Setup-Debloat-Tool/commits/main)
[![License](https://img.shields.io/github/license/PaladinXV/Simple-Windows-11-Setup-Debloat-Tool)](LICENSE)


A simple, open-source Windows 11 setup tool created with PowerShell.

## Features

- Quick download and no installation required
- Remove unwanted Windows apps 
- Configure Windows settings
- Install various user apps via Winget or Chocolatey
- Shortcuts to various Windows control panel/tools
- Use a pre-configured preset or create your own

![Simple Windows Setup](Screenshots/main-window.png)

## How to use

Copy the link below and paste it into PowerShell.

```powershell
irm https://raw.githubusercontent.com/PaladinXV/Simple-Windows-11-Setup-Debloat-Tool/main/Launch.ps1 | iex
```

## Notes

- Best to use on a fresh install of Windows 11
- Recommended to create a System Restore point
- Almost all changes can be reverted
- "Deep Clean" mode is an option for users that want to remove apps from the PC entirely, rather than the current user. This means Windows Update won't randomly reinstall an app. The catch is that it will take much longer to uninstall/reinstall apps. 


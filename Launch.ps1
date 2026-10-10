$SwsRepo   = 'PaladinXV/Simple-Windows-11-Setup-Debloat-Tool'
$SwsBranch = 'main'

& {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'
    try {
        if ($SwsRepo -like '*<*') { throw "This launcher hasn't been set up yet: set `$SwsRepo at the top of Launch.ps1 to the GitHub repository." }
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

        $temp = [IO.Path]::GetTempPath()
        $zip  = Join-Path $temp 'SimpleWindowsSetup.zip'
        $dest = Join-Path $temp 'SimpleWindowsSetup'

        Write-Host "Downloading Simple Windows Tool..." -ForegroundColor Cyan
        Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/$SwsRepo/archive/refs/heads/$SwsBranch.zip" -OutFile $zip

        if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
        Expand-Archive -LiteralPath $zip -DestinationPath $dest -Force
        Remove-Item -LiteralPath $zip -Force

        $main = Get-ChildItem -LiteralPath $dest -Recurse -Filter 'Main.ps1' | Select-Object -First 1
        if (-not $main) { throw "Main.ps1 was not found in the download." }
        Get-ChildItem -LiteralPath $dest -Recurse -File | Unblock-File

        Write-Host "Starting..." -ForegroundColor Cyan
        $windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        Start-Process -FilePath $windowsPowerShell -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($main.FullName)`""
    } catch {
        Write-Host ""
        Write-Host "  Simple Windows Tool could not be started" -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host ""
    }
}

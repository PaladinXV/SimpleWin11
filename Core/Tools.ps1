$SpeedTestBase = "https://speed.cloudflare.com"
$SpeedTestSeconds = 10
$SpeedTestStreams = 4
$LatencyTargets = @(
    @{ Key = "Cloudflare"; Host = "1.1.1.1" }
    @{ Key = "Google";     Host = "8.8.8.8" }
    @{ Key = "Quad9";      Host = "9.9.9.9" }
)

$SpeedWorker = {
    param($State, $Index, $Mode, $Base)
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    [Net.ServicePointManager]::DefaultConnectionLimit = 32
    $key = "$Mode$Index"
    $State[$key] = [int64]0
    $buffer = New-Object byte[] 65536
    if ($Mode -eq "u") { (New-Object Random).NextBytes($buffer) }
    while (-not $State.Stop -and [DateTime]::UtcNow -lt $State.Deadline) {
        $req = $null
        try {
            if ($Mode -eq "d") {
                $req = [Net.HttpWebRequest]::Create("$Base/__down?bytes=100000000")
                $req.Timeout = 15000
                $req.ReadWriteTimeout = 15000
                $resp = $req.GetResponse()
                $stream = $resp.GetResponseStream()
                while (-not $State.Stop -and [DateTime]::UtcNow -lt $State.Deadline) {
                    $n = $stream.Read($buffer, 0, $buffer.Length)
                    if ($n -le 0) { break }
                    $State[$key] += $n
                }
            } else {
                $size = 1MB
                $req = [Net.HttpWebRequest]::Create("$Base/__up")
                $req.Method = "POST"
                $req.ContentType = "application/octet-stream"
                $req.ContentLength = $size
                $req.Timeout = 15000
                $req.ReadWriteTimeout = 15000
                $stream = $req.GetRequestStream()
                for ($sent = 0; $sent -lt $size; $sent += $buffer.Length) { $stream.Write($buffer, 0, [Math]::Min($buffer.Length, $size - $sent)) }
                $stream.Close()
                $req.GetResponse().Close()
                if ([DateTime]::UtcNow -lt $State.Deadline) { $State[$key] += $size }
            }
        } catch {
            $State["e$key"] = $_.Exception.Message
            Start-Sleep -Milliseconds 300
        } finally {
            if ($req) { try { $req.Abort() } catch { } }
        }
    }
}

$SpeedPingWorker = {
    param($State, $Base)
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $times = New-Object System.Collections.Generic.List[double]
    for ($i = 0; $i -lt 12; $i++) {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        try {
            $req = [Net.HttpWebRequest]::Create("$Base/__down?bytes=0")
            $req.Timeout = 5000
            $req.GetResponse().Close()
            if ($i -ge 2) { $times.Add($sw.Elapsed.TotalMilliseconds) }
        } catch { }
    }
    if ($times.Count -gt 0) {
        $sorted = @($times | Sort-Object)
        $State.PingMs = $sorted[[int][Math]::Floor($sorted.Count / 2)]
    }
    $State.PingDone = $true
}

$LatencyWorker = {
    param($State, $Targets)
    $pinger = New-Object System.Net.NetworkInformation.Ping
    foreach ($t in $Targets) {
        $times = New-Object System.Collections.Generic.List[double]
        $lost = 0
        for ($i = 0; $i -lt 10; $i++) {
            try {
                $r = $pinger.Send($t.Host, 1000)
                if ($r.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) { $times.Add([double]$r.RoundtripTime) } else { $lost++ }
            } catch { $lost++ }
            Start-Sleep -Milliseconds 100
        }
        $jitter = 0
        if ($times.Count -gt 1) {
            $diffs = for ($j = 1; $j -lt $times.Count; $j++) { [Math]::Abs($times[$j] - $times[$j - 1]) }
            $jitter = ($diffs | Measure-Object -Average).Average
        }
        $State[$t.Key] = [PSCustomObject]@{
            Received = $times.Count
            Average  = $(if ($times.Count) { ($times | Measure-Object -Average).Average } else { $null })
            Min      = $(if ($times.Count) { ($times | Measure-Object -Minimum).Minimum } else { $null })
            Max      = $(if ($times.Count) { ($times | Measure-Object -Maximum).Maximum } else { $null })
            Jitter   = $jitter
            Loss     = $lost * 10
        }
    }
    $State.Finished = $true
}

$script:ToolPool = $null
$script:ToolJobs = New-Object System.Collections.Generic.List[object]

function Start-ToolWorker {
    param([scriptblock]$Script, [object[]]$Arguments)
    if (-not $script:ToolPool) {
        $script:ToolPool = [RunspaceFactory]::CreateRunspacePool(1, 10)
        $script:ToolPool.Open()
    }
    $ps = [PowerShell]::Create()
    $ps.RunspacePool = $script:ToolPool
    $ps.AddScript($Script.ToString()) | Out-Null
    foreach ($a in $Arguments) { $ps.AddArgument($a) | Out-Null }
    $job = [PSCustomObject]@{ PS = $ps; Handle = $ps.BeginInvoke() }
    $script:ToolJobs.Add($job) | Out-Null
    return $job
}

function Stop-FinishedToolWorkers {
    foreach ($job in $script:ToolJobs.ToArray()) {
        if ($job.Handle.IsCompleted) {
            try { $job.PS.EndInvoke($job.Handle) | Out-Null } catch { }
            $job.PS.Dispose()
            $script:ToolJobs.Remove($job) | Out-Null
        }
    }
}

function Format-Mbps {
    param([double]$Mbps)
    if ($Mbps -ge 100) { return "{0:N0}" -f $Mbps }
    return "{0:N1}" -f $Mbps
}

function Get-PhaseBytes {
    param($State, [string]$Mode)
    $total = [int64]0
    for ($i = 0; $i -lt $SpeedTestStreams; $i++) { if ($State.ContainsKey("$Mode$i")) { $total += [int64]$State["$Mode$i"] } }
    return $total
}

function Start-SpeedTest {
    $btn = $window.FindName("BtnSpeedTest")
    $btn.IsEnabled = $false
    foreach ($n in "SpeedPing", "SpeedDown", "SpeedUp") { $window.FindName($n).Text = "-" }
    $statusText = $window.FindName("SpeedStatus")
    $statusText.Text = "Measuring ping..."
    $state = [hashtable]::Synchronized(@{ Stop = $false; Deadline = [DateTime]::UtcNow; PingDone = $false; PingMs = $null })
    $run = @{ State = $state; Phase = "ping"; PhaseStart = [DateTime]::UtcNow; Sample = $null }
    Start-ToolWorker -Script $SpeedPingWorker -Arguments @($state, $SpeedTestBase) | Out-Null

    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(250)
    $timer.Add_Tick({
        $st = $run.State
        $now = [DateTime]::UtcNow
        Stop-FinishedToolWorkers
        switch ($run.Phase) {
            "ping" {
                if ($st.PingDone) {
                    $window.FindName("SpeedPing").Text = $(if ($st.PingMs) { "{0:N0}" -f $st.PingMs } else { "-" })
                    $run.Phase = "d"
                }
            }
            { $_ -in "d", "u" } {
                $mode = $run.Phase
                $target = $window.FindName($(if ($mode -eq "d") { "SpeedDown" } else { "SpeedUp" }))
                if (-not $run.Started) {
                    $statusText.Text = if ($mode -eq "d") { "Testing download speed..." } else { "Testing upload speed..." }
                    $st.Stop = $false
                    $st.Deadline = $now.AddSeconds($SpeedTestSeconds)
                    $run.PhaseStart = $now
                    $run.Sample = $null
                    for ($i = 0; $i -lt $SpeedTestStreams; $i++) { Start-ToolWorker -Script $SpeedWorker -Arguments @($st, $i, $mode, $SpeedTestBase) | Out-Null }
                    $run.Started = $true
                    return
                }
                $bytes = Get-PhaseBytes -State $st -Mode $mode
                $elapsed = ($now - $run.PhaseStart).TotalSeconds
                if (-not $run.Sample -and $elapsed -ge 2) { $run.Sample = @{ Bytes = $bytes; Time = $now } }
                $mbps = if ($run.Sample -and ($now - $run.Sample.Time).TotalSeconds -gt 0.5) {
                    ($bytes - $run.Sample.Bytes) * 8 / ($now - $run.Sample.Time).TotalSeconds / 1e6
                } elseif ($elapsed -gt 0) { $bytes * 8 / $elapsed / 1e6 } else { 0 }
                if ($bytes -gt 0) { $target.Text = Format-Mbps -Mbps $mbps }
                if ($now -ge $st.Deadline) {
                    $st.Stop = $true
                    if ($bytes -eq 0) { $target.Text = "Failed" }
                    $run.Started = $false
                    $run.Phase = if ($mode -eq "d") { "u" } else { "done" }
                }
            }
            "done" {
                $timer.Stop()
                $failed = ($window.FindName("SpeedDown").Text -eq "Failed") -or ($window.FindName("SpeedUp").Text -eq "Failed")
                $statusText.Text = if ($failed) { "Couldn't reach the speed test servers for part of the test. Check your connection, VPN or firewall." } else { "Finished. Results are approximate and vary with network load." }
                $btn.IsEnabled = $true
            }
        }
    }.GetNewClosure())
    $timer.Start()
}

function Start-LatencyTest {
    $btn = $window.FindName("BtnLatencyTest")
    $btn.IsEnabled = $false
    $statusText = $window.FindName("LatencyStatus")
    $statusText.Text = "Pinging servers..."
    foreach ($t in $LatencyTargets) { $window.FindName("Lat$($t.Key)").Text = "Waiting..." }
    $state = [hashtable]::Synchronized(@{ Finished = $false })
    Start-ToolWorker -Script $LatencyWorker -Arguments @($state, $LatencyTargets) | Out-Null
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(250)
    $timer.Add_Tick({
        Stop-FinishedToolWorkers
        foreach ($t in $LatencyTargets) {
            $r = $state[$t.Key]
            if (-not $r) { continue }
            $window.FindName("Lat$($t.Key)").Text = if ($r.Received -eq 0) {
                "No reply (100% loss)"
            } else {
                "{0:N0} ms average   |   {1:N0} - {2:N0} ms   |   {3:N1} ms jitter   |   {4}% loss" -f $r.Average, $r.Min, $r.Max, $r.Jitter, $r.Loss
            }
        }
        if ($state.Finished) {
            $timer.Stop()
            $statusText.Text = "Finished."
            $btn.IsEnabled = $true
        }
    }.GetNewClosure())
    $timer.Start()
}

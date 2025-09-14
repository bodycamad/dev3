# Git Auto-Sync Status Monitor and Control Panel
# Real-time monitoring dashboard with interactive controls

param(
    [ValidateSet("Dashboard", "Start", "Stop", "Restart", "Logs", "Health")]
    [string]$Action = "Dashboard",
    [switch]$Continuous = $false,
    [int]$RefreshInterval = 5,
    [switch]$ShowDetails = $false
)

# Configuration
$Config = @{
    TaskName = "GitAutoSync"
    MonitorTaskName = "GitAutoSync_Monitor"
    LogPath = ".\git-sync.log"
    ScriptPath = ".\auto-sync-enhanced.ps1"
    VBSPath = ".\start-silent-sync.vbs"
    RefreshInterval = $RefreshInterval
    Colors = @{
        Header = "Cyan"
        Success = "Green" 
        Warning = "Yellow"
        Error = "Red"
        Info = "White"
        Accent = "Magenta"
    }
}

# Clear screen and show header
function Write-Header {
    Clear-Host
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor $Config.Colors.Header
    Write-Host "                    Git Auto-Sync Monitor v2.0                     " -ForegroundColor $Config.Colors.Header
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor $Config.Colors.Header
    Write-Host ""
}

# Get current status
function Get-SyncStatus {
    $status = @{
        Timestamp = Get-Date
        TaskExists = $false
        TaskRunning = $false
        ProcessRunning = $false
        ProcessCount = 0
        LastSync = "Unknown"
        LogSize = 0
        HealthStatus = "Unknown"
        RemoteConnected = $false
        ChangesDetected = $false
    }
    
    try {
        # Check scheduled task
        $task = Get-ScheduledTask -TaskName $Config.TaskName -ErrorAction SilentlyContinue
        if ($task) {
            $status.TaskExists = $true
            $status.TaskRunning = ($task.State -eq "Running")
        }
        
        # Check PowerShell processes
        $processes = Get-Process -Name "powershell" -ErrorAction SilentlyContinue | 
            Where-Object { $_.CommandLine -like "*auto-sync*" }
        $status.ProcessCount = if ($processes) { $processes.Count } else { 0 }
        $status.ProcessRunning = $status.ProcessCount -gt 0
        
        # Check log file
        if (Test-Path $Config.LogPath) {
            $logFile = Get-Item $Config.LogPath
            $status.LogSize = [math]::Round($logFile.Length / 1KB, 2)
            
            # Get last sync from log
            $lastEntries = Get-Content $Config.LogPath -Tail 20 -ErrorAction SilentlyContinue
            $lastSync = $lastEntries | Where-Object { $_ -like "*SUCCESS*" -or $_ -like "*completed*" } | 
                Select-Object -Last 1
            if ($lastSync -match '\[(.*?)\]') {
                $status.LastSync = $matches[1]
            }
        }
        
        # Check git status
        try {
            $gitStatus = git status --porcelain 2>$null
            $status.ChangesDetected = ![string]::IsNullOrEmpty($gitStatus)
            
            git ls-remote origin HEAD 2>$null | Out-Null
            $status.RemoteConnected = $LASTEXITCODE -eq 0
        }
        catch {
            $status.RemoteConnected = $false
        }
        
        # Health assessment
        $status.HealthStatus = if ($status.TaskExists -and $status.RemoteConnected) {
            if ($status.ProcessRunning) { "Healthy" } else { "Stopped" }
        } elseif ($status.TaskExists) {
            "Connectivity Issues"
        } else {
            "Not Configured"
        }
        
    }
    catch {
        Write-Warning "Error getting status: $_"
    }
    
    return $status
}

# Display status dashboard
function Write-StatusDashboard {
    param([hashtable]$Status)
    
    $healthColor = switch ($Status.HealthStatus) {
        "Healthy" { $Config.Colors.Success }
        "Stopped" { $Config.Colors.Warning }
        "Connectivity Issues" { $Config.Colors.Warning }
        "Not Configured" { $Config.Colors.Error }
        default { $Config.Colors.Info }
    }
    
    Write-Host "📊 System Status" -ForegroundColor $Config.Colors.Accent
    Write-Host "────────────────" -ForegroundColor $Config.Colors.Accent
    Write-Host "  Overall Health: " -NoNewline -ForegroundColor $Config.Colors.Info
    Write-Host $Status.HealthStatus -ForegroundColor $healthColor
    Write-Host "  Last Updated: " -NoNewline -ForegroundColor $Config.Colors.Info
    Write-Host $Status.Timestamp.ToString("yyyy-MM-dd HH:mm:ss") -ForegroundColor $Config.Colors.Info
    Write-Host ""
    
    Write-Host "🔧 Service Status" -ForegroundColor $Config.Colors.Accent
    Write-Host "─────────────────" -ForegroundColor $Config.Colors.Accent
    Write-Host "  Scheduled Task: " -NoNewline -ForegroundColor $Config.Colors.Info
    $taskStatus = if ($Status.TaskExists) { 
        if ($Status.TaskRunning) { "✅ Active" } else { "⚠️ Configured" }
    } else { "❌ Not Found" }
    Write-Host $taskStatus -ForegroundColor $(if ($Status.TaskExists) { $Config.Colors.Success } else { $Config.Colors.Error })
    
    Write-Host "  Background Process: " -NoNewline -ForegroundColor $Config.Colors.Info
    $processStatus = if ($Status.ProcessRunning) { 
        "✅ Running ($($Status.ProcessCount) processes)" 
    } else { 
        "❌ Stopped" 
    }
    Write-Host $processStatus -ForegroundColor $(if ($Status.ProcessRunning) { $Config.Colors.Success } else { $Config.Colors.Error })
    Write-Host ""
    
    Write-Host "📡 Git Status" -ForegroundColor $Config.Colors.Accent
    Write-Host "──────────────" -ForegroundColor $Config.Colors.Accent
    Write-Host "  Remote Connection: " -NoNewline -ForegroundColor $Config.Colors.Info
    $remoteStatus = if ($Status.RemoteConnected) { "✅ Connected" } else { "❌ Disconnected" }
    Write-Host $remoteStatus -ForegroundColor $(if ($Status.RemoteConnected) { $Config.Colors.Success } else { $Config.Colors.Error })
    
    Write-Host "  Pending Changes: " -NoNewline -ForegroundColor $Config.Colors.Info
    $changesStatus = if ($Status.ChangesDetected) { "⚠️ Yes" } else { "✅ Clean" }
    Write-Host $changesStatus -ForegroundColor $(if ($Status.ChangesDetected) { $Config.Colors.Warning } else { $Config.Colors.Success })
    
    Write-Host "  Last Sync: " -NoNewline -ForegroundColor $Config.Colors.Info
    Write-Host $Status.LastSync -ForegroundColor $Config.Colors.Info
    Write-Host ""
    
    Write-Host "📁 System Info" -ForegroundColor $Config.Colors.Accent
    Write-Host "───────────────" -ForegroundColor $Config.Colors.Accent
    Write-Host "  Working Directory: " -NoNewline -ForegroundColor $Config.Colors.Info
    Write-Host (Get-Location) -ForegroundColor $Config.Colors.Info
    Write-Host "  Log File Size: " -NoNewline -ForegroundColor $Config.Colors.Info
    Write-Host "$($Status.LogSize) KB" -ForegroundColor $Config.Colors.Info
    
    if ($ShowDetails) {
        # Show recent processes
        $processes = Get-Process -Name "powershell" -ErrorAction SilentlyContinue | 
            Where-Object { $_.CommandLine -like "*auto-sync*" }
        
        if ($processes) {
            Write-Host ""
            Write-Host "🔄 Active Processes" -ForegroundColor $Config.Colors.Accent
            Write-Host "───────────────────" -ForegroundColor $Config.Colors.Accent
            foreach ($proc in $processes) {
                Write-Host "  PID: $($proc.Id) | Started: $($proc.StartTime.ToString('HH:mm:ss'))" -ForegroundColor $Config.Colors.Info
            }
        }
    }
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor $Config.Colors.Header
}

# Show available commands
function Write-Commands {
    Write-Host "Available Commands:" -ForegroundColor $Config.Colors.Accent
    Write-Host "  [D] Dashboard (refresh)" -ForegroundColor $Config.Colors.Info
    Write-Host "  [S] Start auto-sync" -ForegroundColor $Config.Colors.Info
    Write-Host "  [T] Stop auto-sync" -ForegroundColor $Config.Colors.Info
    Write-Host "  [R] Restart auto-sync" -ForegroundColor $Config.Colors.Info
    Write-Host "  [L] Show recent logs" -ForegroundColor $Config.Colors.Info
    Write-Host "  [H] Run health check" -ForegroundColor $Config.Colors.Info
    Write-Host "  [C] Toggle continuous mode" -ForegroundColor $Config.Colors.Info
    Write-Host "  [Q] Quit" -ForegroundColor $Config.Colors.Info
    Write-Host ""
}

# Start auto-sync
function Start-AutoSync {
    Write-Information "Starting Git Auto-Sync..." -InformationAction Continue
    
    try {
        # Try VBS script first (silent)
        if (Test-Path $Config.VBSPath) {
            Start-Process -FilePath "wscript.exe" -ArgumentList "`"$Config.VBSPath`"" -WindowStyle Hidden
            Write-Information "✅ Auto-sync started via VBS launcher" -InformationAction Continue
        }
        # Fallback to PowerShell
        elseif (Test-Path $Config.ScriptPath) {
            Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$Config.ScriptPath`" -Watch -Silent" -WindowStyle Hidden
            Write-Information "✅ Auto-sync started via PowerShell" -InformationAction Continue
        }
        else {
            Write-Error "❌ Auto-sync scripts not found"
        }
    }
    catch {
        Write-Error "❌ Failed to start auto-sync: $_"
    }
    
    Start-Sleep -Seconds 2
}

# Stop auto-sync
function Stop-AutoSync {
    Write-Information "Stopping Git Auto-Sync processes..." -InformationAction Continue
    
    try {
        $processes = Get-Process -Name "powershell" -ErrorAction SilentlyContinue | 
            Where-Object { $_.CommandLine -like "*auto-sync*" }
        
        if ($processes) {
            foreach ($proc in $processes) {
                Write-Verbose "  Stopping PID: $($proc.Id)"
                $proc.CloseMainWindow() | Out-Null
                Start-Sleep -Milliseconds 500
                if (!$proc.HasExited) {
                    $proc.Kill()
                }
            }
            Write-Information "✅ Auto-sync processes stopped" -InformationAction Continue
        }
        else {
            Write-Information "ℹ️ No auto-sync processes running" -InformationAction Continue
        }
    }
    catch {
        Write-Error "❌ Error stopping processes: $_"
    }
    
    Start-Sleep -Seconds 1
}

# Restart auto-sync
function Restart-AutoSync {
    Write-Information "Restarting Git Auto-Sync..." -InformationAction Continue
    Stop-AutoSync
    Start-Sleep -Seconds 2
    Start-AutoSync
}

# Show recent logs
function Write-RecentLogs {
    Write-Host "Recent Log Entries:" -ForegroundColor $Config.Colors.Accent
    Write-Host "───────────────────" -ForegroundColor $Config.Colors.Accent
    
    if (Test-Path $Config.LogPath) {
        $logs = Get-Content $Config.LogPath -Tail 15 -ErrorAction SilentlyContinue
        foreach ($log in $logs) {
            $color = $Config.Colors.Info
            if ($log -like "*ERROR*") { $color = $Config.Colors.Error }
            elseif ($log -like "*WARN*") { $color = $Config.Colors.Warning }
            elseif ($log -like "*SUCCESS*") { $color = $Config.Colors.Success }
            
            Write-Host $log -ForegroundColor $color
        }
    }
    else {
        Write-Warning "Log file not found: $($Config.LogPath)"
    }
    
    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor $Config.Colors.Accent
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Run health check
function Invoke-HealthCheck {
    Write-Information "Running Health Check..." -InformationAction Continue
    Write-Host ""
    
    # Check Git availability
    Write-Host "🔧 Checking Git installation..." -NoNewline -ForegroundColor $Config.Colors.Info
    try {
        $gitVersion = git --version 2>&1
        Write-Host " ✅ $gitVersion" -ForegroundColor $Config.Colors.Success
    }
    catch {
        Write-Host " ❌ Git not found" -ForegroundColor $Config.Colors.Error
    }
    
    # Check repository
    Write-Host "📁 Checking repository..." -NoNewline -ForegroundColor $Config.Colors.Info
    try {
        git rev-parse --git-dir 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host " ✅ Valid Git repository" -ForegroundColor $Config.Colors.Success
        }
        else {
            Write-Host " ❌ Not a Git repository" -ForegroundColor $Config.Colors.Error
        }
    }
    catch {
        Write-Host " ❌ Repository check failed" -ForegroundColor $Config.Colors.Error
    }
    
    # Check remote
    Write-Host "🌐 Checking remote connection..." -NoNewline -ForegroundColor $Config.Colors.Info
    try {
        git ls-remote origin HEAD 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host " ✅ Remote accessible" -ForegroundColor $Config.Colors.Success
        }
        else {
            Write-Host " ❌ Remote connection failed" -ForegroundColor $Config.Colors.Error
        }
    }
    catch {
        Write-Host " ❌ Remote check failed" -ForegroundColor $Config.Colors.Error
    }
    
    # Check scripts
    Write-Host "📄 Checking script files..." -NoNewline -ForegroundColor $Config.Colors.Info
    $scriptsOk = $true
    if (!(Test-Path $Config.ScriptPath)) { $scriptsOk = $false }
    if (!(Test-Path $Config.VBSPath)) { $scriptsOk = $false }
    
    if ($scriptsOk) {
        Write-Host " ✅ All scripts present" -ForegroundColor $Config.Colors.Success
    }
    else {
        Write-Host " ⚠️ Some scripts missing" -ForegroundColor $Config.Colors.Warning
    }
    
    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor $Config.Colors.Accent
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Interactive dashboard mode
function Start-InteractiveDashboard {
    $continuousMode = $Continuous
    
    while ($true) {
        Write-Header
        $status = Get-SyncStatus
        Write-StatusDashboard -Status $status
        
        if ($continuousMode) {
            Write-Host "Continuous Mode Active - Refreshing every $($Config.RefreshInterval) seconds" -ForegroundColor $Config.Colors.Accent
            Write-Host "Press 'C' to toggle continuous mode, 'Q' to quit"
            
            # Non-blocking input with timeout
            $timeout = $Config.RefreshInterval * 1000
            $startTime = Get-Date
            
            while (((Get-Date) - $startTime).TotalMilliseconds -lt $timeout) {
                if ([console]::KeyAvailable) {
                    $key = [console]::ReadKey($true)
                    switch ($key.Key) {
                        'C' { $continuousMode = $false; break }
                        'Q' { return }
                    }
                    break
                }
                Start-Sleep -Milliseconds 100
            }
        }
        else {
            Write-Commands
            Write-Host "Enter command: " -NoNewline -ForegroundColor $Config.Colors.Accent
            $input = Read-Host
            
            switch ($input.ToUpper()) {
                'D' { continue }
                'S' { Start-AutoSync }
                'T' { Stop-AutoSync }
                'R' { Restart-AutoSync }
                'L' { Write-RecentLogs }
                'H' { Invoke-HealthCheck }
                'C' { $continuousMode = $true }
                'Q' { return }
                default { 
                    Write-Host "Invalid command. Press any key to continue..." -ForegroundColor $Config.Colors.Warning
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                }
            }
        }
    }
}

# Main execution
switch ($Action.ToLower()) {
    "dashboard" {
        Start-InteractiveDashboard
    }
    
    "start" {
        Write-Header
        Start-AutoSync
    }
    
    "stop" {
        Write-Header  
        Stop-AutoSync
    }
    
    "restart" {
        Write-Header
        Restart-AutoSync
    }
    
    "logs" {
        Write-Header
        Write-RecentLogs
    }
    
    "health" {
        Write-Header
        Invoke-HealthCheck
    }
}

<#
.SYNOPSIS
Git Auto-Sync Monitor and Control Panel

.DESCRIPTION
Interactive monitoring dashboard for Git Auto-Sync with real-time status updates and control capabilities.

Features:
- Real-time status monitoring
- Process management (start/stop/restart)
- Health checks and diagnostics
- Log viewing and analysis
- Continuous monitoring mode

.PARAMETER Action
Action to perform: Dashboard (default), Start, Stop, Restart, Logs, Health

.PARAMETER Continuous
Enable continuous refresh mode in dashboard

.PARAMETER RefreshInterval
Refresh interval in seconds for continuous mode (default: 5)

.PARAMETER ShowDetails
Show detailed information in dashboard

.EXAMPLE
.\git-sync-monitor.ps1
Start interactive monitoring dashboard

.EXAMPLE
.\git-sync-monitor.ps1 -Action Health
Run health check and exit

.EXAMPLE
.\git-sync-monitor.ps1 -Continuous -RefreshInterval 3
Start dashboard with 3-second auto-refresh
#>
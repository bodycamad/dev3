# Enhanced PowerShell script for automatic git sync with comprehensive logging and monitoring
# Version: 2.0 - Production ready with quality focus

param(
    [string]$CommitMessage = "Auto-sync: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    [switch]$Watch = $false,
    [switch]$Silent = $false,
    [int]$WatchInterval = 5,
    [string]$LogPath = ".\git-sync.log",
    [switch]$DisableNotifications = $false
)

# Global configuration
$Global:Config = @{
    MaxRetries = 3
    RetryDelay = 2
    MaxLogSize = 10MB
    LogRotation = $true
    NotificationTimeout = 5
    HealthCheckInterval = 300 # 5 minutes
}

# Initialize logging
function Initialize-Logging {
    $script:LogPath = Resolve-Path $LogPath -ErrorAction SilentlyContinue
    if (-not $script:LogPath) {
        $script:LogPath = Join-Path (Get-Location) "git-sync.log"
    }
    
    # Rotate log if too large
    if ((Test-Path $script:LogPath) -and (Get-Item $script:LogPath).Length -gt $Global:Config.MaxLogSize) {
        $backupPath = $script:LogPath -replace '\.log$', '-backup.log'
        if (Test-Path $backupPath) { Remove-Item $backupPath -Force }
        Rename-Item $script:LogPath $backupPath -Force
    }
    
    Write-LogMessage "INFO" "Git Auto-Sync Enhanced v2.0 started"
    Write-LogMessage "INFO" "Working directory: $(Get-Location)"
    Write-LogMessage "INFO" "Log file: $script:LogPath"
}

# Enhanced logging function
function Write-LogMessage {
    param(
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS", "DEBUG")]
        [string]$Level,
        [string]$Message,
        [switch]$NoConsole
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to log file
    try {
        Add-Content -Path $script:LogPath -Value $logEntry -ErrorAction SilentlyContinue
    }
    catch {
        # Fallback if log file is locked
        Write-Host "Log write failed: $_" -ForegroundColor Yellow
    }
    
    # Console output (unless silent mode or NoConsole)
    if (-not $Silent -and -not $NoConsole) {
        $color = switch ($Level) {
            "ERROR" { "Red" }
            "WARN" { "Yellow" }
            "SUCCESS" { "Green" }
            "INFO" { "Cyan" }
            "DEBUG" { "Gray" }
            default { "White" }
        }
        Write-Host $logEntry -ForegroundColor $color
    }
}

# Show notification (Windows 10/11)
function Show-Notification {
    param(
        [string]$Title,
        [string]$Message,
        [ValidateSet("Info", "Warning", "Error")]
        [string]$Type = "Info"
    )
    
    if ($DisableNotifications -or $Silent) { return }
    
    try {
        # Use Windows Toast notifications
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
        
        $toastXml = [Windows.Data.Xml.Dom.XmlDocument]::new()
        $toastXml.LoadXml(@"
<toast>
    <visual>
        <binding template="ToastGeneric">
            <text>$Title</text>
            <text>$Message</text>
        </binding>
    </visual>
</toast>
"@)
        
        $toast = [Windows.UI.Notifications.ToastNotification]::new($toastXml)
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Git Auto-Sync").Show($toast)
    }
    catch {
        # Fallback to popup
        try {
            $wshell = New-Object -ComObject wscript.shell
            $wshell.Popup($Message, $Global:Config.NotificationTimeout, $Title, 64) | Out-Null
        }
        catch {
            Write-LogMessage "WARN" "Failed to show notification: $_"
        }
    }
}

# Check git repository status
function Test-GitRepository {
    try {
        $gitStatus = git rev-parse --git-dir 2>$null
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

# Get git status with error handling
function Get-GitStatus {
    try {
        $status = git status --porcelain 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Git status failed: $status"
        }
        return $status
    }
    catch {
        Write-LogMessage "ERROR" "Failed to get git status: $_"
        return $null
    }
}

# Enhanced sync function with retry logic
function Sync-GitRepository {
    param([string]$Message)
    
    Write-LogMessage "INFO" "Starting sync operation..."
    
    if (-not (Test-GitRepository)) {
        Write-LogMessage "ERROR" "Not a git repository or git not available"
        Show-Notification "Git Sync Error" "Not in a git repository" "Error"
        return $false
    }
    
    $retryCount = 0
    while ($retryCount -lt $Global:Config.MaxRetries) {
        try {
            # Check for changes
            $status = Get-GitStatus
            if (-not $status) {
                Write-LogMessage "WARN" "Could not determine git status, skipping sync"
                return $false
            }
            
            if ($status.Trim()) {
                Write-LogMessage "INFO" "Changes detected, syncing..."
                
                # Stage all changes
                git add -A 2>&1 | ForEach-Object { Write-LogMessage "DEBUG" $_ -NoConsole }
                if ($LASTEXITCODE -ne 0) { throw "Git add failed" }
                
                # Commit changes
                git commit -m $Message 2>&1 | ForEach-Object { Write-LogMessage "DEBUG" $_ -NoConsole }
                if ($LASTEXITCODE -ne 0) { throw "Git commit failed" }
                
                # Push to remote
                git push 2>&1 | ForEach-Object { Write-LogMessage "DEBUG" $_ -NoConsole }
                if ($LASTEXITCODE -ne 0) { throw "Git push failed" }
                
                Write-LogMessage "SUCCESS" "Sync completed successfully"
                Show-Notification "Git Sync" "Changes synced successfully" "Info"
                return $true
            }
            else {
                Write-LogMessage "INFO" "No changes to sync"
                return $true
            }
        }
        catch {
            $retryCount++
            Write-LogMessage "ERROR" "Sync attempt $retryCount failed: $_"
            
            if ($retryCount -lt $Global:Config.MaxRetries) {
                Write-LogMessage "INFO" "Retrying in $($Global:Config.RetryDelay) seconds..."
                Start-Sleep -Seconds $Global:Config.RetryDelay
            }
            else {
                Write-LogMessage "ERROR" "Sync failed after $($Global:Config.MaxRetries) attempts"
                Show-Notification "Git Sync Failed" "Failed after $($Global:Config.MaxRetries) attempts" "Error"
                return $false
            }
        }
    }
}

# Health check function
function Invoke-HealthCheck {
    try {
        # Check git availability
        git --version 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-LogMessage "ERROR" "Git is not available"
            return $false
        }
        
        # Check repository status
        if (-not (Test-GitRepository)) {
            Write-LogMessage "ERROR" "Invalid git repository"
            return $false
        }
        
        # Check remote connectivity
        git ls-remote origin HEAD 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-LogMessage "WARN" "Remote connectivity issue"
            return $false
        }
        
        Write-LogMessage "INFO" "Health check passed"
        return $true
    }
    catch {
        Write-LogMessage "ERROR" "Health check failed: $_"
        return $false
    }
}

# File system watcher setup
function Initialize-FileWatcher {
    try {
        $watcher = New-Object System.IO.FileSystemWatcher
        $watcher.Path = Get-Location
        $watcher.Filter = "*.*"
        $watcher.IncludeSubdirectories = $true
        $watcher.EnableRaisingEvents = $true
        
        # Exclude git directory and log files
        $excludePatterns = @('.git', '*.log', '*.tmp', '*.temp')
        
        # Define action with debouncing
        $script:lastChange = Get-Date
        $action = {
            $path = $Event.SourceEventArgs.FullPath
            $changeType = $Event.SourceEventArgs.ChangeType
            
            # Skip excluded patterns
            foreach ($pattern in $excludePatterns) {
                if ($path -like "*$pattern*") { return }
            }
            
            # Debounce rapid changes (wait 5 seconds after last change)
            $script:lastChange = Get-Date
            Start-Sleep -Seconds $WatchInterval
            
            if ((Get-Date).Subtract($script:lastChange).TotalSeconds -lt $WatchInterval) {
                return # Another change occurred, let it handle
            }
            
            $relativePath = [System.IO.Path]::GetRelativePath((Get-Location), $path)
            Write-LogMessage "INFO" "Change detected: $changeType - $relativePath"
            
            $message = "Auto-sync: $changeType - $([System.IO.Path]::GetFileName($relativePath))"
            Sync-GitRepository -Message $message
        }
        
        # Register events
        Register-ObjectEvent -InputObject $watcher -EventName "Changed" -Action $action -SourceIdentifier "FileChanged"
        Register-ObjectEvent -InputObject $watcher -EventName "Created" -Action $action -SourceIdentifier "FileCreated"
        Register-ObjectEvent -InputObject $watcher -EventName "Deleted" -Action $action -SourceIdentifier "FileDeleted"
        Register-ObjectEvent -InputObject $watcher -EventName "Renamed" -Action $action -SourceIdentifier "FileRenamed"
        
        return $watcher
    }
    catch {
        Write-LogMessage "ERROR" "Failed to initialize file watcher: $_"
        return $null
    }
}

# Cleanup function
function Stop-AutoSync {
    Write-LogMessage "INFO" "Stopping auto-sync..."
    
    # Remove event handlers
    Get-EventSubscriber | Where-Object { $_.SourceIdentifier -like "File*" } | Unregister-Event
    
    # Clean up file watcher
    if ($script:watcher) {
        $script:watcher.EnableRaisingEvents = $false
        $script:watcher.Dispose()
    }
    
    Write-LogMessage "INFO" "Auto-sync stopped cleanly"
    Show-Notification "Git Auto-Sync" "Stopped" "Info"
}

# Signal handler for graceful shutdown
Register-EngineEvent PowerShell.Exiting -Action {
    Stop-AutoSync
}

# Trap Ctrl+C
[console]::TreatControlCAsInput = $true
trap {
    Stop-AutoSync
    exit
}

# Main execution
try {
    Initialize-Logging
    
    # Initial health check
    if (-not (Invoke-HealthCheck)) {
        Write-LogMessage "ERROR" "Health check failed, exiting"
        exit 1
    }
    
    if ($Watch) {
        Write-LogMessage "INFO" "Starting watch mode (Interval: $WatchInterval seconds)"
        Show-Notification "Git Auto-Sync" "Watch mode started" "Info"
        
        # Initialize file watcher
        $script:watcher = Initialize-FileWatcher
        if (-not $script:watcher) {
            Write-LogMessage "ERROR" "Failed to start file watcher"
            exit 1
        }
        
        # Periodic health checks
        $lastHealthCheck = Get-Date
        
        # Main watch loop
        while ($true) {
            Start-Sleep -Seconds 1
            
            # Periodic health check
            if ((Get-Date).Subtract($lastHealthCheck).TotalSeconds -gt $Global:Config.HealthCheckInterval) {
                if (-not (Invoke-HealthCheck)) {
                    Write-LogMessage "ERROR" "Health check failed during watch mode"
                    Show-Notification "Git Sync Warning" "Health check failed" "Warning"
                }
                $lastHealthCheck = Get-Date
            }
            
            # Check for Ctrl+C in console mode
            if ([console]::KeyAvailable) {
                $key = [console]::ReadKey($true)
                if ($key.Key -eq "C" -and $key.Modifiers -eq "Control") {
                    Write-LogMessage "INFO" "Ctrl+C detected, shutting down..."
                    break
                }
            }
        }
    }
    else {
        # Single sync operation
        Write-LogMessage "INFO" "Performing single sync operation"
        $result = Sync-GitRepository -Message $CommitMessage
        if ($result) {
            exit 0
        } else {
            exit 1
        }
    }
}
catch {
    Write-LogMessage "ERROR" "Unexpected error: $_"
    Show-Notification "Git Sync Error" "Unexpected error occurred" "Error"
    exit 1
}
finally {
    Stop-AutoSync
}

# Usage examples and documentation
<#
.SYNOPSIS
Enhanced Git Auto-Sync script with comprehensive monitoring and error handling.

.DESCRIPTION
This script provides automatic git synchronization with the following features:
- File system monitoring with change detection
- Comprehensive logging and error handling
- Health checks and monitoring
- Windows notifications
- Retry logic for failed operations
- Graceful shutdown handling

.PARAMETER CommitMessage
Custom commit message. Default includes timestamp.

.PARAMETER Watch
Enable continuous file monitoring mode.

.PARAMETER Silent
Suppress console output (logging continues).

.PARAMETER WatchInterval
Seconds to wait after detecting changes before syncing (debouncing).

.PARAMETER LogPath
Path to log file. Default is git-sync.log in current directory.

.PARAMETER DisableNotifications
Disable Windows toast notifications.

.EXAMPLE
.\auto-sync-enhanced.ps1 -Watch
Start watching for file changes and auto-sync.

.EXAMPLE
.\auto-sync-enhanced.ps1 -CommitMessage "Custom commit message"
Perform single sync with custom message.

.EXAMPLE
.\auto-sync-enhanced.ps1 -Watch -Silent -DisableNotifications
Run in silent background mode with no notifications.
#>
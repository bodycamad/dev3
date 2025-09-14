# Windows Task Scheduler Setup for Git Auto-Sync
# This script creates scheduled tasks for automatic git synchronization
# Requires Administrator privileges for system-level tasks

#Requires -RunAsAdministrator

param(
    [ValidateSet("Install", "Uninstall", "Status")]
    [string]$Action = "Install",
    [switch]$AllUsers = $false,
    [string]$TaskName = "GitAutoSync",
    [string]$ScriptPath = $PSScriptRoot
)

# Configuration
$Config = @{
    TaskName = $TaskName
    TaskDescription = "Automatic Git synchronization for development projects"
    ScriptPath = Join-Path $ScriptPath "start-silent-sync.vbs"
    EnhancedScriptPath = Join-Path $ScriptPath "auto-sync-enhanced.ps1"
    LogPath = Join-Path $ScriptPath "scheduler.log"
    Author = "Git Auto-Sync System"
}

# Logging function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        "ERROR" { Write-Error $logEntry }
        "WARN" { Write-Warning $logEntry }
        "SUCCESS" { Write-Information $logEntry -InformationAction Continue }
        default { Write-Information $logEntry -InformationAction Continue }
    }
    
    Add-Content -Path $Config.LogPath -Value $logEntry -ErrorAction SilentlyContinue
}

# Check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Create the scheduled task
function Install-ScheduledTask {
    try {
        Write-Log "Creating scheduled task: $($Config.TaskName)"
        
        # Check if scripts exist
        if (-not (Test-Path $Config.ScriptPath)) {
            throw "VBS script not found: $($Config.ScriptPath)"
        }
        
        if (-not (Test-Path $Config.EnhancedScriptPath)) {
            throw "Enhanced PowerShell script not found: $($Config.EnhancedScriptPath)"
        }
        
        # Remove existing task if it exists
        $existingTask = Get-ScheduledTask -TaskName $Config.TaskName -ErrorAction SilentlyContinue
        if ($existingTask) {
            Write-Log -Message "Removing existing task: $($Config.TaskName)" -Level "WARN"
            Unregister-ScheduledTask -TaskName $Config.TaskName -Confirm:$false
        }
        
        # Create task action (run VBS script)
        $action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$($Config.ScriptPath)`"" -WorkingDirectory $ScriptPath
        
        # Create triggers
        $triggers = @()
        
        # Trigger 1: At system startup (with delay)
        $triggers += New-ScheduledTaskTrigger -AtStartup
        $triggers[0].Delay = "PT2M"  # 2 minute delay after startup
        
        # Trigger 2: At user logon
        $triggers += New-ScheduledTaskTrigger -AtLogOn
        $triggers[1].Delay = "PT30S"  # 30 second delay after logon
        
        # Create task settings
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -DontStopOnIdleEnd -RestartOnFailure -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 5)
        $settings.ExecutionTimeLimit = "PT0S"  # No time limit
        $settings.Priority = 7  # Below normal priority
        $settings.MultipleInstances = "IgnoreNew"  # Don't start if already running
        
        # Create task principal
        if ($AllUsers) {
            $principal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Users" -LogonType ServiceAccount
        }
        else {
            $principal = New-ScheduledTaskPrincipal -UserId (whoami) -LogonType Interactive -RunLevel Highest
        }
        
        # Create and register the task
        $task = New-ScheduledTask -Action $action -Trigger $triggers -Settings $settings -Principal $principal -Description $Config.TaskDescription
        Register-ScheduledTask -TaskName $Config.TaskName -InputObject $task -Force
        
        Write-Log -Message "Successfully created scheduled task: $($Config.TaskName)" -Level "SUCCESS"
        
        # Create additional monitoring task (daily health check)
        $monitorAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$($Config.EnhancedScriptPath)`" -CommitMessage `"Scheduled health check`"" -WorkingDirectory $ScriptPath
        $monitorTrigger = New-ScheduledTaskTrigger -Daily -At "02:00AM"
        $monitorSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Hidden
        $monitorTask = New-ScheduledTask -Action $monitorAction -Trigger $monitorTrigger -Settings $monitorSettings -Principal $principal -Description "Daily Git sync health check"
        
        Register-ScheduledTask -TaskName "$($Config.TaskName)_Monitor" -InputObject $monitorTask -Force
        Write-Log -Message "Created monitoring task: $($Config.TaskName)_Monitor" -Level "SUCCESS"
        
        return $true
    }
    catch {
        Write-Log -Message "Failed to create scheduled task: $_" -Level "ERROR"
        return $false
    }
}

# Remove the scheduled task
function Uninstall-ScheduledTask {
    try {
        Write-Log "Removing scheduled task: $($Config.TaskName)"
        
        # Remove main task
        $task = Get-ScheduledTask -TaskName $Config.TaskName -ErrorAction SilentlyContinue
        if ($task) {
            Unregister-ScheduledTask -TaskName $Config.TaskName -Confirm:$false
            Write-Log -Message "Removed task: $($Config.TaskName)" -Level "SUCCESS"
        }
        else {
            Write-Log -Message "Task not found: $($Config.TaskName)" -Level "WARN"
        }
        
        # Remove monitor task
        $monitorTask = Get-ScheduledTask -TaskName "$($Config.TaskName)_Monitor" -ErrorAction SilentlyContinue
        if ($monitorTask) {
            Unregister-ScheduledTask -TaskName "$($Config.TaskName)_Monitor" -Confirm:$false
            Write-Log -Message "Removed monitoring task: $($Config.TaskName)_Monitor" -Level "SUCCESS"
        }
        
        return $true
    }
    catch {
        Write-Log -Message "Failed to remove scheduled task: $_" -Level "ERROR"
        return $false
    }
}

# Get task status
function Get-TaskStatus {
    try {
        Write-Log "Checking task status..."
        
        # Check main task
        $task = Get-ScheduledTask -TaskName $Config.TaskName -ErrorAction SilentlyContinue
        if ($task) {
            $taskInfo = Get-ScheduledTaskInfo -TaskName $Config.TaskName
            Write-Log "Main task status:"
            Write-Log "  State: $($task.State)"
            Write-Log "  Last Run: $($taskInfo.LastRunTime)"
            Write-Log "  Last Result: $($taskInfo.LastTaskResult)"
            Write-Log "  Next Run: $($taskInfo.NextRunTime)"
        }
        else {
            Write-Log -Message "Main task not found: $($Config.TaskName)" -Level "WARN"
        }
        
        # Check monitor task
        $monitorTask = Get-ScheduledTask -TaskName "$($Config.TaskName)_Monitor" -ErrorAction SilentlyContinue
        if ($monitorTask) {
            $monitorInfo = Get-ScheduledTaskInfo -TaskName "$($Config.TaskName)_Monitor"
            Write-Log "Monitor task status:"
            Write-Log "  State: $($monitorTask.State)"
            Write-Log "  Last Run: $($monitorInfo.LastRunTime)"
            Write-Log "  Last Result: $($monitorInfo.LastTaskResult)"
            Write-Log "  Next Run: $($monitorInfo.NextRunTime)"
        }
        else {
            Write-Log -Message "Monitor task not found: $($Config.TaskName)_Monitor" -Level "WARN"
        }
        
        # Check if auto-sync process is running
        $syncProcesses = Get-Process -Name "powershell" -ErrorAction SilentlyContinue | Where-Object { 
            $_.CommandLine -like "*auto-sync-enhanced.ps1*" 
        }
        
        if ($syncProcesses) {
            Write-Log -Message "Auto-sync processes running: $($syncProcesses.Count)" -Level "SUCCESS"
            foreach ($proc in $syncProcesses) {
                Write-Log "  PID: $($proc.Id), Started: $($proc.StartTime)"
            }
        }
        else {
            Write-Log -Message "No auto-sync processes currently running" -Level "WARN"
        }
        
        return $true
    }
    catch {
        Write-Log -Message "Failed to get task status: $_" -Level "ERROR"
        return $false
    }
}

# Create startup shortcuts
function New-StartupShortcuts {
    try {
        Write-Log "Creating startup shortcuts..."
        
        # Create shortcut in user startup folder
        $startupPath = [Environment]::GetFolderPath("Startup")
        $shortcutPath = Join-Path $startupPath "Git Auto-Sync.lnk"
        
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = "wscript.exe"
        $shortcut.Arguments = "`"$($Config.ScriptPath)`""
        $shortcut.WorkingDirectory = $ScriptPath
        $shortcut.Description = "Git Auto-Sync Background Service"
        $shortcut.WindowStyle = 7  # Minimized
        $shortcut.Save()
        
        Write-Log -Message "Created startup shortcut: $shortcutPath" -Level "SUCCESS"
        
        # Create desktop shortcut for manual control
        $desktopPath = [Environment]::GetFolderPath("Desktop")
        $desktopShortcut = Join-Path $desktopPath "Git Auto-Sync Control.lnk"
        
        $controlShortcut = $shell.CreateShortcut($desktopShortcut)
        $controlShortcut.TargetPath = "powershell.exe"
        $controlShortcut.Arguments = "-ExecutionPolicy Bypass -File `"$PSCommandPath`" -Action Status"
        $controlShortcut.WorkingDirectory = $ScriptPath
        $controlShortcut.Description = "Git Auto-Sync Status and Control"
        $controlShortcut.Save()
        
        Write-Log -Message "Created desktop control shortcut: $desktopShortcut" -Level "SUCCESS"
        
        return $true
    }
    catch {
        Write-Log -Message "Failed to create shortcuts: $_" -Level "ERROR"
        return $false
    }
}

# Main execution
Write-Log "Git Auto-Sync Task Scheduler Setup Started"
Write-Log "Action: $Action, All Users: $AllUsers, Script Path: $ScriptPath"

# Validate administrator privileges for system tasks
if ($AllUsers -and -not (Test-Administrator)) {
    Write-Log -Message "Administrator privileges required for system-wide installation" -Level "ERROR"
    Write-Log "Please run as Administrator or remove -AllUsers flag"
    exit 1
}

# Validate script paths
if (-not (Test-Path $ScriptPath)) {
    Write-Log -Message "Script path not found: $ScriptPath" -Level "ERROR"
    exit 1
}

# Execute requested action
$success = switch ($Action.ToLower()) {
    "install" {
        Write-Log "Installing Git Auto-Sync scheduled tasks..."
        $result = Install-ScheduledTask
        if ($result) {
            New-StartupShortcuts
            Write-Log -Message "Installation completed successfully!" -Level "SUCCESS"
            Write-Log ""
            Write-Log "Git Auto-Sync will now start automatically with Windows."
            Write-Log "You can check status anytime by running:"
            Write-Log "  powershell -File '$PSCommandPath' -Action Status"
            Write-Log ""
            Write-Log "To stop auto-sync: Task Manager > Task Scheduler Library > $($Config.TaskName)"
        }
        $result
    }
    
    "uninstall" {
        Write-Log "Uninstalling Git Auto-Sync scheduled tasks..."
        $result = Uninstall-ScheduledTask
        if ($result) {
            # Clean up shortcuts
            $startupShortcut = Join-Path ([Environment]::GetFolderPath("Startup")) "Git Auto-Sync.lnk"
            $desktopShortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "Git Auto-Sync Control.lnk"
            
            if (Test-Path $startupShortcut) { Remove-Item $startupShortcut -Force }
            if (Test-Path $desktopShortcut) { Remove-Item $desktopShortcut -Force }
            
            Write-Log -Message "Uninstallation completed successfully!" -Level "SUCCESS"
        }
        $result
    }
    
    "status" {
        Get-TaskStatus
    }
    
    default {
        Write-Log -Message "Invalid action: $Action" -Level "ERROR"
        Write-Log "Valid actions: Install, Uninstall, Status"
        $false
    }
}

if (-not $success -and $Action -ne "Status") {
    Write-Log -Message "Operation failed!" -Level "ERROR"
    exit 1
}

Write-Log "Task Scheduler setup completed."

<#
.SYNOPSIS
Setup Windows Task Scheduler for Git Auto-Sync

.DESCRIPTION
This script creates, manages, and monitors Windows scheduled tasks for automatic git synchronization.

Features:
- Creates startup and logon triggers
- Health monitoring with daily checks
- Failure recovery and restart policies
- User and system-wide installation options
- Status monitoring and control

.PARAMETER Action
Action to perform: Install, Uninstall, or Status

.PARAMETER AllUsers
Install task for all users (requires administrator privileges)

.PARAMETER TaskName
Name of the scheduled task (default: GitAutoSync)

.PARAMETER ScriptPath
Path to the script directory (default: current script location)

.EXAMPLE
.\setup-task-scheduler.ps1 -Action Install
Install Git Auto-Sync as a scheduled task

.EXAMPLE
.\setup-task-scheduler.ps1 -Action Install -AllUsers
Install system-wide for all users (requires admin)

.EXAMPLE
.\setup-task-scheduler.ps1 -Action Status
Check status of Git Auto-Sync tasks

.EXAMPLE
.\setup-task-scheduler.ps1 -Action Uninstall
Remove Git Auto-Sync scheduled tasks
#>
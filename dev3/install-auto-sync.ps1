# Master Installation Script for Git Auto-Sync System
# One-click setup for complete automatic synchronization

#Requires -ExecutionPolicy Bypass

param(
    [ValidateSet("Install", "Uninstall", "Repair", "Status")]
    [string]$Action = "Install",
    [switch]$SystemWide = $false,
    [switch]$StartImmediately = $true,
    [switch]$CreateDesktopShortcuts = $true,
    [switch]$Silent = $false,
    [string]$InstallPath = $PSScriptRoot
)

# Configuration
$Config = @{
    ProductName = "Git Auto-Sync System"
    Version = "2.0"
    InstallPath = $InstallPath
    LogPath = Join-Path $InstallPath "install.log"
    RequiredFiles = @(
        "auto-sync-enhanced.ps1"
        "start-silent-sync.vbs"
        "setup-task-scheduler.ps1"
        "git-sync-monitor.ps1"
    )
    OptionalFiles = @(
        "auto-sync.ps1"
        "sync.bat"
        ".gitignore"
        "README.md"
    )
}

# Enhanced logging with colors
function Write-InstallLog {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "HEADER")]
        [string]$Level = "INFO",
        [switch]$NoConsole
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to log file
    Add-Content -Path $Config.LogPath -Value $logEntry -ErrorAction SilentlyContinue
    
    # Console output
    if (-not $Silent -and -not $NoConsole) {
        $color = switch ($Level) {
            "SUCCESS" { "Green" }
            "WARNING" { "Yellow" }
            "ERROR" { "Red" }
            "HEADER" { "Cyan" }
            default { "White" }
        }
        
        if ($Level -eq "HEADER") {
            Write-Host ""
            Write-Host "═══ $Message ═══" -ForegroundColor $color
        } else {
            $prefix = switch ($Level) {
                "SUCCESS" { "✅" }
                "WARNING" { "⚠️" }
                "ERROR" { "❌" }
                default { "ℹ️" }
            }
            Write-Host "$prefix $Message" -ForegroundColor $color
        }
    }
}

# Check prerequisites
function Test-Prerequisites {
    Write-InstallLog "Prerequisites Check" "HEADER"
    
    $allGood = $true
    
    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    Write-InstallLog "PowerShell Version: $psVersion"
    if ($psVersion.Major -lt 5) {
        Write-InstallLog "PowerShell 5.0 or higher required" "ERROR"
        $allGood = $false
    } else {
        Write-InstallLog "PowerShell version OK" "SUCCESS"
    }
    
    # Check Git installation
    try {
        $gitVersion = git --version 2>&1
        Write-InstallLog "Git Version: $gitVersion" "SUCCESS"
    }
    catch {
        Write-InstallLog "Git not found - please install Git first" "ERROR"
        $allGood = $false
    }
    
    # Check if in Git repository
    try {
        git rev-parse --git-dir 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-InstallLog "Valid Git repository detected" "SUCCESS"
        }
        else {
            Write-InstallLog "Not in a Git repository - auto-sync will have limited functionality" "WARNING"
        }
    }
    catch {
        Write-InstallLog "Could not verify Git repository status" "WARNING"
    }
    
    # Check execution policy
    $executionPolicy = Get-ExecutionPolicy
    Write-InstallLog "Execution Policy: $executionPolicy"
    if ($executionPolicy -eq "Restricted") {
        Write-InstallLog "Execution policy is Restricted - some features may not work" "WARNING"
    }
    
    # Check required files
    Write-InstallLog "Checking required files..."
    foreach ($file in $Config.RequiredFiles) {
        $filePath = Join-Path $Config.InstallPath $file
        if (Test-Path $filePath) {
            Write-InstallLog "Found: $file" "SUCCESS"
        }
        else {
            Write-InstallLog "Missing required file: $file" "ERROR"
            $allGood = $false
        }
    }
    
    return $allGood
}

# Install auto-sync system
function Install-AutoSyncSystem {
    Write-InstallLog "Installing $($Config.ProductName) v$($Config.Version)" "HEADER"
    
    try {
        # Step 1: Validate prerequisites
        if (-not (Test-Prerequisites)) {
            Write-InstallLog "Prerequisites check failed - installation aborted" "ERROR"
            return $false
        }
        
        # Step 2: Setup task scheduler
        Write-InstallLog "Setting up Windows Task Scheduler..." "INFO"
        $schedulerScript = Join-Path $Config.InstallPath "setup-task-scheduler.ps1"
        
        if (Test-Path $schedulerScript) {
            $schedulerArgs = @("-Action", "Install", "-ScriptPath", $Config.InstallPath)
            if ($SystemWide) {
                $schedulerArgs += "-AllUsers"
                Write-InstallLog "Installing system-wide (all users)" "INFO"
            }
            
            # Run scheduler setup
            $result = & $schedulerScript @schedulerArgs
            if ($LASTEXITCODE -eq 0) {
                Write-InstallLog "Task Scheduler setup completed" "SUCCESS"
            }
            else {
                Write-InstallLog "Task Scheduler setup failed" "WARNING"
            }
        }
        else {
            Write-InstallLog "Task Scheduler script not found - skipping" "WARNING"
        }
        
        # Step 3: Create desktop shortcuts
        if ($CreateDesktopShortcuts) {
            Write-InstallLog "Creating desktop shortcuts..." "INFO"
            Create-DesktopShortcuts
        }
        
        # Step 4: Create start menu entries
        Write-InstallLog "Creating Start Menu entries..." "INFO"
        Create-StartMenuEntries
        
        # Step 5: Set up auto-start
        Write-InstallLog "Configuring auto-start..." "INFO"
        Setup-AutoStart
        
        # Step 6: Start service if requested
        if ($StartImmediately) {
            Write-InstallLog "Starting Git Auto-Sync service..." "INFO"
            Start-AutoSyncService
        }
        
        Write-InstallLog "Installation completed successfully!" "SUCCESS"
        Write-InstallLog "Git Auto-Sync is now configured and ready to use." "SUCCESS"
        
        if (-not $Silent) {
            Write-Host ""
            Write-Host "Installation Summary:" -ForegroundColor Cyan
            Write-Host "━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
            Write-Host "• Scheduled Task: Configured" -ForegroundColor Green
            Write-Host "• Desktop Shortcuts: Created" -ForegroundColor Green
            Write-Host "• Start Menu: Added" -ForegroundColor Green
            Write-Host "• Auto-Start: Enabled" -ForegroundColor Green
            if ($StartImmediately) {
                Write-Host "• Service Status: Running" -ForegroundColor Green
            }
            Write-Host ""
            Write-Host "Quick Commands:" -ForegroundColor Yellow
            Write-Host "• Monitor: .\git-sync-monitor.ps1" -ForegroundColor White
            Write-Host "• Manual Sync: .\sync.bat" -ForegroundColor White
            Write-Host "• Uninstall: .\install-auto-sync.ps1 -Action Uninstall" -ForegroundColor White
        }
        
        return $true
    }
    catch {
        Write-InstallLog "Installation failed: $_" "ERROR"
        return $false
    }
}

# Uninstall auto-sync system
function Uninstall-AutoSyncSystem {
    Write-InstallLog "Uninstalling $($Config.ProductName)" "HEADER"
    
    try {
        # Stop running processes
        Write-InstallLog "Stopping auto-sync processes..." "INFO"
        Stop-AutoSyncProcesses
        
        # Remove scheduled tasks
        Write-InstallLog "Removing scheduled tasks..." "INFO"
        $schedulerScript = Join-Path $Config.InstallPath "setup-task-scheduler.ps1"
        if (Test-Path $schedulerScript) {
            & $schedulerScript -Action Uninstall
        }
        
        # Remove shortcuts
        Write-InstallLog "Removing shortcuts..." "INFO"
        Remove-Shortcuts
        
        # Remove start menu entries
        Write-InstallLog "Removing Start Menu entries..." "INFO"
        Remove-StartMenuEntries
        
        # Remove auto-start entries
        Write-InstallLog "Removing auto-start configuration..." "INFO"
        Remove-AutoStart
        
        Write-InstallLog "Uninstallation completed" "SUCCESS"
        return $true
    }
    catch {
        Write-InstallLog "Uninstallation failed: $_" "ERROR"
        return $false
    }
}

# Repair installation
function Repair-AutoSyncSystem {
    Write-InstallLog "Repairing $($Config.ProductName)" "HEADER"
    
    # Check what's broken and fix it
    $issues = @()
    
    # Check scheduled task
    $task = Get-ScheduledTask -TaskName "GitAutoSync" -ErrorAction SilentlyContinue
    if (-not $task) {
        $issues += "Scheduled task missing"
    }
    
    # Check shortcuts
    $desktopShortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "Git Auto-Sync Monitor.lnk"
    if (-not (Test-Path $desktopShortcut)) {
        $issues += "Desktop shortcuts missing"
    }
    
    if ($issues.Count -eq 0) {
        Write-InstallLog "No issues found - system appears healthy" "SUCCESS"
        return $true
    }
    
    Write-InstallLog "Found $($issues.Count) issues to repair:" "WARNING"
    foreach ($issue in $issues) {
        Write-InstallLog "  - $issue" "WARNING"
    }
    
    # Re-run installation to fix issues
    return Install-AutoSyncSystem
}

# Get system status
function Get-SystemStatus {
    Write-InstallLog "System Status Check" "HEADER"
    
    # Check scheduled task
    $task = Get-ScheduledTask -TaskName "GitAutoSync" -ErrorAction SilentlyContinue
    if ($task) {
        Write-InstallLog "Scheduled Task: ✅ $($task.State)" "SUCCESS"
    }
    else {
        Write-InstallLog "Scheduled Task: ❌ Not found" "ERROR"
    }
    
    # Check running processes
    $processes = Get-Process -Name "powershell" -ErrorAction SilentlyContinue | 
        Where-Object { $_.CommandLine -like "*auto-sync*" }
    
    if ($processes) {
        Write-InstallLog "Running Processes: ✅ $($processes.Count) active" "SUCCESS"
    }
    else {
        Write-InstallLog "Running Processes: ❌ None active" "WARNING"
    }
    
    # Check shortcuts
    $shortcuts = @(
        Join-Path ([Environment]::GetFolderPath("Desktop")) "Git Auto-Sync Monitor.lnk"
        Join-Path ([Environment]::GetFolderPath("Desktop")) "Git Auto-Sync Control.lnk"
    )
    
    $shortcutCount = ($shortcuts | Where-Object { Test-Path $_ }).Count
    Write-InstallLog "Desktop Shortcuts: $shortcutCount/$($shortcuts.Count) present"
    
    # Show monitor for detailed status
    if (Test-Path (Join-Path $Config.InstallPath "git-sync-monitor.ps1")) {
        Write-InstallLog "Starting detailed status monitor..." "INFO"
        & (Join-Path $Config.InstallPath "git-sync-monitor.ps1") -Action Dashboard
    }
}

# Helper functions
function Create-DesktopShortcuts {
    try {
        $shell = New-Object -ComObject WScript.Shell
        $desktop = [Environment]::GetFolderPath("Desktop")
        
        # Monitor shortcut
        $monitorShortcut = $shell.CreateShortcut((Join-Path $desktop "Git Auto-Sync Monitor.lnk"))
        $monitorShortcut.TargetPath = "powershell.exe"
        $monitorShortcut.Arguments = "-ExecutionPolicy Bypass -File `"$(Join-Path $Config.InstallPath 'git-sync-monitor.ps1')`""
        $monitorShortcut.WorkingDirectory = $Config.InstallPath
        $monitorShortcut.Description = "Git Auto-Sync Status Monitor"
        $monitorShortcut.IconLocation = "shell32.dll,16"
        $monitorShortcut.Save()
        
        # Quick sync shortcut
        $syncShortcut = $shell.CreateShortcut((Join-Path $desktop "Quick Git Sync.lnk"))
        $syncShortcut.TargetPath = Join-Path $Config.InstallPath "sync.bat"
        $syncShortcut.WorkingDirectory = $Config.InstallPath
        $syncShortcut.Description = "Quick Git Sync"
        $syncShortcut.IconLocation = "shell32.dll,13"
        $syncShortcut.Save()
        
        Write-InstallLog "Desktop shortcuts created" "SUCCESS"
    }
    catch {
        Write-InstallLog "Failed to create desktop shortcuts: $_" "ERROR"
    }
}

function Create-StartMenuEntries {
    try {
        $startMenu = Join-Path ([Environment]::GetFolderPath("StartMenu")) "Programs\Git Auto-Sync"
        if (-not (Test-Path $startMenu)) {
            New-Item -Path $startMenu -ItemType Directory -Force | Out-Null
        }
        
        $shell = New-Object -ComObject WScript.Shell
        
        # Monitor shortcut
        $monitorShortcut = $shell.CreateShortcut((Join-Path $startMenu "Git Auto-Sync Monitor.lnk"))
        $monitorShortcut.TargetPath = "powershell.exe"
        $monitorShortcut.Arguments = "-ExecutionPolicy Bypass -File `"$(Join-Path $Config.InstallPath 'git-sync-monitor.ps1')`""
        $monitorShortcut.WorkingDirectory = $Config.InstallPath
        $monitorShortcut.Save()
        
        # Uninstall shortcut
        $uninstallShortcut = $shell.CreateShortcut((Join-Path $startMenu "Uninstall Git Auto-Sync.lnk"))
        $uninstallShortcut.TargetPath = "powershell.exe"
        $uninstallShortcut.Arguments = "-ExecutionPolicy Bypass -File `"$(Join-Path $Config.InstallPath 'install-auto-sync.ps1')`" -Action Uninstall"
        $uninstallShortcut.WorkingDirectory = $Config.InstallPath
        $uninstallShortcut.Save()
        
        Write-InstallLog "Start Menu entries created" "SUCCESS"
    }
    catch {
        Write-InstallLog "Failed to create Start Menu entries: $_" "ERROR"
    }
}

function Setup-AutoStart {
    try {
        # Create startup shortcut
        $startup = [Environment]::GetFolderPath("Startup")
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut((Join-Path $startup "Git Auto-Sync.lnk"))
        $shortcut.TargetPath = "wscript.exe"
        $shortcut.Arguments = "`"$(Join-Path $Config.InstallPath 'start-silent-sync.vbs')`""
        $shortcut.WorkingDirectory = $Config.InstallPath
        $shortcut.WindowStyle = 7  # Minimized
        $shortcut.Save()
        
        Write-InstallLog "Auto-start configured" "SUCCESS"
    }
    catch {
        Write-InstallLog "Failed to setup auto-start: $_" "ERROR"
    }
}

function Start-AutoSyncService {
    try {
        $vbsScript = Join-Path $Config.InstallPath "start-silent-sync.vbs"
        if (Test-Path $vbsScript) {
            Start-Process -FilePath "wscript.exe" -ArgumentList "`"$vbsScript`"" -WindowStyle Hidden
            Write-InstallLog "Auto-sync service started" "SUCCESS"
        }
        else {
            Write-InstallLog "VBS launcher not found" "ERROR"
        }
    }
    catch {
        Write-InstallLog "Failed to start auto-sync service: $_" "ERROR"
    }
}

function Stop-AutoSyncProcesses {
    $processes = Get-Process -Name "powershell" -ErrorAction SilentlyContinue | 
        Where-Object { $_.CommandLine -like "*auto-sync*" }
    
    foreach ($proc in $processes) {
        try {
            $proc.CloseMainWindow() | Out-Null
            Start-Sleep -Milliseconds 500
            if (!$proc.HasExited) {
                $proc.Kill()
            }
            Write-InstallLog "Stopped process PID: $($proc.Id)" "SUCCESS"
        }
        catch {
            Write-InstallLog "Failed to stop process PID: $($proc.Id)" "WARNING"
        }
    }
}

function Remove-Shortcuts {
    $shortcuts = @(
        (Join-Path ([Environment]::GetFolderPath("Desktop")) "Git Auto-Sync Monitor.lnk")
        (Join-Path ([Environment]::GetFolderPath("Desktop")) "Quick Git Sync.lnk")
        (Join-Path ([Environment]::GetFolderPath("Startup")) "Git Auto-Sync.lnk")
    )
    
    foreach ($shortcut in $shortcuts) {
        if (Test-Path $shortcut) {
            Remove-Item $shortcut -Force
            Write-InstallLog "Removed: $(Split-Path $shortcut -Leaf)" "SUCCESS"
        }
    }
}

function Remove-StartMenuEntries {
    $startMenu = Join-Path ([Environment]::GetFolderPath("StartMenu")) "Programs\Git Auto-Sync"
    if (Test-Path $startMenu) {
        Remove-Item $startMenu -Recurse -Force
        Write-InstallLog "Start Menu entries removed" "SUCCESS"
    }
}

function Remove-AutoStart {
    $startupShortcut = Join-Path ([Environment]::GetFolderPath("Startup")) "Git Auto-Sync.lnk"
    if (Test-Path $startupShortcut) {
        Remove-Item $startupShortcut -Force
        Write-InstallLog "Auto-start removed" "SUCCESS"
    }
}

# Show banner
function Show-Banner {
    if (-not $Silent) {
        Clear-Host
        Write-Host ""
        Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║                    Git Auto-Sync Installer v$($Config.Version)                    ║" -ForegroundColor Cyan  
        Write-Host "║              Complete GitHub Synchronization Solution           ║" -ForegroundColor Cyan
        Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""
    }
}

# Main execution
Show-Banner
Write-InstallLog "$($Config.ProductName) v$($Config.Version) - Action: $Action"

$success = switch ($Action.ToLower()) {
    "install" { Install-AutoSyncSystem }
    "uninstall" { Uninstall-AutoSyncSystem }
    "repair" { Repair-AutoSyncSystem }
    "status" { Get-SystemStatus; $true }
    default {
        Write-InstallLog "Invalid action: $Action" "ERROR"
        $false
    }
}

if (-not $success -and $Action -ne "Status") {
    Write-InstallLog "Operation failed!" "ERROR"
    exit 1
}

Write-InstallLog "Operation completed successfully" "SUCCESS"

<#
.SYNOPSIS
Master installer for Git Auto-Sync System

.DESCRIPTION
Complete installation and management system for Git Auto-Sync with the following features:
- One-click installation and configuration
- Scheduled task setup with automatic startup
- Desktop shortcuts and Start Menu integration
- System health monitoring and repair
- Clean uninstallation

.PARAMETER Action
Action to perform: Install (default), Uninstall, Repair, Status

.PARAMETER SystemWide
Install for all users (requires administrator privileges)

.PARAMETER StartImmediately
Start the auto-sync service immediately after installation

.PARAMETER CreateDesktopShortcuts
Create desktop shortcuts for easy access

.PARAMETER Silent
Run in silent mode with minimal output

.PARAMETER InstallPath
Installation directory (default: current script location)

.EXAMPLE
.\install-auto-sync.ps1
Complete installation with default settings

.EXAMPLE
.\install-auto-sync.ps1 -Action Uninstall
Remove Git Auto-Sync system completely

.EXAMPLE
.\install-auto-sync.ps1 -Action Repair
Repair broken installation

.EXAMPLE
.\install-auto-sync.ps1 -SystemWide
Install system-wide for all users
#>
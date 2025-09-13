# PowerShell script for automatic git sync on Windows
# Run this script to automatically commit and push changes

param(
    [string]$CommitMessage = "Auto-sync: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    [switch]$Watch = $false
)

function Sync-GitRepository {
    param([string]$Message)
    
    Write-Host "Starting Git sync..." -ForegroundColor Green
    
    # Check for changes
    $status = git status --porcelain
    
    if ($status) {
        Write-Host "Changes detected. Syncing..." -ForegroundColor Yellow
        
        # Add all changes
        git add -A
        Write-Host "Files staged" -ForegroundColor Cyan
        
        # Commit
        git commit -m $Message
        Write-Host "Changes committed" -ForegroundColor Cyan
        
        # Push to remote
        git push origin master
        Write-Host "Changes pushed to GitHub" -ForegroundColor Green
        
        Write-Host "Sync completed successfully!" -ForegroundColor Green
    }
    else {
        Write-Host "No changes to sync" -ForegroundColor Gray
    }
}

if ($Watch) {
    Write-Host "Watching for changes... Press Ctrl+C to stop" -ForegroundColor Magenta
    
    # Create FileSystemWatcher
    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = Get-Location
    $watcher.Filter = "*.*"
    $watcher.IncludeSubdirectories = $true
    $watcher.EnableRaisingEvents = $true
    
    # Define action on change
    $action = {
        $path = $Event.SourceEventArgs.FullPath
        $changeType = $Event.SourceEventArgs.ChangeType
        
        # Ignore .git directory
        if ($path -notlike "*.git*") {
            Write-Host "Change detected: $changeType - $path" -ForegroundColor Yellow
            Start-Sleep -Seconds 2  # Wait for file operations to complete
            Sync-GitRepository -Message "Auto-sync: $changeType - $(Split-Path $path -Leaf)"
        }
    }
    
    # Register events
    Register-ObjectEvent -InputObject $watcher -EventName "Changed" -Action $action
    Register-ObjectEvent -InputObject $watcher -EventName "Created" -Action $action
    Register-ObjectEvent -InputObject $watcher -EventName "Deleted" -Action $action
    Register-ObjectEvent -InputObject $watcher -EventName "Renamed" -Action $action
    
    # Keep script running
    while ($true) {
        Start-Sleep -Seconds 1
    }
}
else {
    # Single sync
    Sync-GitRepository -Message $CommitMessage
}

# Usage examples:
# .\auto-sync.ps1                    # Single sync with auto-generated message
# .\auto-sync.ps1 -CommitMessage "Custom message"  # Single sync with custom message
# .\auto-sync.ps1 -Watch            # Watch mode for continuous sync
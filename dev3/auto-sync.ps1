# PowerShell script for automatic git sync on Windows
# Run this script to automatically commit and push changes

param(
    [string]$CommitMessage = "Auto-sync: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    [switch]$Watch = $false
)

function Update-GitRepository {
    param([string]$Message)
    
    Write-Information "Starting Git sync..." -InformationAction Continue
    
    # Check for changes
    $status = git status --porcelain
    
    if ($status) {
        Write-Information "Changes detected. Syncing..." -InformationAction Continue
        
        # Add all changes
        git add -A
        Write-Verbose "Files staged"
        
        # Commit
        git commit -m $Message
        Write-Verbose "Changes committed"
        
        # Push to remote
        git push origin master
        Write-Information "Changes pushed to GitHub" -InformationAction Continue
        
        Write-Information "Sync completed successfully!" -InformationAction Continue
    }
    else {
        Write-Verbose "No changes to sync"
    }
}

if ($Watch) {
    Write-Information "Watching for changes... Press Ctrl+C to stop" -InformationAction Continue
    
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
            Write-Information "Change detected: $changeType - $path" -InformationAction Continue
            Start-Sleep -Seconds 2  # Wait for file operations to complete
            Update-GitRepository -Message "Auto-sync: $changeType - $(Split-Path $path -Leaf)"
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
    Update-GitRepository -Message $CommitMessage
}

# Usage examples:
# .\auto-sync.ps1                    # Single sync with auto-generated message
# .\auto-sync.ps1 -CommitMessage "Custom message"  # Single sync with custom message
# .\auto-sync.ps1 -Watch            # Watch mode for continuous sync
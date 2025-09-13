' VBScript to run PowerShell auto-sync in background silently
' This script hides the PowerShell console window for seamless operation

Dim objShell, strPSScript, strWorkingDir

' Get current directory
strWorkingDir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)

' PowerShell command to run auto-sync with watch mode
strPSScript = "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & strWorkingDir & "\auto-sync-enhanced.ps1"" -Watch -Silent"

' Create shell object
Set objShell = CreateObject("WScript.Shell")

' Run PowerShell script hidden (0 = hidden window)
objShell.Run strPSScript, 0, False

' Clean up
Set objShell = Nothing

' Optional: Create a simple notification that sync is running
CreateObject("WScript.Shell").Popup "Git Auto-Sync started in background", 3, "Git Sync Status", 64
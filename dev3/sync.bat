@echo off
REM Quick sync batch file for Windows

echo ========================================
echo Git Auto-Sync Tool
echo ========================================
echo.

REM Check if custom message provided
if "%~1"=="" (
    set COMMIT_MSG=Auto-sync: %date% %time%
) else (
    set COMMIT_MSG=%*
)

echo Checking for changes...
git status --short

echo.
echo Adding all changes...
git add -A

echo.
echo Committing with message: %COMMIT_MSG%
git commit -m "%COMMIT_MSG%"

echo.
echo Pushing to GitHub...
git push origin master

echo.
echo ========================================
echo Sync completed!
echo ========================================
pause
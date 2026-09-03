@echo off
setlocal

set "REPO_DIR=%~dp0"
set "LAUNCHER_PATH=%REPO_DIR%CursorSchemeStartup-Launcher.vbs"
set "WORKER_PATH=%REPO_DIR%CursorSchemeStartup-Worker.ps1"
set "APPLY_PATH=%REPO_DIR%Apply-CurrentCursorScheme.ps1"
set "SHORTCUT_PATH=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\CursorSchemeStartup.lnk"

if exist "%LAUNCHER_PATH%" if exist "%WORKER_PATH%" if exist "%APPLY_PATH%" goto create_shortcut

echo One or more required files are missing:
echo   %LAUNCHER_PATH%
echo   %WORKER_PATH%
echo   %APPLY_PATH%
echo Keep this script in the same folder as the other files.
pause
exit /b 1

:create_shortcut
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$shell = New-Object -ComObject WScript.Shell; $shortcut = $shell.CreateShortcut($env:SHORTCUT_PATH); $shortcut.TargetPath = Join-Path $env:WINDIR 'System32\wscript.exe'; $quote = [string][char]34; $shortcut.Arguments = $quote + $env:LAUNCHER_PATH + $quote; $shortcut.WorkingDirectory = $env:REPO_DIR; $shortcut.IconLocation = (Join-Path $env:WINDIR 'System32\main.cpl') + ',0'; $shortcut.Save()"
if errorlevel 1 goto register_failed
if not exist "%SHORTCUT_PATH%" goto register_failed

echo Registered the silent cursor fix for the current user.
echo Shortcut: %SHORTCUT_PATH%
echo The fix runs hidden at every logon: first apply after about 3 seconds, then again
echo after about 25 seconds, and then the process keeps re-applying the scheme every
echo 10 seconds, so mid-session cursor resets are repaired automatically.
echo Log file: %TEMP%\CursorSchemeStartup.log
echo To remove it, run Unregister-CursorSchemeStartup.cmd
pause
exit /b 0

:register_failed
echo Failed to create the startup shortcut.
pause
exit /b 1

@echo off
setlocal

set "SHORTCUT_PATH=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\CursorSchemeStartup.lnk"

if exist "%SHORTCUT_PATH%" goto delete_shortcut
echo No startup shortcut found: %SHORTCUT_PATH%
pause
exit /b 0

:delete_shortcut
del "%SHORTCUT_PATH%"
if not exist "%SHORTCUT_PATH%" goto removed
echo Failed to delete: %SHORTCUT_PATH%
pause
exit /b 1

:removed
echo Removed the startup shortcut: %SHORTCUT_PATH%
pause
exit /b 0

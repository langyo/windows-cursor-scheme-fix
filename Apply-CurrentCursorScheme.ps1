$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not ('CursorSchemeNative' -as [type])) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class CursorSchemeNative
{
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern IntPtr LoadCursorFromFile(string fileName);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetSystemCursor(IntPtr cursor, uint cursorId);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool DestroyCursor(IntPtr cursor);
}
'@
}

$cursorSettings = Get-ItemProperty -LiteralPath 'Registry::HKEY_CURRENT_USER\Control Panel\Cursors'
$cursorMappings = @(
    [pscustomobject]@{ Role = 'Arrow'; CursorId = [uint32]32512 }
    [pscustomobject]@{ Role = 'Hand'; CursorId = [uint32]32649 }
)

foreach ($mapping in $cursorMappings) {
    $configuredPath = $cursorSettings.($mapping.Role)
    if ([string]::IsNullOrWhiteSpace($configuredPath)) {
        throw "The $($mapping.Role) cursor path is empty."
    }

    $cursorPath = [Environment]::ExpandEnvironmentVariables($configuredPath)
    if (-not (Test-Path -LiteralPath $cursorPath -PathType Leaf)) {
        throw "The $($mapping.Role) cursor file does not exist: $cursorPath"
    }

    $cursorHandle = [CursorSchemeNative]::LoadCursorFromFile($cursorPath)
    if ($cursorHandle -eq [IntPtr]::Zero) {
        $errorCode = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        throw "LoadCursorFromFile failed for $cursorPath. Win32 error: $errorCode"
    }

    if (-not [CursorSchemeNative]::SetSystemCursor($cursorHandle, $mapping.CursorId)) {
        $errorCode = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        [void][CursorSchemeNative]::DestroyCursor($cursorHandle)
        throw "SetSystemCursor failed for $($mapping.Role). Win32 error: $errorCode"
    }

    Write-Host "Applied $($mapping.Role): $cursorPath"
}

Write-Host 'The current Arrow and Hand cursors are active.'

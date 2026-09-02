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

# Registry value name -> OCR_* id accepted by SetSystemCursor.
# NWPen/Person/Pin have no OCR_* slot, so SetSystemCursor cannot restore them.
$cursorMappings = @(
    [pscustomobject]@{ Role = 'Arrow';       CursorId = [uint32]32512 }  # OCR_NORMAL
    [pscustomobject]@{ Role = 'Help';        CursorId = [uint32]32651 }  # OCR_HELP
    [pscustomobject]@{ Role = 'AppStarting'; CursorId = [uint32]32650 }  # OCR_APPSTARTING
    [pscustomobject]@{ Role = 'Wait';        CursorId = [uint32]32514 }  # OCR_WAIT
    [pscustomobject]@{ Role = 'Crosshair';   CursorId = [uint32]32515 }  # OCR_CROSS
    [pscustomobject]@{ Role = 'IBeam';       CursorId = [uint32]32513 }  # OCR_IBEAM
    [pscustomobject]@{ Role = 'No';          CursorId = [uint32]32648 }  # OCR_NO
    [pscustomobject]@{ Role = 'SizeNS';      CursorId = [uint32]32645 }  # OCR_SIZENS
    [pscustomobject]@{ Role = 'SizeWE';      CursorId = [uint32]32644 }  # OCR_SIZEWE
    [pscustomobject]@{ Role = 'SizeNWSE';    CursorId = [uint32]32642 }  # OCR_SIZENWSE
    [pscustomobject]@{ Role = 'SizeNESW';    CursorId = [uint32]32643 }  # OCR_SIZENESW
    [pscustomobject]@{ Role = 'SizeAll';     CursorId = [uint32]32646 }  # OCR_SIZEALL
    [pscustomobject]@{ Role = 'UpArrow';     CursorId = [uint32]32516 }  # OCR_UP
    [pscustomobject]@{ Role = 'Hand';        CursorId = [uint32]32649 }  # OCR_HAND
)

$appliedCount = 0
$failures = New-Object System.Collections.Generic.List[string]

foreach ($mapping in $cursorMappings) {
    $configuredPath = $null
    if ($cursorSettings.PSObject.Properties.Name -contains $mapping.Role) {
        $configuredPath = $cursorSettings.($mapping.Role)
    }

    # A role the current scheme leaves empty is skipped instead of treated as an error.
    if ([string]::IsNullOrWhiteSpace($configuredPath)) {
        Write-Verbose "Skipping $($mapping.Role): the current scheme does not configure this role."
        continue
    }

    $cursorPath = [Environment]::ExpandEnvironmentVariables($configuredPath)
    if (-not (Test-Path -LiteralPath $cursorPath -PathType Leaf)) {
        $failures.Add("The $($mapping.Role) cursor file does not exist: $cursorPath")
        continue
    }

    $cursorHandle = [CursorSchemeNative]::LoadCursorFromFile($cursorPath)
    if ($cursorHandle -eq [IntPtr]::Zero) {
        $errorCode = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        $failures.Add("LoadCursorFromFile failed for $($mapping.Role) ($cursorPath). Win32 error: $errorCode")
        continue
    }

    if (-not [CursorSchemeNative]::SetSystemCursor($cursorHandle, $mapping.CursorId)) {
        $errorCode = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        [void][CursorSchemeNative]::DestroyCursor($cursorHandle)
        $failures.Add("SetSystemCursor failed for $($mapping.Role). Win32 error: $errorCode")
        continue
    }

    Write-Host "Applied $($mapping.Role): $cursorPath"
    $appliedCount++
}

if ($appliedCount -eq 0) {
    throw "No cursor role could be applied. $($failures.Count) role(s) failed: $($failures -join ' | ')"
}

if ($failures.Count -gt 0) {
    throw "Applied $appliedCount cursor role(s), but $($failures.Count) role(s) failed: $($failures -join ' | ')"
}

Write-Host "The current cursor scheme is active ($appliedCount role(s) applied)."

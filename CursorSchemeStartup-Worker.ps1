param(
    [int]$InitialDelaySeconds = 3,
    [int]$ReapplyDelaySeconds = 25,
    [int]$WatchIntervalSeconds = 10,
    [string]$LogFilePath = (Join-Path $env:TEMP 'CursorSchemeStartup.log')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$applyScriptPath = Join-Path $PSScriptRoot 'Apply-CurrentCursorScheme.ps1'
if (-not (Test-Path -LiteralPath $applyScriptPath -PathType Leaf)) {
    throw "The apply script does not exist: $applyScriptPath"
}

function Write-Log {
    param(
        [string]$Message,
        [switch]$Overwrite
    )

    try {
        $line = "[$([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))] $Message"
        if ($Overwrite) {
            Set-Content -LiteralPath $LogFilePath -Value $line
        }
        else {
            Add-Content -LiteralPath $LogFilePath -Value $line
        }
    }
    catch {
        # Logging must never stop the cursor fix itself.
    }
}

# A crashed instance that left the mutex abandoned is allowed to be replaced.
$mutex = New-Object System.Threading.Mutex($false, 'Local\CursorSchemeFixWatcher')
$ownsMutex = $false
try {
    $ownsMutex = $mutex.WaitOne([TimeSpan]::Zero)
}
catch [System.Threading.AbandonedMutexException] {
    $ownsMutex = $true
}

if (-not $ownsMutex) {
    Write-Log 'Another watcher instance is already running; this instance exits.'
    return
}

Write-Log "Worker started. Initial delay: ${InitialDelaySeconds}s. Reapply delay: ${ReapplyDelaySeconds}s. Watch interval: ${WatchIntervalSeconds}s." -Overwrite

Start-Sleep -Seconds $InitialDelaySeconds

$attemptTotal = 2
for ($attemptNumber = 1; $attemptNumber -le $attemptTotal; $attemptNumber++) {
    try {
        & $applyScriptPath
        Write-Log "Attempt ${attemptNumber} of ${attemptTotal}: the current cursor scheme is active."
    }
    catch {
        Write-Log "Attempt ${attemptNumber} of ${attemptTotal}: failed. $($_.Exception.Message)"
    }

    if ($attemptNumber -lt $attemptTotal) {
        Start-Sleep -Seconds $ReapplyDelaySeconds
    }
}

Write-Log 'Watch mode started. The registry is re-read on every cycle, so scheme changes made in main.cpl are picked up automatically.'

$watchCycle = 0
$lastFailure = $null
$cyclesPerHeartbeat = [Math]::Max(1, [int](1800 / $WatchIntervalSeconds))

while ($true) {
    Start-Sleep -Seconds $WatchIntervalSeconds
    $watchCycle++

    $failure = $null
    try {
        & $applyScriptPath *> $null
    }
    catch {
        $failure = $_.Exception.Message
    }

    # Log on state changes only; otherwise a persistent failure would spam the log every cycle.
    if ($failure -ne $lastFailure) {
        if ($null -eq $failure) {
            Write-Log "Watch mode: scheme re-applied (cycle ${watchCycle})."
        }
        else {
            Write-Log "Watch mode: re-apply failed (cycle ${watchCycle}). $failure"
        }
        $lastFailure = $failure
    }

    if (($watchCycle % $cyclesPerHeartbeat) -eq 0) {
        Write-Log "Watch mode heartbeat: ${watchCycle} cycles completed."
    }
}

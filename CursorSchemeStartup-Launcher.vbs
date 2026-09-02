Option Explicit

Dim fileSystem, shell, scriptFolder, workerPath, command, quote

Set fileSystem = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

scriptFolder = fileSystem.GetParentFolderName(WScript.ScriptFullName)
workerPath = fileSystem.BuildPath(scriptFolder, "CursorSchemeStartup-Worker.ps1")

If Not fileSystem.FileExists(workerPath) Then
    MsgBox "CursorSchemeStartup-Worker.ps1 was not found:" & vbCrLf & workerPath, vbCritical, "Cursor Scheme Startup"
    WScript.Quit 1
End If

quote = Chr(34)
command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File " & quote & workerPath & quote
shell.Run command, 0, False

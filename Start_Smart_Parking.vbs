Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")
projectDir = fso.GetParentFolderName(WScript.ScriptFullName)
launcherPath = fso.BuildPath(fso.BuildPath(projectDir, "SmartParking_Launcher"), "launcher.pyw")
localApp = shell.ExpandEnvironmentStrings("%LOCALAPPDATA%")
pythonw = fso.BuildPath(fso.BuildPath(fso.BuildPath(localApp, "Programs"), "Python"), "Python312")
pythonw = fso.BuildPath(pythonw, "pythonw.exe")

If fso.FileExists(pythonw) Then
    shell.Run Chr(34) & pythonw & Chr(34) & " " & Chr(34) & launcherPath & Chr(34), 0, False
Else
    shell.Run "pyw -3 " & Chr(34) & launcherPath & Chr(34), 0, False
End If

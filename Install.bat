@echo off
setlocal enabledelayedexpansion

md "%ALLUSERSPROFILE%\GamingGaiden"

set "InstallDirectory=%ALLUSERSPROFILE%\GamingGaiden"
set "DesktopPath=%USERPROFILE%\Desktop"
set "StartupPath=%APPDATA%\Microsoft\Windows\Start Menu\Programs\StartUp"
set "StartMenuPath=%APPDATA%\Microsoft\Windows\Start Menu\Programs"
set "IconPath=%InstallDirectory%\icons\running.ico"

REM Install to C:\ProgramData\GamingGaiden
echo Copying Files
xcopy /s/e/q/y "%CD%" "%InstallDirectory%"

REM Create shortcut using powershell and copy to desktop and start menu
echo.
echo Creating Shortcuts
powershell.exe -NoProfile -Command "$WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%InstallDirectory%\Gaming Gaiden.lnk'); $Shortcut.TargetPath = 'powershell.exe'; $Shortcut.Arguments = '-NoLogo -ExecutionPolicy bypass -File \"%InstallDirectory%\GamingGaiden.ps1\"'; $Shortcut.IconLocation = '%IconPath%'; $Shortcut.WorkingDirectory = '%InstallDirectory%'; $Shortcut.WindowStyle = 7; $Shortcut.Save()"
copy "%InstallDirectory%\Gaming Gaiden.lnk" "%DesktopPath%"
copy "%InstallDirectory%\Gaming Gaiden.lnk" "%StartMenuPath%"

REM Unblock all gaming gaiden files as they are downloaded from internet and blocked by default
echo.
echo Unblocking all Gaming Gaiden files
powershell.exe -NoProfile -Command "Get-ChildItem '%InstallDirectory%' -Recurse | Unblock-File"

REM Copy shortcut to startup directory if user chooses to
echo.
set /p AutoStartChoice="Would you like Gaming Gaiden to auto start at boot? Yes/No: "
if /i "%AutoStartChoice%"=="Yes" (
    copy "%InstallDirectory%\Gaming Gaiden.lnk" "%startupPath%"
    echo Auto start successfully setup.
) else if /i "%AutoStartChoice%"=="Y" (
    copy "%InstallDirectory%\Gaming Gaiden.lnk" "%startupPath%"
    echo Auto start successfully setup.
) else (
    echo Auto start setup cancelled by user.
)

echo.
echo Installation successful at %InstallDirectory%. 
echo Your game records and automatic db backups will also be stored in %InstallDirectory%.
echo Make sure you take backup to another drive / external storage if you ever reinstall Windows.
echo You can delete the downloaded files if you wish. Press any key to Exit.
pause >nul
exit /b 0
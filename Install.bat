@echo off
setlocal enabledelayedexpansion

REM Exit if installing to C:\ drive
set "DRIVE=%CD:~0,2%"
if /i "%DRIVE%"=="C:" (
    echo Gaming Gaiden doesn't support installing to C:\ drive due to permission issues on many windows pcs.
    echo Please install to a different drive on your machine e.g. D:\ or E:\ etc. 
    echo Press any key to exit...
    pause >nul
    exit /b 0
)

set "InstallDirectory=%CD%"
set "DesktopPath=%USERPROFILE%\Desktop"
set "StartupPath=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "IconPath=%InstallDirectory%\icons\running.ico"

echo Creating Shortcuts

REM Create shortcut using powershell
powershell.exe -NoProfile -Command "$WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%InstallDirectory%\Gaming Gaiden.lnk'); $Shortcut.TargetPath = 'powershell.exe'; $Shortcut.Arguments = '-NoLogo -ExecutionPolicy bypass -File \"%InstallDirectory%\GamingGaiden.ps1\"'; $Shortcut.IconLocation = '%IconPath%'; $Shortcut.WorkingDirectory = '%InstallDirectory%'; $Shortcut.WindowStyle = 7; $Shortcut.Save()"

REM Copy shortcut to desktop directory as well
copy "%InstallDirectory%\Gaming Gaiden.lnk" "%DesktopPath%"

REM Unblock all gaming gaiden files as they are downloaded from internet and blocked by default
echo Unblocking all Gaming Gaiden files
powershell.exe -NoProfile -Command "Get-ChildItem '%InstallDirectory%' -Recurse | Unblock-File"

set /p AutoStartChoice="Would you like Gaming Gaiden to auto start at boot? Yes/No: "

REM Copy shortcut to startup directory if user answers y/yes
if /i "%AutoStartChoice%"=="Yes" (
    copy "%InstallDirectory%\Gaming Gaiden.lnk" "%startupPath%"
    echo Auto start successfully setup.
) else if /i "%AutoStartChoice%"=="Y" (
    copy "%InstallDirectory%\Gaming Gaiden.lnk" "%startupPath%"
    echo Auto start successfully setup.
) else (
    echo Auto start setup cancelled by user.
)

echo Installation successful. Press any key to exit...
pause >nul
exit /b 0
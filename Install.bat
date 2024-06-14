@echo off
setlocal enabledelayedexpansion

REM Check if the script is on C:
if "%CD:~0,2%"=="C:" (
    echo GamingGaiden cannot be installed on the C: drive. Press any key to exit...
	pause >nul
    exit /b 1
)


set "InstallDirectory=%CD%"
set "DesktopPath=%USERPROFILE%\Desktop"
set "StartupPath=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "IconPath=%InstallDirectory%\icons\running.ico"

echo Creating Shortcuts

REM Create desktop shortcut using powershell
powershell.exe -NoProfile -Command "$WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%DesktopPath%\Gaming Gaiden.lnk'); $Shortcut.TargetPath = 'powershell.exe'; $Shortcut.Arguments = '-NoLogo -ExecutionPolicy bypass -File \"%InstallDirectory%\GamingGaiden.ps1\"'; $Shortcut.IconLocation = '%IconPath%'; $Shortcut.WorkingDirectory = '%InstallDirectory%'; $Shortcut.WindowStyle = 7; $Shortcut.Save()"

REM Copy shortcut to install directory as well
copy "%DesktopPath%\Gaming Gaiden.lnk" "%InstallDirectory%"

REM Unblock all gaming gaiden files as they are downloaded from internet and blocked by default
echo Unblocking all Gaming Gaiden files
powershell.exe -NoProfile -Command "Get-ChildItem '%InstallDirectory%' -Recurse | Unblock-File"

set /p AutoStartChoice="Would you like Gaming Gaiden to auto start at boot? Yes/No: "

REM Copy shortcut to startup directory if user answers y/yes
if /i "%AutoStartChoice%"=="Yes" (
    copy "%DesktopPath%\Gaming Gaiden.lnk" "%startupPath%"
    echo Auto start successfully setup.
) else if /i "%AutoStartChoice%"=="Y" (
    copy "%DesktopPath%\Gaming Gaiden.lnk" "%startupPath%"
    echo Auto start successfully setup.
) else (
    echo Auto start setup cancelled by user.
)

echo Installation successful. Press any key to exit...
pause >nul
exit /b 0
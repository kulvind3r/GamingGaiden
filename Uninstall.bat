@echo off
setlocal enabledelayedexpansion

set "InstallDirectory=%ALLUSERSPROFILE%\GamingGaiden"
set "DesktopPath=%USERPROFILE%\Desktop"
set "StartupPath=%APPDATA%\Microsoft\Windows\Start Menu\Programs\StartUp"
set "StartMenuPath=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Gaming Gaiden"

echo Gaming Gaiden Uninstaller
echo.
echo This will remove Gaming Gaiden but preserve your data.
echo Your database and backups will remain at %InstallDirectory%
echo.
set /p UninstallChoice="Do you want to uninstall Gaming Gaiden? Yes/No: "

if /i not "%UninstallChoice%"=="Yes" if /i not "%UninstallChoice%"=="Y" (
    echo Uninstall cancelled by user.
    echo.
    pause
    exit /b 0
)

echo.
echo Closing Gaming Gaiden if running
taskkill /f /im GamingGaiden.exe 2>nul

echo Removing shortcuts
del "%DesktopPath%\Gaming Gaiden.lnk" 2>nul
del "%StartupPath%\Gaming Gaiden.lnk" 2>nul
rd /s /q "%StartMenuPath%" 2>nul

echo Removing application files
powershell.exe -NoProfile -Command "$items = Get-ChildItem '%InstallDirectory%' -Exclude backups,GamingGaiden.db,Uninstall.bat -ErrorAction SilentlyContinue; $hasExpected = $items | Where-Object { $_.Name -match '^(modules|icons|ui|GamingGaiden\.exe)$' }; if ($items.Count -gt 0 -and -not $hasExpected) { Write-Host 'ERROR: Install directory does not look like Gaming Gaiden. Aborting.'; exit 1 }; $items | Remove-Item -Recurse -Force"
if errorlevel 1 (
    echo.
    echo Uninstall aborted for safety. Directory does not appear to be Gaming Gaiden.
    pause
    exit /b 1
)

echo.
echo Uninstall complete.
echo.
echo Your data has been preserved at %InstallDirectory%
echo - GamingGaiden.db (your game tracking database)
echo - backups\ (your backup files)
echo.
echo To completely remove all data, manually delete %InstallDirectory%
echo.
pause
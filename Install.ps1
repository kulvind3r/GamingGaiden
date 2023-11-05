#Requires -Version 5.1

Write-Host "Read the Following Notice Carefully" -ForegroundColor Green

Start-Sleep -s 2

Write-Host @"
This script will setup Gaming Gaiden to run from current location on your PC
Following actions will be taken

1. Execution policy will be set to "RemoteSigned". This allows to run Powershell scripts after they are unblocked.

Read more here. https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-5.1#remotesigned

2. All scripts included with GamingGaiden will be unblocked so they can be run.

3. PSSQLite and ThreadJob modules will be installed from microsoft powershell gallery.

4. A shortcut will be placed on your desktop and in current directory to run Gaming Gaiden.

5. Optionally you can choose to add a scheduled task to run Gaming Gaiden automatically on startup.
"@

Write-Host "Do you wish to proceed with installation? Yes/No" -ForegroundColor Green

$UserChoice = Read-Host

function CreateShortcut() {
    $GamingGaidenScript = (Get-Item ".\GamingGaiden.ps1")
    $GamingGaidenPath = $GamingGaidenScript.FullName
    $WorkingDirectory = $GamingGaidenScript.Directory.FullName

    $IconPath = (Get-Item ".\icons\running.ico").FullName
    $DesktopPath = [Environment]::GetFolderPath("Desktop")

    $shortcut = (New-Object -ComObject Wscript.Shell).CreateShortcut("$DesktopPath\Gaming Gaiden.lnk")
    $shortcut.TargetPath = 'powershell'
    $shortcut.Arguments = "-NoLogo -File `"$GamingGaidenPath`""
    $shortcut.IconLocation = $IconPath
    $shortcut.WorkingDirectory = "$WorkingDirectory"
    $shortcut.WindowStyle = 7 # Takes only int values, 7 is "Minimized" style
    $shortcut.Save()
    Copy-Item "$DesktopPath\Gaming Gaiden.lnk" .
}

function CreateScheduledTask() {
    $GamingGaidenScript = (Get-Item ".\GamingGaiden.ps1")
    $GamingGaidenPath = $GamingGaidenScript.FullName
    $WorkingDirectory = $GamingGaidenScript.Directory.FullName

    $action = New-ScheduledTaskAction -Execute 'powershell' -Argument "-NoLogo -WindowStyle hidden -File `"$GamingGaidenPath`""
    $action.WorkingDirectory = "$WorkingDirectory"

    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -ExecutionTimeLimit 0

    $trigger = New-ScheduledTaskTrigger -AtStartup

    # Register the scheduled task
    Register-ScheduledTask -TaskName "Gaming Gaiden Autostart" -Description "Runs Gaming Gaiden at startup" -Action $action -Trigger $trigger -Settings $settings -Force
}

if ( $UserChoice.ToLower() -eq 'yes' )
{
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
    Get-ChildItem . -recurse | Unblock-File
    Install-Module ThreadJob
    Install-Module PSSqlite
    CreateShortcut

    $ScheduledTaskChoice = Read-Host -Prompt "Would you like Gaming Gaiden to auto start at boot? Yes/No"
    if ( $ScheduledTaskChoice.ToLower() -eq 'yes' ) {
        CreateScheduledTask
    }

    Write-Host "Installation successful. Enjoy." -ForegroundColor Green
    Start-Sleep 2
}
else
{
    Write-Host "User decided not to proceed with installation. Exiting." -ForegroundColor Green
    Start-Sleep 2
    exit 1
}
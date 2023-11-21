#Requires -Version 5.1
param(
	[string]$InstallDirectory
) 

Set-Location $InstallDirectory 

function UserPrompt($Msg, $Color = "Green") {
    Write-Host $Msg -ForegroundColor $Color
}

function CreateShortcut() {
    $GamingGaidenScript = (Get-Item ".\GamingGaiden.ps1")
    $GamingGaidenPath = $GamingGaidenScript.FullName
    $WorkingDirectory = $GamingGaidenScript.Directory.FullName

    $IconPath = (Get-Item ".\icons\running.ico").FullName
    $DesktopPath = [Environment]::GetFolderPath("Desktop")

    $shortcut = (New-Object -ComObject Wscript.Shell).CreateShortcut("$DesktopPath\Gaming Gaiden.lnk")
    $shortcut.TargetPath = 'powershell'
    $shortcut.Arguments = "-NoLogo -ExecutionPolicy bypass -File `"$GamingGaidenPath`""
    $shortcut.IconLocation = $IconPath
    $shortcut.WorkingDirectory = "$WorkingDirectory"
    $shortcut.WindowStyle = 7 # Takes only int values, 7 is "Minimized" style
    $shortcut.Save()
    Copy-Item "$DesktopPath\Gaming Gaiden.lnk" .
    Copy-Item "$DesktopPath\Gaming Gaiden.lnk" "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\"
}

function CreateScheduledTask() {
    $GamingGaidenScript = (Get-Item ".\GamingGaiden.ps1")
    $GamingGaidenPath = $GamingGaidenScript.FullName
    $WorkingDirectory = $GamingGaidenScript.Directory.FullName

    $action = New-ScheduledTaskAction -Execute 'powershell' -Argument "-NoLogo -ExecutionPolicy bypass -WindowStyle hidden -File `"$GamingGaidenPath`""
    $action.WorkingDirectory = "$WorkingDirectory"

    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -ExecutionTimeLimit 0

    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $trigger.Delay = 'PT1M'

    # Register the scheduled task
    Register-ScheduledTask -TaskName "Gaming Gaiden Autostart" -Description "Runs Gaming Gaiden at startup" -Action $action -Trigger $trigger -Settings $settings -Force
}

UserPrompt "Creating Shortcuts"
CreateShortcut
$ScheduledTaskChoice = Read-Host -Prompt "Would you like Gaming Gaiden to auto start at boot? Yes/No"
if ( $ScheduledTaskChoice.ToLower() -eq 'yes' ) {
    UserPrompt "Creating Scheduled Task"
    CreateScheduledTask
}
UserPrompt "Installation successful. Enjoy."
Start-Sleep 3
exit 0
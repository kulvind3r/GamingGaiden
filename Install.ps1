#Requires -Version 5.1

$isAdmin = [System.Security.Principal.WindowsPrincipal]::new(
    [System.Security.Principal.WindowsIdentity]::GetCurrent()).
        IsInRole('Administrators')

if(-not $isAdmin) {
    (Get-Location).path > "$env:TEMP\gg-install.config"
    $params = @{
        FilePath     = 'powershell' # or pwsh if Core
        Verb         = 'RunAs'
        ArgumentList = @(
            '-NoExit'
            '-ExecutionPolicy ByPass'
            '-File "{0}"' -f $PSCommandPath
        )
    }

    Start-Process @params
    return
}

$InstallDirectory = Get-Content "$env:TEMP\gg-install.config"
Set-Location $InstallDirectory.ToString()

function UserPrompt($Msg, $Color = "Green") {
    Write-Host $Msg -ForegroundColor $Color
}

function CheckConnection() {
    if ( -Not (Test-NetConnection www.powershellgallery.com -Port 443 -InformationLevel "Detailed").TcpTestSucceeded)
    {
        UserPrompt "Dependencies Need to be downloaded. No connection to Internet. Exiting" "Red"
        Start-Sleep -s 2
        exit 1
    }
}

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
    Copy-Item "$DesktopPath\Gaming Gaiden.lnk" "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\"
}

function CreateScheduledTask() {
    $GamingGaidenScript = (Get-Item ".\GamingGaiden.ps1")
    $GamingGaidenPath = $GamingGaidenScript.FullName
    $WorkingDirectory = $GamingGaidenScript.Directory.FullName

    $action = New-ScheduledTaskAction -Execute 'powershell' -Argument "-NoLogo -WindowStyle hidden -File `"$GamingGaidenPath`""
    $action.WorkingDirectory = "$WorkingDirectory"

    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -ExecutionTimeLimit 0

    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $trigger.Delay = 'PT1M'

    # Register the scheduled task
    Register-ScheduledTask -TaskName "Gaming Gaiden Autostart" -Description "Runs Gaming Gaiden at startup" -Action $action -Trigger $trigger -Settings $settings -Force
}

function InstallModules($Modules) {
    if ($Modules.Length -eq 0) { UserPrompt "All modules already installed."; return }

    Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted;
    foreach ($Module in $Modules) { Install-Module $Module }
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy Untrusted;
}

if (-Not ((Get-Module -ListAvailable -Name PSSqlite) -And (Get-Module -ListAvailable -Name ThreadJob))) { CheckConnection }

UserPrompt "Read the Following Notice Carefully"

Start-Sleep -s 2

UserPrompt @"
This script will setup Gaming Gaiden to run from current location on your PC
Following actions will be taken

1. Execution policy will be set to "RemoteSigned". This allows to run Powershell scripts after they are unblocked.

Read more here. https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-5.1#remotesigned

2. All scripts included with GamingGaiden will be unblocked so they can be run.

3. PSSQLite and ThreadJob modules will be installed from microsoft powershell gallery.

4. A shortcut will be placed on your desktop and in current directory to run Gaming Gaiden.

5. Optionally you can choose to add a scheduled task to run Gaming Gaiden automatically on startup.
"@ "White"

UserPrompt "Do you wish to proceed with installation? Yes/No"

$UserChoice = Read-Host

if ( $UserChoice.ToLower() -eq 'yes' )
{
    UserPrompt "Updating LocalMachine Execution Policy."
    $ErrorActionPreference = 'SilentlyContinue'
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
    Remove-Variable $ErrorActionPreference
    
    UserPrompt "Unblocking all Gaming Gaiden files"
    Get-ChildItem . -recurse | Unblock-File

    UserPrompt "Installing ThreadJob and PSSqlite Modules"

    $Modules = @()
    if (-Not (Get-Module -ListAvailable -Name ThreadJob)){ $Modules = $Modules + "ThreadJob" }
    if (-Not (Get-Module -ListAvailable -Name ThreadJob)){ $Modules = $Modules + "PSSqlite" }
    InstallModules $Modules

    UserPrompt "Creating Shortcut"
    CreateShortcut

    $ScheduledTaskChoice = Read-Host -Prompt "Would you like Gaming Gaiden to auto start at boot? Yes/No"
    if ( $ScheduledTaskChoice.ToLower() -eq 'yes' ) {
        UserPrompt "Creating Scheduled Task"
        CreateScheduledTask
    }

    UserPrompt "Installation successful. Enjoy."
    Remove-Item "$env:TEMP\gg-install.config" -Force
    Start-Sleep 2
    exit 0
}
else
{
    UserPrompt "User decided not to proceed with installation. Exiting."
    Remove-Item "$env:TEMP\gg-install.config" -Force
    Start-Sleep 2
    exit 1
}
#Requires -Version 5.1

#_pragma iconFile '.\build\GamingGaiden\icons\running.ico'
#_pragma title 'Gaming Gaiden: Gameplay Time Tracker'
#_pragma product 'Gaming Gaiden'
#_pragma copyright '© 2023 Kulvinder Singh'
#_pragma version '2025.11.28'

[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')    | Out-null
[System.Reflection.Assembly]::LoadWithPartialName('System.Drawing')          | Out-null
[System.Reflection.Assembly]::LoadWithPartialName('System.Web')          	 | Out-null
[System.Reflection.assembly]::LoadwithPartialname("Microsoft.VisualBasic")   | Out-Null

try {
    Import-Module ".\modules\PSSQLite"
    Import-Module ".\modules\ThreadJob"
    Import-Module ".\modules\HelperFunctions.psm1"
    Import-Module ".\modules\QueryFunctions.psm1"
    Import-Module ".\modules\SettingsFunctions.psm1"
    Import-Module ".\modules\SetupDatabase.psm1"
    Import-Module ".\modules\StorageFunctions.psm1"
    Import-Module ".\modules\UIFunctions.psm1"

    #------------------------------------------
    # Launch checks, disabled during development
    if ($env:GAIDEN_DEV_MODE -ne 'true') {
        
        # Exit if Gaming Gaiden is being started from non standard location
        $currentDirectory = (Get-Location).path
        if ($currentDirectory -ne "C:\ProgramData\GamingGaiden") {
            ShowMessage "Launched from non standard location. Please install and use the created shortcuts to start app." "Ok" "Error"
            exit 1;
        }

        # Exit if Gaming Gaiden is already Running
        $results = [System.Diagnostics.Process]::GetProcessesByName("GamingGaiden")
        if ($results.Length -gt 1) {
            ShowMessage "Gaming Gaiden is already running. Check system tray.`r`nNot Starting another Instance." "Ok" "Error"
            Log "Error: Gaming Gaiden already running. Not Starting another Instance."
            exit 1;
        }
    }

    #------------------------------------------
    # Clear log at application boot if log size has grown above 5 MB
    if ((Test-Path .\GamingGaiden.log) -And ((Get-Item .\GamingGaiden.log).Length / 1MB -gt 5)) {
        Remove-Item ".\GamingGaiden.log" -ErrorAction silentlycontinue
        $timestamp = Get-date -f s
        Log "Log grew more than 5 MB. Clearing."
    }

    #------------------------------------------
    # Setup Database
    Log "Executing database setup"
    SetupDatabase
    Log "Database setup complete"

    #------------------------------------------
    # Ensure cache directory exists
    if (-Not (Test-Path ".\ui\resources\images\cache")) {
        New-Item -ItemType Directory -Path ".\ui\resources\images\cache" -Force | Out-Null
        Log "Created cache directory"
    }

    #------------------------------------------
    # Initialize current PC if only one PC exists
    if (-Not (Read-Setting "current_pc")) {
        $pcCount = (RunDBQuery "SELECT COUNT(*) as count FROM gaming_pcs").count
        if ($pcCount -eq 1) {
            $pc = (RunDBQuery "SELECT name FROM gaming_pcs LIMIT 1").name
            Write-Setting "current_pc" $pc
            Log "Initialized current PC to $pc (only PC in database)"
        }
    }

    #------------------------------------------
    # Integrate With HWiNFO
    $HWInfoSensorTracking = 'HKCU:\SOFTWARE\HWiNFO64\Sensors\Custom\Gaming Gaiden\Other0'
    $HWInfoSensorSession = 'HKCU:\SOFTWARE\HWiNFO64\Sensors\Custom\Gaming Gaiden\Other1'

    if ((Test-Path "HKCU:\SOFTWARE\HWiNFO64") -And -Not (Test-Path "HKCU:\SOFTWARE\HWiNFO64\Sensors\Custom\Gaming Gaiden")) {
        Log "Integrating with HWiNFO"
        New-Item -path 'HKCU:\SOFTWARE\HWiNFO64\Sensors\Custom\Gaming Gaiden' -Name 'Other0' -Force | Out-Null
        New-Item -path 'HKCU:\SOFTWARE\HWiNFO64\Sensors\Custom\Gaming Gaiden' -Name 'Other1' -Force | Out-Null
        Set-Itemproperty -path $HWInfoSensorTracking -Name 'Name' -value 'Tracking'
        Set-Itemproperty -path $HWInfoSensorTracking -Name 'Unit' -value 'Yes/No'
        Set-Itemproperty -path $HWInfoSensorTracking -Name 'Value' -value 0
        Set-Itemproperty -path $HWInfoSensorSession -Name 'Name' -value 'Session Length'
        Set-Itemproperty -path $HWInfoSensorSession -Name 'Unit' -value 'Min'
        Set-Itemproperty -path $HWInfoSensorSession -Name 'Value' -value 0
    }
    else {
        Log "HWiNFO not detected. Or Gaming Gaiden is already Integrated. Skipping Auto Integration"
    }

    #------------------------------------------
    # Initialize theme.css on startup (default to light theme)
    $themePath = ".\ui\resources\css\theme.css"
    if (-not (Test-Path $themePath)) {
        $defaultThemePath = ".\ui\resources\css\theme-light.css"
        Copy-Item -Path $defaultThemePath -Destination $themePath -Force
    }

    #------------------------------------------
    # Tracker Job Scripts
    $TrackerJobInitializationScript = {
        Import-Module ".\modules\PSSQLite";
        Import-Module ".\modules\HelperFunctions.psm1";
        Import-Module ".\modules\UIFunctions.psm1";
        Import-Module ".\modules\ProcessFunctions.psm1";
        Import-Module ".\modules\QueryFunctions.psm1";
        Import-Module ".\modules\StorageFunctions.psm1";
        Import-Module ".\modules\UserInput.psm1";
    }

    $TrackerJobScript = {
        try {
            while ($true) {
                $detectedExe = DetectGame
                MonitorGame $detectedExe
                UpdateAllStatsInBackground
            }
        }
        catch {
            $timestamp = (Get-date -f %d-%M-%y`|%H:%m:%s)
            Write-Output "$timestamp : Error: A user or system error has caused an exception. Check log for details." >> ".\GamingGaiden.log"
            Write-Output "$timestamp : Exception: $($_.Exception.Message)" >> ".\GamingGaiden.log"
            Write-Output "$timestamp : Error: Tracker job has failed. Please restart from app menu to continue detection." >> ".\GamingGaiden.log"
            exit 1;
        }
    }

    #------------------------------------------
    # Functions
    function ResetIconAndSensors() {
        Log "Resetting Icon and Sensors"
        Remove-Item "$env:TEMP\GmGdn-TrackingGame.txt" -ErrorAction silentlycontinue
        Set-Itemproperty -path $HWInfoSensorTracking -Name 'Value' -value 0
        Set-Itemproperty -path $HWInfoSensorSession -Name 'Value' -value 0
        $AppNotifyIcon.Text = "Gaming Gaiden"
    }

    function  StartTrackerJob() {
        Start-ThreadJob -InitializationScript $TrackerJobInitializationScript -ScriptBlock $TrackerJobScript -Name "TrackerJob"
        $StopTrackerMenuItem.Enabled = $true
        $StartTrackerMenuItem.Enabled = $false

        # Reset App Icon & Cleanup Tracking file/reset sensors before starting tracker
        ResetIconAndSensors
        $AppNotifyIcon.Icon = $IconRunning
        Log "Started tracker."
    }

    function  StopTrackerJob() {
        Stop-Job "TrackerJob" -ErrorAction silentlycontinue
        $StopTrackerMenuItem.Enabled = $false
        $StartTrackerMenuItem.Enabled = $true

        # Reset App Icon & Cleanup Tracking file/reset sensors if stopped in middle of Tracking
        ResetIconAndSensors
        $AppNotifyIcon.Icon = $IconStopped
        Log "Stopped tracker"
    }

    function  ExecuteSettingsFunction() {
        Param(
            [scriptblock]$SettingsFunctionToCall,
            [string[]]$EntityList = $null
        )

        $databaseFileHashBefore = CalculateFileHash '.\GamingGaiden.db'; Log "Database hash before: $databaseFileHashBefore"

        if ($null -eq $EntityList) {
            $SettingsFunctionToCall.Invoke()
        }
        else {
            $SettingsFunctionToCall.Invoke((, $EntityList))
        }

        $databaseFileHashAfter = CalculateFileHash '.\GamingGaiden.db'; Log "Database hash after: $databaseFileHashAfter"

        if ($databaseFileHashAfter -ne $databaseFileHashBefore) {
            BackupDatabase
            Log "Rebooting tracker job to apply new settings"
            StopTrackerJob
            StartTrackerJob
            Log "Updating UI to reflect changes"
            UpdateAllStatsInBackground
        }
    }

    function UpdateAppIconToShowTracking() {
        if (Test-Path "$env:TEMP\GmGdn-TrackingGame.txt") {
            $gameName = Get-Content "$env:TEMP\GmGdn-TrackingGame.txt"
            $AppNotifyIcon.Text = "Tracking $gameName"
            $AppNotifyIcon.Icon = $IconTracking
            Set-Itemproperty -path $HWInfoSensorTracking -Name 'Value' -value 1
        }
        else {
            if ($AppNotifyIcon.Text -ne "Gaming Gaiden") {
                ResetIconAndSensors
                $AppNotifyIcon.Icon = $IconRunning
            }
        }
    }

    #------------------------------------------
    # Setup Timer To Monitor Tracking Updates from Tracker Job
    $Timer = New-Object Windows.Forms.Timer
    $Timer.Interval = 1000
    $Timer.Add_Tick({
        UpdateAppIconToShowTracking;
    })

    #------------------------------------------
    # Setup Tray Icon
    $menuItemSeparator1 = New-Object Windows.Forms.ToolStripSeparator
    $menuItemSeparator2 = New-Object Windows.Forms.ToolStripSeparator
    $menuItemSeparator3 = New-Object Windows.Forms.ToolStripSeparator
    $menuItemSeparator4 = New-Object Windows.Forms.ToolStripSeparator
    $menuItemSeparator5 = New-Object Windows.Forms.ToolStripSeparator
    $menuItemSeparator6 = New-Object Windows.Forms.ToolStripSeparator
    $menuItemSeparator7 = New-Object Windows.Forms.ToolStripSeparator
    $menuItemSeparator8 = New-Object Windows.Forms.ToolStripSeparator

    $IconRunning = [System.Drawing.Icon]::new(".\icons\running.ico")
    $IconTracking = [System.Drawing.Icon]::new(".\icons\tracking.ico")
    $IconStopped = [System.Drawing.Icon]::new(".\icons\stopped.ico")

    $AppNotifyIcon = New-Object System.Windows.Forms.NotifyIcon
    $AppNotifyIcon.Text = "Gaming Gaiden"
    $AppNotifyIcon.Icon = $IconRunning
    $AppNotifyIcon.Visible = $true

    $allGamesMenuItem = CreateMenuItem "All Games"

    $exitMenuItem = CreateMenuItem "Exit"
    $StartTrackerMenuItem = CreateMenuItem "Start Tracker"
    $StopTrackerMenuItem = CreateMenuItem "Stop Tracker"
    $helpMenuItem = CreateMenuItem "Help / FAQs"
    $aboutMenuItem = CreateMenuItem "About"

    $settingsSubMenuItem = CreateMenuItem "Settings"
    $addGameMenuItem = CreateMenuItem "Add Game"
    $addPlatformMenuItem = CreateMenuItem "Add Emulator"
    $editGameMenuItem = CreateMenuItem "Edit Game"
    $editPlatformMenuItem = CreateMenuItem "Edit Emulator"
    $gamingPCMenuItem = CreateMenuItem "Gaming PCs"
    $openInstallDirectoryMenuItem = CreateMenuItem "Open Install Directory"
    $lightThemeMenuItem = CreateMenuItem "Light Theme"
    $darkThemeMenuItem = CreateMenuItem "Dark Theme"
    $settingsSubMenuItem.DropDownItems.Add($addGameMenuItem)
    $settingsSubMenuItem.DropDownItems.Add($editGameMenuItem)
    $settingsSubMenuItem.DropDownItems.Add($menuItemSeparator1)
    $settingsSubMenuItem.DropDownItems.Add($addPlatformMenuItem)
    $settingsSubMenuItem.DropDownItems.Add($editPlatformMenuItem)
    $settingsSubMenuItem.DropDownItems.Add($menuItemSeparator7)
    $settingsSubMenuItem.DropDownItems.Add($lightThemeMenuItem)
    $settingsSubMenuItem.DropDownItems.Add($darkThemeMenuItem)
    $settingsSubMenuItem.DropDownItems.Add($menuItemSeparator8)
    $settingsSubMenuItem.DropDownItems.Add($gamingPCMenuItem)
    $settingsSubMenuItem.DropDownItems.Add($openInstallDirectoryMenuItem)
    

    $statsSubMenuItem = CreateMenuItem "Statistics"
    $gamingTimeMenuItem = CreateMenuItem "Time Spent Gaming"
    $mostPlayedMenuItem = CreateMenuItem "Most Played"
    $idleTimeMenuItem = CreateMenuItem "Idle Time"
    $pcVsEmulationMenuItem = CreateMenuItem "PC vs Emulation"
    $summaryItem = CreateMenuItem "Life Time Summary"
    $gamesPerPlatformMenuItem = CreateMenuItem "Games Per Platform"
    $sessionHistoryMenuItem = CreateMenuItem "Session History"
    $statsSubMenuItem.DropDownItems.Add($summaryItem)
    $statsSubMenuItem.DropDownItems.Add($gamingTimeMenuItem)
    $statsSubMenuItem.DropDownItems.Add($sessionHistoryMenuItem)
    $statsSubMenuItem.DropDownItems.Add($gamesPerPlatformMenuItem)
    $statsSubMenuItem.DropDownItems.Add($mostPlayedMenuItem)
    $statsSubMenuItem.DropDownItems.Add($idleTimeMenuItem)
    $statsSubMenuItem.DropDownItems.Add($pcVsEmulationMenuItem)
    

    $appContextMenu = New-Object System.Windows.Forms.ContextMenuStrip
    $appContextMenu.Items.AddRange(@($allGamesMenuItem, $menuItemSeparator2, $statsSubMenuItem, $menuItemSeparator3, $settingsSubMenuItem, $menuItemSeparator4, $StartTrackerMenuItem, $StopTrackerMenuItem, $menuItemSeparator5, $helpMenuItem, $aboutMenuItem, $menuItemSeparator6, $exitMenuItem))
    $AppNotifyIcon.ContextMenuStrip = $appContextMenu

    #------------------------------------------
    # Setup Tray Icon Actions
    $AppNotifyIcon.Add_Click({
            if ($_.Button -eq [Windows.Forms.MouseButtons]::Left) {
                RenderQuickView
            }

            if ($_.Button -eq [Windows.Forms.MouseButtons]::Right) {
                $AppNotifyIcon.ShowContextMenu
            }
        })

    #------------------------------------------
    # Setup Tray Icon Context Menu Actions
    $allGamesMenuItem.Add_Click({
            $gamesCheckResult = RenderGameList
            if ($gamesCheckResult -ne $false) {
                Invoke-Item ".\ui\AllGames.html"
            }
        })

    $StartTrackerMenuItem.Add_Click({
            StartTrackerJob;
            $AppNotifyIcon.ShowBalloonTip(3000, "Tracker Started", "Watching for game launches.", [System.Windows.Forms.ToolTipIcon]::Info)
        })

    $StopTrackerMenuItem.Add_Click({
            StopTrackerJob
            $AppNotifyIcon.ShowBalloonTip(3000, "Tracker Stopped", "Game launch detection disabled.", [System.Windows.Forms.ToolTipIcon]::Info)
        })

    $helpMenuItem.Add_Click({
            Log "Showing help"
            Invoke-Item ".\ui\Manual.html"
        })

    $aboutMenuItem.Add_Click({
            RenderAboutDialog
        })

    $exitMenuItem.Add_Click({
            $AppNotifyIcon.Visible = $false;
            Stop-Job -Name "TrackerJob";
            $Timer.Stop()
            $Timer.Dispose()
            [System.Windows.Forms.Application]::Exit();
        })

    #------------------------------------------
    # Statistics Sub Menu Actions
    $summaryItem.Add_Click({
            $sessionVsPlaytimeCheckResult = RenderSummary
            if ($sessionVsPlaytimeCheckResult -ne $false) {
                Invoke-Item ".\ui\Summary.html"
            }
        })

    $gamingTimeMenuItem.Add_Click({
            $gameTimeCheckResult = RenderGamingTime
            if ($gameTimeCheckResult -ne $false) {
                Invoke-Item ".\ui\GamingTime.html"
            }
        })

    $gamesPerPlatformMenuItem.Add_Click({
            $gamesPerPlatformCheckResult = RenderGamesPerPlatform
            if ($gamesPerPlatformCheckResult -ne $false) {
                Invoke-Item ".\ui\GamesPerPlatform.html"
            }
        })

    $mostPlayedMenuItem.Add_Click({
            $mostPlayedCheckResult = RenderMostPlayed
            if ($mostPlayedCheckResult -ne $false) {
                Invoke-Item ".\ui\MostPlayed.html"
            }
        })

    $idleTimeMenuItem.Add_Click({
            $idleTimeCheckResult = RenderIdleTime
            if ($idleTimeCheckResult -ne $false) {
                Invoke-Item ".\ui\IdleTime.html"
            }
        })

    $pcVsEmulationMenuItem.Add_Click({
            $pcVsEmulationCheckResult = RenderPCvsEmulation
            if ($pcVsEmulationCheckResult -ne $false) {
                Invoke-Item ".\ui\PCvsEmulation.html"
            }
        })

    $sessionHistoryMenuItem.Add_Click({
            $sessionHistoryCheckResult = RenderSessionHistory
            if ($sessionHistoryCheckResult -ne $false) {
                Invoke-Item ".\ui\SessionHistory.html"
            }
        })

    #------------------------------------------
    # Settings Sub Menu Actions
    $addGameMenuItem.Add_Click({
            Log "Starting game registration"

            ExecuteSettingsFunction -SettingsFunctionToCall $function:RenderAddGameForm

            # Cleanup temp Files
            Remove-Item -Force "$env:TEMP\GmGdn-*"
        })

    $addPlatformMenuItem.Add_Click({
            Log "Starting emulated platform registration"

            ExecuteSettingsFunction -SettingsFunctionToCall $function:RenderAddPlatformForm
        })

    $editGameMenuItem.Add_Click({
            Log "Starting game editing"

            $gamesList = (RunDBQuery "SELECT name FROM games").name
            if ($gamesList.Length -eq 0) {
                ShowMessage "No Games found in database. Please add few games first." "OK" "Error"
                Log "Error: Games list empty. Returning"
                return
            }

            ExecuteSettingsFunction -SettingsFunctionToCall $function:RenderEditGameForm -EntityList $gamesList

            # Cleanup temp Files
            Remove-Item -Force "$env:TEMP\GmGdn-*"
        })

    $editPlatformMenuItem.Add_Click({
            Log "Starting platform editing"

            $platformsList = (RunDBQuery "SELECT name FROM emulated_platforms").name
            if ($platformsList.Length -eq 0) {
                ShowMessage "No Platforms found in database. Please add few emulators first." "OK" "Error"
                Log "Error: Platform list empty. Returning"
                return
            }

            ExecuteSettingsFunction -SettingsFunctionToCall $function:RenderEditPlatformForm -EntityList $platformsList
        })

    $gamingPCMenuItem.Add_Click({
            Log "Starting Gaming PC registration"

            $PCList = (RunDBQuery "SELECT name FROM gaming_pcs").name

            ExecuteSettingsFunction -SettingsFunctionToCall $function:RenderGamingPCForm -EntityList $PCList

            # Cleanup temp Files
            Remove-Item -Force "$env:TEMP\GmGdn-*"
        })

    $openInstallDirectoryMenuItem.Add_Click({
            Log "Opening Install Directory"
            Invoke-Item .
        })

    $lightThemeMenuItem.Add_Click({
            Log "Switching to light theme"
            Set-Theme "light"
            ShowMessage "Light Theme applied. Refresh pages for effect." "Ok" "Info"
        })

    $darkThemeMenuItem.Add_Click({
            Log "Switching to dark theme"
            Set-Theme "dark"
            ShowMessage "Dark Theme applied. Refresh pages for effect." "Ok" "Info"
        })

    #------------------------------------------
    # Launch Application
    Log "Starting tracker on app boot"
    StartTrackerJob

    Log "Starting timer to check for Tracking updates"
    $Timer.Start()

    Log "Hiding powershell window"
    $windowCode = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
    $asyncWindow = Add-Type -MemberDefinition $windowCode -name Win32ShowWindowAsync -namespace Win32Functions -PassThru
    $null = $asyncWindow::ShowWindowAsync((Get-Process -PID $pid).MainWindowHandle, 0)

    Log "Informing user of successful application launch."
    $AppNotifyIcon.ShowBalloonTip(3000, "App Launched", "Use tray icon menu for all operations.", [System.Windows.Forms.ToolTipIcon]::Info)

    Log "Starting app context"
    $appContext = New-Object System.Windows.Forms.ApplicationContext
    [void][System.Windows.Forms.Application]::Run($appContext)
}
catch {
    [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')    | out-null
    [System.Windows.Forms.MessageBox]::Show("Exception: $($_.Exception.Message). Check log for details", 'Gaming Gaiden', "OK", "Error")

    $timestamp = Get-date -f s
    Write-Output "$timestamp : Error: A user or system error has caused an exception. Check log for details." >> ".\GamingGaiden.log"
    Write-Output "$timestamp : Exception: $($_.Exception.Message)" >> ".\GamingGaiden.log"
    exit 1;
}

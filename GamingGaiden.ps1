#Requires -Version 5.1
#Requires -Modules PSSQLite, ThreadJob

[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')    | Out-null
[System.Reflection.Assembly]::LoadWithPartialName('System.Drawing')          | Out-null
[System.Reflection.Assembly]::LoadWithPartialName('System.Web')          	 | Out-null

try {
	Import-Module PSSQLite
	Import-Module ThreadJob
	Import-Module -Name ".\modules\HelperFunctions.psm1"
	Import-Module -Name ".\modules\UIFunctions.psm1"
	
	# Check if Gaming Gaiden is already Running 
	$PsScriptsRunning = get-wmiobject win32_process | Where-Object{$_.processname -eq 'powershell.exe'} | select-object commandline,ProcessId

	ForEach ($PsCmdLine in $PsScriptsRunning){
		[Int32]$OtherPID = $PsCmdLine.ProcessId
		[String]$OtherCmdLine = $PsCmdLine.commandline
	
		If (($OtherCmdLine -like "*GamingGaiden.ps1*") -And ($OtherPID -ne $PID) ){
			ShowMessage "Gaming Gaiden is already running as PID [$OtherPID]. Not Starting another Instance." "Ok" "Error"
			Log "Gaming Gaiden is already running as PID [$OtherPID]. Not Starting another Instance."
			Exit
		}
	}

	ResetLog
	Log "Executing Database Setup"
	Start-Process -FilePath "powershell" -ArgumentList "-File","`".\SetupDatabase.ps1`"" -WindowStyle Hidden -Wait
	Log "Database Setup Complete"

	#------------------------------------------
	# Setup tracker Job Scripts and Other Functions
	$TrackerJobInitializationScript = {
		Import-Module -Name ".\modules\ProcessFunctions.psm1";
		Import-Module -Name ".\modules\HelperFunctions.psm1";
		Import-Module -Name ".\modules\QueryFunctions.psm1";
		Import-Module -Name ".\modules\StorageFunctions.psm1";
		Import-Module -Name ".\modules\UIFunctions.psm1"
		Import-Module PSSQLite;

		$Database = ".\GamingGaiden.db"
		$DBConnection = New-SQLiteConnection -DataSource $Database
	}

	$TrackerJobScript = {
		try {
			$RecordingNotifyIcon = CreateNotifyIcon "Tracking Game" ".\icons\recording.ico"
			while ($true) {
				$DetectedExe = DetectGame
				MonitorGame $DetectedExe $RecordingNotifyIcon
			}
		}
		catch {
			$RecordingNotifyIcon.Visible = $false
			$Timestamp = (Get-date -f %d-%M-%y`|%H:%m:%s)
			Write-Output "$Timestamp : A User or System error has caused an exception. Check Log for Details." >> ".\GamingGaiden.log"
			Write-Output "$Timestamp : Exception: $($_.Exception.Message)" >> ".\GamingGaiden.log"
			Write-Output "$Timestamp : Tracker job has failed. Please restart from app menu to continue detection." >> ".\GamingGaiden.log"
			exit 1;
		}
		
	}

	function  StartTrackerJob {
		Start-ThreadJob -InitializationScript $TrackerJobInitializationScript -ScriptBlock $TrackerJobScript -Name "TrackerJob"
		$StopTrackerMenuItem.Enabled = $true
		$StartTrackerMenuItem.Enabled = $false
		$AppNotifyIcon.Icon = $IconRunning
		Log "Started Tracker"
	}

	function  StopTrackerJob {
		Stop-Job "TrackerJob" -ErrorAction silentlycontinue
		$StopTrackerMenuItem.Enabled = $false
		$StartTrackerMenuItem.Enabled = $true
		$AppNotifyIcon.Icon = $IconStopped
		Log "Stopped Tracker"
	}

	function  ConfigureAction($Action, $WindowStyle = "Normal") {
		Log "Executing Configuration Action: $Action"
	   	Start-Process -FilePath "powershell" -ArgumentList "-File","`".\Configure.ps1`"", "$Action" -NoNewWindow -Wait
	   	Log "Rebooting Tracker Job to apply new configuration"
		StopTrackerJob
		StartTrackerJob
	}

	function CreateMenuSeparator(){
		return New-Object Windows.Forms.ToolStripSeparator
	}
	#------------------------------------------

	#------------------------------------------
	# Setup Tray Icon
	$MenuItemSeparator1 = CreateMenuSeparator
	$MenuItemSeparator2 = CreateMenuSeparator
	$MenuItemSeparator3 = CreateMenuSeparator
	$MenuItemSeparator4 = CreateMenuSeparator
	$MenuItemSeparator5 = CreateMenuSeparator
	$MenuItemSeparator6 = CreateMenuSeparator

	$IconRunning = [System.Drawing.Icon]::new(".\icons\running.ico")
	$IconStopped = [System.Drawing.Icon]::new(".\icons\stopped.ico")

	$AppNotifyIcon = CreateNotifyIcon "Gaming Gaiden" ".\icons\running.ico"
	$AppNotifyIcon.Visible = $true

	$MyGamesMenuItem = CreateMenuItem "My Games"
	$MyGamesMenuItem.Font = New-Object Drawing.Font("Segoe UI", 9, [Drawing.FontStyle]::Bold)

	$ExitMenuItem = CreateMenuItem "Exit"
	$StartTrackerMenuItem = CreateMenuItem "Start Tracker"
	$StopTrackerMenuItem = CreateMenuItem "Stop Tracker"
	$HelpMenuItem = CreateMenuItem "Help"
	
	$SettingsSubMenuItem = CreateMenuItem "Settings"
	$AddGameMenuItem = CreateMenuItem "Add Game"
	$AddPlatformMenuItem = CreateMenuItem "Add Emulator"
	$EditGameMenuItem = CreateMenuItem "Edit Game"
	$EditPlatformMenuItem = CreateMenuItem "Edit Emulator"
	$SettingsSubMenuItem.DropDownItems.Add($AddGameMenuItem)
	$SettingsSubMenuItem.DropDownItems.Add($EditGameMenuItem)
	$SettingsSubMenuItem.DropDownItems.Add($MenuItemSeparator1)
	$SettingsSubMenuItem.DropDownItems.Add($AddPlatformMenuItem)
	$SettingsSubMenuItem.DropDownItems.Add($EditPlatformMenuItem)

	$StatsSubMenuItem = CreateMenuItem "Statstics"
	$GamingTimeMenuItem = CreateMenuItem "Time Spent Gaming"
	$MostPlayedMenuItem = CreateMenuItem "Most Played"
	$GamesPerPlatformMenuItem = CreateMenuItem "Games Per Platform"
	$StatsSubMenuItem.DropDownItems.Add($GamingTimeMenuItem)
	$StatsSubMenuItem.DropDownItems.Add($MostPlayedMenuItem)
	$StatsSubMenuItem.DropDownItems.Add($GamesPerPlatformMenuItem)

	$AppContextMenu = New-Object System.Windows.Forms.ContextMenuStrip
	$AppContextMenu.Items.AddRange(@($MyGamesMenuItem, $MenuItemSeparator2, $StatsSubMenuItem, $MenuItemSeparator3, $SettingsSubMenuItem, $MenuItemSeparator4, $StartTrackerMenuItem, $StopTrackerMenuItem, $MenuItemSeparator5, $HelpMenuItem, $MenuItemSeparator6, $ExitMenuItem))
	$AppNotifyIcon.ContextMenuStrip = $AppContextMenu
	
	#------------------------------------------
	# Setup Tray Icon Actions
	$AppNotifyIcon.Add_Click({

		If ($_.Button -eq [Windows.Forms.MouseButtons]::Left) {
			Log "Rendering html list of tracked games"
			RenderGameList
			Invoke-Item ".\ui\MyGames.html"
			return
		}

		If ($_.Button -eq [Windows.Forms.MouseButtons]::Right) {
			$AppNotifyIcon.GetType().GetMethod("ShowContextMenu",[System.Reflection.BindingFlags]::Instance `
			-bor [System.Reflection.BindingFlags]::NonPublic).Invoke($AppNotifyIcon,$null)
		}
	})

	$MyGamesMenuItem.Add_Click({
		Log "Rendering html list of tracked games"
		RenderGameList
		Invoke-Item ".\ui\MyGames.html"
	})

	$GamingTimeMenuItem.Add_Click({
		Log "Rendering GamingTime"
		RenderGamingTime
		Invoke-Item ".\ui\GamingTime.html"
	})

	$MostPlayedMenuItem.Add_Click({
		Log "Rendering Most Played"
		RenderMostPlayed
		Invoke-Item ".\ui\MostPlayed.html"
	})

	$GamesPerPlatformMenuItem.Add_Click({
		Log "Rendering Games Per Platform"
		RenderGamesPerPlatform
		Invoke-Item ".\ui\GamesPerPlatform.html"
	})

	$HelpMenuItem.Add_Click({
		Log "Showing Help"
		Invoke-Item ".\ui\Manual.html"
	})

	$StartTrackerMenuItem.Add_Click({ 
		StartTrackerJob;
		$AppNotifyIcon.ShowBalloonTip(3000, "Gaming Gaiden", "Tracker Started.", [System.Windows.Forms.ToolTipIcon]::Info)
	})

	$StopTrackerMenuItem.Add_Click({ 
		StopTrackerJob
		$AppNotifyIcon.ShowBalloonTip(3000, "Gaming Gaiden", "Tracker Stopped.", [System.Windows.Forms.ToolTipIcon]::Info)
	})

	$AddGameMenuItem.Add_Click({ ConfigureAction "AddGame"; CleanupTempFiles })

	$AddPlatformMenuItem.Add_Click({ ConfigureAction "AddPlatform"; })

	$EditGameMenuItem.Add_Click({ ConfigureAction "EditGame"; CleanupTempFiles })

	$EditPlatformMenuItem.Add_Click({ ConfigureAction "EditPlatform"; })

	$ExitMenuItem.Add_Click({ $AppNotifyIcon.Visible = $false; Stop-Job -Name "TrackerJob"; [System.Windows.Forms.Application]::Exit(); })
	#------------------------------------------

	Log "Starting TrackerJob on app boot"
	StartTrackerJob

	Log "Hiding powershell window"
	$WindowCode = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
	$AsyncWindow = Add-Type -MemberDefinition $WindowCode -name Win32ShowWindowAsync -namespace Win32Functions -PassThru
	$null = $AsyncWindow::ShowWindowAsync((Get-Process -PID $pid).MainWindowHandle, 0)

	Log "Running one time garbage collection before app context launch"
	[System.GC]::Collect()

	Log "Starting app context"
	$AppContext = New-Object System.Windows.Forms.ApplicationContext
	[void][System.Windows.Forms.Application]::Run($AppContext)
}
catch {
	[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')    | out-null
    [System.Windows.Forms.MessageBox]::Show("Exception: $($_.Exception.Message). Check log for details",'Gaming Gaiden', "OK", "Error")

	$Timestamp = (Get-date -f %d-%M-%y`|%H:%m:%s)
    Write-Output "$Timestamp : A User or System error has caused an exception. Check Log for Details." >> ".\GamingGaiden.log"
    Write-Output "$Timestamp : Exception: $($_.Exception.Message)" >> ".\GamingGaiden.log"
    exit 1;
}
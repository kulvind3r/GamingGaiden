#Requires -Version 5.1

[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')    | Out-null
[System.Reflection.Assembly]::LoadWithPartialName('System.Drawing')          | Out-null
[System.Reflection.Assembly]::LoadWithPartialName('System.Web')          	 | Out-null

try {
	Import-Module ".\modules\PSSQLite"
	Import-Module ".\modules\ThreadJob"
	Import-Module ".\modules\HelperFunctions.psm1"
	Import-Module ".\modules\UIFunctions.psm1"
	
	# Check if Gaming Gaiden is already Running 
	$PsScriptsRunning = get-wmiobject win32_process | Where-Object{$_.processname -eq 'powershell.exe'} | select-object commandline,ProcessId

	ForEach ($PsCmdLine in $PsScriptsRunning){
		[Int32]$OtherPID = $PsCmdLine.ProcessId
		[String]$OtherCmdLine = $PsCmdLine.commandline
	
		If (($OtherCmdLine -like "*GamingGaiden.ps1*") -And ($OtherPID -ne $PID) ){
			ShowMessage "Gaming Gaiden is already running as PID [$OtherPID]. Not Starting another Instance." "Ok" "Error"
			Log "Error: Gaming Gaiden already running as PID [$OtherPID]. Not Starting another Instance."
			Exit
		}
	}

	ResetLog
	Log "Executing database setup"
	Start-Process -FilePath "powershell" -ArgumentList "-File","`".\SetupDatabase.ps1`"" -WindowStyle Hidden -Wait
	Log "Database setup complete"

	# Integrate With HWiNFO
	$HWinfoSensorTracking = 'HKCU:\SOFTWARE\HWiNFO64\Sensors\Custom\Gaming Gaiden\Other0'
	$HWinfoSensorSession = 'HKCU:\SOFTWARE\HWiNFO64\Sensors\Custom\Gaming Gaiden\Other1'

	if ((Test-Path "HKCU:\SOFTWARE\HWiNFO64") -And -Not (Test-Path "HKCU:\SOFTWARE\HWiNFO64\Sensors\Custom\Gaming Gaiden")) {
		Log "Integrating with HWiNFO"
		New-Item -path 'HKCU:\SOFTWARE\HWiNFO64\Sensors\Custom\Gaming Gaiden' -Name 'Other0' -Force
		New-Item -path 'HKCU:\SOFTWARE\HWiNFO64\Sensors\Custom\Gaming Gaiden' -Name 'Other1' -Force
		Set-Itemproperty -path $HWinfoSensorTracking -Name 'Name' -value 'Tracking'
		Set-Itemproperty -path $HWinfoSensorTracking -Name 'Unit' -value 'Yes/No'
		Set-Itemproperty -path $HWinfoSensorTracking -Name 'Value' -value 0
		Set-Itemproperty -path $HWinfoSensorSession -Name 'Name' -value 'Session Length'
		Set-Itemproperty -path $HWinfoSensorSession -Name 'Unit' -value 'Min'
		Set-Itemproperty -path $HWinfoSensorSession -Name 'Value' -value 0
	}
	else {
		Log "HWiNFO not detected. Or Gaming Gaiden is already Integrated. Skipping Auto Integration"
	}
	
	#------------------------------------------
	# Setup tracker Job Scripts and Other Functions
	$TrackerJobInitializationScript = {
		Import-Module ".\modules\ProcessFunctions.psm1";
		Import-Module ".\modules\HelperFunctions.psm1";
		Import-Module ".\modules\QueryFunctions.psm1";
		Import-Module ".\modules\StorageFunctions.psm1";
		Import-Module ".\modules\PSSQLite";
		Import-Module ".\modules\UserInput.psm1";
	}

	$TrackerJobScript = {
		try {
			while ($true) {
				$DetectedExe = DetectGame
				MonitorGame $DetectedExe
			}
		}
		catch {
			$Timestamp = (Get-date -f %d-%M-%y`|%H:%m:%s)
			Write-Output "$Timestamp : Error: A user or system error has caused an exception. Check log for details." >> ".\GamingGaiden.log"
			Write-Output "$Timestamp : Exception: $($_.Exception.Message)" >> ".\GamingGaiden.log"
			Write-Output "$Timestamp : Error: Tracker job has failed. Please restart from app menu to continue detection." >> ".\GamingGaiden.log"
			exit 1;
		}
	}

	function ResetIconAndSensors(){
		Log "Resetting Icon and Sensors"
		Remove-Item "$env:TEMP\GG-TrackingGame.txt" -ErrorAction silentlycontinue
		Set-Itemproperty -path $HWinfoSensorTracking -Name 'Value' -value 0
		Set-Itemproperty -path $HWinfoSensorSession -Name 'Value' -value 0
		$AppNotifyIcon.Text = "Gaming Gaiden"
	}

	function  StartTrackerJob {
		Start-ThreadJob -InitializationScript $TrackerJobInitializationScript -ScriptBlock $TrackerJobScript -Name "TrackerJob"
		$StopTrackerMenuItem.Enabled = $true
		$StartTrackerMenuItem.Enabled = $false

		# Reset App Icon & Cleanup Tracking file/reset sensors before starting tracker
		ResetIconAndSensors
		$AppNotifyIcon.Icon = $IconRunning
		Log "Started tracker"
	}

	function  StopTrackerJob {
		Stop-Job "TrackerJob" -ErrorAction silentlycontinue
		$StopTrackerMenuItem.Enabled = $false
		$StartTrackerMenuItem.Enabled = $true

		# Reset App Icon & Cleanup Tracking file/reset sensors if stopped in middle of Tracking
		ResetIconAndSensors
		$AppNotifyIcon.Icon = $IconStopped
		Log "Stopped tracker"
	}

	function  ConfigureAction($Action, $WindowStyle = "Normal") {
		$DatabaseFileHashBefore = CalculateFileHash '.\GamingGaiden.db'
    	Log "Database hash before: $DatabaseFileHashBefore"

		Log "Executing configuration action: $Action"
	   	Start-Process -FilePath "powershell" -ArgumentList "-File","`".\Configure.ps1`"", "$Action" -NoNewWindow -Wait

		$DatabaseFileHashAfter = CalculateFileHash '.\GamingGaiden.db'
		Log "Database hash after: $DatabaseFileHashAfter"
	
		if ($DatabaseFileHashAfter -ne $DatabaseFileHashBefore){
			BackupDatabase
			Log "Rebooting tracker job to apply new configuration"
			StopTrackerJob
			StartTrackerJob
		}
	}

	function CreateMenuSeparator(){
		return New-Object Windows.Forms.ToolStripSeparator
	}

	function UpdateAppIconToShowTracking(){
		if (Test-Path "$env:TEMP\GG-TrackingGame.txt")
		{
			$GameName = Get-Content "$env:TEMP\GG-TrackingGame.txt"
			$AppNotifyIcon.Text = "Tracking $GameName"
			$AppNotifyIcon.Icon = $IconTracking
			Set-Itemproperty -path $HWinfoSensorTracking -Name 'Value' -value 1
		}
		else
		{
			if ($AppNotifyIcon.Text -ne "Gaming Gaiden")
			{
				ResetIconAndSensors
				$AppNotifyIcon.Icon = $IconRunning
			} 
		}
	}

	#------------------------------------------
	# Setup Timer To Monitor Tracking Updates from Tracker Job
	$Timer = New-Object Windows.Forms.Timer
	$Timer.Interval = 750
	$Timer.Add_Tick({ UpdateAppIconToShowTracking })

	#------------------------------------------
	# Setup Tray Icon
	$MenuItemSeparator1 = CreateMenuSeparator
	$MenuItemSeparator2 = CreateMenuSeparator
	$MenuItemSeparator3 = CreateMenuSeparator
	$MenuItemSeparator4 = CreateMenuSeparator
	$MenuItemSeparator5 = CreateMenuSeparator
	$MenuItemSeparator6 = CreateMenuSeparator

	$IconRunning = [System.Drawing.Icon]::new(".\icons\running.ico")
	$IconTracking = [System.Drawing.Icon]::new(".\icons\tracking.ico")
	$IconStopped = [System.Drawing.Icon]::new(".\icons\stopped.ico")

	$AppNotifyIcon = CreateNotifyIcon "Gaming Gaiden" ".\icons\running.ico"
	$AppNotifyIcon.Visible = $true

	$AllGamesMenuItem = CreateMenuItem "All Games"
	$AllGamesMenuItem.Font = New-Object Drawing.Font("Segoe UI", 9, [Drawing.FontStyle]::Bold)

	$ExitMenuItem = CreateMenuItem "Exit"
	$StartTrackerMenuItem = CreateMenuItem "Start Tracker"
	$StopTrackerMenuItem = CreateMenuItem "Stop Tracker"
	$HelpMenuItem = CreateMenuItem "Help"
	$AboutMenuItem = CreateMenuItem "About"
	
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

	$StatsSubMenuItem = CreateMenuItem "Statistics"
	$GamingTimeMenuItem = CreateMenuItem "Time Spent Gaming"
	$MostPlayedMenuItem = CreateMenuItem "Most Played"
	$IdleTimeMenuItem = CreateMenuItem "Idle Time"
	$PCvsEmulationMenuItem = CreateMenuItem "PC vs Emulation Time"
	$SummaryItem = CreateMenuItem "Life Time Summary"
	$GamesPerPlatformMenuItem = CreateMenuItem "Games Per Platform"
	$StatsSubMenuItem.DropDownItems.Add($SummaryItem)
	$StatsSubMenuItem.DropDownItems.Add($GamingTimeMenuItem)
	$StatsSubMenuItem.DropDownItems.Add($GamesPerPlatformMenuItem)
	$StatsSubMenuItem.DropDownItems.Add($MostPlayedMenuItem)
	$StatsSubMenuItem.DropDownItems.Add($IdleTimeMenuItem)
	$StatsSubMenuItem.DropDownItems.Add($PCvsEmulationMenuItem)
	

	$AppContextMenu = New-Object System.Windows.Forms.ContextMenuStrip
	$AppContextMenu.Items.AddRange(@($AllGamesMenuItem, $MenuItemSeparator2, $StatsSubMenuItem, $MenuItemSeparator3, $SettingsSubMenuItem, $MenuItemSeparator4, $StartTrackerMenuItem, $StopTrackerMenuItem, $MenuItemSeparator5, $HelpMenuItem, $AboutMenuItem, $MenuItemSeparator6, $ExitMenuItem))
	$AppNotifyIcon.ContextMenuStrip = $AppContextMenu

	#------------------------------------------
	# Setup Quick View Form
	$QuickViewForm = CreateForm "Currently Playing / Recently Finished Games" 400 388 ".\icons\running.ico"
	$QuickViewForm.MaximizeBox = $false; $QuickViewForm.MinimizeBox = $false;
	$QuickViewForm.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
	$QuickViewForm.TopMost = $true

	$dataGridView = New-Object System.Windows.Forms.DataGridView
	$dataGridView.Dock = [System.Windows.Forms.DockStyle]::Fill
	$dataGridView.BorderStyle = [System.Windows.Forms.BorderStyle]::None
	$dataGridView.RowTemplate.Height = 65
	$dataGridView.AllowUserToAddRows = $false
	$dataGridView.RowHeadersVisible = $false
	$dataGridView.CellBorderStyle = "None"
	$dataGridView.AutoSizeColumnsMode = "Fill"
	$dataGridView.DefaultCellStyle.Padding = New-Object System.Windows.Forms.Padding(2, 2, 2, 2)
	$dataGridView.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect

	$iconColumn = New-Object System.Windows.Forms.DataGridViewImageColumn
	$iconColumn.Name = "icon"
	$iconColumn.HeaderText = ""
	$iconColumn.ImageLayout = [System.Windows.Forms.DataGridViewImageCellLayout]::Zoom
	$dataGridView.Columns.Add($iconColumn)

	$dataGridView.Columns.Add("name", "Name")
	$dataGridView.Columns.Add("play_time", "Playtime")
	$dataGridView.Columns.Add("last_play_date", "Last Played On")

	foreach ($column in $dataGridView.Columns) {
		$column.Resizable = [System.Windows.Forms.DataGridViewTriState]::False
	}

	$QuickViewForm.Controls.Add($dataGridView)

	# Event handler to hide the form when it loses focus
	$QuickViewForm.Add_Deactivate({
		$QuickViewForm.Hide()
	})

	# Event handler to hide the form when it is closed by User
	$IsParentAppBeingShutdown = $false
	$QuickViewForm.Add_FormClosing({
		param($sender, $e)

		# If gaming gaiden is not exiting, just hide instead of closing
		if (-not $IsParentAppBeingShutdown) {
			$e.Cancel = $true
			$sender.Hide()
		}
	})

	function ShowPopup {
		$screenBounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
		$formWidth = $QuickViewForm.Width
		$formHeight = $QuickViewForm.Height
		$QuickViewForm.Left = $screenBounds.Width - $formWidth - 20
		$QuickViewForm.Top = $screenBounds.Height - $formHeight - 40

		$LastFiveGamesQuery = "Select icon, name, play_time, last_play_date from games ORDER BY completed, last_play_date DESC LIMIT 5"
		$GameRecords = RunDBQuery $LastFiveGamesQuery
		if ($GameRecords.Length -eq 0) {
			ShowMessage "No Games found in DB. Please add some games first." "OK" "Error"
			Log "Error: Games list empty. Returning"
			return
		}
		
		$dataGridView.Rows.Clear()

		foreach ($row in $GameRecords) {
			$image = BytesToBitmap $row.icon
			$playTimeFormatted = PlayTimeMinsToString $row.play_time
			$dateFormatted = PlayDateEpochToString $row.last_play_date
			$dataGridView.Rows.Add($image, $row.name, $playTimeFormatted, $dateFormatted)
		}

		foreach ($row in $dataGridView.Rows) {
			$row.Resizable = [System.Windows.Forms.DataGridViewTriState]::False
		}

		$QuickViewForm.Show()
		$QuickViewForm.Activate()
	}

	#------------------------------------------
	# Setup Tray Icon Actions
	$AppNotifyIcon.Add_Click({
		If ($_.Button -eq [Windows.Forms.MouseButtons]::Left) {
			ShowPopup
		}

		If ($_.Button -eq [Windows.Forms.MouseButtons]::Right) {
			$AppNotifyIcon.GetType().GetMethod("ShowContextMenu",[System.Reflection.BindingFlags]::Instance `
			-bor [System.Reflection.BindingFlags]::NonPublic).Invoke($AppNotifyIcon,$null)
		}
	})

	$AllGamesMenuItem.Add_Click({
		$GamesCheckResult = RenderGameList
		if ($GamesCheckResult -ne $false) {
			Invoke-Item ".\ui\AllGames.html"
		}
	})

	$GamingTimeMenuItem.Add_Click({
		$GameTimeCheckResult = RenderGamingTime
		if ($GameTimeCheckResult -ne $false) {
			Invoke-Item ".\ui\GamingTime.html"
		}
	})

	$MostPlayedMenuItem.Add_Click({
		$MostPlayedCheckResult = RenderMostPlayed
		if ($MostPlayedCheckResult -ne $false) {
			Invoke-Item ".\ui\MostPlayed.html"
		}
	})

	$IdleTimeMenuItem.Add_Click({
		$IdleTimeCheckResult = RenderIdleTime
		if ($IdleTimeCheckResult -ne $false) {
			Invoke-Item ".\ui\IdleTime.html"
		}
	})

	$PCvsEmulationMenuItem.Add_Click({
		$PCvsEmulationCheckResult = RenderPCvsEmulation
		if ($PCvsEmulationCheckResult -ne $false) {
			Invoke-Item ".\ui\PCvsEmulation.html"
		}
	})

	$SummaryItem.Add_Click({
		$SessionVsPlaytimeCheckResult = RenderSummary
		if ($SessionVsPlaytimeCheckResult -ne $false) {
			Invoke-Item ".\ui\Summary.html"
		}
	})

	$GamesPerPlatformMenuItem.Add_Click({
		$GamesPerPlatformCheckResult = RenderGamesPerPlatform
		if ($GamesPerPlatformCheckResult -ne $false) {
			Invoke-Item ".\ui\GamesPerPlatform.html"
		}
	})

	$HelpMenuItem.Add_Click({
		Log "Showing help"
		Invoke-Item ".\ui\Manual.html"
	})

	$AboutMenuItem.Add_Click({
		RenderAboutDialog
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

	$ExitMenuItem.Add_Click({ 
		$AppNotifyIcon.Visible = $false; 
		Stop-Job -Name "TrackerJob";
		$Timer.Stop()
		$Timer.Dispose()
		$global:IsParentAppBeingShutdown = $true
		$QuickViewForm.Close()
		[System.Windows.Forms.Application]::Exit(); 
	})
	#------------------------------------------

	Log "Starting tracker on app boot"
	StartTrackerJob

	Log "Starting timer to check for Tracking updates"
	$Timer.Start()

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

	$Timestamp = Get-date -f s
    Write-Output "$Timestamp : Error: A user or system error has caused an exception. Check log for details." >> ".\GamingGaiden.log"
    Write-Output "$Timestamp : Exception: $($_.Exception.Message)" >> ".\GamingGaiden.log"
    exit 1;
}

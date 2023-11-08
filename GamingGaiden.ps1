#Requires -Version 5.1
#Requires -Modules PSSQLite, ThreadJob

[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')    | out-null
[System.Reflection.Assembly]::LoadWithPartialName('presentationframework')   | out-null
[System.Reflection.Assembly]::LoadWithPartialName('System.Drawing')          | out-null
[System.Reflection.Assembly]::LoadWithPartialName('System.Web')          	 | out-null
[System.Reflection.Assembly]::LoadWithPartialName('WindowsFormsIntegration') | out-null
[System.Reflection.assembly]::loadwithpartialname("microsoft.visualbasic") | Out-Null

try {
	Import-Module PSSQLite
	Import-Module ThreadJob
	Import-Module -Name ".\modules\HelperFunctions.psm1"
	Import-Module -Name ".\modules\UIFunctions.psm1"
	
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
				$RecordingNotifyIcon.Visible = $true
				MonitorGame $DetectedExe $RecordingNotifyIcon
				$RecordingNotifyIcon.Visible = $false
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

	$IconRunning = [System.Drawing.Icon]::new(".\icons\running.ico")
	$IconStopped = [System.Drawing.Icon]::new(".\icons\stopped.ico")

	$AppNotifyIcon = CreateNotifyIcon "Gaming Gaiden" ".\icons\running.ico"
	$AppNotifyIcon.Visible = $true

	$ShowListMenuItem = CreateMenuItem "My Games"
	$ShowStatsMenuItem = CreateMenuItem "Statstics"
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
		
	$AppContextMenu = New-Object System.Windows.Forms.ContextMenuStrip
	$AppContextMenu.Items.AddRange(@($ShowListMenuItem, $ShowStatsMenuItem, $MenuItemSeparator2, $SettingsSubMenuItem, $MenuItemSeparator3, $StartTrackerMenuItem, $StopTrackerMenuItem, $MenuItemSeparator4, $HelpMenuItem, $MenuItemSeparator5, $ExitMenuItem))
	$AppNotifyIcon.ContextMenuStrip = $AppContextMenu
	
	#------------------------------------------
	# Setup Tray Icon Actions
	$AppNotifyIcon.Add_Click({                    
		If ($_.Button -eq [Windows.Forms.MouseButtons]::Left) {
			$AppNotifyIcon.GetType().GetMethod("ShowContextMenu",[System.Reflection.BindingFlags]::Instance `
			-bor [System.Reflection.BindingFlags]::NonPublic).Invoke($AppNotifyIcon,$null)
		}
	})

	$ShowListMenuItem.Add_Click({
		Log "Rendering html list of tracked games"
		RenderGameList
		Invoke-Item ".\ui\index.html"
	})

	$ShowStatsMenuItem.Add_Click({
		Log "Rendering History"
		RenderHistory
		Invoke-Item ".\ui\history.html"
	})

	$HelpMenuItem.Add_Click({
		Log "Showing Help"
		Invoke-Item ".\ui\manual.html"
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
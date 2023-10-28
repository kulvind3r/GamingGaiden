[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')    | out-null
[System.Reflection.Assembly]::LoadWithPartialName('presentationframework')   | out-null
[System.Reflection.Assembly]::LoadWithPartialName('System.Drawing')          | out-null
[System.Reflection.Assembly]::LoadWithPartialName('System.Web')          	 | out-null
[System.Reflection.Assembly]::LoadWithPartialName('WindowsFormsIntegration') | out-null

try {
	Import-Module PSSQLite
	Import-Module -Name ".\Functions.psm1"
	Import-Module ThreadJob

	Log "Executing Database Setup"
	Start-Process -FilePath "powershell" -ArgumentList "-File","`".\SetupDatabase.ps1`"" -WindowStyle Hidden
	Log "Database Setup Complete"

	#------------------------------------------
	# Setup tracker Job Script and Job Function
	$TrackerJobInitializationScript = {
		Import-Module -Name ".\Functions.psm1"; 
		Import-Module PSSQLite;

		$Database = ".\GameplayGaiden.db"
		$DBConnection = New-SQLiteConnection -DataSource $Database
	}

	$TrackerJobScript = {
		try {
			$RecordingNotifyIcon = New-Object System.Windows.Forms.NotifyIcon
			$RecordingIcon = [System.Drawing.Icon]::new(".\icons\recording.ico")
			$RecordingNotifyIcon.Text = "Tracking Game"; $RecordingNotifyIcon.Icon = $RecordingIcon;

			while ($true) {
				$DetectedGame = DetectGame
				$RecordingNotifyIcon.Visible = $true
				$RecordingNotifyIcon.Text = "Tracking $DetectedGame"
				MonitorGame $DetectedGame
				$RecordingNotifyIcon.Visible = $false
			}
		}
		catch {
			$RecordingNotifyIcon.Visible = $false
			$Timestamp = (Get-date -f %d-%M-%y`|%H:%m:%s)
			Write-Output "$Timestamp : A User or System error has caused an exception. Check Log for Details." >> ".\GameplayGaiden.log"
			Write-Output "$Timestamp : Exception: $($_.Exception.Message)" >> ".\GameplayGaiden.log"
			Write-Output "$Timestamp : Tracker job has failed. Please restart from app menu to continue detection." >> ".\GameplayGaiden.log"
			exit 1;
		}
		
	}

	function  StartTrackerJob {
		Start-ThreadJob -InitializationScript $TrackerJobInitializationScript -ScriptBlock $TrackerJobScript -Name "TrackerJob"
	}
	#------------------------------------------

	#------------------------------------------
	# Setup Tray Icon
	$RunningIcon = [System.Drawing.Icon]::new(".\icons\running.ico")

	$AppNotifyIcon = New-Object System.Windows.Forms.NotifyIcon
	$AppNotifyIcon.Text = "Gameplay Gaiden"; $AppNotifyIcon.Icon = $RunningIcon; $AppNotifyIcon.Visible = $true

	$ConfigureMenuItem = CreateMenuItem $true "Configure"
	$ShowListMenuItem = CreateMenuItem $true "Show List"
	$ExitMenuItem = CreateMenuItem $true "Exit"
	$RestartTrackerMenuItem = CreateMenuItem $true "Restart Tracker"

	$AppContextMenu = New-Object System.Windows.Forms.ContextMenu
	$AppNotifyIcon.ContextMenu = $AppContextMenu
	$AppNotifyIcon.ContextMenu.MenuItems.AddRange(@($ShowListMenuItem, $RestartTrackerMenuItem, $ConfigureMenuItem, $ExitMenuItem))

	$AppNotifyIcon.Add_Click({                    
		If ($_.Button -eq [Windows.Forms.MouseButtons]::Left) {
			$AppNotifyIcon.GetType().GetMethod("ShowContextMenu",[System.Reflection.BindingFlags]::Instance `
			-bor [System.Reflection.BindingFlags]::NonPublic).Invoke($AppNotifyIcon,$null)
		}
	})

	$ConfigureMenuItem.Add_Click({
		Log "Stopping TrackerJob to start configuration. Any ongoing gameplay session will be lost."
		Stop-Job "TrackerJob"
		Log "Launching configuration script"
		Start-Process -FilePath "powershell" -ArgumentList "-File","`".\ConfigureGG.ps1`"" -WindowStyle Normal
		Log "Starting TrackerJob again after configuration."
		StartTrackerJob
	})

	$ShowListMenuItem.Add_Click({
		Log "Rendering html list of tracked games"
		RenderGameList
		Invoke-Item ".\ui\index.html"
	})

	$RestartTrackerMenuItem.Add_Click({
		Log "Restarting Tracker Job"
		Stop-Job "TrackerJob" -ErrorAction silentlycontinue
		StartTrackerJob
	})

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
	$Timestamp = (Get-date -f %d-%M-%y`|%H:%m:%s)
    Write-Output "$Timestamp : A User or System error has caused an exception. Check Log for Details." >> ".\GameplayGaiden.log"
    Write-Output "$Timestamp : Exception: $($_.Exception.Message)" >> ".\GameplayGaiden.log"
    Start-Sleep -s 5; exit 1;
}
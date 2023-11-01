#Requires -Version 5.1
#Requires -Modules PSSQLite, ThreadJob

[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')    | out-null
[System.Reflection.Assembly]::LoadWithPartialName('presentationframework')   | out-null
[System.Reflection.Assembly]::LoadWithPartialName('System.Drawing')          | out-null
[System.Reflection.Assembly]::LoadWithPartialName('System.Web')          	 | out-null
[System.Reflection.Assembly]::LoadWithPartialName('WindowsFormsIntegration') | out-null

try {
	Import-Module PSSQLite
	Import-Module ThreadJob
	Import-Module -Name ".\modules\HelperFunctions.psm1"
	Import-Module -Name ".\modules\UIFunctions.psm1"
	
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
	}

	function  RebootTrackerJob {
		Stop-Job "TrackerJob" -ErrorAction silentlycontinue
		StartTrackerJob
	}

	function  ConfigureAction($Action, $WindowStyle = "Normal") {
		Log "Executing Configuration Action: $Action"
	   	Start-Process -FilePath "powershell" -ArgumentList "-File","`".\Configure.ps1`"", "$Action" -WindowStyle $WindowStyle -Wait
	   	Log "Rebooting Tracker Job to apply new configuration"
		RebootTrackerJob
	}
	#------------------------------------------

	#------------------------------------------
	# Setup Tray Icon
	$AppNotifyIcon = CreateNotifyIcon "Gaming Gaiden" ".\icons\running.ico"
	$AppNotifyIcon.Visible = $true

	$ShowListMenuItem = CreateMenuItem "My Games"
	$ExitMenuItem = CreateMenuItem "Exit"
	$RestartTrackerMenuItem = CreateMenuItem "Restart Tracker"
	
	$ConfigureSubMenuItem = CreateMenuItem "Configure"
	$RegGameMenuItem = CreateMenuItem "Register Game"
	$RegPlatformMenuItem = CreateMenuItem "Register Emulator"
	$UpdateGameIconMenuItem = CreateMenuItem "Update Game Icon"
	
	$ConfigureSubMenuItem.DropDownItems.Add($RegGameMenuItem)
	$ConfigureSubMenuItem.DropDownItems.Add($RegPlatformMenuItem)
	$ConfigureSubMenuItem.DropDownItems.Add($UpdateGameIconMenuItem)
	
	$AppContextMenu = New-Object System.Windows.Forms.ContextMenuStrip
	$AppContextMenu.Items.AddRange(@($ShowListMenuItem, $ConfigureSubMenuItem, $RestartTrackerMenuItem, $ExitMenuItem))
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

	$RestartTrackerMenuItem.Add_Click({ 
		RebootTrackerJob; 
		$AppNotifyIcon.ShowBalloonTip(3000, "Gaming Gaiden", "Tracker Restarted", [System.Windows.Forms.ToolTipIcon]::Info)
	})

	$RegGameMenuItem.Add_Click({ ConfigureAction "RegisterGame"; })

	$RegPlatformMenuItem.Add_Click({ ConfigureAction "RegisterEmulatedPlatform"; })

	$UpdateGameIconMenuItem.Add_Click({ ConfigureAction "UpdateGameIcon" "Hidden"; })

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
    Write-Output "$Timestamp : A User or System error has caused an exception. Check Log for Details." >> ".\GamingGaiden.log"
    Write-Output "$Timestamp : Exception: $($_.Exception.Message)" >> ".\GamingGaiden.log"
    Start-Sleep -s 5; exit 1;
}
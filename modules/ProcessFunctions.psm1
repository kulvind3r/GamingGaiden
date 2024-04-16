function DetectGame() {
	Log "Starting game detection"

    $GetGameExesQuery = "SELECT exe_name FROM games ORDER BY last_play_date DESC"
	$GetEmulatorExesQuery = "SELECT exe_name FROM emulated_platforms"

    $GameExeList = (RunDBQuery $GetGameExesQuery).exe_name
	
	$RawEmulatorExes = (RunDBQuery $GetEmulatorExesQuery).exe_name
	# Flatten the rows with multiple exes into a single list
	$EmulatorExeList = ($RawEmulatorExes -join ',') -split ','

	$ExesToDetect = $($GameExeList; $EmulatorExeList) | Select-Object -Unique

    do {
		$AllProcesses = ((Get-Process).ProcessName | Select-Object -Unique)
        foreach ( $ExeName in $ExesToDetect ){
			if ( $AllProcesses -contains $ExeName )
			{
				Log "Found $ExeName running. Exiting detection"
				return $ExeName
			}
		}
		Clear-Variable AllProcesses; Remove-Variable AllProcesses
		# Mandatory Garbage collect in loop because powershell is dogshit in recovering memory from infinite loops
		[System.GC]::GetTotalMemory($true) | out-null
        Start-Sleep -s 5
    }
    while ($true)
}

function TimeTrackerLoop($DetectedExe) {
	$HWinfoSensorSession = 'HKCU:\SOFTWARE\HWiNFO64\Sensors\Custom\Gaming Gaiden\Other1'
	$PlayTimeForCurrentSession = 0
	$IdleSessionsCount = 0
	$IdleSessions = New-Object int[] 100;
	$ExeStartTime = (Get-Process $DetectedExe).StartTime | Sort-Object | Select-Object -First 1
    while(Get-Process $DetectedExe)
    {
        $PlayTimeForCurrentSession = [int16] (New-TimeSpan -Start $ExeStartTime).TotalMinutes
		$IdleTime = [int16] ([PInvoke.Win32.UserInput]::IdleTime).Minutes
		if ($IdleTime -ge 10)
		{
			# Entered idle Session
			while( $IdleTime -ge 10)
			{
				# Track idle Time for current Idle Session
				$IdleSessions[$IdleSessionsCount] = $IdleTime
				$IdleTime = [int16] ([PInvoke.Win32.UserInput]::IdleTime).Minutes

				# Keep the hwinfo sensor updated to current play time session length while tracking idle session
				$PlayTimeForCurrentSession = [int16] (New-TimeSpan -Start $ExeStartTime).TotalMinutes
				Set-Itemproperty -path $HWinfoSensorSession -Name 'Value' -value $PlayTimeForCurrentSession

				Start-Sleep -s 5
			}
			# Exited Idle Session, increment idle session counter for storing next idle sessions's length
			$IdleSessionsCount++
		}
		Set-Itemproperty -path $HWinfoSensorSession -Name 'Value' -value $PlayTimeForCurrentSession
        Start-Sleep -s 5
    }
	$IdleTimeForCurrentSession = ($IdleSessions | Measure-Object -Sum).Sum
	Log "Play time for current session: $PlayTimeForCurrentSession min. Idle time for current session: $IdleTimeForCurrentSession min."
	$PlayTimeExcludingIdleTime = $PlayTimeForCurrentSession - $IdleTimeForCurrentSession
	Log "Play time for current session excluding Idle time $PlayTimeExcludingIdleTime min"
	return @($PlayTimeExcludingIdleTime, $IdleTimeForCurrentSession)
}

function MonitorGame($DetectedExe) {
	Log "Starting monitoring for $DetectedExe"
	
	$DatabaseFileHashBefore = CalculateFileHash '.\GamingGaiden.db'
	Log "Database hash before: $DatabaseFileHashBefore"

	$EmulatedGameDetails = $null
	$GameName = $null
	$EntityFound = $null
	$UpdatedPlayTime = 0
	$UpdatedLastPlayDate = (Get-Date -UFormat %s).Split('.').Get(0)

	if (IsExeEmulator $DetectedExe)
	{
		$EmulatedGameDetails = findEmulatedGameDetails $DetectedExe
		if ($EmulatedGameDetails -eq $false)
		{
			Log "Error: Problem in fetching emulated game details. See earlier logs for more info"
			Log "Error: Cannot resume detection until $DetectedExe exits. No playtime will be recorded."
			
			TimeTrackerLoop $DetectedExe
			return
		}
		$GameName = $EmulatedGameDetails.Name
		$EntityFound = DoesEntityExists "games" "name" $GameName
	}
	else
	{
		$DetectedExePattern = SQLEscapedMatchPattern($DetectedExe.Trim())
		$GetGameNameQuery = "SELECT name FROM games WHERE exe_name LIKE '{0}'" -f $DetectedExePattern
		$EntityFound = RunDBQuery $GetGameNameQuery
		$GameName = $EntityFound.name
	}
	
	Write-Output "$GameName" > "$env:TEMP\GG-TrackingGame.txt"
	$SessionTimeDetails = TimeTrackerLoop $DetectedExe
    $CurrentPlayTime = $SessionTimeDetails[0]
	$CurrentIdleTime = $SessionTimeDetails[1]
	Remove-Item "$env:TEMP\GG-TrackingGame.txt"

	if ($null -ne $EntityFound)
	{
		Log "Game Already Exists. Updating PlayTime and Last Played Date"
		
		$RecordedGamePlayTime = GetPlayTime $GameName
		$RecordedGameIdleTime = GetIdleTime $GameName
		$UpdatedPlayTime = $RecordedGamePlayTime + $CurrentPlayTime
		$UpdatedIdleTime = $RecordedGameIdleTime + $CurrentIdleTime
		
		UpdateGameOnSession -GameName $GameName -GamePlayTime $UpdatedPlayTime -GameIdleTime $UpdatedIdleTime -GameLastPlayDate $UpdatedLastPlayDate
	}
	else
	{
		Log "Game Doesn't Exists. Adding New Game"
		SaveGame -GameName $GameName -GameExeName $DetectedExe -GameIconPath "./icons/default.png" `
				 -GamePlayTime $CurrentPlayTime -GameIdleTime $CurrentIdleTime -GameLastPlayDate $UpdatedLastPlayDate -GameCompleteStatus 'FALSE' -GamePlatform $EmulatedGameDetails.Platform
	}

	RecordPlaytimOnDate($CurrentPlayTime)

	$DatabaseFileHashAfter = CalculateFileHash '.\GamingGaiden.db'
	Log "Database hash after: $DatabaseFileHashAfter"

	if ($DatabaseFileHashAfter -ne $DatabaseFileHashBefore){
        BackupDatabase
    }
}
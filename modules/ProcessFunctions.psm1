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
	$CurrentPlayTime = 0
	$ExeStartTime = (Get-Process $DetectedExe).StartTime
    while(Get-Process $DetectedExe)
    {
        $CurrentPlayTime = [int16] (New-TimeSpan -Start $ExeStartTime).TotalMinutes
		Set-Itemproperty -path $HWinfoSensorSession -Name 'Value' -value $CurrentPlayTime
        Start-Sleep -s 5
    }
	return $CurrentPlayTime
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
    $CurrentPlayTime = TimeTrackerLoop $DetectedExe
	Remove-Item "$env:TEMP\GG-TrackingGame.txt"

	if ($null -ne $EntityFound)
	{
		Log "Game Already Exists. Updating PlayTime and Last Played Date"
		
		$RecordedGamePlayTime = GetPlayTime $GameName
		$UpdatedPlayTime = $RecordedGamePlayTime + $CurrentPlayTime
		
		UpdateGameOnSession -GameName $GameName -GamePlayTime $UpdatedPlayTime -GameLastPlayDate $UpdatedLastPlayDate
	}
	else
	{
		Log "Game Doesn't Exists. Adding New Game"
		SaveGame -GameName $GameName -GameExeName $DetectedExe -GameIconPath "./icons/default.png" `
				 -GamePlayTime $CurrentPlayTime -GameLastPlayDate $UpdatedLastPlayDate -GameCompleteStatus 'FALSE' -GamePlatform $EmulatedGameDetails.Platform
	}

	RecordPlaytimOnDate($CurrentPlayTime)

	$DatabaseFileHashAfter = CalculateFileHash '.\GamingGaiden.db'
	Log "Database hash after: $DatabaseFileHashAfter"

	if ($DatabaseFileHashAfter -ne $DatabaseFileHashBefore){
        BackupDatabase
    }
}
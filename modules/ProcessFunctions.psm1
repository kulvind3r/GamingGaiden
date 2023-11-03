function DetectGame() {

	Log "Starting game detection"

    $GetRegisteredGameExeQuery = "SELECT exe_name FROM games WHERE completed LIKE 'FALSE'"
	$GetRegisteredEmulatorsExeQuery = "SELECT exe_name FROM emulated_platforms"

    $RegisteredGamesExeList = (Invoke-SqliteQuery -Query $GetRegisteredGameExeQuery -SQLiteConnection $DBConnection).exe_name
	$RegisteredEmulatorsExeList = (Invoke-SqliteQuery -Query $GetRegisteredEmulatorsExeQuery -SQLiteConnection $DBConnection).exe_name

	$ExesToDetect = ( $RegisteredEmulatorsExeList + $RegisteredGamesExeList ) | Select-Object -Unique
	
    $DetectedExe = $null
    do {
        foreach ( $ExeName in $ExesToDetect ){
			if ( $null = Get-Process $ExeName -ErrorAction SilentlyContinue )
			{
				$DetectedExe = $ExeName
				Log "Found $ExeName Running. Exiting Detection"
				break
			}
		}
        Start-Sleep -s 10
    }
    while (-not $DetectedExe)
    
    return $DetectedExe
}

function MonitorGame($DetectedExe, $RecordingNotifyIcon) {

	Log "Starting monitoring for $DetectedExe"

	$EmulatedGameDetails = $null
	$GameName = $null
	$EntityFound = $null
	$UpdatedPlayTime = 0
	$UpdatedLastPlayDate = (Get-Date -UFormat %s).Split('.').Get(0)

	if (IsExeEmulator($DetectedExe))
	{
		$EmulatedGameDetails = findEmulatedGameDetails $DetectedExe
		if ($EmulatedGameDetails -eq $false)
		{
			Log "Something went wrong. Detected Emulated Game's Name was of 0 char length. Exiting Monitoring Loop. Going back to Detection"
			return
		}
		$GameName = $EmulatedGameDetails.Name
		$EntityFound = DoesEntityExists "games" "name" $GameName
	}
	else
	{
		$DetectedExePattern = SQLEscapedMatchPattern($DetectedExe.Trim())
		$GetGameNameQuery = "SELECT name FROM games WHERE exe_name LIKE '{0}'" -f $DetectedExePattern
		$GameName = (Invoke-SqliteQuery -Query $GetGameNameQuery -SQLiteConnection $DBConnection).name
	}
	$RecordingNotifyIcon.Text = "Tracking $GameName"

    $CurrentPlayTime = 0
    while(Get-Process $DetectedExe)
    {
        $CurrentPlayTime = [int16](New-TimeSpan -Start (Get-Process $DetectedExe).StartTime).TotalMinutes
        Start-Sleep -s 10
    }

	if ($null -ne $EntityFound)
	{
		Log "Game Already Exists. Updating PlayTime and Last Played Date"
		
		$RecordedGamePlayTime = GetPlayTime $GameName
		$UpdatedPlayTime = $RecordedGamePlayTime + $CurrentPlayTime

		UpdateGameOnSession -GameName $GameName -GamePlayTime $UpdatedPlayTime -GameLastPlayDate $UpdatedLastPlayDate
	}
	else
	{
		Log "Game Doesn't Exists. Registerting New Game"
		SaveGame -GameName $GameName -GameExeName $DetectedExe -$GameIconPath "./icons/default.png" `
				 -GamePlayTime $UpdatedPlayTime -GameLastPlayDate $UpdatedLastPlayDate -GameCompleteStatus 'FALSE' -GamePlatform $EmulatedGameDetails.Platform
	}
}
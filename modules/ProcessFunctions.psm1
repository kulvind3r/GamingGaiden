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

	$IsEmulatedGame = $null
	$EmulatedGameDetails = $null 
	if (IsExeEmulator($DetectedExe))
	{
		$IsEmulatedGame = $true
		$EmulatedGameDetails = findEmulatedGameDetails $DetectedExe
		if ($EmulatedGameDetails -eq $false)
		{
			Log "Something went wrong. Detected Emulated Game's Name was of 0 char length. Exiting Monitoring Loop. Going back to Detection"
			return
		}
		$RecordingNotifyIcon.Text = ("Tracking {0}" -f $EmulatedGameDetails.Name)
	}
	else
	{
		$DetectedExePattern = SQLEscapedMatchPattern($DetectedExe.Trim())
		$GetGameNameQuery = "SELECT name FROM games WHERE exe_name LIKE '{0}'" -f $DetectedExePattern

		$GameName = (Invoke-SqliteQuery -Query $GetGameNameQuery -SQLiteConnection $DBConnection).name
		$RecordingNotifyIcon.Text = "Tracking $GameName"
	}

    $CurrentPlayTime = 0
    while(Get-Process $DetectedExe)
    {
        $CurrentPlayTime = [int16](New-TimeSpan -Start (Get-Process $DetectedExe).StartTime).TotalMinutes
        Start-Sleep -s 10
    }

	if ($IsEmulatedGame)
	{
		updateEmulatedGame $EmulatedGameDetails $CurrentPlayTime
	}
	else
	{
		updateGame $DetectedExe $CurrentPlayTime
	}
}
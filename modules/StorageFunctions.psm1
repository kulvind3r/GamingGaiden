function RegisterEmulatedGame(){
    param(
        [string]$GameName,
        [string]$GameExeName,
        [string]$GamePlayTime,
        [string]$GameLastPlayDate,
        [string]$GamePlatform
    )

    $GameIconBytes = (Get-Content -Path ".\icons\default.png" -Encoding byte -Raw);

    $RegisterGameQuery = "INSERT INTO GAMES (name, exe_name, icon, play_time, last_play_date, completed, platform)" +
						"VALUES (@GameName, @GameExeName, @GameIconBytes, @GamePlayTime, @GameLastPlayDate, 'FALSE', @GamePlatform)"

	Log "Registering $GameName in Database"
    Invoke-SqliteQuery -Query $RegisterGameQuery -SQLiteConnection $DBConnection -SqlParameters @{
        GameName = $GameName.Trim()
        GameExeName = $GameExeName.Trim()
		GameIconBytes = $GameIconBytes
        GamePlayTime = $GamePlayTime
        GameLastPlayDate = $GameLastPlayDate
        GamePlatform = $GamePlatform.Trim()
    }
}

function updateEmulatedGame($EmulatedGameDetails, $CurrentPlayTime) {
	
	$UpdatedLastPlayDate = (Get-Date -UFormat %s).Split('.').Get(0)
	$GameName = $EmulatedGameDetails.Name

	$GameNamePattern = SQLEscapedMatchPattern($GameName.Trim())

	$GetEmulatedGameDetailsQuery = "SELECT COUNT(*) as '' FROM games WHERE name LIKE '{0}'" -f $GameNamePattern
	$GamesFound = (Invoke-SqliteQuery -Query $GetEmulatedGameDetailsQuery -SQLiteConnection $DBConnection).Column1

	if ($GamesFound -gt 0){
		Log "$GameName is already registered. Updating Play Time and Last Played Date"
		
		$GetGamePlayTimeQuery = "SELECT play_time FROM games WHERE name LIKE '{0}'" -f $GameNamePattern
    	$RecordedGamePlayTime = (Invoke-SqliteQuery -Query $GetGamePlayTimeQuery -SQLiteConnection $DBConnection).play_time

    	$UpdatedPlayTime = $RecordedGamePlayTime + $CurrentPlayTime

		$UpdateGamePlayTimeQuery = "UPDATE games SET play_time = @UpdatedPlayTime, last_play_date = @UpdatedLastPlayDate WHERE name LIKE '{0}'" -f $GameNamePattern

		Invoke-SqliteQuery -Query $UpdateGamePlayTimeQuery -SQLiteConnection $DBConnection -SqlParameters @{ 
			UpdatedPlayTime = $UpdatedPlayTime
			UpdatedLastPlayDate = $UpdatedLastPlayDate
		}		
	}
	else
	{
		Log "$GameName not found. Registering"
		RegisterEmulatedGame -GameName $GameName -GameExeName $EmulatedGameDetails.Exe `
							-GamePlayTime $CurrentPlayTime -GameLastPlayDate $UpdatedLastPlayDate -GamePlatform $EmulatedGameDetails.Platform
	}

}

function updateGame($DetectedExe, $CurrentPlayTime) {
	$DetectedExePattern = SQLEscapedMatchPattern($DetectedExe.Trim())
	$GetGamePlayTimeQuery = "SELECT play_time FROM games WHERE exe_name LIKE '{0}'" -f $DetectedExePattern

    $RecordedGamePlayTime = (Invoke-SqliteQuery -Query $GetGamePlayTimeQuery -SQLiteConnection $DBConnection).play_time

	Log "Found Recorded Play Time of $RecordedGamePlayTime minutes for $DetectedExe Exe. Adding $CurrentPlayTime minutes of current session"

    $UpdatedPlayTime = $RecordedGamePlayTime + $CurrentPlayTime
	$UpdatedLastPlayDate = (Get-Date -UFormat %s).Split('.').Get(0)

    $UpdateGamePlayTimeQuery = "UPDATE games SET play_time = @UpdatedPlayTime, last_play_date = @UpdatedLastPlayDate WHERE exe_name LIKE '{0}'" -f $DetectedExe

    Invoke-SqliteQuery -Query $UpdateGamePlayTimeQuery -SQLiteConnection $DBConnection -SqlParameters @{ 
		UpdatedPlayTime = $UpdatedPlayTime
		UpdatedLastPlayDate = $UpdatedLastPlayDate
	}
}
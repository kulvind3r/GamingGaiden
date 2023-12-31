function SaveGame(){
    param(
        [string]$GameName,
        [string]$GameExeName,
		[string]$GameIconPath,
		[string]$GamePlayTime,
        [string]$GameLastPlayDate,
        [string]$GameCompleteStatus,
        [string]$GamePlatform
    )

    $GameIconBytes = (Get-Content -Path $GameIconPath -Encoding byte -Raw);

    $AddGameQuery = "INSERT INTO games (name, exe_name, icon, play_time, last_play_date, completed, platform)" +
						"VALUES (@GameName, @GameExeName, @GameIconBytes, @GamePlayTime, @GameLastPlayDate, @GameCompleteStatus, @GamePlatform)"

	Log "Adding $GameName in Database"
    RunDBQuery $AddGameQuery @{
        GameName = $GameName.Trim()
        GameExeName = $GameExeName.Trim()
		GameIconBytes = $GameIconBytes
        GamePlayTime = $GamePlayTime
        GameLastPlayDate = $GameLastPlayDate
        GameCompleteStatus = $GameCompleteStatus
        GamePlatform = $GamePlatform.Trim()
    }
}

function SavePlatform(){
    param(
        [string]$PlatformName,
        [string]$EmulatorExeName,
		[string]$CoreName,
		[string]$RomExtensions
    )

    $AddPlatformQuery = "INSERT INTO emulated_platforms (name, exe_name, core, rom_extensions)" +
                                    "VALUES (@PlatformName, @EmulatorExeName, @CoreName, @RomExtensions)"

    Log "Adding $PlatformName in Database"
    RunDBQuery $AddPlatformQuery @{
        PlatformName = $PlatformName.Trim()
        EmulatorExeName = $EmulatorExeName.Trim()
        CoreName = $CoreName.Trim()
        RomExtensions = $RomExtensions.Trim()
    }
}

function UpdateGameOnSession() {
	param(
        [string]$GameName,
        [string]$GamePlayTime,
        [string]$GameLastPlayDate
    )

	$GameNamePattern = SQLEscapedMatchPattern($GameName.Trim())

	$UpdateGamePlayTimeQuery = "UPDATE games SET play_time = @UpdatedPlayTime, last_play_date = @UpdatedLastPlayDate WHERE name LIKE '{0}'" -f $GameNamePattern

    Log "Updating $GameName playtime to $GamePlayTime in database"
	RunDBQuery $UpdateGamePlayTimeQuery @{ 
		UpdatedPlayTime = $GamePlayTime
		UpdatedLastPlayDate = $GameLastPlayDate
	}
}

function UpdateGameOnEdit() {
    param(
        [string]$GameName,
        [string]$GameExeName,
		[string]$GameIconPath,
		[string]$GamePlayTime,
        [string]$GameCompleteStatus,
        [string]$GamePlatform
    )

    $GameIconBytes = (Get-Content -Path $GameIconPath -Encoding byte -Raw);

	$GameNamePattern = SQLEscapedMatchPattern($GameName.Trim())

	$UpdateGameQuery = "UPDATE games SET exe_name = @GameExeName, icon = @GameIconBytes, play_time = @GamePlayTime, completed = @GameCompleteStatus, platform = @GamePlatform WHERE name LIKE '{0}'" -f $GameNamePattern

    Log "Editing $GameName in database"
	RunDBQuery $UpdateGameQuery @{
        GameExeName = $GameExeName.Trim()
		GameIconBytes = $GameIconBytes
        GamePlayTime = $GamePlayTime
        GameCompleteStatus = $GameCompleteStatus
        GamePlatform = $GamePlatform.Trim()
	}
}

function  UpdatePlatformOnEdit() {
    param(
        [string]$PlatformName,
        [string]$EmulatorExeName,
		[string]$EmulatorCore,
		[string]$PlatformRomExtensions
    )

	$PlatformNamePattern = SQLEscapedMatchPattern($PlatformName.Trim())

    $UpdatePlatformQuery = "UPDATE emulated_platforms set exe_name = @EmulatorExeName, core = @EmulatorCore, rom_extensions = @PlatformRomExtensions WHERE name LIKE '{0}'" -f $PlatformNamePattern

    Log "Editing $GameName in database"
	RunDBQuery $UpdatePlatformQuery @{
        EmulatorExeName = $EmulatorExeName
		EmulatorCore = $EmulatorCore
        PlatformRomExtensions = $PlatformRomExtensions.Trim()
	}
}

function RemoveGame($GameName) {
    $GameNamePattern = SQLEscapedMatchPattern($GameName.Trim())
    $RemoveGameQuery = "DELETE FROM games WHERE name LIKE '{0}'" -f $GameNamePattern

    Log "Removing $GameName from database"
    RunDBQuery $RemoveGameQuery
}

function RemovePlatform($PlatformName) {
    $PlatformNamePattern = SQLEscapedMatchPattern($PlatformName.Trim())
    $RemovePlatformQuery = "DELETE FROM emulated_platforms WHERE name LIKE '{0}'" -f $PlatformNamePattern

    Log "Removing $PlatformName from database"
    RunDBQuery $RemovePlatformQuery
}

function RecordPlaytimOnDate($PlayTime) {
    $ExistingPlayTimeQuery = "SELECT play_time FROM daily_playtime WHERE play_date like DATE('now')"

    $ExistingPlayTime = (RunDBQuery $ExistingPlayTimeQuery).play_time
    
    $RecordPlayTimeQuery = ""
    if ($null -eq $ExistingPlayTime)
    {
        $RecordPlayTimeQuery = "INSERT INTO daily_playtime(play_date, play_time) VALUES (DATE('now'), {0})" -f $PlayTime
    }
    else
    {
        $UpdatedPlayTime = $PlayTime + $ExistingPlayTime

        $RecordPlayTimeQuery = "UPDATE daily_playtime SET play_time = {0} WHERE play_date like DATE('now')" -f $UpdatedPlayTime
    }

    Log "Updating playTime for today in database"
    RunDBQuery $RecordPlayTimeQuery
}
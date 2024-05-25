function SaveGame() {
    param(
        [string]$GameName,
        [string]$GameExeName,
        [string]$GameIconPath,
        [string]$GamePlayTime,
        [string]$GameIdleTime,
        [string]$GameLastPlayDate,
        [string]$GameCompleteStatus,
        [string]$GamePlatform,
        [string]$GameSessionCount,
        [string]$GameRomBasedName = ""
    )

    $gameIconBytes = (Get-Content -Path $GameIconPath -Encoding byte -Raw);

    $addGameQuery = "INSERT INTO games (name, exe_name, icon, play_time, idle_time, last_play_date, completed, platform, session_count, rom_based_name)" +
    "VALUES (@GameName, @GameExeName, @gameIconBytes, @GamePlayTime, @GameIdleTime, @GameLastPlayDate, @GameCompleteStatus, @GamePlatform, @GameSessionCount, @GameRomBasedName)"

    Log "Adding $GameName in Database"

    # Forced to repeat complete RunDBQuery command twice in if/else because the following code doesn't work.
    #
    #    $var = $GameRomBasedName.Trim()
    #    if ($GameRomBasedName -eq "") {
    #       $var = [System.DBNull]::Value
    #    } 
    #    RunDBQuery $addGameQuery @{ ..., GameRomBasedName = $var }
    #
    # On using the above code, [System.DBNull]::Value gets casted to string for some reason and gets inserted in DB as blank string instead of a true NULL. 
    
    if ($GameRomBasedName -eq "") {
        RunDBQuery $addGameQuery @{
            GameName           = $GameName.Trim()
            GameExeName        = $GameExeName.Trim()
            gameIconBytes      = $gameIconBytes
            GamePlayTime       = $GamePlayTime
            GameIdleTime       = $GameIdleTime
            GameLastPlayDate   = $GameLastPlayDate
            GameCompleteStatus = $GameCompleteStatus
            GamePlatform       = $GamePlatform.Trim()
            GameSessionCount   = $GameSessionCount
            GameRomBasedName   = [System.DBNull]::Value
        }
    }
    else {
        RunDBQuery $addGameQuery @{
            GameName           = $GameName.Trim()
            GameExeName        = $GameExeName.Trim()
            gameIconBytes      = $gameIconBytes
            GamePlayTime       = $GamePlayTime
            GameIdleTime       = $GameIdleTime
            GameLastPlayDate   = $GameLastPlayDate
            GameCompleteStatus = $GameCompleteStatus
            GamePlatform       = $GamePlatform.Trim()
            GameSessionCount   = $GameSessionCount
            GameRomBasedName   = $GameRomBasedName.Trim()
        }
    }
}

function SavePlatform() {
    param(
        [string]$PlatformName,
        [string]$EmulatorExeList,
        [string]$CoreName,
        [string]$RomExtensions
    )

    $addPlatformQuery = "INSERT INTO emulated_platforms (name, exe_name, core, rom_extensions)" +
    "VALUES (@PlatformName, @EmulatorExeList, @CoreName, @RomExtensions)"

    Log "Adding $PlatformName in database"
    RunDBQuery $addPlatformQuery @{
        PlatformName    = $PlatformName.Trim()
        EmulatorExeList = $EmulatorExeList.Trim()
        CoreName        = $CoreName.Trim()
        RomExtensions   = $RomExtensions.Trim()
    }
}

function UpdateGameOnSession() {
    param(
        [string]$GameName,
        [string]$GamePlayTime,
        [string]$GameIdleTime,
        [string]$GameLastPlayDate
    )

    $gameNamePattern = SQLEscapedMatchPattern($GameName.Trim())

    $getSessionCountQuery = "SELECT session_count FROM games WHERE name LIKE '{0}'" -f $gameNamePattern
    $currentSessionCount = (RunDBQuery $getSessionCountQuery).session_count

    $newSessionCount = $currentSessionCount + 1

    $updateGamePlayTimeQuery = "UPDATE games SET play_time = @UpdatedPlayTime, idle_time = @UpdatedIdleTime, last_play_date = @UpdatedLastPlayDate, session_count = @newSessionCount WHERE name LIKE '{0}'" -f $gameNamePattern

    Log "Updating $GameName play time to $GamePlayTime min and idle time to $GameIdleTime min in database"
    Log "Updating session count from $currentSessionCount to $newSessionCount in database"

    RunDBQuery $updateGamePlayTimeQuery @{ 
        UpdatedPlayTime     = $GamePlayTime
        UpdatedIdleTime     = $GameIdleTime
        UpdatedLastPlayDate = $GameLastPlayDate
        newSessionCount     = $newSessionCount
    }
}

function UpdateGameOnEdit() {
    param(
        [string]$OriginalGameName,
        [string]$GameName,
        [string]$GameExeName,
        [string]$GameIconPath,
        [string]$GamePlayTime,
        [string]$GameCompleteStatus,
        [string]$GamePlatform
    )

    $gameIconBytes = (Get-Content -Path $GameIconPath -Encoding byte -Raw);

    $gameNamePattern = SQLEscapedMatchPattern($OriginalGameName.Trim())

    if ( $OriginalGameName -eq $GameName) {
        $updateGameQuery = "UPDATE games SET exe_name = @GameExeName, icon = @gameIconBytes, play_time = @GamePlayTime, completed = @GameCompleteStatus, platform = @GamePlatform WHERE name LIKE '{0}'" -f $gameNamePattern
        
        Log "Editing $GameName in database"
        RunDBQuery $updateGameQuery @{
            GameExeName        = $GameExeName.Trim()
            gameIconBytes      = $gameIconBytes
            GamePlayTime       = $GamePlayTime
            GameCompleteStatus = $GameCompleteStatus
            GamePlatform       = $GamePlatform.Trim()
        }
    }
    else {
        Log "User changed game's name from $OriginalGameName to $GameName. Need to delete the game and add it again"

        $getSessionCountQuery = "SELECT session_count FROM games WHERE name LIKE '{0}'" -f $gameNamePattern
        $gameSessionCount = (RunDBQuery $getSessionCountQuery).session_count

        $getIdleTimeQuery = "SELECT idle_time FROM games WHERE name LIKE '{0}'" -f $gameNamePattern
        $gameIdleTime = (RunDBQuery $getIdleTimeQuery).idle_time

        $getLastPlayDateQuery = "SELECT last_play_date FROM games WHERE name LIKE '{0}'" -f $gameNamePattern
        $gameLastPlayDate = (RunDBQuery $getLastPlayDateQuery).last_play_date

        if (IsExeEmulator $GameExeName) {
            $getRomBasedNameQuery = "SELECT rom_based_name FROM games WHERE name LIKE '{0}'" -f $gameNamePattern
            $romBasedName = (RunDBQuery $getRomBasedNameQuery).rom_based_name

            SaveGame -GameName $GameName -GameExeName $GameExeName -GameIconPath $GameIconPath `
            -GamePlayTime $GamePlayTime -GameIdleTime $gameIdleTime -GameLastPlayDate $gameLastPlayDate -GameCompleteStatus $GameCompleteStatus -GamePlatform $GamePlatform -GameSessionCount $gameSessionCount -GameRomBasedName $romBasedName
        } else {
            SaveGame -GameName $GameName -GameExeName $GameExeName -GameIconPath $GameIconPath `
            -GamePlayTime $GamePlayTime -GameIdleTime $gameIdleTime -GameLastPlayDate $gameLastPlayDate -GameCompleteStatus $GameCompleteStatus -GamePlatform $GamePlatform -GameSessionCount $gameSessionCount
        }

        RemoveGame($OriginalGameName)
    }
}
 
function  UpdatePlatformOnEdit() {
    param(
        [string]$OriginalPlatformName,
        [string]$PlatformName,
        [string]$EmulatorExeList,
        [string]$EmulatorCore,
        [string]$PlatformRomExtensions
    )

    $platformNamePattern = SQLEscapedMatchPattern($OriginalPlatformName.Trim())

    if ( $OriginalPlatformName -eq $PlatformName) {

        $updatePlatformQuery = "UPDATE emulated_platforms set exe_name = @EmulatorExeList, core = @EmulatorCore, rom_extensions = @PlatformRomExtensions WHERE name LIKE '{0}'" -f $platformNamePattern

        Log "Editing $PlatformName in database"
        RunDBQuery $updatePlatformQuery @{
            EmulatorExeList       = $EmulatorExeList
            EmulatorCore          = $EmulatorCore
            PlatformRomExtensions = $PlatformRomExtensions.Trim()
        }
    }
    else {
        Log "User changed platform's name from $OriginalPlatformName to $PlatformName. Need to delete the platform and add it again"
        Log "All games mapped to $OriginalPlatformName will be updated to platform $PlatformName"

        RemovePlatform($OriginalPlatformName)

        SavePlatform -PlatformName $PlatformName -EmulatorExeList $EmulatorExeList -CoreName $EmulatorCore -RomExtensions $PlatformRomExtensions

        $updateGamesPlatformQuery = "UPDATE games SET platform = @PlatformName WHERE platform LIKE '{0}'" -f $platformNamePattern

        RunDBQuery $updateGamesPlatformQuery @{ PlatformName = $PlatformName }
    }
}

function RemoveGame($GameName) {
    $gameNamePattern = SQLEscapedMatchPattern($GameName.Trim())
    $removeGameQuery = "DELETE FROM games WHERE name LIKE '{0}'" -f $gameNamePattern

    Log "Removing $GameName from database"
    RunDBQuery $removeGameQuery
}

function RemovePlatform($PlatformName) {
    $platformNamePattern = SQLEscapedMatchPattern($PlatformName.Trim())
    $removePlatformQuery = "DELETE FROM emulated_platforms WHERE name LIKE '{0}'" -f $platformNamePattern

    Log "Removing $PlatformName from database"
    RunDBQuery $removePlatformQuery
}

function RecordPlaytimOnDate($PlayTime) {
    $existingPlayTimeQuery = "SELECT play_time FROM daily_playtime WHERE play_date like DATE('now')"

    $existingPlayTime = (RunDBQuery $existingPlayTimeQuery).play_time
    
    $recordPlayTimeQuery = ""
    if ($null -eq $existingPlayTime) {
        $recordPlayTimeQuery = "INSERT INTO daily_playtime(play_date, play_time) VALUES (DATE('now'), {0})" -f $PlayTime
    }
    else {
        $updatedPlayTime = $PlayTime + $existingPlayTime

        $recordPlayTimeQuery = "UPDATE daily_playtime SET play_time = {0} WHERE play_date like DATE('now')" -f $updatedPlayTime
    }

    Log "Updating playTime for today in database"
    RunDBQuery $recordPlayTimeQuery
}
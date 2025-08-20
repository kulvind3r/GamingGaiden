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
        [string]$GameStatus = "",
        [string]$GameRomBasedName = "",
        [bool]$GameDisableIdleDetection = $false
    )

    $gameIconBytes = (Get-Content -Path $GameIconPath -Encoding byte -Raw);
    $gameIconColor = Get-DominantColor $gameIconBytes

    $addGameQuery = "INSERT INTO games (name, exe_name, icon, play_time, idle_time, last_play_date, completed, platform, session_count, status, rom_based_name, color_hex, disable_idle_detection)" +
    "VALUES (@GameName, @GameExeName, @gameIconBytes, @GamePlayTime, @GameIdleTime, @GameLastPlayDate, @GameCompleteStatus, @GamePlatform, @GameSessionCount, @GameStatus, @GameRomBasedName, @GameIconColor, @GameDisableIdleDetection)"

    $gameNamePattern = SQLEscapedMatchPattern($GameName.Trim())
    $setGameStatusNull = "UPDATE games SET status = @GameStatus WHERE name LIKE '{0}'" -f $gameNamePattern
    $setRomBasedNameNull = "UPDATE games SET rom_based_name = @GameRomBasedName WHERE name LIKE '{0}'" -f $gameNamePattern

    Log "Adding $GameName in Database"

    RunDBQuery $addGameQuery @{
        GameName                 = $GameName.Trim()
        GameExeName              = $GameExeName.Trim()
        gameIconBytes            = $gameIconBytes
        GamePlayTime             = $GamePlayTime
        GameIdleTime             = $GameIdleTime
        GameLastPlayDate         = $GameLastPlayDate
        GameCompleteStatus       = $GameCompleteStatus
        GamePlatform             = $GamePlatform.Trim()
        GameSessionCount         = $GameSessionCount
        GameStatus               = $GameStatus
        GameRomBasedName         = $GameRomBasedName.Trim()
        GameIconColor            = $gameIconColor
        GameDisableIdleDetection = $GameDisableIdleDetection
    }

    # Have to set Null Values after the Save for clean code, bcause the following doesn't work
    #
    #    $var = $GameRomBasedName.Trim()
    #    if ($GameRomBasedName -eq "") {
    #       $var = [System.DBNull]::Value
    #    }
    #    RunDBQuery $addGameQuery @{ ..., GameRomBasedName = $var }
    #
    # On using the above code, [System.DBNull]::Value gets casted to string for some reason and gets inserted in DB as blank string instead of a true NULL.
    
    if ($GameRomBasedName -eq "") {
        RunDBQuery $setRomBasedNameNull @{
            GameRomBasedName = [System.DBNull]::Value
        }
    }

    if ($GameStatus -eq "") {
        RunDBQuery $setGameStatusNull @{
            GameStatus = [System.DBNull]::Value
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

function SavePC() {
    param(
        [string]$PCName,
        [string]$PCIconPath,
        [string]$PCCost,
        [string]$PCCurrency,
        [string]$PCStartDate,
        [string]$PCEndDate,
        [string]$PCCurrentStatus
    )

    $PCIconBytes = (Get-Content -Path $PCIconPath -Encoding byte -Raw);

    $addPCQuery = "INSERT INTO gaming_pcs (name, icon, cost, currency, start_date, end_date, current)" +
    "VALUES (@PCName, @PCIconBytes, @PCCost, @PCCurrency, @PCStartDate, @PCEndDate, @PCCurrentStatus)"

    Log "Adding PC $PCName in database"
    RunDBQuery $addPCQuery @{
        PCName          = $PCName.Trim()
        PCIconBytes     = $PCIconBytes
        PCCost          = $PCCost.Trim()
        PCCurrency      = $PCCurrency.Trim()
        PCStartDate     = $PCStartDate
        PCEndDate       = $PCEndDate
        PCCurrentStatus = $PCCurrentStatus
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
        [string]$GamePlatform,
        [string]$GameStatus,
        [bool]$GameDisableIdleDetection
    )

    $gameIconBytes = (Get-Content -Path $GameIconPath -Encoding byte -Raw);
    $gameIconColor = Get-DominantColor $gameIconBytes

    $gameNamePattern = SQLEscapedMatchPattern($OriginalGameName.Trim())

    if ( $OriginalGameName -eq $GameName) {
        $updateGameQuery = "UPDATE games SET exe_name = @GameExeName, icon = @gameIconBytes, play_time = @GamePlayTime, completed = @GameCompleteStatus, platform = @GamePlatform, status = @GameStatus, color_hex = @GameIconColor, disable_idle_detection = @GameDisableIdleDetection WHERE name LIKE '{0}'" -f $gameNamePattern

        Log "Editing $GameName in database"
        RunDBQuery $updateGameQuery @{
            GameExeName              = $GameExeName.Trim()
            gameIconBytes            = $gameIconBytes
            GamePlayTime             = $GamePlayTime
            GameCompleteStatus       = $GameCompleteStatus
            GamePlatform             = $GamePlatform.Trim()
            GameStatus               = $GameStatus
            GameIconColor            = $gameIconColor
            GameDisableIdleDetection = $GameDisableIdleDetection
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
                -GamePlayTime $GamePlayTime -GameIdleTime $gameIdleTime -GameLastPlayDate $gameLastPlayDate -GameCompleteStatus $GameCompleteStatus -GamePlatform $GamePlatform -GameSessionCount $gameSessionCount -GameStatus $GameStatus -GameRomBasedName $romBasedName -GameDisableIdleDetection $GameDisableIdleDetection
        }
        else {
            SaveGame -GameName $GameName -GameExeName $GameExeName -GameIconPath $GameIconPath `
                -GamePlayTime $GamePlayTime -GameIdleTime $gameIdleTime -GameLastPlayDate $gameLastPlayDate -GameCompleteStatus $GameCompleteStatus -GamePlatform $GamePlatform -GameSessionCount $gameSessionCount -GameStatus $GameStatus -GameDisableIdleDetection $GameDisableIdleDetection
        }

        RemoveGame($OriginalGameName)
    }
}

function UpdatePC() {
    param(
        [string]$AddNew = $false,
        [string]$OriginalPCName,
        [string]$PCName,
        [string]$PCIconPath,
        [string]$PCCost,
        [string]$PCCurrency,
        [string]$PCStartDate,
        [string]$PCEndDate,
        [string]$PCCurrentStatus
    )
    
    $PCNamePattern = SQLEscapedMatchPattern($OriginalPCName.Trim())

    if ($AddNew -eq $true) {
        SavePC -PCName $PCName -PCIconPath $PCIconPath -PCCost $PCCost -PCCurrency $PCCurrency -PCStartDate $PCStartDate -PCEndDate $PCEndDate -PCCurrentStatus $PCCurrentStatus
        return
    }

    if ($OriginalPCName -eq $PCName) {

        $PCIconBytes = (Get-Content -Path $PCIconPath -Encoding byte -Raw);
        
        $updatePCQuery = "UPDATE gaming_pcs SET icon = @PCIconBytes, cost = @PCCost, currency = @PCCurrency, start_date = @PCStartDate, end_date = @PCEndDate, current = @PCCurrentStatus WHERE name LIKE '{0}'" -f $PCNamePattern

        Log "Updating PC $PCName in database"
        RunDBQuery $updatePCQuery @{
            PCIconBytes     = $PCIconBytes
            PCCost          = $PCCost
            PCCurrency      = $PCCurrency
            PCStartDate     = $PCStartDate
            PCEndDate       = $PCEndDate
            PCCurrentStatus = $PCCurrentStatus
        }
    }
    else {
        Log "User changed PC's name from $OriginalPCName to $PCName. Need to delete the PC and add it again"
        RemovePC $OriginalPCName
        SavePC -PCName $PCName -PCIconPath $PCIconPath -PCCost $PCCost -PCCurrency $PCCurrency -PCStartDate $PCStartDate -PCEndDate $PCEndDate -PCCurrentStatus $PCCurrentStatus
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

function RemovePC($PCName) {
    $PCNamePattern = SQLEscapedMatchPattern($PCName.Trim())
    $removePCQuery = "DELETE FROM gaming_pcs WHERE name LIKE '{0}'" -f $PCNamePattern

    Log "Removing PC $PCName from database"
    RunDBQuery $removePCQuery
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

function RecordSessionHistory() {
    param(
        [string]$GameName,
        [datetime]$SessionStartTime,
        [int]$SessionDuration
    )

    $gameNamePattern = SQLEscapedMatchPattern($GameName.Trim())
    $sessionStartTimeUnix = (Get-Date $SessionStartTime -UFormat %s).Split('.')[0]

    $insertSessionQuery = "INSERT INTO session_history (game_name, session_start_time, session_duration_minutes) VALUES (@GameName, @SessionStartTime, @SessionDuration)"

    Log "Recording session history for $GameName"
    RunDBQuery $insertSessionQuery @{
        GameName         = $GameName
        SessionStartTime = $sessionStartTimeUnix
        SessionDuration  = $SessionDuration
    }
}
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
        [string]$GameGamingPCName = ""
    )

    $gameIconBytes = (Get-Content -Path $GameIconPath -Encoding byte -Raw);

    $addGameQuery = "INSERT INTO games (name, exe_name, icon, play_time, idle_time, last_play_date, completed, platform, session_count, status, rom_based_name, gaming_pc_name)" +
    "VALUES (@GameName, @GameExeName, @gameIconBytes, @GamePlayTime, @GameIdleTime, @GameLastPlayDate, @GameCompleteStatus, @GamePlatform, @GameSessionCount, @GameStatus, @GameRomBasedName, @GameGamingPCName)"

    $gameNamePattern = SQLEscapedMatchPattern($GameName.Trim())
    $setGameStatusNull = "UPDATE games SET status = @GameStatus WHERE name LIKE '{0}'" -f $gameNamePattern
    $setRomBasedNameNull = "UPDATE games SET rom_based_name = @GameRomBasedName WHERE name LIKE '{0}'" -f $gameNamePattern
    $setGamingPCNameNull = "UPDATE games SET gaming_pc_name = @GameGamingPCName WHERE name LIKE '{0}'" -f $gameNamePattern

    Log "Adding $GameName in Database"

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
        GameStatus         = $GameStatus
        GameRomBasedName   = $GameRomBasedName.Trim()
        GameGamingPCName   = $GameGamingPCName.Trim()
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

    if ($GameGamingPCName -eq "") {
        RunDBQuery $setGamingPCNameNull @{
            GameGamingPCName = [System.DBNull]::Value
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
        [string]$PCCurrentStatus,
        [int]$PCTotalPlaytime = 0
    )

    $PCIconBytes = (Get-Content -Path $PCIconPath -Encoding byte -Raw);

    $addPCQuery = "INSERT INTO gaming_pcs (name, icon, cost, currency, start_date, end_date, in_use, total_play_time)" +
    "VALUES (@PCName, @PCIconBytes, @PCCost, @PCCurrency, @PCStartDate, @PCEndDate, @PCCurrentStatus, @PCTotalPlaytime)"

    Log "Adding PC $PCName in database"
    RunDBQuery $addPCQuery @{
        PCName          = $PCName.Trim()
        PCIconBytes     = $PCIconBytes
        PCCost          = $PCCost.Trim()
        PCCurrency      = $PCCurrency.Trim()
        PCStartDate     = $PCStartDate
        PCEndDate       = $PCEndDate
        PCCurrentStatus = $PCCurrentStatus
        PCTotalPlaytime = $PCTotalPlaytime
    }
}

function UpdateGameOnSession() {
    param(
        [string]$GameName,
        [string]$GamePlayTime,
        [string]$GameIdleTime,
        [string]$GameLastPlayDate,
        [string]$GameGamingPCName = ""
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

    if (-not [string]::IsNullOrEmpty($GameGamingPCName)) {
        Log "Updating gaming PC list to: $GameGamingPCName"
        $updateGamePCQuery = "UPDATE games SET gaming_pc_name = @GameGamingPCName WHERE name LIKE '{0}'" -f $gameNamePattern
        RunDBQuery $updateGamePCQuery @{
            GameGamingPCName    = $GameGamingPCName
        }
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
        [string]$GameGamingPCName = ""
    )

    $gameIconBytes = (Get-Content -Path $GameIconPath -Encoding byte -Raw);

    $gameNamePattern = SQLEscapedMatchPattern($OriginalGameName.Trim())

    if ( $OriginalGameName -eq $GameName) {
        $updateGameQuery = "UPDATE games SET exe_name = @GameExeName, icon = @gameIconBytes, play_time = @GamePlayTime, completed = @GameCompleteStatus, platform = @GamePlatform, status = @GameStatus, gaming_pc_name = @GameGamingPCName WHERE name LIKE '{0}'" -f $gameNamePattern
        
        $setGamingPCNameNull = "UPDATE games SET gaming_pc_name = @GameGamingPCName WHERE name LIKE '{0}'" -f $gameNamePattern

        Log "Editing $GameName in database"
        RunDBQuery $updateGameQuery @{
            GameExeName        = $GameExeName.Trim()
            gameIconBytes      = $gameIconBytes
            GamePlayTime       = $GamePlayTime
            GameCompleteStatus = $GameCompleteStatus
            GamePlatform       = $GamePlatform.Trim()
            GameStatus         = $GameStatus
            GameGamingPCName   = $GameGamingPCName.Trim()
        }

        if ($GameGamingPCName -eq "") {
            RunDBQuery $setGamingPCNameNull @{
                GameGamingPCName = [System.DBNull]::Value
            }
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
                -GamePlayTime $GamePlayTime -GameIdleTime $gameIdleTime -GameLastPlayDate $gameLastPlayDate -GameCompleteStatus $GameCompleteStatus -GamePlatform $GamePlatform -GameSessionCount $gameSessionCount -GameStatus $GameStatus -GameRomBasedName $romBasedName -GameGamingPCName $GameGamingPCName
        }
        else {
            SaveGame -GameName $GameName -GameExeName $GameExeName -GameIconPath $GameIconPath `
                -GamePlayTime $GamePlayTime -GameIdleTime $gameIdleTime -GameLastPlayDate $gameLastPlayDate -GameCompleteStatus $GameCompleteStatus -GamePlatform $GamePlatform -GameSessionCount $gameSessionCount -GameStatus $GameStatus -GameGamingPCName $GameGamingPCName
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
        [string]$PCCurrentStatus,
        [int]$PCTotalPlaytime = 0
    )

    $PCNamePattern = SQLEscapedMatchPattern($OriginalPCName.Trim())

    if ($AddNew -eq $true) {
        SavePC -PCName $PCName -PCIconPath $PCIconPath -PCCost $PCCost -PCCurrency $PCCurrency -PCStartDate $PCStartDate -PCEndDate $PCEndDate -PCCurrentStatus $PCCurrentStatus -PCTotalPlaytime $PCTotalPlaytime
        return
    }

    if ($OriginalPCName -eq $PCName) {

        $PCIconBytes = (Get-Content -Path $PCIconPath -Encoding byte -Raw);

        $updatePCQuery = "UPDATE gaming_pcs SET icon = @PCIconBytes, cost = @PCCost, currency = @PCCurrency, start_date = @PCStartDate, end_date = @PCEndDate, in_use = @PCCurrentStatus, total_play_time = @PCTotalPlaytime WHERE name LIKE '{0}'" -f $PCNamePattern

        Log "Updating PC $PCName in database"
        RunDBQuery $updatePCQuery @{
            PCIconBytes     = $PCIconBytes
            PCCost          = $PCCost
            PCCurrency      = $PCCurrency
            PCStartDate     = $PCStartDate
            PCEndDate       = $PCEndDate
            PCCurrentStatus = $PCCurrentStatus
            PCTotalPlaytime = $PCTotalPlaytime
        }
    }
    else {
        Log "User changed PC's name from $OriginalPCName to $PCName. Need to delete the PC and add it again"
        RemovePC $OriginalPCName
        SavePC -PCName $PCName -PCIconPath $PCIconPath -PCCost $PCCost -PCCurrency $PCCurrency -PCStartDate $PCStartDate -PCEndDate $PCEndDate -PCCurrentStatus $PCCurrentStatus -PCTotalPlaytime $PCTotalPlaytime
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

function RecordSessionHistory($GameName, $StartTime, $Duration) {
    Log "Recording session history for $GameName - Start: $StartTime, Duration: $Duration min"

    $insertQuery = @"
INSERT INTO session_history (game_name, start_time, duration)
VALUES (@GameName, @StartTime, @Duration)
"@

    $parameters = @{
        GameName = $GameName
        StartTime = $StartTime
        Duration = $Duration
    }

    try {
        RunDBQuery $insertQuery $parameters
        Log "Session history recorded successfully"
    }
    catch {
        Log "Error recording session history: $($_.Exception.Message)"
    }
}

function Read-Setting($Key) {
    $settingsPath = ".\settings.ini"

    if (-Not (Test-Path $settingsPath)) {
        Log "Settings file not found at $settingsPath"
        return $null
    }

    $content = Get-Content -Path $settingsPath -Raw
    $pattern = "(?m)^$Key\s*=\s*(.+)$"

    if ($content -match $pattern) {
        return $Matches[1].Trim()
    }

    return $null
}

function Write-Setting($Key, $Value) {
    $settingsPath = ".\settings.ini"

    if (-Not (Test-Path $settingsPath)) {
        New-Item -Path $settingsPath -ItemType File -Force | Out-Null
        Log "Created settings file at $settingsPath"
    }

    $content = Get-Content -Path $settingsPath -Raw
    $pattern = "(?m)^$Key\s*=\s*.+$"

    if ($content -match $pattern) {
        $newContent = $content -replace $pattern, "$Key=$Value"
    }
    else {
        $newContent = $content + "$Key=$Value`n"
    }

    Set-Content -Path $settingsPath -Value $newContent -Force
    Log "Setting updated: $Key=$Value"
}

function UpdatePCPlaytime($PCName, $DurationMinutes) {
    if ([string]::IsNullOrEmpty($PCName)) {
        return
    }

    $updateQuery = "UPDATE gaming_pcs SET total_play_time = total_play_time + @Duration WHERE name = @PCName"

    Log "Updating PC $PCName playtime by $DurationMinutes minutes"
    RunDBQuery $updateQuery @{
        Duration = $DurationMinutes
        PCName = $PCName
    }
}
function IsExeEmulator($DetectedExe) {	
    Log "Is $DetectedExe is an Emulator?"

    $pattern = SQLEscapedMatchPattern $DetectedExe.Trim()
    $findExeQuery = "SELECT COUNT(*) as '' FROM emulated_platforms WHERE exe_name LIKE '%{0}%'" -f $pattern

    $exesFound = (RunDBQuery $findExeQuery).Column1

    Log ("Check result: {0}" -f ($exesFound -gt 0))
    return ($exesFound -gt 0)
}

function DoesEntityExists($Table, $Column, $EntityName) {
    Log "Does $EntityName exists in $Table ?"

    $entityNamePattern = SQLEscapedMatchPattern($EntityName.Trim())
    $validateEntityQuery = "SELECT * FROM {0} WHERE {1} LIKE '{2}'" -f $Table, $Column, $entityNamePattern

    $entityFound = RunDBQuery $validateEntityQuery

    Log "Discovered entity: $entityFound"
    return $entityFound
}

function CheckExeCoreCombo($ExeList, $Core) {
    Log "Is $ExeList already registered with $Core?"

    $exeListPattern = SQLEscapedMatchPattern($ExeList.Trim())
    $coreNamePattern = SQLEscapedMatchPattern($Core.Trim())
    $validateEntityQuery = "SELECT * FROM emulated_platforms WHERE exe_name LIKE '%{0}%' AND core LIKE '{1}'" -f $exeListPattern, $coreNamePattern

    $entityFound = RunDBQuery $validateEntityQuery

    Log "Detected exe core Combo: $entityFound"
    return $entityFound
}

function GetPlayTime($GameName) {
    Log "Get existing gameplay time for $GameName"

    $gameNamePattern = SQLEscapedMatchPattern($GameName.Trim())
    $getGamePlayTimeQuery = "SELECT play_time FROM games WHERE name LIKE '{0}'" -f $gameNamePattern

    $recordedGamePlayTime = (RunDBQuery $getGamePlayTimeQuery).play_time

    Log "Detected gameplay time: $recordedGamePlayTime min"
    return $recordedGamePlayTime
}

function GetIdleTime($GameName) {
    Log "Get existing game idle time for $GameName"

    $gameNamePattern = SQLEscapedMatchPattern($GameName.Trim())
    $getGameIdleTimeQuery = "SELECT idle_time FROM games WHERE name LIKE '{0}'" -f $gameNamePattern

    $recordedGameIdleTime = (RunDBQuery $getGameIdleTimeQuery).idle_time

    Log "Detected game idle time: $recordedGameIdleTime min"
    return $recordedGameIdleTime
}

function findEmulatedGame($DetectedEmulatorExe, $EmulatorCommandLine) {
    Log "Finding emulated game for $DetectedEmulatorExe"

    $pattern = SQLEscapedMatchPattern $DetectedEmulatorExe.Trim()
    $getRomExtensionsQuery = "SELECT rom_extensions FROM emulated_platforms WHERE exe_name LIKE '%{0}%'" -f $pattern
    $romExtensions = (RunDBQuery $getromExtensionsQuery).rom_extensions.Split(',')

    $romName = $null
    foreach ($romExtension in $romExtensions) {
        $romName = [System.Text.RegularExpressions.Regex]::Match($EmulatorCommandLine, "[^\\]*\.$romExtension").Value

        if ($romName -ne "") {
            $romName = $romName -replace ".$romExtension", ""
            break 
        }
    }

    $emulatedGame = [regex]::Replace($romName, '\([^)]*\)|\[[^\]]*\]', "")

    Log ("Detected game: {0}" -f $emulatedGame.Trim())
    return $emulatedGame.Trim()
}

function findEmulatedGameCore($DetectedEmulatorExe, $EmulatorCommandLine) {
    Log "Finding core in use by $DetectedEmulatorExe"

    $pattern = SQLEscapedMatchPattern $DetectedEmulatorExe.Trim()
    $getCoresQuery = "SELECT core FROM emulated_platforms WHERE exe_name LIKE '%{0}%'" -f $pattern
    $coreName = $null
    $cores = (RunDBQuery $getCoresQuery).core
    if ( $cores.Length -le 1) {
        $coreName = $cores[0]
    }
    else {
        foreach ($core in $cores) {
            if ($EmulatorCommandLine.Contains($core)) {
                $coreName = $core
            }
        }
    }

    Log "Detected core: $coreName"
    return $coreName
}

function findEmulatedGamePlatform($DetectedEmulatorExe, $Core) {	
    $exePattern = SQLEscapedMatchPattern $DetectedEmulatorExe.Trim()
    $getPlatformQuery = $null
    if ($Core.Length -eq 0 ) {
        Log "Finding platform for $DetectedEmulatorExe"
        $getPlatformQuery = "SELECT name FROM emulated_platforms WHERE exe_name LIKE '%{0}%' AND core LIKE ''" -f $exePattern
    }
    else {
        Log "Finding platform for $DetectedEmulatorExe and core $Core"
        $corePattern = SQLEscapedMatchPattern $Core.Trim()
        $getPlatformQuery = "SELECT name FROM emulated_platforms WHERE exe_name LIKE '%{0}%' AND core LIKE '{1}'" -f $exePattern, $corePattern
    }
    
    $emulatedGamePlatform = (RunDBQuery $getPlatformQuery).name

    Log "Detected platform : $emulatedGamePlatform"
    return $emulatedGamePlatform
}

function findEmulatedGameDetails($DetectedEmulatorExe) {
    Log "Finding emulated game details for $DetectedEmulatorExe"

    $emulatorCommandLine = Get-WmiObject Win32_Process -Filter "name = '$DetectedEmulatorExe.exe'" | Select-Object -ExpandProperty CommandLine

    $emulatedGameName = findEmulatedGame $DetectedEmulatorExe $emulatorCommandLine
    if ($emulatedGameName.Length -eq 0) {
        Log "Error: Detected emulated game name of 0 char length. Returning"
        return $false
    }

    $coreName = $null
    if ($DetectedEmulatorExe.ToLower() -like "*retroarch*") {
        Log "Retroarch detected. Detecting core next"
        $coreName = findEmulatedGameCore $DetectedEmulatorExe $emulatorCommandLine

        if ($null -eq $coreName) {
            Log "Error: No core detected. Most likely platform is not registered. Please register platform."
            return $false
        }
    }
    
    $emulatedGamePlatform = findEmulatedGamePlatform $DetectedEmulatorExe $coreName

    if ($emulatedGamePlatform -is [system.array]) {
        Log "Error: Multiple platforms detected. Returning."
        return $false
    }

    Log "Found emulated game details. Name: $emulatedGameName, Exe: $DetectedEmulatorExe, Platform: $emulatedGamePlatform"
    return New-Object PSObject -Property @{ Name = $emulatedGameName; Exe = $DetectedEmulatorExe ; Platform = $emulatedGamePlatform }
}

function GetGameDetails($Game) {
    Log "Finding Details of $Game"

    $pattern = SQLEscapedMatchPattern $Game.Trim()
    $getGameDetailsQuery = "SELECT * FROM games WHERE name LIKE '{0}'" -f $pattern

    $gameDetails = RunDBQuery $getGameDetailsQuery

    Log ("Found details: name: {0}, exe_name: {1}, platform: {2}, play_time: {3}" -f $gameDetails.name, $gameDetails.exe_name, $gameDetails.platform, $gameDetails.play_time)
    return $gameDetails
}

function GetPlatformDetails($Platform) {
    Log "Finding Details of $Platform"

    $pattern = SQLEscapedMatchPattern $Platform.Trim()
    $getPlatformDetailsQuery = "SELECT * FROM emulated_platforms WHERE name LIKE '{0}'" -f $pattern

    $platformDetails = RunDBQuery $getplatformDetailsQuery

    Log ("Found details: name: {0}, exe_name: {1}, core: {2}" -f $platformDetails.name, $platformDetails.exe_name, $platformDetails.core)
    return $platformDetails 
}
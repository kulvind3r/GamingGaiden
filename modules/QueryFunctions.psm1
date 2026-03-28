function IsExeEmulator($DetectedExe) {
    Log "Is $DetectedExe an Emulator?"

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

function FindEmulatedGame($DetectedEmulatorExe, $EmulatorCommandLine) {
    Log "Finding emulated game for $DetectedEmulatorExe"

    $pattern = SQLEscapedMatchPattern $DetectedEmulatorExe.Trim()
    $getRomExtensionsQuery = "SELECT rom_extensions FROM emulated_platforms WHERE exe_name LIKE '%{0}%'" -f $pattern
    $romExtensions = (RunDBQuery $getRomExtensionsQuery).rom_extensions.Split(',')

    $romName = $null
    foreach ($romExtension in $romExtensions) {
        $romName = [System.Text.RegularExpressions.Regex]::Match($EmulatorCommandLine, "[^`"\\]*\.$romExtension").Value

        if ($romName -ne "") {
            $romName = $romName -replace ".$romExtension", ""
            break
        }
    }

    $romBasedGameName = [regex]::Replace($romName, '\([^)]*\)|\[[^\]]*\]', "")

    Log ("Detected game: {0}" -f $romBasedGameName.Trim())
    return $romBasedGameName.Trim()
}

function FindEmulatedGameCore($DetectedEmulatorExe, $EmulatorCommandLine) {
    Log "Finding core in use by $DetectedEmulatorExe"

    $coreName = $null

    $pattern = SQLEscapedMatchPattern $DetectedEmulatorExe.Trim()
    $getCoresQuery = "SELECT core FROM emulated_platforms WHERE exe_name LIKE '%{0}%'" -f $pattern
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

function FindEmulatedGamePlatform($DetectedEmulatorExe, $Core) {
    $getPlatformQuery = $null

    $exePattern = SQLEscapedMatchPattern $DetectedEmulatorExe.Trim()
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

function FindEmulatedGameDetails($DetectedEmulatorExe) {
    Log "Finding emulated game details for $DetectedEmulatorExe"

    $emulatorCommandLine = Get-CimInstance -ClassName Win32_Process -Filter "name = '$DetectedEmulatorExe.exe'" | Select-Object -ExpandProperty CommandLine

    $emulatedGameRomBasedName = FindEmulatedGame $DetectedEmulatorExe $emulatorCommandLine
    if ($emulatedGameRomBasedName.Length -eq 0) {
        Log "Error: Detected emulated game name of 0 char length. Returning"
        return $false
    }

    $coreName = $null
    if ($DetectedEmulatorExe.ToLower() -like "*retroarch*") {
        Log "Retroarch detected. Detecting core next"
        $coreName = FindEmulatedGameCore $DetectedEmulatorExe $emulatorCommandLine

        if ($null -eq $coreName) {
            Log "Error: No core detected. Most likely platform is not registered. Please register platform."
            return $false
        }
    }

    $emulatedGamePlatform = FindEmulatedGamePlatform $DetectedEmulatorExe $coreName

    if ($emulatedGamePlatform -is [system.array]) {
        Log "Error: Multiple platforms detected. Returning."
        return $false
    }

    Log "Found emulated game details. Rom Based Name: $emulatedGameRomBasedName, Exe: $DetectedEmulatorExe, Platform: $emulatedGamePlatform"
    return New-Object PSObject -Property @{ RomBasedName = $emulatedGameRomBasedName; Exe = $DetectedEmulatorExe ; Platform = $emulatedGamePlatform }
}

function GetGameDetails($Game) {
    Log "Finding Details of $Game"

    $pattern = SQLEscapedMatchPattern $Game.Trim()
    $getGameDetailsQuery = "SELECT * FROM games WHERE name LIKE '{0}'" -f $pattern

    $gameDetails = RunDBQuery $getGameDetailsQuery

    Log ("Found details: name: {0}, exe_name: {1}, platform: {2}, play_time: {3}" -f $gameDetails.name, $gameDetails.exe_name, $gameDetails.platform, $gameDetails.play_time)
    return $gameDetails
}

function GetPCDetails($PC) {
    Log "Finding Details of $PC"

    $pattern = SQLEscapedMatchPattern $PC.Trim()
    $getPCDetailsQuery = "SELECT * FROM gaming_pcs WHERE name LIKE '{0}'" -f $pattern

    $PCDetails = RunDBQuery $getPCDetailsQuery

    Log ("Found details: name: {0}, cost: {1}, start_date: {2}, end_date: {3}, in_use: {4}" -f $PCDetails.name, $PCDetails.cost, $PCDetails.start_date, $PCDetails.end_date, $PCDetails.in_use)
    return $PCDetails
}

function GetPlatformDetails($Platform) {
    Log "Finding Details of $Platform"

    $pattern = SQLEscapedMatchPattern $Platform.Trim()
    $getPlatformDetailsQuery = "SELECT * FROM emulated_platforms WHERE name LIKE '{0}'" -f $pattern

    $platformDetails = RunDBQuery $getPlatformDetailsQuery

    Log ("Found details: name: {0}, exe_name: {1}, core: {2}" -f $platformDetails.name, $platformDetails.exe_name, $platformDetails.core)
    return $platformDetails
}
function DetectGame() {
    Log "Starting game detection"

    $getGameExesQuery = "SELECT exe_name FROM games ORDER BY last_play_date DESC"
    $getEmulatorExesQuery = "SELECT exe_name FROM emulated_platforms"

    $gameExeList = (RunDBQuery $getGameExesQuery).exe_name
    
    $rawEmulatorExes = (RunDBQuery $getEmulatorExesQuery).exe_name
    # Flatten the rows with multiple exes into a single list
    $emulatorExeList = ($rawEmulatorExes -join ',') -split ','

    $exesToDetect = $($gameExeList; $emulatorExeList) | Select-Object -Unique

    do {
        $allProcesses = ((Get-Process).ProcessName | Select-Object -Unique)
        foreach ( $exeName in $exesToDetect ) {
            if ( $allProcesses -contains $exeName ) {
                Log "Found $exeName running. Exiting detection"
                return $exeName
            }
        }
        Clear-Variable allProcesses; Remove-Variable allProcesses
        # Mandatory Garbage collect in loop because powershell is dogshit in recovering memory from infinite loops
        [System.GC]::GetTotalMemory($true) | out-null
        Start-Sleep -s 5
    }
    while ($true)
}

function TimeTrackerLoop($DetectedExe) {
    $hwInfoSensorSession = 'HKCU:\SOFTWARE\HWiNFO64\Sensors\Custom\Gaming Gaiden\Other1'
    $playTimeForCurrentSession = 0
    $idleSessionsCount = 0
    $idleSessions = New-Object int[] 100;
    $exeStartTime = (Get-Process $DetectedExe).StartTime | Sort-Object | Select-Object -First 1

    while (Get-Process $DetectedExe) {
        $playTimeForCurrentSession = [int16] (New-TimeSpan -Start $exeStartTime).TotalMinutes
        $idleTime = [int16] ([PInvoke.Win32.UserInput]::IdleTime).Minutes

        if ($idleTime -ge 10) {
            # Entered idle Session
            while ( $idleTime -ge 5) {
                # Track idle Time for current Idle Session
                $idleSessions[$idleSessionsCount] = $idleTime
                $idleTime = [int16] ([PInvoke.Win32.UserInput]::IdleTime).Minutes

                # Keep the hwinfo sensor updated to current play time session length while tracking idle session
                $playTimeForCurrentSession = [int16] (New-TimeSpan -Start $exeStartTime).TotalMinutes
                Set-Itemproperty -path $hwInfoSensorSession -Name 'Value' -value $playTimeForCurrentSession

                Start-Sleep -s 5
            }
            # Exited Idle Session, increment idle session counter for storing next idle sessions's length
            $idleSessionsCount++
        }

        Set-Itemproperty -path $hwInfoSensorSession -Name 'Value' -value $playTimeForCurrentSession
        Start-Sleep -s 5
    }

    $idleTimeForCurrentSession = ($idleSessions | Measure-Object -Sum).Sum
    Log "Play time for current session: $playTimeForCurrentSession min. Idle time for current session: $idleTimeForCurrentSession min."

    $PlayTimeExcludingIdleTime = $playTimeForCurrentSession - $idleTimeForCurrentSession
    Log "Play time for current session excluding Idle time $PlayTimeExcludingIdleTime min"

    return @($PlayTimeExcludingIdleTime, $idleTimeForCurrentSession)
}

function MonitorGame($DetectedExe) {
    Log "Starting monitoring for $DetectedExe"
    
    $databaseFileHashBefore = CalculateFileHash '.\GamingGaiden.db'
    Log "Database hash before: $databaseFileHashBefore"

    $emulatedGameDetails = $null
    $gameName = $null
    $romBasedName = $null
    $entityFound = $null
    $updatedPlayTime = 0
    $updatedLastPlayDate = (Get-Date ([datetime]::UtcNow) -UFormat %s).Split('.').Get(0)

    if (IsExeEmulator $DetectedExe) {
        $emulatedGameDetails = findEmulatedGameDetails $DetectedExe
        if ($emulatedGameDetails -eq $false) {
            Log "Error: Problem in fetching emulated game details. See earlier logs for more info"
            Log "Error: Cannot resume detection until $DetectedExe exits. No playtime will be recorded."
            
            TimeTrackerLoop $DetectedExe
            return
        }

        $romBasedName = $emulatedGameDetails.RomBasedName
        $entityFound = DoesEntityExists "games" "rom_based_name" $romBasedName
    }
    else {
        $entityFound = DoesEntityExists "games" "exe_name" $DetectedExe
    }
    
    # Create Temp file to signal parent process to update notification icon color to show game is running
    Write-Output "$gameName" > "$env:TEMP\GG-TrackingGame.txt"
    $sessionTimeDetails = TimeTrackerLoop $DetectedExe
    $currentPlayTime = $sessionTimeDetails[0]
    $currentIdleTime = $sessionTimeDetails[1]
    # Remove Temp file to signal parent process to update notification icon color to show game has finished
    Remove-Item "$env:TEMP\GG-TrackingGame.txt"

    if ($null -ne $entityFound) {
        Log "Game Already Exists. Updating PlayTime and Last Played Date"
        $gameName = $entityFound.name
        $recordedGamePlayTime = GetPlayTime $gameName
        $recordedGameIdleTime = GetIdleTime $gameName
        $updatedPlayTime = $recordedGamePlayTime + $currentPlayTime
        $updatedIdleTime = $recordedGameIdleTime + $currentIdleTime
        
        UpdateGameOnSession -GameName $gameName -GamePlayTime $updatedPlayTime -GameIdleTime $updatedIdleTime -GameLastPlayDate $updatedLastPlayDate
    }
    else {
        Log "New Emulated Game Doesn't Exists. Adding."
        
        SaveGame -GameName $romBasedName -GameExeName $DetectedExe -GameIconPath "./icons/default.png" `
        -GamePlayTime $currentPlayTime -GameIdleTime $currentIdleTime -GameLastPlayDate $updatedLastPlayDate -GameCompleteStatus 'FALSE' -GamePlatform $emulatedGameDetails.Platform -GameSessionCount 1 -GameRomBasedName $romBasedName
    }

    RecordPlaytimOnDate($currentPlayTime)

    $databaseFileHashAfter = CalculateFileHash '.\GamingGaiden.db'
    Log "Database hash after: $databaseFileHashAfter"

    if ($databaseFileHashAfter -ne $databaseFileHashBefore) {
        BackupDatabase
    }
}
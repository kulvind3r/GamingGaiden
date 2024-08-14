function DetectGame() {
    Log "Starting game detection"

    # Fetch games in order of most recent to least recent
    $getGameExesQuery = "SELECT exe_name FROM games ORDER BY last_play_date DESC"
    $getEmulatorExesQuery = "SELECT exe_name FROM emulated_platforms"

    $gameExeList = (RunDBQuery $getGameExesQuery).exe_name
    $rawEmulatorExes = (RunDBQuery $getEmulatorExesQuery).exe_name

    if($null -eq $gameExeList -and $null -eq $rawEmulatorExes) {
        Log "No games/emulators in datbase. Exiting tracker."
        exit 1
    }

    # Flatten the returned result rows containing multiple emulator exes into list with one exe per item
    $emulatorExeList = ($rawEmulatorExes -join ',') -split ','

    $exeList = $($gameExeList; $emulatorExeList) | Select-Object -Unique
    
    # PERFORMANCE OPTIMIZATION: CPU & MEMORY
    # Process games in batches of 35 with most recent 10 games processed every batch. 5 sec wait b/w every batch. 
    # Processes 300 games in 60 sec. Most recent 10 games guaranteed to be detected in 5 sec, accounting for 99% of UX in typical usage.
    # Uses less than 2% cpu on a 2019 Ryzen 3550H in low power mode (1.7 GHz Clk with boost disabled), Windows 10 21H2.
    # No new objects are created inside infinite loops to prevent objects explosion, keeps Memory usage ~ 50 MB or less.
    if($exeList.length -le 35) {
        # If exeList is of size 35 or less. process whole list in every batch
        while($true) {
            foreach ($exe in $exeList) {
                if ([System.Diagnostics.Process]::GetProcessesByName($exe)) {
                    Log "Found $exe running. Exiting detection"
                    return $exe
                }
            }
            Start-Sleep -s 5
        }
    }
    else {
        # If exeList is longer than 35.
        $startIndex = 10; $batchSize = 25
        while($true) {
            # Process most recent 10 games in every batch.
            for($i=0; $i -lt 10; $i++) {
                if ([System.Diagnostics.Process]::GetProcessesByName($exeList[$i])) {
                    Log "Found $($exeList[$i]) running. Exiting detection"
                    return $exeList[$i]
                }
            }
            # Rest of the games in incrementing way. 25 in each batch.
            $endIndex = [Math]::Min($startIndex + $batchSize, $exeList.length)
    
            for($i=$startIndex; $i -lt $endIndex; $i++) {
                if ([System.Diagnostics.Process]::GetProcessesByName($exeList[$i])) {
                    Log "Found $exeList[$i] running. Exiting detection"
                    return $exeList[$i]
                }
            }
    
            if ($startIndex + $batchSize -lt $exeList.length) {
                $startIndex = $startIndex + $batchSize
            } else {
                $startIndex = 10
            }
    
            Start-Sleep -s 5
        }
    }
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
    
    if ($null -ne $entityFound) {
        $gameName = $entityFound.name
    }
    else {
        $gameName = $romBasedName
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
        $recordedGamePlayTime = GetPlayTime $gameName
        $recordedGameIdleTime = GetIdleTime $gameName
        $updatedPlayTime = $recordedGamePlayTime + $currentPlayTime
        $updatedIdleTime = $recordedGameIdleTime + $currentIdleTime
        
        UpdateGameOnSession -GameName $gameName -GamePlayTime $updatedPlayTime -GameIdleTime $updatedIdleTime -GameLastPlayDate $updatedLastPlayDate
    }
    else {
        Log "Detected emulated game is new and doesn't exist already. Adding to database."
        
        SaveGame -GameName $gameName -GameExeName $DetectedExe -GameIconPath "./icons/default.png" `
        -GamePlayTime $currentPlayTime -GameIdleTime $currentIdleTime -GameLastPlayDate $updatedLastPlayDate -GameCompleteStatus 'FALSE' -GamePlatform $emulatedGameDetails.Platform -GameSessionCount 1 -GameRomBasedName $gameName
    }

    RecordPlaytimOnDate($currentPlayTime)

    $databaseFileHashAfter = CalculateFileHash '.\GamingGaiden.db'
    Log "Database hash after: $databaseFileHashAfter"

    if ($databaseFileHashAfter -ne $databaseFileHashBefore) {
        BackupDatabase
    }
}
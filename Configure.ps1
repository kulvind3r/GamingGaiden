param (
    $Action
)

#Requires -Version 5.1
#Requires -Modules PSSQLite

function RegisterGame{
    
    Log "Starting Game Registration"
    
    $GameName = UserInputDialog "Register Game" "Enter Name for the Game"

    $EntityFound = DoesEntityExists "games" "name" $GameName
    if ($null -ne $EntityFound)
    {
        ShowMessage "Game already exists" "OK" "Asterisk"
        Log "Game Already Exists. returning"
        return
    }
    
    $GameExeFile = FileBrowserDialog "Select Game Executable File" 'Executable (*.exe)|*.exe'
    $GameExeName = $GameExeFile.BaseName

    $GameIcon = [System.Drawing.Icon]::ExtractAssociatedIcon($GameExeFile)
    $GameIcon.ToBitmap().save("$env:TEMP\icon.bmp")
    $GameIconBytes = (Get-Content -Path "$env:TEMP\icon.bmp" -Encoding byte -Raw);
    
    $GameLastPlayDate = (Get-Date -UFormat %s).Split('.').Get(0)

    $RegisterGameQuery = "INSERT INTO GAMES (name, exe_name, icon, play_time, last_play_date, completed, platform)" +
						"VALUES (@GameName, @GameExeName, @GameIconBytes, 0, @GameLastPlayDate, 'FALSE', 'PC')"

	Log "Registering $GameExeName in Database"
    Invoke-SqliteQuery -Query $RegisterGameQuery -SQLiteConnection $DBConnection -SqlParameters @{
        GameName = $GameName.Trim()
        GameExeName = $GameExeName.Trim()
        GameIconBytes = $GameIconBytes
        GameLastPlayDate = $GameLastPlayDate
    }
    Remove-Item "$env:TEMP\icon.bmp";

    ShowMessage "Game Successfully Registered" "OK" "Asterisk"
}

function RegisterEmulatedPlatform{

    Log "Starting emulated platform registration"

    $PlatformName = UserInputDialog "Register Platform" "Enter Platform Name: NES, Gamecube, Playstation 2 etc"

    $EntityFound = DoesEntityExists "emulated_platforms" "name"  $PlatformName 
    if ($null -ne $EntityFound)
    {
        ShowMessage "Platform already exists" "OK" "Asterisk"
        Log "Platform already exists. returning"
        return
    }

    $EmulatorExeFile = FileBrowserDialog "Select Emulator Executable" 'Executable (*.exe)|*.exe'
    $EmulatorExeName = $EmulatorExeFile.BaseName

    $CoreName = ""
    if ($EmulatorExeName.ToLower() -eq "retroarch")
    {
        ShowMessage "Retroarch detected. Please Select Core for Platform." "OK" "Asterisk"
        $CoreFile = FileBrowserDialog "Select Retroarch Core" 'DLL (*.dll)|*.dll'
        $CoreName = $CoreFile.Name
    }

    $RomExtensions = UserInputDialog "Rom Extensions" "Enter all rom file extensions for Platform: zip,chd,iso..."
    
    $RegisterEmulatedPlatformQuery = "INSERT INTO Emulated_Platforms (name, exe_name, core, rom_extensions)" +
						"VALUES (@PlatformName, @EmulatorExeName, @CoreName, @RomExtensions)"

    Log "Registering $PlatformName in Database"
    Invoke-SqliteQuery -Query $RegisterEmulatedPlatformQuery -SQLiteConnection $DBConnection -SqlParameters @{
        PlatformName = $PlatformName.Trim()
        EmulatorExeName = $EmulatorExeName.Trim()
        CoreName = $CoreName.Trim()
        RomExtensions = $RomExtensions.Trim()
    }

    ShowMessage "Platform Successfully Registered" "OK" "Asterisk"
}

function UpdateGameIcon{
    
    Log "Starting Game Icon Update"

    $GamesList = (Invoke-SqliteQuery -Query "SELECT name FROM games ORDER BY last_play_date DESC" -SQLiteConnection $DBConnection).name
    $SelectedGame = $GamesList | Out-GridView -Title "Select a Game" -OutputMode Single
    if ($null -eq $SelectedGame)
    {
        Log "Icon Update Operation cancelled or closed abruptly. Returning";
        exit 1
    }
    
    $GameIconFile = FileBrowserDialog "Select Game Icon File" 'PNG (*.png)|*.png|JPEG (*.jpg)|*.jpg'
    $GameIconPath = $GameIconFile.FullName
    
    $ResizedImagePath = ResizeImage $GameIconPath $SelectedGame
    $GameIconBytes = (Get-Content -Path $ResizedImagePath -Encoding byte -Raw);
    Remove-Item $ResizedImagePath

    $GameNamePattern = SQLEscapedMatchPattern($SelectedGame.Trim())

    $UpdateGameIconQuery = "UPDATE games SET icon = @GameIconBytes WHERE name LIKE '{0}'" -f $GameNamePattern

    Invoke-SqliteQuery -Query $UpdateGameIconQuery -SQLiteConnection $DBConnection -SqlParameters @{ 
        GameIconBytes = $GameIconBytes
    }
    
    ShowMessage "Icon Successfully Updated." "OK" "Asterisk"
}

function UpdatePlayTime{
    Log "Starting PlayTime Update"

    $GamesList = (Invoke-SqliteQuery -Query "SELECT name FROM games ORDER BY last_play_date DESC" -SQLiteConnection $DBConnection).name
    $SelectedGame = $GamesList | Out-GridView -Title "Select a Game" -OutputMode Single
    if ($null -eq $SelectedGame)
    {
        Log "Update Playtime Operation cancelled or closed abruptly. Returning";
        exit 1
    }

    $PlayTimeDelta = UserInputDialog "Input PlayTime" "To Add Playtime enter '+ HH:MM'.`r`nTo Deduct Playtime enter '- HH:MM'"
    
    if ( -Not ($PlayTimeDelta -match '^\+ \d\d:\d\d$|^\- \d\d:\d\d$') ) {
        ShowMessage "Incorrect Playtime Format. Expected '+ HH:MM' or '- HH:MM'. Read Input dialog carefully." "OK" "Error"
        Log "Incorrect Playtime format entered. Exiting"
        exit 1
    }

    $Action = $PlayTimeDelta[0]
    $Hours = $PlayTimeDelta.Split(" ")[1].Split(":")[0]
    $Minutes = $PlayTimeDelta.Split(" ")[1].Split(":")[1]
    $PlayTimeDeltaInMinutes = ([int]$Hours * 60) + [int]$Minutes

    $GameNamePattern = SQLEscapedMatchPattern($SelectedGame.Trim())
    $GetGamePlayTimeQuery = "SELECT play_time FROM games WHERE name LIKE '{0}'" -f $GameNamePattern
    $RecordedGamePlayTime = (Invoke-SqliteQuery -Query $GetGamePlayTimeQuery -SQLiteConnection $DBConnection).play_time

    $UpdatedPlayTime = $null
    switch ($Action) {
        '-' { $UpdatedPlayTime = $RecordedGamePlayTime - $PlayTimeDeltaInMinutes }
        '+' { $UpdatedPlayTime = $RecordedGamePlayTime + $PlayTimeDeltaInMinutes }
    }

    $UpdateGamePlayTimeQuery = "UPDATE games SET play_time = @UpdatedPlayTime WHERE name LIKE '{0}'" -f $GameNamePattern

    Invoke-SqliteQuery -Query $UpdateGamePlayTimeQuery -SQLiteConnection $DBConnection -SqlParameters @{ UpdatedPlayTime = $UpdatedPlayTime }

    ShowMessage "Playtime Updated. " "OK" "Asterisk"
}

function RemoveGame{
    Write-Output "TBD 4"
}

try {

    [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')  | out-null
    [System.Reflection.assembly]::loadwithpartialname("microsoft.visualbasic") | Out-Null
    Import-Module PSSQLite
    Import-Module -Name ".\modules\HelperFunctions.psm1"
    Import-Module -Name ".\modules\QueryFunctions.psm1"
    Import-Module -Name ".\modules\UIFunctions.psm1"

    $Database = ".\GamingGaiden.db"
    Log "Connecting to database for configuration"
    $DBConnection = New-SQLiteConnection -DataSource $Database
        
    switch ($Action) {
        "RegisterGame" { Clear-Host; RegisterGame }
        "RegisterEmulatedPlatform" { Clear-Host; RegisterEmulatedPlatform }
        "UpdateGameIcon" { Clear-Host; UpdateGameIcon }
        "UpdatePlayTime" { Clear-Host; UpdatePlayTime }
    }
    
    $DBConnection.Close()
}
catch {
    $Timestamp = (Get-date -f %d-%M-%y`|%H:%m:%s)
    Write-Output "$Timestamp : A User or System error has caused an exception. Please Try again. Check log for exception details" >> ".\GamingGaiden.log"
    Write-Output "$Timestamp : Exception: $($_.Exception.Message)" >> ".\GamingGaiden.log"
    Start-Sleep -s 5; exit 1;
}
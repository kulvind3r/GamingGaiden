param (
    $Action
)

#Requires -Version 5.1
#Requires -Modules PSSQLite

function RegisterGame{
    $GameName = Read-Host -Prompt "Enter Name for the Game"

    if ($GameName.Length -eq 0)
    {
        user_prompt "Game Name cannot be empty. Please try again"; countdown
        return
    }

    $EntityFound = DoesEntityExists "games" "name" $GameName
    if ($null -ne $EntityFound)
    {
        user_prompt "Game already exists"
        "Name: '{0}'   Platform: '{1}'   PlayTime: '{2}' Min   Last Played On: '{3}'" -f $EntityFound.name, $EntityFound.platform, $EntityFound.play_time, $EntityFound.last_play_date
        countdown
        return
    }
    
    user_prompt "Select game executable"
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

    user_prompt "Game Successfully Registered. Returning to Menu."; countdown
}

function RegisterEmulatedPlatform{
    $PlatformName = Read-Host -Prompt "Enter Name for the Emulated Platform (Console) e.g NES, Gamecube, Playstation 2 etc"

    if ($PlatformName.Length -eq 0)
    {
        user_prompt "Platform Name cannot be empty. Please try again"; countdown
        return
    }

    $EntityFound = DoesEntityExists "emulated_platforms" "name"  $PlatformName 
    if ($null -ne $EntityFound)
    {
        user_prompt "Platform already exists"
        "Name: '{0}'   Exe: '{1}'   Core: '{2}'   Rom Extensions: '{3}'" -f $EntityFound.name, $EntityFound.exe_name, $EntityFound.core, $EntityFound.rom_extensions
        countdown
        return
    }

    user_prompt "Select Emulator Executable"
    $EmulatorExeFile = FileBrowserDialog "Select Emulator Executable File" 'Executable (*.exe)|*.exe'
    $EmulatorExeName = $EmulatorExeFile.BaseName

    $CoreName = ""
    if ($EmulatorExeName.ToLower() -eq "retroarch")
    {
        user_prompt "Retroarch detected, select core file for the platform"; countdown
        $CoreFile = FileBrowserDialog "Select Retroarch Core" 'DLL (*.dll)|*.dll'
        $CoreName = $CoreFile.Name
    }

    $RomExtensions = Read-Host -Prompt "Enter all rom file extensions separated by ',' for the Emulated Platform e.g. zip,chd,iso etc"

    $RegisterEmulatedPlatformQuery = "INSERT INTO Emulated_Platforms (name, exe_name, core, rom_extensions)" +
						"VALUES (@PlatformName, @EmulatorExeName, @CoreName, @RomExtensions)"

    Log "Registering $PlatformName in Database"
    Invoke-SqliteQuery -Query $RegisterEmulatedPlatformQuery -SQLiteConnection $DBConnection -SqlParameters @{
        PlatformName = $PlatformName.Trim()
        EmulatorExeName = $EmulatorExeName.Trim()
        CoreName = $CoreName.Trim()
        RomExtensions = $RomExtensions.Trim()
    }

    user_prompt "Platform Successfully Registered. Returning to Menu."; countdown
}

function UpdateGameIcon{

    $GamesList = (Invoke-SqliteQuery -Query "SELECT name FROM games ORDER BY last_play_date DESC" -SQLiteConnection $DBConnection).name
    $SelectedGame = $GamesList | Out-GridView -Title "Select a Game" -OutputMode Single
    if ($null -eq $SelectedGame)
    {
        Log "Operation cancelled or closed abruptly. Returning";
        countdown
        return
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

function UpdateGame{
    Write-Output "TBD 3"
}

function RemoveGame{
    Write-Output "TBD 4"
}

try {
    Add-Type -AssemblyName System.Windows.Forms
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
        4 { Clear-Host; RemoveGame }
    }

    user_prompt "Closing Configuration Session."; countdown

    $DBConnection.Close()
}
catch {
    $Timestamp = (Get-date -f %d-%M-%y`|%H:%m:%s)
    Write-Output "$Timestamp : A User or System error has caused an exception. Please Try again. Check log for exception details" >> ".\GamingGaiden.log"
    Write-Output "$Timestamp : Exception: $($_.Exception.Message)" >> ".\GamingGaiden.log"
    Start-Sleep -s 5; exit 1;
}
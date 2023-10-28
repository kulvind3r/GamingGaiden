function RegisterGame{
    $GameName = Read-Host -Prompt "Enter Name for the Game"

    if ($GameName.Length -eq 0)
    {
        user_prompt "Game Name cannot be empty. Please try again"; countdown
        return
    }
    
    user_prompt "Select game executable"; countdown
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
        InitialDirectory = [Environment]::GetFolderPath('Desktop')
        Filter           = 'Executable (*.exe)|*.exe'
        Title = "Select Game Executable File"
        ShowHelp = $true
    }
    $FileBrowser.ShowDialog() | Out-Null

    $GameExePath = Get-Item $FileBrowser.FileName
    $GameExeName = (Get-Item $FileBrowser.FileName).BaseName

    $GameIcon = [System.Drawing.Icon]::ExtractAssociatedIcon($GameExePath)
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
    $PlatformName = Read-Host -Prompt "Enter Name for the Emulated Platform (Console)"

    if ($PlatformName.Length -eq 0)
    {
        user_prompt "Platform Name cannot be empty. Please try again"; countdown
        return
    }

    user_prompt "Select Emulator Executable"; countdown
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
        InitialDirectory = [Environment]::GetFolderPath('Desktop')
        Filter           = 'Executable (*.exe)|*.exe'
        Title = "Select Emulator Executable File"
        ShowHelp = $true
    }
    $FileBrowser.ShowDialog() | Out-Null

    $EmulatorExeName = (Get-Item $FileBrowser.FileName).BaseName

    $CoreName = ""
    if ($EmulatorExeName.ToLower() -eq "retroarch")
    {
        user_prompt "Retroarch detected, select core file for the platform"; countdown
        $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
            InitialDirectory = [Environment]::GetFolderPath('Desktop')
            Filter           = 'Executable (*.dll)|*.dll'
            Title = "Select Retroarch Core"
            ShowHelp = $true
        }
        $FileBrowser.ShowDialog() | Out-Null

        $CoreName = (Get-Item $FileBrowser.FileName).Name
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

    $GamesList = (Invoke-SqliteQuery -Query "select name from games" -SQLiteConnection $DBConnection).name

    user_prompt "All Registered Games"    
    $sno = 1; foreach ($Game in $GamesList) { Write-Host "$sno. $Game";  $sno++; }
    $GameNo = Read-Host -Prompt "Enter Serial No of the game you want to update"
    $GameName = $GamesList[$GameNo-1]

    user_prompt "Select an image file"; countdown
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
        InitialDirectory = [Environment]::GetFolderPath('Desktop')
        Filter           = 'Icon (*.ico)|*.ico|PNG (*.png)|*.png|JPEG (*.jpg)|*.jpg'
        Title = "Select Game Icon File"
        ShowHelp = $true
    }

    $FileBrowser.ShowDialog() | Out-Null

    $GameIconPath = (Get-Item $FileBrowser.FileName).FullName
    $ResizedImagePath = ResizeImage $GameIconPath $GameName
    $GameIconBytes = (Get-Content -Path $ResizedImagePath -Encoding byte -Raw);
    Remove-Item $ResizedImagePath

    $GameNamePattern = SQLEscapedMatchPattern($GameName.Trim())

    $UpdateGameIconQuery = "UPDATE games SET icon = @GameIconBytes WHERE name LIKE '{0}'" -f $GameNamePattern

    Invoke-SqliteQuery -Query $UpdateGameIconQuery -SQLiteConnection $DBConnection -SqlParameters @{ 
        GameIconBytes = $GameIconBytes
    }
    
    user_prompt "Icon Successfully Updated. Returning to Menu."; countdown
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
    Import-Module -Name ".\Functions.psm1"

    $Database = ".\GameplayGaiden.db"
    Log "Connecting to database for configuration"
    $DBConnection = New-SQLiteConnection -DataSource $Database

    do {
        Clear-Host
        user_prompt "What would you like to configure?"
        Write-Host "1. Register a new game"
        Write-Host "2. Register an Emulated Platform. e.g. SNES, Playstation 2 etc"
        Write-Host "3. Update a game Icon"
        Write-Host "4. Remove an existing game from record"
        Write-Host "5. Exit"
        $UserChoice = Read-Host -Prompt "Enter your choice 1-4?"
        
            switch ($UserChoice) {
                1 { Clear-Host; RegisterGame }
                2 { Clear-Host; RegisterEmulatedPlatform }
                3 { Clear-Host; UpdateGameIcon }
                4 { Clear-Host; RemoveGame }
            }
        
    } while($UserChoice -ne 5)

    user_prompt "Closing Configuration Session."; countdown

    $DBConnection.Close()
}
catch {
    $Timestamp = (Get-date -f %d-%M-%y`|%H:%m:%s)
    Write-Output "$Timestamp : A User or System error has caused an exception. Please Try again. Check log for exception details" >> ".\GameplayGaiden.log"
    Write-Output "$Timestamp : Exception: $($_.Exception.Message)" >> ".\GameplayGaiden.log"
    Start-Sleep -s 5; exit 1;
}
param (
    $Action
)

#Requires -Version 5.1
#Requires -Modules PSSQLite

function AddGame {
    
    Log "Starting Game Registration"
    
    $GameName = UserInputDialog "Add Game" "Enter Name for the Game"

    $EntityFound = DoesEntityExists "games" "name" $GameName
    if ($null -ne $EntityFound)
    {
        ShowMessage "Game already exists" "OK" "Asterisk"
        Log "Game Already Exists. returning"
        return
    }
    
    $GameExeFile = ""
    $openFileDialog = OpenFileDialog "Select Game Executable" 'Executable (*.exe)|*.exe'
    $result = $openFileDialog.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $GameExeFile = Get-Item $openFileDialog.FileName
    }
    else {
        ShowMessage "Game Reigstration Cancelled" "Ok" "Asterisk"
        Log "Game Reigstration Cancelled"
        exit 1
    }
    $GameExeName = $GameExeFile.BaseName
    $IconFileName = ToBase64 $GameName
    $GameIconPath="$env:TEMP\GG-{0}-$IconFileName.png" -f $(Get-Random)
    $GameIcon = [System.Drawing.Icon]::ExtractAssociatedIcon($GameExeFile)
    $GameIcon.ToBitmap().save($GameIconPath)
    
    $GameLastPlayDate = (Get-Date -UFormat %s).Split('.').Get(0)

    SaveGame -GameName $GameName -GameExeName $GameExeName -GameIconPath $GameIconPath `
				-GamePlayTime 0 -GameLastPlayDate $GameLastPlayDate -GameCompleteStatus 'FALSE' -GamePlatform 'PC'

    ShowMessage "Game Successfully Registered" "OK" "Asterisk"
}

function AddPlatform {

    Log "Starting emulated platform registration"

    $PlatformName = UserInputDialog "Add Platform" "Enter Platform Name: NES, Gamecube, Playstation 2 etc"

    $EntityFound = DoesEntityExists "emulated_platforms" "name"  $PlatformName 
    if ($null -ne $EntityFound)
    {
        ShowMessage "Platform already exists" "OK" "Asterisk"
        Log "Platform already exists. returning"
        return
    }

    $EmulatorExeName = ""
    $openFileDialog = OpenFileDialog "Select Emulator Executable" 'Executable (*.exe)|*.exe'
    $result = $openFileDialog.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $EmulatorExeName = (Get-Item $openFileDialog.FileName).BaseName
    }
    else {
        ShowMessage "Emulator Reigstration Cancelled" "Ok" "Asterisk"
        Log "Emulator Reigstration Cancelled"
        exit 1
    }

    $CoreName = ""
    if ($EmulatorExeName.ToLower() -eq "retroarch")
    {
        ShowMessage "Retroarch detected. Please Select Core for Platform." "OK" "Asterisk"
        $openFileDialog = OpenFileDialog "Select Retroarch Core" 'DLL (*.dll)|*.dll'
        $result = $openFileDialog.ShowDialog()
        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            $CoreName = (Get-Item $openFileDialog.FileName).Name
        }
        else {
            ShowMessage "Emulator Reigstration Cancelled" "Ok" "Asterisk"
            Log "Emulator Reigstration Cancelled"
            exit 1
        }
    }

    $RomExtensions = UserInputDialog "Rom Extensions" "Enter all rom file extensions for Platform: zip,chd,iso..."

    SavePlatform -PlatformName $PlatformName -EmulatorExeName $EmulatorExeName -CoreName $CoreName -RomExtensions $RomExtensions
    
    ShowMessage "Platform Successfully Registered" "OK" "Asterisk"
}

function EditGame {
    Log "Starting Game Editing"

    $GamesList = (Invoke-SqliteQuery -Query "SELECT name FROM games" -SQLiteConnection $DBConnection).name
    $SelectedGame = RenderListBoxForm "Select a Game" $GamesList

    $SelectedGameDetails = GetGameDetails $SelectedGame
    
    RenderEditGameForm $SelectedGameDetails
}

function EditPlatform {
    Log "Starting Platform Editing"

    $PlatformsList = (Invoke-SqliteQuery -Query "SELECT name FROM emulated_platforms" -SQLiteConnection $DBConnection).name
    $SelectedPlatform = RenderListBoxForm "Select a Platform" $PlatformsList

    $SelectedPlatformDetails = GetPlatformDetails $SelectedPlatform
    
    RenderEditPlatformForm $SelectedPlatformDetails
}

try {

    [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')  | out-null
    [System.Reflection.assembly]::loadwithpartialname("microsoft.visualbasic") | Out-Null
    Import-Module PSSQLite
    Import-Module -Name ".\modules\HelperFunctions.psm1"
    Import-Module -Name ".\modules\QueryFunctions.psm1"
    Import-Module -Name ".\modules\UIFunctions.psm1"
    Import-Module -Name ".\modules\StorageFunctions.psm1"

    $Database = ".\GamingGaiden.db"
    Log "Connecting to database for configuration"
    $DBConnection = New-SQLiteConnection -DataSource $Database
        
    switch ($Action) {
        "AddGame" { Clear-Host; AddGame }
        "AddPlatform" { Clear-Host; AddPlatform }
        "EditGame" { Clear-Host; EditGame }
        "EditPlatform" { Clear-Host; EditPlatform }
    }
}
catch {
    [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')    | out-null
    [System.Windows.Forms.MessageBox]::Show("Exception: $($_.Exception.Message). Check log for details",'Gaming Gaiden', "OK", "Error")

    $Timestamp = (Get-date -f %d-%M-%y`|%H:%m:%s)
    Write-Output "$Timestamp : A User or System error has caused an exception. Please Try again. Check log for exception details" >> ".\GamingGaiden.log"
    Write-Output "$Timestamp : Exception: $($_.Exception.Message)" >> ".\GamingGaiden.log"
    exit 1;
}
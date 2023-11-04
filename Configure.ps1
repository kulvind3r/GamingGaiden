param (
    $Action
)

#Requires -Version 5.1
#Requires -Modules PSSQLite

function AddGame {
    Log "Starting Game Registration"
    RenderAddGameForm
}

function AddPlatform {
    Log "Starting emulated platform registration"
    RenderAddPlatformForm
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
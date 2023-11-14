param (
    $Action
)

#Requires -Version 5.1
#Requires -Modules PSSQLite

function AddGame {
    Log "Starting game registration"
    RenderAddGameForm
}

function AddPlatform {
    Log "Starting emulated platform registration"
    RenderAddPlatformForm
}

function EditGame {
    Log "Starting game editing"

    $GamesList = (RunDBQuery "SELECT name FROM games").name
    if ($GamesList.Length -eq 0){
        ShowMessage "No Games found in database. Please add few games first." "OK" "Error"
        Log "Error: Games list empty. Returning"
        return
    }
    
    $SelectedGame = RenderListBoxForm "Select a Game" $GamesList

    $SelectedGameDetails = GetGameDetails $SelectedGame
    
    RenderEditGameForm $SelectedGameDetails
}

function EditPlatform {
    Log "Starting platform editing"

    $PlatformsList = (RunDBQuery "SELECT name FROM emulated_platforms").name 
    if ($PlatformsList.Length -eq 0){
        ShowMessage "No Platforms found in database. Please add few emulators first." "OK" "Error"
        Log "Error: Platform list empty. Returning"
        return
    }

    $SelectedPlatform = RenderListBoxForm "Select a Platform" $PlatformsList

    $SelectedPlatformDetails = GetPlatformDetails $SelectedPlatform
    
    RenderEditPlatformForm $SelectedPlatformDetails
}

try {
    [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')  | Out-Null
    [System.Reflection.assembly]::LoadwithPartialname("microsoft.visualbasic") | Out-Null
    Import-Module PSSQLite
    Import-Module -Name ".\modules\HelperFunctions.psm1"
    Import-Module -Name ".\modules\QueryFunctions.psm1"
    Import-Module -Name ".\modules\UIFunctionsForConfiguration.psm1"
    Import-Module -Name ".\modules\StorageFunctions.psm1"
    
    $DatabaseFileHashBefore = CalculateFileHash '.\GamingGaiden.db'
    Log "Database hash before: $DatabaseFileHashBefore"

    switch ($Action) {
        "AddGame" { Clear-Host; AddGame }
        "AddPlatform" { Clear-Host; AddPlatform }
        "EditGame" { Clear-Host; EditGame }
        "EditPlatform" { Clear-Host; EditPlatform }
    }

    $DatabaseFileHashAfter = CalculateFileHash '.\GamingGaiden.db'
    Log "Database hash after: $DatabaseFileHashAfter"

    if ($DatabaseFileHashAfter -ne $DatabaseFileHashBefore){
        BackupDatabase
    }
}
catch {
    [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')    | out-null
    [System.Windows.Forms.MessageBox]::Show("Exception: $($_.Exception.Message). Check log for details",'Gaming Gaiden', "OK", "Error")

    $Timestamp = Get-date -f s
    Write-Output "$Timestamp : Error: A user or system error has caused an exception. Check log for details" >> ".\GamingGaiden.log"
    Write-Output "$Timestamp : Exception: $($_.Exception.Message)" >> ".\GamingGaiden.log"
    exit 1;
}
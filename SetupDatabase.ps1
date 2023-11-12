#Requires -Version 5.1
#Requires -Modules PSSQLite

try {
    Import-Module PSSQLite
    
    $Database = ".\GamingGaiden.db"
    $DBConnection = New-SQLiteConnection -DataSource $Database

    $CreateGamesTableQuery="CREATE TABLE IF NOT EXISTS games (
                        name TEXT PRIMARY KEY NOT NULL,
                        exe_name TEXT,
                        icon BLOB,
                        play_time INTEGER,
                        last_play_date INTEGER,
                        completed TEXT,
                        platform TEXT)"

    Invoke-SqliteQuery -Query $CreateGamesTableQuery -SQLiteConnection $DBConnection

    $CreatePlatformsTableQuery="CREATE TABLE IF NOT EXISTS emulated_platforms (
                        name TEXT PRIMARY KEY NOT NULL,
                        exe_name TEXT,
                        core TEXT,
                        rom_extensions TEXT)"

    Invoke-SqliteQuery -Query $CreatePlatformsTableQuery -SQLiteConnection $DBConnection

    $CreateDailyPlaytimeTableQuery="CREATE TABLE IF NOT EXISTS daily_playtime (
                        play_date TEXT PRIMARY KEY NOT NULL,
                        play_time INTEGER)"

    Invoke-SqliteQuery -Query $CreateDailyPlaytimeTableQuery -SQLiteConnection $DBConnection

    $DBConnection.Close()
}
catch {
    [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')    | out-null
    [System.Windows.Forms.MessageBox]::Show("Exception: $($_.Exception.Message). Check log for details",'Gaming Gaiden', "OK", "Error")

    $Timestamp = (Get-date -f %d-%M-%y`|%H:%m:%s)
    Write-Output "$Timestamp : Error: A user or system error has caused an exception. Database setup could not be finished. Check log for details." >> ".\GamingGaiden.log"
    Write-Output "$Timestamp : Exception: $($_.Exception.Message)" >> ".\GamingGaiden.log"
    exit 1;
}

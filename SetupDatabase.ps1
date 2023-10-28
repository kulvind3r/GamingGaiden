Import-Module PSSQLite

try {
    $Database = ".\GameplayGaiden.db"
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

    $DBConnection.Close()
}
catch {
    $Timestamp = (Get-date -f %d-%M-%y`|%H:%m:%s)
    Write-Output "$Timestamp : A User or System error has caused an exception. Database Setup could not be finished. Check Log for Details." >> ".\GameplayGaiden.log"
    Write-Output "$Timestamp : Exception: $($_.Exception.Message)" >> ".\GameplayGaiden.log"
    Start-Sleep -s 5; exit 1;
}

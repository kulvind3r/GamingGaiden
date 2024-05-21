#Requires -Version 5.1

try {
    Import-Module ".\modules\PSSQLite"
    
    $dbConnection = New-SQLiteConnection -DataSource ".\GamingGaiden.db"

    $createGamesTableQuery = "CREATE TABLE IF NOT EXISTS games (
                        name TEXT PRIMARY KEY NOT NULL,
                        exe_name TEXT,
                        icon BLOB,
                        play_time INTEGER,
                        last_play_date INTEGER,
                        completed TEXT,
                        platform TEXT)"

    Invoke-SqliteQuery -Query $createGamesTableQuery -SQLiteConnection $dbConnection

    $createPlatformsTableQuery = "CREATE TABLE IF NOT EXISTS emulated_platforms (
                        name TEXT PRIMARY KEY NOT NULL,
                        exe_name TEXT,
                        core TEXT,
                        rom_extensions TEXT)"

    Invoke-SqliteQuery -Query $createPlatformsTableQuery -SQLiteConnection $dbConnection

    $createDailyPlaytimeTableQuery = "CREATE TABLE IF NOT EXISTS daily_playtime (
                        play_date TEXT PRIMARY KEY NOT NULL,
                        play_time INTEGER)"

    Invoke-SqliteQuery -Query $createDailyPlaytimeTableQuery -SQLiteConnection $dbConnection

    # Migration 1
    $addIdleTimeColumnInGamesTableQuery = "ALTER TABLE games ADD COLUMN idle_time INTEGER DEFAULT 0"
    $checkIdleTimeColumnInGamesTableQuery = "SELECT count(*) AS count FROM pragma_table_info('games') WHERE name='idle_time'"

    $checkResult = (Invoke-SqliteQuery -Query $checkIdleTimeColumnInGamesTableQuery -SQLiteConnection $dbConnection).count
    if ($checkResult -lt 1) {
        Invoke-SqliteQuery -Query $addIdleTimeColumnInGamesTableQuery -SQLiteConnection $dbConnection
    }
    # End Migration 1

    # Migration 2
    $addSessionCountColumnInGamesTableQuery = "ALTER TABLE games ADD COLUMN session_count INTEGER DEFAULT 0"
    $checkSessionCountColumnInGamesTableQuery = "SELECT count(*) AS count FROM pragma_table_info('games') WHERE name='session_count'"

    $checkResult = (Invoke-SqliteQuery -Query $checkSessionCountColumnInGamesTableQuery -SQLiteConnection $dbConnection).count
    if ($checkResult -lt 1) {
        Invoke-SqliteQuery -Query $addSessionCountColumnInGamesTableQuery -SQLiteConnection $dbConnection
    }
    # End Migration 2
    
    $dbConnection.Close()
    $dbConnection.Dispose()
}
catch {
    [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')    | out-null
    [System.Windows.Forms.MessageBox]::Show("Exception: $($_.Exception.Message). Check log for details", 'Gaming Gaiden', "OK", "Error")

    $timestamp = Get-date -f s
    Write-Output "$timestamp : Error: A user or system error has caused an exception. Database setup could not be finished. Check log for details." >> ".\GamingGaiden.log"
    Write-Output "$timestamp : Exception: $($_.Exception.Message)" >> ".\GamingGaiden.log"
    exit 1;
}

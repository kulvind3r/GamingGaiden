#Requires -Version 5.1

try {
    Import-Module ".\modules\PSSQLite"
    
    $DBConnection = New-SQLiteConnection -DataSource ".\GamingGaiden.db"

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

    # Migration 1
    $AddIdleTimeColumnInGamesTableQuery="ALTER TABLE games ADD COLUMN idle_time INTEGER DEFAULT 0"
    $CheckIdleTimeColumnInGamesTableQuery="SELECT count(*) AS count FROM pragma_table_info('games') WHERE name='idle_time'"

    $CheckResult = (Invoke-SqliteQuery -Query $CheckIdleTimeColumnInGamesTableQuery -SQLiteConnection $DBConnection).count
    if ($CheckResult -lt 1)
    {
        Invoke-SqliteQuery -Query $AddIdleTimeColumnInGamesTableQuery -SQLiteConnection $DBConnection
    }
    # End Migration 1

    # Migration 2
    $AddSessionCountColumnInGamesTableQuery="ALTER TABLE games ADD COLUMN session_count INTEGER DEFAULT 0"
    $CheckSessionCountColumnInGamesTableQuery="SELECT count(*) AS count FROM pragma_table_info('games') WHERE name='session_count'"

    $CheckResult = (Invoke-SqliteQuery -Query $CheckSessionCountColumnInGamesTableQuery -SQLiteConnection $DBConnection).count
    if ($CheckResult -lt 1)
    {
        Invoke-SqliteQuery -Query $AddSessionCountColumnInGamesTableQuery -SQLiteConnection $DBConnection
    }
    # End Migration 2
    
    $DBConnection.Close()
    $DBConnection.Dispose()
}
catch {
    [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')    | out-null
    [System.Windows.Forms.MessageBox]::Show("Exception: $($_.Exception.Message). Check log for details",'Gaming Gaiden', "OK", "Error")

    $Timestamp = Get-date -f s
    Write-Output "$Timestamp : Error: A user or system error has caused an exception. Database setup could not be finished. Check log for details." >> ".\GamingGaiden.log"
    Write-Output "$Timestamp : Exception: $($_.Exception.Message)" >> ".\GamingGaiden.log"
    exit 1;
}

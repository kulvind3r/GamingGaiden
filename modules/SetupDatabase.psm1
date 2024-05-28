function SetupDatabase() {
    try {
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
        $checkIdleTimeColumnInGamesTableQuery = "SELECT count(*) AS count FROM pragma_table_info('games') WHERE name='idle_time'"
        $checkResult = (Invoke-SqliteQuery -Query $checkIdleTimeColumnInGamesTableQuery -SQLiteConnection $dbConnection).count

        if ($checkResult -lt 1) {
            $addIdleTimeColumnInGamesTableQuery = "ALTER TABLE games ADD COLUMN idle_time INTEGER DEFAULT 0"
            Invoke-SqliteQuery -Query $addIdleTimeColumnInGamesTableQuery -SQLiteConnection $dbConnection
        }
        # End Migration 1

        # Migration 2
        $checkSessionCountColumnInGamesTableQuery = "SELECT count(*) AS count FROM pragma_table_info('games') WHERE name='session_count'"
        $checkResult = (Invoke-SqliteQuery -Query $checkSessionCountColumnInGamesTableQuery -SQLiteConnection $dbConnection).count
        
        if ($checkResult -lt 1) {
            $addSessionCountColumnInGamesTableQuery = "ALTER TABLE games ADD COLUMN session_count INTEGER DEFAULT 0"
            Invoke-SqliteQuery -Query $addSessionCountColumnInGamesTableQuery -SQLiteConnection $dbConnection
        }
        # End Migration 2

        # Migration 3
        $checkRomBasedNameColumnInGamesTableQuery = "SELECT count(*) AS count FROM pragma_table_info('games') WHERE name='rom_based_name'"
        $checkResult = (Invoke-SqliteQuery -Query $checkRomBasedNameColumnInGamesTableQuery -SQLiteConnection $dbConnection).count
        
        if ($checkResult -lt 1) {
            $addRomBasedNameColumnInGamesTableQuery = "ALTER TABLE games ADD COLUMN rom_based_name TEXT"
            $updateRomBasedNameColumnValues = "UPDATE games SET rom_based_name = name WHERE exe_name IN (SELECT DISTINCT exe_name FROM emulated_platforms)"

            Invoke-SqliteQuery -Query $addRomBasedNameColumnInGamesTableQuery -SQLiteConnection $dbConnection
            Invoke-SqliteQuery -Query $updateRomBasedNameColumnValues -SQLiteConnection $dbConnection
        }
        # End Migration 3

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
}
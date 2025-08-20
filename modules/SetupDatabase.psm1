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
                            platform TEXT,
                            disable_idle_detection BOOLEAN)"

        Invoke-SqliteQuery -Query $createGamesTableQuery -SQLiteConnection $dbConnection | Out-Null

        $createPlatformsTableQuery = "CREATE TABLE IF NOT EXISTS emulated_platforms (
                            name TEXT PRIMARY KEY NOT NULL,
                            exe_name TEXT,
                            core TEXT,
                            rom_extensions TEXT)"

        Invoke-SqliteQuery -Query $createPlatformsTableQuery -SQLiteConnection $dbConnection | Out-Null

        $createDailyPlaytimeTableQuery = "CREATE TABLE IF NOT EXISTS daily_playtime (
                            play_date TEXT PRIMARY KEY NOT NULL,
                            play_time INTEGER)"

        Invoke-SqliteQuery -Query $createDailyPlaytimeTableQuery -SQLiteConnection $dbConnection | Out-Null

        $createPCTableQuery = "CREATE TABLE IF NOT EXISTS gaming_pcs (
                            name TEXT PRIMARY KEY NOT NULL,
                            icon BLOB,
                            cost TEXT,
                            currency TEXT,
                            start_date INTEGER,
                            end_date INTEGER,
                            current TEXT)"

        Invoke-SqliteQuery -Query $createPCTableQuery -SQLiteConnection $dbConnection | Out-Null

        $createSessionHistoryTableQuery = "CREATE TABLE IF NOT EXISTS session_history (
                                    game_name TEXT,
                                    session_start_time INTEGER,
                                    session_duration_minutes INTEGER
        )"
        Invoke-SqliteQuery -Query $createSessionHistoryTableQuery -SQLiteConnection $dbConnection | Out-Null

        $gamesTableSchema = Invoke-SqliteQuery -query "PRAGMA table_info('games')" -SQLiteConnection $dbConnection

        # Migration 1
        if (-Not $gamesTableSchema.name.Contains("idle_time")) {
            $addIdleTimeColumnInGamesTableQuery = "ALTER TABLE games ADD COLUMN idle_time INTEGER DEFAULT 0"
            Invoke-SqliteQuery -Query $addIdleTimeColumnInGamesTableQuery -SQLiteConnection $dbConnection | Out-Null
        }
        # End Migration 1

        # Migration 2
        if (-Not $gamesTableSchema.name.Contains("session_count")) {
            $addSessionCountColumnInGamesTableQuery = "ALTER TABLE games ADD COLUMN session_count INTEGER DEFAULT 0"
            Invoke-SqliteQuery -Query $addSessionCountColumnInGamesTableQuery -SQLiteConnection $dbConnection | Out-Null
        }
        # End Migration 2

        # Migration 3
        if (-Not $gamesTableSchema.name.Contains("rom_based_name")) {
            $addRomBasedNameColumnInGamesTableQuery = "ALTER TABLE games ADD COLUMN rom_based_name TEXT"
            $updateRomBasedNameColumnValues = "UPDATE games SET rom_based_name = name WHERE exe_name IN (SELECT DISTINCT exe_name FROM emulated_platforms)"

            Invoke-SqliteQuery -Query $addRomBasedNameColumnInGamesTableQuery -SQLiteConnection $dbConnection | Out-Null
            Invoke-SqliteQuery -Query $updateRomBasedNameColumnValues -SQLiteConnection $dbConnection | Out-Null
        }
        # End Migration 3

        # Migration 4
        if (-Not $gamesTableSchema.name.Contains("status")) {
            $addStatusColumnInGamesTableQuery = "ALTER TABLE games ADD COLUMN status TEXT"

            Invoke-SqliteQuery -Query $addStatusColumnInGamesTableQuery -SQLiteConnection $dbConnection | Out-Null
        }
        # End Migration 4

        # Migration 5
        if (-Not $gamesTableSchema.name.Contains("color_hex")) {
            $addColorHexColumnInGamesTableQuery = "ALTER TABLE games ADD COLUMN color_hex TEXT"

            Invoke-SqliteQuery -Query $addColorHexColumnInGamesTableQuery -SQLiteConnection $dbConnection | Out-Null
        }
        # End Migration 5

        # Migration 6
        if (-Not $gamesTableSchema.name.Contains("disable_idle_detection")) {
            $addIdleDetectionColumnInGamesTableQuery = "ALTER TABLE games ADD COLUMN disable_idle_detection BOOLEAN DEFAULT 0"
            Invoke-SqliteQuery -Query $addIdleDetectionColumnInGamesTableQuery -SQLiteConnection $dbConnection | Out-Null
        }
        # End Migration 6

        # Backfill color_hex for existing games
        Log "Checking for games with missing color data."
        $gamesMissingColor = Invoke-SqliteQuery -Query "SELECT name, icon FROM games WHERE color_hex IS NULL" -SQLiteConnection $dbConnection
        if ($gamesMissingColor.Length -gt 0) {
            Log "Found $($gamesMissingColor.Length) games with missing color data. Backfilling now..."
            foreach ($game in $gamesMissingColor) {
                $gameName = $game.name
                $iconBytes = $game.icon
                $dominantColor = Get-DominantColor $iconBytes

                $updateColorQuery = "UPDATE games SET color_hex = @color WHERE name = @name"
                $updateParams = @{
                    color = $dominantColor
                    name = $gameName
                }
                Invoke-SqliteQuery -Query $updateColorQuery -SQLiteConnection $dbConnection -SqlParameters $updateParams | Out-Null
                Log "Updated color for $gameName to $dominantColor"
            }
            Log "Color backfill complete."
        }

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
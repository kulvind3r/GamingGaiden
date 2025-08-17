class Game {
    [ValidateNotNullOrEmpty()][string]$Icon
    [ValidateNotNullOrEmpty()][string]$Name
    [ValidateNotNullOrEmpty()][string]$Platform
    [ValidateNotNullOrEmpty()][string]$Playtime
    [ValidateNotNullOrEmpty()][string]$Session_Count
    [ValidateNotNullOrEmpty()][string]$Completed
    [ValidateNotNullOrEmpty()][string]$Last_Played_On

    Game($IconUri, $Name, $Platform, $Playtime, $SessionCount, $Completed, $LastPlayDate) {
        $this.Icon = $IconUri
        $this.Name = $Name
        $this.Platform = $Platform
        $this.Playtime = $Playtime
        $this.Session_Count = $SessionCount
        $this.Completed = $Completed
        $this.Last_Played_On = $LastPlayDate
    }
}

class GamingPC {
    [ValidateNotNullOrEmpty()][string]$IconUri
    [ValidateNotNullOrEmpty()][string]$Name
    [ValidateNotNullOrEmpty()][string]$Current
    [ValidateNotNullOrEmpty()][string]$Cost
    [ValidateNotNullOrEmpty()][string]$Currency
    [ValidateNotNullOrEmpty()][string]$StartDate
    [ValidateNotNullOrEmpty()][string]$EndDate
    [ValidateNotNullOrEmpty()][string]$Age
    [ValidateNotNullOrEmpty()][string]$TotalHours
    

    GamingPC($IconUri, $Name, $Current, $Cost, $Currency, $StartDate, $EndDate, $Age, $TotalHours) {
        $this.IconUri = $IconUri
        $this.Name = $Name
        $this.Current = $Current
        $this.Cost = $Cost
        $this.Currency = $Currency
        $this.StartDate = $StartDate
        $this.EndDate = $EndDate
        $this.Age = $Age
        $this.TotalHours = $TotalHours
    }
}

class Session {
    [ValidateNotNullOrEmpty()][string]$Icon
    [ValidateNotNullOrEmpty()][string]$Name
    [ValidateNotNullOrEmpty()][string]$Duration
    [ValidateNotNullOrEmpty()][string]$StartTime

    Session($IconUri, $Name, $Duration, $StartTime) {
        $this.Icon = $IconUri
        $this.Name = $Name
        $this.Duration = $Duration
        $this.StartTime = $StartTime
    }
}

function UpdateAllStatsInBackground() {
    RenderGameList -InBackground $true
    RenderSummary -InBackground $true
    RenderGamingTime -InBackground $true
    RenderGamesPerPlatform -InBackground $true
    RenderMostPlayed -InBackground $true
    RenderIdleTime -InBackground $true
}

function RenderGameList() {
    param(
        [bool]$InBackground = $false
    )

    Log "Rendering all games list."

    $workingDirectory = (Get-Location).Path

    $getAllGamesQuery = "SELECT name, icon, platform, play_time, session_count, completed, last_play_date, status FROM games"
    $gameRecords = RunDBQuery $getAllGamesQuery
    if ($gameRecords.Length -eq 0) {
        if(-Not $InBackground) {
            ShowMessage "No Games found in DB. Please add some games first." "OK" "Error"
        }
        Log "Error: Games list empty. Returning"
        return $false
    }

    $getMaxPlayTime = "SELECT max(play_time) as 'max_play_time' FROM games"
    $maxPlayTime = (RunDBQuery $getMaxPlayTime).max_play_time

    $games = [System.Collections.Generic.List[Game]]::new()
    $iconUri = $null
    $totalPlayTime = $null

    foreach ($gameRecord in $gameRecords) {
        $name = $gameRecord.name
        $imageFileName = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($name))

        # Check if image is pre loaded for ui. Render if not found.
        if ( (Test-Path "$workingDirectory\ui\resources\images\$imageFileName.jpg") ) {
            $iconUri = "<img src=`".\resources\images\$imageFileName.jpg`">"
        }
        elseif ( (Test-Path "$workingDirectory\ui\resources\images\$imageFileName.png") ) {
            $iconUri = "<img src=`".\resources\images\$imageFileName.png`">"
        }
        else {
            $iconByteStream = [System.IO.MemoryStream]::new($gameRecord.icon)
            $iconBitmap = [System.Drawing.Bitmap]::FromStream($iconByteStream)

            if ($iconBitmap.PixelFormat -eq "Format32bppArgb") {
                $iconBitmap.Save("$workingDirectory\ui\resources\images\$imageFileName.png", [System.Drawing.Imaging.ImageFormat]::Png)
                $iconUri = "<img src=`".\resources\images\$imageFileName.png`">"
            }
            else {
                $iconBitmap.Save("$workingDirectory\ui\resources\images\$imageFileName.jpg", [System.Drawing.Imaging.ImageFormat]::Jpeg)
                $iconUri = "<img src=`".\resources\images\$imageFileName.jpg`">"
            }

            $iconBitmap.Dispose()
        }

        $statusUri = "<div>Finished</div><img src=`".\resources\images\finished.png`">"
        if ($gameRecord.completed -eq 'FALSE') {
            $statusUri = "<div>Playing</div><img src=`".\resources\images\playing.png`">"
        }
        if ($gameRecord.status -eq 'dropped') {
            $statusUri = "<div>Dropped</div><img title=`"Utter Garbage!!`" src=`".\resources\images\dropped.png`">"
        }
        if ($gameRecord.status -eq 'hold') {
            $statusUri = "<div>Pick Later</div><img src=`".\resources\images\hold.png`">"
        }
        if ($gameRecord.status -eq 'forever') {
            $statusUri = "<div>Forever</div><img src=`".\resources\images\forever.png`">"
        }

        $currentGame = [Game]::new($iconUri, $name, $gameRecord.platform, $gameRecord.play_time, $gameRecord.session_count, $statusUri, $gameRecord.last_play_date)

        # Assign to null to avoid appending output to pipeline, improves performance and resource consumption
        $null = $games.Add($currentGame)

        $totalPlayTime += $gameRecord.play_time
    }

    $totalPlayTimeString = PlayTimeMinsToString $totalPlayTime

    $table = $games | ConvertTo-Html -Fragment

    $report = (Get-Content $workingDirectory\ui\templates\AllGames.html.template) -replace "_GAMESTABLE_", $table
    $report = $report -replace "Last_Played_On", "Last Played On"
    $report = $report -replace "Session_Count", "Sessions"
    $report = $report -replace "Completed", "Status"
    $report = $report -replace "_MAXPLAYTIME_", $maxPlayTime
    $report = $report -replace "_TOTALGAMECOUNT_", $games.Count
    $report = $report -replace "_TOTALPLAYTIME_", $totalPlayTimeString

    [System.Web.HttpUtility]::HtmlDecode($report) | Out-File -encoding UTF8 $workingDirectory\ui\AllGames.html
}

function RenderGamingTime() {
    param(
        [bool]$InBackground = $false
    )

    Log "Rendering time spent gaming"

    $workingDirectory = (Get-Location).Path

    $getDailyPlayTimeDataQuery = "SELECT play_date as date, play_time as time FROM daily_playtime ORDER BY date ASC"
    $dailyPlayTimeData = RunDBQuery $getDailyPlayTimeDataQuery
    if ($dailyPlayTimeData.Length -eq 0) {
        if(-Not $InBackground) {
            ShowMessage "No Records of Game Time found in DB. Please play some games first." "OK" "Error"
        }
        Log "Error: Game time records empty. Returning"
        return $false
    }

    $table = $dailyPlayTimeData | ConvertTo-Html -Fragment

    $report = (Get-Content $workingDirectory\ui\templates\GamingTime.html.template) -replace "_DAILYPLAYTIMETABLE_", $table

    [System.Web.HttpUtility]::HtmlDecode($report) | Out-File -encoding UTF8 $workingDirectory\ui\GamingTime.html
}

function RenderMostPlayed() {
    param(
        [bool]$InBackground = $false
    )

    Log "Rendering most played"

    $workingDirectory = (Get-Location).Path

    $getGamesPlayTimeDataQuery = "SELECT name, play_time as time FROM games Order By play_time DESC"
    $gamesPlayTimeData = RunDBQuery $getGamesPlayTimeDataQuery
    if ($gamesPlayTimeData.Length -eq 0) {
        if(-Not $InBackground) {
            ShowMessage "No Games found in DB. Please add some games first." "OK" "Error"
        }
        Log "Error: Games list empty. Returning"
        return $false
    }

    $table = $gamesPlayTimeData | ConvertTo-Html -Fragment

    $report = (Get-Content $workingDirectory\ui\templates\MostPlayed.html.template) -replace "_GAMESPLAYTIMETABLE_", $table

    [System.Web.HttpUtility]::HtmlDecode($report) | Out-File -encoding UTF8 $workingDirectory\ui\MostPlayed.html
}

function RenderSummary() {
    param(
        [bool]$InBackground = $false
    )

    Log "Rendering life time summary"

    $workingDirectory = (Get-Location).Path

    $getGamesPlayTimeVsSessionDataQuery = "SELECT name, play_time, session_count, completed, status FROM games"
    $gamesPlayTimeVsSessionData = RunDBQuery $getGamesPlayTimeVsSessionDataQuery
    if ($gamesPlayTimeVsSessionData.Length -eq 0) {
        if(-Not $InBackground) {
            ShowMessage "No Games found in DB. Please add some games first." "OK" "Error"
        }
        Log "Error: Games list empty. Returning"
        return $false
    }

    $getGamingPCsQuery = "SELECT gp.*,
                            SUM(dp.play_time) / 60 AS total_hours,
                            CAST((julianday(COALESCE(datetime(gp.end_date, 'unixepoch'), datetime('now'))) - julianday(datetime(gp.start_date, 'unixepoch'))) / 365.25 AS INTEGER) AS age_years,
                            CAST((julianday(COALESCE(datetime(gp.end_date, 'unixepoch'), datetime('now'))) - julianday(datetime(gp.start_date, 'unixepoch'))) % 365.25 / 30.4375 AS INTEGER) AS age_months
                        FROM 
                            gaming_pcs gp
                        JOIN 
                            daily_playtime dp 
                        ON 
                            dp.play_date BETWEEN DATE(datetime(gp.start_date, 'unixepoch')) 
                                            AND DATE(COALESCE(datetime(gp.end_date, 'unixepoch'), datetime('now')))
                        GROUP BY 
                            gp.name
                        ORDER BY
                            gp.current DESC, gp.end_date DESC;"
    $gamingPCData = RunDBQuery $getGamingPCsQuery

    $TotalAnnualGamingHoursQuery = "SELECT 
                                    strftime('%Y', play_date) AS Year, 
                                    SUM(ROUND(play_time/60.0,2)) AS TotalPlaytime 
                                   FROM daily_playtime GROUP BY strftime('%Y', play_date) ORDER BY Year;"

    $totalAnnualGamingHoursData = RunDBQuery $TotalAnnualGamingHoursQuery

    $gamingPCs = [System.Collections.Generic.List[GamingPC]]::new()
    $pcIconUri = $null

    foreach ($gamingPCRecord in $gamingPCData) {
        $name = $gamingPCRecord.name
        $imageFileName = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($name))
        
        $iconByteStream = [System.IO.MemoryStream]::new($gamingPCRecord.icon)
        $iconBitmap = [System.Drawing.Bitmap]::FromStream($iconByteStream)

        if ($iconBitmap.PixelFormat -eq "Format32bppArgb") {
            $iconBitmap.Save("$workingDirectory\ui\resources\images\$imageFileName.png", [System.Drawing.Imaging.ImageFormat]::Png)
            $pcIconUri = "<img src=`".\resources\images\$imageFileName.png`">"
        }
        else {
            $iconBitmap.Save("$workingDirectory\ui\resources\images\$imageFileName.jpg", [System.Drawing.Imaging.ImageFormat]::Jpeg)
            $pcIconUri = "<img src=`".\resources\images\$imageFileName.jpg`">"
        }

        $iconBitmap.Dispose()

        $pcAge = "{0} Years and {1} Months" -f $gamingPCRecord.age_years, $gamingPCRecord.age_months

        $thisPC = [GamingPC]::new($pcIconUri, $name, $gamingPCRecord.current, $gamingPCRecord.cost, $gamingPCRecord.currency, $gamingPCRecord.start_date, $gamingPCRecord.end_date, $pcAge, $gamingPCRecord.total_hours)

        $null = $gamingPCs.add($thisPC)
    }

    $getGamesSummaryDataQuery = "SELECT COUNT(*) AS total_games, SUM(play_time) AS total_play_time, SUM(session_count) AS total_sessions, SUM(idle_time) AS total_idle_time FROM games"
    $gamesSummaryData = RunDBQuery $getGamesSummaryDataQuery

    $getPlayDateSummaryQuery = "SELECT MIN(play_date) AS min_play_date, MAX(play_date) AS max_play_date FROM daily_playtime"
    $playDateSummary = RunDBQuery $getPlayDateSummaryQuery

    if ($null -eq $playDateSummary.min_play_date -or $null -eq $playDateSummary.max_play_date) {
        if(-Not $InBackground) {
            ShowMessage "No play time found in DB. Please play some games first." "OK" "Error"
        }
        Log "Error: No playtime found in DB. Returning"
        return $false
    }

    $startDate = Get-Date -Date $playDateSummary.min_play_date -Format "MMM yyyy"
    $endDate = Get-Date -Date $playDateSummary.max_play_date -Format "MMM yyyy"

    $totalPlayTime = PlayTimeMinsToString $gamesSummaryData.total_play_time
    $totalIdleTime = PlayTimeMinsToString $gamesSummaryData.total_idle_time

    $summaryStatement = "<b>Duration: </b>$startDate - $endDate. <b>Games: </b>$($gamesSummaryData.total_games). <b>Sessions: </b>$($gamesSummaryData.total_sessions).<br><br><b>Play time: </b>$totalPlayTime. <b>Idle time: </b>$totalIdleTime."

    $summaryTable = $gamesPlayTimeVsSessionData | ConvertTo-Html -Fragment
    $pcTable = $gamingPCs | ConvertTo-Html -Fragment
    $annualHoursTable = $totalAnnualGamingHoursData | ConvertTo-Html -Fragment

    $report = (Get-Content $workingDirectory\ui\templates\Summary.html.template) -replace "_SUMMARYTABLE_", $summaryTable
    $report = $report -replace "_SUMMARYSTATEMENT_", $summaryStatement
    $report = $report -replace "_ANNUALGAMINGHOURSTABLE_", $annualHoursTable
    $report = $report -replace "_PCTABLE_", $pcTable

    [System.Web.HttpUtility]::HtmlDecode($report) | Out-File -encoding UTF8 $workingDirectory\ui\Summary.html
}

function RenderIdleTime() {
    param(
        [bool]$InBackground = $false
    )

    Log "Rendering Idle time"

    $workingDirectory = (Get-Location).Path

    $getGamesIdleTimeDataQuery = "SELECT name, idle_time as time FROM games WHERE idle_time > 0 ORDER BY idle_time DESC"
    $gamesIdleTimeData = RunDBQuery $getGamesIdleTimeDataQuery
    if ($gamesIdleTimeData.Length -eq 0) {
        if(-Not $InBackground) {
            ShowMessage "No Idle Games found in DB." "OK" "Error"
        }
        Log "Error: Idle Games list empty. Returning"
        return $false
    }

    $getTotalIdleTimeQuery = "SELECT SUM(idle_time) as total_idle_time FROM games"
    $totalIdleTime = (RunDBQuery $getTotalIdleTimeQuery).total_idle_time
    $totalIdleTimeString = PlayTimeMinsToString $totalIdleTime

    $table = $gamesIdleTimeData | ConvertTo-Html -Fragment

    $report = (Get-Content $workingDirectory\ui\templates\IdleTime.html.template) -replace "_GAMESIDLETIMETABLE_", $table
    $report = $report -replace "_TOTALIDLETIME_", $totalIdleTimeString

    [System.Web.HttpUtility]::HtmlDecode($report) | Out-File -encoding UTF8 $workingDirectory\ui\IdleTime.html
}

function RenderGamesPerPlatform() {
    param(
        [bool]$InBackground = $false
    )

    Log "Rendering games per platform"

    $workingDirectory = (Get-Location).Path

    $getGamesPerPlatformDataQuery = "SELECT  platform, COUNT(name) FROM games GROUP BY platform"
    $getGamesPerPlatformData = RunDBQuery $getGamesPerPlatformDataQuery
    if ($getGamesPerPlatformData.Length -eq 0) {
        if(-Not $InBackground) {
            ShowMessage "No Games found in DB. Please add some games first." "OK" "Error"
        }
        Log "Error: Games list empty. Returning"
        return $false
    }

    $table = $getGamesPerPlatformData | ConvertTo-Html -Fragment

    $report = (Get-Content $workingDirectory\ui\templates\GamesPerPlatform.html.template) -replace "_GAMESPERPLATFORMTABLE_", $table

    [System.Web.HttpUtility]::HtmlDecode($report) | Out-File -encoding UTF8 $workingDirectory\ui\GamesPerPlatform.html
}

function RenderSessionHistory() {
    param(
        [bool]$InBackground = $false
    )

    Log "Rendering session history"

    $workingDirectory = (Get-Location).Path

    $getSessionHistoryQuery = "SELECT sh.game_name, sh.session_start_time, sh.session_duration_minutes, g.icon FROM session_history sh JOIN games g ON sh.game_name = g.name ORDER BY sh.session_start_time DESC LIMIT 50"
    $sessionRecords = RunDBQuery $getSessionHistoryQuery
    if ($sessionRecords.Length -eq 0) {
        if(-Not $InBackground) {
            ShowMessage "No session history found in DB. Please play some games first." "OK" "Error"
        }
        Log "Error: Session history empty. Returning"
        return $false
    }

    $sessions = [System.Collections.Generic.List[Session]]::new()
    $iconUri = $null

    foreach ($sessionRecord in $sessionRecords) {
        $name = $sessionRecord.game_name
        $imageFileName = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($name))

        if ( (Test-Path "$workingDirectory\ui\resources\images\$imageFileName.jpg") ) {
            $iconUri = "<img src=`".\resources\images\$imageFileName.jpg`">"
        }
        elseif ( (Test-Path "$workingDirectory\ui\resources\images\$imageFileName.png") ) {
            $iconUri = "<img src=`".\resources\images\$imageFileName.png`">"
        }
        else {
            $iconByteStream = [System.IO.MemoryStream]::new($sessionRecord.icon)
            $iconBitmap = [System.Drawing.Bitmap]::FromStream($iconByteStream)

            if ($iconBitmap.PixelFormat -eq "Format32bppArgb") {
                $iconBitmap.Save("$workingDirectory\ui\resources\images\$imageFileName.png", [System.Drawing.Imaging.ImageFormat]::Png)
                $iconUri = "<img src=`".\resources\images\$imageFileName.png`">"
            }
            else {
                $iconBitmap.Save("$workingDirectory\ui\resources\images\$imageFileName.jpg", [System.Drawing.Imaging.ImageFormat]::Jpeg)
                $iconUri = "<img src=`".\resources\images\$imageFileName.jpg`">"
            }

            $iconBitmap.Dispose()
        }

        $currentSession = [Session]::new($iconUri, $name, $sessionRecord.session_duration_minutes, $sessionRecord.session_start_time)
        $null = $sessions.Add($currentSession)
    }

    $table = $sessions | ConvertTo-Html -Fragment

    $report = (Get-Content $workingDirectory\ui\templates\SessionHistory.html.template) -replace "_SESSIONSTABLE_", $table
    $report = $report -replace "StartTime", "Session Start"
    $report = $report -replace "Name", "Game"

    [System.Web.HttpUtility]::HtmlDecode($report) | Out-File -encoding UTF8 $workingDirectory\ui\SessionHistory.html
}

function RenderAboutDialog() {
    $aboutForm = CreateForm "About" 350 280 ".\icons\running.ico"

    $pictureBox = CreatePictureBox "./icons/banner.png" 0 10 345 70
    $aboutForm.Controls.Add($pictureBox)

    $labelVersion = CreateLabel "v2025.07.28" 145 90
    $aboutForm.Controls.Add($labelVersion)

    $textCopyRight = [char]::ConvertFromUtf32(0x000000A9) + " 2023 Kulvinder Singh"
    $labelCopyRight = CreateLabel $textCopyRight 112 110
    $aboutForm.Controls.Add($labelCopyRight)

    $labelHome = New-Object Windows.Forms.LinkLabel
    $labelHome.Text = "Home"
    $labelHome.Location = New-Object Drawing.Point(160, 140)
    $labelHome.AutoSize = $true
    $labelHome.Add_LinkClicked({
            Start-Process "https://github.com/kulvind3r/GamingGaiden"
        })
    $aboutForm.Controls.Add($labelHome)

    $labelAttributions = New-Object Windows.Forms.LinkLabel
    $labelAttributions.Text = "Open Source And Original Art Attributions"
    $labelAttributions.Location = New-Object Drawing.Point(70, 165)
    $labelAttributions.AutoSize = $true
    $labelAttributions.Add_LinkClicked({
            Start-Process "https://github.com/kulvind3r/GamingGaiden#attributions"
        })
    $aboutForm.Controls.Add($labelAttributions)

    $buttonClose = CreateButton "Close" 140 205; $buttonClose.Add_Click({ $pictureBox.Image.Dispose(); $pictureBox.Dispose(); $aboutForm.Dispose() }); $aboutForm.Controls.Add($buttonClose)

    $aboutForm.ShowDialog()
    $pictureBox.Image.Dispose(); $pictureBox.Dispose();
    $aboutForm.Dispose()
}

function RenderQuickView() {
    $quickViewForm = CreateForm "Quick View" 420 400 ".\icons\running.ico"
    $quickViewForm.MaximizeBox = $false
    $quickViewForm.MinimizeBox = $false
    $quickViewForm.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual

    $screenBounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $quickViewForm.Left = $screenBounds.Width - $quickViewForm.Width - 20
    $quickViewForm.Top = $screenBounds.Height - $quickViewForm.Height - 60

    $dataGridView = New-Object System.Windows.Forms.DataGridView
    $dataGridView.Dock = [System.Windows.Forms.DockStyle]::Fill
    $dataGridView.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $dataGridView.RowTemplate.Height = 65
    $dataGridView.AllowUserToAddRows = $false
    $dataGridView.RowHeadersVisible = $false
    $dataGridView.CellBorderStyle = "None"
    $dataGridView.AutoSizeColumnsMode = "Fill"
    $dataGridView.Enabled = $false
    $dataGridView.DefaultCellStyle.Padding = New-Object System.Windows.Forms.Padding(2, 2, 2, 2)
    $dataGridView.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)

    $toggleSwitch = New-Object System.Windows.Forms.CheckBox
    $toggleSwitch.Text = "Show Most Played"
    $toggleSwitch.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $toggleSwitch.Appearance = [System.Windows.Forms.Appearance]::Button
    $toggleSwitch.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $toggleSwitch.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $toggleSwitch.FlatAppearance.BorderSize = 0

    $doubleBufferProperty = $dataGridView.GetType().GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Instance)
    $doubleBufferProperty.SetValue($dataGridView, $true, $null)

    function Load-RecentSessions {
        $quickViewForm.text = "Recent Sessions"
        $toggleSwitch.Text = "Show Most Played"
        $dataGridView.Rows.Clear()
        $dataGridView.Columns.Clear()

        $lastFiveSessionsQuery = "SELECT sh.game_name, g.icon, sh.session_duration_minutes, sh.session_start_time FROM session_history sh JOIN games g ON sh.game_name = g.name ORDER BY sh.session_start_time DESC LIMIT 5"
        $sessionRecords = RunDBQuery $lastFiveSessionsQuery
        if ($sessionRecords.Length -eq 0) {
            ShowMessage "No sessions found in DB. Please play some games first." "OK" "Error"
            Log "Error: Session history empty. Returning"
            $quickViewForm.Close()
            return
        }

        $IconColumn = New-Object System.Windows.Forms.DataGridViewImageColumn
        $IconColumn.Name = "icon"
        $IconColumn.HeaderText = ""
        $IconColumn.ImageLayout = [System.Windows.Forms.DataGridViewImageCellLayout]::Zoom
        $null = $dataGridView.Columns.Add($IconColumn)

        $null = $dataGridView.Columns.Add("name", "Name")
        $null = $dataGridView.Columns.Add("duration", "Duration")
        $null = $dataGridView.Columns.Add("played_on", "Played On")

        foreach ($column in $dataGridView.Columns) {
            $column.Resizable = [System.Windows.Forms.DataGridViewTriState]::False
        }

        foreach ($row in $sessionRecords) {
            $iconByteStream = [System.IO.MemoryStream]::new($row.icon)
            $gameIcon = [System.Drawing.Bitmap]::FromStream($iconByteStream)
            $minutes = $null; $hours = [math]::divrem($row.session_duration_minutes, 60, [ref]$minutes);
            $durationFormatted = "{0} Hr {1} Min" -f $hours, $minutes
            [datetime]$origin = '1970-01-01 00:00:00'
            $dateFormatted = $origin.AddSeconds($row.session_start_time).ToLocalTime().ToString("dd MMM HH:mm")
            $null = $dataGridView.Rows.Add($gameIcon, $row.game_name, $durationFormatted, $dateFormatted)
        }
    }

    function Load-MostPlayed {
        $quickViewForm.text = "Most Played Games"
        $toggleSwitch.Text = "Show Recent Sessions"
        $dataGridView.Rows.Clear()
        $dataGridView.Columns.Clear()

        $mostPlayedQuery = "SELECT name, icon, play_time, last_play_date FROM games ORDER BY play_time DESC LIMIT 5"
        $gameRecords = RunDBQuery $mostPlayedQuery
        if ($gameRecords.Length -eq 0) {
            ShowMessage "No Games found in DB. Please add some games first." "OK" "Error"
            Log "Error: Games list empty. Returning"
            $quickViewForm.Close()
            return
        }

        $IconColumn = New-Object System.Windows.Forms.DataGridViewImageColumn
        $IconColumn.Name = "icon"
        $IconColumn.HeaderText = ""
        $IconColumn.ImageLayout = [System.Windows.Forms.DataGridViewImageCellLayout]::Zoom
        $null = $dataGridView.Columns.Add($IconColumn)

        $null = $dataGridView.Columns.Add("name", "Name")
        $null = $dataGridView.Columns.Add("play_time", "Playtime")
        $null = $dataGridView.Columns.Add("last_play_date", "Last Played On")

        foreach ($column in $dataGridView.Columns) {
            $column.Resizable = [System.Windows.Forms.DataGridViewTriState]::False
        }

        foreach ($row in $gameRecords) {
            $iconByteStream = [System.IO.MemoryStream]::new($row.icon)
            $gameIcon = [System.Drawing.Bitmap]::FromStream($iconByteStream)
            $minutes = $null; $hours = [math]::divrem($row.play_time, 60, [ref]$minutes);
            $playTimeFormatted = "{0} Hr {1} Min" -f $hours, $minutes
            [datetime]$origin = '1970-01-01 00:00:00'
            $dateFormatted = $origin.AddSeconds($row.last_play_date).ToLocalTime().ToString("dd MMMM yyyy")
            $null = $dataGridView.Rows.Add($gameIcon, $row.name, $playTimeFormatted, $dateFormatted)
        }
    }

    $toggleSwitch.Add_CheckedChanged({
        if ($toggleSwitch.Checked) {
            Load-MostPlayed
        } else {
            Load-RecentSessions
        }
        $dataGridView.ClearSelection()
    })

    $quickViewForm.Controls.Add($dataGridView)
    $quickViewForm.Controls.Add($toggleSwitch)

    $quickViewForm.Add_Deactivate({ $quickViewForm.Dispose() })
    $quickViewForm.Add_Shown({
        Load-RecentSessions
        $dataGridView.ClearSelection()
        $quickViewForm.Activate()
    })

    $quickViewForm.ShowDialog()
}
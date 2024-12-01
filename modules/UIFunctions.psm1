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

function RenderGameList() {
    Log "Rendering all games list."

    $workingDirectory = (Get-Location).Path

    $getAllGamesQuery = "SELECT name, icon, platform, play_time, session_count, completed, last_play_date, status FROM games"
    $gameRecords = RunDBQuery $getAllGamesQuery
    if ($gameRecords.Length -eq 0) {
        ShowMessage "No Games found in DB. Please add some games first." "OK" "Error"
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
    Log "Rendering time spent gaming"

    $workingDirectory = (Get-Location).Path

    $getDailyPlayTimeDataQuery = "SELECT play_date as date, play_time as time FROM daily_playtime ORDER BY date ASC"
    $dailyPlayTimeData = RunDBQuery $getDailyPlayTimeDataQuery
    if ($dailyPlayTimeData.Length -eq 0) {
        ShowMessage "No Records of Game Time found in DB. Please play some games first." "OK" "Error"
        Log "Error: Game time records empty. Returning"
        return $false
    }

    $table = $dailyPlayTimeData | ConvertTo-Html -Fragment

    $report = (Get-Content $workingDirectory\ui\templates\GamingTime.html.template) -replace "_DAILYPLAYTIMETABLE_", $table

    [System.Web.HttpUtility]::HtmlDecode($report) | Out-File -encoding UTF8 $workingDirectory\ui\GamingTime.html
}

function RenderMostPlayed() {
    Log "Rendering most played"

    $workingDirectory = (Get-Location).Path

    $getGamesPlayTimeDataQuery = "SELECT name, play_time as time FROM games Order By play_time DESC"
    $gamesPlayTimeData = RunDBQuery $getGamesPlayTimeDataQuery
    if ($gamesPlayTimeData.Length -eq 0) {
        ShowMessage "No Games found in DB. Please add some games first." "OK" "Error"
        Log "Error: Games list empty. Returning"
        return $false
    }

    $table = $gamesPlayTimeData | ConvertTo-Html -Fragment

    $report = (Get-Content $workingDirectory\ui\templates\MostPlayed.html.template) -replace "_GAMESPLAYTIMETABLE_", $table

    [System.Web.HttpUtility]::HtmlDecode($report) | Out-File -encoding UTF8 $workingDirectory\ui\MostPlayed.html
}

function RenderSummary() {
    Log "Rendering life time summary"

    $workingDirectory = (Get-Location).Path

    $getGamesPlayTimeVsSessionDataQuery = "SELECT name, play_time, session_count, completed FROM games"
    $gamesPlayTimeVsSessionData = RunDBQuery $getGamesPlayTimeVsSessionDataQuery
    if ($gamesPlayTimeVsSessionData.Length -eq 0) {
        ShowMessage "No Games found in DB. Please add some games first." "OK" "Error"
        Log "Error: Games list empty. Returning"
        return $false
    }

    $getGamesSummaryDataQuery = "SELECT COUNT(*) AS total_games, SUM(play_time) AS total_play_time, SUM(session_count) AS total_sessions, SUM(idle_time) AS total_idle_time FROM games"
    $gamesSummaryData = RunDBQuery $getGamesSummaryDataQuery

    $getPlayDateSummaryQuery = "SELECT MIN(play_date) AS min_play_date, MAX(play_date) AS max_play_date FROM daily_playtime"
    $playDateSummary = RunDBQuery $getPlayDateSummaryQuery

    $startDate = Get-Date -Date $playDateSummary.min_play_date -Format "MMM yyyy"
    $endDate = Get-Date -Date $playDateSummary.max_play_date -Format "MMM yyyy"

    $totalPlayTime = PlayTimeMinsToString $gamesSummaryData.total_play_time
    $totalIdleTime = PlayTimeMinsToString $gamesSummaryData.total_idle_time

    $gameString = "game"
    $sessionString = "session"
    if ($gamesSummaryData.total_games -gt 1) {
        $gameString = "games"
    }
    if ($gamesSummaryData.total_sessions -gt 1) {
        $sessionString = "sessions"
    }

    $summaryStatement = "From <b>$startDate to $endDate</b> you played <b>$($gamesSummaryData.total_games) $gameString</b> in <b>$($gamesSummaryData.total_sessions) $sessionString</b>. Total <b>play time is $totalPlayTime</b> with <b>$totalIdleTime spent idling</b>."

    $table = $gamesPlayTimeVsSessionData | ConvertTo-Html -Fragment

    $report = (Get-Content $workingDirectory\ui\templates\Summary.html.template) -replace "_SUMMARYTABLE_", $table
    $report = $report -replace "_SUMMARYSTATEMENT_", $summaryStatement

    [System.Web.HttpUtility]::HtmlDecode($report) | Out-File -encoding UTF8 $workingDirectory\ui\Summary.html
}

function RenderIdleTime() {
    Log "Rendering Idle time"

    $workingDirectory = (Get-Location).Path

    $getGamesIdleTimeDataQuery = "SELECT name, idle_time as time FROM games WHERE idle_time > 0 ORDER BY idle_time DESC"
    $gamesIdleTimeData = RunDBQuery $getGamesIdleTimeDataQuery
    if ($gamesIdleTimeData.Length -eq 0) {
        ShowMessage "No Idle Games found in DB." "OK" "Error"
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
    Log "Rendering games per platform"

    $workingDirectory = (Get-Location).Path

    $getGamesPerPlatformDataQuery = "SELECT  platform, COUNT(name) FROM games GROUP BY platform"
    $getGamesPerPlatformData = RunDBQuery $getGamesPerPlatformDataQuery
    if ($getGamesPerPlatformData.Length -eq 0) {
        ShowMessage "No Games found in DB. Please add some games first." "OK" "Error"
        Log "Error: Games list empty. Returning"
        return $false
    }

    $table = $getGamesPerPlatformData | ConvertTo-Html -Fragment

    $report = (Get-Content $workingDirectory\ui\templates\GamesPerPlatform.html.template) -replace "_GAMESPERPLATFORMTABLE_", $table

    [System.Web.HttpUtility]::HtmlDecode($report) | Out-File -encoding UTF8 $workingDirectory\ui\GamesPerPlatform.html
}

function RenderPCvsEmulation() {
    Log "Rendering PC vs Emulation"

    $workingDirectory = (Get-Location).Path

    $getPCvsEmulationTimeQuery = "SELECT  platform, SUM(play_time) as play_time FROM games WHERE platform LIKE 'PC' UNION SELECT 'Emulation', SUM(play_time) as play_time FROM games WHERE platform NOT LIKE 'PC'"
    $pcVsEmulationTime = RunDBQuery $getPCvsEmulationTimeQuery
    if ($pcVsEmulationTime.Length -eq 0) {
        ShowMessage "No Games found in DB. Please add some games first." "OK" "Error"
        Log "Error: Games list empty. Returning"
        return $false
    }

    $table = $pcVsEmulationTime | ConvertTo-Html -Fragment

    $report = (Get-Content $workingDirectory\ui\templates\PCvsEmulation.html.template) -replace "_PCVSEMULATIONTABLE_", $table

    [System.Web.HttpUtility]::HtmlDecode($report) | Out-File -encoding UTF8 $workingDirectory\ui\PCvsEmulation.html
}

function RenderAboutDialog() {
    $aboutForm = CreateForm "About" 340 270 ".\icons\running.ico"

    $pictureBox = CreatePictureBox "./icons/banner.png" 6 20 322 60
    $aboutForm.Controls.Add($pictureBox)

    $textCopyRight = [char]::ConvertFromUtf32(0x000000A9) + " 2024 Kulvinder Singh"
    $labelCopyRight = CreateLabel $textCopyRight 107 100
    $aboutForm.Controls.Add($labelCopyRight)

    $labelHome = New-Object Windows.Forms.LinkLabel
    $labelHome.Text = "Home"
    $labelHome.Location = New-Object Drawing.Point(154, 130)
    $labelHome.AutoSize = $true
    $labelHome.Add_LinkClicked({
            Start-Process "https://github.com/kulvind3r/GamingGaiden"
        })
    $aboutForm.Controls.Add($labelHome)

    $labelAttributions = New-Object Windows.Forms.LinkLabel
    $labelAttributions.Text = "Open Source And Original Art Attributions"
    $labelAttributions.Location = New-Object Drawing.Point(63, 160)
    $labelAttributions.AutoSize = $true
    $labelAttributions.Add_LinkClicked({
            Start-Process "https://github.com/kulvind3r/GamingGaiden#attributions"
        })
    $aboutForm.Controls.Add($labelAttributions)

    $buttonClose = CreateButton "Close" 133 200; $buttonClose.Add_Click({ $aboutForm.Close() }); $aboutForm.Controls.Add($buttonClose)

    $aboutForm.ShowDialog()
    $aboutForm.Dispose()
}

function RenderQuickView() {
    $lastFiveGamesQuery = "Select icon, name, play_time, last_play_date from games ORDER BY completed, last_play_date DESC LIMIT 5"
    $gameRecords = RunDBQuery $lastFiveGamesQuery
    if ($gameRecords.Length -eq 0) {
        ShowMessage "No Games found in DB. Please add some games first." "OK" "Error"
        Log "Error: Games list empty. Returning"
        return
    }

    $quickViewForm = CreateForm "Currently Playing / Recently Finished Games" 390 378 ".\icons\running.ico"
    $quickViewForm.MaximizeBox = $false; $quickViewForm.MinimizeBox = $false;
    $quickViewForm.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual

    $screenBounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $quickViewForm.Left = $screenBounds.Width - $quickViewForm.Width - 20
    $quickViewForm.Top = $screenBounds.Height - $quickViewForm.Height - 40

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

    $IconColumn = New-Object System.Windows.Forms.DataGridViewImageColumn
    $IconColumn.Name = "icon"
    $IconColumn.HeaderText = ""
    $IconColumn.ImageLayout = [System.Windows.Forms.DataGridViewImageCellLayout]::Zoom
    $dataGridView.Columns.Add($IconColumn)

    $dataGridView.Columns.Add("name", "Name")
    $dataGridView.Columns.Add("play_time", "Playtime")
    $dataGridView.Columns.Add("last_play_date", "Last Played On")

    foreach ($column in $dataGridView.Columns) {
        $column.Resizable = [System.Windows.Forms.DataGridViewTriState]::False
    }

    foreach ($row in $GameRecords) {

        $iconByteStream = [System.IO.MemoryStream]::new($row.icon)
        $gameIcon = [System.Drawing.Bitmap]::FromStream($iconByteStream)

        $minutes = $null; $hours = [math]::divrem($row.play_time, 60, [ref]$minutes);
        $playTimeFormatted = "{0} Hr {1} Min" -f $hours, $minutes

        [datetime]$origin = '1970-01-01 00:00:00'
        $dateFormatted = $origin.AddSeconds($row.last_play_date).ToLocalTime().ToString("dd MMMM yyyy")

        $dataGridView.Rows.Add($gameIcon, $row.name, $playTimeFormatted, $dateFormatted)
    }

    foreach ($row in $dataGridView.Rows) {
        $row.Resizable = [System.Windows.Forms.DataGridViewTriState]::False
    }

    # Remove flickering in Data Grid View
    $doubleBufferProperty = $dataGridView.GetType().GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]::NonPublic -bor [System.Reflection.BindingFlags]::Instance)
    $doubleBufferProperty.SetValue($dataGridView, $true, $null)

    $quickViewForm.Controls.Add($dataGridView)

    $quickViewForm.Add_Deactivate({
            $quickViewForm.Dispose()
        })

    $quickViewForm.Add_Shown({
            $dataGridView.ClearSelection()
            $quickViewForm.Activate()
        })

    $quickViewForm.ShowDialog()
}
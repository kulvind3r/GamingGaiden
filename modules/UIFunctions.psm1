class Game {
    [ValidateNotNullOrEmpty()][string]$Icon
    [ValidateNotNullOrEmpty()][string]$Name
    [ValidateNotNullOrEmpty()][string]$Platform
    [ValidateNotNullOrEmpty()][string]$Playtime
    [ValidateNotNullOrEmpty()][string]$Session_Count
    [ValidateNotNullOrEmpty()][string]$Completed
    [ValidateNotNullOrEmpty()][string]$Last_Played_On
    [string]$Gaming_PC

    Game($IconUri, $Name, $Platform, $Playtime, $SessionCount, $Completed, $LastPlayDate, $GamingPC) {
        $this.Icon = $IconUri
        $this.Name = $Name
        $this.Platform = $Platform
        $this.Playtime = $Playtime
        $this.Session_Count = $SessionCount
        $this.Completed = $Completed
        $this.Last_Played_On = $LastPlayDate
        $this.Gaming_PC = $GamingPC
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
    [ValidateNotNullOrEmpty()][string]$GamesPlayed
    [ValidateNotNullOrEmpty()][string]$TotalHours


    GamingPC($IconUri, $Name, $Current, $Cost, $Currency, $StartDate, $EndDate, $Age, $GamesPlayed, $TotalHours) {
        $this.IconUri = $IconUri
        $this.Name = $Name
        $this.Current = $Current
        $this.Cost = $Cost
        $this.Currency = $Currency
        $this.StartDate = $StartDate
        $this.EndDate = $EndDate
        $this.Age = $Age
        $this.GamesPlayed = $GamesPlayed
        $this.TotalHours = $TotalHours
    }
}

function UpdateAllStatsInBackground() {
    RenderGameList -InBackground $true
    RenderSummary -InBackground $true
    RenderGamingTime -InBackground $true
    RenderGamesPerPlatform -InBackground $true
    RenderMostPlayed -InBackground $true
    RenderIdleTime -InBackground $true
    RenderPCvsEmulation -InBackground $true
    RenderSessionHistory -InBackground $true
}

function RenderGameList() {
    param(
        [bool]$InBackground = $false
    )

    Log "Rendering all games list."

    $workingDirectory = (Get-Location).Path

    $getAllGamesQuery = "SELECT name, icon, platform, play_time, session_count, completed, last_play_date, status, gaming_pc_name FROM games"
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
                $iconBitmap.Save("$workingDirectory\ui\resources\images\$imageFileName.png", [System.Drawing.Imaging.ImageFormat]::Png) | Out-Null
                $iconUri = "<img src=`".\resources\images\$imageFileName.png`">"
            }
            else {
                $iconBitmap.Save("$workingDirectory\ui\resources\images\$imageFileName.jpg", [System.Drawing.Imaging.ImageFormat]::Jpeg) | Out-Null
                $iconUri = "<img src=`".\resources\images\$imageFileName.jpg`">"
            }

            $iconBitmap.Dispose()
        }

        # Process gaming PC names
        $gamingPCs = ""
        if ($null -ne $gameRecord.gaming_pc_name -and $gameRecord.gaming_pc_name -ne "") {
            $pcArray = $gameRecord.gaming_pc_name -split ','
            $gamingPCs = $pcArray -join '<br/>'
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

        $currentGame = [Game]::new($iconUri, $name, $gameRecord.platform, $gameRecord.play_time, $gameRecord.session_count, $statusUri, $gameRecord.last_play_date, $gamingPCs)

        # Assign to null to avoid appending output to pipeline, improves performance and resource consumption
        $null = $games.Add($currentGame)
    }

    $table = $games | ConvertTo-Html -Fragment -Property Icon, Name, Platform, Playtime, Session_Count, Completed, Gaming_PC, Last_Played_On

    $report = (Get-Content $workingDirectory\ui\templates\AllGames.html.template) -replace "_GAMESTABLE_", $table
    $report = $report -replace "Last_Played_On", "Last Played On"
    $report = $report -replace "Session_Count", "Sessions"
    $report = $report -replace "Completed", "Status"
    $report = $report -replace "Gaming_PC", "Gaming PC"
    $report = $report -replace "_MAXPLAYTIME_", $maxPlayTime
    $report = $report -replace "_TOTALGAMECOUNT_", $games.Count

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

    $getGamingPCsQuery = "SELECT * FROM gaming_pcs ORDER BY in_use DESC, end_date DESC"
    $gamingPCData = RunDBQuery $getGamingPCsQuery

    # Check if PC warning should be shown
    $currentPC = Read-Setting "current_pc"
    $pcWarning = ""
    if ($null -eq $currentPC -and $gamingPCData.Length -gt 1) {
        $pcWarning = "<p style='color: red; font-size: 12px; margin: 5px 0;'>⚠ Current PC unidentified. Mark a PC as current to measure PC usage</p>"
    }

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
            $iconBitmap.Save("$workingDirectory\ui\resources\images\$imageFileName.png", [System.Drawing.Imaging.ImageFormat]::Png) | Out-Null
            $pcIconUri = "<img src=`".\resources\images\$imageFileName.png`">"
        }
        else {
            $iconBitmap.Save("$workingDirectory\ui\resources\images\$imageFileName.jpg", [System.Drawing.Imaging.ImageFormat]::Jpeg) | Out-Null
            $pcIconUri = "<img src=`".\resources\images\$imageFileName.jpg`">"
        }

        $iconBitmap.Dispose()

        # Calculate PC age in PowerShell
        $startDate = (Get-Date "1970-01-01 00:00:00Z").AddSeconds($gamingPCRecord.start_date)
        $endDate = if ($gamingPCRecord.in_use -eq 'TRUE') { Get-Date } else { (Get-Date "1970-01-01 00:00:00Z").AddSeconds($gamingPCRecord.end_date) }
        $ageSpan = New-TimeSpan -Start $startDate -End $endDate
        $ageYears = [Math]::Floor($ageSpan.TotalDays / 365.25)
        $ageMonths = [Math]::Floor(($ageSpan.TotalDays % 365.25) / 30.4375)
        $pcAge = "{0} Years and {1} Months" -f $ageYears, $ageMonths

        # Get game count for this PC
        $getGamesPlayedQuery = "SELECT COUNT(*) as game_count FROM games WHERE gaming_pc_name LIKE '%{0}%'" -f $name
        $gamesPlayedResult = RunDBQuery $getGamesPlayedQuery
        $gamesPlayed = $gamesPlayedResult.game_count

        # Convert playtime to hours string
        $totalHours = PlayTimeMinsToString $gamingPCRecord.total_play_time

        $thisPC = [GamingPC]::new($pcIconUri, $name, $gamingPCRecord.in_use, $gamingPCRecord.cost, $gamingPCRecord.currency, $gamingPCRecord.start_date, $gamingPCRecord.end_date, $pcAge, $gamesPlayed, $totalHours)

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
    $report = $report -replace "_PCWARNING_", $pcWarning

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

function RenderPCvsEmulation() {
    param(
        [bool]$InBackground = $false
    )

    Log "Rendering PC vs Emulation"

    $workingDirectory = (Get-Location).Path

    $getPCvsEmulationTimeQuery = "SELECT  platform, IFNULL(SUM(play_time), 0) as play_time FROM games WHERE platform LIKE 'PC' UNION SELECT 'Emulation', IFNULL(SUM(play_time), 0) as play_time FROM games WHERE platform NOT LIKE 'PC'"
    $pcVsEmulationTime = RunDBQuery $getPCvsEmulationTimeQuery
    if ($pcVsEmulationTime.Length -eq 0) {
        if(-Not $InBackground) {
            ShowMessage "No Games found in DB. Please add some games first." "OK" "Error"
        }
        Log "Error: Games list empty. Returning"
        return $false
    }

    $totalPlayTime = $pcVsEmulationTime[0].play_time + $pcVsEmulationTime[1].play_time

    if ($totalPlayTime -eq 0 ) {
        if(-Not $InBackground) {
            ShowMessage "No play time found in DB. Please play some games first." "OK" "Error"
        }
        Log "Error: No playtime found in DB. Returning"
        return $false
    }

    $table = $pcVsEmulationTime | ConvertTo-Html -Fragment

    $report = (Get-Content $workingDirectory\ui\templates\PCvsEmulation.html.template) -replace "_PCVSEMULATIONTABLE_", $table

    [System.Web.HttpUtility]::HtmlDecode($report) | Out-File -encoding UTF8 $workingDirectory\ui\PCvsEmulation.html
}

function RenderAboutDialog() {
    $aboutForm = CreateForm "About" 350 280 ".\icons\running.ico"

    $pictureBox = CreatePictureBox "./icons/banner.png" 0 10 345 70
    $aboutForm.Controls.Add($pictureBox)

    $labelVersion = CreateLabel (Get-AppVersion) 145 90
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

function RenderSessionHistory() {
    param(
        [bool]$InBackground = $false
    )

    Log "Rendering session history page"
    $workingDirectory = (Get-Location).Path

    # Query ALL sessions with game info
    $getSessionDataQuery = @"
SELECT
    sh.id,
    sh.game_name,
    g.platform,
    DATE(sh.start_time, 'unixepoch', 'localtime') as session_date,
    sh.start_time,
    sh.duration
FROM session_history sh
LEFT JOIN games g ON sh.game_name = g.name
ORDER BY sh.start_time DESC
"@

    $sessionData = RunDBQuery $getSessionDataQuery

    if ($sessionData.Length -eq 0) {
        if (-Not $InBackground) {
            ShowMessage "No session history found. Play some games first!" "OK" "Info"
        }
        Log "No session data available"
        return $false
    }

    # Ensure array format
    if ($sessionData -isnot [System.Array]) {
        $sessionData = @($sessionData)
    }

    # Get unique games with session counts for the left panel
    $getGamesWithSessionsQuery = @"
SELECT
    sh.game_name,
    g.platform,
    g.icon,
    COUNT(sh.id) as session_count,
    SUM(sh.duration) as total_duration
FROM session_history sh
LEFT JOIN games g ON sh.game_name = g.name
GROUP BY sh.game_name
ORDER BY sh.game_name ASC
"@

    $gamesWithSessions = RunDBQuery $getGamesWithSessionsQuery

    if ($gamesWithSessions -isnot [System.Array]) {
        $gamesWithSessions = @($gamesWithSessions)
    }

    # Process icons for games data (icons will be used in sidebar and header)
    foreach ($game in $gamesWithSessions) {
        if ($null -ne $game.icon) {
            $name = $game.game_name
            $imageFileName = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($name))

            # Check if icon already exists on disk (cache check)
            if (Test-Path "$workingDirectory\ui\resources\images\$imageFileName.jpg") {
                $game.icon = ".\resources\images\$imageFileName.jpg"
            }
            elseif (Test-Path "$workingDirectory\ui\resources\images\$imageFileName.png") {
                $game.icon = ".\resources\images\$imageFileName.png"
            }
            else {
                # Extract and save icon from BLOB
                $iconByteStream = [System.IO.MemoryStream]::new($game.icon)
                $iconBitmap = [System.Drawing.Bitmap]::FromStream($iconByteStream)

                if ($iconBitmap.PixelFormat -eq "Format32bppArgb") {
                    $iconBitmap.Save("$workingDirectory\ui\resources\images\$imageFileName.png", [System.Drawing.Imaging.ImageFormat]::Png) | Out-Null
                    $game.icon = ".\resources\images\$imageFileName.png"
                }
                else {
                    $iconBitmap.Save("$workingDirectory\ui\resources\images\$imageFileName.jpg", [System.Drawing.Imaging.ImageFormat]::Jpeg) | Out-Null
                    $game.icon = ".\resources\images\$imageFileName.jpg"
                }

                $iconBitmap.Dispose()
            }
        }
    }

    # Convert both to HTML tables (hidden, for JavaScript parsing)
    $sessionTable = $sessionData | ConvertTo-Html -Fragment
    $gamesTable = $gamesWithSessions | ConvertTo-Html -Fragment

    # Load template and replace placeholders
    $report = (Get-Content $workingDirectory\ui\templates\SessionHistory.html.template) `
        -replace "_SESSIONTABLE_", $sessionTable `
        -replace "_GAMESTABLE_", $gamesTable

    [System.Web.HttpUtility]::HtmlDecode($report) | Out-File -encoding UTF8 $workingDirectory\ui\SessionHistory.html

    return $true
}
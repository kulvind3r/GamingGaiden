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
	Log "Rendering my games list"
	
	$WorkingDirectory = (Get-Location).Path
	mkdir -f $WorkingDirectory\ui\resources\images
	
	$GetAllGamesQuery = "SELECT name, icon, platform, play_time, session_count, completed, last_play_date FROM games"
	
	$GameRecords = RunDBQuery $GetAllGamesQuery
	if ($GameRecords.Length -eq 0) {
        ShowMessage "No Games found in DB. Please add some games first." "OK" "Error"
        Log "Error: Games list empty. Returning"
        return $false
    }

	$GetMaxPlayTime = "SELECT max(play_time) as 'max_play_time' FROM games"
	$MaxPlayTime = (RunDBQuery $GetMaxPlayTime).max_play_time
	
	$Games = @()
	$TotalPlayTime = $null
	foreach ($GameRecord in $GameRecords) {
		$Name = $GameRecord.name

		$IconUri = "<img src=`".\resources\images\default.png`">"
		if ($null -ne $GameRecord.icon)	{
			$ImageFileName = ToBase64 $Name
			$IconBitmap = BytesToBitmap $GameRecord.icon
			$IconBitmap.Save("$WorkingDirectory\ui\resources\images\$ImageFileName.png",[System.Drawing.Imaging.ImageFormat]::Png)
			$IconBitmap.Dispose()
			$IconUri = "<img src=`".\resources\images\$ImageFileName.png`">"
		}

		$StatusUri = "<div>Finished</div><img src=`".\resources\images\finished.png`">"
		if ($GameRecord.completed -eq 'FALSE') {
			$StatusUri = "<div>Playing</div><img src=`".\resources\images\playing.png`">"
		}
		
		$CurrentGame = [Game]::new($IconUri, $Name, $GameRecord.platform, $GameRecord.play_time, $GameRecord.session_count, $StatusUri, $GameRecord.last_play_date)

		$Games += $CurrentGame
		$TotalPlayTime += $GameRecord.play_time
	}
	
	$TotalPlayTimeString = PlayTimeMinsToString $TotalPlayTime

	$Table = $Games | ConvertTo-Html -Fragment
	
	$report = (Get-Content $WorkingDirectory\ui\templates\AllGames.html.template) -replace "_GAMESTABLE_", $Table
	$report = $report -replace "Last_Played_On", "Last Played On"
	$report = $report -replace "Session_Count", "Session Count"
	$report = $report -replace "Completed", "Status"
	$report = $report -replace "_MAXPLAYTIME_", $MaxPlayTime
	$report = $report -replace "_TOTALGAMECOUNT_", $Games.length
	$report = $report -replace "_TOTALPLAYTIME_", $TotalPlayTimeString
	
	[System.Web.HttpUtility]::HtmlDecode($report) | Out-File -encoding UTF8 $WorkingDirectory\ui\AllGames.html
}

function RenderGamingTime() {
	Log "Rendering time spent gaming"

	$WorkingDirectory = (Get-Location).Path

	$GetDailyPlayTimeDataQuery = "SELECT play_date as date, play_time as time FROM daily_playtime ORDER BY date ASC"

	$DailyPlayTimeData = RunDBQuery $GetDailyPlayTimeDataQuery

	if ($DailyPlayTimeData.Length -eq 0) {
        ShowMessage "No Records of Game Time found in DB. Please play some games first." "OK" "Error"
        Log "Error: Game time records empty. Returning"
        return $false
    }

	$Table = $DailyPlayTimeData | ConvertTo-Html -Fragment
	
	$report = (Get-Content $WorkingDirectory\ui\templates\GamingTime.html.template) -replace "_DAILYPLAYTIMETABLE_", $Table

	[System.Web.HttpUtility]::HtmlDecode($report) | Out-File -encoding UTF8 $WorkingDirectory\ui\GamingTime.html
}

function RenderMostPlayed() {
	Log "Rendering most played"

	$WorkingDirectory = (Get-Location).Path

	$GetGamesPlayTimeDataQuery = "SELECT name, play_time as time FROM games Order By play_time DESC"

	$GamesPlayTimeData = RunDBQuery $GetGamesPlayTimeDataQuery
	if ($GamesPlayTimeData.Length -eq 0) {
        ShowMessage "No Games found in DB. Please add some games first." "OK" "Error"
        Log "Error: Games list empty. Returning"
        return $false
    }

	$Table = $GamesPlayTimeData | ConvertTo-Html -Fragment
	
	$report = (Get-Content $WorkingDirectory\ui\templates\MostPlayed.html.template) -replace "_GAMESPLAYTIMETABLE_", $Table

	[System.Web.HttpUtility]::HtmlDecode($report) | Out-File -encoding UTF8 $WorkingDirectory\ui\MostPlayed.html
}

function RenderSummary() {
	Log "Rendering life time summary"

	$WorkingDirectory = (Get-Location).Path

	$GetGamesPlayTimeVsSessionDataQuery = "SELECT name, play_time, session_count, completed FROM games"

	$GamesPlayTimeVsSessionData = RunDBQuery $GetGamesPlayTimeVsSessionDataQuery
	if ($GamesPlayTimeVsSessionData.Length -eq 0) {
        ShowMessage "No Games found in DB. Please add some games first." "OK" "Error"
        Log "Error: Games list empty. Returning"
        return $false
    }

	$GetGamesSummaryDataQuery = "SELECT COUNT(*) AS total_games, SUM(play_time) AS total_play_time, SUM(session_count) AS total_sessions, SUM(idle_time) AS total_idle_time FROM games"
	$GamesSummaryData = RunDBQuery $GetGamesSummaryDataQuery

	$GetPlayDateSummaryQuery = "SELECT MIN(play_date) AS min_play_date, MAX(play_date) AS max_play_date FROM daily_playtime"
	$PlayDateSummary = RunDBQuery $GetPlayDateSummaryQuery

	$StartDate = Get-Date -Date $PlayDateSummary.min_play_date -Format "MMM yyyy"
	$EndDate = Get-Date -Date $PlayDateSummary.max_play_date -Format "MMM yyyy"

	$TotalPlayTime =  PlayTimeMinsToString $GamesSummaryData.total_play_time
	$TotalIdleTime = PlayTimeMinsToString $GamesSummaryData.total_idle_time

	$SummaryStatement = "From <b>$StartDate to $EndDate</b> you played <b>$($GamesSummaryData.total_games) games</b> in <b>$($GamesSummaryData.total_sessions) sessions</b>. Total <b>play time is $TotalPlayTime</b> with <b>$TotalIdleTime spent idling</b>."

	$Table = $GamesPlayTimeVsSessionData | ConvertTo-Html -Fragment
	
	$report = (Get-Content $WorkingDirectory\ui\templates\Summary.html.template) -replace "_SUMMARYTABLE_", $Table
	$report = $report -replace "_SUMMARYSTATEMENT_", $SummaryStatement

	[System.Web.HttpUtility]::HtmlDecode($report) | Out-File -encoding UTF8 $WorkingDirectory\ui\Summary.html
}

function RenderIdleTime() {
	Log "Rendering Idle time"

	$WorkingDirectory = (Get-Location).Path

	$GetGamesIdleTimeDataQuery = "SELECT name, idle_time as time FROM games WHERE idle_time > 0 ORDER BY idle_time DESC"
	$GetTotalIdleTimeQuery = "SELECT SUM(idle_time) as total_idle_time FROM games"

	$GamesIdleTimeData = RunDBQuery $GetGamesIdleTimeDataQuery
	if ($GamesIdleTimeData.Length -eq 0) {
        ShowMessage "No Idle Games found in DB." "OK" "Error"
        Log "Error: Idle Games list empty. Returning"
        return $false
    }

	$TotalIdleTime = (RunDBQuery $GetTotalIdleTimeQuery).total_idle_time
	$TotalIdleTimeString = PlayTimeMinsToString $TotalIdleTime

	$Table = $GamesIdleTimeData | ConvertTo-Html -Fragment
	
	$report = (Get-Content $WorkingDirectory\ui\templates\IdleTime.html.template) -replace "_GAMESIDLETIMETABLE_", $Table
	$report = $report -replace "_TOTALIDLETIME_", $TotalIdleTimeString

	[System.Web.HttpUtility]::HtmlDecode($report) | Out-File -encoding UTF8 $WorkingDirectory\ui\IdleTime.html
}

function RenderGamesPerPlatform() {
	Log "Rendering games per platform"

	$WorkingDirectory = (Get-Location).Path

	$GetGamesPerPlatformDataQuery = "SELECT  platform, COUNT(name) FROM games GROUP BY platform"

	$GetGamesPerPlatformData = RunDBQuery $GetGamesPerPlatformDataQuery
	if ($GetGamesPerPlatformData.Length -eq 0) {
        ShowMessage "No Games found in DB. Please add some games first." "OK" "Error"
        Log "Error: Games list empty. Returning"
        return $false
    }

	$Table = $GetGamesPerPlatformData | ConvertTo-Html -Fragment
	
	$report = (Get-Content $WorkingDirectory\ui\templates\GamesPerPlatform.html.template) -replace "_GAMESPERPLATFORMTABLE_", $Table

	[System.Web.HttpUtility]::HtmlDecode($report) | Out-File -encoding UTF8 $WorkingDirectory\ui\GamesPerPlatform.html

}

function RenderPCvsEmulation() {
	Log "Rendering PC vs Emulation"

	$WorkingDirectory = (Get-Location).Path

	$GetPCvsEmulationTimeQuery = "SELECT  platform, SUM(play_time) as play_time FROM games WHERE platform LIKE 'PC' UNION SELECT 'Emulation', SUM(play_time) as play_time FROM games WHERE platform NOT LIKE 'PC'"

	$PCvsEmulationTime = RunDBQuery $GetPCvsEmulationTimeQuery
	
	if ($PCvsEmulationTime.Length -eq 0) {
        ShowMessage "No Games found in DB. Please add some games first." "OK" "Error"
        Log "Error: Games list empty. Returning"
        return $false
    }

	$Table = $PCvsEmulationTime | ConvertTo-Html -Fragment
	
	$report = (Get-Content $WorkingDirectory\ui\templates\PCvsEmulation.html.template) -replace "_PCVSEMULATIONTABLE_", $Table

	[System.Web.HttpUtility]::HtmlDecode($report) | Out-File -encoding UTF8 $WorkingDirectory\ui\PCvsEmulation.html
}

function RenderAboutDialog() {
	$AboutForm = CreateForm "About" 350 280 ".\icons\running.ico"

	$PictureBox = CreatePictureBox "./icons/banner.png" 6 20 322 60
	$AboutForm.Controls.Add($pictureBox)

	$TextCopyRight = [char]::ConvertFromUtf32(0x000000A9) + " 2023 Kulvinder Singh"
	$LabelCopyRight = CreateLabel $TextCopyRight 107 100
	$AboutForm.Controls.Add($LabelCopyRight)

	$LabelHome = New-Object Windows.Forms.LinkLabel
	$LabelHome.Text = "Home"
	$LabelHome.Location = New-Object Drawing.Point(154, 130)
	$LabelHome.AutoSize = $true
	$LabelHome.Add_LinkClicked({
		Start-Process "https://github.com/kulvind3r/GamingGaiden"
	})
	$AboutForm.Controls.Add($LabelHome)

	$LabelAttributions = New-Object Windows.Forms.LinkLabel
	$LabelAttributions.Text = "Open Source And Original Art Attributions"
	$LabelAttributions.Location = New-Object Drawing.Point(63, 160)
	$LabelAttributions.AutoSize = $true
	$LabelAttributions.Add_LinkClicked({
		Start-Process "https://github.com/kulvind3r/GamingGaiden#attributions"
	})
	$AboutForm.Controls.Add($LabelAttributions)

	$buttonClose = CreateButton "Close" 133 200; $buttonClose.Add_Click({ $AboutForm.Close() }); $AboutForm.Controls.Add($buttonClose)

	$AboutForm.ShowDialog()
	$AboutForm.Dispose()
}

function RenderQuickView() {
	$LastFiveGamesQuery = "Select icon, name, play_time, last_play_date from games ORDER BY completed, last_play_date DESC LIMIT 5"
	$GameRecords = RunDBQuery $LastFiveGamesQuery
	if ($GameRecords.Length -eq 0) {
		ShowMessage "No Games found in DB. Please add some games first." "OK" "Error"
		Log "Error: Games list empty. Returning"
		return
	}

	$QuickViewForm = CreateForm "Currently Playing / Recently Finished Games" 400 388 ".\icons\running.ico"
	$QuickViewForm.MaximizeBox = $false; $QuickViewForm.MinimizeBox = $false;
	$QuickViewForm.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
	$QuickViewForm.ShowInTaskbar = $false

	$ScreenBounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
	$QuickViewForm.Left = $ScreenBounds.Width - $QuickViewForm.Width - 20
	$QuickViewForm.Top = $ScreenBounds.Height - $QuickViewForm.Height - 40

	$DataGridView = New-Object System.Windows.Forms.DataGridView
	$DataGridView.Dock = [System.Windows.Forms.DockStyle]::Fill
	$DataGridView.BorderStyle = [System.Windows.Forms.BorderStyle]::None
	$DataGridView.RowTemplate.Height = 65
	$DataGridView.AllowUserToAddRows = $false
	$DataGridView.RowHeadersVisible = $false
	$DataGridView.CellBorderStyle = "None"
	$DataGridView.AutoSizeColumnsMode = "Fill"
	$DataGridView.Enabled = $false
	$DataGridView.DefaultCellStyle.Padding = New-Object System.Windows.Forms.Padding(2, 2, 2, 2)
	$DataGridView.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)

	$IconColumn = New-Object System.Windows.Forms.DataGridViewImageColumn
	$IconColumn.Name = "icon"
	$IconColumn.HeaderText = ""
	$IconColumn.ImageLayout = [System.Windows.Forms.DataGridViewImageCellLayout]::Zoom
	$DataGridView.Columns.Add($IconColumn)

	$DataGridView.Columns.Add("name", "Name")
	$DataGridView.Columns.Add("play_time", "Playtime")
	$DataGridView.Columns.Add("last_play_date", "Last Played On")

	foreach ($column in $DataGridView.Columns) {
		$column.Resizable = [System.Windows.Forms.DataGridViewTriState]::False
	}

	foreach ($row in $GameRecords) {
		$GameIcon = BytesToBitmap $row.icon
		$PlayTimeFormatted = PlayTimeMinsToString $row.play_time
		$DateFormatted = PlayDateEpochToString $row.last_play_date
		$DataGridView.Rows.Add($GameIcon, $row.name, $PlayTimeFormatted, $DateFormatted)
	}

	foreach ($row in $DataGridView.Rows) {
		$row.Resizable = [System.Windows.Forms.DataGridViewTriState]::False
	}

	$QuickViewForm.Controls.Add($DataGridView)

	$QuickViewForm.Add_Deactivate({
		$QuickViewForm.Dispose()
	})

	$QuickViewForm.Add_Shown({
		$DataGridView.ClearSelection()
		$QuickViewForm.Activate()
	})

	$QuickViewForm.ShowDialog()
}
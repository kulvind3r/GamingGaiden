class Game {
	[ValidateNotNullOrEmpty()][string]$Icon
    [ValidateNotNullOrEmpty()][string]$Name
	[ValidateNotNullOrEmpty()][string]$Platform
    [ValidateNotNullOrEmpty()][string]$Playtime
	[ValidateNotNullOrEmpty()][string]$Completed
    [ValidateNotNullOrEmpty()][string]$Last_Played_On
	

    Game($IconUri, $Name, $Platform, $Playtime, $Completed, $LastPlayDate) {
       $this.Icon = $IconUri
	   $this.Name = $Name
	   $this.Platform = $Platform
       $this.Playtime = $Playtime
	   $this.Completed = $Completed
	   $this.Last_Played_On = $LastPlayDate
    }
}

function RenderGameList() {
	Log "Rendering my games list"
	
	$WorkingDirectory = (Get-Location).Path
	mkdir -f $WorkingDirectory\ui\resources\images
	
	$GetAllGamesQuery = "SELECT name, icon, platform, play_time, completed, last_play_date FROM games"
	
	$GameRecords = RunDBQuery $GetAllGamesQuery
	if ($GameRecords.Length -eq 0){
        ShowMessage "No Games found in DB. Please add some games first." "Ok" "Error"
        Log "Error: Games list empty. Returning"
        return
    }

	$Games = @()
	$TotalPlayTime = $null;
	foreach ($GameRecord in $GameRecords) {
		$Name = $GameRecord.name

		$IconUri = "<img src=`".\resources\images\default.png`">"
		if ($null -ne $GameRecord.icon)
		{
			$ImageFileName = ToBase64 $Name
			$IconBitmap = BytesToBitmap $GameRecord.icon
			$IconBitmap.Save("$WorkingDirectory\ui\resources\images\$ImageFileName.png",[System.Drawing.Imaging.ImageFormat]::Png)
			$IconUri = "<img src=`".\resources\images\$ImageFileName.png`">"
		}

		$StatusUri = "<div>Finished</div><img src=`".\resources\images\finished.png`">"
		if ($GameRecord.completed -eq 'FALSE')
		{
			$StatusUri = "<div>Playing</div><img src=`".\resources\images\playing.png`">"
		}
		
		$CurrentGame = [Game]::new($IconUri, $Name, $GameRecord.platform, $GameRecord.play_time, $StatusUri, $GameRecord.last_play_date)

		$Games += $CurrentGame
		$TotalPlayTime += $GameRecord.play_time
	}
	
	$TotalPlayTimeString = PlayTimeMinsToString $TotalPlayTime

	$Table = $Games | ConvertTo-Html -Fragment
	
	$report = (Get-Content $WorkingDirectory\ui\templates\MyGames.html.template) -replace "_GAMESTABLE_", $Table
	$report = $report -replace "Last_Played_On", "Last Played On"
	$report = $report -replace "Completed", "Status"
	$report = $report -replace "_TOTALGAMECOUNT_", $Games.length
	$report = $report -replace "_TOTALPLAYTIME_", $TotalPlayTimeString
	
	[System.Web.HttpUtility]::HtmlDecode($report) | Out-File -encoding UTF8 $WorkingDirectory\ui\MyGames.html

	$DBConnection.Close()
}

function RenderGamingTime() {
	Log "Rendering time spent gaming"

	$WorkingDirectory = (Get-Location).Path

	$GetDailyPlayTimeDataQuery = "SELECT play_date as date, play_time as time FROM daily_playtime ORDER BY date ASC"

	$DailyPlayTimeData = RunDBQuery $GetDailyPlayTimeDataQuery

	if ($DailyPlayTimeData.Length -eq 0){
        ShowMessage "No Records of Game Time found in DB. Please play some games first." "Ok" "Error"
        Log "Error: Game time records empty. Returning"
        return
    }

	$Table = $DailyPlayTimeData | ConvertTo-Html -Fragment
	
	$report = (Get-Content $WorkingDirectory\ui\templates\GamingTime.html.template) -replace "_DAILYPLAYTIMETABLE_", $Table

	[System.Web.HttpUtility]::HtmlDecode($report) | Out-File -encoding UTF8 $WorkingDirectory\ui\GamingTime.html

	$DBConnection.Close()
}

function RenderMostPlayed() {
	Log "Rendering most played"

	$WorkingDirectory = (Get-Location).Path

	$GetGamesPlayTimeDataQuery = "SELECT name, play_time as time FROM games Order By play_time DESC"

	$GamesPlayTimeData = RunDBQuery $GetGamesPlayTimeDataQuery
	if ($GamesPlayTimeData.Length -eq 0){
        ShowMessage "No Games found in DB. Please add some games first." "Ok" "Error"
        Log "Error: Games list empty. Returning"
        return
    }

	$Table = $GamesPlayTimeData | ConvertTo-Html -Fragment
	
	$report = (Get-Content $WorkingDirectory\ui\templates\MostPlayed.html.template) -replace "_GAMESPLAYTIMETABLE_", $Table

	[System.Web.HttpUtility]::HtmlDecode($report) | Out-File -encoding UTF8 $WorkingDirectory\ui\MostPlayed.html

	$DBConnection.Close()
}

function RenderGamesPerPlatform() {
	Log "Rendering games per platform"

	$WorkingDirectory = (Get-Location).Path

	$GetGamesPerPlatformDataQuery = "SELECT  platform, COUNT(name) FROM games GROUP BY platform"

	$GetGamesPerPlatformData = RunDBQuery $GetGamesPerPlatformDataQuery
	if ($GetGamesPerPlatformData.Length -eq 0){
        ShowMessage "No Games found in DB. Please add some games first." "Ok" "Error"
        Log "Error: Games list empty. Returning"
        return
    }

	$Table = $GetGamesPerPlatformData | ConvertTo-Html -Fragment
	
	$report = (Get-Content $WorkingDirectory\ui\templates\GamesPerPlatform.html.template) -replace "_GAMESPERPLATFORMTABLE_", $Table

	[System.Web.HttpUtility]::HtmlDecode($report) | Out-File -encoding UTF8 $WorkingDirectory\ui\GamesPerPlatform.html

	$DBConnection.Close()
}

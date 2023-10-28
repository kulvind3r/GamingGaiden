class Game
{
	[ValidateNotNullOrEmpty()][string]$IconUri
    [ValidateNotNullOrEmpty()][string]$Name
    [ValidateNotNullOrEmpty()][string]$Playtime
    [ValidateNotNullOrEmpty()][string]$LastPlayDate

    Game($IconUri, $Name, $Playtime, $LastPlayDate) {
       $this.IconUri = $IconUri
	   $this.Name = $Name
       $this.Playtime = $Playtime
	   $this.LastPlayDate = $LastPlayDate
    }
}

function Log($MSG) {
	$Timestamp = (Get-date -f %d-%M-%y`|%H:%m:%s)
	Write-Output "$Timestamp : $MSG" >> ".\GameplayGaiden.log"
}

function countdown {
    $seconds = 3
    1..$seconds | ForEach-Object {
        $remainingSeconds = ($seconds+1) - $_
        Write-Host "`r$remainingSeconds" -NoNewline -ForegroundColor Red
        Start-Sleep -Seconds 1
    }
    Write-Host "`r" -NoNewline
}

function user_prompt($msg) {
    Write-Host $msg -ForegroundColor Green
}

function CreateMenuItem($Enabled, $Text) {

    $MenuItem = New-Object System.Windows.Forms.MenuItem
    $MenuItem.Enabled = $Enabled
    $MenuItem.Text = "$Text"
    
    return $MenuItem
}

function SQLEscapedMatchPattern($pattern) {
	return $pattern -replace "'", "''"
}

function IsExeEmulator($DetectedExe) {
	
	Log "Checking if Detected Exe is an Emulator"

	$pattern = SQLEscapedMatchPattern $DetectedExe.Trim()
	$FindExeQuery = "SELECT COUNT(*) as '' FROM emulated_platforms WHERE exe_name LIKE '{0}'" -f $pattern

	$ExesFound = (Invoke-SqliteQuery -Query $FindExeQuery -SQLiteConnection $DBConnection).Column1

	return ($ExesFound -gt 0)
}

function findEmulatedGame($DetectedEmulatorExe, $EmulatorCommandLine){
	
	Log "Finding name of emulated game for $DetectedEmulatorExe"

	$pattern = SQLEscapedMatchPattern $DetectedEmulatorExe.Trim()
	$GetRomExtensionsQuery = "SELECT rom_extensions FROM emulated_platforms WHERE exe_name LIKE '{0}'" -f $pattern
	$RomExtensions = (Invoke-SqliteQuery -Query $GetRomExtensionsQuery -SQLiteConnection $DBConnection).rom_extensions.Split(',')

	$RomName = $null
	foreach ($RomExtension in $RomExtensions) {
		$RomName = [System.Text.RegularExpressions.Regex]::Match($EmulatorCommandLine, "[^\\]*\.$RomExtension").Value

		if($RomName -ne "") {
			$RomName = $RomName -replace ".$RomExtension", ""
			break 
		}
	}

	$EmulatedGame = [regex]::Replace($RomName, '\([^)]*\)', "")

	return $EmulatedGame
}

function findEmulatedGameCore($DetectedEmulatorExe, $EmulatorCommandLine) {
	Log "Finding core used for emulated game by $DetectedEmulatorExe"

	$pattern = SQLEscapedMatchPattern $DetectedEmulatorExe.Trim()
	$GetCoresQuery = "SELECT core FROM emulated_platforms WHERE exe_name LIKE '{0}'" -f $pattern
	$CoreName = $null
	$Cores = (Invoke-SqliteQuery -Query $GetCoresQuery -SQLiteConnection $DBConnection).core
	if ( $Cores.Length -le 1)
	{
		$CoreName = $Cores[0]
	}
	else
	{
		foreach ($Core in $Cores) {
			if ($EmulatorCommandLine.Contains($Core))
			{
				$CoreName = $Core
			}
		}
	}

	return $CoreName
}

function findEmulatedGamePlatform($DetectedEmulatorExe, $Core) {
	
	$ExePattern = SQLEscapedMatchPattern $DetectedEmulatorExe.Trim()
	$GetPlatformQuery = $null
	if ($Core.Length -eq 0 )
	{
		Log "Finding platform for $DetectedEmulatorExe"
		$GetPlatformQuery = "SELECT name FROM emulated_platforms WHERE exe_name LIKE '{0}'" -f $ExePattern
	}
	else {
		Log "Finding platform for $DetectedEmulatorExe and core $Core"
		$CorePattern = SQLEscapedMatchPattern $Core.Trim()
		$GetPlatformQuery = "SELECT name FROM emulated_platforms WHERE exe_name LIKE '{0}' AND core LIKE '{1}'" -f $ExePattern, $CorePattern
	}
	
	$EmulatedGamePlatform = (Invoke-SqliteQuery -Query $GetPlatformQuery -SQLiteConnection $DBConnection).name

	return $EmulatedGamePlatform
}

function findEmulatedGameDetails($DetectedEmulatorExe) {

	Log "Finding Details of Emulated Game by $DetectedEmulatorExe"

	$EmulatorCommandLine = Get-WmiObject Win32_Process -Filter "name = '$DetectedEmulatorExe.exe'" | Select-Object -ExpandProperty CommandLine

	$EmulatedGameName = findEmulatedGame $DetectedEmulatorExe $EmulatorCommandLine
	if ($EmulatedGameName.Length -eq 0)
	{
		return $false
	}
	$CoreName = findEmulatedGameCore $DetectedEmulatorExe $EmulatorCommandLine
	$EmulatedGamePlatform = findEmulatedGamePlatform $DetectedEmulatorExe $CoreName

	return New-Object PSObject -Property @{ Name = $EmulatedGameName; Exe = $DetectedEmulatorExe ; Platform = $EmulatedGamePlatform }
}

function RegisterEmulatedGame(){
    param(
        [string]$GameName,
        [string]$GameExeName,
        [string]$GamePlayTime,
        [string]$GameLastPlayDate,
        [string]$GamePlatform
    )

    $RegisterGameQuery = "INSERT INTO GAMES (name, exe_name, icon, play_time, last_play_date, completed, platform)" +
						"VALUES (@GameName, @GameExeName, 'NULL', @GamePlayTime, @GameLastPlayDate, 'FALSE', @GamePlatform)"

	Log "Registering $GameName in Database"
    Invoke-SqliteQuery -Query $RegisterGameQuery -SQLiteConnection $DBConnection -SqlParameters @{
        GameName = $GameName.Trim()
        GameExeName = $GameExeName.Trim()
        GamePlayTime = $GamePlayTime
        GameLastPlayDate = $GameLastPlayDate
        GamePlatform = $GamePlatform.Trim()
    }
}

function updateEmulatedGame($EmulatedGameDetails, $CurrentPlayTime) {
	
	$UpdatedLastPlayDate = (Get-Date -UFormat %s).Split('.').Get(0)
	$GameName = $EmulatedGameDetails.Name

	$GameNamePattern = SQLEscapedMatchPattern($GameName.Trim())

	$GetEmulatedGameDetailsQuery = "SELECT COUNT(*) as '' FROM games WHERE name LIKE '{0}'" -f $GameNamePattern
	$GamesFound = (Invoke-SqliteQuery -Query $GetEmulatedGameDetailsQuery -SQLiteConnection $DBConnection).Column1

	if ($GamesFound -gt 0){
		Log "$GameName is already registered. Updating Play Time and Last Played Date"
		
		$GetGamePlayTimeQuery = "SELECT play_time FROM games WHERE name LIKE '{0}'" -f $GameNamePattern
    	$RecordedGamePlayTime = (Invoke-SqliteQuery -Query $GetGamePlayTimeQuery -SQLiteConnection $DBConnection).play_time

    	$UpdatedPlayTime = $RecordedGamePlayTime + $CurrentPlayTime

		$UpdateGamePlayTimeQuery = "UPDATE games SET play_time = @UpdatedPlayTime, last_play_date = @UpdatedLastPlayDate WHERE name LIKE '{0}'" -f $GameNamePattern

		Invoke-SqliteQuery -Query $UpdateGamePlayTimeQuery -SQLiteConnection $DBConnection -SqlParameters @{ 
			UpdatedPlayTime = $UpdatedPlayTime
			UpdatedLastPlayDate = $UpdatedLastPlayDate
		}		
	}
	else
	{
		Log "$GameName not found. Registering"
		RegisterEmulatedGame -GameName $GameName -GameExeName $EmulatedGameDetails.Exe `
							-GamePlayTime $CurrentPlayTime -GameLastPlayDate $UpdatedLastPlayDate -GamePlatform $EmulatedGameDetails.Platform
	}

}

function updateGame($DetectedExe, $CurrentPlayTime) {
	$DetectedExePattern = SQLEscapedMatchPattern($DetectedExe.Trim())
	$GetGamePlayTimeQuery = "SELECT play_time FROM games WHERE exe_name LIKE '{0}'" -f $DetectedExePattern

    $RecordedGamePlayTime = (Invoke-SqliteQuery -Query $GetGamePlayTimeQuery -SQLiteConnection $DBConnection).play_time

	Log "Found Recorded Play Time of $RecordedGamePlayTime minutes for $DetectedExe Exe. Adding $CurrentPlayTime minutes of current session"

    $UpdatedPlayTime = $RecordedGamePlayTime + $CurrentPlayTime
	$UpdatedLastPlayDate = (Get-Date -UFormat %s).Split('.').Get(0)

    $UpdateGamePlayTimeQuery = "UPDATE games SET play_time = @UpdatedPlayTime, last_play_date = @UpdatedLastPlayDate WHERE exe_name LIKE '{0}'" -f $DetectedExe

    Invoke-SqliteQuery -Query $UpdateGamePlayTimeQuery -SQLiteConnection $DBConnection -SqlParameters @{ 
		UpdatedPlayTime = $UpdatedPlayTime
		UpdatedLastPlayDate = $UpdatedLastPlayDate
	}
}

function DetectGame() {

	Log "Starting game detection"

    $GetRegisteredGameExeQuery = "SELECT exe_name FROM games WHERE completed LIKE 'FALSE'"
	$GetRegisteredEmulatorsExeQuery = "SELECT exe_name FROM emulated_platforms"

    $RegisteredGamesExeList = (Invoke-SqliteQuery -Query $GetRegisteredGameExeQuery -SQLiteConnection $DBConnection).exe_name
	$RegisteredEmulatorsExeList = (Invoke-SqliteQuery -Query $GetRegisteredEmulatorsExeQuery -SQLiteConnection $DBConnection).exe_name

	$ExesToDetect = ( $RegisteredEmulatorsExeList + $RegisteredGamesExeList ) | Select-Object -Unique
	
    $DetectedExe = $null
    do {
        foreach ( $ExeName in $ExesToDetect ){
			if ( $null = Get-Process $ExeName -ErrorAction SilentlyContinue )
			{
				$DetectedExe = $ExeName
				Log "Found $ExeName Running. Exiting Detection"
				break
			}
		}
        Start-Sleep -s 10
    }
    while (-not $DetectedExe)
    
    return $DetectedExe
}

function MonitorGame($DetectedExe) {

	Log "Starting monitoring for $DetectedExe"

	$IsEmulatedGame = $null
	$EmulatedGameDetails = $null 
	if (IsExeEmulator($DetectedExe))
	{
		$IsEmulatedGame = $true
		$EmulatedGameDetails = findEmulatedGameDetails $DetectedExe

		if ($EmulatedGameDetails -eq $false)
		{
			Log "Something went wrong. Detected Emulated Game's Name was of 0 char length. Exiting Monitoring Loop. Going back to Detection"
			return
		}
	}

    $CurrentPlayTime = 0
    while(Get-Process $DetectedExe)
    {
        $CurrentPlayTime = [int16](New-TimeSpan -Start (Get-Process $DetectedExe).StartTime).TotalMinutes
        Start-Sleep -s 10
    }

	if ($IsEmulatedGame)
	{
		updateEmulatedGame $EmulatedGameDetails $CurrentPlayTime
	}
	else
	{
		updateGame $DetectedExe $CurrentPlayTime
	}
}

function RenderGameList() {

	$Database = ".\GameplayGaiden.db"
	Log "Connecting to database for Rendering game list"
	$DBConnection = New-SQLiteConnection -DataSource $Database
	
	$WorkingDirectory = (Get-Location).Path
	mkdir -f $WorkingDirectory/ui/gameicons
	
	$GetAllGamesQuery = "SELECT name, icon, play_time, last_play_date FROM games"
	
	$GamesRaw = (Invoke-SqliteQuery -Query $GetAllGamesQuery -SQLiteConnection $DBConnection)
	
	$Games = @()
	foreach ($RawGame in $GamesRaw) {
		$Name = $RawGame.name
		
		$PlayTimeInMinutes = $RawGame.play_time
		$PlayTimeHrs = [Int]($PlayTimeInMinutes / 60).ToString()
		$PlayTimeMin = [Int]($PlayTimeInMinutes % 60).ToString()
		$PlayTime = "$PlayTimeHrs Hr $PlayTimeMin Min"
		
		$LastPlayDate = ((Get-Date -Date "01-01-1970") + ([System.TimeSpan]::FromSeconds(($RawGame.last_play_date)))).ToLongDateString()
		
		$IconByteStream = [System.IO.MemoryStream]::new($RawGame.icon)
		$IconBitmap = [System.Drawing.Bitmap]::FromStream($IconByteStream)
		$IconBitmap.Save("$WorkingDirectory\ui\gameicons\$Name.png",[System.Drawing.Imaging.ImageFormat]::Png)
		$IconUri = "<img src=`".\gameicons\$Name.png`">"
		
		$CurrentGame = [Game]::new($IconUri, $Name, $PlayTime, $LastPlayDate)

		$Games += $CurrentGame 
	}
	
	$Table = $Games | ConvertTo-Html -Fragment
	$report = (Get-Content $WorkingDirectory/ui/index.html.template) -replace "INSERT_TABLE",$Table
	[System.Web.HttpUtility]::HtmlDecode($report) | Out-File -encoding UTF8 $WorkingDirectory/ui/index.html

	$DBConnection.Close()
}
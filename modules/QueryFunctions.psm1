function IsExeEmulator($DetectedExe) {
	
	Log "Checking if Detected Exe is an Emulator"

	$pattern = SQLEscapedMatchPattern $DetectedExe.Trim()
	$FindExeQuery = "SELECT COUNT(*) as '' FROM emulated_platforms WHERE exe_name LIKE '{0}'" -f $pattern

	$ExesFound = (Invoke-SqliteQuery -Query $FindExeQuery -SQLiteConnection $DBConnection).Column1

	return ($ExesFound -gt 0)
}

function DoesEntityExists($Table, $Column, $EntityName){
    Log "Checking if $EntityName Exists in $Table"

	$EntityNamePattern = SQLEscapedMatchPattern($EntityName.Trim())
    $ValidateEntityQuery = "SELECT * FROM {0} WHERE {1} LIKE '{2}'" -f $Table, $Column, $EntityNamePattern

    $EntityFound = (Invoke-SqliteQuery -Query $ValidateEntityQuery -SQLiteConnection $DBConnection)

    return $EntityFound
}

function CheckExeCoreCombo($Exe, $Core){
	Log "Checking if $Exe is already registered with $Core"

	$ExeNamePattern = SQLEscapedMatchPattern($Exe.Trim())
	$CoreNamePattern = SQLEscapedMatchPattern($Core.Trim())
    $ValidateEntityQuery = "SELECT * FROM emulated_platforms WHERE exe_name LIKE '{0}' AND core LIKE '{1}'" -f $ExeNamePattern, $CoreNamePattern

    $EntityFound = (Invoke-SqliteQuery -Query $ValidateEntityQuery -SQLiteConnection $DBConnection)

    return $EntityFound
}

function GetPlayTime($GameName) {
	$GameNamePattern = SQLEscapedMatchPattern($GameName.Trim())
	$GetGamePlayTimeQuery = "SELECT play_time FROM games WHERE name LIKE '{0}'" -f $GameNamePattern

	$RecordedGamePlayTime = (Invoke-SqliteQuery -Query $GetGamePlayTimeQuery -SQLiteConnection $DBConnection).play_time

	return $RecordedGamePlayTime
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

	return $EmulatedGame.Trim()
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

	Log "Detected Core : $CoreName"
	return $CoreName
}

function findEmulatedGamePlatform($DetectedEmulatorExe, $Core) {
	
	$ExePattern = SQLEscapedMatchPattern $DetectedEmulatorExe.Trim()
	$GetPlatformQuery = $null
	if ($Core.Length -eq 0 ) {
		Log "Finding platform for $DetectedEmulatorExe"
		$GetPlatformQuery = "SELECT name FROM emulated_platforms WHERE exe_name LIKE '{0}' AND core LIKE ''" -f $ExePattern
	}
	else {
		Log "Finding platform for $DetectedEmulatorExe and core $Core"
		$CorePattern = SQLEscapedMatchPattern $Core.Trim()
		$GetPlatformQuery = "SELECT name FROM emulated_platforms WHERE exe_name LIKE '{0}' AND core LIKE '{1}'" -f $ExePattern, $CorePattern
	}
	
	$EmulatedGamePlatform = (Invoke-SqliteQuery -Query $GetPlatformQuery -SQLiteConnection $DBConnection).name

	Log "Detected Platform : $EmulatedGamePlatform"
	return $EmulatedGamePlatform
}

function findEmulatedGameDetails($DetectedEmulatorExe) {

	Log "Finding Details of Emulated Game by $DetectedEmulatorExe"

	$EmulatorCommandLine = Get-WmiObject Win32_Process -Filter "name = '$DetectedEmulatorExe.exe'" | Select-Object -ExpandProperty CommandLine

	$EmulatedGameName = findEmulatedGame $DetectedEmulatorExe $EmulatorCommandLine
	if ($EmulatedGameName.Length -eq 0)
	{
		Log "Something went wrong. Detected Emulated Game's Name was of 0 char length."
		return $false
	}

	$CoreName = $null
	if ($DetectedEmulatorExe.ToLower() -like "*retroarch*"){
		Log "Retroarch detected. Triggering core detection"
		$CoreName = findEmulatedGameCore $DetectedEmulatorExe $EmulatorCommandLine

		if ($null -eq $CoreName)
		{
			Log "No Core found for retroarch based emulation. Most likely Platform is not registered. Please register Platform."
			return $false
		}
	}
	
	$EmulatedGamePlatform = findEmulatedGamePlatform $DetectedEmulatorExe $CoreName

	if ($EmulatedGamePlatform -is [system.array])
	{
		Log "Something went wrong. More Than one platform detected. Game Details won't be accurate."
		return $false
	}

	return New-Object PSObject -Property @{ Name = $EmulatedGameName; Exe = $DetectedEmulatorExe ; Platform = $EmulatedGamePlatform }
}

function GetGameDetails($Game) {
	Log "Finding Details of $Game"

	$pattern = SQLEscapedMatchPattern $Game.Trim()
	$GetGameDetailsQuery = "SELECT name, exe_name, platform, play_time, completed, icon FROM games WHERE name LIKE '{0}'" -f $pattern

	$GameDetails = Invoke-SqliteQuery -Query $GetGameDetailsQuery -SQLiteConnection $DBConnection

	return $GameDetails
}

function GetPlatformDetails($Platform) {
	Log "Finding Details of $Platform"

	$pattern = SQLEscapedMatchPattern $Platform.Trim()
	$GetPlatformDetailsQuery = "SELECT * FROM emulated_platforms WHERE name LIKE '{0}'" -f $pattern

	$PlatformDetails = Invoke-SqliteQuery -Query $GetPlatformDetailsQuery -SQLiteConnection $DBConnection

	return $PlatformDetails
}
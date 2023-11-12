function IsExeEmulator($DetectedExe) {	
	Log "Is $DetectedExe is an Emulator?"

	$pattern = SQLEscapedMatchPattern $DetectedExe.Trim()
	$FindExeQuery = "SELECT COUNT(*) as '' FROM emulated_platforms WHERE exe_name LIKE '{0}'" -f $pattern

	$ExesFound = (RunDBQuery $FindExeQuery).Column1

	Log ("Check result: {0}" -f ($ExesFound -gt 0))
	return ($ExesFound -gt 0)
}

function DoesEntityExists($Table, $Column, $EntityName){
    Log "Does $EntityName exists in $Table ?"

	$EntityNamePattern = SQLEscapedMatchPattern($EntityName.Trim())
    $ValidateEntityQuery = "SELECT * FROM {0} WHERE {1} LIKE '{2}'" -f $Table, $Column, $EntityNamePattern

    $EntityFound = RunDBQuery $ValidateEntityQuery

	Log "Discovered entity: $EntityFound"
    return $EntityFound
}

function CheckExeCoreCombo($Exe, $Core) {
	Log "Is $Exe already registered with $Core?"

	$ExeNamePattern = SQLEscapedMatchPattern($Exe.Trim())
	$CoreNamePattern = SQLEscapedMatchPattern($Core.Trim())
    $ValidateEntityQuery = "SELECT * FROM emulated_platforms WHERE exe_name LIKE '{0}' AND core LIKE '{1}'" -f $ExeNamePattern, $CoreNamePattern

    $EntityFound = RunDBQuery $ValidateEntityQuery

	Log "Detected exe core Combo: $EntityFound"
    return $EntityFound
}

function GetPlayTime($GameName) {
	Log "Get existing gameplay time for $GameName"

	$GameNamePattern = SQLEscapedMatchPattern($GameName.Trim())
	$GetGamePlayTimeQuery = "SELECT play_time FROM games WHERE name LIKE '{0}'" -f $GameNamePattern

	$RecordedGamePlayTime = (RunDBQuery $GetGamePlayTimeQuery).play_time

	Log "Detected gameplay time: $RecordedGamePlayTime"
	return $RecordedGamePlayTime
}

function findEmulatedGame($DetectedEmulatorExe, $EmulatorCommandLine) {
	Log "Finding emulated game for $DetectedEmulatorExe"

	$pattern = SQLEscapedMatchPattern $DetectedEmulatorExe.Trim()
	$GetRomExtensionsQuery = "SELECT rom_extensions FROM emulated_platforms WHERE exe_name LIKE '{0}'" -f $pattern
	$RomExtensions = (RunDBQuery $GetRomExtensionsQuery).rom_extensions.Split(',')

	$RomName = $null
	foreach ($RomExtension in $RomExtensions) {
		$RomName = [System.Text.RegularExpressions.Regex]::Match($EmulatorCommandLine, "[^\\]*\.$RomExtension").Value

		if($RomName -ne "") {
			$RomName = $RomName -replace ".$RomExtension", ""
			break 
		}
	}

	$EmulatedGame = [regex]::Replace($RomName, '\([^)]*\)', "")

	Log ("Detected game: {0}" -f $EmulatedGame.Trim())
	return $EmulatedGame.Trim()
}

function findEmulatedGameCore($DetectedEmulatorExe, $EmulatorCommandLine) {
	Log "Finding core in use by $DetectedEmulatorExe"

	$pattern = SQLEscapedMatchPattern $DetectedEmulatorExe.Trim()
	$GetCoresQuery = "SELECT core FROM emulated_platforms WHERE exe_name LIKE '{0}'" -f $pattern
	$CoreName = $null
	$Cores = (RunDBQuery $GetCoresQuery).core
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

	Log "Detected core: $CoreName"
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
	
	$EmulatedGamePlatform = (RunDBQuery $GetPlatformQuery).name

	Log "Detected platform : $EmulatedGamePlatform"
	return $EmulatedGamePlatform
}

function findEmulatedGameDetails($DetectedEmulatorExe) {
	Log "Finding emulated game details for $DetectedEmulatorExe"

	$EmulatorCommandLine = Get-WmiObject Win32_Process -Filter "name = '$DetectedEmulatorExe.exe'" | Select-Object -ExpandProperty CommandLine

	$EmulatedGameName = findEmulatedGame $DetectedEmulatorExe $EmulatorCommandLine
	if ($EmulatedGameName.Length -eq 0)
	{
		Log "Error: Detected emulated game name of 0 char length. Returning"
		return $false
	}

	$CoreName = $null
	if ($DetectedEmulatorExe.ToLower() -like "*retroarch*"){
		Log "Retroarch detected. Detecting core next"
		$CoreName = findEmulatedGameCore $DetectedEmulatorExe $EmulatorCommandLine

		if ($null -eq $CoreName)
		{
			Log "Error: No core detected. Most likely platform not registered. Please register platform."
			return $false
		}
	}
	
	$EmulatedGamePlatform = findEmulatedGamePlatform $DetectedEmulatorExe $CoreName

	if ($EmulatedGamePlatform -is [system.array])
	{
		Log "Error: Multiple platforms detected. Returning."
		return $false
	}

	Log "Found emulated game details. Name: $EmulatedGameName, Exe: $DetectedEmulatorExe, Platform: $EmulatedGamePlatform"
	return New-Object PSObject -Property @{ Name = $EmulatedGameName; Exe = $DetectedEmulatorExe ; Platform = $EmulatedGamePlatform }
}

function GetGameDetails($Game) {
	Log "Finding Details of $Game"

	$pattern = SQLEscapedMatchPattern $Game.Trim()
	$GetGameDetailsQuery = "SELECT name, exe_name, platform, play_time, completed, icon FROM games WHERE name LIKE '{0}'" -f $pattern

	$GameDetails = RunDBQuery $GetGameDetailsQuery

	Log ("Found details: name: {0}, exe_name: {1}, platform: {2}, play_time: {3}" -f $GameDetails.name, $GameDetails.exe_name, $GameDetails.platform, $GameDetails.play_time)
	return $GameDetails
}

function GetPlatformDetails($Platform) {
	Log "Finding Details of $Platform"

	$pattern = SQLEscapedMatchPattern $Platform.Trim()
	$GetPlatformDetailsQuery = "SELECT * FROM emulated_platforms WHERE name LIKE '{0}'" -f $pattern

	$PlatformDetails = RunDBQuery $GetPlatformDetailsQuery

	Log ("Found details: name: {0}, exe_name: {1}, core: {2}" -f $PlatformDetails.name, $PlatformDetails.exe_name, $PlatformDetails.core)
	return $PlatformDetails 
}
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

function FilterListBox {
    param(
        [string]$filterText,
        [System.Windows.Forms.ListBox]$listBox,
        [string[]]$originalItems
    )

    $listBox.Items.Clear()

    foreach ($item in $originalItems) {
        if ($item -like "*$filterText*") {
            $listBox.Items.Add($item)
        }
    }
}

function RenderListBoxForm($Prompt, $List) {
	$form = New-Object System.Windows.Forms.Form
	$form.Text = "Gaming Gaiden"
	$form.Size = New-Object System.Drawing.Size(300,400)
	$form.StartPosition = 'CenterScreen'
	$form.FormBorderStyle = 'FixedDialog'
	$form.Icon = [System.Drawing.Icon]::new(".\icons\running.ico")
	$form.Topmost = $true

	$okButton = New-Object System.Windows.Forms.Button
	$okButton.Location = New-Object System.Drawing.Point(60,320)
	$okButton.Size = New-Object System.Drawing.Size(75,23)
	$okButton.Text = 'OK'
	$okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
	$form.AcceptButton = $okButton
	$form.Controls.Add($okButton)

	$cancelButton = New-Object System.Windows.Forms.Button
	$cancelButton.Location = New-Object System.Drawing.Point(150,320)
	$cancelButton.Size = New-Object System.Drawing.Size(75,23)
	$cancelButton.Text = 'Cancel'
	$cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
	$form.CancelButton = $cancelButton
	$form.Controls.Add($cancelButton)

	$label = New-Object System.Windows.Forms.Label
	$label.Location = New-Object System.Drawing.Point(10,60)
	$label.Size = New-Object System.Drawing.Size(280,20)
	$label.Text = $Prompt
	$form.Controls.Add($label)

	$listBox = New-Object System.Windows.Forms.ListBox
	$listBox.Location = New-Object System.Drawing.Point(10,80)
	$listBox.Size = New-Object System.Drawing.Size(265,20)
	$listBox.Height = 230

	$labelSearch = New-Object System.Windows.Forms.Label
	$labelSearch.AutoSize = $true
	$labelSearch.Location = New-Object Drawing.Point(10, 20)
	$labelSearch.Text = "Search:"
	$form.Controls.Add($labelSearch)

	$textSearch = New-Object System.Windows.Forms.TextBox
	$textSearch.Size = New-Object System.Drawing.Size(200,20)
	$textSearch.Location = New-Object Drawing.Point(70, 20)
	$form.Controls.Add($textSearch)

	$textSearch.Add_TextChanged({
		FilterListBox -filterText $textSearch.Text -listBox $listBox -originalItems $List
	})

	[void] $listBox.Items.AddRange($List)

	$form.Controls.Add($listBox)

	$result = $form.ShowDialog()

	if ( -Not ($result -eq [System.Windows.Forms.DialogResult]::OK))
	{
		Log "Error: Operation cancelled or closed abruptly. Returning";
        exit 1
	}
	
	if ($null -eq $listBox.SelectedItem)
	{
		ShowMessage "You must select an item to proceed. Try Again." "OK" "Error"
		Log "Error: No item selected in list operation. Returning";
		exit 1
	}

	$form.Dispose()
	
	return $listBox.SelectedItem
}

function RenderGameList() {
	Log "Rendering my games list"

	$Database = ".\GamingGaiden.db"
	$DBConnection = New-SQLiteConnection -DataSource $Database
	
	$WorkingDirectory = (Get-Location).Path
	mkdir -f $WorkingDirectory\ui\resources\images
	
	$GetAllGamesQuery = "SELECT name, icon, platform, play_time, completed, last_play_date FROM games"
	
	$GameRecords = (Invoke-SqliteQuery -Query $GetAllGamesQuery -SQLiteConnection $DBConnection)
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

	$Database = ".\GamingGaiden.db"
	$DBConnection = New-SQLiteConnection -DataSource $Database

	$WorkingDirectory = (Get-Location).Path

	$GetDailyPlayTimeDataQuery = "SELECT play_date as date, play_time as time FROM daily_playtime ORDER BY date ASC"

	$DailyPlayTimeData = (Invoke-SqliteQuery -Query $GetDailyPlayTimeDataQuery -SQLiteConnection $DBConnection)

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

	$Database = ".\GamingGaiden.db"
	$DBConnection = New-SQLiteConnection -DataSource $Database

	$WorkingDirectory = (Get-Location).Path

	$GetGamesPlayTimeDataQuery = "SELECT name, play_time as time FROM games Order By play_time DESC"

	$GamesPlayTimeData = (Invoke-SqliteQuery -Query $GetGamesPlayTimeDataQuery -SQLiteConnection $DBConnection)
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

	$Database = ".\GamingGaiden.db"
	$DBConnection = New-SQLiteConnection -DataSource $Database

	$WorkingDirectory = (Get-Location).Path

	$GetGamesPerPlatformDataQuery = "SELECT  platform, COUNT(name) FROM games GROUP BY platform"

	$GetGamesPerPlatformData = (Invoke-SqliteQuery -Query $GetGamesPerPlatformDataQuery -SQLiteConnection $DBConnection)
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

function RenderEditGameForm($SelectedGame) {

	$form = New-Object System.Windows.Forms.Form
	$form.Text = "Gaming Gaiden: Edit Game"
	$form.Size = New-Object Drawing.Size(580, 255)
	$form.StartPosition = 'CenterScreen'
	$form.FormBorderStyle = 'FixedDialog'
	$form.Icon = [System.Drawing.Icon]::new(".\icons\running.ico")
	$form.Topmost = $true

	$labelName = New-Object System.Windows.Forms.Label
	$labelName.AutoSize = $true
	$labelName.Location = New-Object Drawing.Point(170, 20)
	$labelName.Text = "Name:"
	$form.Controls.Add($labelName)

	$textName = New-Object System.Windows.Forms.TextBox
	$textName.Size = New-Object System.Drawing.Size(300,20)
	$textName.Location = New-Object Drawing.Point(245, 20)
	$textName.Text = $SelectedGame.name
	$textName.ReadOnly = $true
	$form.Controls.Add($textName)

	$labelExe = New-Object System.Windows.Forms.Label
	$labelExe.AutoSize = $true
	$labelExe.Location = New-Object Drawing.Point(170, 60)
	$labelExe.Text = "Exe:"
	$form.Controls.Add($labelExe)

	$textExe = New-Object System.Windows.Forms.TextBox
	$textExe.Size = New-Object System.Drawing.Size(200,20)
	$textExe.Location = New-Object Drawing.Point(245, 60)
	$textExe.Text = ($SelectedGame.exe_name + ".exe")
	$textExe.ReadOnly = $true
	$form.Controls.Add($textExe)

	$labelPlatform = New-Object System.Windows.Forms.Label
	$labelPlatform.AutoSize = $true
	$labelPlatform.Location = New-Object Drawing.Point(170, 100)
	$labelPlatform.Text = "Platform:"
	$form.Controls.Add($labelPlatform)

	$textPlatform = New-Object System.Windows.Forms.TextBox
	$textPlatform.Size = New-Object System.Drawing.Size(200,20)
	$textPlatform.Location = New-Object Drawing.Point(245, 100)
	$textPlatform.Text = $SelectedGame.platform
	$form.Controls.Add($textPlatform)

	$labelPlayTime = New-Object System.Windows.Forms.Label
	$labelPlayTime.AutoSize = $true
	$labelPlayTime.Location = New-Object Drawing.Point(170, 140)
	$labelPlayTime.Text = "PlayTime:"
	$form.Controls.Add($labelPlayTime)

	$PlayTimeString = PlayTimeMinsToString $SelectedGame.play_time

	$textPlayTime = New-Object System.Windows.Forms.TextBox
	$textPlayTime.Size = New-Object System.Drawing.Size(200,20)
	$textPlayTime.Location = New-Object Drawing.Point(245, 140)
	$textPlayTime.Text = $PlayTimeString
	$form.Controls.Add($textPlayTime)

	$checkboxCompleted = New-Object Windows.Forms.CheckBox
    $checkboxCompleted.Text = "Finished"
	if($SelectedGame.completed -eq 'TRUE')
	{
		$checkboxCompleted.Checked = $true
	}
    $checkboxCompleted.Top = 140
    $checkboxCompleted.Left = 470
	$form.Controls.Add($checkboxCompleted)

	$IconFileName = ToBase64 $SelectedGame.name
	$ImagePath = "$env:TEMP\GG-{0}-$IconFileName.png" -f $(Get-Random)
	$IconBitmap = BytesToBitmap $SelectedGame.icon
	$IconBitmap.Save($ImagePath,[System.Drawing.Imaging.ImageFormat]::Png)
	$IconBitmap.Dispose()

	$pictureBoxImagePath = New-Object System.Windows.Forms.TextBox
	$pictureBoxImagePath.hide()
	$pictureBoxImagePath.Text = $ImagePath
	$form.Controls.Add($pictureBoxImagePath)

	$pictureBox = New-Object Windows.Forms.PictureBox
	$pictureBox.Location = New-Object Drawing.Point(15, 20)
	$pictureBox.Size = New-Object Drawing.Size(140, 140)
	$pictureBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::CenterImage
	$pictureBox.Image = [System.Drawing.Image]::FromFile($ImagePath)
	$form.Controls.Add($pictureBox)

	$buttonUpdateIcon = New-Object System.Windows.Forms.Button
	$buttonUpdateIcon.Location = New-Object Drawing.Point(48, 175)
	$buttonUpdateIcon.Text = "Edit Icon"
	$buttonUpdateIcon.Add_Click({
		$openFileDialog = OpenFileDialog "Select Game Icon File" 'PNG (*.png)|*.png|JPEG (*.jpg)|*.jpg'
		$result = $openFileDialog.ShowDialog()
		if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
			$ImagePath = ResizeImage $openFileDialog.FileName $SelectedGame.name
			$pictureBoxImagePath.Text = $ImagePath
			$pictureBox.Image = [System.Drawing.Image]::FromFile($ImagePath)
		}
	})
	$form.Controls.Add($buttonUpdateIcon)

	$buttonUpdateExe = New-Object System.Windows.Forms.Button
	$buttonUpdateExe.Location = New-Object Drawing.Point(470, 60)
	$buttonUpdateExe.Text = "Edit Exe"
	$buttonUpdateExe.Add_Click({
		$openFileDialog = OpenFileDialog "Select Executable" 'Executable (*.exe)|*.exe'
		$result = $openFileDialog.ShowDialog()
		if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
			$textExe.Text = (Get-Item $openFileDialog.FileName).Name
		}
	})
	$form.Controls.Add($buttonUpdateExe)

	$buttonRemove = New-Object System.Windows.Forms.Button
	$buttonRemove.Location = New-Object Drawing.Point(470, 100)
	$buttonRemove.Text = "Delete"
	$buttonRemove.Add_Click({
		$GameName = $textName.Text
		$UserInput = UserConfirmationDialog "Confirm Game Removal" "All Data about '$GameName' will be lost.`r`nAre you sure?"
		if ($UserInput.ToLower() -eq 'yes')
		{
			RemoveGame $GameName
			ShowMessage "Removed '$GameName' from Database." "OK" "Asterisk"
			Log "Removed '$GameName' from Database."
			$form.Close()
		}
	})
	$form.Controls.Add($buttonRemove)

	$buttonOK = New-Object System.Windows.Forms.Button
	$buttonOK.Location = New-Object Drawing.Point(245, 175)
	$buttonOK.Text = "OK"
	$buttonOK.Add_Click({

		if($textPlatform.Text -eq "" -Or $textPlayTime.Text -eq "")
		{
			ShowMessage "Platform, Playtime fields cannot be empty. Try Again." "OK" "Error"
			return
		}

		$GameName = $textName.Text
		$PlayTimeInMin = PlayTimeStringToMin $textPlayTime.Text
		if ($null -eq $PlayTimeInMin)
		{
			ShowMessage "Incorrect Playtime Format. Enter exactly 'x Hr y Min'. Resetting PlayTime" "OK" "Error"
			$textPlayTime.Text = $PlayTimeString
			return
		}
		$GameExeName = $textExe.Text -replace ".exe"

		$GameCompleteStatus = $SelectedGame.completed
		if ($checkboxCompleted.Checked -eq $true){
			$GameCompleteStatus = 'TRUE'
		}
		
		UpdateGameOnEdit -GameName $GameName -GameExeName $GameExeName -GameIconPath $pictureBoxImagePath.Text -GamePlayTime $PlayTimeInMin -GameCompleteStatus $GameCompleteStatus -GamePlatform $textPlatform.Text

		ShowMessage "Updated '$GameName' in Database." "OK" "Asterisk"

		$form.Close()
	})
	$form.Controls.Add($buttonOK)

	$buttonCancel = New-Object System.Windows.Forms.Button
	$buttonCancel.Location = New-Object Drawing.Point(370, 175)
	$buttonCancel.Text = "Cancel"
	$buttonCancel.Add_Click({
		$form.Close()
	})
	$form.Controls.Add($buttonCancel)

	$form.ShowDialog()
	$form.Dispose()
}

function RenderEditPlatformForm($SelectedPlatform) {

	$form = New-Object System.Windows.Forms.Form
	$form.Text = "Gaming Gaiden: Edit Platform"
	$form.Size = New-Object Drawing.Size(410, 255)
	$form.StartPosition = 'CenterScreen'
	$form.FormBorderStyle = 'FixedDialog'
	$form.Icon = [System.Drawing.Icon]::new(".\icons\running.ico")
	$form.Topmost = $true

	$labelName = New-Object System.Windows.Forms.Label
	$labelName.AutoSize = $true
	$labelName.Location = New-Object Drawing.Point(10, 20)
	$labelName.Text = "Name:"
	$form.Controls.Add($labelName)

	$textName = New-Object System.Windows.Forms.TextBox
	$textName.Size = New-Object System.Drawing.Size(200,20)
	$textName.Location = New-Object Drawing.Point(85, 20)
	$textName.Text = $SelectedPlatform.name
	$textName.ReadOnly = $true
	$form.Controls.Add($textName)

	$labelExe = New-Object System.Windows.Forms.Label
	$labelExe.AutoSize = $true
	$labelExe.Location = New-Object Drawing.Point(10, 60)
	$labelExe.Text = "Exe:"
	$form.Controls.Add($labelExe)

	$textExe = New-Object System.Windows.Forms.TextBox
	$textExe.Size = New-Object System.Drawing.Size(200,20)
	$textExe.Location = New-Object Drawing.Point(85, 60)
	$textExe.Text = ($SelectedPlatform.exe_name + ".exe")
	$textExe.ReadOnly = $true
	$form.Controls.Add($textExe)

	$labelRomExt = New-Object System.Windows.Forms.Label
	$labelRomExt.AutoSize = $true
	$labelRomExt.Location = New-Object Drawing.Point(10, 100)
	$labelRomExt.Text = "Rom Extns:"
	$form.Controls.Add($labelRomExt)

	$textRomExt = New-Object System.Windows.Forms.TextBox
	$textRomExt.Size = New-Object System.Drawing.Size(200,20)
	$textRomExt.Location = New-Object Drawing.Point(85, 100)
	$textRomExt.Text = $SelectedPlatform.rom_extensions
	$form.Controls.Add($textRomExt)
	
	$buttonUpdateExe = New-Object System.Windows.Forms.Button
	$buttonUpdateExe.Location = New-Object Drawing.Point(300, 58)
	$buttonUpdateExe.Text = "Edit Exe"
	$buttonUpdateExe.Add_Click({
		$openFileDialog = OpenFileDialog "Select Executable" 'Executable (*.exe)|*.exe'
		$result = $openFileDialog.ShowDialog()
		if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
			$textExe.Text = (Get-Item $openFileDialog.FileName).Name
		}
	})
	$form.Controls.Add($buttonUpdateExe)

	if (-Not $SelectedPlatform.core -eq "") {
		$labelCores = New-Object System.Windows.Forms.Label
		$labelCores.AutoSize = $true
		$labelCores.Location = New-Object Drawing.Point(10, 140)
		$labelCores.Text = "Cores:"
		$form.Controls.Add($labelCores)

		$textCore = New-Object System.Windows.Forms.TextBox
		$textCore.Size = New-Object System.Drawing.Size(200,20)
		$textCore.Location = New-Object Drawing.Point(85, 140)
		$textCore.Text = $SelectedPlatform.core
		$textCore.ReadOnly = $true
		$form.Controls.Add($textCore)

		$buttonUpdateCore = New-Object System.Windows.Forms.Button
		$buttonUpdateCore.Location = New-Object Drawing.Point(300, 138)
		$buttonUpdateCore.Text = "Edit Core"
		$buttonUpdateCore.Add_Click({
			$openFileDialog = OpenFileDialog "Select Retroarch Core" 'DLL (*.dll)|*.dll'
			$result = $openFileDialog.ShowDialog()
			if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
				$textCore.Text = (Get-Item $openFileDialog.FileName).Name
			}
		})
		$form.Controls.Add($buttonUpdateCore)
	}

	$buttonRemove = New-Object System.Windows.Forms.Button
	$buttonRemove.Location = New-Object Drawing.Point(300, 18)
	$buttonRemove.Text = "Delete"
	$buttonRemove.Add_Click({
		$PlatformName = $textName.Text
		$UserInput = UserConfirmationDialog "Confirm Platform Removal" "All Data about '$PlatformName' will be lost.`r`nAre you sure?"
		if ($UserInput.ToLower() -eq 'yes')
		{
			RemovePlatform $PlatformName
			ShowMessage "Removed '$PlatformName' from Database." "OK" "Asterisk"
			Log "Removed '$PlatformName' from Database."
			$form.Close()
		}
	})
	$form.Controls.Add($buttonRemove)

	$buttonOK = New-Object System.Windows.Forms.Button
	$buttonOK.Location = New-Object Drawing.Point(85, 175)
	$buttonOK.Text = "OK"
	$buttonOK.Add_Click({

		if ($textRomExt.Text -eq "")
		{
			ShowMessage "Extensions field cannot be empty.`r`nResetting Extensions. Try again." "OK" "Error"
			$textRomExt.Text = $SelectedPlatform.rom_extensions
			return
		}

		$PlatformRomExtensions = $textRomExt.Text
		if (-Not ($PlatformRomExtensions -match '^([a-z]{3},)*([a-z]{3}){1}$'))
		{
			ShowMessage "Error in rom extensions. Please submit extensions as a ',' separated list without the leading '.'`r`ne.g. zip,iso,chd OR zip,iso OR zip" "OK" "Error"
			return
		}

		$PlatformName = $textName.Text
		$EmulatorExeName = $textExe.Text -replace ".exe"
		$EmulatorCore = ""
		if (-Not $SelectedPlatform.core -eq "")
		{
			$EmulatorCore = $textCore.Text
		}
		
		UpdatePlatformOnEdit -PlatformName $PlatformName -EmulatorExeName $EmulatorExeName -EmulatorCore $EmulatorCore -PlatformRomExtensions $PlatformRomExtensions

		ShowMessage "Updated '$PlatformName' in Database." "OK" "Asterisk"

		$form.Close()
	})
	$form.Controls.Add($buttonOK)

	$buttonCancel = New-Object System.Windows.Forms.Button
	$buttonCancel.Location = New-Object Drawing.Point(210, 175)
	$buttonCancel.Text = "Cancel"
	$buttonCancel.Add_Click({
		$form.Close()
	})
	$form.Controls.Add($buttonCancel)

	$form.ShowDialog()
	$form.Dispose()
}

function RenderAddGameForm() {

	$form = New-Object System.Windows.Forms.Form
	$form.Text = "Gaming Gaiden: Add Game"
	$form.Size = New-Object Drawing.Size(580, 255)
	$form.StartPosition = 'CenterScreen'
	$form.FormBorderStyle = 'FixedDialog'
	$form.Icon = [System.Drawing.Icon]::new(".\icons\running.ico")
	$form.Topmost = $true

	$labelName = New-Object System.Windows.Forms.Label
	$labelName.AutoSize = $true
	$labelName.Location = New-Object Drawing.Point(170, 20)
	$labelName.Text = "Name:"
	$form.Controls.Add($labelName)

	$textName = New-Object System.Windows.Forms.TextBox
	$textName.Size = New-Object System.Drawing.Size(300,20)
	$textName.Location = New-Object Drawing.Point(245, 20)
	$form.Controls.Add($textName)

	$labelExe = New-Object System.Windows.Forms.Label
	$labelExe.AutoSize = $true
	$labelExe.Location = New-Object Drawing.Point(170, 60)
	$labelExe.Text = "Exe:"
	$form.Controls.Add($labelExe)

	$textExe = New-Object System.Windows.Forms.TextBox
	$textExe.Size = New-Object System.Drawing.Size(200,20)
	$textExe.Location = New-Object Drawing.Point(245, 60)
	$textExe.ReadOnly = $true
	$form.Controls.Add($textExe)

	$labelPlatform = New-Object System.Windows.Forms.Label
	$labelPlatform.AutoSize = $true
	$labelPlatform.Location = New-Object Drawing.Point(170, 100)
	$labelPlatform.Text = "Platform:"
	$form.Controls.Add($labelPlatform)

	$textPlatform = New-Object System.Windows.Forms.TextBox
	$textPlatform.Size = New-Object System.Drawing.Size(200,20)
	$textPlatform.Location = New-Object Drawing.Point(245, 100)
	$textPlatform.Text = 'PC'
	$textPlatform.ReadOnly = $true
	$form.Controls.Add($textPlatform)

	$labelPlayTime = New-Object System.Windows.Forms.Label
	$labelPlayTime.AutoSize = $true
	$labelPlayTime.Location = New-Object Drawing.Point(170, 140)
	$labelPlayTime.Text = "PlayTime:"
	$form.Controls.Add($labelPlayTime)

	$textPlayTime = New-Object System.Windows.Forms.TextBox
	$textPlayTime.Size = New-Object System.Drawing.Size(200,20)
	$textPlayTime.Location = New-Object Drawing.Point(245, 140)
	$textPlayTime.Text = "0 Hr 0 Min"
	$textPlayTime.ReadOnly = $true
	$form.Controls.Add($textPlayTime)

	$ImagePath = "./icons/default.png"
	$pictureBoxImagePath = New-Object System.Windows.Forms.TextBox
	$pictureBoxImagePath.hide()
	$pictureBoxImagePath.Text = $ImagePath
	$form.Controls.Add($pictureBoxImagePath)

	$pictureBox = New-Object Windows.Forms.PictureBox
	$pictureBox.Location = New-Object Drawing.Point(15, 20)
	$pictureBox.Size = New-Object Drawing.Size(140, 140)
	$pictureBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::CenterImage
	$pictureBox.Image = [System.Drawing.Image]::FromFile($ImagePath)
	$form.Controls.Add($pictureBox)

	$buttonUpdateExe = New-Object System.Windows.Forms.Button
	$buttonUpdateExe.Location = New-Object Drawing.Point(470, 60)
	$buttonUpdateExe.Text = "Add Exe"
	$buttonUpdateExe.Add_Click({
		$openFileDialog = OpenFileDialog "Select Executable" 'Executable (*.exe)|*.exe'
		$result = $openFileDialog.ShowDialog()
		if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
			$textExe.Text = $openFileDialog.FileName

			$GameExeFile = Get-Item $textExe.Text
			$GameExeName = $GameExeFile.BaseName
			if ($textName.Text -eq "") {
				$textName.Text = $GameExeName
			}
			
			$EntityFound = DoesEntityExists "games" "exe_name" $GameExeName
			if ($null -ne $EntityFound)
			{
				ShowMessage "Another Game with Executable $GameExeName.exe already exists`r`nSee Games List." "OK" "Asterisk"
				$textExe.Text = ""
				return
			}

			$GameIconPath="$env:TEMP\GG-{0}.png" -f $(Get-Random)
     		$GameIcon = [System.Drawing.Icon]::ExtractAssociatedIcon($GameExeFile)
     		$GameIcon.ToBitmap().save($GameIconPath)
		
			$pictureBoxImagePath.Text = $GameIconPath
			$pictureBox.Image = [System.Drawing.Image]::FromFile($GameIconPath)

		}
	})
	$form.Controls.Add($buttonUpdateExe)

	$buttonOK = New-Object System.Windows.Forms.Button
	$buttonOK.Location = New-Object Drawing.Point(245, 175)
	$buttonOK.Text = "OK"
	$buttonOK.Add_Click({

		if ($textExe.Text -eq "" -Or $textName.Text -eq "" )
		{
			ShowMessage "Name, Exe fields cannot be empty. Try Again." "OK" "Error"
			return
		}
		$GameName = $textName.Text
		$GameExeFile = Get-Item $textExe.Text
		$GameExeName = $GameExeFile.BaseName
		$GameIconPath = $pictureBoxImagePath.Text
		$GameLastPlayDate = (Get-Date -UFormat %s).Split('.').Get(0)

		SaveGame -GameName $GameName -GameExeName $GameExeName -GameIconPath $GameIconPath `
	 			-GamePlayTime 0 -GameLastPlayDate $GameLastPlayDate -GameCompleteStatus 'FALSE' -GamePlatform 'PC'
		ShowMessage "Registered '$GameName' in Database." "OK" "Asterisk"

		$form.Close()
	})
	$form.Controls.Add($buttonOK)

	$buttonCancel = New-Object System.Windows.Forms.Button
	$buttonCancel.Location = New-Object Drawing.Point(370, 175)
	$buttonCancel.Text = "Cancel"
	$buttonCancel.Add_Click({
		$form.Close()
	})
	$form.Controls.Add($buttonCancel)

	$form.ShowDialog()
	$form.Dispose()
}

function RenderAddPlatformForm() {

	$form = New-Object System.Windows.Forms.Form
	$form.Text = "Gaming Gaiden: Add Emulator"
	$form.Size = New-Object Drawing.Size(410, 255)
	$form.StartPosition = 'CenterScreen'
	$form.FormBorderStyle = 'FixedDialog'
	$form.Icon = [System.Drawing.Icon]::new(".\icons\running.ico")
	$form.Topmost = $true

	$labelName = New-Object System.Windows.Forms.Label
	$labelName.AutoSize = $true
	$labelName.Location = New-Object Drawing.Point(10, 20)
	$labelName.Text = "Platorm:"
	$form.Controls.Add($labelName)

	$textName = New-Object System.Windows.Forms.TextBox
	$textName.Size = New-Object System.Drawing.Size(200,20)
	$textName.Location = New-Object Drawing.Point(85, 20)
	$form.Controls.Add($textName)

	$labelExe = New-Object System.Windows.Forms.Label
	$labelExe.AutoSize = $true
	$labelExe.Location = New-Object Drawing.Point(10, 60)
	$labelExe.Text = "Emulator Exe:"
	$form.Controls.Add($labelExe)

	$textExe = New-Object System.Windows.Forms.TextBox
	$textExe.Size = New-Object System.Drawing.Size(200,20)
	$textExe.Location = New-Object Drawing.Point(85, 60)
	$textExe.ReadOnly = $true
	$form.Controls.Add($textExe)

	$labelRomExt = New-Object System.Windows.Forms.Label
	$labelRomExt.AutoSize = $true
	$labelRomExt.Location = New-Object Drawing.Point(10, 100)
	$labelRomExt.Text = "Rom Extns:"
	$form.Controls.Add($labelRomExt)

	$textRomExt = New-Object System.Windows.Forms.TextBox
	$textRomExt.Size = New-Object System.Drawing.Size(200,20)
	$textRomExt.Location = New-Object Drawing.Point(85, 100)
	$textRomExt.Text = ""
	$form.Controls.Add($textRomExt)
	
	$labelCores = New-Object System.Windows.Forms.Label
	$labelCores.AutoSize = $true
	$labelCores.Location = New-Object Drawing.Point(10, 140)
	$labelCores.Text = "Core:"
	$labelCores.hide()
	$form.Controls.Add($labelCores)

	$textCore = New-Object System.Windows.Forms.TextBox
	$textCore.Size = New-Object System.Drawing.Size(200,20)
	$textCore.Location = New-Object Drawing.Point(85, 140)
	$textCore.Text = ""
	$textCore.ReadOnly = $true
	$textCore.hide()
	$form.Controls.Add($textCore)

	$buttonAddCore = New-Object System.Windows.Forms.Button
	$buttonAddCore.Location = New-Object Drawing.Point(300, 138)
	$buttonAddCore.Text = "Add Core"
	$buttonAddCore.hide()
	$buttonAddCore.Add_Click({
		$openFileDialog = OpenFileDialog "Select Retroarch Core" 'DLL (*.dll)|*.dll'
		$result = $openFileDialog.ShowDialog()
		if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
			$textCore.Text = (Get-Item $openFileDialog.FileName).Name
		}
	})
	$form.Controls.Add($buttonAddCore)

	$buttonAddExe = New-Object System.Windows.Forms.Button
	$buttonAddExe.Location = New-Object Drawing.Point(300, 58)
	$buttonAddExe.Text = "Add Exe"
	$buttonAddExe.Add_Click({
		$openFileDialog = OpenFileDialog "Select Executable" 'Executable (*.exe)|*.exe'
		$result = $openFileDialog.ShowDialog()
		if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
			$textExe.Text = $openFileDialog.FileName
			$ExeName = (Get-Item $textExe.Text).BaseName
			if ($ExeName.ToLower() -like "*retroarch*"){
				$labelCores.show()
				$textCore.show()
				$buttonAddCore.show()
				ShowMessage "Retroarch detected. Please Select Core for Platform." "OK" "Asterisk"
			}
		}
	})
	$form.Controls.Add($buttonAddExe)

	$buttonOK = New-Object System.Windows.Forms.Button
	$buttonOK.Location = New-Object Drawing.Point(85, 175)
	$buttonOK.Text = "OK"
	$buttonOK.Add_Click({

		if ($textExe.Text -eq "" -Or $textName.Text -eq "" -Or $textRomExt.Text -eq "")
		{
			ShowMessage "Platform, Exe and Extensions fields cannot be empty.`r`nTry again." "OK" "Error"
			return
		}
		$EmulatorExeName = (Get-Item $textExe.Text).BaseName
		if ($EmulatorExeName.ToLower() -like "*retroarch*"){
			if ($textCore.Text -eq "")
			{
				ShowMessage "Retroarch detected.`r`nYou must select Core for platform. Try again." "OK" "Error"
				return
			}
		}

		$PlatformName = $textName.Text
		$PlatformFound = DoesEntityExists "emulated_platforms" "name"  $PlatformName
		if ($null -ne $PlatformFound)
		{
			ShowMessage "Platform $PlatformName already exists.`r`nUse Edit Platform setting to check existing platforms." "OK" "Error"
			return
		}

		$EmulatorCore = $textCore.Text

		$ExeCoreComboFound = CheckExeCoreCombo $EmulatorExeName $EmulatorCore
		Log "Checkpoint 1"
		if ($null -ne $ExeCoreComboFound)
		{
			ShowMessage "Executable '$EmulatorExeName.exe' is already registered with core '$EmulatorCore'.`r`nCannot register another platform with same Exe and Core Combination.`r`nUse Edit Platform setting to check existing platforms." "OK" "Error"
			return
		}

		$PlatformRomExtensions = $textRomExt.Text
		if (-Not ($PlatformRomExtensions -match '^([a-z]{3},)*([a-z]{3}){1}$'))
		{
			ShowMessage "Error in rom extensions. Please submit extensions as a ',' separated list without the leading '.'`r`ne.g. zip,iso,chd OR zip,iso OR zip" "OK" "Error"
			return
		}

		SavePlatform -PlatformName $PlatformName -EmulatorExeName $EmulatorExeName -CoreName $EmulatorCore -RomExtensions $PlatformRomExtensions

		ShowMessage "Registered '$PlatformName' in Database." "OK" "Asterisk"

		$form.Close()
	})
	$form.Controls.Add($buttonOK)

	$buttonCancel = New-Object System.Windows.Forms.Button
	$buttonCancel.Location = New-Object Drawing.Point(210, 175)
	$buttonCancel.Text = "Cancel"
	$buttonCancel.Add_Click({
		$form.Close()
	})
	$form.Controls.Add($buttonCancel)

	$form.ShowDialog()
	$form.Dispose()
}
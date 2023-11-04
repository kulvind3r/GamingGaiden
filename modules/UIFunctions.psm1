class Game {
	[ValidateNotNullOrEmpty()][string]$Icon
    [ValidateNotNullOrEmpty()][string]$Name
	[ValidateNotNullOrEmpty()][string]$Platform
    [ValidateNotNullOrEmpty()][string]$Playtime
    [ValidateNotNullOrEmpty()][string]$Last_Played_On
	

    Game($IconUri, $Name, $Platform, $Playtime, $LastPlayDate) {
       $this.Icon = $IconUri
	   $this.Name = $Name
	   $this.Platform = $Platform
       $this.Playtime = $Playtime
	   $this.Last_Played_On = $LastPlayDate
    }
}

function RenderListBoxForm($Prompt, $List) {
	$form = New-Object System.Windows.Forms.Form
	$form.Text = "Gaming Gaiden"
	$form.Size = New-Object System.Drawing.Size(300,360)
	$form.StartPosition = 'CenterScreen'
	$form.FormBorderStyle = 'FixedDialog'
	$form.Icon = [System.Drawing.Icon]::new(".\icons\running.ico")
	$form.Topmost = $true

	$okButton = New-Object System.Windows.Forms.Button
	$okButton.Location = New-Object System.Drawing.Point(60,280)
	$okButton.Size = New-Object System.Drawing.Size(75,23)
	$okButton.Text = 'OK'
	$okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
	$form.AcceptButton = $okButton
	$form.Controls.Add($okButton)

	$cancelButton = New-Object System.Windows.Forms.Button
	$cancelButton.Location = New-Object System.Drawing.Point(150,280)
	$cancelButton.Size = New-Object System.Drawing.Size(75,23)
	$cancelButton.Text = 'Cancel'
	$cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
	$form.CancelButton = $cancelButton
	$form.Controls.Add($cancelButton)

	$label = New-Object System.Windows.Forms.Label
	$label.Location = New-Object System.Drawing.Point(10,20)
	$label.Size = New-Object System.Drawing.Size(280,20)
	$label.Text = $Prompt
	$form.Controls.Add($label)

	$listBox = New-Object System.Windows.Forms.ListBox
	$listBox.Location = New-Object System.Drawing.Point(10,40)
	$listBox.Size = New-Object System.Drawing.Size(265,20)
	$listBox.Height = 230

	[void] $listBox.Items.AddRange($List)

	$form.Controls.Add($listBox)

	$result = $form.ShowDialog()

	if ( -Not ($result -eq [System.Windows.Forms.DialogResult]::OK))
	{
		Log "Operation cancelled or closed abruptly. Returning";
        exit 1
	}
	
	if ($null -eq $listBox.SelectedItem)
	{
		ShowMessage "You must select an item to proceed. Try Again." "OK" "Error"
		exit 1
	}

	$form.Dispose()
	
	return $listBox.SelectedItem
}

function RenderGameList() {

	$Database = ".\GamingGaiden.db"
	Log "Connecting to database for Rendering game list"
	$DBConnection = New-SQLiteConnection -DataSource $Database
	
	$WorkingDirectory = (Get-Location).Path
	mkdir -f $WorkingDirectory\ui\resources\images
	
	$GetAllGamesQuery = "SELECT name, icon, platform, play_time, last_play_date FROM games"
	
	$GameRecords = (Invoke-SqliteQuery -Query $GetAllGamesQuery -SQLiteConnection $DBConnection)
	
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
		
		$CurrentGame = [Game]::new($IconUri, $Name, $GameRecord.platform, $GameRecord.play_time, $GameRecord.last_play_date)

		$Games += $CurrentGame
		$TotalPlayTime += $GameRecord.play_time
	}
	
	$TotalPlayTimeString = PlayTimeMinsToString $TotalPlayTime

	$Table = $Games | ConvertTo-Html -Fragment
	
	$report = (Get-Content $WorkingDirectory\ui\templates\index.html.template) -replace "_GAMESTABLE_", $Table
	$report = $report -replace "Last_Played_On", "Last Played On"
	$report = $report -replace "_TOTALGAMECOUNT_", $Games.length
	$report = $report -replace "_TOTALPLAYTIME_", $TotalPlayTimeString
	
	[System.Web.HttpUtility]::HtmlDecode($report) | Out-File -encoding UTF8 $WorkingDirectory\ui\index.html

	$DBConnection.Close()
}

function RenderEditGameForm($SelectedGame) {

	$form = New-Object System.Windows.Forms.Form
	$form.Text = "Gameplay Gaiden: Edit Game"
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

	$IconFileName = ToBase64 $SelectedGame.name
	$ImagePath = "$env:TEMP\GG-{0}-$IconFileName.png" -f $(Get-Random)
	$IconBitmap = BytesToBitmap $SelectedGame.icon
	$IconBitmap.Save($ImagePath,[System.Drawing.Imaging.ImageFormat]::Png)
	$IconBitmap.Dispose()

	$pictureBox = New-Object Windows.Forms.PictureBox
	$pictureBox.Location = New-Object Drawing.Point(15, 20)
	$pictureBox.Size = New-Object Drawing.Size(140, 140)
	$pictureBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::CenterImage
	$pictureBox.Image = [System.Drawing.Image]::FromFile($ImagePath)
	$form.Controls.Add($pictureBox)

	$pictureBoxImagePath = New-Object System.Windows.Forms.TextBox
	$pictureBoxImagePath.hide()
	$form.Controls.Add($pictureBoxImagePath)

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

		$GameName = $textName.Text
		$PlayTimeInMin = PlayTimeStringToMin $textPlayTime.Text
		$GameExeName = $textExe.Text -replace ".exe"
		
		UpdateGameOnEdit -GameName $GameName -GameExeName $GameExeName -GameIconPath $pictureBoxImagePath.Text -GamePlayTime $PlayTimeInMin -GameCompleteStatus 'FALSE' -GamePlatform $textPlatform.Text

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

	# Show the form
	$form.ShowDialog()

	
	# Dispose of the form
	$form.Dispose()
}

function RenderEditPlatformForm($SelectedPlatform) {

	$form = New-Object System.Windows.Forms.Form
	$form.Text = "Gameplay Gaiden: Edit Platform"
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

		$PlatformName = $textName.Text
		$EmulatorExeName = $textExe.Text -replace ".exe"
		$EmulatorCore = ""
		if (-Not $SelectedPlatform.core -eq "")
		{
			$EmulatorCore = $textCore.Text
		}
		
		UpdatePlatformOnEdit -PlatformName $PlatformName -EmulatorExeName $EmulatorExeName -EmulatorCore $EmulatorCore -PlatformRomExtensions $textRomExt.Text

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

	# Show the form
	$form.ShowDialog()

	# Dispose of the form
	$form.Dispose()
}
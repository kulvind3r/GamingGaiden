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

function RenderEditGameForm($GamesList) {

	$EditGameForm = CreateForm "Gaming Gaiden: Edit Game" 880 265 ".\icons\running.ico"

	$ImagePath = "./icons/default.png"
	
	# Hidden fields to save non user editable values
	$pictureBoxImagePath = CreateTextBox $ImagePath 879 264 1 1; $pictureBoxImagePath.hide(); $EditGameForm.Controls.Add($pictureBoxImagePath)
	$textOriginalGameName = CreateTextBox "" 879 264 1 1; $textOriginalGameName.hide(); $EditGameForm.Controls.Add($textOriginalGameName)
	# Hidden fields end
	
	$listBox = New-Object System.Windows.Forms.ListBox
	$listBox.Location = New-Object System.Drawing.Point(585,60)
	$listBox.Size = New-Object System.Drawing.Size(260,20)
	$listBox.Height = 150
	[void] $listBox.Items.AddRange($GamesList)

	$labelSearch = Createlabel "Search:" 585 20; $EditGameForm.Controls.Add($labelSearch)
	$textSearch = CreateTextBox "" 645 20 200 20;	$EditGameForm.Controls.Add($textSearch)

	$textSearch.Add_TextChanged({
		FilterListBox -filterText $textSearch.Text -listBox $listBox -originalItems $GamesList
	})

	$labelName = Createlabel "Name:" 170 20; $EditGameForm.Controls.Add($labelName)
	$textName = CreateTextBox "" 245 20 300 20;	$EditGameForm.Controls.Add($textName)

	$labelExe = Createlabel "Exe:" 170 60; $EditGameForm.Controls.Add($labelExe)
	$textExe = CreateTextBox "" 245 60 200 20; $textExe.ReadOnly = $true; $EditGameForm.Controls.Add($textExe)

	$labelPlatform = Createlabel "Platform:" 170 100; $EditGameForm.Controls.Add($labelPlatform)
	$textPlatform = CreateTextBox "" 245 100 200 20; $EditGameForm.Controls.Add($textPlatform)

	$labelPlayTime = Createlabel "PlayTime:" 170 140; $EditGameForm.Controls.Add($labelPlayTime)
	$textPlayTime = CreateTextBox "" 245 140 200 20; $EditGameForm.Controls.Add($textPlayTime)

	$checkboxCompleted = New-Object Windows.Forms.CheckBox
    $checkboxCompleted.Text = "Finished"
    $checkboxCompleted.Top = 140
    $checkboxCompleted.Left = 470
	$EditGameForm.Controls.Add($checkboxCompleted)

	$labelPictureBox = Createlabel "Game Icon" 57 165; $EditGameForm.Controls.Add($labelPictureBox)
	$pictureBox = CreatePictureBox $ImagePath 15 20 140 140
	$EditGameForm.Controls.Add($pictureBox)

	$listBox.Add_SelectedIndexChanged({
		$SelectedGame = GetGameDetails $listBox.SelectedItem
		
		$textName.Text = $SelectedGame.name
		$textOriginalGameName.Text = $SelectedGame.name
		$textExe.Text =  ($SelectedGame.exe_name + ".exe")
		$textPlatform.Text = $SelectedGame.platform
		$checkboxCompleted.Checked = ($SelectedGame.completed -eq 'TRUE')

		$PlayTimeString = PlayTimeMinsToString $SelectedGame.play_time
		$textPlayTime.Text = $PlayTimeString

		$IconFileName = ToBase64 $SelectedGame.name
		$ImagePath = "$env:TEMP\GG-{0}-$IconFileName.png" -f $(Get-Random)
		$IconBitmap = BytesToBitmap $SelectedGame.icon
		$IconBitmap.Save($ImagePath,[System.Drawing.Imaging.ImageFormat]::Png)
		$ImagePath = ResizeImage -ImagePath $ImagePath -GameName $SelectedGame.name
		$IconBitmap.Dispose()

		$pictureBoxImagePath.Text = $ImagePath
		$pictureBox.Image = [System.Drawing.Image]::FromFile($ImagePath)

	})
	$EditGameForm.Controls.Add($listBox)

	$buttonSearchIcon = CreateButton "Search" 20 185
	$buttonSearchIcon.Size = New-Object System.Drawing.Size(60, 23)
	$buttonSearchIcon.Add_Click({
		$GameName = $textName.Text
		if ($GameName -eq "") { 
			ShowMessage "Please enter a name first." "OK" "Error"
			return
		}
		$GameNameEncoded = $GameName -replace " ","+"
		Start-Process "https://www.google.com/search?as_q=Cover+Art+$GameNameEncoded+Game&imgar=s&udm=2"
	})
	$EditGameForm.Controls.Add($buttonSearchIcon)

	$buttonUpdateIcon = CreateButton "Update" 90 185
	$buttonUpdateIcon.Size = New-Object System.Drawing.Size(60, 23)
	$buttonUpdateIcon.Add_Click({
		$downloadsDirectoryPath = (New-Object -ComObject Shell.Application).Namespace('shell:Downloads').Self.Path
		$openFileDialog = OpenFileDialog "Select Game Icon File" 'Image (*.png, *.jpg, *.jpeg)|*.png;*.jpg;*.jpeg' $downloadsDirectoryPath
		$result = $openFileDialog.ShowDialog()
		if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
			$ImagePath = ResizeImage $openFileDialog.FileName $textName.name
			$pictureBoxImagePath.Text = $ImagePath
			$pictureBox.Image = [System.Drawing.Image]::FromFile($ImagePath)
		}
	})
	$EditGameForm.Controls.Add($buttonUpdateIcon)

	$buttonUpdateExe = CreateButton "Edit Exe" 470 60
	$buttonUpdateExe.Add_Click({
		$openFileDialog = OpenFileDialog "Select Executable" 'Executable (*.exe)|*.exe'
		$result = $openFileDialog.ShowDialog()
		if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
			$textExe.Text = (Get-Item $openFileDialog.FileName).Name
		}
	})
	$EditGameForm.Controls.Add($buttonUpdateExe)

	$buttonRemove = CreateButton "Delete" 470 100
	$buttonRemove.Add_Click({
		$GameName = $textName.Text
		$UserInput = UserConfirmationDialog "Confirm Game Removal" "All Data about '$GameName' will be lost.`r`nAre you sure?"
		if ($UserInput.ToLower() -eq 'yes')	{
			RemoveGame $GameName
			ShowMessage "Removed '$GameName' from Database." "OK" "Asterisk"
			Log "Removed '$GameName' from Database."
		}
	})
	$EditGameForm.Controls.Add($buttonRemove)

	$buttonOK = CreateButton "OK" 245 185
	$buttonOK.Add_Click({
		if($textName.Text -eq "" -Or $textPlatform.Text -eq "" -Or $textPlayTime.Text -eq "")	{
			ShowMessage "Name, Platform, Playtime fields cannot be empty. Try Again." "OK" "Error"
			return
		}

		$GameName = $textName.Text

		$PlayTimeInMin = PlayTimeStringToMin $textPlayTime.Text
		if ($null -eq $PlayTimeInMin) {
			ShowMessage "Incorrect Playtime Format. Enter exactly 'x Hr y Min'. Resetting PlayTime" "OK" "Error"
			$textPlayTime.Text = $PlayTimeString
			return
		}

		$GameExeName = $textExe.Text -replace ".exe"

		$GameCompleteStatus = $checkboxCompleted.Checked
		
		UpdateGameOnEdit -OriginalGameName $textOriginalGameName.Text -GameName $GameName -GameExeName $GameExeName -GameIconPath $pictureBoxImagePath.Text -GamePlayTime $PlayTimeInMin -GameCompleteStatus $GameCompleteStatus -GamePlatform $textPlatform.Text

		ShowMessage "Updated '$GameName' in Database." "OK" "Asterisk"

		$GamesList = (RunDBQuery "SELECT name FROM games").name
		$listBox.Items.Clear(); $listBox.Items.AddRange($GamesList); 
		$listBox.SelectedIndex = $listBox.FindString($GameName)
	})
	$EditGameForm.Controls.Add($buttonOK)

	$buttonCancel = CreateButton "Cancel" 370 185; $buttonCancel.Add_Click({ $EditGameForm.Close() }); $EditGameForm.Controls.Add($buttonCancel)
	
	#Select the first game to populate the form before rendering for first time
	$listBox.SelectedIndex = 0
	
	$EditGameForm.ShowDialog()
	$EditGameForm.Dispose()
}

function RenderEditPlatformForm($PlatformsList) {

	$EditPlatformForm =	CreateForm "Gaming Gaiden: Edit Platform" 655  330 ".\icons\running.ico"

	# Hidden fields to save non user editable values
	$textOriginalPlatformName = CreateTextBox "" 654 329 1 1; $textOriginalPlatformName.hide(); $EditPlatformForm.Controls.Add($textOriginalPlatformName)
	# Hidden fields end

	$listBox = New-Object System.Windows.Forms.ListBox
	$listBox.Location = New-Object System.Drawing.Point(400,65)
	$listBox.Size = New-Object System.Drawing.Size(225,20)
	$listBox.Height = 212
	[void] $listBox.Items.AddRange($PlatformsList)

	$labelSearch = Createlabel "Search:" 400 20; $EditPlatformForm.Controls.Add($labelSearch)
	$textSearch = CreateTextBox "" 465 20 160 20; $EditPlatformForm.Controls.Add($textSearch)

	$textSearch.Add_TextChanged({
		FilterListBox -filterText $textSearch.Text -listBox $listBox -originalItems $PlatformsList
	})
	
	$labelName = Createlabel "Platorm:" 10 20; $EditPlatformForm.Controls.Add($labelName)
	$textName = CreateTextBox "" 75 20 200 20; $EditPlatformForm.Controls.Add($textName)

	$labelExe = Createlabel "Emulator`nExe List:" 10 79; $EditPlatformForm.Controls.Add($labelExe)
	$textExe = CreateTextBox "" 75 82 200 20; $textExe.ReadOnly = $true;$EditPlatformForm.Controls.Add($textExe)

	$labelRomExt = Createlabel "Rom Extns:" 10 146;	$EditPlatformForm.Controls.Add($labelRomExt)
	$textRomExt = CreateTextBox "" 75 144 200 20;	$EditPlatformForm.Controls.Add($textRomExt)

	$labelCores = Createlabel "Cores:" 10 208; $EditPlatformForm.Controls.Add($labelCores)
	$textCore = CreateTextBox "" 75 206 200 20;	$textCore.ReadOnly = $true;	$EditPlatformForm.Controls.Add($textCore)

	$listBox.Add_SelectedIndexChanged({
		$SelectedPlatform = GetPlatformDetails $listBox.SelectedItem

		$textName.Text = $SelectedPlatform.name
		$textOriginalPlatformName.Text = $SelectedPlatform.name
		$textRomExt.Text = $SelectedPlatform.rom_extensions

		$exeList = ($SelectedPlatform.exe_name -replace "," , ".exe,") + ".exe"
		$textExe.Text = $exeList

		$HasCore = -Not ($SelectedPlatform.core -eq "")

		if ($HasCore) {
			$textCore.Text = $SelectedPlatform.core

			$buttonUpdateCore.show()
			$labelCores.show()
			$textCore.show()

			$EditPlatformForm.Size = New-Object System.Drawing.Size(655, 330)
			$listBox.Height = 212
			$buttonOK.Location = New-Object System.Drawing.Point(85, 254)
			$buttonCancel.Location = New-Object System.Drawing.Point(210, 254)
		}
		else {
			$buttonUpdateCore.hide()
			$labelCores.hide()
			$textCore.Text = ""; $textCore.hide()

			$EditPlatformForm.Size = New-Object System.Drawing.Size(655, 277)
			$listBox.Height = 166
			$buttonOK.Location = New-Object System.Drawing.Point(85, 201)
			$buttonCancel.Location = New-Object System.Drawing.Point(210, 201)
		}
	})
	$EditPlatformForm.Controls.Add($listBox)
	
	$buttonUpdateCore = CreateButton "Edit Core" 300 204
	$buttonUpdateCore.Add_Click({
		$openFileDialog = OpenFileDialog "Select Retroarch Core" 'DLL (*.dll)|*.dll'
		$result = $openFileDialog.ShowDialog()
		if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
			$textCore.Text = (Get-Item $openFileDialog.FileName).Name
		}
	})
	$EditPlatformForm.Controls.Add($buttonUpdateCore)

	$buttonUpdateExe = CreateButton "Add Exe" 300 65
	$buttonUpdateExe.Add_Click({
		$openFileDialog = OpenFileDialog "Select Executable" 'Executable (*.exe)|*.exe'
		$result = $openFileDialog.ShowDialog()
		if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
			$existingExes = $textExe.Text
			$selectedExe = (Get-Item $openFileDialog.FileName).Name
			if ($existingExes -eq "") {
				$textExe.Text = $selectedExe
			}
			else {
				$textExe.Text = ("$existingExes,$selectedExe" -split ',' | Select-Object -Unique ) -join ','
			}
		}
	})
	$EditPlatformForm.Controls.Add($buttonUpdateExe)

	$buttonClearExe = CreateButton "Clear List" 300 95
	$buttonClearExe.Add_Click({
		$textExe.Text = ""
	})
	$EditPlatformForm.Controls.Add($buttonClearExe)

	$buttonRemove = CreateButton "Delete" 300 18
	$buttonRemove.Add_Click({
		$PlatformName = $textName.Text
		$UserInput = UserConfirmationDialog "Confirm Platform Removal" "All Data about '$PlatformName' will be lost.`r`nAre you sure?"
		if ($UserInput.ToLower() -eq 'yes')	{
			RemovePlatform $PlatformName
			ShowMessage "Removed '$PlatformName' from Database." "OK" "Asterisk"
			Log "Removed '$PlatformName' from Database."
		}
	})
	$EditPlatformForm.Controls.Add($buttonRemove)

	$buttonOK = CreateButton "OK" 85 254
	$buttonOK.Add_Click({
		if ($textRomExt.Text -eq "" -Or $textExe.Text -eq "") {
			ShowMessage "Exe List or Rom Extensions field cannot be empty.`r`nTry again." "OK" "Error"
			return
		}

		$PlatformRomExtensions = $textRomExt.Text
		if (-Not ($PlatformRomExtensions -match '^([a-z]{3},)*([a-z]{3}){1}$')) {
			ShowMessage "Error in rom extensions. Please submit extensions as a ',' separated list without the leading '.'`r`ne.g. zip,iso,chd OR zip,iso OR zip" "OK" "Error"
			return
		}

		$PlatformName = $textName.Text
		$EmulatorExeList = $textExe.Text -replace ".exe"
		
		UpdatePlatformOnEdit -OriginalPlatformName $textOriginalPlatformName.Text -PlatformName $PlatformName -EmulatorExeList $EmulatorExeList -EmulatorCore $textCore.Text -PlatformRomExtensions $PlatformRomExtensions

		ShowMessage "Updated '$PlatformName' in Database." "OK" "Asterisk"

		$PlatformsList = (RunDBQuery "SELECT name FROM emulated_platforms").name
		$listBox.Items.Clear(); $listBox.Items.AddRange($PlatformsList); 
		$listBox.SelectedIndex = $listBox.FindString($PlatformName)
	})
	$EditPlatformForm.Controls.Add($buttonOK)

	$buttonCancel = CreateButton "Cancel" 210 254;	$buttonCancel.Add_Click({ $EditPlatformForm.Close() });	$EditPlatformForm.Controls.Add($buttonCancel)

	#Select the first platform to populate the form before rendering for first time
	$listBox.SelectedIndex = 0

	$EditPlatformForm.ShowDialog()
	$EditPlatformForm.Dispose()
}

function RenderAddGameForm() {

	$AddGameForm =	CreateForm "Gaming Gaiden: Add Game" 580 265 ".\icons\running.ico"

	$labelName = Createlabel "Name:" 170 20; $AddGameForm.Controls.Add($labelName)
	$textName = CreateTextBox "" 245 20 300 20;	$AddGameForm.Controls.Add($textName)

	$labelExe = Createlabel "Exe:" 170 60; $AddGameForm.Controls.Add($labelExe)
	$textExe = CreateTextBox "" 245 60 200 20; $textExe.ReadOnly = $true; $AddGameForm.Controls.Add($textExe)

	$labelPlatform = Createlabel "Platform:" 170 100; $AddGameForm.Controls.Add($labelPlatform)
	$textPlatform = CreateTextBox "PC" 245 100 200 20; $textPlatform.ReadOnly = $true; $AddGameForm.Controls.Add($textPlatform)

	$labelPlayTime = Createlabel "PlayTime:" 170 140; $AddGameForm.Controls.Add($labelPlayTime)
	$textPlayTime = CreateTextBox "0 Hr 0 Min" 245 140 200 20; $textPlayTime.ReadOnly = $true; $AddGameForm.Controls.Add($textPlayTime)

	$buttonSearchIcon = CreateButton "Search" 20 185
	$buttonSearchIcon.Size = New-Object System.Drawing.Size(60, 23)
	$buttonSearchIcon.Add_Click({
		$GameName = $textName.Text
		if ($GameName -eq "") { 
			ShowMessage "Please enter a name first." "OK" "Error"
			return
		}
		$GameNameEncoded = $GameName -replace " ","+"
		Start-Process "https://www.google.com/search?as_q=Cover+Art+$GameNameEncoded+Game&imgar=s&udm=2"
	})
	$AddGameForm.Controls.Add($buttonSearchIcon)

	$ImagePath = "./icons/default.png"
	$pictureBoxImagePath = CreateTextBox $ImagePath 579 254 1 1; $pictureBoxImagePath.hide(); $AddGameForm.Controls.Add($pictureBoxImagePath)
	
	$pictureBox = CreatePictureBox $ImagePath 15 20 140 140
	$AddGameForm.Controls.Add($pictureBox)

	$labelPictureBox = Createlabel "Game Icon" 57 165; $AddGameForm.Controls.Add($labelPictureBox)

	$buttonUpdateIcon = CreateButton "Update" 90 185
	$buttonUpdateIcon.Size = New-Object System.Drawing.Size(60, 23)
	$buttonUpdateIcon.Add_Click({
		$downloadsDirectoryPath = (New-Object -ComObject Shell.Application).Namespace('shell:Downloads').Self.Path
		$openFileDialog = OpenFileDialog "Select Game Icon File" 'Image (*.png, *.jpg, *.jpeg)|*.png;*.jpg;*.jpeg' $downloadsDirectoryPath
		$result = $openFileDialog.ShowDialog()
		if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
			$ImagePath = ResizeImage $openFileDialog.FileName "GG-NEW_GAME.png"
			$pictureBoxImagePath.Text = $ImagePath
			$pictureBox.Image = [System.Drawing.Image]::FromFile($ImagePath)
		}
	})
	$AddGameForm.Controls.Add($buttonUpdateIcon)

	$buttonUpdateExe = CreateButton "Add Exe" 470 60
	$buttonUpdateExe.Add_Click({

		$openFileDialog = OpenFileDialog "Select Executable" 'Executable (*.exe)|*.exe'
		$result = $openFileDialog.ShowDialog()

		if ($result -eq [System.Windows.Forms.DialogResult]::OK) {	
			$textExe.Text = $openFileDialog.FileName
			$GameExeFile = Get-Item $textExe.Text
			$GameExeName = $GameExeFile.BaseName

			if ($textName.Text -eq "") { $textName.Text = $GameExeName }
			
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
	$AddGameForm.Controls.Add($buttonUpdateExe)

	$buttonOK = CreateButton "OK" 245 185
	$buttonOK.Add_Click({

		if ($textExe.Text -eq "" -Or $textName.Text -eq "" ) {
			ShowMessage "Name, Exe fields cannot be empty. Try Again." "OK" "Error"
			return
		}
		$GameName = $textName.Text
		$GameExeFile = Get-Item $textExe.Text
		$GameExeName = $GameExeFile.BaseName
		$GameIconPath = $pictureBoxImagePath.Text
		$GameLastPlayDate = (Get-Date -UFormat %s).Split('.').Get(0)

		SaveGame -GameName $GameName -GameExeName $GameExeName -GameIconPath $GameIconPath `
	 			-GamePlayTime 0 -GameIdleTime 0 -GameLastPlayDate $GameLastPlayDate -GameCompleteStatus 'FALSE' -GamePlatform 'PC' -GameSessionCount 0
		ShowMessage "Registered '$GameName' in Database." "OK" "Asterisk"

		$AddGameForm.Close()
	})
	$AddGameForm.Controls.Add($buttonOK)

	$buttonCancel = CreateButton "Cancel" 370 185; $buttonCancel.Add_Click({ $AddGameForm.Close() }); $AddGameForm.Controls.Add($buttonCancel)

	$AddGameForm.ShowDialog()
	$AddGameForm.Dispose()
}

function RenderAddPlatformForm() {

	$AddPlatform =	CreateForm "Gaming Gaiden: Add Emulator" 405 275 ".\icons\running.ico"

	$labelName = Createlabel "Platorm:" 10 20; $AddPlatform.Controls.Add($labelName)
	$textName = CreateTextBox "" 85 20 200 20; $AddPlatform.Controls.Add($textName)

	$labelExe = Createlabel "Emulator`nExe List:" 10 79; $AddPlatform.Controls.Add($labelExe)
	$textExe = CreateTextBox "" 85 82 200 20; $textExe.ReadOnly = $true; $AddPlatform.Controls.Add($textExe)

	$labelRomExt = Createlabel "Rom Extns:" 10 146;	$AddPlatform.Controls.Add($labelRomExt)
	$textRomExt = CreateTextBox "" 85 144 200 20; $AddPlatform.Controls.Add($textRomExt)
	
	$labelCores = Createlabel "Core:" 10 208; $labelCores.hide(); $AddPlatform.Controls.Add($labelCores)
	$textCore = CreateTextBox "" 85 206 200 20;	$textCore.ReadOnly = $true;	$textCore.hide(); $AddPlatform.Controls.Add($textCore)

	$buttonAddCore = CreateButton "Add Core" 300 204; $buttonAddCore.hide()
	$buttonAddCore.Add_Click({
		$openFileDialog = OpenFileDialog "Select Retroarch Core" 'DLL (*.dll)|*.dll'
		$result = $openFileDialog.ShowDialog()
		if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
			$textCore.Text = (Get-Item $openFileDialog.FileName).Name
		}
	})
	$AddPlatform.Controls.Add($buttonAddCore)

	$buttonAddExe = CreateButton "Add Exe" 300 65
	$buttonAddExe.Add_Click({
		$openFileDialog = OpenFileDialog "Select Executable" 'Executable (*.exe)|*.exe'
		$result = $openFileDialog.ShowDialog()
		if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
			$existingExes = $textExe.Text
			$selectedExe = (Get-Item $openFileDialog.FileName).Name
			if ($existingExes -eq "") {
				$textExe.Text = $selectedExe
			}
			else {
				$textExe.Text = ("$existingExes,$selectedExe" -split ',' | Select-Object -Unique ) -join ','
			}
			$EmulatorExeList = $textExe.Text
			if ($EmulatorExeList.ToLower() -like "*retroarch*"){
				$AddPlatform.Size = New-Object System.Drawing.Size(405, 325)
				$buttonOK.Location = New-Object System.Drawing.Point(85, 250)
				$buttonCancel.Location = New-Object System.Drawing.Point(210, 250)

				$labelCores.show()
				$textCore.show()
				$buttonAddCore.show()
				ShowMessage "Retroarch detected. Please Select Core for Platform." "OK" "Asterisk"
			}
		}
	})
	$AddPlatform.Controls.Add($buttonAddExe)

	$buttonClearExe = CreateButton "Clear List" 300 95
	$buttonClearExe.Add_Click({
		$textExe.Text = ""
	})
	$AddPlatform.Controls.Add($buttonClearExe)

	$buttonOK = CreateButton "OK" 85 200
	$buttonOK.Add_Click({

		if ($textExe.Text -eq "" -Or $textName.Text -eq "" -Or $textRomExt.Text -eq "")	{
			ShowMessage "Platform, Exe and Extensions fields cannot be empty.`r`nTry again." "OK" "Error"
			return
		}

		$EmulatorExeList = $textExe.Text -replace ".exe"
		if ($EmulatorExeList.ToLower() -like "*retroarch*") {
			if ($textCore.Text -eq "")
			{
				ShowMessage "Retroarch detected.`r`nYou must select Core for platform. Try again." "OK" "Error"
				return
			}
		}

		$PlatformName = $textName.Text
		$PlatformFound = DoesEntityExists "emulated_platforms" "name"  $PlatformName
		if ($null -ne $PlatformFound) {
			ShowMessage "Platform $PlatformName already exists.`r`nUse Edit Emulator setting to check existing platforms." "OK" "Error"
			return
		}

		$EmulatorCore = $textCore.Text

		$ExeCoreComboFound = CheckExeCoreCombo $EmulatorExeList $EmulatorCore
		if ($null -ne $ExeCoreComboFound) {
			ShowMessage "Executables in the list '$EmulatorExeList' is already registered with core '$EmulatorCore'.`r`nCannot register another platform with same Exe and Core Combination.`r`nUse Edit Platform setting to check existing platforms." "OK" "Error"
			return
		}

		$PlatformRomExtensions = $textRomExt.Text
		if (-Not ($PlatformRomExtensions -match '^([a-z]{3},)*([a-z]{3}){1}$'))	{
			ShowMessage "Error in rom extensions. Please submit extensions as a ',' separated list without the leading '.'`r`ne.g. zip,iso,chd OR zip,iso OR zip" "OK" "Error"
			return
		}

		SavePlatform -PlatformName $PlatformName -EmulatorExeList $EmulatorExeList -CoreName $EmulatorCore -RomExtensions $PlatformRomExtensions

		ShowMessage "Registered '$PlatformName' in Database." "OK" "Asterisk"

		$AddPlatform.Close()
	})
	$AddPlatform.Controls.Add($buttonOK)

	$buttonCancel = CreateButton "Cancel" 210 200; $buttonCancel.Add_Click({ $AddPlatform.Close() }); $AddPlatform.Controls.Add($buttonCancel)

	$AddPlatform.ShowDialog()
	$AddPlatform.Dispose()
}
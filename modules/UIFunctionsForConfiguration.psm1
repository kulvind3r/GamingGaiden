function CreateForm($Text, $SizeX, $SizeY, $IconPath) {
	$form = New-Object System.Windows.Forms.Form
	$form.Text = $Text
	$form.Size = New-Object Drawing.Size($SizeX, $SizeY)
	$form.StartPosition = 'CenterScreen'
	$form.FormBorderStyle = 'FixedDialog'
	$form.Icon = [System.Drawing.Icon]::new($IconPath)
	$form.Topmost = $true

	return $form
}

function Createlabel($Text, $DrawX, $DrawY) {
	$label = New-Object System.Windows.Forms.Label
	$label.AutoSize = $true
	$label.Location = New-Object Drawing.Point($DrawX, $DrawY)
	$label.Text = $Text

	return $label
}

function CreateTextBox($Text, $DrawX, $DrawY, $SizeX, $SizeY) {
	$textBox = New-Object System.Windows.Forms.TextBox
	$textBox.Text = $Text
	$textBox.Location = New-Object Drawing.Point($DrawX, $DrawY)
	$textBox.Size = New-Object System.Drawing.Size($SizeX,$SizeY)
	
	return $textBox
}

function CreateButton($Text, $DrawX, $DrawY) {
	$button = New-Object System.Windows.Forms.Button
	$button.Location = New-Object Drawing.Point($DrawX, $DrawY)
	$button.Text = $Text

	return $button
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

	$ListBoxForm = CreateForm "Gaming Gaiden" 300 400 ".\icons\running.ico"

	$okButton = CreateButton "OK" 60 320
	$okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
	$ListBoxForm.AcceptButton = $okButton
	$ListBoxForm.Controls.Add($okButton)

	$cancelButton = CreateButton "Cancel" 150 320
	$cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
	$ListBoxForm.CancelButton = $cancelButton
	$ListBoxForm.Controls.Add($cancelButton)

	$label = Createlabel $Prompt 10 60;	$label.Size = New-Object System.Drawing.Size(280,20); $ListBoxForm.Controls.Add($label)

	$listBox = New-Object System.Windows.Forms.ListBox
	$listBox.Location = New-Object System.Drawing.Point(10,80)
	$listBox.Size = New-Object System.Drawing.Size(265,20)
	$listBox.Height = 230

	$labelSearch = Createlabel "Search:" 10 20;	$ListBoxForm.Controls.Add($labelSearch)

	$textSearch = CreateTextBox "" 70 20 200 20; $ListBoxForm.Controls.Add($textSearch)

	$textSearch.Add_TextChanged({
		FilterListBox -filterText $textSearch.Text -listBox $listBox -originalItems $List
	})

	[void] $listBox.Items.AddRange($List)

	$ListBoxForm.Controls.Add($listBox)

	$result = $ListBoxForm.ShowDialog()

	if ( -Not ($result -eq [System.Windows.Forms.DialogResult]::OK)) {
		Log "Error: Operation cancelled or closed abruptly. Returning";
        exit 1
	}
	
	if ($null -eq $listBox.SelectedItem) {
		ShowMessage "You must select an item to proceed. Try Again." "OK" "Error"
		Log "Error: No item selected in list operation. Returning";
		exit 1
	}

	$ListBoxForm.Dispose()
	
	return $listBox.SelectedItem
}

function CreatePictureBox($ImagePath, $DrawX, $DrawY, $SizeX, $SizeY){
	$pictureBox = New-Object Windows.Forms.PictureBox
	$pictureBox.Location = New-Object Drawing.Point($DrawX, $DrawY)
	$pictureBox.Size = New-Object Drawing.Size($SizeX, $SizeY)
	$pictureBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::CenterImage
	$pictureBox.Image = [System.Drawing.Image]::FromFile($ImagePath)

	return $pictureBox
}

function RenderEditGameForm($SelectedGame) {

	$EditGameForm = CreateForm "Gaming Gaiden: Edit Game" 580 255 ".\icons\running.ico"
	
	$labelName = Createlabel "Name:" 170 20; $EditGameForm.Controls.Add($labelName)
	$textName = CreateTextBox $SelectedGame.name 245 20 300 20;	$textName.ReadOnly = $true;	$EditGameForm.Controls.Add($textName)

	$labelExe = Createlabel "Exe:" 170 60; $EditGameForm.Controls.Add($labelExe)
	$textExe = CreateTextBox ($SelectedGame.exe_name + ".exe") 245 60 200 20; $textExe.ReadOnly = $true; $EditGameForm.Controls.Add($textExe)

	$labelPlatform = Createlabel "Platform:" 170 100; $EditGameForm.Controls.Add($labelPlatform)
	$textPlatform = CreateTextBox $SelectedGame.platform 245 100 200 20; $EditGameForm.Controls.Add($textPlatform)

	$labelPlayTime = Createlabel "PlayTime:" 170 140; $EditGameForm.Controls.Add($labelPlayTime)
	$PlayTimeString = PlayTimeMinsToString $SelectedGame.play_time
	$textPlayTime = CreateTextBox $PlayTimeString 245 140 200 20; $EditGameForm.Controls.Add($textPlayTime)

	$checkboxCompleted = New-Object Windows.Forms.CheckBox
    $checkboxCompleted.Text = "Finished"
	if($SelectedGame.completed -eq 'TRUE') { $checkboxCompleted.Checked = $true	}
    $checkboxCompleted.Top = 140
    $checkboxCompleted.Left = 470
	$EditGameForm.Controls.Add($checkboxCompleted)

	$IconFileName = ToBase64 $SelectedGame.name
	$ImagePath = "$env:TEMP\GG-{0}-$IconFileName.png" -f $(Get-Random)
	$IconBitmap = BytesToBitmap $SelectedGame.icon
	$IconBitmap.Save($ImagePath,[System.Drawing.Imaging.ImageFormat]::Png)
	$IconBitmap.Dispose()

	$pictureBoxImagePath = CreateTextBox $ImagePath 579 254 1 1; $pictureBoxImagePath.hide(); $EditGameForm.Controls.Add($pictureBoxImagePath)
	
	$pictureBox = CreatePictureBox $ImagePath 15 20 140 140
	$EditGameForm.Controls.Add($pictureBox)

	$buttonUpdateIcon = CreateButton "Edit Icon" 48 175
	$buttonUpdateIcon.Add_Click({
		$openFileDialog = OpenFileDialog "Select Game Icon File" 'PNG (*.png)|*.png|JPEG (*.jpg)|*.jpg'
		$result = $openFileDialog.ShowDialog()
		if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
			$ImagePath = ResizeImage $openFileDialog.FileName $SelectedGame.name
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
			$EditGameForm.Close()
		}
	})
	$EditGameForm.Controls.Add($buttonRemove)

	$buttonOK = CreateButton "OK" 245 175
	$buttonOK.Add_Click({
		if($textPlatform.Text -eq "" -Or $textPlayTime.Text -eq "")	{
			ShowMessage "Platform, Playtime fields cannot be empty. Try Again." "OK" "Error"
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

		$GameCompleteStatus = $SelectedGame.completed
		if ($checkboxCompleted.Checked -eq $true) {	$GameCompleteStatus = 'TRUE' }
		
		UpdateGameOnEdit -GameName $GameName -GameExeName $GameExeName -GameIconPath $pictureBoxImagePath.Text -GamePlayTime $PlayTimeInMin -GameCompleteStatus $GameCompleteStatus -GamePlatform $textPlatform.Text

		ShowMessage "Updated '$GameName' in Database." "OK" "Asterisk"

		$EditGameForm.Close()
	})
	$EditGameForm.Controls.Add($buttonOK)

	$buttonCancel = CreateButton "Cancel" 370 175; $buttonCancel.Add_Click({ $EditGameForm.Close() }); $EditGameForm.Controls.Add($buttonCancel)

	$EditGameForm.ShowDialog()
	$EditGameForm.Dispose()
}

function RenderEditPlatformForm($SelectedPlatform) {

	$EditPlatform =	CreateForm "Gaming Gaiden: Edit Platform" 410 255 ".\icons\running.ico"

	$labelName = Createlabel "Name:" 10 20;	$EditPlatform.Controls.Add($labelName)
	$textName = CreateTextBox $SelectedPlatform.name 85 20 200 20; $textName.ReadOnly = $true; $EditPlatform.Controls.Add($textName)

	$labelExe = Createlabel "Exe:" 10 60; $EditPlatform.Controls.Add($labelExe)
	$textExe = CreateTextBox ($SelectedPlatform.exe_name + ".exe") 85 60 200 20; $textExe.ReadOnly = $true;	$EditPlatform.Controls.Add($textExe)

	$labelRomExt = Createlabel "Rom Extns:" 10 100;	$EditPlatform.Controls.Add($labelRomExt)
	$textRomExt = CreateTextBox $SelectedPlatform.rom_extensions 85 100 200 20;	$EditPlatform.Controls.Add($textRomExt)
	
	$buttonUpdateExe = CreateButton "Edit Exe" 300 58
	$buttonUpdateExe.Add_Click({
		$openFileDialog = OpenFileDialog "Select Executable" 'Executable (*.exe)|*.exe'
		$result = $openFileDialog.ShowDialog()
		if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
			$textExe.Text = (Get-Item $openFileDialog.FileName).Name
		}
	})
	$EditPlatform.Controls.Add($buttonUpdateExe)

	if (-Not $SelectedPlatform.core -eq "") {
		$labelCores = Createlabel "Cores:" 10 140; $EditPlatform.Controls.Add($labelCores)
		$textCore = CreateTextBox $SelectedPlatform.core 85 140 200 20;	$textCore.ReadOnly = $true;	$EditPlatform.Controls.Add($textCore)

		$buttonUpdateCore = CreateButton "Edit Core" 300 138
		$buttonUpdateCore.Add_Click({
			$openFileDialog = OpenFileDialog "Select Retroarch Core" 'DLL (*.dll)|*.dll'
			$result = $openFileDialog.ShowDialog()
			if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
				$textCore.Text = (Get-Item $openFileDialog.FileName).Name
			}
		})
		$EditPlatform.Controls.Add($buttonUpdateCore)
	}

	$buttonRemove = CreateButton "Delete" 300 18
	$buttonRemove.Add_Click({
		$PlatformName = $textName.Text
		$UserInput = UserConfirmationDialog "Confirm Platform Removal" "All Data about '$PlatformName' will be lost.`r`nAre you sure?"
		if ($UserInput.ToLower() -eq 'yes')	{
			RemovePlatform $PlatformName
			ShowMessage "Removed '$PlatformName' from Database." "OK" "Asterisk"
			Log "Removed '$PlatformName' from Database."
			$EditPlatform.Close()
		}
	})
	$EditPlatform.Controls.Add($buttonRemove)

	$buttonOK = CreateButton "OK" 85 175
	$buttonOK.Add_Click({
		if ($textRomExt.Text -eq "") {
			ShowMessage "Extensions field cannot be empty.`r`nResetting Extensions. Try again." "OK" "Error"
			$textRomExt.Text = $SelectedPlatform.rom_extensions
			return
		}

		$PlatformRomExtensions = $textRomExt.Text
		if (-Not ($PlatformRomExtensions -match '^([a-z]{3},)*([a-z]{3}){1}$')) {
			ShowMessage "Error in rom extensions. Please submit extensions as a ',' separated list without the leading '.'`r`ne.g. zip,iso,chd OR zip,iso OR zip" "OK" "Error"
			return
		}

		$PlatformName = $textName.Text
		$EmulatorExeName = $textExe.Text -replace ".exe"
		$EmulatorCore = ""
		if (-Not $SelectedPlatform.core -eq "") { $EmulatorCore = $textCore.Text }
		
		UpdatePlatformOnEdit -PlatformName $PlatformName -EmulatorExeName $EmulatorExeName -EmulatorCore $EmulatorCore -PlatformRomExtensions $PlatformRomExtensions

		ShowMessage "Updated '$PlatformName' in Database." "OK" "Asterisk"

		$EditPlatform.Close()
	})
	$EditPlatform.Controls.Add($buttonOK)

	$buttonCancel = CreateButton "Cancel" 210 175;	$buttonCancel.Add_Click({ $EditPlatform.Close() });	$EditPlatform.Controls.Add($buttonCancel)

	$EditPlatform.ShowDialog()
	$EditPlatform.Dispose()
}

function RenderAddGameForm() {

	$AddGameForm =	CreateForm "Gaming Gaiden: Add Game" 580 255 ".\icons\running.ico"

	$labelName = Createlabel "Name:" 170 20; $AddGameForm.Controls.Add($labelName)
	$textName = CreateTextBox "" 245 20 300 20;	$AddGameForm.Controls.Add($textName)

	$labelExe = Createlabel "Exe:" 170 60; $AddGameForm.Controls.Add($labelExe)
	$textExe = CreateTextBox "" 245 60 200 20; $textExe.ReadOnly = $true; $AddGameForm.Controls.Add($textExe)

	$labelPlatform = Createlabel "Platform:" 170 100; $AddGameForm.Controls.Add($labelPlatform)
	$textPlatform = CreateTextBox "PC" 245 100 200 20; $textPlatform.ReadOnly = $true; $AddGameForm.Controls.Add($textPlatform)

	$labelPlayTime = Createlabel "PlayTime:" 170 140; $AddGameForm.Controls.Add($labelPlayTime)
	$textPlayTime = CreateTextBox "0 Hr 0 Min" 245 140 200 20; $textPlayTime.ReadOnly = $true; $AddGameForm.Controls.Add($textPlayTime)

	$ImagePath = "./icons/default.png"
	$pictureBoxImagePath = CreateTextBox $ImagePath 579 254 1 1; $pictureBoxImagePath.hide(); $AddGameForm.Controls.Add($pictureBoxImagePath)
	
	$pictureBox = CreatePictureBox $ImagePath 15 20 140 140
	$AddGameForm.Controls.Add($pictureBox)

	$buttonUpdateExe = CreateButton "Add Exe" 470 60
	$buttonUpdateExe.Add_Click({

		$openFileDialog = OpenFileDialog "Select Executable" 'Executable (*.exe)|*.exe'
		$result = $openFileDialog.ShowDialog()

		if ($result -eq [System.Windows.Forms.DialogResult]::OK) {	
			$textExe.Text = $openFileDialog.FileName
			$GameExeFile = Get-Item $textExe.Text
			$GameExeName = $GameExeFile.BaseName

			if ($textName.Text -eq "") { $textName.Text = $GameExeName	}
			
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

	$buttonOK = CreateButton "OK" 245 175
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
	 			-GamePlayTime 0 -GameLastPlayDate $GameLastPlayDate -GameCompleteStatus 'FALSE' -GamePlatform 'PC'
		ShowMessage "Registered '$GameName' in Database." "OK" "Asterisk"

		$AddGameForm.Close()
	})
	$AddGameForm.Controls.Add($buttonOK)

	$buttonCancel = CreateButton "Cancel" 370 175; $buttonCancel.Add_Click({ $AddGameForm.Close() }); $AddGameForm.Controls.Add($buttonCancel)

	$AddGameForm.ShowDialog()
	$AddGameForm.Dispose()
}

function RenderAddPlatformForm() {

	$AddPlatform =	CreateForm "Gaming Gaiden: Add Emulator" 410 255 ".\icons\running.ico"

	$labelName = Createlabel "Platorm:" 10 20; $AddPlatform.Controls.Add($labelName)
	$textName = CreateTextBox "" 85 20 200 20; $AddPlatform.Controls.Add($textName)

	$labelExe = Createlabel "Emulator Exe:" 10 60; $AddPlatform.Controls.Add($labelExe)
	$textExe = CreateTextBox "" 85 60 200 20; $textExe.ReadOnly = $true; $AddPlatform.Controls.Add($textExe)

	$labelRomExt = Createlabel "Rom Extns:" 10 100;	$AddPlatform.Controls.Add($labelRomExt)
	$textRomExt = CreateTextBox "" 85 100 200 20; $AddPlatform.Controls.Add($textRomExt)
	
	$labelCores = Createlabel "Core:" 10 140; $labelCores.hide(); $AddPlatform.Controls.Add($labelCores)
	$textCore = CreateTextBox "" 85 140 200 20;	$textCore.ReadOnly = $true;	$textCore.hide(); $AddPlatform.Controls.Add($textCore)

	$buttonAddCore = CreateButton "Add Core" 300 138; $buttonAddCore.hide()
	$buttonAddCore.Add_Click({
		$openFileDialog = OpenFileDialog "Select Retroarch Core" 'DLL (*.dll)|*.dll'
		$result = $openFileDialog.ShowDialog()
		if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
			$textCore.Text = (Get-Item $openFileDialog.FileName).Name
		}
	})
	$AddPlatform.Controls.Add($buttonAddCore)

	$buttonAddExe = CreateButton "Add Exe" 300 58
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
	$AddPlatform.Controls.Add($buttonAddExe)

	$buttonOK = CreateButton "OK" 85 175
	$buttonOK.Add_Click({

		if ($textExe.Text -eq "" -Or $textName.Text -eq "" -Or $textRomExt.Text -eq "")	{
			ShowMessage "Platform, Exe and Extensions fields cannot be empty.`r`nTry again." "OK" "Error"
			return
		}
		$EmulatorExeName = (Get-Item $textExe.Text).BaseName
		if ($EmulatorExeName.ToLower() -like "*retroarch*") {
			if ($textCore.Text -eq "")
			{
				ShowMessage "Retroarch detected.`r`nYou must select Core for platform. Try again." "OK" "Error"
				return
			}
		}

		$PlatformName = $textName.Text
		$PlatformFound = DoesEntityExists "emulated_platforms" "name"  $PlatformName
		if ($null -ne $PlatformFound) {
			ShowMessage "Platform $PlatformName already exists.`r`nUse Edit Platform setting to check existing platforms." "OK" "Error"
			return
		}

		$EmulatorCore = $textCore.Text

		$ExeCoreComboFound = CheckExeCoreCombo $EmulatorExeName $EmulatorCore
		Log "Checkpoint 1"
		if ($null -ne $ExeCoreComboFound) {
			ShowMessage "Executable '$EmulatorExeName.exe' is already registered with core '$EmulatorCore'.`r`nCannot register another platform with same Exe and Core Combination.`r`nUse Edit Platform setting to check existing platforms." "OK" "Error"
			return
		}

		$PlatformRomExtensions = $textRomExt.Text
		if (-Not ($PlatformRomExtensions -match '^([a-z]{3},)*([a-z]{3}){1}$'))	{
			ShowMessage "Error in rom extensions. Please submit extensions as a ',' separated list without the leading '.'`r`ne.g. zip,iso,chd OR zip,iso OR zip" "OK" "Error"
			return
		}

		SavePlatform -PlatformName $PlatformName -EmulatorExeName $EmulatorExeName -CoreName $EmulatorCore -RomExtensions $PlatformRomExtensions

		ShowMessage "Registered '$PlatformName' in Database." "OK" "Asterisk"

		$AddPlatform.Close()
	})
	$AddPlatform.Controls.Add($buttonOK)

	$buttonCancel = CreateButton "Cancel" 210 175; $buttonCancel.Add_Click({ $AddPlatform.Close() }); $AddPlatform.Controls.Add($buttonCancel)

	$AddPlatform.ShowDialog()
	$AddPlatform.Dispose()
}
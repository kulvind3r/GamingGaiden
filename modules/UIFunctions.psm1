class Game
{
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

function CreateMenuItem($Text) {
    $MenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $MenuItem.Text = "$Text"
    
    return $MenuItem
}

function CreateNotifyIcon($ToolTip, $IconPath) {
	$NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
	$Icon = [System.Drawing.Icon]::new($IconPath)
	$NotifyIcon.Text = $ToolTip; 
	$NotifyIcon.Icon = $Icon;

	return $NotifyIcon
}

function FileBrowserDialog($Title, $Filters) {
	$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
        InitialDirectory = [Environment]::GetFolderPath('Desktop')
        Filter = $Filters
        Title = $Title
        ShowHelp = $true
    }

	$result = $FileBrowser.ShowDialog()
    
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
		Log "$Title : Operation cancelled or closed abruptly. Exiting"; 
        exit 1
    }
	
	return (Get-Item $FileBrowser.FileName)
}

function UserInputDialog($Title, $Prompt) {
	$UserInput = [microsoft.visualbasic.interaction]::InputBox($Prompt,$Title)

	if ($UserInput.Length -eq 0)
    {
        ShowMessage "Input cannot be empty. Please try again" "OK" "Error"
        Log "$Title : Empty input provided or closed abruptly. Exiting."
        exit 1
    }
	return $UserInput.Trim()
}

function ShowMessage($Msg, $Buttons, $Type){
	[System.Windows.Forms.MessageBox]::Show($Msg,'Gaming Gaiden', $Buttons, $Type)
}

function UserConfirmationDialog($Title, $Prompt) {
	$UserInput = [microsoft.visualbasic.interaction]::MsgBox($Prompt, "YesNo,Question", $Title).ToString()

	if (-Not ($UserInput.ToLower() -eq 'yes'))
    {
        ShowMessage "Confirmation Denied. No Action Taken." "OK" "Asterisk"
        Log "$Title : Action cancelled. Exiting."
        exit 1
    }
}

function RenderListBoxForm($Prompt, $List) {
	$form = New-Object System.Windows.Forms.Form
	$form.Text = "Gaming Gaiden"
	$form.Size = New-Object System.Drawing.Size(300,360)
	$form.StartPosition = 'CenterScreen'
	$form.FormBorderStyle = 'FixedDialog'

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

	$form.Topmost = $true

	$result = $form.ShowDialog()
	
	if ( -Not ($result -eq [System.Windows.Forms.DialogResult]::OK))
	{
		Log "Operation cancelled or closed abruptly. Returning";
        exit 1
	}
	
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

	# Create a form
	$form = New-Object System.Windows.Forms.Form
	$form.Text = "Gameplay Gaiden: Edit Game"
	$form.Size = New-Object Drawing.Size(580, 255)
	$form.StartPosition = 'CenterScreen'
	$form.FormBorderStyle = 'FixedDialog'

	# Create labels and text fields for Name, Platform, and PlayTime
	$labelName = New-Object System.Windows.Forms.Label
	$labelName.AutoSize = $true
	$labelName.Location = New-Object Drawing.Point(170, 20)
	$labelName.Text = "Name:"
	$form.Controls.Add($labelName)

	$textName = New-Object System.Windows.Forms.TextBox
	$textName.Size = New-Object System.Drawing.Size(300,20)
	$textName.Location = New-Object Drawing.Point(245, 20)
	$textName.Text = $SelectedGame.name
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

	$buttonUpdateIcon = New-Object System.Windows.Forms.Button
	$buttonUpdateIcon.Location = New-Object Drawing.Point(48, 175)
	$buttonUpdateIcon.Text = "Edit Icon"
	$buttonUpdateIcon.Add_Click({
		$openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
		$openFileDialog.Filter = 'PNG (*.png)|*.png|JPEG (*.jpg)|*.jpg'
		$result = $openFileDialog.ShowDialog()
		if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
			$ImagePath = ResizeImage $openFileDialog.FileName $SelectedGame.name
			$pictureBox.Image = [System.Drawing.Image]::FromFile($ImagePath)
		}
	})
	$form.Controls.Add($buttonUpdateIcon)

	$buttonUpdateExe = New-Object System.Windows.Forms.Button
	$buttonUpdateExe.Location = New-Object Drawing.Point(470, 60)
	$buttonUpdateExe.Text = "Edit EXE"
	$buttonUpdateExe.Add_Click({
		$openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
		$openFileDialog.Filter = 'Executable (*.exe)|*.exe'
		$result = $openFileDialog.ShowDialog()
		if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
			# Selected file path is in $openFileDialog.FileName
			Write-Host "Selected EXE: $($openFileDialog.FileName)"
		}
	})
	$form.Controls.Add($buttonUpdateExe)

	# Create OK button to save form fields
	$buttonOK = New-Object System.Windows.Forms.Button
	$buttonOK.Location = New-Object Drawing.Point(320, 175)
	$buttonOK.Text = "OK"
	$buttonOK.Add_Click({
		# $formData = @{
		# 	Name = $textName.Text
		# 	Platform = $textPlatform.Text
		# 	PlayTime = $textPlayTime.Text
		# }
		# $formData | Out-File -FilePath "ConfigFile.txt"
		$form.Close()
	})
	$form.Controls.Add($buttonOK)

	# Show the form
	$form.ShowDialog()

	# Dispose of the form
	$form.Dispose()

}
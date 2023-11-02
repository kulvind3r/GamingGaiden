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
			$ImageFileName = ToBase64($Name)
			$IconByteStream = [System.IO.MemoryStream]::new($GameRecord.icon)
			$IconBitmap = [System.Drawing.Bitmap]::FromStream($IconByteStream)
			$IconBitmap.Save("$WorkingDirectory\ui\resources\images\$ImageFileName.png",[System.Drawing.Imaging.ImageFormat]::Png)
			$IconUri = "<img src=`".\resources\images\$ImageFileName.png`">"
		}
		
		$CurrentGame = [Game]::new($IconUri, $Name, $GameRecord.platform, $GameRecord.play_time, $GameRecord.last_play_date)

		$Games += $CurrentGame
		$TotalPlayTime += $GameRecord.play_time
	}
	
	$Table = $Games | ConvertTo-Html -Fragment
	$Minutes = $null; $Hours = [math]::divrem($TotalPlayTime, 60, [ref]$Minutes);

	$report = (Get-Content $WorkingDirectory\ui\templates\index.html.template) -replace "_GAMESTABLE_", $Table
	$report = $report -replace "Last_Played_On", "Last Played On"
	$report = $report -replace "_TOTALGAMECOUNT_", $Games.length
	$report = $report -replace "_TOTALPLAYTIME_", ("{0} Hr {1} Min" -f $Hours, $Minutes)
	
	[System.Web.HttpUtility]::HtmlDecode($report) | Out-File -encoding UTF8 $WorkingDirectory\ui\index.html

	$DBConnection.Close()
}
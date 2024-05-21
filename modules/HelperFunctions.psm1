function ResetLog($MSG) {
	Remove-Item ".\GamingGaiden.log" -ErrorAction silentlycontinue
	$Timestamp = Get-date -f s
	Write-Output "$Timestamp : Cleared log at application boot" >> ".\GamingGaiden.log"
}

function Log($MSG) {
	$Timestamp = Get-date -f s
	$mutex = New-Object System.Threading.Mutex($false, "LogFileLock")
	if($mutex.WaitOne(500)) {
		Write-Output "$Timestamp : $MSG" >> ".\GamingGaiden.log"
		[void]$mutex.ReleaseMutex()
	}
}

function CleanupTempFiles(){
	Remove-Item -Force "$env:TEMP\GG-*.png"
}

function SQLEscapedMatchPattern($pattern) {
	return $pattern -replace "'", "''"
}

function ToBase64($String) {
	return [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($String))
}

function PlayTimeMinsToString($PlayTime) {
	$Minutes = $null; $Hours = [math]::divrem($PlayTime, 60, [ref]$Minutes);
	return ("{0} Hr {1} Min" -f $Hours, $Minutes)
}

function PlayDateEpochToString($PlayDateEpoch) {
	[datetime]$origin = '1970-01-01 00:00:00'
	return $origin.AddSeconds($PlayDateEpoch).ToLocalTime().ToString("dd MMMM yyyy")
}

function PlayTimeStringToMin($PlayTime) {
	if ( -Not ($PlayTime -match '^[0-9]{0,5} Hr [0-5]{0,1}[0-9]{1} Min$') ) {
        Log "Error: Incorrect playtime format. Returning null"
        return $null
    }

	$Hours = $PlayTime.Split(" ")[0]
	$Minutes = $PlayTime.Split(" ")[2]

	return ([int]$Hours * 60) + [int]$Minutes
}

function BytesToBitmap($ImageBytes) {
	$IconByteStream = [System.IO.MemoryStream]::new($ImageBytes)
	$IconBitmap = [System.Drawing.Bitmap]::FromStream($IconByteStream)
	return $IconBitmap
}

function ResizeImage($ImagePath, $GameName) {
	$ImageFileName = ToBase64 $GameName
	$WIA = New-Object -com wia.imagefile
	$WIA.LoadFile($ImagePath)
	$WIP = New-Object -ComObject wia.imageprocess
	$Scale = $WIP.FilterInfos.Item("Scale").FilterId                    
	$WIP.Filters.Add($Scale)
	$WIP.Filters[1].Properties("MaximumWidth") = 140
	$WIP.Filters[1].Properties("MaximumHeight") = 140
	$WIP.Filters[1].Properties("PreserveAspectRatio") = $true

	$ScaledImage = $WIP.Apply($WIA)
	$ScaledImagePath = "$env:TEMP\GG-{0}-$ImageFileName.png" -f $(Get-Random)
	$ScaledImage.SaveFile($ScaledImagePath)
	return $ScaledImagePath
}

function CreateMenuItem($Text) {
    $MenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $MenuItem.Text = "$Text"
    
    return $MenuItem
}

function CreateMenuSeparator(){
	return New-Object Windows.Forms.ToolStripSeparator
}

function CreateNotifyIcon($ToolTip, $IconPath) {
	$NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
	$Icon = [System.Drawing.Icon]::new($IconPath)
	$NotifyIcon.Text = $ToolTip; 
	$NotifyIcon.Icon = $Icon;

	return $NotifyIcon
}

function OpenFileDialog($Title, $Filters, $DirectoryPath = [Environment]::GetFolderPath('Desktop')) {
	$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
        InitialDirectory = $DirectoryPath
        Filter = $Filters
        Title = $Title
    }
	return $FileBrowser
}

function ShowMessage($Msg, $Buttons, $Type){
	[System.Windows.Forms.MessageBox]::Show($Msg,'Gaming Gaiden', $Buttons, $Type)
}

function UserConfirmationDialog($Title, $Prompt) {
	return [microsoft.visualbasic.interaction]::MsgBox($Prompt, "YesNo,Question", $Title).ToString()
}

function CalculateFileHash ($FilePath) {
	$FileName = (Get-Item $FilePath).Name
	Copy-Item $FilePath "$env:TEMP\$FileName"
	$FileHash = Get-FileHash "$env:TEMP\$FileName"
	Remove-Item "$env:TEMP\$FileName"

	return $FileHash.Hash
}

function BackupDatabase {
	Log "Backing up database"
	
	$WorkingDirectory = (Get-Location).Path
	mkdir -f $WorkingDirectory\backups
	$Timestamp = Get-Date -f "dd-MM-yyyy-HH.mm.ss"
	
	Copy-Item ".\GamingGaiden.db" "$env:TEMP\"
	Compress-Archive "$env:TEMP\GamingGaiden.db" ".\backups\GamingGaiden-$Timestamp.zip"
	Remove-Item "$env:TEMP\GamingGaiden.db"

	Get-ChildItem -Path .\backups -File | Sort-Object -Property CreationTime | Select-Object -SkipLast 5 | Remove-Item
}

function RunDBQuery ($Query, $SQLParameters = $null) {
	
	if ($null -eq $SQLParameters)
	{
		$Result = Invoke-SqliteQuery -Query $Query -DataBase ".\GamingGaiden.db"
	}
	else
	{
		$Result = Invoke-SqliteQuery -Query $Query -DataBase ".\GamingGaiden.db" -SqlParameters $SQLParameters
	}
	return $Result
}

function CreateForm($Text, $SizeX, $SizeY, $IconPath) {
	$form = New-Object System.Windows.Forms.Form
	$form.Text = $Text
	$form.Size = New-Object Drawing.Size($SizeX, $SizeY)
	$form.StartPosition = 'CenterScreen'
	$form.FormBorderStyle = 'FixedDialog'
	$form.Icon = [System.Drawing.Icon]::new($IconPath)
	$form.Topmost = $true
	$form.ShowInTaskbar = $false

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

function CreatePictureBox($ImagePath, $DrawX, $DrawY, $SizeX, $SizeY){
	$pictureBox = New-Object Windows.Forms.PictureBox
	$pictureBox.Location = New-Object Drawing.Point($DrawX, $DrawY)
	$pictureBox.Size = New-Object Drawing.Size($SizeX, $SizeY)
	$pictureBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::CenterImage
	$pictureBox.Image = [System.Drawing.Image]::FromFile($ImagePath)

	return $pictureBox
}
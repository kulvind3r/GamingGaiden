function ResetLog($MSG) {
	Remove-Item ".\GamingGaiden.log" -ErrorAction silentlycontinue
	$Timestamp = (Get-date -f %d-%M-%y`|%H:%m:%s)
	Write-Output "$Timestamp : Cleared log at application boot" >> ".\GamingGaiden.log"
}

function Log($MSG) {
	$Timestamp = (Get-date -f %d-%M-%y`|%H:%m:%s)
	Write-Output "$Timestamp : $MSG" >> ".\GamingGaiden.log"
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

function PlayTimeStringToMin($PlayTime) {
	if ( -Not ($PlayTime -match '^[0-9]{0,5} Hr [0-5][0-9] Min$') ) {
        Log "Incorrect Playtime format entered. Returning null"
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
	$WIP.Filters[1].Properties("MaximumWidth") = 100
	$WIP.Filters[1].Properties("MaximumHeight") = 200
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

function CreateNotifyIcon($ToolTip, $IconPath) {
	$NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
	$Icon = [System.Drawing.Icon]::new($IconPath)
	$NotifyIcon.Text = $ToolTip; 
	$NotifyIcon.Icon = $Icon;

	return $NotifyIcon
}

function OpenFileDialog($Title, $Filters) {
	$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
        InitialDirectory = [Environment]::GetFolderPath('Desktop')
        Filter = $Filters
        Title = $Title
    }
	return $FileBrowser
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
	return [microsoft.visualbasic.interaction]::MsgBox($Prompt, "YesNo,Question", $Title).ToString()
}
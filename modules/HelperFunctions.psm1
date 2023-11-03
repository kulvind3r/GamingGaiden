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
        ShowMessage "Incorrect Playtime Format. Enter exactly 'x Hr y Min'." "OK" "Error"
        Log "Incorrect Playtime format entered. Exiting"
        exit 1
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
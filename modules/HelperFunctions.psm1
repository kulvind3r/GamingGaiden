function Log($MSG) {
	$Timestamp = (Get-date -f %d-%M-%y`|%H:%m:%s)
	Write-Output "$Timestamp : $MSG" >> ".\GamingGaiden.log"
}

function countdown($seconds = 2) {
    1..$seconds | ForEach-Object {
        $remainingSeconds = ($seconds+1) - $_
        Write-Host "`r$remainingSeconds" -NoNewline -ForegroundColor Red
        Start-Sleep -Seconds 1
    }
    Write-Host "`r" -NoNewline
}

function user_prompt($msg) {
    Write-Host $msg -ForegroundColor Green
}

function SQLEscapedMatchPattern($pattern) {
	return $pattern -replace "'", "''"
}

function ToBase64($String) {
	return [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($String))
}

function ResizeImage($ImagePath, $GameName) {
	$ImageFileName = ToBase64($GameName)
	$WIA = New-Object -com wia.imagefile
	$WIA.LoadFile($ImagePath)
	$WIP = New-Object -ComObject wia.imageprocess
	$Scale = $WIP.FilterInfos.Item("Scale").FilterId                    
	$WIP.Filters.Add($Scale)
	$WIP.Filters[1].Properties("MaximumWidth") = 100
	$WIP.Filters[1].Properties("MaximumHeight") = 200
	$WIP.Filters[1].Properties("PreserveAspectRatio") = $true

	$ScaledImage = $WIP.Apply($WIA)
	$ScaledImage.SaveFile("$env:TEMP\$ImageFileName.png")
	return "$env:TEMP\$ImageFileName.png"
}
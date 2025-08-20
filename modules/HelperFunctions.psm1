function Log($MSG) {
    $mutex = New-Object System.Threading.Mutex($false, "LogFileLock")

    if ($mutex.WaitOne(500)) {
        Write-Output "$(Get-date -f s) : $MSG" >> ".\GamingGaiden.log"
        [void]$mutex.ReleaseMutex()
    }
}

function SQLEscapedMatchPattern($pattern) {
    return $pattern -replace "'", "''"
}

function ToBase64($String) {
    return [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($String))
}

function PlayTimeMinsToString($PlayTime) {
    $minutes = $null; $hours = [math]::divrem($PlayTime, 60, [ref]$minutes);
    return ("{0} Hr {1} Min" -f $hours, $minutes)
}

function ResizeImage() {

    param(
        [string]$ImagePath,
        [string]$EntityName,
        [bool]$HD = $false
    )

    $imageFileName = ToBase64 $EntityName
    $WIA = New-Object -com wia.imagefile
    $WIA.LoadFile($ImagePath)
    $WIP = New-Object -ComObject wia.imageprocess
    $scale = $WIP.FilterInfos.Item("Scale").FilterId
    $WIP.Filters.Add($scale)

    $WIP.Filters[1].Properties("PreserveAspectRatio") = $true

    if ($HD) {
        if ($WIA.Width -gt 720 -or $WIA.Height -gt 720) {
            $WIP.Filters[1].Properties("MaximumWidth") = 720
            $WIP.Filters[1].Properties("MaximumHeight") = 720
        }
        else {
            $WIP.Filters[1].Properties("MaximumWidth") = $WIA.Width
            $WIP.Filters[1].Properties("MaximumHeight") = $WIA.Height
        }
    }
    else {
        $WIP.Filters[1].Properties("MaximumWidth") = 140
        $WIP.Filters[1].Properties("MaximumHeight") = 140
    }

    $scaledImage = $WIP.Apply($WIA)
    $scaledImagePath = $null
    if ($ImagePath -like '*.png') {
        $scaledImagePath = "$env:TEMP\GmGdn-{0}-$imageFileName.png" -f $(Get-Random)
    }
    else {
        $scaledImagePath = "$env:TEMP\GmGdn-{0}-$imageFileName.jpg" -f $(Get-Random)
    }

    $scaledImage.SaveFile($scaledImagePath)
    return $scaledImagePath
}

function CreateMenuItem($Text) {
    $menuItem = New-Object System.Windows.Forms.ToolStripmenuItem
    $menuItem.Text = "$Text"

    return $menuItem
}

function OpenFileDialog($Title, $Filters, $DirectoryPath = [Environment]::GetFolderPath('Desktop')) {
    $fileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{
        InitialDirectory = $DirectoryPath
        Filter           = $Filters
        Title            = $Title
    }
    return $fileBrowser
}

function ShowMessage($Msg, $Buttons, $Type) {
    [System.Windows.Forms.MessageBox]::Show($Msg, 'Gaming Gaiden', $Buttons, $Type)
}

function CalculateFileHash ($FilePath) {
    $fileName = (Get-Item $FilePath).Name
    Copy-Item $FilePath "$env:TEMP\$fileName"

    $fileHash = Get-FileHash "$env:TEMP\$fileName"
    Remove-Item "$env:TEMP\$fileName"

    return $fileHash.Hash
}

function BackupDatabase {
    Log "Backing up database"

    $workingDirectory = (Get-Location).Path
    mkdir -f $workingDirectory\backups
    $timestamp = Get-Date -f "dd-MM-yyyy-HH.mm.ss"

    Copy-Item ".\GamingGaiden.db" "$env:TEMP\"
    Compress-Archive "$env:TEMP\GamingGaiden.db" ".\backups\GamingGaiden-$timestamp.zip"
    Remove-Item "$env:TEMP\GamingGaiden.db"

    Get-ChildItem -Path .\backups -File | Sort-Object -Property CreationTime | Select-Object -SkipLast 5 | Remove-Item
}

function RunDBQuery ($Query, $SQLParameters = $null) {
    if ($null -eq $SQLParameters) {
        $result = Invoke-SqliteQuery -Query $Query -DataBase ".\GamingGaiden.db"
    }
    else {
        $result = Invoke-SqliteQuery -Query $Query -DataBase ".\GamingGaiden.db" -SqlParameters $SQLParameters
    }
    return $result
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
    $textBox.Size = New-Object System.Drawing.Size($SizeX, $SizeY)

    return $textBox
}

function CreateButton($Text, $DrawX, $DrawY) {
    $button = New-Object System.Windows.Forms.Button
    $button.Location = New-Object Drawing.Point($DrawX, $DrawY)
    $button.Text = $Text

    return $button
}

function CreatePictureBox() {
    param(
        [string]$ImagePath,
        [int]$DrawX,
        [int]$DrawY,
        [int]$SizeX,
        [int]$SizeY,
        [string]$SizeMode = "center"
    )

    $pictureBox = New-Object Windows.Forms.PictureBox
    $pictureBox.Location = New-Object Drawing.Point($DrawX, $DrawY)
    $pictureBox.Size = New-Object Drawing.Size($SizeX, $SizeY)
    $pictureBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::CenterImage
    if ($SizeMode -eq "zoom") {
        $pictureBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
    }
    $pictureBox.Image = [System.Drawing.Image]::FromFile($ImagePath)

    return $pictureBox
}
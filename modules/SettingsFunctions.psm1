function FilterListBox {
    param(
        [string]$filterText,
        [System.Windows.Forms.ListBox]$listBox,
        [string[]]$originalItems
    )

    $listBox.Items.Clear()

    foreach ($item in $originalItems) {
        if ($item -like "*$filterText*") {
            # Assign to null to avoid appending output to pipeline, improves performance and resource consumption
            $null = $listBox.Items.Add($item)
        }
    }
}

function RefreshPCListBox {
    param(
        [System.Windows.Forms.ListBox]$listBox,
        [string]$selectedPCName = $null
    )

    $PCList = (RunDBQuery "SELECT name FROM gaming_pcs").name
    $currentPC = Read-Setting "current_pc"
    $displayList = @()

    foreach ($pc in $PCList) {
        if ($pc -eq $currentPC) {
            $displayList += "$pc (Current PC)"
        } else {
            $displayList += $pc
        }
    }

    $listBox.Items.Clear()
    if ($displayList.Length -gt 0) {
        $listBox.Items.AddRange($displayList)
    }
}

function RenderEditGameForm($GamesList) {

    $editGameForm = CreateForm "Gaming Gaiden: Edit Game" 865 345 ".\icons\running.ico"

    $imagePath = "./icons/default.png"

    # Hidden fields to save non user editable values
    $pictureBoxImagePath = CreateTextBox $imagePath 874 304 1 1; $pictureBoxImagePath.hide(); $editGameForm.Controls.Add($pictureBoxImagePath)
    $textOriginalGameName = CreateTextBox "" 874 304 1 1; $textOriginalGameName.hide(); $editGameForm.Controls.Add($textOriginalGameName)
    # Hidden fields end

    $listBox = New-Object System.Windows.Forms.ListBox
    $listBox.Location = New-Object System.Drawing.Point(585, 55)
    $listBox.Size = New-Object System.Drawing.Size(260, 20)
    $listBox.Height = 200
    [void] $listBox.Items.AddRange($GamesList)

    $labelSearch = Createlabel "Search:" 585 20; $editGameForm.Controls.Add($labelSearch)
    $textSearch = CreateTextBox "" 645 20 200 20; $editGameForm.Controls.Add($textSearch)

    $textSearch.Add_TextChanged({
            FilterListBox -filterText $textSearch.Text -listBox $listBox -originalItems $GamesList
        })

    $labelName = Createlabel "Name:" 170 20; $editGameForm.Controls.Add($labelName)
    $textName = CreateTextBox "" 245 20 300 20;	$editGameForm.Controls.Add($textName)

    $labelExe = Createlabel "Exe:" 170 60; $editGameForm.Controls.Add($labelExe)
    $textExe = CreateTextBox "" 245 60 200 20; $textExe.ReadOnly = $true; $editGameForm.Controls.Add($textExe)

    $labelPlatform = Createlabel "Platform:" 170 100; $editGameForm.Controls.Add($labelPlatform)
    $textPlatform = CreateTextBox "" 245 100 200 20; $editGameForm.Controls.Add($textPlatform)

    $labelPlayTime = Createlabel "PlayTime:" 170 140; $editGameForm.Controls.Add($labelPlayTime)
    $textPlayTime = CreateTextBox "" 245 140 200 20; $editGameForm.Controls.Add($textPlayTime)

    $labelGamingPC = Createlabel "Gaming PC:" 170 180; $editGameForm.Controls.Add($labelGamingPC)
    $listboxGamingPC = New-Object System.Windows.Forms.ListBox
    $listboxGamingPC.Location = New-Object System.Drawing.Point(245, 180)
    $listboxGamingPC.Size = New-Object System.Drawing.Size(200, 80)
    $listboxGamingPC.SelectionMode = [System.Windows.Forms.SelectionMode]::MultiSimple

    $currentPC = Read-Setting "current_pc"
    $pcList = (RunDBQuery "SELECT name FROM gaming_pcs ORDER BY in_use DESC, name ASC").name

    if ($pcList.Length -gt 0) {
        $currentPCIndex = 0
        for ($i = 0; $i -lt $pcList.Length; $i++) {
            if ($pcList[$i] -eq $currentPC) {
                $listboxGamingPC.Items.Add("$($pcList[$i]) (Current PC)") | Out-Null
                $currentPCIndex = $i
            } else {
                $listboxGamingPC.Items.Add($pcList[$i]) | Out-Null
            }
        }
        $listboxGamingPC.SelectedIndex = $currentPCIndex
    }

    $editGameForm.Controls.Add($listboxGamingPC)

    $checkboxCompleted = New-Object Windows.Forms.CheckBox
    $checkboxCompleted.Text = "Finished"
    $checkboxCompleted.Top = 175
    $checkboxCompleted.Left = 470
    $editGameForm.Controls.Add($checkboxCompleted)

    $checkboxDropped = New-Object Windows.Forms.CheckBox
    $checkboxDropped.Text = "Dropped"
    $checkboxDropped.Top = 195
    $checkboxDropped.Left = 470
    $checkboxDropped.Add_CheckedChanged({
            if ($checkboxDropped.Checked) {
                $checkboxCompleted.Checked = $true
                $checkboxCompleted.Enabled = $false
                $checkboxHold.Checked = $false
                $checkboxForever.Checked = $false
            }
            else {
                if ( -Not $checkboxHold.Checked -And -Not $checkboxForever.Checked ) {
                    $checkboxCompleted.Enabled = $true
                }
            }
        })
    $editGameForm.Controls.Add($checkboxDropped)

    $checkboxHold = New-Object Windows.Forms.CheckBox
    $checkboxHold.Text = "Pick Up Later"
    $checkboxHold.Top = 215
    $checkboxHold.Left = 470
    $checkboxHold.Add_CheckedChanged({
            if ($checkboxHold.Checked) {
                $checkboxCompleted.Checked = $true
                $checkboxCompleted.Enabled = $false
                $checkboxDropped.Checked = $false
                $checkboxForever.Checked = $false
            }
            else {
                if ( -Not $checkboxDropped.Checked -And -Not $checkboxForever.Checked ) {
                    $checkboxCompleted.Enabled = $true
                }
            }
        })
    $editGameForm.Controls.Add($checkboxHold)

    $checkboxForever = New-Object Windows.Forms.CheckBox
    $checkboxForever.Text = "Forever Game"
    $checkboxForever.Top = 235
    $checkboxForever.Left = 470
    $checkboxForever.Add_CheckedChanged({
            if ($checkboxForever.Checked) {
                $checkboxCompleted.Checked = $true
                $checkboxCompleted.Enabled = $false
                $checkboxHold.Checked = $false
                $checkboxDropped.Checked = $false
            }
            else {
                if ( -Not $checkboxHold.Checked -And -Not $checkboxDropped.Checked) {
                    $checkboxCompleted.Enabled = $true
                }
            }
        })
    $editGameForm.Controls.Add($checkboxForever)

    $labelPictureBox = Createlabel "Game Icon" 57 200; $editGameForm.Controls.Add($labelPictureBox)
    $pictureBox = CreatePictureBox $imagePath 15 40 140 140
    $editGameForm.Controls.Add($pictureBox)

    $listBox.Add_SelectedIndexChanged({
            $selectedGame = GetGameDetails $listBox.SelectedItem

            $textName.Text = $selectedGame.name
            $textOriginalGameName.Text = $selectedGame.name
            $textExe.Text = ($selectedGame.exe_name + ".exe")
            $textPlatform.Text = $selectedGame.platform
            $checkboxCompleted.Checked = ($selectedGame.completed -eq 'TRUE')
            $checkboxDropped.Checked = ($selectedGame.status -eq 'dropped')
            $checkboxHold.Checked = ($selectedGame.status -eq 'hold')
            $checkboxForever.Checked = ($selectedGame.status -eq 'forever')

            if ($checkboxForever.Checked -or $checkboxHold.Checked -or $checkboxDropped.Checked) {
                $checkboxCompleted.Enabled = $false
            }

            $textPlayTime.Text = PlayTimeMinsToString $selectedGame.play_time

            # Set gaming PC listbox multi-selection
            $listboxGamingPC.ClearSelected()
            if ($null -ne $selectedGame.gaming_pc_name -and $selectedGame.gaming_pc_name -ne "") {
                $gamePCs = $selectedGame.gaming_pc_name -split ','
                $currentPC = Read-Setting "current_pc"

                for ($i = 0; $i -lt $listboxGamingPC.Items.Count; $i++) {
                    $item = $listboxGamingPC.Items[$i]
                    $pcName = $item -replace ' \(Current PC\)', ''

                    if ($gamePCs -contains $pcName.Trim()) {
                        $listboxGamingPC.SetSelected($i, $true)
                    }
                }
            }

            $iconFileName = ToBase64 $selectedGame.name

            $iconByteStream = [System.IO.MemoryStream]::new($selectedGame.icon)
            $iconBitmap = [System.Drawing.Bitmap]::FromStream($iconByteStream)

            if ($iconBitmap.PixelFormat -eq "Format32bppArgb") {
                $imagePath = "$env:TEMP\GmGdn-{0}-$iconFileName.png" -f $(Get-Random)
                $iconBitmap.Save($imagePath, [System.Drawing.Imaging.ImageFormat]::Png) | Out-Null
            }
            else {
                $imagePath = "$env:TEMP\GmGdn-{0}-$iconFileName.jpg" -f $(Get-Random)
                $iconBitmap.Save($imagePath, [System.Drawing.Imaging.ImageFormat]::Jpeg) | Out-Null
            }

            $iconBitmap.Dispose()

            $pictureBoxImagePath.Text = $imagePath
            $pictureBox.Image.Dispose()
            $pictureBox.Image = [System.Drawing.Image]::FromFile($imagePath)

        })
    $editGameForm.Controls.Add($listBox)

    $buttonSearchIcon = CreateButton "Search" 20 230
    $buttonSearchIcon.Size = New-Object System.Drawing.Size(60, 23)
    $buttonSearchIcon.Add_Click({
            $gameName = $textName.Text
            if ($gameName -eq "") {
                ShowMessage "Please enter a name first." "OK" "Error"
                return
            }
            $gameNameEncoded = $gameName -replace " ", "+"
            Start-Process "https://www.google.com/search?as_q=$gameNameEncoded+Game&imgar=s&udm=2"
        })
    $editGameForm.Controls.Add($buttonSearchIcon)

    $buttonUpdateIcon = CreateButton "Update" 90 230
    $buttonUpdateIcon.Size = New-Object System.Drawing.Size(60, 23)
    $buttonUpdateIcon.Add_Click({
            $downloadsDirectoryPath = (New-Object -ComObject Shell.Application).Namespace('shell:Downloads').Self.Path
            $openFileDialog = OpenFileDialog "Select Game Icon File" 'Image (*.png, *.jpg, *.jpeg)|*.png;*.jpg;*.jpeg' $downloadsDirectoryPath
            $result = $openFileDialog.ShowDialog()
            if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
                $imagePath = ResizeImage $openFileDialog.FileName $textName.name
                $pictureBoxImagePath.Text = $imagePath
                $pictureBox.Image.Dispose()
                $pictureBox.Image = [System.Drawing.Image]::FromFile($imagePath)
                $openFileDialog.Dispose()
            }
        })
    $editGameForm.Controls.Add($buttonUpdateIcon)

    $buttonUpdateExe = CreateButton "Edit Exe" 470 60
    $buttonUpdateExe.Add_Click({
            $openFileDialog = OpenFileDialog "Select Executable" 'Executable (*.exe)|*.exe'
            $result = $openFileDialog.ShowDialog()
            if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
                $textExe.Text = (Get-Item $openFileDialog.FileName).Name
                $openFileDialog.Dispose()
            }
        })
    $editGameForm.Controls.Add($buttonUpdateExe)

    $buttonRemove = CreateButton "Delete" 470 100
    $buttonRemove.Add_Click({
            $gameName = $textName.Text

            $userInput = [microsoft.visualbasic.interaction]::MsgBox("All Data about '$gameName' will be lost.`r`nAre you sure?", "YesNo,Question", "Confirm Game Removal").ToString()
            if ($userInput.ToLower() -eq 'yes')	{
                RemoveGame $gameName
                ShowMessage "Removed '$gameName' from Database." "OK" "Asterisk"
                Log "Removed '$gameName' from Database."

                $gamesList = (RunDBQuery "SELECT name FROM games").name
                if ($gamesList.Length -eq 0) {
                    ShowMessage "No more games in Database. Closing Edit Form." "OK" "Asterisk"
                    $editGameForm.Close() | Out-Null
                    return
                }
                $listBox.Items.Clear(); $listBox.Items.AddRange($gamesList);
                $listBox.SelectedIndex = 0
            }
        })
    $editGameForm.Controls.Add($buttonRemove)

    $buttonOK = CreateButton "OK" 245 270
    $buttonOK.Add_Click({
            $currentlySelectedIndex = $listBox.SelectedIndex

            if ($textName.Text -eq "" -Or $textPlatform.Text -eq "" -Or $textPlayTime.Text -eq "")	{
                ShowMessage "Name, Platform, Playtime fields cannot be empty. Try Again." "OK" "Error"
                $listBox.SetSelected($currentlySelectedIndex, $true)
                return
            }

            $gameName = $textName.Text

            $playTime = $textPlayTime.Text
            if ( -Not ($playTime -match '^[0-9]{0,5} Hr [0-5]{0,1}[0-9]{1} Min$') ) {
                ShowMessage "Incorrect Playtime Format. Enter exactly 'x Hr y Min'." "OK" "Error"
                $listBox.SetSelected($currentlySelectedIndex, $true)
                return
            }
            $playTimeInMin = ([int]$playTime.Split(" ")[0] * 60) + [int]$playTime.Split(" ")[2]

            $gameExeName = $textExe.Text -replace ".exe"

            $gameCompleteStatus = if ($checkboxCompleted.Checked) { "TRUE" } else { "FALSE" }

            $gameStatus = ""
            if ($checkboxDropped.Checked) { $gameStatus = "dropped"; $checkboxCompleted.Checked = $true; $gameCompleteStatus = "TRUE"; }
            if ($checkboxHold.Checked) { $gameStatus = "hold"; $checkboxCompleted.Checked = $true; $gameCompleteStatus = "TRUE"; }
            if ($checkboxForever.Checked) { $gameStatus = "forever"; $checkboxCompleted.Checked = $true; $gameCompleteStatus = "TRUE"; }

            $selectedPCs = @()
            foreach ($item in $listboxGamingPC.SelectedItems) {
                $pcName = ($item -replace ' \(Current PC\)', '').Trim()
                $selectedPCs += $pcName
            }
            $gameGamingPCName = $selectedPCs -join ','

            UpdateGameOnEdit -OriginalGameName $textOriginalGameName.Text -GameName $gameName -GameExeName $gameExeName -GameIconPath $pictureBoxImagePath.Text -GamePlayTime $playTimeInMin -GameCompleteStatus $gameCompleteStatus -GamePlatform $textPlatform.Text -GameStatus $gameStatus -GameGamingPCName $gameGamingPCName

            ShowMessage "Updated '$gameName' in Database." "OK" "Asterisk"

            # Clear existing and then pre load image in ui\resources\images folder for rendering 'All Games' list faster
            $imageFileName = ToBase64 $gameName
            $gameIconPath = $pictureBoxImagePath.Text
            $imageFileExtension = $gameIconPath.Split(".")[-1]
            Remove-Item ".\ui\resources\images\$imageFileName.*"
            Copy-Item -Path $gameIconPath -Destination ".\ui\resources\images\$imageFileName.$imageFileExtension"

            $gamesList = (RunDBQuery "SELECT name FROM games").name
            $listBox.Items.Clear(); $listBox.Items.AddRange($gamesList);
            $listBox.SelectedIndex = $listBox.FindString($gameName)
        })
    $editGameForm.Controls.Add($buttonOK)

    $buttonCancel = CreateButton "Cancel" 370 270;
    $buttonCancel.Add_Click({
            $textSearch.Remove_TextChanged({})
            $listBox.Remove_SelectedIndexChanged({})
            $pictureBox.Image.Dispose(); $pictureBox.Dispose();
            $editGameForm.Dispose()
        });
    $editGameForm.Controls.Add($buttonCancel)

    #Select the first game to populate the form before rendering for first time
    $listBox.SelectedIndex = 0

    $editGameForm.ShowDialog()
    $textSearch.Remove_TextChanged({})
    $listBox.Remove_SelectedIndexChanged({})
    $pictureBox.Image.Dispose(); $pictureBox.Dispose();
    $editGameForm.Dispose()
}

function RenderEditPlatformForm($PlatformsList) {

    $editPlatformForm =	CreateForm "Gaming Gaiden: Edit Platform" 645  320 ".\icons\running.ico"

    # Hidden fields to save non user editable values
    $textOriginalPlatformName = CreateTextBox "" 654 329 1 1; $textOriginalPlatformName.hide(); $editPlatformForm.Controls.Add($textOriginalPlatformName)
    # Hidden fields end

    $listBox = New-Object System.Windows.Forms.ListBox
    $listBox.Location = New-Object System.Drawing.Point(400, 65)
    $listBox.Size = New-Object System.Drawing.Size(225, 20)
    $listBox.Height = 212
    [void] $listBox.Items.AddRange($PlatformsList)

    $labelSearch = Createlabel "Search:" 400 20; $editPlatformForm.Controls.Add($labelSearch)
    $textSearch = CreateTextBox "" 465 20 160 20; $editPlatformForm.Controls.Add($textSearch)

    $textSearch.Add_TextChanged({
            FilterListBox -filterText $textSearch.Text -listBox $listBox -originalItems $PlatformsList
        })

    $labelName = Createlabel "Platorm:" 10 20; $editPlatformForm.Controls.Add($labelName)
    $textName = CreateTextBox "" 75 20 200 20; $editPlatformForm.Controls.Add($textName)

    $labelExe = Createlabel "Emulator`nExe List:" 10 79; $editPlatformForm.Controls.Add($labelExe)
    $textExe = CreateTextBox "" 75 82 200 20; $textExe.ReadOnly = $true; $editPlatformForm.Controls.Add($textExe)

    $labelRomExt = Createlabel "Rom Extns:" 10 146;	$editPlatformForm.Controls.Add($labelRomExt)
    $textRomExt = CreateTextBox "" 75 144 200 20;	$editPlatformForm.Controls.Add($textRomExt)

    $labelCores = Createlabel "Cores:" 10 208; $editPlatformForm.Controls.Add($labelCores)
    $textCore = CreateTextBox "" 75 206 200 20;	$textCore.ReadOnly = $true;	$editPlatformForm.Controls.Add($textCore)

    $listBox.Add_SelectedIndexChanged({
            $selectedPlatform = GetPlatformDetails $listBox.SelectedItem

            $textName.Text = $selectedPlatform.name
            $textOriginalPlatformName.Text = $selectedPlatform.name
            $textRomExt.Text = $selectedPlatform.rom_extensions

            $exeList = ($selectedPlatform.exe_name -replace "," , ".exe,") + ".exe"
            $textExe.Text = $exeList

            $hasCore = -Not ($selectedPlatform.core -eq "")

            if ($hasCore) {
                $textCore.Text = $selectedPlatform.core

                $buttonUpdateCore.show()
                $labelCores.show()
                $textCore.show()

                $editPlatformForm.Size = New-Object System.Drawing.Size(645, 320)
                $listBox.Height = 212
                $buttonOK.Location = New-Object System.Drawing.Point(85, 254)
                $buttonCancel.Location = New-Object System.Drawing.Point(210, 254)
            }
            else {
                $buttonUpdateCore.hide()
                $labelCores.hide()
                $textCore.Text = ""; $textCore.hide()

                $editPlatformForm.Size = New-Object System.Drawing.Size(645, 267)
                $listBox.Height = 166
                $buttonOK.Location = New-Object System.Drawing.Point(85, 201)
                $buttonCancel.Location = New-Object System.Drawing.Point(210, 201)
            }
        })
    $editPlatformForm.Controls.Add($listBox)

    $buttonUpdateCore = CreateButton "Edit Core" 300 204
    $buttonUpdateCore.Add_Click({
            $openFileDialog = OpenFileDialog "Select Retroarch Core" 'DLL (*.dll)|*.dll'
            $result = $openFileDialog.ShowDialog()
            if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
                $textCore.Text = (Get-Item $openFileDialog.FileName).Name
                $openFileDialog.Dispose()
            }
        })
    $editPlatformForm.Controls.Add($buttonUpdateCore)

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
                $openFileDialog.Dispose()
            }
        })
    $editPlatformForm.Controls.Add($buttonUpdateExe)

    $buttonClearExe = CreateButton "Clear List" 300 95
    $buttonClearExe.Add_Click({
            $textExe.Text = ""
        })
    $editPlatformForm.Controls.Add($buttonClearExe)

    $buttonRemove = CreateButton "Delete" 300 18
    $buttonRemove.Add_Click({
            $platformName = $textName.Text

            $userInput = [microsoft.visualbasic.interaction]::MsgBox("All Data about '$platformName' will be lost.`r`nAre you sure?", "YesNo,Question", "Confirm Platform Removal").ToString()
            if ($userInput.ToLower() -eq 'yes')	{
                RemovePlatform $platformName
                ShowMessage "Removed '$platformName' from Database." "OK" "Asterisk"
                Log "Removed '$platformName' from Database."

                $platformsList = (RunDBQuery "SELECT name FROM emulated_platforms").name
                if ($platformsList.Length -eq 0) {
                    ShowMessage "No more platforms in Database. Closing Edit Form." "OK" "Asterisk"
                    $editPlatformForm.Close() | Out-Null
                    return
                }
                $listBox.Items.Clear(); $listBox.Items.AddRange($platformsList);
                $listBox.SelectedIndex = 0
            }
        })
    $editPlatformForm.Controls.Add($buttonRemove)

    $buttonOK = CreateButton "OK" 85 254
    $buttonOK.Add_Click({
            $currentlySelectedIndex = $listBox.SelectedIndex

            if ($textRomExt.Text -eq "" -Or $textExe.Text -eq "" -Or $textName.Text -eq "") {
                ShowMessage "Platform Name, Exe List or Rom Extensions field cannot be empty.`r`nTry again." "OK" "Error"
                $listBox.SetSelected($currentlySelectedIndex, $true)
                return
            }

            $platformRomExtensions = $textRomExt.Text
            if (-Not ($platformRomExtensions -match '^([a-zA-Z0-9!@#$%^&_\-~]+,)*([a-zA-Z0-9!@#$%^&_\-~]+)$')) {
                ShowMessage "Error in rom extensions. Please submit extensions as a ',' separated list without the leading '.' or spaces.`r`n`r`ne.g. zip,iso,chd OR zip,iso OR zip" "OK" "Error"
                $listBox.SetSelected($currentlySelectedIndex, $true)
                return
            }

            $platformName = $textName.Text
            $emulatorExeList = $textExe.Text -replace ".exe"

            UpdatePlatformOnEdit -OriginalPlatformName $textOriginalPlatformName.Text -PlatformName $platformName -EmulatorExeList $emulatorExeList -EmulatorCore $textCore.Text -PlatformRomExtensions $platformRomExtensions

            ShowMessage "Updated '$platformName' in Database." "OK" "Asterisk"

            $platformsList = (RunDBQuery "SELECT name FROM emulated_platforms").name
            $listBox.Items.Clear(); $listBox.Items.AddRange($platformsList);
            $listBox.SelectedIndex = $listBox.FindString($platformName)
        })
    $editPlatformForm.Controls.Add($buttonOK)

    $buttonCancel = CreateButton "Cancel" 210 254;	$buttonCancel.Add_Click({ 
            $textSearch.Remove_TextChanged({})
            $listBox.Remove_SelectedIndexChanged({})
            $editPlatformForm.Dispose() 
        });	
    $editPlatformForm.Controls.Add($buttonCancel)

    #Select the first platform to populate the form before rendering for first time
    $listBox.SelectedIndex = 0

    $editPlatformForm.ShowDialog()
    $textSearch.Remove_TextChanged({})
    $listBox.Remove_SelectedIndexChanged({})
    $editPlatformForm.Dispose()
}

function RenderAddGameForm() {
    $addGameForm =	CreateForm "Gaming Gaiden: Add Game" 570 295 ".\icons\running.ico"

    $labelName = Createlabel "Name:" 170 20; $addGameForm.Controls.Add($labelName)
    $textName = CreateTextBox "" 245 20 300 20;	$addGameForm.Controls.Add($textName)

    $labelExe = Createlabel "Exe:" 170 60; $addGameForm.Controls.Add($labelExe)
    $textExe = CreateTextBox "" 245 60 200 20; $textExe.ReadOnly = $true; $addGameForm.Controls.Add($textExe)

    $labelPlatform = Createlabel "Platform:" 170 100; $addGameForm.Controls.Add($labelPlatform)
    $textPlatform = CreateTextBox "PC" 245 100 200 20; $textPlatform.ReadOnly = $true; $addGameForm.Controls.Add($textPlatform)

    $labelPlayTime = Createlabel "PlayTime:" 170 140; $addGameForm.Controls.Add($labelPlayTime)
    $textPlayTime = CreateTextBox "0 Hr 0 Min" 245 140 200 20; $textPlayTime.ReadOnly = $true; $addGameForm.Controls.Add($textPlayTime)

    $labelGamingPC = Createlabel "Gaming PC:" 170 180; $addGameForm.Controls.Add($labelGamingPC)
    $dropdownGamingPC = New-Object System.Windows.Forms.ComboBox
    $dropdownGamingPC.Location = New-Object System.Drawing.Point(245, 180)
    $dropdownGamingPC.Size = New-Object System.Drawing.Size(200, 20)
    $dropdownGamingPC.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList

    $currentPC = Read-Setting "current_pc"
    $pcList = (RunDBQuery "SELECT name FROM gaming_pcs").name

    if ($pcList.Length -gt 0) {
        foreach ($pc in $pcList) {
            $dropdownGamingPC.Items.Add($pc) | Out-Null
        }

        if ($null -ne $currentPC -and $pcList -contains $currentPC) {
            $dropdownGamingPC.SelectedItem = $currentPC
        } else {
            $dropdownGamingPC.SelectedIndex = 0
        }
    }

    $addGameForm.Controls.Add($dropdownGamingPC)

    $buttonSearchIcon = CreateButton "Search" 25 220
    $buttonSearchIcon.Size = New-Object System.Drawing.Size(60, 23)
    $buttonSearchIcon.Add_Click({
            $gameName = $textName.Text
            if ($gameName -eq "") {
                ShowMessage "Please enter a name first." "OK" "Error"
                return
            }
            $gameNameEncoded = $gameName -replace " ", "+"
            Start-Process "https://www.google.com/search?as_q=$gameNameEncoded+Game&imgar=s&udm=2"
        })
    $addGameForm.Controls.Add($buttonSearchIcon)

    $imagePath = "./icons/default.png"
    $pictureBoxImagePath = CreateTextBox $imagePath 579 294 1 1; $pictureBoxImagePath.hide(); $addGameForm.Controls.Add($pictureBoxImagePath)

    $pictureBox = CreatePictureBox $imagePath 15 20 147 147
    $addGameForm.Controls.Add($pictureBox)

    $labelPictureBox = Createlabel "Game Icon" 62 167; $addGameForm.Controls.Add($labelPictureBox)

    $buttonUpdateIcon = CreateButton "Update" 95 220
    $buttonUpdateIcon.Size = New-Object System.Drawing.Size(60, 23)
    $buttonUpdateIcon.Add_Click({
            $downloadsDirectoryPath = (New-Object -ComObject Shell.Application).Namespace('shell:Downloads').Self.Path
            $openFileDialog = OpenFileDialog "Select Game Icon File" 'Image (*.png, *.jpg, *.jpeg)|*.png;*.jpg;*.jpeg' $downloadsDirectoryPath
            $result = $openFileDialog.ShowDialog()
            if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
                $imagePath = ResizeImage $openFileDialog.FileName "GG-NEW_GAME"
                $pictureBoxImagePath.Text = $imagePath
                $pictureBox.Image.Dispose()
                $pictureBox.Image = [System.Drawing.Image]::FromFile($imagePath)
                $openFileDialog.Dispose()
            }
        })
    $addGameForm.Controls.Add($buttonUpdateIcon)

    $buttonUpdateExe = CreateButton "Add Exe" 470 60
    $buttonUpdateExe.Add_Click({
            $openFileDialog = OpenFileDialog "Select Executable" 'Executable (*.exe)|*.exe'
            $result = $openFileDialog.ShowDialog()

            if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
                $textExe.Text = $openFileDialog.FileName
                $gameExeFile = Get-Item $textExe.Text
                $gameExeName = $gameExeFile.BaseName

                if ($textName.Text -eq "") { $textName.Text = $gameExeName }

                $entityFound = DoesEntityExists "games" "exe_name" $gameExeName
                if ($null -ne $entityFound) {
                    ShowMessage "Another Game with Executable $gameExeName.exe already exists`r`nSee Games List." "OK" "Asterisk"
                    $textExe.Text = ""
                    return
                }

                $gameIconPath = "$env:TEMP\GmGdn-{0}.jpg" -f $(Get-Random)
                $gameIcon = [System.Drawing.Icon]::ExtractAssociatedIcon($gameExeFile)
                $gameIcon.ToBitmap().save($gameIconPath)

                $pictureBoxImagePath.Text = $gameIconPath
                $pictureBox.Image.Dispose()
                $pictureBox.Image = [System.Drawing.Image]::FromFile($gameIconPath)

                $openFileDialog.Dispose()
            }
        })
    $addGameForm.Controls.Add($buttonUpdateExe)

    $buttonOK = CreateButton "OK" 245 220
    $buttonOK.Add_Click({
            if ($textExe.Text -eq "" -Or $textName.Text -eq "" ) {
                ShowMessage "Name, Exe fields cannot be empty. Try Again." "OK" "Error"
                return
            }
            $gameName = $textName.Text
            $gameExeFile = Get-Item $textExe.Text
            $gameExeName = $gameExeFile.BaseName
            $gameIconPath = $pictureBoxImagePath.Text
            $gameLastPlayDate = (Get-Date ([datetime]::UtcNow) -UFormat "%s").Split('.').Get(0)
            $gameGamingPCName = if ($dropdownGamingPC.SelectedItem -eq "") { "" } else { $dropdownGamingPC.SelectedItem }

            SaveGame -GameName $gameName -GameExeName $gameExeName -GameIconPath $gameIconPath `
                -GamePlayTime 0 -GameIdleTime 0 -GameLastPlayDate $gameLastPlayDate -GameCompleteStatus 'FALSE' -GamePlatform 'PC' -GameSessionCount 0 -GameGamingPCName $gameGamingPCName

            ShowMessage "Registered '$gameName' in Database." "OK" "Asterisk"

            # Pre Load image in ui\resources\images folder for rendering 'All Games' list faster
            $imageFileName = ToBase64 $gameName
            $imageFileExtension = $gameIconPath.Split(".")[-1]
            Copy-Item -Path $gameIconPath -Destination ".\ui\resources\images\$imageFileName.$imageFileExtension"
        })
    $addGameForm.Controls.Add($buttonOK)

    $buttonCancel = CreateButton "Cancel" 370 220;
    $buttonCancel.Add_Click({
            $pictureBox.Image.Dispose(); $pictureBox.Dispose();
            $addGameForm.Dispose()
        });
    $addGameForm.Controls.Add($buttonCancel)

    $addGameForm.ShowDialog()
    $pictureBox.Image.Dispose(); $pictureBox.Dispose();
    $addGameForm.Dispose()
}

function RenderGamingPCForm($PCList) {

    $gamingPCForm = CreateForm "Gaming Gaiden: Gaming PCs" 710 295 ".\icons\running.ico"

    $imagePath = "./icons/pc.png"

    # Hidden fields to save non user editable values
    $pictureBoxImagePath = CreateTextBox $imagePath 664 264 1 1; $pictureBoxImagePath.hide(); $gamingPCForm.Controls.Add($pictureBoxImagePath)
    $checkboxNew = New-Object Windows.Forms.CheckBox; $checkboxNew.Checked = $false; $checkboxNew.hide(); $gamingPCForm.Controls.Add($checkboxNew)
    $textOriginalPCName = CreateTextBox "" 664 264 1 1; $textOriginalPCName.hide(); $gamingPCForm.Controls.Add($textOriginalPCName)
    # Hidden fields end

    $labelList = Createlabel "Your PCs" 565 30; $gamingPCForm.Controls.Add($labelList)

    # Check if warning should be shown
    $currentPC = Read-Setting "current_pc"
    $showWarning = ($null -eq $currentPC -and $PCList.Length -gt 1)
    $warningLabel = $null

    if ($showWarning) {
        $warningLabel = CreateLabel "⚠ Current PC unidentified. Mark a PC as current to track PC usage" 165 2
        $warningLabel.ForeColor = [System.Drawing.Color]::Red
        $warningLabel.Font = New-Object System.Drawing.Font("Arial", 8)
        $warningLabel.AutoSize = $true
        $gamingPCForm.Controls.Add($warningLabel)
    }

    $listBox = New-Object System.Windows.Forms.ListBox
    $listBox.Location = New-Object System.Drawing.Point(505, 55)
    $listBox.Size = New-Object System.Drawing.Size(175, 20)
    $listBox.Height = 160

    # Add current PC indicator
    RefreshPCListBox -listBox $listBox

    $labelName = Createlabel "Name:" 170 20; $gamingPCForm.Controls.Add($labelName)
    $textName = CreateTextBox "" 240 20 245 20;	$gamingPCForm.Controls.Add($textName)

    $labelTotalPlaytime = Createlabel "Playtime:" 170 50; $gamingPCForm.Controls.Add($labelTotalPlaytime)
    $textTotalPlaytime = CreateTextBox "0 Hr 0 Min" 240 50 245 20; $gamingPCForm.Controls.Add($textTotalPlaytime)

    $labelCurrency = Createlabel "Currency:" 170 80; $gamingPCForm.Controls.Add($labelCurrency)
    $textCurrency = CreateTextBox "" 240 80 55 20;	$gamingPCForm.Controls.Add($textCurrency)

    $labelCost = Createlabel "Cost:" 365 80; $gamingPCForm.Controls.Add($labelCost)
    $textCost = CreateTextBox "" 405 80 80 20;	$gamingPCForm.Controls.Add($textCost)

    $labelStartDate = Createlabel "Start Date" 190 110; $gamingPCForm.Controls.Add($labelStartDate)
    $startDatePicker = New-Object Windows.Forms.DateTimePicker
    $startDatePicker.Location = "170, 130"
    $startDatePicker.Width = "100"
    $startDatePicker.MaxDate = [DateTime]::Today
    $startDatePicker.Format = [windows.forms.datetimepickerFormat]::custom
    $startDatePicker.CustomFormat = "dd/MM/yyyy"
    $gamingPCForm.Controls.Add($startDatePicker)

    $labelEndDate = Createlabel "End Date" 410 110; $gamingPCForm.Controls.Add($labelEndDate)
    $endDatePicker = New-Object Windows.Forms.DateTimePicker
    $endDatePicker.Location = "385, 130"
    $endDatePicker.Width = “100”
    $endDatePicker.MaxDate = [DateTime]::Today
    $endDatePicker.Format = [windows.forms.datetimepickerFormat]::custom
    $endDatePicker.CustomFormat = “dd/MM/yyyy”
    $gamingPCForm.Controls.Add($endDatePicker)

    $labelInUse = Createlabel "In Use" 320 135; $gamingPCForm.Controls.Add($labelInUse)
    $checkboxInUse = New-Object Windows.Forms.CheckBox
    $checkboxInUse.Top = 130
    $checkboxInUse.Left = 300
    $checkboxInUse.Add_CheckedChanged({
            $endDatePicker.Enabled = (-Not $checkboxInUse.Checked)
        })
    $gamingPCForm.Controls.Add($checkboxInUse)

    $labelCurrentPC = Createlabel "Current" 320 170; $gamingPCForm.Controls.Add($labelCurrentPC)
    $checkboxCurrentPC = New-Object Windows.Forms.CheckBox
    $checkboxCurrentPC.Top = 165
    $checkboxCurrentPC.Left = 300
    $disableCurrentPCCheckBoxHandler = $false
    $checkboxCurrentPCHandler = {
            # if handler is disabled return
            if ($disableCurrentPCCheckBoxHandler) { return }

            # If checked, mark this PC as current for tracking
            if ($checkboxCurrentPC.Checked -and $textName.Text -ne "") {
                Write-Setting "current_pc" $textName.Text

                # Hide warning if it exists
                if ($showWarning -and $null -ne $warningLabel) {
                    $warningLabel.Visible = $false
                }

                # Refresh listbox to show current PC indicator
                $currentlySelected = $listBox.SelectedItem
                RefreshPCListBox -listBox $listBox -selectedPCName $currentlySelected
            }
            else {
                # Clear current_pc setting when unchecked
                Write-Setting "current_pc" ""

                # Refresh listbox to remove current PC indicator
                $currentlySelected = $listBox.SelectedItem
                RefreshPCListBox -listBox $listBox -selectedPCName $currentlySelected
            }
        }
    $checkboxCurrentPC.Add_CheckedChanged($checkboxCurrentPCHandler)
    $gamingPCForm.Controls.Add($checkboxCurrentPC)

    $pictureBox = CreatePictureBox $imagePath 10 20 150 150 "zoom"
    $gamingPCForm.Controls.Add($pictureBox)

    $listBox.Add_SelectedIndexChanged({
            $selectedItem = $listBox.SelectedItem
            $cleanName = $selectedItem -replace " \(Current PC\)", ""
            $selectedPC = GetPCDetails $cleanName

            $textName.Text = $selectedPC.name
            $textOriginalPCName.Text = $selectedPC.name
            $textCost.Text = $selectedPC.cost
            $textCurrency.Text = $selectedPC.currency

            # Convert total_play_time from minutes to "X Hr Y Min" format
            $textTotalPlaytime.Text = PlayTimeMinsToString $selectedPC.total_play_time

            # Set "In Use" checkbox based on database value
            $checkboxInUse.Checked = ($selectedPC.in_use -eq "TRUE")

            # Update "Current PC" checkbox status from settings.ini
            # Disable handler to prevent updating settings file
            $disableCurrentPCCheckBoxHandler = $true
            $currentPC = Read-Setting "current_pc"
            $checkboxCurrentPC.Checked = ($selectedPC.name -eq $currentPC)
            $disableCurrentPCCheckBoxHandler = $false

            $startDatePicker.Value = (Get-Date "1970-01-01 00:00:00Z").AddSeconds($selectedPC.start_date)
            if ($selectedPC.in_use -eq 'TRUE') {
                $endDatePicker.Value = [DateTime]::Today
                $endDatePicker.Enabled = $false
            }
            else {
                $endDatePicker.Value = (Get-Date "1970-01-01 00:00:00Z").AddSeconds($selectedPC.end_date)
            }

            $iconFileName = ToBase64 $selectedPC.name

            $iconByteStream = [System.IO.MemoryStream]::new($selectedPC.icon)
            $iconBitmap = [System.Drawing.Bitmap]::FromStream($iconByteStream)

            if ($iconBitmap.PixelFormat -eq "Format32bppArgb") {
                $imagePath = "$env:TEMP\GmGdn-{0}-$iconFileName.png" -f $(Get-Random)
                $iconBitmap.Save($imagePath, [System.Drawing.Imaging.ImageFormat]::Png) | Out-Null
            }
            else {
                $imagePath = "$env:TEMP\GmGdn-{0}-$iconFileName.jpg" -f $(Get-Random)
                $iconBitmap.Save($imagePath, [System.Drawing.Imaging.ImageFormat]::Jpeg) | Out-Null
            }

            $iconBitmap.Dispose()

            $pictureBoxImagePath.Text = $imagePath
            $pictureBox.Image.Dispose()
            $pictureBox.Image = [System.Drawing.Image]::FromFile($imagePath)

        })
    $gamingPCForm.Controls.Add($listBox)
    
    $buttonUpdateImage = CreateButton "Update Image" 40 220
    $buttonUpdateImage.Size = New-Object System.Drawing.Size(90, 23)
    $buttonUpdateImage.Add_Click({
            $downloadsDirectoryPath = (New-Object -ComObject Shell.Application).Namespace('shell:Downloads').Self.Path
            $openFileDialog = OpenFileDialog "Select PC Image File" 'Image (*.png, *.jpg, *.jpeg)|*.png;*.jpg;*.jpeg' $downloadsDirectoryPath
            $result = $openFileDialog.ShowDialog()
            if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
                $imagePath = ResizeImage $openFileDialog.FileName $textName.Text -HD $true
                $pictureBoxImagePath.Text = $imagePath
                $pictureBox.Image.Dispose()
                $pictureBox.Image = [System.Drawing.Image]::FromFile($imagePath)
                $openFileDialog.Dispose()
            }
        })
    $gamingPCForm.Controls.Add($buttonUpdateImage)

    $buttonRemove = CreateButton "Delete" 410 180
    $buttonRemove.Add_Click({
            $PCName = $textName.Text

            $userInput = [microsoft.visualbasic.interaction]::MsgBox("All Data about '$PCName' will be lost.`r`nAre you sure?", "YesNo,Question", "Confirm PC Removal").ToString()
            if ($userInput.ToLower() -eq 'yes')	{
                RemovePC $PCName
                ShowMessage "Removed '$PCName' from Database." "OK" "Asterisk"
                Log "Removed $PCName from Database."
                $PCList = (RunDBQuery "SELECT name FROM gaming_pcs").name
                $listBox.Items.Clear();
                if ($PCList.Length -gt 0) {
                    $listBox.Items.AddRange($PCList);
                    $listBox.SelectedIndex = 0
                }
                else {
                    $buttonReset.PerformClick() | Out-Null
                }
            }
        })
    $gamingPCForm.Controls.Add($buttonRemove)

    $buttonUpdate = CreateButton "Update" 290 220
    $buttonUpdate.Add_Click({
            $currentlySelectedIndex = $listBox.SelectedIndex

            if ($textName.Text -eq "" -Or $textCost.Text -eq "" -Or $textCurrency.Text -eq "")	{
                ShowMessage "Name, Cost, Currency fields cannot be empty. Try Again." "OK" "Error"
                if ($listBox.Items.Count -gt 0) {
                    $listBox.SetSelected($currentlySelectedIndex, $true)
                }
                return
            }

            $PCName = $textName.Text
            if ( $startDatePicker.Value -gt (Get-Date)) {
                ShowMessage "Start Date Cannot be in Future." "OK" "Error"
                if ($listBox.Items.Count -gt 0) {
                    $listBox.SetSelected($currentlySelectedIndex, $true)
                }
                return
            }
            $PCStartDate = (Get-Date ($startDatePicker.Value) -UFormat %s).Split('.').Get(0)

            $PCCurrency = $textCurrency.Text
            if ( -Not ($PCCurrency -match '\D{1,3}') ) {
                ShowMessage "Currency Symbol cannot be more than 3 characters long'." "OK" "Error"
                if ($listBox.Items.Count -gt 0) {
                    $listBox.SetSelected($currentlySelectedIndex, $true)
                }
                return
            }

            $PCCost = $textCost.Text
            if ( -Not ($PCCost -match '^[0-9]+') ) {
                ShowMessage "Cost cannot have non numeric characters'." "OK" "Error"
                if ($listBox.Items.Count -gt 0) {
                    $listBox.SetSelected($currentlySelectedIndex, $true)
                }
                return
            }

            # Validate and convert Total Playtime
            $playTime = $textTotalPlaytime.Text
            if ( -Not ($playTime -match '^[0-9]{0,5} Hr [0-5]{0,1}[0-9]{1} Min$') ) {
                ShowMessage "Total Playtime format is incorrect. Use 'X Hr Y Min' format." "OK" "Error"
                if ($listBox.Items.Count -gt 0) {
                    $listBox.SetSelected($currentlySelectedIndex, $true)
                }
                return
            }
            $PCTotalPlaytime = ([int]$playTime.Split(" ")[0] * 60) + [int]$playTime.Split(" ")[2]

            if ($checkboxInUse.Checked) {
                $PCEndDate = ""
                $PCCurrentStatus = "TRUE";
            }
            else {
                $PCEndDate = (Get-Date ($endDatePicker.Value) -UFormat %s).Split('.').Get(0)
                $PCCurrentStatus = "FALSE";
                if ( $endDatePicker.Value -gt [DateTime]::Today -or $PCStartDate -gt $PCEndDate) {
                    ShowMessage "End Date Cannot be in Future or before Start Date'." "OK" "Error"
                    if ($listBox.Items.Count -gt 0) {
                        $listBox.SetSelected($currentlySelectedIndex, $true)
                    }
                    return
                }
            }

            $AddNew = $checkboxNew.Checked

            UpdatePC -AddNew $AddNew -OriginalPCName $textOriginalPCName.Text -PCName $PCName -PCIconPath $pictureBoxImagePath.Text -PCCost $PCCost -PCCurrency $PCCurrency -PCStartDate $PCStartDate -PCEndDate $PCEndDate -PCCurrentStatus $PCCurrentStatus -PCTotalPlaytime $PCTotalPlaytime

            if ($AddNew) {
                ShowMessage "Added '$PCName' in Database." "OK" "Asterisk"
            }
            else {
                ShowMessage "Updated '$PCName' in Database." "OK" "Asterisk"
            }

            RefreshPCListBox -listBox $listBox -selectedPCName $PCName
            
            $checkboxNew.Checked = $false
        })
    $gamingPCForm.Controls.Add($buttonUpdate)

    $buttonReset = CreateButton "Reset" 170 180; $buttonReset.Add_Click({
            $textName.Clear(); $textCost.Clear(); $textCurrency.Clear(); $textTotalPlaytime.Text = "0 Hr 0 Min";

            $PCList = (RunDBQuery "SELECT name FROM gaming_pcs").name
            $listBox.Items.Clear(); 
            if ($PCList.Length -gt 0) {
                $listBox.Items.AddRange($PCList);
            }

            $textOriginalPCName.Clear();
            $checkboxInUse.Checked = $false;

            # Disable handler before reset, prevent actual setting reset
            $disableCurrentPCCheckBoxHandler = $true
            $checkboxCurrentPC.Checked = $false;
            $disableCurrentPCCheckBoxHandler = $false

            $checkboxNew.Checked = $false;
            $pictureBoxImagePath.Text = "./icons/pc.png"
            $pictureBox.Image.Dispose()
            $pictureBox.Image = [System.Drawing.Image]::FromFile($pictureBoxImagePath.Text)
            $startDatePicker.Value = [DateTime]::Today
            $endDatePicker.Value = [DateTime]::Today
        }); 
    $gamingPCForm.Controls.Add($buttonReset)

    $buttonAddNew = CreateButton "Add New" 170 220; $buttonAddNew.Add_Click({
            $checkboxNew.Checked = $true
            $buttonUpdate.PerformClick() | Out-Null
        }); 
    $gamingPCForm.Controls.Add($buttonAddNew)

    $buttonCancel = CreateButton "Cancel" 410 220; $buttonCancel.Add_Click({ 
            $listBox.Remove_SelectedIndexChanged({})
            $pictureBox.Image.Dispose(); $pictureBox.Dispose();
            $gamingPCForm.Dispose()
        }); 
    $gamingPCForm.Controls.Add($buttonCancel)

    $gamingPCForm.ShowDialog()
    $listBox.Remove_SelectedIndexChanged({})
    $pictureBox.Image.Dispose(); $pictureBox.Dispose();
    $gamingPCForm.Dispose()
}

function RenderAddPlatformForm() {
    $addPlatformForm =	CreateForm "Gaming Gaiden: Add Emulator" 395 265 ".\icons\running.ico"

    $labelName = Createlabel "Platorm:" 10 20; $addPlatformForm.Controls.Add($labelName)
    $textName = CreateTextBox "" 85 20 200 20; $addPlatformForm.Controls.Add($textName)

    $labelExe = Createlabel "Emulator`nExe List:" 10 79; $addPlatformForm.Controls.Add($labelExe)
    $textExe = CreateTextBox "" 85 82 200 20; $textExe.ReadOnly = $true; $addPlatformForm.Controls.Add($textExe)

    $labelRomExt = Createlabel "Rom Extns:" 10 146;	$addPlatformForm.Controls.Add($labelRomExt)
    $textRomExt = CreateTextBox "" 85 144 200 20; $addPlatformForm.Controls.Add($textRomExt)

    $labelCores = Createlabel "Core:" 10 208; $labelCores.hide(); $addPlatformForm.Controls.Add($labelCores)
    $textCore = CreateTextBox "" 85 206 200 20;	$textCore.ReadOnly = $true;	$textCore.hide(); $addPlatformForm.Controls.Add($textCore)

    $buttonAddCore = CreateButton "Add Core" 300 204; $buttonAddCore.hide()
    $buttonAddCore.Add_Click({
            $openFileDialog = OpenFileDialog "Select Retroarch Core" 'DLL (*.dll)|*.dll'
            $result = $openFileDialog.ShowDialog()
            if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
                $textCore.Text = (Get-Item $openFileDialog.FileName).Name
                $openFileDialog.Dispose()
            }
        })
    $addPlatformForm.Controls.Add($buttonAddCore)

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

                $emulatorExeList = $textExe.Text
                if ($emulatorExeList.ToLower() -like "*retroarch*") {
                    $addPlatformForm.Size = New-Object System.Drawing.Size(395, 315)
                    $buttonOK.Location = New-Object System.Drawing.Point(85, 250)
                    $buttonCancel.Location = New-Object System.Drawing.Point(210, 250)

                    $labelCores.show()
                    $textCore.show()
                    $buttonAddCore.show()

                    ShowMessage "Retroarch detected. Please Select Core for Platform." "OK" "Asterisk"
                }

                $openFileDialog.Dispose()
            }
        })
    $addPlatformForm.Controls.Add($buttonAddExe)

    $buttonClearExe = CreateButton "Clear List" 300 95
    $buttonClearExe.Add_Click({
            $textExe.Text = ""
        })
    $addPlatformForm.Controls.Add($buttonClearExe)

    $buttonOK = CreateButton "OK" 85 200
    $buttonOK.Add_Click({
            if ($textExe.Text -eq "" -Or $textName.Text -eq "" -Or $textRomExt.Text -eq "")	{
                ShowMessage "Platform, Exe and Extensions fields cannot be empty.`r`nTry again." "OK" "Error"
                return
            }

            $emulatorExeList = $textExe.Text -replace ".exe"
            if ($emulatorExeList.ToLower() -like "*retroarch*") {
                if ($textCore.Text -eq "") {
                    ShowMessage "Retroarch detected.`r`nYou must select Core for platform. Try again." "OK" "Error"
                    return
                }
            }

            $platformName = $textName.Text
            $platformFound = DoesEntityExists "emulated_platforms" "name"  $platformName
            if ($null -ne $platformFound) {
                ShowMessage "Platform $platformName already exists.`r`nUse Edit Emulator setting to check existing platforms." "OK" "Error"
                return
            }

            $emulatorCore = $textCore.Text

            $exeCoreComboFound = CheckExeCoreCombo $emulatorExeList $emulatorCore
            if ($null -ne $exeCoreComboFound) {
                ShowMessage "Executables in the list '$emulatorExeList' is already registered with core '$emulatorCore'.`r`nCannot register another platform with same Exe and Core Combination.`r`nUse Edit Platform setting to check existing platforms." "OK" "Error"
                return
            }

            $platformRomExtensions = $textRomExt.Text
            if (-Not ($platformRomExtensions -match '^([a-zA-Z0-9!@#$%^&_\-~]+,)*([a-zA-Z0-9!@#$%^&_\-~]+)$'))	{
                ShowMessage "Error in rom extensions. Please submit extensions as a ',' separated list without the leading '.'`r`ne.g. zip,iso,chd OR zip,iso OR zip" "OK" "Error"
                return
            }

            SavePlatform -PlatformName $platformName -EmulatorExeList $emulatorExeList -CoreName $emulatorCore -RomExtensions $platformRomExtensions

            ShowMessage "Registered '$platformName' in Database." "OK" "Asterisk"

            $addPlatformForm.Close() | Out-Null
        })
    $addPlatformForm.Controls.Add($buttonOK)

    $buttonCancel = CreateButton "Cancel" 210 200; $buttonCancel.Add_Click({ $addPlatformForm.Dispose() }); $addPlatformForm.Controls.Add($buttonCancel)

    $addPlatformForm.ShowDialog()
    $addPlatformForm.Dispose()
}

function Set-Theme {
    param([string]$ThemeName)

    $themeDir = ".\ui\resources\css"
    $themePath = "$themeDir\theme.css"
    $sourceTheme = "$themeDir\theme-$ThemeName.css"

    # Copy the selected theme to theme.css
    Copy-Item -Path $sourceTheme -Destination $themePath -Force
}
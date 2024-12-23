[System.Reflection.Assembly]::LoadWithPartialName('System.Web') | out-null

Remove-Item -Recurse .\build\GamingGaiden

mkdir -f .\build\GamingGaiden

Get-ChildItem -File .\ui\*.html -Exclude 404.html | Remove-Item

pandoc.exe --ascii .\Manual.md -o .\ui\Manual.html

$ManualHTML = Get-Content .\ui\Manual.html
$ManualTemplate = Get-Content .\ui\templates\Manual.html.template

$FinalHTML = $ManualTemplate -replace "_MARKDOWN_HTML_", $ManualHTML

[System.Web.HttpUtility]::HtmlDecode($FinalHTML) | Out-File -encoding UTF8 .\ui\Manual.html

Get-ChildItem .\ui\resources\images\ -Exclude default.png, dropped.png, pc.png, 404.png, 404-tutorial.gif, forever.png, hold.png, finished.png, playing.png, favicon.ico | Remove-Item

$SourceFiles = ".\Install.bat", ".\modules", ".\icons", ".\ui"

Copy-Item -Recurse -Path $SourceFiles -Destination .\build\GamingGaiden\ -Force

# Add 404 pages for all ui pages for first time render
$fileNames = @("Summary.html", "GamingTime.html", "MostPlayed.html", "AllGames.html", "IdleTime.html", "GamesPerPlatform.html", "PCvsEmulation.html")
foreach ($fileName in $fileNames) {
    Copy-Item -Path .\ui\404.html -Destination .\build\GamingGaiden\ui\$fileName -Force
}

ps12exe -inputFile ".\GamingGaiden.ps1" -outputFile ".\build\GamingGaiden\GamingGaiden.exe" -resourceParams @{iconFile = '.\build\GamingGaiden\icons\running.ico'; title = 'Gaming Gaiden: Gameplay Time Tracker'; product = 'Gaming Gaiden'; copyright = '© 2024 Kulvinder Singh'; version = '2024.12.23' }

Compress-Archive -Force -Path .\build\GamingGaiden -DestinationPath .\build\GamingGaiden.zip

Remove-Item -Recurse .\build\GamingGaiden
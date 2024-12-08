[System.Reflection.Assembly]::LoadWithPartialName('System.Web') | out-null

Remove-Item -Recurse .\build\GamingGaiden

mkdir -f .\build\GamingGaiden

Remove-Item .\ui\*.html -ErrorAction SilentlyContinue

pandoc.exe --ascii .\Manual.md -o .\ui\Manual.html

$ManualHTML = Get-Content .\ui\Manual.html
$ManualTemplate = Get-Content .\ui\templates\Manual.html.template

$FinalHTML = $ManualTemplate -replace "_MARKDOWN_HTML_", $ManualHTML

[System.Web.HttpUtility]::HtmlDecode($FinalHTML) | Out-File -encoding UTF8 .\ui\Manual.html

Get-ChildItem .\ui\resources\images\ -Exclude default.png, dropped.png, pc.png, forever.png, hold.png, finished.png, playing.png, favicon.ico | Remove-Item

$SourceFiles = ".\Install.bat", ".\modules", ".\icons", ".\ui"

Copy-Item -Recurse -Path $SourceFiles -Destination .\build\GamingGaiden\ -Force

ps12exe -inputFile ".\GamingGaiden.ps1" -outputFile ".\build\GamingGaiden\GamingGaiden.exe" -resourceParams @{iconFile = '.\build\GamingGaiden\icons\running.ico'; title = 'Gaming Gaiden: Gameplay Time Tracker'; product = 'Gaming Gaiden'; copyright = '© 2024 Kulvinder Singh'; version = '2024.12.8' }

Compress-Archive -Force -Path .\build\GamingGaiden -DestinationPath .\build\GamingGaiden.zip

Remove-Item -Recurse .\build\GamingGaiden
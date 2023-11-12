[System.Reflection.Assembly]::LoadWithPartialName('System.Web')          	 | out-null

mkdir -f .\build\GamingGaiden
Remove-Item .\ui\*.html -ErrorAction SilentlyContinue

pandoc.exe --ascii .\Manual.md -o .\ui\Manual.html

$ManualHTML = Get-Content .\ui\Manual.html
$ManualTemplate = Get-Content .\ui\templates\Manual.html.template

$FinalHTML = $ManualTemplate -replace "_MARKDOWN_HTML_",$ManualHTML 

[System.Web.HttpUtility]::HtmlDecode($FinalHTML) | Out-File -encoding UTF8 .\ui\Manual.html

Get-ChildItem .\ui\resources\images\ -Exclude default.png, finished.png, playing.png | Remove-Item

$SourceFiles = ".\GamingGaiden.ps1", ".\SetupDatabase.ps1", ".\Configure.ps1", ".\Install.ps1", ".\modules", ".\icons", ".\ui"

Copy-Item -Recurse -Path $SourceFiles -Destination .\build\GamingGaiden\ -Force

Compress-Archive -Force -Path .\build\GamingGaiden -DestinationPath .\build\GamingGaiden.zip

Remove-Item -Recurse .\build\GamingGaiden
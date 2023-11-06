[System.Reflection.Assembly]::LoadWithPartialName('System.Web')          	 | out-null

mkdir -f .\build\GamingGaiden

D:\Projects\pandoc-3.1.9\pandoc.exe --ascii .\manual.md -o .\ui\manual.html

$ManualHTML = Get-Content .\ui\manual.html
$ManualTemplate = Get-Content .\ui\templates\manual.html.template

$FinalHTML = $ManualTemplate -replace "_MARKDOWN_HTML_",$ManualHTML 

[System.Web.HttpUtility]::HtmlDecode($FinalHTML) | Out-File -encoding UTF8 .\ui\manual.html

Remove-Item .\ui\index.html -ErrorAction SilentlyContinue

Get-ChildItem .\ui\resources\images\ -Exclude default.png, finished.png, playing.png | Remove-Item

$SourceFiles = ".\GamingGaiden.ps1", ".\SetupDatabase.ps1", ".\Configure.ps1", ".\Install.ps1", ".\modules", ".\icons", ".\ui"

Copy-Item -Recurse -Path $SourceFiles -Destination .\build\GamingGaiden\ -Force

Compress-Archive -Force -Path .\build\GamingGaiden -DestinationPath .\build\GamingGaiden.zip

Remove-Item -Recurse .\build\GamingGaiden
mkdir -f .\build\GamingGaiden

Remove-Item .\ui\index.html -ErrorAction SilentlyContinue

Get-ChildItem .\ui\resources\images\ -Exclude default.png | Remove-Item

$SourceFiles = ".\GamingGaiden.ps1", ".\SetupDatabase.ps1", ".\Configure.ps1", ".\Install.ps1", ".\modules", ".\icons", ".\ui"

Copy-Item -Recurse -Path $SourceFiles -Destination .\build\GamingGaiden\ -Force

Compress-Archive -Force -Path .\build\GamingGaiden -DestinationPath .\build\GamingGaiden.zip

Remove-Item -Recurse .\build\GamingGaiden
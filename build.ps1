mkdir -f .\build\GamingGaiden

ps2exe -inputFile .\Install.ps1 -outputFile .\build\Install.exe -iconFile .\icons\running.ico -title "Gaming Gaiden Installer" -version 1.0 -requireAdmin -lcid 1033

Remove-Item .\ui\index.html

Get-ChildItem .\ui\resources\images\ -Exclude default.png | Remove-Item

$SourceFiles = ".\GamingGaiden.ps1", ".\SetupDatabase.ps1", ".\Configure.ps1", ".\modules", ".\icons", ".\ui", ".\build\Install.exe"

Copy-Item -Recurse -Path $SourceFiles -Destination .\build\GamingGaiden\

Compress-Archive -Force -Path .\build\GamingGaiden -DestinationPath .\build\GamingGaiden.zip

Remove-Item -Recurse .\build\GamingGaiden
Remove-Item -Recurse .\build\Install.exe
<div align="center">

[![GitHub stars](https://img.shields.io/github/stars/kulvind3r/gaminggaiden)](https://github.com/kulvind3r/gaminggaiden/stargazers)
[![Hits](https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2Fkulvind3r%2FGamingGaiden&count_bg=%23EF476F&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=Visitors&edge_flat=false)](https://hits.seeyoufarm.com)
[![GitHub Downloads (latest)](https://img.shields.io/github/downloads/kulvind3r/gaminggaiden/latest/total?label=Downloads%20-%20Latest&color=%23FFD166)](https://github.com/kulvind3r/GamingGaiden/releases/latest)
![GitHub Downloads (all)](https://img.shields.io/github/downloads/kulvind3r/gaminggaiden/total?label=Downloads%20-%20Total&color=%23FFD166)

[![Codacy Quality](https://app.codacy.com/project/badge/Grade/c4a01f22c3864d8c80b8c6891a6feb5f)](https://app.codacy.com/gh/kulvind3r/GamingGaiden/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)
[![GitHub commit activity](https://img.shields.io/github/commit-activity/m/kulvind3r/gaminggaiden?label=Commit%20Activity&color=%23073B4C)](https://github.com/kulvind3r/gaminggaiden/graphs/commit-activity)
[![GitHub issues](https://img.shields.io/github/issues/kulvind3r/gaminggaiden?label=Issues&color=%23118AB2)](https://github.com/kulvind3r/gaminggaiden/issues)

![Gaming Gaiden](./readme-files/GamingGaidenBanner.png)

</div>

### 外伝 (Gaiden)

Japanese

noun (common)

A Tale; Side Story;

A small powershell tray application for windows os to track gaming time. Helps you record your gaming story over the years.

https://github.com/user-attachments/assets/4837b88c-e403-4069-a3f5-3f0147e9328a

## Features
- #### Time Tracking and Emulator Support
    - Tracks play time for PC or emulated games.
    - Auto tracks new roms after registering any emulator just once.
    - Supports Retroarch cores.
    - Detects and removes idle time from gaming sessions.
    - Out of box HWiNFO64 integration with session time and tracking status metrics.
- #### UI and Statistics
    - Fast browser based UI with search and sorting. Quick view popup for recent games.
    - Multiple in depth statistics on gaming. Lifetime summary, monthly/yearly time analysis, most played games, games per emulator etc.
    - Integrated google image search for game icons / box art.
    - Mark games as Finished / Playing to track backlog completion.
- #### Quality of Life Features
    - Small size (~7 MB). High performance (Sub 5 sec game detection). Light on cpu & ram.
    - Completely offline and portable, all data stored in local database.
    - Automated data backup after each gaming session.

> [!WARNING]  
> Gaming Gaiden is only available for download on this Github repo. Any copy available elsewhere could be malicious.

## How to install / upgrade / use
1. Open a Powershell window as admin and run below command to allow powershell modules to load on your system. Choose `Yes` when prompted.
    - `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

2. Download ***GamingGaiden.zip*** from the [latest release](https://github.com/kulvind3r/GamingGaiden/releases/latest).
3. Extract ***GamingGaiden*** folder and Run `Install.bat`. Choose Yes/No for autostart at Boot.
4. Use the shortcut on desktop / start menu for launching the application.
5. Regularly backup your `GamingGaiden.db` and `backups` folder to avoid data loss. Click ***Settings => Open Install Directory*** option in app menu to find them.

## Unknown Publisher
Windows SmartScreen may warn that the application is from an ***Unknown Publisher*** because it lacks signature from a public CA. 
Signing cost for apps is hundreds of dollars per year. Can't afford them.

## Antivirus False Positives
> :hearts:
> Anitvirus false positives are hard to fight.
> If you have found the app useful and safe. Please leave a star on github to increase trust.

GamingGaiden performs following tasks that are similar to common malware behavior, leading it to be flagged as malware by antivirus software.

- Scanning running programs to detect and track games.
- Adding registry entries for HWinfo64 integration.
- Periodically sleeping to conserve resources.
- Monitoring user activity to detect idle time.
- Packaged as an executable using ps12exe.

Its PowerShell-based implementation also raises flags as powershell scripts can be used maliciously and have low trust in tech community.

Antivirus flag such behavior to keep users safe without doing actual verification of malicious actiity. Fixing false positives requires manually requesting antivirus providers to unflag GamingGaiden or rewriting it in a compiled language like C#. Even then there is no guarantee of a fix due to it's functionality being process scanning.

Given that I wrote it for personal use, above is not something I can work on atleast for some time. The source code is open and available for anyone to review and ensure nothing wrong is happening. Users are responsible for their own safety and actions when using the program. 

Please remember that open-source software comes without any support or warranties.

## Attributions
Made with love using 

- [PSSQLite](https://www.powershellgallery.com/packages/PSSQLite) by [Warren Frame](https://github.com/RamblingCookieMonster)
- [ps12exe](https://github.com/steve02081504/ps12exe) by [Steve Green](https://github.com/steve02081504)
- [DOMPurify](https://github.com/cure53/DOMPurify) by [Cure53](https://github.com/cure53)
- [DataTables](https://datatables.net/)
- [Jquery](https://jquery.com/)
- [ChartJs](https://www.chartjs.org/)
- Various Icons from [Icons8](https://icons8.com)
- Game Cartridge Icon from [FreePik on Flaticon](https://www.flaticon.com/free-icons/game-cartridge)
- Cute [Ninja Vector by Catalyststuff on Freepik](https://www.freepik.com/free-vector/cute-ninja-gaming-cartoon-vector-icon-illustration-people-technology-icon-concept-isolated-flat_42903434.htm)
- [Ninja Garden Font](https://www.fontspace.com/ninja-garden-font-f32923) by [Iconian Fonts](https://www.fontspace.com/iconian-fonts)

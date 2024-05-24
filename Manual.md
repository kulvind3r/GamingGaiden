# Gaming Gaiden Manual

### How do I track a PC game?
1. Notify icon menu *Settings => Add Game*. 
2. Add the executable of game using *Add Exe*.
3. Icon should auto update. You can set a new icon by using *Search* (searches google for game icon) and *Update* (browse for image) buttons.
4. Change the auto populated *Name* to a better one and click *Ok*.

### Pre-requisite for emulated games

**Gaming Gaiden tracks emulated games automatically based on emulator *Command Line* parameters.**

To use Gaming Gaiden, you must use *Command lines* to launch your emulated games. *Command lines* for emulator looks like below

- **PCSX2** *[path]\\pcsx2-qtx64-avx2.exe %ROM%*

- **Retrorach** *[path]\\retroarch.exe -L [path]\\cores\\flycast_libretro.dll %ROM%*

Most Frontends like Emulation Station etc. are setup to use command lines to launch games. If you don't use a frontend, you can find online how to create desktop shortcuts for most emulators that launch games in above manner.

### How do I track an emulated game?
Once you have your emulation setup like above..

1. Notify icon menu *Settings => Add Emulator*
2. Enter platform name in *Platform* e.g. NES, Genesis, Playstation 2, Gamecube etc.
3. Add executable of the emulator you use for the platform using *Add Exe*. You can add more than one emulator's exe for the same platform e.g. ePSXe and Duckstation for Playstation.
4. If retroarch is detected, it will automatically ask you for the core used for the platform. Add using *Add Core* button that shows.
5. Enter extensions you use for your game rom files e.g. zip,chd,rvg in *Rom Extns*. A comma separated list of just the extension name without the leading *"."* and no spaces.

Click ok to register the platform and Gaming Gaiden will now track any game you play with the added emulators automatically.

**Emulated games are auto detected and auto registered. Name of Rom File is used to track the game. If you change name of Rom file later, it will be re-detected as a brand new game.**

### How do I make changes to a tracked game or mark it as finished?

1. Notify icon menu *Settings => Edit Game*. Select the game you want to change in the list that shows on right side in dialog box. You can search for game by name too.
2. Change executable if you need to e.g. After reinstallation to a different directory.
3. To change icon, use *Search* button to google for game icon and save it. Then click *Update* to browse and select the file. *png* and *jpg* files are supported.
4. Update play time manually, Simply add number of hours / minutes in the already displayed playtime values.
5. Change platform if required, although not likely.
6. Mark the game as finished using provided checkbox.
7. Press *Ok* to update or Cancel to close.

### How do I make changes to an emulator for a platform?

1. Notify icon menu *Settings => Edit Emulator*. Select the platform you want to change in the list that shows on right side in dialog box. You can search for platform by name too.
2. Change or add another executable to the emulator exe list or a new path if you relocated your emulator
3. Change retorach core to a new one if you started using a different core.
4. Add new file extensions by adding as comma separated list without spaces and leading ".", or change existing ones as required.
5. Press *Ok* to update or *Cancel* to close.

### How do I pause/resume tracking?

To pause, notify icon menu => *Stop Tracker*. To resume tracking, *Start Tracker*.

### How do I disable/enable auto start?

1. Open Run Dialog by pressing *Win+R*.
2. Enter *shell:startup* in the dialog box and press enter.
3. Delete the *Gaming Gaiden* shortcut from the folder that opens.
4. To re enable auto start, just run *install.bat* again from existing install directory and choose *yes* when prompted for enabling auto start.

### I accidentally corrupted / lost / deleted some or all of my data. How do I restore?

Check the backup folder in the install directory, it should have backups of database. Exit the app. Copy the database file from one of the backup zip files to install directory and start the app again.

### Gaming Gaiden is not tracking emulated games launched from emulator application directly.

It cannot. 

Games launched directly from emulator GUI like Retroarch, PCSX2, Dolphin or Duckstation might not have *Command lines* attached in Windows process. You must either use a Frontend like EmulationStation, Launchbox etc with *Command line* or Windows desktop shortcuts to the emulators with *Command lines*

### I use a single emulator for multiple platforms. How do I track them separately?

For emulators that can play more than one platform, for e.g. Dolphin that plays both Wii and Gamecube. You need to make sure that there is some difference in the command line of the emulator when running different platform.

To do this, make a copy of executable of emulator and change it's name to include platform name for e.g.

Make two copies of *Dolphin.exe* in the same directory and name them *Dolphin-Wii.exe* and *Dolphin-Gamecube.exe*.

Now register Gamecube and Wii Platforms in Gaming Gaiden and use the new exes with the platform name for each. **Don't forget to update your frontend / shortcuts similarly to use the new exes.**

This is the only way for Gaming Gaiden to register games under the correct platform. Otherwise if you don't care about which platform game belongs to. You can just name the platform *"Gamecube and Wii"* and use the single *"Dolphin.exe"*

Hide the extra copies of *"Dplphin.exe"* in explorer to keep your Dolphin installation looking neat and clean.

### I use the same Retroarch core for multiple platforms. How do I track them separately?

Same trick as above can be applied fore retroarch as well. Use the same core, but make copies of *"retroarch.exe"* for each platform and use those as executables for different platforms.

Hide the extra copies of *"retroarch.exe"* in explorer to keep your retroarch installation looking neat and clean.
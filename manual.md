# Gaming Gaiden Manual

### How do I track a PC game?
1. Notify icon menu *Settings => Add Game*. 
2. Add the executable of game using *Add Exe*.
3. Icon should auto update, and can be later changed from *Settings => Edit Game*
4. Change the auto populated *Name* to a better one.

Name field cannot be changed once game is added without deleting and re adding the game. Update it correctly before adding.

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
3. Add executable of the emulator you use for the platform using *Add Exe*
4. If retroarch is detected, it will automatically ask you for the core used for the platform. Add using *Add Core* button that shows.
5. Enter extensions you use for your game rom files e.g. zip, chd, rvg in *Rom Extns*. Just the extension name without the leading *"."*

Click ok to register the platform and Gaming Gaiden will now track any game you play with an emulator automatically.

### How do I make changes to a tracked game or mark it as finished?

1. Notify icon menu *Settings => Edit Game*. Select the game you want to change in the list that shows and press ok.
2. Change executable if you need to e.g. After reinstallation to a different directory.
3. Change Icon. Browse and select a file, *png* and *jpg* files are supported.
4. Update play time manually, Simply add number of hours / minutes in the already displayed playtime values.
5. Change platform if required, although not likely.
6. Mark the game as finished using provided checkbox.

**Game name cannot be changed. To change the name, copy your play time, delete the game, add it again with new name, and then set play time to same as before**

### How do I make changes to an emulator for a platform?

1. Notify icon menu *Settings => Edit Emulator*. Select the platform you want to change in the list that shows and press ok.
2. Change executable to the new emulator executable or a new path if you relocated your emulator
3. Change retorach core to a new one if you started using a different core.
4. Add new extensions by adding as comma separated list, or change existing ones as required.

**Platform name cannot be changed. You will have to delete a platform and add it again, already registered games of the platform will not be affected on deleting platform**

### How do I pause/resume tracking?

Notify icon menu *Settings => Stop Tracker*. To resume tracking *Settings => Start Tracker*

### Gaming Gaiden is not tracking emulated games launched from emulator application directly

It cannot. Games launched directly from emulator GUI like Retroarch, PCSX2, Dolphin or Duckstation might not have *Command lines* attached in Windows process. You must either use a Frontend like EmulationStation, Launchbox etc with *Command line* or Windows desktop shortcuts to the emulators with *Command lines*

### Single emulator for multiple platforms
For emulators that can play more than one platform, for e.g. Dolphin that plays both Wii and Gamecube. You need to make sure that there is some difference in the command line of the emulator when running different platform.

To do this, make a copy of executable of emulator and change it's name to include platform name for e.g.

Make two copies of *Dolphin.exe* in the same directory and name them *Dolphin-Wii.exe* and *Dolphin-Gamecube.exe*.

Now register Gamecube and Wii Platforms in Gaming Gaiden and use the new exes with the platform name for each. **Don't forget to update your frontend / shortcuts similarly to use the new exes.**

This is the only way for Gaming Gaiden to register games under the correct platform. Otherwise if you don't care about which platform game belongs to. You can just name the platform *"Gamecube and Wii"* and use the single *"Dolphin.exe"*

Hide the extra copies of *"Dplphin.exe"* in explorer to keep your Dolphin installation looking neat and clean.

### Single Retroarch core for multiple platforms

Same trick as above can be applied fore retroarch as well. Use the same core, but make copies of *"retroarch.exe"* for each platform and use those as executables for different platforms.

Hide the extra copies of *"retroarch.exe"* in explorer to keep your retroarch installation looking neat and clean.

### Why the above workarounds, can't you just code something to handle this?

Gaming Gaiden was born due to an excellent program *"Gameplay-Time-Tracker"* completly failing due to it's complexity. *"Gameplay-Time-Tracker"* did lots of tricks and stuff to handle complex scenarios. With time as Operating systems and applications changed, it couldn't even do it's core feature of tracking games. It was abandoned and is no longer maintained.

Gaming Gaiden has been designed to remain as simple as possible. It avoids doing complex intelligent guess work / smart identification to not depend on special operating system features or unique libraries that can change in future.

*Command line* approach to run applications is the most fundamental way to run programs without GUI. If an emulator makes changes in it's *Command line* , Gaming Gaiden can be quickly updated to adjust to those changes and keep working.

Doing the above workaround keeps the *Command line* for each emulator distinct and therefore chances of misdetection are eliminated. 

And the workaround is very simple for end user to do.
### Track PC games
1. Notify icon menu *Settings => Add Game*. 
2. Add the executable of game using *Add Exe*.
3. Icon should auto update. You can set a new icon by using *Search* (searches google for game icon) and *Update* (browse for image) buttons.
4. Change the auto populated *Name* to a better one and click *Ok*.

### Track emulated games

**Requires launching games via command line params** like 

- *pcsx2-qtx64-avx2.exe %ROM%*
- *retroarch.exe -L cores\\flycast_libretro.dll %ROM%*. 

Most frontends already use the above way.

1. *Settings => Add Emulator*
2. Enter platform (NES, Genesis, PS2, etc.)
3. *Add Exe* - emulator executable (can add multiple per platform)
4. For Retroarch: *Add Core* when prompted
5. *Rom Extns* - comma-separated list without dots/spaces (zip,chd,rvg)

**Games auto-register using ROM filename. Renaming ROM creates new entry.**

### Update tracked game status, edit play time, change icon etc.

App menu: *Settings => Edit Game*, select game from list (searchable).

- Change executable (after reinstall)
- Update icon (*Search* for online, *Update* to browse - png/jpg supported)
- Manually adjust play time
- Change platform
- Mark as finished / other status (checkbox)

### Update emulator for platform

*Settings => Edit Emulator*, select platform from list (searchable).

- Update executable path or add new exe
- Change Retroarch core
- Modify ROM extensions

### Pause/Resume tracking

App menu: *Stop Tracker* to pause, *Start Tracker* to resume.

### Disable/Enable auto start

**Disable:** Press *Win+R*, enter *shell:startup*, delete *Gaming Gaiden* shortcut.

**Re-enable:** Run *install.bat* from install directory, choose *yes* for auto start.

### Restore data

1. App menu: *Settings => Open Install Directory*. Go to *backups* folder.
2. Exit app. 
3. Copy database file from backup folder zip to install directory. 
4. Restart app.

### Games launched from emulator application directly are not tracked

Games launched from emulator GUI (Retroarch, PCSX2, Dolphin, Duckstation) lack command line parameters in Windows process. Use a frontend (EmulationStation, Launchbox) or desktop shortcuts with command lines.

### Track multiple platforms using a single emulator

1. Copy emulator exe with platform-specific names. Example: Copy *Dolphin.exe* to *Dolphin-Wii.exe* and *Dolphin-Gamecube.exe*. 
2. Register each platform with its renamed exe. 
3. Update frontend/shortcuts to use new exes.

Alternative: Name platform *"Gamecube and Wii"* using single exe.

### Track multiple platforms using a single Retroarch core

1. Copy *retroarch.exe* with platform-specific names (e.g. *Retroarch-Genesis.exe*, *Retroarch-GameGear.exe*). 
2. Register each platform with its renamed exe. 
3. Update frontend/shortcuts.

Alternative: Name platform *"Genesis & GameGear"* using single core.
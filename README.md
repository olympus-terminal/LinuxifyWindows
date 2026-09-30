# LinuxifyWindows

Scripts for Linux users who have to live with a Windows 11 machine. They keep your **local account**,
stop Microsoft's account sign-up pushing and ads, and make Windows work more like Linux: a
bash-style shell, CLI tools, cleaner Explorer and taskbar defaults, fixes for dual-booting with GRUB, and a
GNOME-style desktop: translucent terminal, 10 workspaces with GNOME hotkeys, and a wallpaper per workspace.

Plain PowerShell, every section opt-in, everything logged and reversible. The core sections have no
dependencies; the optional desktop sections (13, 14) download AutoHotkey, a small DLL and wallpapers.

**Tested on:** Windows 11 Home 24H2 and 25H2 (build 26200). Ran cleanly with no `SKIP` lines in the log.
Reports from other editions and builds are welcome (please include your `linuxify.log`).

## Why

Windows 11 increasingly pushes existing local-account users into a Microsoft account. You get
full-screen "finish setting up your device" loops at sign-in, sometimes with a countdown ("you have
7 days"). Since 2025 Microsoft has also removed the usual setup workarounds (`oobe\bypassnro`,
the BypassNRO registry value, `ms-cxh:localonly`)
([Windows Latest, Sep 2026](https://www.windowslatest.com/2026/09/13/microsoft-blocked-every-windows-11-account-bypass-except-the-most-boring-link-on-its-own-page/)).
These scripts use Microsoft's own documented policies and settings to keep the account you already have.

## Quick start

1. Download or clone this repo onto the Windows machine and sign in to the local admin account you want to keep.
2. Double-click **`1-keep-local-account.cmd`** and accept the UAC prompt.
3. Double-click **`2-linuxify.cmd`** and answer Y/n for each section.
4. Restart.
5. Optional: [Gaming](#gaming) (`3-game-tune.cmd`) and [Claude Code](#claude-code-on-native-windows).

If SmartScreen says "Windows protected your PC", click **More info → Run anyway**, or right-click
the file → Properties → **Unblock** first.

To run from a terminal instead (Terminal (Admin)):

```powershell
powershell -ExecutionPolicy Bypass -File .\keep-local-account.ps1
powershell -ExecutionPolicy Bypass -File .\linuxify.ps1
```

## Files

| File | What it does |
|---|---|
| `1-keep-local-account.cmd` → `keep-local-account.ps1` | Creates a `BackupAdmin` local admin (password prompted, never stored), blocks Microsoft accounts, turns off the setup nag screens, then verifies. |
| `2-linuxify.cmd` → `linuxify.ps1` | Interactive customizer: 15 sections, each asks Y/n first. Logs to `%USERPROFILE%\linuxify.log`. |
| `hotkeys/linux-hotkeys.ahk` | AutoHotkey v2 script with the GNOME workspace keys (installed by section 13). |
| `set-workspace-wallpapers.ps1` | Gives each virtual desktop its own wallpaper. Runs on its own too (no admin), with `-ImageDir` for your own pictures. |
| `3-game-tune.cmd` → `gaming/game-tune.ps1` | Gaming check and tune-up, see [Gaming](#gaming). `-CheckOnly` reports without changing anything. |
| `gaming/play-game.ps1` | Launches a Steam game with background apps and AutoHotkey closed, then restores them when the game exits. |
| `undo-linuxify.cmd` → `undo-linuxify.ps1` | Resets the registry changes from both scripts to Windows defaults and removes the shell-profile block. |

## What `linuxify.ps1` does

| # | Section | Details |
|---|---|---|
| 0 | Restore point | Creates a "Before linuxify" System Restore point, your full undo. |
| 1 | Account recruiting | `NoConnectedUser=3` ("Accounts: Block Microsoft accounts"), turns off SCOOBE ("finish setting up") and the welcome experience, Start account notifications off, `DisableConsumerAccountStateContent`. |
| 2 | Ads and suggestions | Start, Settings, and lock-screen suggestions; silent promo-app installs; advertising ID; tailored experiences; OneDrive ads in Explorer. |
| 3 | Telemetry | `AllowTelemetry=0` (Home/Pro still keep "Required" data), feedback prompts, activity history. |
| 4 | Bing / Copilot / Recall / Widgets | Web results in Start search, Copilot policy and app, Recall snapshots, Widgets. |
| 5 | OneDrive | Turns OneDrive off completely. Say **n** if you use it. |
| 6 | Promo apps | News, Weather, Tips, Solitaire, Feedback Hub, Clipchamp, personal Teams, Office hub, Cortana, Phone Link, Maps, and more. Removed for the current user; reinstallable from the Store. |
| 7 | Desktop | File extensions and hidden files shown, Explorer opens to This PC, full path in the title bar, no recent files, classic right-click menu, left-aligned taskbar, no search box / Task View / Chat, dark mode. |
| 8 | Dual boot | Fast Startup off (Linux can then mount the NTFS drive read-write), hardware clock in UTC (no clock jumps after booting Linux). |
| 9 | Developer | Long paths, Developer Mode (symlinks without admin), built-in `sudo` (24H2+), `RemoteSigned` execution policy for the current user. |
| 10 | Tools (winget) | PowerShell 7, Git + Git Bash, uutils coreutils, neovim, ripgrep, fd, fzf, bat, zoxide, 7-Zip, PowerToys (FancyZones tiling, a rofi-like launcher). |
| 11 | Shell profile | Emacs/bash keys (Ctrl+A/E/R/W), Tab menu-complete, history prediction, `which`, `touch`, `ll`, `grep`→rg, `vim`→nvim, zoxide `z`. Written between `# >>> linuxify >>>` markers, so re-runs replace it cleanly. |
| 12 | Terminal look | Windows Terminal like [ghost_terminal](https://github.com/olympus-terminal/ghost_terminal): black at 58% opacity (no blur), green `#96D5A2` text, Linux console palette, 96×42, 13pt, Ctrl+PgUp/PgDn switch tabs. Old settings kept as `settings.json.linuxify-bak`. |
| 13 | Workspace hotkeys | AutoHotkey v2 + [VirtualDesktopAccessor](https://github.com/Ciantic/VirtualDesktopAccessor), started at login. See the table below. |
| 14 | Workspace wallpapers | Downloads the 11 dark sci-fi wallpapers from [linux_desktop_customization](https://github.com/olympus-terminal/linux_desktop_customization), scales them to the screen, and sets one per desktop (alphabetical order). Native per-desktop wallpapers, so no daemon. Uses the `VirtualDesktop` PowerShell Gallery module. |

**Never touched:** Windows Defender, Windows Update, firewall.

## Workspace hotkeys (section 13)

From `gnome-keybindings.dconf` in linux_desktop_customization. Ten fixed desktops, like GNOME with dynamic workspaces off.

| Keys | Action |
|---|---|
| Ctrl+1 … Ctrl+9, Ctrl+0 | Go to workspace 1–10 |
| Ctrl+Shift+← / → | Previous / next workspace |
| Ctrl+Shift+Alt+← / →, Win+Shift+Alt+← / →, Win+Shift+PgUp / PgDn | Move the active window to the previous / next workspace and follow it |
| Win+T | Tile cycle, like `gnome-window-tiler`: full → left half → right half → four quarters |
| Ctrl+Space | New terminal window |
| Ctrl+Shift+3 / 4 / 5 | Full screenshot / area screenshot / screen recording (Mac layout, Ctrl for Cmd) |
| Ctrl+Alt+4 / 5 | Area screenshot / active window to the clipboard |

Ctrl+1…0 override the same keys inside apps (for example browser tab switching), just as on GNOME.
Edit `%USERPROFILE%\linux-hotkeys\linux-hotkeys.ahk` to change them, then double-click it to reload.

## Workspace wallpapers without the rest

```powershell
powershell -ExecutionPolicy Bypass -File .\set-workspace-wallpapers.ps1                          # default set
powershell -ExecutionPolicy Bypass -File .\set-workspace-wallpapers.ps1 -ImageDir ~\Pictures\mine  # your own
```

Images go to desktops in alphabetical order; name them `01-…`, `02-…` to control it. The panoramic default set is
centre-cropped on 16:9 screens. To change a single desktop later, switch to it and use right-click → Personalize.

## Gaming

For competitive FPS games on a gaming laptop. Tested on an HP OMEN 16 (i7-13620H, RTX 4050 6 GB) with a
Samsung Odyssey G9 (5120×1440, 240 Hz) playing Battlefield 6.

### 1. Check the display path first

Double-click `3-game-tune.cmd`, or run `gaming\game-tune.ps1 -CheckOnly`. It reports:

- **Which GPU drives each monitor.** On Optimus laptops (no MUX set), a monitor on an iGPU-wired port
  runs through the Intel/AMD iGPU. Every frame is copied from the NVIDIA GPU (costing FPS and adding
  latency), and **G-Sync is impossible**: NVIDIA Control Panel won't even show the G-SYNC page.
  `nvidia-smi --query-gpu=display_attached --format=csv` should say `Yes`.
  - Try each USB-C/DP port: usually only one is wired to the dGPU.
  - Otherwise switch to discrete / dGPU-only mode (OMEN Gaming Hub → Graphics Switcher, MSI Center → GPU
    Switch, or the BIOS), then reboot.
  - HDMI is wired to the dGPU on many laptops, but check the monitor's HDMI version: the G9's HDMI 2.0
    input can't do 5120×1440 at 240 Hz.
- **What the monitor advertises (EDID).** If the maximum is below the panel's rated refresh, Windows can't
  offer the higher mode, and the fix is in the **monitor's OSD, not the PC**. Odyssey G9: *System →
  DisplayPort Ver → 1.4*, then *Game → Refresh Rate → 240 Hz*. With DP 1.2 it advertises 120 Hz max.
- **Power mode** (should be *Best performance* on AC) and the top CPU users.

### 2. Tune (each step asks Y/n)

Game DVR and background recording off; *Optimizations for windowed games* and Windows *variable refresh
rate* on; `-GameExe <path>` pins a game to the high-performance GPU; SysMain off; HP analytics services
off (OMEN's own service is kept); resident browser updaters removed from login (scheduled updates still run).

### 3. Launch through `play-game.ps1`

```powershell
powershell -ExecutionPolicy Bypass -File .\gaming\play-game.ps1 -SteamAppId 2807960 -Process bf6
```

Closes AutoHotkey (EA Javelin anti-cheat kicks Battlefield 6 while it runs), PowerToys, Command Palette,
OneDrive and Widgets, then restores them when the game quits. Close your browser yourself.

### Reading the Battlefield 6 performance overlay

*Minimal* shows no FPS number; it breaks the frame down instead. Each value is `fps / ms per frame`:

| Stat | Meaning |
|---|---|
| CPU | FPS the CPU could deliver. |
| GPU | FPS the GPU could deliver. At 5120×1440 on a 6 GB laptop GPU this is the bottleneck. |
| SIM | Simulation / server tick (30 in menus and Portal, 60 in matches). Not render speed. |
| MP/s | Megapixels per second. Throughput, not a bottleneck; red is fine. |

Your real FPS ≈ the lowest of CPU and GPU. If both sit at ~60 with low ms, something is capping you:
check VSync and the refresh-rate setting (both were stuck at *On* / *60 Hz* here). "Memory exceeded" in the
graphics menu means VRAM is full: use DLSS Performance before lowering textures.

## Claude Code on native Windows

Two steps, no WSL, no admin:

1. In PowerShell:

   ```powershell
   irm https://claude.ai/install.ps1 | iex
   ```

   From CMD instead: `curl -fsSL https://claude.ai/install.cmd -o install.cmd && install.cmd && del install.cmd`

2. Open a **new** terminal (so PATH is picked up), `cd` into your project, and run `claude`. A browser
   window opens to log in (needs a Pro, Max, Team, Enterprise or Console account; the free plan doesn't
   include Claude Code).

Check with `claude --version`; `claude doctor` diagnoses install problems. The native install updates itself.

- **Git for Windows** (installed by section 10, or `winget install Git.Git`) is optional. Without it,
  Claude Code runs commands in PowerShell; with it, it also gets a Bash tool via Git Bash.
- `winget install Anthropic.ClaudeCode` works too, but doesn't auto-update (`winget upgrade Anthropic.ClaudeCode`).
- If `claude` is "not recognized", the new terminal hasn't picked up PATH yet: open another one, or see
  [Troubleshoot installation](https://code.claude.com/docs/en/troubleshoot-install).

Source: [Claude Code setup docs](https://code.claude.com/docs/en/setup).

## Manual commands (no script)

Type each command as a single line in an admin PowerShell. If the prompt turns into `>>`, a quote was
mangled while pasting: press **Ctrl+C** and retype. These commands use no quotes, and they create
missing registry keys, which avoids the "cannot find path" error.

```powershell
net user BackupAdmin * /add
net localgroup Administrators BackupAdmin /add
New-Item -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -Force -ErrorAction SilentlyContinue | Out-Null; Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -Name NoConnectedUser -Type DWord -Value 3
New-Item -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement -Force -ErrorAction SilentlyContinue | Out-Null; Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement -Name ScoobeSystemSettingEnabled -Type DWord -Value 0
New-Item -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager -Force -ErrorAction SilentlyContinue | Out-Null; Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager -Name SubscribedContent-310093Enabled -Type DWord -Value 0
```

## If the account prompt still appears at sign-in

- Don't type an email address. Look for **Skip / Not now / Remind me later**, which is sometimes small text at the bottom of the screen.
- If there is no skip option, sign in as **BackupAdmin**.

## Recovery if you can't sign in

GRUB can't send Windows into Safe Mode, and F8 doesn't work on Windows 10/11.

- **From the Windows sign-in screen:** click the power icon, hold **Shift**, and click **Restart**. Then go to Troubleshoot → Advanced options → Startup Settings → Restart, and press **4**.
- **If you can't reach the sign-in screen:** force power-off at the Windows logo 3 times in a row. Windows opens Automatic Repair, and from there you follow the same path.
- **From Linux on the same machine** (only if the Windows drive is not BitLocker-encrypted). This enables the built-in Administrator account:

  ```bash
  sudo apt install chntpw
  lsblk -o NAME,SIZE,FSTYPE,LABEL          # find the ntfs partition
  sudo mkdir -p /mnt/win && sudo mount -t ntfs3 /dev/<ntfs-partition> /mnt/win
  sudo chntpw -u Administrator /mnt/win/Windows/System32/config/SAM
  ```

  In chntpw, press `2` (unlock and enable), then `q`, then `y`. If the mount fails because Windows
  is hibernated, boot Windows, shut down while holding **Shift**, and try again.

## Undo

- Run `undo-linuxify.cmd`, or use System Restore → "Before linuxify". Undo also stops the hotkeys and restores your old Windows Terminal settings; wallpapers stay until you change them.
- Removed apps come back from the Microsoft Store. winget tools uninstall with `winget uninstall <id>`.
- Delete the backup account with `net user BackupAdmin /delete`.

## Caveats

- `NoConnectedUser=3` may also block Microsoft account sign-in in the Store, OneDrive, and Xbox apps.
- On Home and Pro, `AllowTelemetry=0` is treated as "Required", which is the lowest level those editions allow.
- Microsoft renames or ignores some keys after feature updates. Each step reports `SKIP` with the reason instead of failing. Re-run after big updates; the scripts are safe to re-run.
- Why two PCs behave differently: edition (Home gets pushed harder), build, staged feature rollouts, region (EU/EEA gets fewer prompts), and how the PC was set up.

## Background

- [Microsoft blocked every Windows 11 account bypass except the most boring link on its own page](https://www.windowslatest.com/2026/09/13/microsoft-blocked-every-windows-11-account-bypass-except-the-most-boring-link-on-its-own-page/) (Windows Latest, Sep 2026)
- [Microsoft is killing the Microsoft account lock-in across products, Windows 11 may be next](https://www.windowslatest.com/2026/06/20/microsoft-is-killing-the-microsoft-account-lock-in-across-products-windows-11-may-be-next/) (Windows Latest, Jun 2026)
- [Windows 11 forced updates and local accounts](https://learn.microsoft.com/en-us/answers/questions/5812465/windows-11-forced-updates-and-local-accounts) (Microsoft Q&A)

## License

MIT, see [LICENSE](LICENSE). No warranty. These scripts change system settings, so make a restore point first (section 0 offers one).

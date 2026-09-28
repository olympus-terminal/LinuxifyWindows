# LinuxifyWindows

Scripts for Linux users who have to live with a Windows 11 machine. They keep your **local account**,
stop Microsoft's account sign-up pushing and ads, and make Windows work more like Linux: a
bash-style shell, CLI tools, cleaner Explorer and taskbar defaults, and fixes for dual-booting with GRUB.

Plain PowerShell, no dependencies, every section opt-in, everything logged and reversible.

**Tested on:** Windows 11 Home 24H2. Ran cleanly with no `SKIP` lines in the log.
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
| `2-linuxify.cmd` → `linuxify.ps1` | Interactive customizer: 13 sections, each asks Y/n first. Logs to `%USERPROFILE%\linuxify.log`. |
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
| 12 | WSL | `wsl --install -d Ubuntu`. Needs a reboot. |

**Never touched:** Windows Defender, Windows Update, firewall.

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

- Run `undo-linuxify.cmd`, or use System Restore → "Before linuxify".
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

# linuxify.ps1
# Make Windows 11 quieter and more Linux-like: block Microsoft account recruiting, ads, "suggestions",
# telemetry extras, Bing/Copilot/Recall/Widgets; Explorer + taskbar tweaks; dual-boot fixes;
# Linux-style shell and CLI tools; GNOME-style translucent terminal, workspace hotkeys and wallpapers.
#
# Run from an ADMIN PowerShell, signed in to the account you want customized:
#   powershell -ExecutionPolicy Bypass -File .\linuxify.ps1
#
# Every section asks Y/n first. Safe to re-run.
# Deliberately NOT touched: Windows Defender, Windows Update, firewall (security).

#Requires -RunAsAdministrator

$Log = Join-Path $HOME 'linuxify.log'
"=== linuxify run $(Get-Date -Format s) ===" | Out-File $Log -Append

function Ask($Question) {
    $a = Read-Host "$Question [Y/n]"
    return ($a -eq '' -or $a -match '^[Yy]')
}

function Set-Reg($Path, $Name, $Value, $Type = 'DWord') {
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force -ErrorAction Stop | Out-Null }
        if ($Name -eq '(default)') {
            Set-Item -Path $Path -Value $Value -ErrorAction Stop
        } else {
            New-ItemProperty -Path $Path -Name $Name -PropertyType $Type -Value $Value -Force -ErrorAction Stop | Out-Null
        }
        "  ok    $Path\$Name = $Value" | Tee-Object -FilePath $Log -Append | Write-Host
    } catch {
        "  SKIP  $Path\$Name ($($_.Exception.Message))" | Tee-Object -FilePath $Log -Append | Write-Host -ForegroundColor Yellow
    }
}

$CDM  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
$ADV  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$SYS  = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'

# ---------------------------------------------------------------- 0. restore point
Write-Host "`n== 0. System restore point ==" -ForegroundColor Cyan
if (Ask 'Create a restore point first (recommended)?') {
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description 'Before linuxify' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Write-Host '  restore point created'
    } catch {
        Write-Host "  could not create restore point: $($_.Exception.Message)" -ForegroundColor Yellow
        if (-not (Ask 'Continue anyway?')) { exit 1 }
    }
}

# ---------------------------------------------------------------- 1. account recruiting
Write-Host "`n== 1. Block Microsoft account recruiting ==" -ForegroundColor Cyan
if (Ask 'Block Microsoft accounts and all "finish setting up / sign in" nags?') {
    # "Accounts: Block Microsoft accounts" -> 3 = can't add or log on with Microsoft accounts
    Set-Reg $SYS 'NoConnectedUser' 3
    # "Let's finish setting up your device" (SCOOBE)
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' 'ScoobeSystemSettingEnabled' 0
    # Windows welcome experience after updates
    Set-Reg $CDM 'SubscribedContent-310093Enabled' 0
    # Account-related notifications in Start ("sign in", "back up your PC")
    Set-Reg $ADV 'Start_AccountNotifications' 0
    # Cloud consumer account state content (account nags in File Explorer/Settings)
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableConsumerAccountStateContent' 1
}

# ---------------------------------------------------------------- 2. ads, suggestions, silent installs
Write-Host "`n== 2. Ads, suggestions, silently installed apps ==" -ForegroundColor Cyan
if (Ask 'Turn off ads, tips, suggestions, and auto-installed promo apps?') {
    Set-Reg $CDM 'SystemPaneSuggestionsEnabled' 0          # Start suggestions
    Set-Reg $CDM 'SubscribedContent-338388Enabled' 0       # Start suggestions
    Set-Reg $CDM 'SubscribedContent-338389Enabled' 0       # tips and tricks
    Set-Reg $CDM 'SubscribedContent-338393Enabled' 0       # Settings suggested content
    Set-Reg $CDM 'SubscribedContent-353694Enabled' 0       # Settings suggested content
    Set-Reg $CDM 'SubscribedContent-353696Enabled' 0       # Settings suggested content
    Set-Reg $CDM 'SubscribedContent-338387Enabled' 0       # lock screen "fun facts"
    Set-Reg $CDM 'RotatingLockScreenOverlayEnabled' 0
    Set-Reg $CDM 'SoftLandingEnabled' 0
    Set-Reg $CDM 'SilentInstalledAppsEnabled' 0            # stop auto-installing promo apps
    Set-Reg $CDM 'PreInstalledAppsEnabled' 0
    Set-Reg $CDM 'OemPreInstalledAppsEnabled' 0
    Set-Reg $ADV 'Start_IrisRecommendations' 0             # Start "Recommended" promos
    Set-Reg $ADV 'ShowSyncProviderNotifications' 0         # OneDrive ads in Explorer
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' 0
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableSoftLanding' 1
}

# ---------------------------------------------------------------- 3. telemetry
Write-Host "`n== 3. Telemetry ==" -ForegroundColor Cyan
if (Ask 'Reduce telemetry to the minimum this edition allows?') {
    # 0 = Security (Enterprise/Edu); Home/Pro treat it as 1 = Required
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 0
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'DoNotShowFeedbackNotifications' 1
    Set-Reg 'HKCU:\Software\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod' 0   # feedback prompts
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'PublishUserActivities' 0  # activity history
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'UploadUserActivities' 0
}

# ---------------------------------------------------------------- 4. Bing, Copilot, Recall, Widgets
Write-Host "`n== 4. Bing search, Copilot, Recall, Widgets ==" -ForegroundColor Cyan
if (Ask 'Disable web/Bing results in Start search, Copilot, Recall, and Widgets?') {
    Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled' 0
    Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
    Set-Reg $ADV 'ShowCopilotButton' 0
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' 1   # Recall snapshots
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0                  # Widgets
    # Copilot is also a Store app on newer builds; remove it for this user
    Get-AppxPackage -Name 'Microsoft.Copilot' -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------- 5. OneDrive
Write-Host "`n== 5. OneDrive ==" -ForegroundColor Cyan
if (Ask 'Disable OneDrive entirely? (say n if you use it)') {
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' 'DisableFileSyncNGSC' 1
    Get-Process OneDrive -ErrorAction SilentlyContinue | Stop-Process -Force
}

# ---------------------------------------------------------------- 6. bloat apps
Write-Host "`n== 6. Preinstalled consumer apps ==" -ForegroundColor Cyan
$Bloat = @(
    'Microsoft.BingNews', 'Microsoft.BingWeather', 'Microsoft.BingSearch', 'Microsoft.GetHelp',
    'Microsoft.Getstarted', 'Microsoft.MicrosoftSolitaireCollection', 'Microsoft.People',
    'Microsoft.WindowsFeedbackHub', 'Microsoft.Todos', 'Microsoft.PowerAutomateDesktop',
    'Clipchamp.Clipchamp', 'MicrosoftTeams', 'MSTeams', 'Microsoft.MicrosoftOfficeHub',
    'Microsoft.549981C3F5F10', 'Microsoft.YourPhone', 'Microsoft.WindowsMaps', 'Microsoft.ZuneVideo'
)
Write-Host "  Candidates: $($Bloat -join ', ')"
if (Ask 'Uninstall these for this user? (reinstallable from the Store)') {
    foreach ($app in $Bloat) {
        $pkg = Get-AppxPackage -Name $app -ErrorAction SilentlyContinue
        if ($pkg) {
            try { $pkg | Remove-AppxPackage -ErrorAction Stop; "  removed $app" | Tee-Object -FilePath $Log -Append | Write-Host }
            catch { "  SKIP  $app ($($_.Exception.Message))" | Tee-Object -FilePath $Log -Append | Write-Host -ForegroundColor Yellow }
        }
    }
}

# ---------------------------------------------------------------- 7. Explorer, taskbar, look
Write-Host "`n== 7. Explorer / taskbar / theme ==" -ForegroundColor Cyan
if (Ask 'Linux-ish desktop: file extensions, hidden files, classic right-click menu, left taskbar, dark mode?') {
    Set-Reg $ADV 'HideFileExt' 0                  # show .ext
    Set-Reg $ADV 'Hidden' 1                       # show hidden files
    Set-Reg $ADV 'LaunchTo' 1                     # Explorer opens "This PC", not Home/recents
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState' 'FullPath' 1
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer' 'ShowRecent' 0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer' 'ShowFrequent' 0
    # classic full right-click menu (no "Show more options")
    Set-Reg 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32' '(default)' '' 'String'
    Set-Reg $ADV 'TaskbarAl' 0                    # taskbar icons left-aligned
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'SearchboxTaskbarMode' 0
    Set-Reg $ADV 'ShowTaskViewButton' 0
    Set-Reg $ADV 'TaskbarMn' 0                    # Chat/Teams button
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'AppsUseLightTheme' 0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'SystemUsesLightTheme' 0
}

# ---------------------------------------------------------------- 8. dual boot
Write-Host "`n== 8. Dual-boot fixes (GRUB + Linux) ==" -ForegroundColor Cyan
if (Ask 'Disable Fast Startup and store hardware clock in UTC like Linux?') {
    # Fast Startup leaves NTFS hibernated -> Linux can't mount it read-write
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled' 0
    # stops the clock jumping by hours after switching between Linux and Windows
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation' 'RealTimeIsUniversal' 1
}

# ---------------------------------------------------------------- 9. developer basics
Write-Host "`n== 9. Developer basics ==" -ForegroundColor Cyan
if (Ask 'Long paths, symlinks without admin (Developer Mode), built-in sudo, allow local scripts?') {
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' 'LongPathsEnabled' 1
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' 'AllowDevelopmentWithoutDevLicense' 1
    Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
    if (Get-Command sudo.exe -ErrorAction SilentlyContinue) {
        sudo.exe config --enable normal   # Windows 11 24H2+ built-in sudo
    } else {
        Write-Host '  built-in sudo not available on this build (needs 24H2+)'
    }
}

# ---------------------------------------------------------------- 10. CLI tools
Write-Host "`n== 10. Linux-style tools via winget ==" -ForegroundColor Cyan
$Tools = [ordered]@{
    'Microsoft.PowerShell'      = 'PowerShell 7'
    'Git.Git'                   = 'git + Git Bash (bash, ssh, coreutils)'
    'uutils.coreutils'          = 'GNU-style coreutils (ls, cat, cp, ...)'
    'Neovim.Neovim'             = 'neovim'
    'BurntSushi.ripgrep.MSVC'   = 'ripgrep (rg)'
    'sharkdp.fd'                = 'fd (find)'
    'junegunn.fzf'              = 'fzf'
    'sharkdp.bat'               = 'bat (cat with colors)'
    'ajeetdsouza.zoxide'        = 'zoxide (z / smart cd)'
    '7zip.7zip'                 = '7-Zip'
    'Microsoft.PowerToys'       = 'PowerToys (FancyZones tiling, Run launcher like rofi)'
}
if (Get-Command winget -ErrorAction SilentlyContinue) {
    $Tools.GetEnumerator() | ForEach-Object { Write-Host ("  {0,-26} {1}" -f $_.Key, $_.Value) }
    if (Ask 'Install these?') {
        foreach ($id in $Tools.Keys) {
            Write-Host "  installing $id ..."
            winget install --id $id --exact --silent --accept-source-agreements --accept-package-agreements | Out-Null
            "  winget $id exit=$LASTEXITCODE" | Tee-Object -FilePath $Log -Append | Write-Host
        }
    }
} else {
    Write-Host '  winget not found: install "App Installer" from the Microsoft Store, then re-run' -ForegroundColor Yellow
}

# ---------------------------------------------------------------- 11. shell profile
Write-Host "`n== 11. Bash-like PowerShell profile ==" -ForegroundColor Cyan
if (Ask 'Add bash-style keys (Ctrl+A/E/R/W), Tab menu-complete, which/touch/ll/grep aliases, zoxide?') {
    $Begin = '# >>> linuxify >>>'
    $End   = '# <<< linuxify <<<'
    $Block = @'
# >>> linuxify >>>
Set-PSReadLineOption -EditMode Emacs
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
try { Set-PSReadLineOption -PredictionSource History -ErrorAction Stop } catch {}
function which { param($Name) (Get-Command $Name -ErrorAction SilentlyContinue).Source }
function touch { foreach ($f in $args) { if (Test-Path $f) { (Get-Item $f).LastWriteTime = Get-Date } else { New-Item -ItemType File -Path $f | Out-Null } } }
function ll { Get-ChildItem -Force @args }
if (Get-Command rg -ErrorAction SilentlyContinue)   { Set-Alias grep rg }
if (Get-Command nvim -ErrorAction SilentlyContinue) { Set-Alias vim nvim; Set-Alias vi nvim }
if (Get-Command zoxide -ErrorAction SilentlyContinue) { Invoke-Expression (& { (zoxide init powershell | Out-String) }) }
# <<< linuxify <<<
'@
    $Docs = [Environment]::GetFolderPath('MyDocuments')
    foreach ($p in @("$Docs\WindowsPowerShell\profile.ps1", "$Docs\PowerShell\profile.ps1")) {
        $dir = Split-Path $p
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $old = if (Test-Path $p) { Get-Content $p -Raw } else { '' }
        if ($null -eq $old) { $old = '' }
        $pattern = [regex]::Escape($Begin) + '[\s\S]*?' + [regex]::Escape($End) + '\r?\n?'
        $new = ([regex]::Replace($old, $pattern, '')).TrimEnd() + "`r`n" + $Block
        Set-Content -Path $p -Value $new.TrimStart() -Encoding UTF8
        "  profile updated: $p" | Tee-Object -FilePath $Log -Append | Write-Host
    }
}

# ---------------------------------------------------------------- 12. WSL
Write-Host "`n== 12. WSL (real Linux inside Windows) ==" -ForegroundColor Cyan
if (Ask 'Install WSL with Ubuntu? (large download, needs a reboot)') {
    wsl.exe --install -d Ubuntu
}

# ---------------------------------------------------------------- 13. terminal look
Write-Host "`n== 13. Translucent terminal (ghost_terminal look) ==" -ForegroundColor Cyan
if (Ask 'Windows Terminal: black background at 58% opacity, green #96D5A2 text, Linux console colors, 96x42?') {
    # Same values as olympus-terminal/ghost_terminal's GNOME profile. The old file is kept as
    # settings.json.linuxify-bak; undo-linuxify restores it.
    $WtDir = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
    $WtFile = Join-Path $WtDir 'settings.json'
    try {
        if (-not (Test-Path $WtDir)) { throw 'Windows Terminal not found (install it from the Store)' }
        if (Test-Path $WtFile) {
            if (-not (Test-Path "$WtFile.linuxify-bak")) { Copy-Item $WtFile "$WtFile.linuxify-bak" }
            $wt = Get-Content $WtFile -Raw | ConvertFrom-Json
        } else {
            $wt = [pscustomobject]@{ profiles = [pscustomobject]@{ defaults = [pscustomobject]@{}; list = @() } }
        }
        $scheme = [pscustomobject][ordered]@{
            name = 'Ghost Terminal'; background = '#000000'; foreground = '#96D5A2'; cursorColor = '#96D5A2'
            selectionBackground = '#555555'
            black = '#000000'; red = '#AA0000'; green = '#00AA00'; yellow = '#AA5500'
            blue = '#0000AA'; purple = '#AA00AA'; cyan = '#00AAAA'; white = '#AAAAAA'
            brightBlack = '#555555'; brightRed = '#FF5555'; brightGreen = '#55FF55'; brightYellow = '#FFFF55'
            brightBlue = '#5555FF'; brightPurple = '#FF55FF'; brightCyan = '#55FFFF'; brightWhite = '#FFFFFF'
        }
        $schemes = @($wt.schemes | Where-Object { $_ -and $_.name -ne 'Ghost Terminal' }) + $scheme
        $wt | Add-Member -Force NoteProperty schemes $schemes
        $wt | Add-Member -Force NoteProperty initialCols 96
        $wt | Add-Member -Force NoteProperty initialRows 42
        if (-not $wt.profiles.defaults) { $wt.profiles | Add-Member -Force NoteProperty defaults ([pscustomobject]@{}) }
        $d = $wt.profiles.defaults
        $d | Add-Member -Force NoteProperty colorScheme 'Ghost Terminal'
        $d | Add-Member -Force NoteProperty opacity 58
        $d | Add-Member -Force NoteProperty useAcrylic $false   # GNOME-style: see-through, no blur
        $d | Add-Member -Force NoteProperty font ([pscustomobject]@{ size = 13 })
        # Ctrl+PgUp / Ctrl+PgDn switch tabs, as in GNOME Terminal
        $keys = @($wt.keybindings | Where-Object { $_ -and $_.keys -notin 'ctrl+pgup', 'ctrl+pgdn' }) +
                [pscustomobject]@{ id = 'Terminal.PrevTab'; keys = 'ctrl+pgup' } +
                [pscustomobject]@{ id = 'Terminal.NextTab'; keys = 'ctrl+pgdn' }
        $wt | Add-Member -Force NoteProperty keybindings $keys
        $wt | ConvertTo-Json -Depth 20 | Set-Content $WtFile -Encoding UTF8
        "  ok    Windows Terminal settings: $WtFile" | Tee-Object -FilePath $Log -Append | Write-Host
    } catch {
        "  SKIP  Windows Terminal ($($_.Exception.Message))" | Tee-Object -FilePath $Log -Append | Write-Host -ForegroundColor Yellow
    }
}

# ---------------------------------------------------------------- 14. workspace hotkeys
Write-Host "`n== 14. GNOME workspace hotkeys (AutoHotkey) ==" -ForegroundColor Cyan
Write-Host '  10 fixed desktops; Ctrl+1..0 switch, Ctrl+Shift+Left/Right prev/next, Ctrl+Shift+Alt+Left/Right'
Write-Host '  move window, Win+T tile cycle, Ctrl+Space terminal, Ctrl+Shift+3/4/5 screenshots'
if (Ask 'Install AutoHotkey v2 + VirtualDesktopAccessor and start the hotkeys at login?') {
    $HkDir = Join-Path $HOME 'linux-hotkeys'
    $HkSrc = Join-Path $PSScriptRoot 'hotkeys\linux-hotkeys.ahk'
    try {
        if (-not (Test-Path $HkSrc)) { throw "$HkSrc missing (run from the repo folder)" }
        New-Item -ItemType Directory -Force $HkDir | Out-Null
        Copy-Item $HkSrc $HkDir -Force

        $ahk = @("$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe",
                 "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $ahk) {
            if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw 'winget not found; install AutoHotkey v2 manually' }
            Write-Host '  installing AutoHotkey v2 ...'
            winget install --id AutoHotkey.AutoHotkey --exact --silent --accept-source-agreements --accept-package-agreements | Out-Null
            $ahk = @("$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe",
                     "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
            if (-not $ahk) { throw 'AutoHotkey64.exe not found after install' }
        }

        # Ciantic/VirtualDesktopAccessor (MIT): Windows 11 24H2+ build of the desktop-switching DLL
        $Dll = Join-Path $HkDir 'VirtualDesktopAccessor.dll'
        if (-not (Test-Path $Dll)) {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest 'https://github.com/Ciantic/VirtualDesktopAccessor/releases/download/2024-12-16-windows11/VirtualDesktopAccessor.dll' -OutFile $Dll -UseBasicParsing
        }

        $Lnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'linux-hotkeys.lnk'
        $sc = (New-Object -ComObject WScript.Shell).CreateShortcut($Lnk)
        $sc.TargetPath = $ahk
        $sc.Arguments = "`"$HkDir\linux-hotkeys.ahk`""
        $sc.WorkingDirectory = $HkDir
        $sc.Save()

        # Start it now through Explorer so it runs un-elevated, as it will at login
        Get-CimInstance Win32_Process -Filter "Name like 'AutoHotkey%'" |
            Where-Object CommandLine -match 'linux-hotkeys\.ahk' | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
        Start-Process explorer.exe "`"$Lnk`""
        "  ok    hotkeys: $HkDir (starts at login via $Lnk)" | Tee-Object -FilePath $Log -Append | Write-Host
    } catch {
        "  SKIP  hotkeys ($($_.Exception.Message))" | Tee-Object -FilePath $Log -Append | Write-Host -ForegroundColor Yellow
    }
}

# ---------------------------------------------------------------- 15. workspace wallpapers
Write-Host "`n== 15. One wallpaper per workspace ==" -ForegroundColor Cyan
if (Ask 'Download the dark sci-fi set (~120 MB) and give each desktop its own wallpaper?') {
    try {
        # The hotkeys script creates the 10 desktops; give it a moment if it was just started
        Start-Sleep -Seconds 3
        & (Join-Path $PSScriptRoot 'set-workspace-wallpapers.ps1')
        "  ok    workspace wallpapers" | Tee-Object -FilePath $Log -Append | Write-Host
    } catch {
        "  SKIP  wallpapers ($($_.Exception.Message))" | Tee-Object -FilePath $Log -Append | Write-Host -ForegroundColor Yellow
    }
}

# ---------------------------------------------------------------- done
Write-Host "`n== Done ==" -ForegroundColor Green
Write-Host "Log: $Log"
if (Ask 'Restart Explorer now to apply desktop changes?') {
    Stop-Process -Name explorer -Force
}
Write-Host 'Some changes (policies, Fast Startup, WSL) need a full restart.'

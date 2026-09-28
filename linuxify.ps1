# linuxify.ps1
# Make Windows 11 quieter and more Linux-like: block Microsoft account recruiting, ads, "suggestions",
# telemetry extras, Bing/Copilot/Recall/Widgets; Explorer + taskbar tweaks; dual-boot fixes;
# Linux-style shell and CLI tools.
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

# ---------------------------------------------------------------- done
Write-Host "`n== Done ==" -ForegroundColor Green
Write-Host "Log: $Log"
if (Ask 'Restart Explorer now to apply desktop changes?') {
    Stop-Process -Name explorer -Force
}
Write-Host 'Some changes (policies, Fast Startup, WSL) need a full restart.'

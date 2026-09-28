# undo-linuxify.ps1
# Reverts the registry changes made by linuxify.ps1 and keep-local-account.ps1 back to Windows defaults.
# Does NOT reinstall removed apps (use the Microsoft Store), uninstall winget tools,
# or delete the BackupAdmin account (net user BackupAdmin /delete).
#   powershell -ExecutionPolicy Bypass -File .\undo-linuxify.ps1
# Alternative: System Restore -> "Before linuxify" restore point.

#Requires -RunAsAdministrator

$CDM = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
$ADV = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'

# Deleting a value restores the Windows default
$Remove = @(
    @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System', 'NoConnectedUser'),
    @('HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement', 'ScoobeSystemSettingEnabled'),
    @($CDM, 'SubscribedContent-310093Enabled'),
    @($CDM, 'SystemPaneSuggestionsEnabled'),
    @($CDM, 'SubscribedContent-338388Enabled'),
    @($CDM, 'SubscribedContent-338389Enabled'),
    @($CDM, 'SubscribedContent-338393Enabled'),
    @($CDM, 'SubscribedContent-353694Enabled'),
    @($CDM, 'SubscribedContent-353696Enabled'),
    @($CDM, 'SubscribedContent-338387Enabled'),
    @($CDM, 'RotatingLockScreenOverlayEnabled'),
    @($CDM, 'SoftLandingEnabled'),
    @($CDM, 'SilentInstalledAppsEnabled'),
    @($CDM, 'PreInstalledAppsEnabled'),
    @($CDM, 'OemPreInstalledAppsEnabled'),
    @($ADV, 'Start_AccountNotifications'),
    @($ADV, 'Start_IrisRecommendations'),
    @($ADV, 'ShowSyncProviderNotifications'),
    @($ADV, 'ShowCopilotButton'),
    @($ADV, 'HideFileExt'),
    @($ADV, 'Hidden'),
    @($ADV, 'LaunchTo'),
    @($ADV, 'TaskbarAl'),
    @($ADV, 'ShowTaskViewButton'),
    @($ADV, 'TaskbarMn'),
    @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState', 'FullPath'),
    @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer', 'ShowRecent'),
    @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer', 'ShowFrequent'),
    @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Search', 'SearchboxTaskbarMode'),
    @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Search', 'BingSearchEnabled'),
    @('HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo', 'Enabled'),
    @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy', 'TailoredExperiencesWithDiagnosticDataEnabled'),
    @('HKCU:\Software\Microsoft\Siuf\Rules', 'NumberOfSIUFInPeriod'),
    @('HKCU:\Software\Policies\Microsoft\Windows\Explorer', 'DisableSearchBoxSuggestions'),
    @('HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot', 'TurnOffWindowsCopilot'),
    @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot', 'TurnOffWindowsCopilot'),
    @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI', 'DisableAIDataAnalysis'),
    @('HKLM:\SOFTWARE\Policies\Microsoft\Dsh', 'AllowNewsAndInterests'),
    @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent', 'DisableConsumerAccountStateContent'),
    @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent', 'DisableWindowsConsumerFeatures'),
    @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent', 'DisableSoftLanding'),
    @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection', 'AllowTelemetry'),
    @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection', 'DoNotShowFeedbackNotifications'),
    @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\System', 'PublishUserActivities'),
    @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\System', 'UploadUserActivities'),
    @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive', 'DisableFileSyncNGSC'),
    @('HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation', 'RealTimeIsUniversal')
)

foreach ($r in $Remove) {
    if (Get-ItemProperty -Path $r[0] -Name $r[1] -ErrorAction SilentlyContinue) {
        Remove-ItemProperty -Path $r[0] -Name $r[1] -ErrorAction SilentlyContinue
        Write-Host "  reset $($r[0])\$($r[1])"
    }
}

# Values whose default is 1 rather than "absent"
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name HiberbootEnabled -PropertyType DWord -Value 1 -Force | Out-Null
New-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name AppsUseLightTheme -PropertyType DWord -Value 1 -Force | Out-Null
New-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name SystemUsesLightTheme -PropertyType DWord -Value 1 -Force | Out-Null
Write-Host '  Fast Startup on, light theme on'

# Windows 11 right-click menu
Remove-Item -Path 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}' -Recurse -Force -ErrorAction SilentlyContinue
Write-Host '  Windows 11 right-click menu restored'

# Profile block
$Docs = [Environment]::GetFolderPath('MyDocuments')
foreach ($p in @("$Docs\WindowsPowerShell\profile.ps1", "$Docs\PowerShell\profile.ps1")) {
    if (Test-Path $p) {
        $old = Get-Content $p -Raw
        $new = [regex]::Replace($old, '# >>> linuxify >>>[\s\S]*?# <<< linuxify <<<\r?\n?', '')
        Set-Content -Path $p -Value $new -Encoding UTF8
        Write-Host "  linuxify block removed from $p"
    }
}

# Workspace hotkeys (AutoHotkey itself stays installed: winget uninstall AutoHotkey.AutoHotkey)
Get-CimInstance Win32_Process -Filter "Name like 'AutoHotkey%'" |
    Where-Object CommandLine -match 'linux-hotkeys\.ahk' | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
$Lnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'linux-hotkeys.lnk'
if (Test-Path $Lnk) { Remove-Item $Lnk -Force; Write-Host '  workspace hotkeys stopped and removed from startup' }

# Windows Terminal settings from before linuxify
$WtFile = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (Test-Path "$WtFile.linuxify-bak") {
    Move-Item "$WtFile.linuxify-bak" $WtFile -Force
    Write-Host '  Windows Terminal settings restored'
}

Write-Host "`nDone. Restart Windows to apply everything."
Write-Host 'Workspace wallpapers are left as they are; change them in Settings > Personalization > Background.'

# game-tune.ps1 - check a gaming laptop's display path and trim background load for competitive FPS games.
# Run as admin. Prints a report first, then asks Y/n for each change. Logs to %USERPROFILE%\game-tune.log.
#   -CheckOnly        report only, change nothing
#   -GameExe <path>   also pin this game to the high-performance GPU (repeatable: -GameExe a.exe,b.exe)
param([switch]$CheckOnly, [string[]]$GameExe)

$Log = Join-Path $HOME 'game-tune.log'
"=== game-tune run $(Get-Date -Format s) ===" | Out-File $Log -Append
function Say($Text, $Color = 'Gray') { $Text | Tee-Object -FilePath $Log -Append | Write-Host -ForegroundColor $Color }
function Ask($Question) { (Read-Host "$Question [Y/n]") -notmatch '^[nN]' }

# ---------------------------------------------------------------- report
Say "`n== Display path ==" Cyan

# Which GPU scans out each monitor. On Optimus laptops a monitor on an iGPU-wired port costs FPS
# (every frame is copied dGPU -> iGPU) and rules out G-Sync.
Get-CimInstance Win32_VideoController | ForEach-Object {
    $mode = if ($_.CurrentHorizontalResolution) { "$($_.CurrentHorizontalResolution)x$($_.CurrentVerticalResolution) @ $($_.CurrentRefreshRate) Hz" } else { '(no display attached)' }
    Say ("  {0,-40} {1}" -f $_.Name, $mode)
}
$smi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
if ($smi) {
    $attached = (& nvidia-smi --query-gpu=display_attached --format=csv,noheader 2>$null) -join ''
    if ($attached -match 'Yes') { Say "  NVIDIA GPU drives a display: G-Sync possible, no copy overhead." Green }
    else { Say "  NVIDIA GPU drives NO display: monitor is on an iGPU-wired port. Try another port or the MUX / discrete-GPU mode (see README)." Yellow }
}

# What each monitor advertises (EDID). If the max here is below the panel's rated refresh, the limit is the
# monitor's own OSD (e.g. Samsung G9: DisplayPort Ver 1.2 caps it at 120 Hz), not the PC or cable.
$active = Get-CimInstance -Namespace root\wmi WmiMonitorID -ErrorAction SilentlyContinue
foreach ($mon in $active) {
    $name = ($mon.UserFriendlyName | Where-Object { $_ } | ForEach-Object { [char]$_ }) -join ''
    $inst = $mon.InstanceName -replace '_0$', ''
    $edid = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Enum\$inst\Device Parameters" -ErrorAction SilentlyContinue).EDID
    if (-not $edid) { continue }
    $range = $null
    for ($o = 54; $o -le 108; $o += 18) { if ($edid[$o] -eq 0 -and $edid[$o + 3] -eq 0xFD) { $range = "$($edid[$o + 5])-$($edid[$o + 6]) Hz" } }
    $vrr = (($edid | ForEach-Object { $_.ToString('X2') }) -join '') -match '1A0000'
    Say "  Monitor $name advertises: $range$(if ($vrr) { ', Adaptive-Sync/FreeSync' })"
}

Say "`n== Power ==" Cyan
$ps = Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes -ErrorAction SilentlyContinue
$best = 'ded574b5-45a0-4f42-8737-46345c09c238'
Say "  Power mode on AC: $(if ($ps.ActiveOverlayAcPowerScheme -eq $best) { 'Best performance' } else { 'NOT Best performance (Settings > System > Power)' })"

Say "`n== Background load ==" Cyan
Get-Process | Where-Object { $_.CPU } | Sort-Object CPU -Descending | Select-Object -First 12 |
    ForEach-Object { Say ("  {0,-34} {1,8:N0} s CPU {2,6:N0} MB" -f $_.Name, $_.CPU, ($_.WorkingSet64 / 1MB)) }

if ($CheckOnly) { Say "`nCheck only, nothing changed. Log: $Log"; return }

# ---------------------------------------------------------------- changes
function Set-Reg($Path, $Name, $Value, $Type = 'DWord') {
    try {
        if (-not (Test-Path $Path)) { New-Item $Path -Force | Out-Null }
        Set-ItemProperty $Path $Name $Value -Type $Type -ErrorAction Stop
        Say "  ok    $Path\$Name = $Value"
    } catch { Say "  SKIP  $Path\$Name ($($_.Exception.Message))" Yellow }
}
function Disable-Svc($Name) {
    $s = Get-Service $Name -ErrorAction SilentlyContinue
    if (-not $s) { return }
    try { Stop-Service $Name -Force -ErrorAction SilentlyContinue; Set-Service $Name -StartupType Disabled -ErrorAction Stop; Say "  ok    service $Name disabled" }
    catch { Say "  SKIP  service $Name ($($_.Exception.Message))" Yellow }
}

Write-Host ''
if (Ask 'Turn off Game DVR / background recording?') {
    Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'HistoricalCaptureEnabled' 0
}

if (Ask 'Turn on "Optimizations for windowed games" and Windows variable refresh rate?') {
    $k = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
    $cur = (Get-ItemProperty $k -ErrorAction SilentlyContinue).DirectXUserGlobalSettings
    $kv = [ordered]@{}
    if ($cur) { foreach ($p in $cur.Split(';') | Where-Object { $_ }) { $n, $v = $p.Split('=', 2); $kv[$n] = $v } }
    $kv['SwapEffectUpgradeEnable'] = '1'; $kv['VRROptimizeEnable'] = '1'
    Set-Reg $k 'DirectXUserGlobalSettings' ((($kv.Keys | ForEach-Object { "$_=$($kv[$_])" }) -join ';') + ';') 'String'
}

foreach ($exe in $GameExe) {
    if (Test-Path $exe) { Set-Reg 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences' (Resolve-Path $exe).Path 'GpuPreference=2;' 'String' }
    else { Say "  SKIP  $exe (not found)" Yellow }
}

if (Ask 'Disable SysMain (Superfetch)? Safe on SSD machines with 16 GB+ RAM') { Disable-Svc 'SysMain' }

# HP analytics services (verified on an OMEN 16). Only ones that exist are touched; HPOmenCap is left
# alone so OMEN Gaming Hub keeps working. Other brands: add their telemetry service names here.
$oem = 'HpTouchpointAnalyticsService', 'HPDiagsCap', 'HPNetworkCap', 'HPSysInfoCap', 'HPAppHelperCap'
$present = $oem | Where-Object { Get-Service $_ -ErrorAction SilentlyContinue }
if ($present -and (Ask "Disable OEM telemetry services ($($present -join ', '))?")) { $present | ForEach-Object { Disable-Svc $_ } }

# Brave/Chrome-style updaters that stay resident after the browser closes. The scheduled update
# task still runs, so the browser keeps getting security updates.
$run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$updaters = (Get-ItemProperty $run -ErrorAction SilentlyContinue).PSObject.Properties | Where-Object { $_.Name -match 'Brave.*Update|Google.*Update|Edge.*Update' }
if ($updaters -and (Ask "Stop resident browser updaters at login ($($updaters.Name -join ', '))? Scheduled updates keep running")) {
    foreach ($u in $updaters) { Remove-ItemProperty $run $u.Name; Say "  ok    removed Run\$($u.Name)" }
    Get-ScheduledTask | Where-Object { $_.TaskName -match 'BraveSoftwareUpdateTask.*Core' } | Disable-ScheduledTask | Out-Null
    Get-Process BraveUpdate -ErrorAction SilentlyContinue | Stop-Process -Force
}

Say "`nDone. Log: $Log" Green

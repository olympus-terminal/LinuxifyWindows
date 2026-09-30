# play-game.ps1 - launch a Steam game with background apps (and AutoHotkey) closed, restore them on exit.
# Kernel anti-cheats (EA Javelin, Vanguard, ...) can kick or block the game while AutoHotkey runs.
#   powershell -ExecutionPolicy Bypass -File play-game.ps1 -SteamAppId 2807960 -Process bf6
#   -AttachOnly   the game is already running: close apps now, restore when it exits
param([Parameter(Mandatory)][string]$Process, [string]$SteamAppId, [switch]$AttachOnly)

$ahkExe    = "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"
$ahkScript = "$env:USERPROFILE\linux-hotkeys\linux-hotkeys.ahk"

# Closed for the session; relaunched afterwards via explorer so they run unelevated.
$pauseApps = @(
    @{ Match = 'PowerToys*', 'Microsoft.CmdPal*'; Relaunch = "$env:LOCALAPPDATA\PowerToys\PowerToys.exe" }
    @{ Match = 'OneDrive*';                       Relaunch = "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe" }
    @{ Match = 'Widgets', 'WidgetBoard', 'WidgetService', 'MicrosoftStartFeedProvider'; Relaunch = $null }
)

$ahkWasRunning = [bool](Get-Process AutoHotkey* -ErrorAction SilentlyContinue)
Get-Process AutoHotkey* -ErrorAction SilentlyContinue | Stop-Process -Force

$toRestore = @()
foreach ($app in $pauseApps) {
    $procs = Get-Process -Name $app.Match -ErrorAction SilentlyContinue
    if ($procs) {
        Write-Host "Closing $($app.Match[0])..."
        $procs | Stop-Process -Force -ErrorAction SilentlyContinue
        if ($app.Relaunch) { $toRestore += $app.Relaunch }
    }
}
Start-Sleep -Seconds 1

if (-not $AttachOnly) {
    if (-not $SteamAppId) { throw 'Pass -SteamAppId, or -AttachOnly for a running game.' }
    Write-Host "Launching Steam app $SteamAppId..."
    Start-Process "steam://rungameid/$SteamAppId"
    # Anti-cheat launchers run first; wait up to 5 minutes
    $deadline = (Get-Date).AddMinutes(5)
    while (-not (Get-Process $Process -ErrorAction SilentlyContinue) -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 3 }
}

if (Get-Process $Process -ErrorAction SilentlyContinue) {
    Write-Host 'Game running. Apps come back when you quit.'
    while (Get-Process $Process -ErrorAction SilentlyContinue) { Start-Sleep -Seconds 5 }
} else {
    Write-Host "$Process never started."
}

Write-Host 'Restoring background apps...'
foreach ($exe in $toRestore) { if (Test-Path $exe) { Start-Process explorer.exe -ArgumentList "`"$exe`"" } }
if (($ahkWasRunning -or -not $AttachOnly) -and (Test-Path $ahkExe) -and (Test-Path $ahkScript)) {
    Start-Process $ahkExe -ArgumentList "`"$ahkScript`"" -WorkingDirectory (Split-Path $ahkScript)
}

# bf6-settings.ps1 - export, diff and re-import Battlefield 6 settings (graphics, input, keybinds, audio).
#
#   bf6-settings.ps1 export                         # snapshot to ~\bf6-settings\<PC>-<date>.zip
#   bf6-settings.ps1 diff   -From <zip|folder|file> # what differs from the current settings
#   bf6-settings.ps1 import -From <zip|folder|file> # merge everything in
#   bf6-settings.ps1 import -From <...> -Only Input,KeyBinding,Audio   # keep this PC's graphics
#   bf6-settings.ps1 import -From <...> -Full       # same-PC restore: replace every file as-is
#
# BF6 keeps settings in Documents\Battlefield 6\settings\<platform>\PROFSAVEbf6mp_profile, a plain-text
# "Gst<Section>.<Key> <value>" list the game reads at start and rewrites on exit. Import merges keys into
# that file, so keys the source doesn't have are left alone. GstRender.ShaderBundleVersion_* lines are
# shader-cache stamps for one GPU/driver and are never copied between PCs. The game must be closed.
param(
    [Parameter(Position = 0, Mandatory)][ValidateSet('export', 'import', 'diff')][string]$Action,
    [string]$From,
    [ValidateSet('Render', 'Input', 'KeyBinding', 'Audio')][string[]]$Only,
    [switch]$Full,
    [string]$OutDir = (Join-Path $HOME 'bf6-settings'),
    [string]$Platform = 'steam',
    # Follows OneDrive folder redirection; override for a non-standard Documents location
    [string]$SettingsRoot = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Battlefield 6\settings')
)
$ErrorActionPreference = 'Stop'

$settingsRoot = $SettingsRoot
$settingsDir = Join-Path $settingsRoot $Platform
$profileName = 'PROFSAVEbf6mp_profile'
$skipKey = '^GstRender\.ShaderBundleVersion_'

function Read-Profile($Path) {
    $map = [ordered]@{}
    foreach ($line in [IO.File]::ReadAllLines($Path)) {
        if ($line -match '^(\S+) (.*)$') { $map[$Matches[1]] = $Matches[2] }
    }
    $map
}
function Section($Key) { ($Key -split '\.', 2)[0] -replace '^Gst', '' }
function Want($Key) { ($Key -notmatch $skipKey) -and (-not $Only -or (Section $Key) -in $Only) }

# Resolve -From (zip, export folder, settings folder or a profile file) to a folder holding the profile.
function Resolve-Source {
    if (-not $From) { throw 'Pass -From <zip | folder | PROFSAVEbf6mp_profile>.' }
    $src = (Resolve-Path $From).Path
    if ($src -like '*.zip') {
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ("bf6-import-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
        Expand-Archive $src $tmp
        $src = $tmp
    }
    if (Test-Path $src -PathType Leaf) { return Split-Path $src }
    $hit = Get-ChildItem $src -Recurse -Filter $profileName | Select-Object -First 1
    if (-not $hit) { throw "No $profileName found in $From" }
    $hit.DirectoryName
}
function Assert-GameClosed {
    if (Get-Process bf6 -ErrorAction SilentlyContinue) { throw 'Battlefield 6 is running. Quit it first: the game overwrites the file on exit.' }
}
function Show-Diff($Source, $Target) {
    $n = 0
    foreach ($k in $Source.Keys) {
        if (-not (Want $k)) { continue }
        $old = $Target[$k]
        if ($old -ne $Source[$k]) { "  {0,-60} {1} -> {2}" -f $k, $(if ($null -eq $old) { '(new)' } else { $old }), $Source[$k]; $n++ }
    }
    "  $n setting(s) differ$(if ($Only) { " in: $($Only -join ', ')" })"
}

switch ($Action) {
    'export' {
        if (-not (Test-Path $settingsRoot)) { throw "No BF6 settings at $settingsRoot" }
        $stamp = "$env:COMPUTERNAME-$(Get-Date -Format yyyyMMdd-HHmm)"
        $stage = Join-Path ([IO.Path]::GetTempPath()) "bf6-$stamp"
        New-Item -ItemType Directory $stage -Force | Out-Null
        # Every platform folder (steam, ea, ...), without backups or Steam's per-account cloud marker
        Copy-Item $settingsRoot (Join-Path $stage 'settings') -Recurse
        Get-ChildItem (Join-Path $stage 'settings') -Recurse -File | Where-Object { $_.Name -like '*.bak-*' -or $_.Name -eq 'steam_autocloud.vdf' } | Remove-Item
        # Human-readable copy, sorted, without shader-cache stamps
        $prof = Join-Path $settingsDir $profileName
        if (Test-Path $prof) {
            $map = Read-Profile $prof
            $map.Keys | Where-Object { $_ -notmatch $skipKey } | Sort-Object | ForEach-Object { "$_ $($map[$_])" } |
                Set-Content (Join-Path $stage 'settings-readable.txt') -Encoding ascii
        }
        "Exported from $env:COMPUTERNAME on $(Get-Date -Format s)`nGPU: $((Get-CimInstance Win32_VideoController).Name -join ', ')" |
            Set-Content (Join-Path $stage 'SOURCE.txt') -Encoding ascii
        New-Item -ItemType Directory $OutDir -Force | Out-Null
        $zip = Join-Path $OutDir "$stamp.zip"
        Compress-Archive "$stage\*" $zip -Force
        Remove-Item $stage -Recurse -Force
        "Exported to $zip"
    }
    'diff' {
        $srcDir = Resolve-Source
        Show-Diff (Read-Profile (Join-Path $srcDir $profileName)) (Read-Profile (Join-Path $settingsDir $profileName))
    }
    'import' {
        Assert-GameClosed
        $srcDir = Resolve-Source
        if (-not (Test-Path $settingsDir)) { New-Item -ItemType Directory $settingsDir -Force | Out-Null }

        # Back up the whole current folder first
        $backup = Join-Path $OutDir "before-import-$env:COMPUTERNAME-$(Get-Date -Format yyyyMMdd-HHmmss)"
        New-Item -ItemType Directory $backup -Force | Out-Null
        Copy-Item "$settingsDir\*" $backup -Recurse -ErrorAction SilentlyContinue
        "Backup of current settings: $backup"

        if ($Full) {
            Get-ChildItem $srcDir -File | Where-Object { $_.Name -notlike '*.bak-*' -and $_.Name -ne 'steam_autocloud.vdf' } | Copy-Item -Destination $settingsDir -Force
            "Replaced all files in $settingsDir"
        } else {
            $targetFile = Join-Path $settingsDir $profileName
            $source = Read-Profile (Join-Path $srcDir $profileName)
            $target = if (Test-Path $targetFile) { Read-Profile $targetFile } else { [ordered]@{} }
            Show-Diff $source $target
            foreach ($k in $source.Keys) { if (Want $k) { $target[$k] = $source[$k] } }
            # Keep the file's key order (new keys go at the end); the game writes LF endings and no BOM
            $text = (($target.Keys | ForEach-Object { "$_ $($target[$_])" }) -join "`n") + "`n"
            [IO.File]::WriteAllText($targetFile, $text, (New-Object Text.UTF8Encoding $false))
            "Merged into $targetFile"
        }
        'Start the game and check Graphics. If Steam reports a Cloud conflict, choose the LOCAL files.'
    }
}

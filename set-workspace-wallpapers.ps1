# set-workspace-wallpapers.ps1
# One wallpaper per virtual desktop, like a GNOME workspace-wallpaper daemon. Windows 11 stores a
# wallpaper per desktop natively, so nothing keeps running afterwards.
#
# Images are assigned to desktops in alphabetical order (desktop 1 = first image). With no -ImageDir,
# the dark sci-fi set from olympus-terminal/linux_desktop_customization is downloaded (~120 MB).
# Copies scaled to the screen height go to Pictures\Wallpapers\workspaces, so switching stays fast.
#
#   powershell -ExecutionPolicy Bypass -File .\set-workspace-wallpapers.ps1
#   powershell -ExecutionPolicy Bypass -File .\set-workspace-wallpapers.ps1 -ImageDir ~\Pictures\mine
#
# No admin needed. Uses the VirtualDesktop module from the PowerShell Gallery (installed for the
# current user) to set each desktop's wallpaper.

param(
    [string]$ImageDir,
    [string]$OutDir = (Join-Path ([Environment]::GetFolderPath('MyPictures')) 'Wallpapers\workspaces'),
    [string]$Repo = 'olympus-terminal/linux_desktop_customization',
    [string]$RepoPath = 'wallpapers'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest is very slow with the progress bar
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Drawing

# ---------------------------------------------------------------- source images
if (-not $ImageDir) {
    $ImageDir = Join-Path $env:TEMP 'linuxify-wallpapers'
    New-Item -ItemType Directory -Force $ImageDir | Out-Null
    Write-Host "Downloading wallpapers from github.com/$Repo/$RepoPath ..."
    $list = Invoke-RestMethod "https://api.github.com/repos/$Repo/contents/$RepoPath" -Headers @{ 'User-Agent' = 'linuxify' }
    foreach ($f in $list | Where-Object { $_.type -eq 'file' -and $_.name -match '\.(png|jpe?g|bmp)$' }) {
        $dest = Join-Path $ImageDir $f.name
        if (-not (Test-Path $dest) -or (Get-Item $dest).Length -ne $f.size) {
            Write-Host "  $($f.name)"
            Invoke-WebRequest $f.download_url -OutFile $dest -UseBasicParsing
        }
    }
}
$images = @(Get-ChildItem $ImageDir -File | Where-Object { $_.Extension -match '^\.(png|jpe?g|bmp|tiff?)$' } |
            Sort-Object { $_.Name.ToLowerInvariant() })
if (-not $images) { throw "No images found in $ImageDir" }

# ---------------------------------------------------------------- scale to the screen height
$screenH = (Get-CimInstance Win32_VideoController | Where-Object CurrentVerticalResolution |
            Measure-Object CurrentVerticalResolution -Maximum).Maximum
if (-not $screenH) { $screenH = 1080 }

New-Item -ItemType Directory -Force $OutDir | Out-Null
Get-ChildItem $OutDir -Filter '*.jpg' | Remove-Item
$jpeg = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object MimeType -eq 'image/jpeg'
$quality = New-Object Drawing.Imaging.EncoderParameters 1
$quality.Param[0] = New-Object Drawing.Imaging.EncoderParameter([Drawing.Imaging.Encoder]::Quality, [long]93)

$scaled = @()
for ($i = 0; $i -lt $images.Count; $i++) {
    $src = [Drawing.Image]::FromFile($images[$i].FullName)
    try {
        $s = [Math]::Min([double]1.0, [double]$screenH / $src.Height)   # doubles: the int overload rounds to 1
        $w = [int]($src.Width * $s); $h = [int]($src.Height * $s)
        $bmp = New-Object Drawing.Bitmap $w, $h
        $g = [Drawing.Graphics]::FromImage($bmp)
        $g.InterpolationMode = 'HighQualityBicubic'
        $g.DrawImage($src, 0, 0, $w, $h)
        $name = ($images[$i].BaseName -replace '[^\w-]+', '_')
        $out = Join-Path $OutDir ('{0:D2}-{1}.jpg' -f ($i + 1), $name.Substring(0, [Math]::Min(40, $name.Length)).TrimEnd('_'))
        $bmp.Save($out, $jpeg, $quality)
        $g.Dispose(); $bmp.Dispose()
        $scaled += $out
    } finally { $src.Dispose() }
}
Write-Host "Scaled $($scaled.Count) image(s) to ${screenH}px high in $OutDir"

# ---------------------------------------------------------------- VirtualDesktop module
if (-not (Get-Module -ListAvailable VirtualDesktop)) {
    Write-Host 'Installing the VirtualDesktop PowerShell module (current user) ...'
    if (-not (Get-PackageProvider -ListAvailable NuGet -ErrorAction SilentlyContinue)) {
        Install-PackageProvider NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force | Out-Null
    }
    Install-Module VirtualDesktop -Scope CurrentUser -Repository PSGallery -Force -AllowClobber
}
Import-Module VirtualDesktop -WarningAction SilentlyContinue

# ---------------------------------------------------------------- assign
# "Fill": panoramic images are centre-cropped to the screen
Set-ItemProperty 'HKCU:\Control Panel\Desktop' WallpaperStyle '10'
Set-ItemProperty 'HKCU:\Control Panel\Desktop' TileWallpaper '0'

$count = Get-DesktopCount
for ($d = 0; $d -lt $count; $d++) {
    $img = $scaled[$d % $scaled.Count]   # fewer images than desktops: cycle
    Set-DesktopWallpaper -Desktop (Get-Desktop $d) -Path $img
    Write-Host ("  desktop {0,2} -> {1}" -f ($d + 1), (Split-Path $img -Leaf))
}
if ($scaled.Count -gt $count) {
    Write-Host "$($scaled.Count - $count) image(s) unused: only $count desktop(s). Re-run after adding desktops."
}
Write-Host 'Done. Change one later: switch to that desktop, right-click the desktop -> Personalize.'

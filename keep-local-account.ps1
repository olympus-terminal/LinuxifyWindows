# keep-local-account.ps1
# Keep a Windows 11 local account; stop the "create a Microsoft account" / "finish setting up" nags.
# Run from an ADMIN PowerShell while signed in to the local account you want to keep:
#   powershell -ExecutionPolicy Bypass -File .\keep-local-account.ps1
# Undo notes are in README.md.

#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

function Set-RegDword($Path, $Name, $Value) {
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name $Name -Type DWord -Value $Value
    Write-Host "  set $Path\$Name = $Value"
}

# 1. Backup local admin account (a second way in if the main account is ever locked behind an MSA prompt)
Write-Host "`n[1] Backup local admin account"
if (Get-LocalUser -Name 'BackupAdmin' -ErrorAction SilentlyContinue) {
    Write-Host "  BackupAdmin already exists, skipping creation"
} else {
    $pw = Read-Host -AsSecureString "  Choose a password for BackupAdmin"
    New-LocalUser -Name 'BackupAdmin' -Password $pw -PasswordNeverExpires -Description 'Backup local admin' | Out-Null
    Write-Host "  created BackupAdmin"
}
if (-not (Get-LocalGroupMember -Group 'Administrators' -Member 'BackupAdmin' -ErrorAction SilentlyContinue)) {
    Add-LocalGroupMember -Group 'Administrators' -Member 'BackupAdmin'
}
Write-Host "  BackupAdmin is an administrator"

# 2. Block Microsoft accounts on this PC (policy "Accounts: Block Microsoft accounts")
#    3 = users can't add or log on with Microsoft accounts
Write-Host "`n[2] Block Microsoft accounts"
Set-RegDword 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'NoConnectedUser' 3

# 3. Turn off "Let's finish setting up your device" (SCOOBE) and the Windows welcome experience
Write-Host "`n[3] Disable setup nag screens (current user)"
Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' 'ScoobeSystemSettingEnabled' 0
Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-310093Enabled' 0

# 4. Verify
Write-Host "`n[4] Verify"
Get-LocalGroupMember -Group 'Administrators' | Format-Table Name, PrincipalSource -AutoSize
Write-Host "  NoConnectedUser            =" (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System').NoConnectedUser "(expect 3)"
Write-Host "  ScoobeSystemSettingEnabled =" (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement').ScoobeSystemSettingEnabled "(expect 0)"
Write-Host "  SubscribedContent-310093   =" (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager').'SubscribedContent-310093Enabled' "(expect 0)"

Write-Host "`nDone. Restart, then sign in once as BackupAdmin to confirm it works."

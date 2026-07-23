# F1.5 - registreert (of ververst) de nachtelijke arena-run in Windows
# Taakplanner. Draait dagelijks om 02:00 als de machine aan staat.
# Verwijderen: schtasks /Delete /TN "FogOfWar nachtrun" /F
param(
    [string]$Tijd = "02:00",
    [int]$DuurMinuten = 480
)
$repo = Split-Path -Parent $PSScriptRoot
$script = Join-Path $repo "arena_nacht.ps1"
$actie = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$script`" -DuurMinuten $DuurMinuten"
schtasks /Create /F /TN "FogOfWar nachtrun" /TR $actie /SC DAILY /ST $Tijd
Write-Host "[REGISTER] taak 'FogOfWar nachtrun' dagelijks om $Tijd (duur ${DuurMinuten}m)."
Write-Host "[REGISTER] status: schtasks /Query /TN `"FogOfWar nachtrun`" /V /FO LIST"

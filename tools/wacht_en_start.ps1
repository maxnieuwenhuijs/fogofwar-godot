# Fog of War - wacht tot de machine vrij is en start dan een ander script
# (23 september, Max: "doe hierna dan de trainer of iets om te kijken waar we
# staan"). Zo kun je een tweede klus alvast klaarzetten achter een meting of
# training die nog loopt, zonder dat ze elkaar de kernen afpakken.
#
# "Vrij" = geen arena- of trainings-Godot EN geen regie-script meer
# (training_nacht.ps1, arena_nacht.ps1, meet_variant.ps1, zoeker_vanavond.ps1).
# Dat laatste is nodig: training_nacht.ps1 laat zijn trainers stoppen en start
# pas een tel later de fuzz en de arena; in dat gat draait er geen Godot, maar
# de pijplijn is nog niet klaar.
#
# Gebruik: .\tools\wacht_en_start.ps1 -Script <pad> [-Argumenten "<args>"]
#   bv. -Script tools\balans\meet_variant.ps1 -Argumenten "-Variant leeuw_cp4,leeuw_cp8"
# Start hem via Start-Process in een eigen venster, dan overleeft hij het
# sluiten van de terminal of een onderbroken sessie. Let op de quotes: geef
# -Argumenten als EEN string mee.
param(
    [Parameter(Mandatory = $true)]
    [string]$Script,
    [string]$Argumenten = ""
)
$ErrorActionPreference = "Continue"
Set-Location (Join-Path $PSScriptRoot "..")
$stamp = Get-Date -Format "yyyyMMdd_HHmm"
$log = "results/wacht_en_start_$stamp.log"
function Log([string]$msg) {
    $regel = "{0:HH:mm:ss} {1}" -f (Get-Date), $msg
    Write-Host $regel
    Add-Content -Encoding utf8 -Path $log -Value $regel
}
function Bezig {
    $godots = @(Get-CimInstance Win32_Process -Filter "Name like 'Godot%'" | Where-Object {
            $_.CommandLine -like "*arena.tscn*" -or $_.CommandLine -like "*-- train *" }).Count
    $regie = @(Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" | Where-Object {
            $_.ProcessId -ne $PID -and (
                $_.CommandLine -like "*training_nacht.ps1*" -or $_.CommandLine -like "*arena_nacht.ps1*" -or
                $_.CommandLine -like "*meet_variant.ps1*" -or $_.CommandLine -like "*zoeker_vanavond.ps1*") }).Count
    return ($godots + $regie) -gt 0
}
if (-not (Test-Path $Script)) { Log "[WACHT] script niet gevonden: $Script"; exit 1 }
Log "[WACHT] wacht tot de machine vrij is, daarna: $Script $Argumenten"
while (Bezig) {
    Start-Sleep -Seconds 30
}
Log "[WACHT] machine vrij, start $Script"
Invoke-Expression "& '.\$Script' $Argumenten"
Log "[WACHT] klaar"

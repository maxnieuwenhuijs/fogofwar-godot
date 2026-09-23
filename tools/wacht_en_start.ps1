# Fog of War - wacht tot er geen arena- of trainingsprocessen meer draaien en
# start dan een ander script (23 september, Max: "doe hierna dan de trainer of
# iets om te kijken waar we staan"). Zo kun je een tweede klus alvast klaarzetten
# achter een meting die nog loopt, zonder dat ze elkaar de kernen afpakken.
#
# Gebruik: .\tools\wacht_en_start.ps1 -Script training_nacht.ps1 [-Argumenten "-TrainMinuten 420 -ArenaMinuten 60"]
# Start je hem via Start-Process (los venster), dan overleeft hij het sluiten
# van de terminal of een onderbroken sessie.
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
if (-not (Test-Path $Script)) { Log "[WACHT] script niet gevonden: $Script"; exit 1 }
Log "[WACHT] wacht tot arena en trainers klaar zijn, daarna: $Script $Argumenten"
while (@(Get-CimInstance Win32_Process -Filter "Name like 'Godot%'" | Where-Object {
            $_.CommandLine -like "*arena.tscn*" -or $_.CommandLine -like "*-- train *" }).Count -gt 0) {
    Start-Sleep -Seconds 30
}
Log "[WACHT] machine vrij, start $Script"
$regel = "& '.\$Script' $Argumenten"
Invoke-Expression $regel
Log "[WACHT] klaar"

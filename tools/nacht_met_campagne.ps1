# Fog of War - een trainingsnacht voor ALLE bots (29 september, Max: "opnieuw
# trainen ook met campagne modus, want volgens mij snappen de bots nog niet
# goed hoe belangrijk de CP en reinforcements kunnen zijn").
#
# Drie stappen achter elkaar, elk pas als de vorige klaar is:
#   1. training_nacht.ps1: de duelbots (per factie, op de campagne-economie),
#      daarna de nachtmatrix, fuzz en dashboard;
#   2. campagne_arena.ps1: de datarun voor het duel-orakel (losse duels over
#      de invoerruimte van de campagne);
#   3. campagne_train.ps1: het verstand van de campagnebots (hoe ze in het
#      campagnemenu met punten en CP omgaan), getraind op dat orakel.
#
# Max start dit zelf (B13). Gebruik:
#   .\tools\nacht_met_campagne.ps1 [-TrainMinuten 480] [-ArenaMinuten 60] [-CampagneMinuten 60]
param(
    [int]$TrainMinuten = 480,
    [int]$ArenaMinuten = 60,
    [int]$CampagneMinuten = 60
)
$ErrorActionPreference = "Continue"
Set-Location (Join-Path $PSScriptRoot "..")
$stamp = Get-Date -Format "yyyyMMdd_HHmm"
$log = "results/nacht_met_campagne_$stamp.log"
function Log([string]$msg) {
    $regel = "{0:HH:mm:ss} {1}" -f (Get-Date), $msg
    Write-Host $regel
    Add-Content -Encoding utf8 -Path $log -Value $regel
}

Log "[KETEN] 1/3 duelbots: training_nacht.ps1 -TrainMinuten $TrainMinuten -ArenaMinuten $ArenaMinuten"
& .\training_nacht.ps1 -TrainMinuten $TrainMinuten -ArenaMinuten $ArenaMinuten 2>&1 | ForEach-Object { Log "[NACHT] $_" }

Log "[KETEN] 2/3 campagne-datarun: campagne_arena.ps1"
& .\campagne_arena.ps1 -Naam "campagne_$stamp" 2>&1 | ForEach-Object { Log "[CAMPAGNE] $_" }

Log "[KETEN] 3/3 campagnebots: campagne_train.ps1 -Minuten $CampagneMinuten"
& .\campagne_train.ps1 -Minuten $CampagneMinuten -Naam "campagnetrain_$stamp" 2>&1 | ForEach-Object { Log "[CTRAIN] $_" }

Log "[KETEN] klaar -> $log"

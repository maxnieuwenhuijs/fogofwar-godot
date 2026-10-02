# Fog of War - een cyclus van de trainingsmarathon (Max, 2 oktober: "doe de
# monster training 48 u lang met ook campagne daarin meenemen ... Start zelf de
# training, kijk naar de percentages"). Een cyclus op de regels van NU:
#
#   A. training_nacht.ps1: zes duel-trainers (een kern per factie,
#      -TrainMinuten), daarna de nachtmatrix (30 processen), fuzz, dashboard.
#   B. tegelijk, op de vrije kernen:
#      1. een verse campagne-datarun (losse duels op de regels van nu),
#      2. het duel-orakel ALLEEN uit die datarun en de campagnetrainer
#         (oude duels van andere regels horen er niet meer in),
#      3. daarna de puntenbots (tools/punten_meting.ps1, drie trainers).
#   C. na A: de campagnebots nameten op echte duels (campagne_validatie).
#
# Alles in results/marathon_<stempel>.log. Start dit via WMI (los van de
# Claude-app, zie de memory "lange runs"), nooit gepland (B13): alleen op
# Max' verzoek. Gebruik:
#   .\tools\marathon_cyclus.ps1 [-TrainMinuten 420] [-CampagneMinuten 120]
#       [-PuntenMinuten 300] [-ZonderPunten] [-ZonderValidatie]
param(
    [int]$TrainMinuten = 420,
    [int]$CampagneMinuten = 120,
    [int]$DatarunProcs = 20,
    [int]$DatarunDuels = 60,
    [int]$PuntenMinuten = 300,
    [int]$ValidatieProcs = 24,
    [switch]$ZonderPunten,
    [switch]$ZonderValidatie
)
$ErrorActionPreference = "Continue"
$repo = Split-Path $PSScriptRoot -Parent
Set-Location $repo
$stamp = Get-Date -Format "yyyyMMdd_HHmm"
$log = "results/marathon_$stamp.log"

function Log([string]$msg) {
    $regel = "{0:yyyy-MM-dd HH:mm:ss} {1}" -f (Get-Date), $msg
    Write-Host $regel
    Add-Content -Encoding utf8 -Path $log -Value $regel
}

function Start-Los([string]$script, [string[]]$argumenten) {
    return Start-Process powershell -PassThru -WindowStyle Minimized -WorkingDirectory $repo `
        -ArgumentList (@("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$repo\$script") + $argumenten)
}

$sha = (git rev-parse --short HEAD)
Log "[MARATHON] cyclus $stamp op ${sha}: duel-training $TrainMinuten min + matrix; campagne parallel"

# A. De duelbots (blijft lopen terwijl B werkt).
$nacht = Start-Los "training_nacht.ps1" @("-TrainMinuten", "$TrainMinuten", "-ArenaMinuten", "60")
Log "[MARATHON] A gestart: training_nacht.ps1 (pid $($nacht.Id))"

# B1. Verse duels op de regels van nu.
$data = "campagne_$stamp"
Log "[MARATHON] B1: datarun $DatarunProcs x $DatarunDuels duels -> results/$data"
& .\campagne_arena.ps1 -Procs $DatarunProcs -Duels $DatarunDuels -Naam $data 2>&1 |
    Where-Object { $_ -match "klaar|FOUT|ERROR|duels" } | ForEach-Object { Log "[DATARUN] $_" }

# B2. Orakel alleen uit die datarun, dan de campagnetrainer.
Log "[MARATHON] B2: campagnetrainer $CampagneMinuten min, orakel uit results/$data"
& .\campagne_train.ps1 -Minuten $CampagneMinuten -Naam "campagnetrain_$stamp" -OrakelMappen "results/$data" 2>&1 |
    Where-Object { $_ -match "ORAKEL|ADOPTIE|check gen|klaar|FOUT|ERROR" } | ForEach-Object { Log "[CTRAIN] $_" }

# B3. De puntenbots, op het verse orakel en het verse teamverstand.
$punten = $null
if (-not $ZonderPunten) {
    $punten = Start-Los "tools\punten_meting.ps1" @("-Minuten", "$PuntenMinuten")
    Log "[MARATHON] B3 gestart: punten_meting.ps1 $PuntenMinuten min (pid $($punten.Id))"
}

Log "[MARATHON] wacht op A (duel-training + matrix)"
$nacht | Wait-Process
Log "[MARATHON] A klaar"

# C. De campagnebots op echte duels.
if (-not $ZonderValidatie) {
    Log "[MARATHON] C: campagnebots nameten op echte duels ($ValidatieProcs processen)"
    & .\campagne_arena.ps1 -Config arena/arena_configs/campagne_validatie.json -Procs $ValidatieProcs `
        -Naam "validatie_$stamp" 2>&1 | Where-Object { $_ -match "winkans|getraind|hand|klaar" } |
        ForEach-Object { Log "[VALIDATIE] $_" }
}
if ($punten) {
    Log "[MARATHON] wacht op B3 (puntenbots)"
    $punten | Wait-Process
}
Log "[MARATHON] cyclus $stamp klaar"

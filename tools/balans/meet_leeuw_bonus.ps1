# Fog of War - meet de Leeuw met startpunten (C11-budget_bonus) in plaats van
# een extra kaart (22 september, Max: "doe idd met +2 voor de leeuw").
#
# De nachtmatrix van 21 september met getrainde bots gaf Leeuw 36,6% (band
# 36,6-59,2). Het factiezoeker-voorstel "3 kaarten" haalde hem naar 59,8%:
# +23 pp, veel te grof, de kwaal verhuist alleen. `budget_bonus` is de fijne
# knop (C11): Muis heeft +4, Beer +3, Wolf +2 en 4 CP, Krokodil +3, de Leeuw
# nu 0. Deze meting probeert +2 (en met -Variant bonus3 de +3).
#
# Alleen `campaign.budget_bonus` verschilt; het doctrines-blok blijft gelijk,
# dus de Leeuw houdt 2 kaarten, budget 8 en leger [12,4,2]. GameState leest
# de bonus uit `rules.campaign.budget_bonus` (`_budget_bonus_van`), dus het
# variant-regelsbestand is genoeg: het spel zelf wordt niet aangeraakt.
#
# Gebruik: .\tools\balans\meet_leeuw_bonus.ps1 [-Variant bonus2] [-Procs 24]
param(
    [string]$Variant = "bonus2",   # naam na v437_matrix_ in arena/arena_configs/varianten
    [int]$Procs = 24,
    [string]$WachtOp = ""
)
$ErrorActionPreference = "Continue"
Set-Location (Join-Path $PSScriptRoot "..\..")
$stamp = Get-Date -Format "yyyyMMdd_HHmm"
$log = "results/leeuw_${Variant}_$stamp.log"
function Log([string]$msg) {
    $regel = "{0:HH:mm:ss} {1}" -f (Get-Date), $msg
    Write-Host $regel
    Add-Content -Encoding utf8 -Path $log -Value $regel
}
if ($WachtOp) {
    Log "[LEEUW] wacht tot de arena-processen van $WachtOp klaar zijn"
    while (@(Get-CimInstance Win32_Process -Filter "Name like 'Godot%'" | Where-Object { $_.CommandLine -like "*$WachtOp*" }).Count -gt 0) {
        Start-Sleep -Seconds 30
    }
}
$naam = "leeuw_${Variant}_$stamp"
Log "[LEEUW] arena: Leeuw $Variant startpunten, 5 potjes per paar, $Procs processen -> results/$naam"
& .\arena.ps1 -Config "arena/arena_configs/varianten/v437_matrix_leeuw_$Variant.json" -Procs $Procs -Naam $naam 2>&1 | ForEach-Object { Log "[ARENA] $_" }
$n = 0
if (Test-Path "results/$naam/games.jsonl") { $n = (Get-Content "results/$naam/games.jsonl" | Measure-Object -Line).Lines - 1 }
Log "[LEEUW] klaar: $n partijen"
python tools/dashboard/compare_runs.py results/nacht_20260921_1621_v42_matrix_l2 "results/$naam" 2>&1 | ForEach-Object { Log "[VS HUIDIG] $_" }
Log "[LEEUW] klaar -> $log"

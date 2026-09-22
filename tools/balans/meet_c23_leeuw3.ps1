# Fog of War - controlemeting van het factiezoeker-voorstel van 22 september:
# de Leeuw krijgt 3 kaarten per ronde (was 2), verder niets (C23-kandidaat).
# Wacht eerst tot de factiezoeker (results/facties_20260922_085341) klaar is,
# zodat de arena niet met hem om de kernen vecht, en meet dan de volledige
# campagne-matrix (36 paren, L2 tegen L2, getrainde bots van 21 september)
# met games_per_matchup 5 over -Procs processen. Vergelijk daarna met de
# nachtmatrix van 21 september (zelfde bots, huidige Leeuw).
#
# Gebruik: .\tools\balans\meet_c23_leeuw3.ps1 [-Procs 20] [-WachtOp facties_20260922_085341]
param(
    [int]$Procs = 20,
    [string]$WachtOp = "facties_20260922_085341"
)
$ErrorActionPreference = "Continue"
Set-Location (Join-Path $PSScriptRoot "..\..")
$stamp = Get-Date -Format "yyyyMMdd_HHmm"
$log = "results/c23_leeuw3_$stamp.log"
function Log([string]$msg) {
    $regel = "{0:HH:mm:ss} {1}" -f (Get-Date), $msg
    Write-Host $regel
    Add-Content -Encoding utf8 -Path $log -Value $regel
}
if ($WachtOp) {
    Log "[C23] wacht tot de arena-processen van $WachtOp klaar zijn"
    while (@(Get-CimInstance Win32_Process -Filter "Name like 'Godot%'" | Where-Object { $_.CommandLine -like "*$WachtOp*" }).Count -gt 0) {
        Start-Sleep -Seconds 30
    }
    Log "[C23] factiezoeker klaar"
}
$naam = "c23_leeuw3_$stamp"
Log "[C23] arena: Leeuw 3 kaarten, 5 potjes per paar, $Procs processen -> results/$naam"
& .\arena.ps1 -Config arena/arena_configs/varianten/v437_matrix_leeuw3.json -Procs $Procs -Naam $naam 2>&1 | ForEach-Object { Log "[ARENA] $_" }
$n = 0
if (Test-Path "results/$naam/games.jsonl") { $n = (Get-Content "results/$naam/games.jsonl" | Measure-Object -Line).Lines - 1 }
Log "[C23] klaar: $n partijen"
python tools/dashboard/compare_runs.py results/nacht_20260921_1621_v42_matrix_l2 "results/$naam" 2>&1 | ForEach-Object { Log "[VS HUIDIG] $_" }
Log "[C23] klaar -> $log"

# Fog of War - meet de drie 4.3.7-kandidaten voor de ruiterbonus naast elkaar
# (18 september, Max: "doe inderdaad die 3 naast elkaar, alleen dan meer
# partijen"). De nachtrun van 18 september liet zien dat 4.3.6 (+2 stamina,
# +2 attack op elke ruiter) het spel een havenrace maakte: band 27-69%.
#
#   atk2       stat_bonus  cav {attack 2}                  (alleen de slag)
#   atk2_sta1  stat_bonus  cav {attack 2, stamina 1}       (het midden)
#   min_atk2   stat_minimum cav {attack 2}, bonus 0        (Max' ondergrens)
#
# Elke variant: de campagne-matrix (36 paren, L2 tegen L2) met
# games_per_matchup 5 over -Procs processen = 5400 partijen per variant,
# ruim twee uur per stuk op 30 processen. Na afloop het dashboard en een
# vergelijking met 4.3.5 (nacht_20260910_1525) en 4.3.6 (nacht_20260918_0442).
#
# Gebruik: .\tools\balans\meet_437_varianten.ps1 [-Procs 30] [-Varianten atk2,atk2_sta1,min_atk2]
# Raakt het spel niet aan: alleen results/.
param(
    [int]$Procs = 30,
    [string[]]$Varianten = @("atk2", "atk2_sta1", "min_atk2")
)
$ErrorActionPreference = "Continue"
Set-Location (Join-Path $PSScriptRoot "..\..")
$stamp = Get-Date -Format "yyyyMMdd_HHmm"
$log = "results/varianten_437_$stamp.log"
function Log([string]$msg) {
    $regel = "{0:HH:mm:ss} {1}" -f (Get-Date), $msg
    Write-Host $regel
    Add-Content -Encoding utf8 -Path $log -Value $regel
}
Log "[437] start: varianten $($Varianten -join ', ') met $Procs processen, 5 potjes per paar"
$namen = @()
foreach ($v in $Varianten) {
    $cfg = "arena/arena_configs/varianten/v437_matrix_$v.json"
    $naam = "v437_${v}_$stamp"
    $namen += $naam
    $t0 = Get-Date
    Log "[437] $v -> results/$naam"
    & .\arena.ps1 -Config $cfg -Procs $Procs -Naam $naam 2>&1 | ForEach-Object { Log "[ARENA] $_" }
    $n = 0
    if (Test-Path "results/$naam/games.jsonl") { $n = (Get-Content "results/$naam/games.jsonl" | Measure-Object -Line).Lines - 1 }
    Log ("[437] {0} klaar: {1} partijen in {2:N0} s" -f $v, $n, ((Get-Date) - $t0).TotalSeconds)
}
python tools/dashboard/build_dashboard.py 2>&1 | ForEach-Object { Log "[DASHBOARD] $_" }
Log "[437] vergelijking met 4.3.5 en 4.3.6:"
foreach ($naam in $namen) {
    python tools/dashboard/compare_runs.py results/nacht_20260910_1525_v42_matrix_l2 "results/$naam" 2>&1 | ForEach-Object { Log "[VS 4.3.5] $_" }
    python tools/dashboard/compare_runs.py results/nacht_20260918_0442_v42_matrix_l2 "results/$naam" 2>&1 | ForEach-Object { Log "[VS 4.3.6] $_" }
}
Log "[437] klaar -> $log"

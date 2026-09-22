# L4 neuraal: een selfplay-ronde (22 september).
#
# 1. L4 (tweetraps) speelt tegen zichzelf op alle 36 paren en logt elke 4e
#    beslissing (arena/arena_configs/l4_beslislog.json).
# 2. Het WAARDE-netje wordt opnieuw getraind op ALLE beslislogs tot nu toe
#    (de L2-run plus elke selfplay-ronde): partijen die al beter gespeeld
#    zijn dan die van L2. Het score-netje (de L2-imitatie) blijft staan.
# 3. netcheck (pariteit, legaliteit).
# 4. Meting van het nieuwe waarde-netje als rood tegen L2.
#
# Gebruik: .\tools\l4\selfplay_ronde.ps1 [-Ronde 1] [-Procs 12]
# Het nieuwe netje komt in data/ai_net_waarde_r<Ronde>.json; pas als de
# meting (tools/l4/meet_l4.py) beter is dan de vorige ronde kopieer je hem
# over data/ai_net_waarde.json en commit je hem apart (trainingsdata).
param(
    [int]$Ronde = 1,
    [int]$Procs = 12
)
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..\..")
$godot = $env:GODOT_PATH
if (-not $godot) { $godot = "C:\Users\maxni\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe" }
$stempel = Get-Date -Format "yyyyMMdd"
$logNaam = "l4_selfplay_r${Ronde}_$stempel"
$netUit = "data/ai_net_waarde_r$Ronde.json"

Write-Host "[SELFPLAY] ronde $Ronde: L4 vs L4 loggen -> results/$logNaam"
.\arena.ps1 -Config arena/arena_configs/l4_beslislog.json -Procs $Procs -Naam $logNaam

$logs = Get-ChildItem results -Directory | Where-Object { $_.Name -like "l4_log_*" -or $_.Name -like "l4_selfplay_*" } | ForEach-Object { $_.FullName }
Write-Host "[SELFPLAY] waarde-netje trainen op: $($logs -join ', ')"
python tools/l4/train_net.py @logs --uit $netUit --epochs 20 --imitatie 0 --uitslag 1

Write-Host "[SELFPLAY] netcheck"
& $godot --headless --path . res://tools/capture.tscn -- netcheck "net=res://data/ai_net.json" "waarde=res://$netUit" 2>&1 | Select-String "NETCHECK"

$cfg = Get-Content arena/arena_configs/l4_vs_l2.json | ConvertFrom-Json
$cfg.agents.p1 = "l4:res://data/ai_net.json+res://$netUit"
$cfg.base_seed = 100000 + 1000 * $Ronde
$cfgPad = "arena/arena_configs/_proef_r${Ronde}_vs_l2.json"
$cfg | ConvertTo-Json -Depth 5 | Set-Content -Encoding utf8 $cfgPad
$meetNaam = "proef_r${Ronde}_$stempel"
Write-Host "[SELFPLAY] meting als rood tegen L2 -> results/$meetNaam"
.\arena.ps1 -Config $cfgPad -Procs $Procs -Naam $meetNaam
python tools/l4/meet_l4.py "results/$meetNaam"
Write-Host "[SELFPLAY] klaar. Beter dan de vorige ronde? Dan: Copy-Item $netUit data/ai_net_waarde.json en apart committen."

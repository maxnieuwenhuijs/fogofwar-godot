# Fog of War - campagnebots trainen (F7.2b, docs/F7-campagnetrainer.md)
# Gebruik: .\campagne_train.ps1 [-Minuten 60] [-Naam run1]
# 1. Bouwt het duel-orakel (data/duel_orakel.json) uit ALLE duel-metingen die
#    in results/campagne_*/duels.jsonl liggen (de knop "Campagne-duels meten").
# 2. Draait de campagnetrainer: het verstand van de bots (hoe ze handelen in
#    het campagnemenu) tegen de kampioen, op het orakel. Een adoptie schrijft
#    data/campagne_verstand.json (apart committen, net als de duelgewichten).
# Log: results/<naam>/train.log. Max start dit zelf (B13).
param(
    [int]$Minuten = 60,
    [string]$Naam = ""
)
$repo = $PSScriptRoot
Set-Location $repo
$godot = $env:GODOT_PATH
if (-not $godot) { $godot = "C:\Users\maxni\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe" }
$console = $godot -replace "\.exe$", "_console.exe"
if (-not (Test-Path $console)) { $console = $godot }
if (-not $Naam) { $Naam = "campagnetrain_" + (Get-Date -Format "yyyyMMdd_HHmmss") }
$uit = "results/$Naam"
New-Item -ItemType Directory -Force -Path $uit | Out-Null
$zonderBom = New-Object System.Text.UTF8Encoding $false

# 1. Het orakel uit alle metingen die er liggen.
$mappen = @(Get-ChildItem (Join-Path $repo "results") -Directory -Filter "campagne_*" |
    Where-Object { Test-Path (Join-Path $_.FullName "duels.jsonl") } |
    ForEach-Object { $_.FullName })
if ($mappen.Count -eq 0) {
    Write-Host "[CAMPAGNETRAIN] nog geen duel-metingen: eerst 'Campagne-duels meten' (campagne_arena.ps1)."
    exit 1
}
Write-Host "[CAMPAGNETRAIN] orakel uit $($mappen.Count) meting(en)"
& python tools/campagne/maak_orakel.py @mappen --uit data/duel_orakel.json 2>&1 | Tee-Object -FilePath "$uit/orakel.txt"

# 2. De trainer, met de minuten van het paneel.
$cfg = Get-Content "arena/arena_configs/campagne_train.json" -Raw | ConvertFrom-Json
$cfg.minuten = $Minuten
$cfgPad = Join-Path $repo "$uit/config.json"
[IO.File]::WriteAllText($cfgPad, ($cfg | ConvertTo-Json), $zonderBom)
Write-Host "[CAMPAGNETRAIN] trainer $Minuten minuten -> $uit"
& $console --headless --path . res://arena/arena.tscn -- --campagnetrain --config "$uit/config.json" --out $uit 2>&1 |
    Where-Object { $_ -match "\[TRAIN\]|SCRIPT ERROR" } | Tee-Object -FilePath "$uit/console.txt"
Write-Host "[CAMPAGNETRAIN] klaar -> $uit/train.log"

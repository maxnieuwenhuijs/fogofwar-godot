# Fog of War - F6.0-P4: puntenbots trainen en meten (docs/F6-punten-masterplan.md,
# hoofdstuk 8). Max start dit zelf (B13), via het paneel of:
#   .\tools\punten_meting.ps1 [-Minuten 420] [-Campagnes 1000] [-AlleenMeten]
#
# 1. Drie trainers naast elkaar, een per puntentabel: kroonfactor 1, 2 en 3 (de
#    kampioen krijgt 20, 40 of 60 punten, de rest van de kroonpot schaalt mee).
#    Elk -Minuten lang, vanaf het teamverstand (data/campagne_verstand.json),
#    met de fitness "eigen punten" op gemengde stoelen. Ze schrijven
#    data/campagne_verstand_k1.json, _k2 en _k3 (apart committen).
# 2. Vijf metingen naast elkaar, elk -Campagnes campagnes op het duel-orakel,
#    met op alle stoelen hetzelfde verstand: hand (leeg), team, k1, k2, k3.
# 3. Het rapport: tools/campagne/punten_rapport.py -> rapport.md in de map.
#
# Nodig: data/duel_orakel.json (de F7-datarun) en data/campagne_verstand.json.
# Alles komt in results/punten_<stempel>/ (train_k1..3, meet_*, keten.log).
param(
    [int]$Minuten = 420,
    [int]$Campagnes = 1000,
    [switch]$AlleenMeten
)
$ErrorActionPreference = "Continue"
$repo = Split-Path $PSScriptRoot -Parent
Set-Location $repo
$godot = $env:GODOT_PATH
if (-not $godot) { $godot = "C:\Users\maxni\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe" }
$console = $godot -replace "\.exe$", "_console.exe"
if (-not (Test-Path $console)) { $console = $godot }
$stamp = Get-Date -Format "yyyyMMdd_HHmm"
$uit = "results/punten_$stamp"
New-Item -ItemType Directory -Force -Path $uit | Out-Null
$log = "$uit/keten.log"
# Zonder BOM: de JSON-lezer van Godot struikelt erover.
$zonderBom = New-Object System.Text.UTF8Encoding $false

function Log([string]$msg) {
    $regel = "{0:HH:mm:ss} {1}" -f (Get-Date), $msg
    Write-Host $regel
    Add-Content -Encoding utf8 -Path $log -Value $regel
}

function Schrijf-Json($obj, [string]$pad) {
    [IO.File]::WriteAllText((Join-Path $repo $pad), ($obj | ConvertTo-Json -Depth 8), $zonderBom)
}

# Een Godot-proces op de achtergrond, met zijn uitvoer in de map.
function Start-Godot([string]$map, [string[]]$argumenten) {
    return Start-Process -FilePath $console -PassThru -NoNewWindow `
        -RedirectStandardOutput "$map/console.txt" -RedirectStandardError "$map/fouten.txt" `
        -ArgumentList (@("--headless", "--path", ".", "res://arena/arena.tscn", "--") + $argumenten)
}

foreach ($nodig in @("data/duel_orakel.json", "data/campagne_verstand.json")) {
    if (-not (Test-Path $nodig)) {
        Log "[PUNTEN] $nodig ontbreekt: eerst de campagnebots (Campagne-duels meten, dan trainen)."
        exit 1
    }
}

# 1. De trainers: een kern elk, dus alle drie tegelijk.
if (-not $AlleenMeten) {
    Log "[PUNTEN] 1/3 drie trainers naast elkaar, elk $Minuten minuten -> $uit/train_k1..3"
    $jobs = @()
    foreach ($k in 1..3) {
        $map = "$uit/train_k$k"
        New-Item -ItemType Directory -Force -Path $map | Out-Null
        $cfg = Get-Content "arena/arena_configs/campagne_punten_k$k.json" -Raw | ConvertFrom-Json
        $cfg.minuten = $Minuten
        Schrijf-Json $cfg "$map/config.json"
        $jobs += Start-Godot $map @("--campagnetrain", "--config", "$map/config.json", "--out", $map)
    }
    $jobs | Wait-Process
    foreach ($k in 1..3) {
        $laatste = Get-Content "$uit/train_k$k/train.log" -Tail 1 -ErrorAction SilentlyContinue
        Log "[PUNTEN] k${k}: $laatste"
    }
}

# 2. De metingen: alle stoelen hetzelfde verstand, de tabel van dat verstand
#    (hand en team rekenen met tabel v1).
Log "[PUNTEN] 2/3 metingen, elk $Campagnes campagnes op het orakel"
$metingen = [ordered]@{
    "hand" = @{ "naam" = "hand"; "verstand" = @{} }
    "team" = @{ "naam" = "team"; "verstand_pad" = "res://data/campagne_verstand.json" }
}
$tabellen = @{}
foreach ($k in 1..3) {
    $tabellen["k$k"] = (Get-Content "arena/arena_configs/campagne_punten_k$k.json" -Raw | ConvertFrom-Json).tabel
    if (Test-Path "data/campagne_verstand_k$k.json") {
        $metingen["k$k"] = @{ "naam" = "k$k"; "verstand_pad" = "res://data/campagne_verstand_k$k.json" }
    } else {
        Log "[PUNTEN] data/campagne_verstand_k$k.json ontbreekt: k$k wordt niet gemeten"
    }
}
$jobs = @()
foreach ($naam in $metingen.Keys) {
    $map = "$uit/meet_$naam"
    New-Item -ItemType Directory -Force -Path $map | Out-Null
    $cfg = Get-Content "arena/arena_configs/campagne_punten_meting.json" -Raw | ConvertFrom-Json
    $cfg.campagnes = $Campagnes
    $cfg.teams = @($metingen[$naam], $metingen[$naam])
    if ($tabellen.ContainsKey($naam)) { $cfg.tabel = $tabellen[$naam] }
    Schrijf-Json $cfg "$map/config.json"
    $jobs += Start-Godot $map @("--campagne", "--config", "$map/config.json", "--out", $map)
}
$jobs | Wait-Process

# 3. Het rapport.
Log "[PUNTEN] 3/3 rapport"
& python tools/campagne/punten_rapport.py $uit 2>&1 | ForEach-Object { Log "[RAPPORT] $_" }
Log "[PUNTEN] klaar -> $uit/rapport.md"

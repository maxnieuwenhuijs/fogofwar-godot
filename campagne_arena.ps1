# Fog of War - campagne-arena multi-proces-launcher (F7.1a, docs/F7-campagnetrainer.md)
# Gebruik: .\campagne_arena.ps1 [-Config arena/arena_configs/campagne_duels.json] [-Procs 0] [-Naam run1]
# Procs 0 = automatisch (cores - 1). Elk proces krijgt een eigen seed-offset en
# submap; na afloop worden duels.jsonl (en campagnes.jsonl) samengevoegd.
# De datarun voor het duel-orakel: de standaard-config (losse duels over de
# invoerruimte). Een meting van volledige campagnes: -Config ...campagne_hand.json.
# Max start dit zelf (B13): een nacht met 31 processen levert duizenden duels.
param(
    [string]$Config = "arena/arena_configs/campagne_duels.json",
    [int]$Procs = 0,
    [string]$Naam = "",
    [int]$Duels = 0   # >0: zoveel duels per proces (overschrijft de config)
)
$godot = $env:GODOT_PATH
if (-not $godot) { $godot = "C:\Users\maxni\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe" }
if ($Procs -le 0) { $Procs = [Math]::Max(1, [Environment]::ProcessorCount - 1) }
if (-not $Naam) { $Naam = "campagne_" + (Get-Date -Format "yyyyMMdd_HHmmss") }
$uit = "results/$Naam"
New-Item -ItemType Directory -Force -Path $uit | Out-Null
if ($Duels -gt 0) {
    # Een kopie van de config met het gevraagde aantal duels per proces
    # (zonder BOM: de JSON-lezer van Godot struikelt erover).
    $cfg = Get-Content $Config -Raw | ConvertFrom-Json
    $cfg.duels = $Duels
    $Config = "$uit/config.json"
    [IO.File]::WriteAllText((Join-Path $PSScriptRoot $Config), ($cfg | ConvertTo-Json),
        (New-Object System.Text.UTF8Encoding $false))
}
Write-Host "[CAMPAGNE.PS1] $Procs processen -> $uit (config: $Config)"
$jobs = @()
for ($i = 0; $i -lt $Procs; $i++) {
    $sub = "$uit/proc$i"
    $offset = $i * 100000
    $jobs += Start-Process -FilePath $godot -PassThru -NoNewWindow -ArgumentList @(
        "--headless", "--path", ".", "res://arena/arena.tscn", "--",
        "--campagne", "--config", $Config, "--out", $sub, "--seed-offset", "$offset")
}
$jobs | Wait-Process
foreach ($bestand in @("duels.jsonl", "campagnes.jsonl")) {
    if (-not (Test-Path "$uit/proc0/$bestand")) { continue }
    $doel = "$uit/$bestand"
    Get-Content "$uit/proc0/$bestand" -TotalCount 1 | Set-Content -Encoding utf8 $doel
    for ($i = 0; $i -lt $Procs; $i++) {
        if (Test-Path "$uit/proc$i/$bestand") {
            Get-Content "$uit/proc$i/$bestand" | Select-Object -Skip 1 | Add-Content -Encoding utf8 $doel
        }
    }
    Write-Host "[CAMPAGNE.PS1] klaar -> $doel"
}
python tools/campagne/rapport.py $uit

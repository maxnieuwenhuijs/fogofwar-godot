# Fog of War - meet een of meer regelvarianten op de volle campagne-matrix en
# vergelijk elk met de nieuwste nachtmatrix.
#
# Begon op 22 september als de Leeuw-met-startpunten-meting (Max: "doe idd
# met +2 voor de leeuw"), op 23 september algemeen gemaakt nadat een
# variantnaam buiten het vaste naampatroon 28 Godots liet starten die meteen
# weer stopten (de config bestond niet en niemand zei het).
#
# Een variant is een regels-json in arena/arena_configs/varianten met een
# bijbehorende arena-config `v437_matrix_<naam>.json` (36 paren, L2 tegen L2,
# 5 potjes per paar). Het spel zelf wordt niet aangeraakt.
#
# Het ijkpunt is de NIEUWSTE nachtmatrix (results\nacht_*_v42_matrix_l2),
# gekozen op het moment van vergelijken: na een trainingsnacht vergelijk je dus
# vanzelf met de verse bots. Met -Referentie <map> kies je er zelf een.
#
# Gebruik: .\tools\balans\meet_variant.ps1 -Variant <naam>[,<naam>...] [-Procs 24] [-Referentie results\<map>]
#   bv. -Variant leeuw_cp4,leeuw_cp8   (naam = wat na "v437_matrix_" staat)
param(
    [Parameter(Mandatory = $true)]
    [string[]]$Variant,
    [int]$Procs = 24,
    [string]$Referentie = ""
)
$ErrorActionPreference = "Continue"
Set-Location (Join-Path $PSScriptRoot "..\..")
$stamp = Get-Date -Format "yyyyMMdd_HHmm"
$log = "results/variant_$($Variant -join '+')_$stamp.log"
function Log([string]$msg) {
    $regel = "{0:HH:mm:ss} {1}" -f (Get-Date), $msg
    Write-Host $regel
    Add-Content -Encoding utf8 -Path $log -Value $regel
}

foreach ($v in $Variant) {
    $cfg = "arena/arena_configs/varianten/v437_matrix_$v.json"
    if (-not (Test-Path $cfg)) {
        Log "[METING] GEEN CONFIG: $cfg"
        $namen = (Get-ChildItem "arena/arena_configs/varianten" -Filter "v437_matrix_*.json" |
            ForEach-Object { $_.BaseName -replace "^v437_matrix_", "" }) -join ", "
        Log "[METING] beschikbare varianten: $namen"
        continue
    }
    $naam = "variant_${v}_$stamp"
    Log "[METING] arena: variant $v, 5 potjes per paar, $Procs processen -> results/$naam"
    & .\arena.ps1 -Config $cfg -Procs $Procs -Naam $naam 2>&1 | ForEach-Object { Log "[ARENA] $_" }
    $n = 0
    if (Test-Path "results/$naam/games.jsonl") { $n = (Get-Content "results/$naam/games.jsonl" | Measure-Object -Line).Lines - 1 }
    Log "[METING] $v klaar: $n partijen"
    $ref = $Referentie
    if (-not $ref) {
        $r = Get-ChildItem "results" -Directory -Filter "nacht_*_v42_matrix_l2" |
            Where-Object { Test-Path (Join-Path $_.FullName "games.jsonl") } |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($r) { $ref = "results/" + $r.Name }
    }
    Log "[METING] ijkpunt: $ref"
    python tools/dashboard/compare_runs.py $ref "results/$naam" 2>&1 | ForEach-Object { Log "[VS $v] $_" }
}
Log "[METING] klaar -> $log"

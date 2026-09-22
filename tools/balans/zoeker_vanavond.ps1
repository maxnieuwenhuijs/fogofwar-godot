# Fog of War - de factiezoeker klaarzetten voor een avond (22 september).
#
# Doet drie dingen achter elkaar, zodat je maar een keer hoeft te drukken:
#   1. wacht tot er geen arena- of trainingsprocessen meer draaien (de zoeker
#      naast een andere meting zetten maakt allebei twee keer zo traag);
#   2. kiest de factie die in -Achtergrond het VERST van 50% staat, tenzij je
#      hem met -Facties zelf noemt (namen of enum-nummers, komma's ertussen);
#   3. start `factiezoeker.py` gericht op die factie met die matrix als
#      achtergrond: alleen de 11 paren met de factie worden gespeeld, de
#      overige 25 komen uit het bestand (ruim drie keer sneller).
#
# De zoeker raakt het spel NIET aan: hij schrijft `voorstel.json` en een log
# per kandidaat in `results/facties_<stempel>/`. Een voorstel gaat daarna
# eerst door een controlemeting (zie meet_c23_leeuw3.ps1 / meet_leeuw_bonus.ps1)
# voordat er iets in `rules_v42_campaign.json` verandert.
#
# LET OP (22 september): zijn knoppen zijn GROF. Een kaart erbij is ~25 pp,
# dus voor een correctie van tien punten is `budget_bonus` (C11-startpunten,
# `zet_budget_bonus.py`) de betere knop; die zit NIET in zijn zoekruimte.
#
# Gebruik: .\tools\balans\zoeker_vanavond.ps1 [-Minuten 240] [-Facties leeuw]
#          [-Achtergrond results\<run>\games.jsonl] [-Potjes 3] [-Procs 5]
param(
    [int]$Minuten = 240,
    [string]$Facties = "",
    [string]$Achtergrond = "",
    [int]$Potjes = 3,
    [int]$Procs = 5,
    [switch]$NietWachten
)
$ErrorActionPreference = "Continue"
Set-Location (Join-Path $PSScriptRoot "..\..")
$stamp = Get-Date -Format "yyyyMMdd_HHmm"
$log = "results/zoeker_$stamp.log"
function Log([string]$msg) {
    $regel = "{0:HH:mm:ss} {1}" -f (Get-Date), $msg
    Write-Host $regel
    Add-Content -Encoding utf8 -Path $log -Value $regel
}

if (-not $NietWachten) {
    Log "[ZOEKER] wacht tot arena en trainers klaar zijn"
    while (@(Get-CimInstance Win32_Process -Filter "Name like 'Godot%'" | Where-Object {
                $_.CommandLine -like "*arena.tscn*" -or $_.CommandLine -like "*-- train *" }).Count -gt 0) {
        Start-Sleep -Seconds 30
    }
}

# Achtergrond: standaard de nieuwste run met een volledige 36-paren-matrix.
if (-not $Achtergrond) {
    $kandidaat = Get-ChildItem "results" -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName "games.jsonl") } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $kandidaat) { Log "[ZOEKER] geen enkele run met games.jsonl gevonden"; exit 1 }
    $Achtergrond = (Resolve-Path (Join-Path $kandidaat.FullName "games.jsonl") -Relative) -replace '^\.\\',''
}
Log "[ZOEKER] achtergrond: $Achtergrond"

# Welke factie? Zonder -Facties: die het verst van 50% staat in de achtergrond.
if (-not $Facties) {
    $Facties = (python tools/balans/verste_factie.py $Achtergrond) 2>&1 | Select-Object -Last 1
    if (-not $Facties -or $Facties -notmatch '^\d$') { Log "[ZOEKER] kon de factie niet bepalen ($Facties)"; exit 1 }
}
Log "[ZOEKER] gericht op factie $Facties, $Minuten minuten, $Potjes potjes x $Procs processen"
python -u tools/balans/factiezoeker.py --minuten $Minuten --potjes $Potjes --procs $Procs `
    --facties $Facties --achtergrond $Achtergrond 2>&1 | ForEach-Object { Log "[FACTIES] $_" }
Log "[ZOEKER] klaar -> $log (voorstel: results/facties_*/voorstel.json)"

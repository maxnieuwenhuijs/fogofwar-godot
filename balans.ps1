# Fog of War - starter voor de twee balans-zoekers.
#
# Waarom een apart script: het paneel riep python eerder aan via een lange
# -Command string met aanhalingstekens erin, en die raakte onderweg zijn pad
# kwijt ("can't find '__main__' module"). Zoals de andere knoppen: een klein
# script starten met -File is eenvoudig en gaat niet stuk op quoting.
#
# Gebruik:
#   .\balans.ps1 -Soort regels  -Minuten 60  -Potjes 2
#   .\balans.ps1 -Soort facties -Minuten 360 -Potjes 2 -Facties "2,3"
param(
    [ValidateSet("regels", "facties")]
    [string]$Soort = "regels",
    [int]$Minuten = 60,
    [int]$Potjes = 2,
    [int]$Kandidaten = 6,
    [int]$Procs = 3,
    [string]$Facties = ""
)
$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
$script = if ($Soort -eq "facties") { "tools\balans\factiezoeker.py" } else { "tools\balans\regelzoeker.py" }
$pad = Join-Path $repo $script
if (-not (Test-Path $pad)) {
    Write-Host "Niet gevonden: $pad" -ForegroundColor Red
    Read-Host "Enter om te sluiten"
    exit 1
}
$argumenten = @($pad, "--minuten", $Minuten, "--potjes", $Potjes,
                "--kandidaten", $Kandidaten, "--procs", $Procs)
if ($Facties -ne "") { $argumenten += @("--facties", $Facties) }

Write-Host ""
Write-Host "Fog of War - $Soort uitproberen" -ForegroundColor Cyan
Write-Host "  $Minuten minuten - $Potjes potje(s) per matchup x $Procs processen - $Kandidaten kandidaten"
if ($Facties -ne "") { Write-Host "  alleen factie(s): $Facties" }
Write-Host "  Dit verandert NIETS aan het spel: het voorstel komt in results\ te staan."
Write-Host ""
Push-Location $repo
& python @argumenten
Pop-Location
Write-Host ""
Read-Host "Klaar - druk op Enter om te sluiten"

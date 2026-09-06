<#
.SYNOPSIS
  Bouwt het server-pakket (F4.4a): alleen wat de scheidsrechter
  (tools/server_worker.tscn) nodig heeft, zonder modellen, geluiden en muziek.

.DESCRIPTION
  Het volle project is 4,7 GB en de Godot-import ervan piekt op 7,5 GB
  werkgeheugen; de worker gebruikt daar niets van. Dit pakket is ~2 MB,
  importeert in seconden en geeft dezelfde core-hash (bewezen met -Proef).

  Uitvoer: results/serverpakket/ (map) en results/serverpakket.tgz.

  -Proef  importeert het pakket, start er een worker uit en vergelijkt de
          core-hash en de init-hash met een worker uit het volle project.
          Exit 1 bij verschil. Draai dit voor elke uitrol (deploy-server.ps1
          doet het vanzelf).

.EXAMPLE
  .\tools\deploy\bouw_serverpakket.ps1 -Proef
#>
param(
    [switch]$Proef,
    [string]$Uit = "results/serverpakket"
)
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$doel = Join-Path $root $Uit
$results = Split-Path $doel -Parent
$regels = Join-Path $root "arena\arena_configs\rules_v42_campaign.json"

# Wat gaat er mee: de engine (core/), de autoloads en kernscripts (scripts/),
# de bots (agents/, voor de loopback-tests en straks de botclient), de
# netlaag (net/), de regelbestanden (arena/), vertalingen (i18n/),
# gewichten (data/), en van tools/ alleen de worker zelf.
$mappen = @("core", "scripts", "agents", "net", "arena", "i18n", "data")
$losse = @("project.godot", "icon.svg", "icon.svg.import")
$toolBestanden = @("server_worker.gd", "server_worker.gd.uid", "server_worker.tscn")
# Niet mee: scripts/game/game.gd (preloadt Board.tscn en daarmee het hele 3D-bord;
# de worker praat er nooit mee) en de scenes/ (schermen).
$weglaten = @("scripts\game\game.gd", "scripts\game\game.gd.uid")

if (Test-Path $doel) { Remove-Item -Recurse -Force $doel }
New-Item -ItemType Directory -Force $doel | Out-Null
foreach ($m in $mappen) {
    Copy-Item -Recurse (Join-Path $root $m) (Join-Path $doel $m)
}
New-Item -ItemType Directory -Force (Join-Path $doel "tools") | Out-Null
foreach ($f in $toolBestanden) {
    Copy-Item (Join-Path $root "tools\$f") (Join-Path $doel "tools\$f")
}
foreach ($f in $losse) {
    Copy-Item (Join-Path $root $f) (Join-Path $doel $f)
}
foreach ($w in $weglaten) {
    $p = Join-Path $doel $w
    if (Test-Path $p) { Remove-Item -Force $p }
}
Get-ChildItem $doel -Recurse -Directory -Filter "__pycache__" | Remove-Item -Recurse -Force
Get-ChildItem $doel -Recurse -File -Include "*.pyc", "*.log", "*.bak" | Remove-Item -Force

$tgz = "$doel.tgz"
if (Test-Path $tgz) { Remove-Item -Force $tgz }
# tar zit standaard op Windows 10+ (bsdtar); -C houdt de paden relatief.
& tar -czf $tgz -C $results (Split-Path $doel -Leaf)
if ($LASTEXITCODE -ne 0) { throw "tar mislukte ($LASTEXITCODE)" }
$mb = [math]::Round((Get-Item $tgz).Length / 1MB, 2)
$aantal = (Get-ChildItem $doel -Recurse -File | Measure-Object).Count
Write-Host "Pakket: $tgz ($mb MB, $aantal bestanden) uit $doel"

if (-not $Proef) { exit 0 }

# ---- Proef: importeren, worker starten, hashes vergelijken -------------------
$godot = $env:GODOT_PATH
if (-not $godot) {
    $kandidaat = "C:\Users\maxni\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe"
    if (-not (Test-Path $kandidaat)) { $kandidaat = $kandidaat -replace "_console", "" }
    $godot = $kandidaat
}
if (-not (Test-Path $godot)) { throw "Godot niet gevonden: zet GODOT_PATH ($godot)" }

$importLog = Join-Path $results "serverpakket_import.log"
$imp = Start-Process -FilePath $godot -ArgumentList @("--headless", "--path", "`"$doel`"", "--import") `
    -Wait -PassThru -NoNewWindow -RedirectStandardOutput $importLog -RedirectStandardError "$importLog.err"
$fouten = @(Select-String -Path $importLog, "$importLog.err" -Pattern "SCRIPT ERROR|Failed to load|Parse Error" -ErrorAction SilentlyContinue)
if ($imp.ExitCode -ne 0 -or $fouten.Count -gt 0) {
    Write-Host "Import van het pakket gaf fouten (exit $($imp.ExitCode)):"
    $fouten | ForEach-Object { Write-Host "  $($_.Line)" }
    exit 1
}
Write-Host "Import van het pakket: schoon (exit 0, geen scriptfouten)"

function Proef-Worker([string]$Pad, [string]$Naam) {
    $poort = Get-Random -Minimum 9400 -Maximum 9499
    $log = Join-Path $results "serverpakket_worker_$Naam.log"
    $env:FOW_WORKER = "1"
    try {
        $p = Start-Process -FilePath $godot -ArgumentList @("--headless", "--path", "`"$Pad`"", "res://tools/server_worker.tscn", "--", "poort=$poort") `
            -PassThru -NoNewWindow -RedirectStandardOutput $log -RedirectStandardError "$log.err"
    } finally {
        Remove-Item Env:FOW_WORKER -ErrorAction SilentlyContinue
    }
    $uit = & node (Join-Path $PSScriptRoot "worker_proef.mjs") $poort $regels
    if (-not $p.HasExited) {
        Wait-Process -Id $p.Id -Timeout 10 -ErrorAction SilentlyContinue
        if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
    }
    $regelsUit = @($uit | Where-Object { $_ -like "{*" })
    if ($regelsUit.Count -eq 0) { throw "worker_proef gaf geen JSON ($Naam): $uit" }
    return ($regelsUit[-1] | ConvertFrom-Json)
}

$vanPakket = Proef-Worker $doel "pakket"
$vanRepo = Proef-Worker $root "repo"
Write-Host ("pakket: ok={0} core_hash={1} init_hash={2}" -f $vanPakket.ok, $vanPakket.core_hash, $vanPakket.init_hash)
Write-Host ("repo:   ok={0} core_hash={1} init_hash={2}" -f $vanRepo.ok, $vanRepo.core_hash, $vanRepo.init_hash)
$goed = $vanPakket.ok -and $vanRepo.ok -and ($vanPakket.core_hash -eq $vanRepo.core_hash) -and ($vanPakket.init_hash -eq $vanRepo.init_hash)
if (-not $goed) {
    Write-Host "PROEF MISLUKT: het pakket geeft niet dezelfde scheidsrechter als het volle project."
    exit 1
}
Write-Host "PROEF OK: pakket en volle project geven dezelfde core-hash en init-hash."
exit 0

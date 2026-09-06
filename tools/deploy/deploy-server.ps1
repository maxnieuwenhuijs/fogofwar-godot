<#
.SYNOPSIS
  Rolt de backend uit naar de droplet (F4.4a): engine-pakket + server-code
  per scp, dan op de droplet importeren, bouwen en herstarten.

.DESCRIPTION
  Vereist een droplet die eenmalig is ingericht met droplet-setup.sh (zie
  tools/deploy/README.md) en ssh-toegang met je sleutel. Stappen:
    1. bouw_serverpakket.ps1 -Proef  (pakket + bewijs zelfde core-hash)
    2. server-bron inpakken (src, db, package*.json, tsconfig*)
    3. scp naar /tmp op de droplet
    4. ssh: op-droplet-uitrollen.sh (import, npm ci, build, herstart, gezond?)
    5. GET /versie via de publieke url
    6. -Nettest: het 13-stappen contract (capture -- nettest) tegen de droplet

  Uitrollen = enkele seconden geen server (herstart). Niet midden in een
  playtest doen; lopende partijen staan in de database en zijn daarna
  gewoon te hervatten.

.PARAMETER Droplet
  ssh-doel: hostnaam of IP van de droplet (bv. fog.example.nl of 164.92.1.2).
.PARAMETER Gebruiker
  ssh-gebruiker (standaard root; het script op de droplet draait met sudo).
.PARAMETER Url
  Publieke url voor de versiecheck en de nettest (standaard https://<Droplet>).
.PARAMETER Nettest
  Draai na de uitrol `capture -- nettest <Url>` (13 stappen).
.PARAMETER ZonderProef
  Sla de lokale proef van het pakket over (alleen als je haast hebt).

.EXAMPLE
  .\tools\deploy\deploy-server.ps1 -Droplet fog.example.nl -Nettest
#>
param(
    [Parameter(Mandatory = $true)][string]$Droplet,
    [string]$Gebruiker = "root",
    [string]$Url = "",
    [switch]$Nettest,
    [switch]$ZonderProef
)
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$results = Join-Path $root "results"
if ($Url -eq "") { $Url = "https://$Droplet" }
$Url = $Url.TrimEnd("/")

# 1. pakket
if ($ZonderProef) {
    & (Join-Path $PSScriptRoot "bouw_serverpakket.ps1")
} else {
    & (Join-Path $PSScriptRoot "bouw_serverpakket.ps1") -Proef
}
if ($LASTEXITCODE -ne 0) { throw "pakket bouwen/proef mislukt ($LASTEXITCODE)" }
$pakket = Join-Path $results "serverpakket.tgz"

# 2. server-bron (zonder node_modules, tests en .env)
$bron = Join-Path $results "serverbron.tgz"
if (Test-Path $bron) { Remove-Item -Force $bron }
& tar -czf $bron -C (Join-Path $root "server") src db package.json package-lock.json tsconfig.json tsconfig.build.json
if ($LASTEXITCODE -ne 0) { throw "server-bron inpakken mislukte ($LASTEXITCODE)" }

# 3. omhoog
$doel = "$Gebruiker@$Droplet"
Write-Host "scp naar $doel ..."
& scp -q $pakket $bron (Join-Path $PSScriptRoot "op-droplet-uitrollen.sh") "${doel}:/tmp/"
if ($LASTEXITCODE -ne 0) { throw "scp mislukte ($LASTEXITCODE)" }

# 4. op de droplet
Write-Host "uitrollen op $Droplet ..."
& ssh $doel "sudo bash /tmp/op-droplet-uitrollen.sh /tmp/serverpakket.tgz /tmp/serverbron.tgz"
if ($LASTEXITCODE -ne 0) { throw "uitrollen op de droplet mislukte ($LASTEXITCODE); zie de uitvoer hierboven" }

# 5. publieke versiecheck
try {
    $versie = Invoke-RestMethod -Uri "$Url/versie" -TimeoutSec 15
    Write-Host "publiek: $Url/versie -> core_hash=$($versie.core_hash)"
} catch {
    Write-Host "LET OP: $Url/versie niet bereikbaar ($($_.Exception.Message)). DNS/TLS al goed? Lokaal op de droplet was hij gezond."
}

# 6. nettest
if ($Nettest) {
    $godot = $env:GODOT_PATH
    if (-not $godot) {
        $kandidaat = "C:\Users\maxni\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe"
        if (-not (Test-Path $kandidaat)) { $kandidaat = $kandidaat -replace "_console", "" }
        $godot = $kandidaat
    }
    Write-Host "nettest tegen $Url ..."
    # Als array, zodat PowerShell het losse "--" letterlijk doorgeeft.
    & $godot @("--headless", "--path", $root, "res://tools/capture.tscn", "--", "nettest", $Url)
}

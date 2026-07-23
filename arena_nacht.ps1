# Fog of War - nachtjob (F1.5): git pull -> fuzz -> arena (tijdgebonden,
# multi-proces) -> dashboard -> summary. Draait via Windows Taakplanner
# (tools/register_nachtjob.ps1); verhuist in F4 naar een VPS-cron. Geen n8n (B5).
#
# Gebruik: .\arena_nacht.ps1 [-DuurMinuten 480] [-Procs 0] [-FuzzGames 10000] [-Kort]
#   -Kort = smoke-run voor de end-to-end-check: 1 arena-batch + 100 fuzz-games.
param(
    [int]$DuurMinuten = 480,
    [int]$Procs = 0,
    [int]$FuzzGames = 10000,
    [string]$Config = "arena/arena_configs/matrix_l1.json",
    [switch]$Kort
)
$ErrorActionPreference = "Continue"
Set-Location $PSScriptRoot
$godot = $env:GODOT_PATH
if (-not $godot) { $godot = "C:\Users\maxni\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe" }
if ($Procs -le 0) { $Procs = [Math]::Max(1, [Environment]::ProcessorCount - 2) }
if ($Kort) { $DuurMinuten = 1; $FuzzGames = 100 }

$stamp = Get-Date -Format "yyyyMMdd_HHmm"
$uit = "results/nacht_$stamp"
New-Item -ItemType Directory -Force -Path $uit | Out-Null
$logPad = "$uit/nacht.log"
$t0 = Get-Date
function Log([string]$msg) {
    $regel = "{0:HH:mm:ss} {1}" -f (Get-Date), $msg
    Write-Host $regel
    Add-Content -Encoding utf8 -Path $logPad -Value $regel
}
Log "[NACHT] start -> $uit (procs=$Procs, duur=${DuurMinuten}m, fuzz=$FuzzGames)"

# 1) Verse code (ff-only: nooit een merge-commit vanuit een job).
git pull --ff-only 2>&1 | ForEach-Object { Log "[GIT] $_" }
$sha = (git rev-parse --short HEAD) 2>$null
Log "[NACHT] git-sha $sha"

# 2) Fuzz-vangnet eerst: schendingen -> repro's in results/fuzz/ + exitcode 1.
$fuzzSeed = [int]([DateTimeOffset]::Now.ToUnixTimeSeconds() % 1000000000)
$fuzzProc = Start-Process -FilePath $godot -PassThru -NoNewWindow -Wait `
    -RedirectStandardOutput "$uit/fuzz.log" -ArgumentList @(
    "--headless", "--path", ".", "res://arena/arena.tscn", "--",
    "--fuzz", "$FuzzGames", "$fuzzSeed")
$fuzzOk = ($fuzzProc.ExitCode -eq 0)
Get-Content "$uit/fuzz.log" | Where-Object { $_ -match "\[FUZZ" } | ForEach-Object { Log $_ }
if (-not $fuzzOk) { Log "[NACHT] LET OP: fuzz vond schendingen (zie results/fuzz/ voor repro's)" }

# 3) Arena, tijdgebonden: batches van $Procs parallelle matrix-runs tot de
# deadline. Elke batch/proc krijgt een unieke seed-offset (nacht-epoch erin,
# zodat elke nacht verse seeds loot; de offset staat in run_meta = reproduceerbaar).
$deadline = $t0.AddMinutes($DuurMinuten)
$nachtOffset = [long]([DateTimeOffset]::Now.ToUnixTimeSeconds() % 100000) * 10000000
$batch = 0
$totaalGames = 0
while ($true) {
    $batchProcs = @()
    for ($i = 0; $i -lt $Procs; $i++) {
        $sub = "$uit/b${batch}_p$i"
        $offset = $nachtOffset + ([long]($batch * $Procs + $i)) * 100000
        $batchProcs += Start-Process -FilePath $godot -PassThru -WindowStyle Hidden -ArgumentList @(
            "--headless", "--path", ".", "res://arena/arena.tscn", "--",
            "--config", $Config, "--out", $sub, "--seed-offset", "$offset")
    }
    $batchProcs | Wait-Process
    $batch++
    Log "[NACHT] arena-batch $batch klaar ($Procs procs)"
    if ((Get-Date) -ge $deadline) { break }
    if ($Kort) { break }
}

# 4) Samenvoegen tot 1 games.jsonl voor deze nachtrun (header 1x).
$doel = "$uit/games.jsonl"
$eerste = $true
Get-ChildItem -Path $uit -Recurse -Filter "games.jsonl" | Where-Object { $_.FullName -ne (Resolve-Path $doel -ErrorAction SilentlyContinue).Path } | ForEach-Object {
    if ($eerste) {
        Get-Content $_.FullName -TotalCount 1 | Set-Content -Encoding utf8 $doel
        $eerste = $false
    }
    Get-Content $_.FullName | Select-Object -Skip 1 | Add-Content -Encoding utf8 $doel
}
if (Test-Path $doel) {
    $totaalGames = (Get-Content $doel | Measure-Object -Line).Lines - 1
    # Submappen opruimen: alles zit nu in de samengevoegde games.jsonl.
    Get-ChildItem -Path $uit -Directory | Remove-Item -Recurse -Force -Confirm:$false
}

# 5) Dashboard verversen.
python tools/dashboard/build_dashboard.py 2>&1 | ForEach-Object { Log $_ }

# 6) Capaciteitslog + samenvatting (de "echte 8-uurs-meting" van F1.3/F1.5).
$duurSec = ((Get-Date) - $t0).TotalSeconds
$perSec = 0.0
if ($duurSec -gt 0) { $perSec = [Math]::Round($totaalGames / $duurSec, 2) }
$fuzzTekst = "schoon"
if (-not $fuzzOk) { $fuzzTekst = "SCHENDINGEN (results/fuzz/)" }
$samenvatting = @(
    "Fog of War nachtrun $stamp (git $sha)",
    ("arena : {0} partijen in {1:N0} s over {2} batches x {3} procs = {4} match/s totaal" -f $totaalGames, $duurSec, $batch, $Procs, $perSec),
    "fuzz  : $FuzzGames partijen, $fuzzTekst",
    "output: $doel + results/dashboard.html"
)
$samenvatting | Set-Content -Encoding utf8 "$uit/summary.txt"
$samenvatting | ForEach-Object { Log "[SUMMARY] $_" }
Log "[NACHT] klaar"

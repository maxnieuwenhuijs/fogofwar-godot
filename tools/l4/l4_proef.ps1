# L4 neuraal: een proefronde op de regels en bots van NU (3 oktober, marathon;
# Max: "misschien ook het neural net gebruiken om ze ultiem te maken").
#
# Het netwerk van 22 september imiteert de L2-gewichten van toen; sindsdien
# zijn regels (C26-C30) en bots veranderd. Deze ronde bouwt alles opnieuw,
# zonder data/ai_net*.json aan te raken:
#   1. L2 tegen L2 met beslislog (arena_configs/l2_beslislog.json)
#   2. scorenetwerk (imitatie 1, uitslag 0,5) en waardenetwerk (imitatie 0,
#      uitslag 1) in results/l4_proef_<stempel>/
#   3. netcheck (pariteit GDScript/Python, legaliteit)
#   4. L4 tegen L2 in beide kleuren, en tools/l4/meet_l4.py
# Alleen als L4 duidelijk boven 50% uitkomt is het de moeite van een
# volgende stap waard (selfplay, of L4 in het spel). 22 september: 49%.
#
# Gebruik: .\tools\l4\l4_proef.ps1 [-Procs 12]
param(
    [int]$Procs = 12
)
$ErrorActionPreference = "Continue"
Set-Location (Join-Path $PSScriptRoot "..\..")
$repo = (Get-Location).Path
$godot = $env:GODOT_PATH
if (-not $godot) { $godot = "C:\Users\maxni\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe" }
$console = $godot -replace "\.exe$", "_console.exe"
if (-not (Test-Path $console)) { $console = $godot }
$stempel = Get-Date -Format "yyyyMMdd_HHmm"
$map = "results/l4_proef_$stempel"
New-Item -ItemType Directory -Force -Path $map | Out-Null
$log = "$map/proef.log"
$zonderBom = New-Object System.Text.UTF8Encoding $false

function Log([string]$msg) {
    $regel = "{0:yyyy-MM-dd HH:mm:ss} {1}" -f (Get-Date), $msg
    Write-Host $regel
    for ($i = 0; $i -lt 10; $i++) {
        try { [IO.File]::AppendAllText((Join-Path $repo $log), $regel + "`r`n", $zonderBom); return }
        catch { Start-Sleep -Milliseconds 500 }
    }
}

$data = "l2_log_$stempel"
Log "[L4] 1/4 L2 tegen L2 met beslislog ($Procs processen) -> results/$data"
& .\arena.ps1 -Config arena/arena_configs/l2_beslislog.json -Procs $Procs -Naam $data *> $null

Log "[L4] 2/4 netwerken trainen"
& python tools/l4/train_net.py "results/$data" --uit "$map/score.json" 2>&1 | Select-Object -Last 5 | ForEach-Object { Log "[SCORE] $_" }
& python tools/l4/train_net.py "results/$data" --uit "$map/waarde.json" --imitatie 0 --uitslag 1 --epochs 20 2>&1 |
    Select-Object -Last 5 | ForEach-Object { Log "[WAARDE] $_" }

Log "[L4] 3/4 netcheck"
& $console --headless --path . res://tools/capture.tscn -- netcheck "net=res://$map/score.json" "waarde=res://$map/waarde.json" 2>&1 |
    Select-String "NETCHECK" | ForEach-Object { Log "[NETCHECK] $_" }

Log "[L4] 4/4 L4 tegen L2, beide kleuren"
$label = "l4:res://$map/score.json+res://$map/waarde.json"
$metingen = @()
foreach ($kant in @("p1", "p2")) {
    $bron = if ($kant -eq "p1") { "arena/arena_configs/l4_vs_l2.json" } else { "arena/arena_configs/l2_vs_l4.json" }
    $cfg = Get-Content $bron -Raw | ConvertFrom-Json
    $cfg.agents.$kant = $label
    $cfgPad = "$map/meet_$kant.json"
    [IO.File]::WriteAllText((Join-Path $repo $cfgPad), ($cfg | ConvertTo-Json -Depth 6), $zonderBom)
    $naam = "l4_proef_meet_${kant}_$stempel"
    & .\arena.ps1 -Config $cfgPad -Procs $Procs -Naam $naam *> $null
    $metingen += "results/$naam"
}
& python tools/l4/meet_l4.py @metingen 2>&1 | ForEach-Object { Log "[MEET] $_" }
Log "[L4] klaar -> $map"

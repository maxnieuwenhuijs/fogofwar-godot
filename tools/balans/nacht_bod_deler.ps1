# Fog of War - trainingsnacht op de geldende regels plus een gepaarde meting
# van de deler van het initiatief-bod (7 oktober, Max: "doe maar een nacht
# trainen toch", na 4.3.10).
#
# 1) training_nacht.ps1: zes trainers op rules_v42_campaign.json (4.3.10),
#    dan de nachtmatrix en het dashboard (zoals de paneelknop TRAINING-NACHT)
# 2) meet_variant.ps1 bod_tegen,bod_kaarten: dezelfde verse bots en dezelfde
#    seeds, alleen de deler anders (4.3.10 "tegenstander" tegen 4.3.8
#    "kaarten"); 2 potjes per paar, 1728 partijen per kant
# 3) compare_runs.py tussen die twee: het effect van alleen de regel, gepaard
#    (docs/lessen-trainingsmarathon.md: meet een regel gepaard, nooit van
#    nacht tot nacht, en nooit tijdens een trainersessie)
#
# Gebruik: .\tools\balans\nacht_bod_deler.ps1 [-TrainMinuten 420] [-Procs 24]
# Log: results\nacht_bod_deler_<stempel>.log
param(
    [int]$TrainMinuten = 420,
    [int]$Procs = 24
)
$ErrorActionPreference = "Continue"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $repo
$stamp = Get-Date -Format "yyyyMMdd_HHmm"
$log = Join-Path $repo "results\nacht_bod_deler_$stamp.log"
function Log([string]$msg) {
    $regel = "{0:HH:mm:ss} {1}`r`n" -f (Get-Date), $msg
    for ($i = 0; $i -lt 5; $i++) {
        try { [IO.File]::AppendAllText($log, $regel); break } catch { Start-Sleep -Milliseconds 200 }
    }
}

$sha = (git rev-parse --short HEAD) 2>$null
Log "[BOD] start op ${sha}: trainingsnacht ($TrainMinuten min training), dan de gepaarde meting"
& powershell -NoProfile -ExecutionPolicy Bypass -File "$repo\training_nacht.ps1" -TrainMinuten $TrainMinuten
$nacht = Get-ChildItem "results" -Directory -Filter "nacht_*_v42_matrix_l2" |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
Log "[BOD] trainingsnacht klaar (nachtmatrix: results/$($nacht.Name))"

Log "[BOD] gepaarde meting: bod_tegen (4.3.10) en bod_kaarten (4.3.8), $Procs processen"
& powershell -NoProfile -ExecutionPolicy Bypass -File "$repo\tools\balans\meet_variant.ps1" `
    -Variant "bod_tegen,bod_kaarten" -Procs $Procs
$tegen = Get-ChildItem "results" -Directory -Filter "variant_bod_tegen_*" |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
$kaarten = Get-ChildItem "results" -Directory -Filter "variant_bod_kaarten_*" |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($tegen -and $kaarten) {
    Log "[BOD] vergelijking: A = results/$($kaarten.Name) (4.3.8, oud), B = results/$($tegen.Name) (4.3.10, nieuw)"
    python tools/dashboard/compare_runs.py "results/$($kaarten.Name)" "results/$($tegen.Name)" 2>&1 |
        ForEach-Object { Log "[BOD VS] $_" }
} else {
    Log "[BOD] FOUT: variantmappen niet gevonden (tegen: $tegen, kaarten: $kaarten)"
}
Log "[BOD] klaar"

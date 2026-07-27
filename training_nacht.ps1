# Fog of War - VOLLE TRAINING-NACHT (besluit Max 27-07: een knop, alles vanzelf):
# 1) 6 parallelle v4.2-trainers (campagne-fitness, wanhoop-modus, logbestanden)
# 2) wachten tot alle trainers klaar zijn
# 3) automatisch een arena-meting (4.1 + v4.2 matrix) over de NIEUWE gewichten
# 4) dashboard verversen -> results\dashboard.html staat 's ochtends klaar
param(
    [int]$TrainMinuten = 420,
    [int]$ArenaMinuten = 60
)
$repo = $PSScriptRoot
Set-Location $repo
$godot = $env:GODOT_PATH
if (-not $godot) { $godot = "C:\Users\maxni\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe" }
$console = $godot -replace "\.exe$", "_console.exe"
if (-not (Test-Path $console)) { $console = $godot }

$stamp = Get-Date -Format "yyyyMMdd_HHmm"
$logmap = Join-Path $repo ("results\training_" + $stamp)
New-Item -ItemType Directory -Force $logmap | Out-Null
$basisSeed = [int]([DateTimeOffset]::Now.ToUnixTimeSeconds() % 900000000)

$procs = @()
$i = 0
foreach ($f in @("mens", "muis", "leeuw", "beer", "wolf", "vos")) {
    $trainArgs = @("--headless", "--path", ".", "res://tools/capture.tscn", "--",
        "train", $TrainMinuten, 6, 6, $f, ($basisSeed + $i),
        "arena/arena_configs/rules_v42_campaign.json")
    $procs += Start-Process $console -WorkingDirectory $repo -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $logmap "train_$f.log") `
        -RedirectStandardError (Join-Path $logmap "train_$f.fouten.log") `
        -ArgumentList $trainArgs
    $i += 1
}
"[NACHT] $($procs.Count) trainers gestart ($TrainMinuten min budget); logs in $logmap" |
    Out-File (Join-Path $logmap "pijplijn.log") -Encoding utf8

# Wachten tot ALLE trainers klaar zijn (budget stopt nieuwe generaties;
# een lopende generatie maakt zichzelf af, dus dit kan ~15 min uitlopen).
$procs | Wait-Process
"[NACHT] trainers klaar om $(Get-Date -Format HH:mm) - arena-meting starten" |
    Out-File (Join-Path $logmap "pijplijn.log") -Append -Encoding utf8

# Arena-meting over de verse gewichten (4.1- en v4.2-matrix om-en-om).
& powershell -NoProfile -ExecutionPolicy Bypass -File "$repo\arena_nacht.ps1" `
    -DuurMinuten $ArenaMinuten -FuzzGames 500

# Dashboard verversen zodat de ochtendkoffie meteen cijfers heeft.
try { & python "$repo\tools\dashboard\build_dashboard.py" | Out-Null } catch {}
"[NACHT] klaar om $(Get-Date -Format HH:mm) - dashboard ververst" |
    Out-File (Join-Path $logmap "pijplijn.log") -Append -Encoding utf8

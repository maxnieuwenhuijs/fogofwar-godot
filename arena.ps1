# Fog of War - arena multi-proces-launcher (F1.2)
# Gebruik: .\arena.ps1 [-Config arena/arena_configs/matrix_l1.json] [-Procs 0] [-Naam run1]
# Procs 0 = automatisch (cores - 1). Elk proces krijgt een eigen seed-offset
# en submap; na afloop worden de games.jsonl-bestanden samengevoegd.
param(
    [string]$Config = "arena/arena_configs/matrix_l1.json",
    [int]$Procs = 0,
    [string]$Naam = ""
)
$godot = $env:GODOT_PATH
if (-not $godot) { $godot = "C:\Users\maxni\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe" }
if ($Procs -le 0) { $Procs = [Math]::Max(1, [Environment]::ProcessorCount - 1) }
if (-not $Naam) { $Naam = Get-Date -Format "yyyyMMdd_HHmmss" }
$uit = "results/$Naam"
New-Item -ItemType Directory -Force -Path $uit | Out-Null
Write-Host "[ARENA.PS1] $Procs processen -> $uit (config: $Config)"
$jobs = @()
for ($i = 0; $i -lt $Procs; $i++) {
    $sub = "$uit/proc$i"
    $offset = $i * 100000
    $jobs += Start-Process -FilePath $godot -PassThru -NoNewWindow -ArgumentList @(
        "--headless", "--path", ".", "res://arena/arena.tscn", "--",
        "--config", $Config, "--out", $sub, "--seed-offset", "$offset")
}
$jobs | Wait-Process
# Samenvoegen: header van proc0, daarna alle game-regels.
$doel = "$uit/games.jsonl"
Get-Content "$uit/proc0/games.jsonl" -TotalCount 1 | Set-Content -Encoding utf8 $doel
for ($i = 0; $i -lt $Procs; $i++) {
    Get-Content "$uit/proc$i/games.jsonl" | Select-Object -Skip 1 | Add-Content -Encoding utf8 $doel
}
Write-Host "[ARENA.PS1] klaar -> $doel"

# Testbatterij over meerdere processen (Max, 30 juli: "kun je die batterijen
# niet wat sneller laten gaan"). Elke groep draait in een eigen Godot-proces;
# aan het eind worden de uitslagen opgeteld. Zelfde tests, zelfde uitkomst,
# alleen parallel. Gebruik: .\tests.ps1
$godot = $env:GODOT_PATH
if (-not $godot) { $godot = "C:\Users\maxni\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" }
$uit = Join-Path $env:TEMP ("fow_tests_" + (Get-Date -Format "HHmmss"))
New-Item -ItemType Directory -Force -Path $uit | Out-Null

# Groepen: de trage suites elk apart, de snelle samen. SoloTests is veruit de
# zwaarste (complete solo-campagnes), daarna CampaignTests en FuzzTests.
# SoloTests is in zijn eentje de langste: die knippen we in drieen met deel=i/n.
$groepen = @(
    "SoloTests|0/3",
    "SoloTests|1/3",
    "SoloTests|2/3",
    "CampaignTests",
    "FuzzTests",
    "AgentTests,V42AgentTests,AITests",
    "GoldenReplayTests,DeterminismTests,SerializerTests",
    "RulesTests,ValidatorTests,ReducerTests,ViewTests",
    "SpawnTests,CpTests,CannonTests,ClockTests,CardTests,GameSessionTests,RulesConfigTests"
)
$start = Get-Date
$procs = @()
for ($i = 0; $i -lt $groepen.Count; $i++) {
    $log = Join-Path $uit "groep$i.txt"
    $stuk = $groepen[$i] -split "\|"
    $args = @("--headless", "--path", ".", "res://tests/TestScene.tscn", "--", "suites=$($stuk[0])")
    if ($stuk.Count -gt 1) { $args += "deel=$($stuk[1])" }
    $procs += Start-Process -FilePath $godot -PassThru -NoNewWindow -RedirectStandardOutput $log `
        -ArgumentList $args
}
$procs | Wait-Process
$passed = 0; $failed = 0; $fouten = @()
for ($i = 0; $i -lt $groepen.Count; $i++) {
    $tekst = Get-Content (Join-Path $uit "groep$i.txt") -Raw
    if ($tekst -match "Passed: (\d+)") { $passed += [int]$Matches[1] }
    if ($tekst -match "Failed: (\d+)")  { $failed += [int]$Matches[1] }
    $inFouten = $false
    foreach ($regel in ($tekst -split "`n")) {
        if ($regel -match "^Failures:") { $inFouten = $true; continue }
        if ($inFouten -and $regel.Trim().StartsWith("- ")) { $fouten += $regel.Trim() }
    }
}
$duur = [int]((Get-Date) - $start).TotalSeconds
Write-Host ""
Write-Host "=== RESULTS (parallel, $duur s) ==="
Write-Host "Passed: $passed"
Write-Host "Failed: $failed"
if ($fouten.Count -gt 0) {
    Write-Host ""
    Write-Host "Failures:"
    $fouten | ForEach-Object { Write-Host "  $_" }
}
exit ($(if ($failed -eq 0) { 0 } else { 1 }))

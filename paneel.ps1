# Fog of War - controlepaneel (F1.6): een-klik-knoppen voor de runs.
# Starten: dubbelklik "FogOfWar Paneel.bat" (of: powershell -STA -File paneel.ps1)
# Besluit Max 23-07: niets draait automatisch — alles start vanuit dit paneel.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$repo = $PSScriptRoot
Set-Location $repo
$godot = $env:GODOT_PATH
if (-not $godot) { $godot = "C:\Users\maxni\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe" }

function Aantal-Godots {
    return @(Get-Process | Where-Object { $_.ProcessName -like "Godot*" }).Count
}

function Bevestig-BijDrukte {
    if ((Aantal-Godots) -gt 0) {
        $antwoord = [System.Windows.Forms.MessageBox]::Show(
            "Er draaien al Godot-processen. Toch nog een run starten?",
            "Fog of War", [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question)
        return ($antwoord -eq [System.Windows.Forms.DialogResult]::Yes)
    }
    return $true
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Fog of War - paneel"
$form.Size = New-Object System.Drawing.Size(400, 430)
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.StartPosition = "CenterScreen"

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Location = New-Object System.Drawing.Point(15, 12)
$lblStatus.Size = New-Object System.Drawing.Size(360, 22)
$lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($lblStatus)

function Maak-Knop([string]$tekst, [int]$y, [scriptblock]$actie) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $tekst
    $b.Location = New-Object System.Drawing.Point(15, $y)
    $b.Size = New-Object System.Drawing.Size(255, 34)
    $b.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $b.Add_Click($actie)
    $form.Controls.Add($b)
    return $b
}

function Maak-Minuten([int]$y, [int]$standaard) {
    $n = New-Object System.Windows.Forms.NumericUpDown
    $n.Location = New-Object System.Drawing.Point(280, ($y + 4))
    $n.Size = New-Object System.Drawing.Size(60, 26)
    $n.Minimum = 1
    $n.Maximum = 600
    $n.Value = $standaard
    $form.Controls.Add($n)
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "min"
    $lbl.Location = New-Object System.Drawing.Point(343, ($y + 9))
    $lbl.Size = New-Object System.Drawing.Size(35, 18)
    $form.Controls.Add($lbl)
    return $n
}

# --- Nachtrun (fuzz -> L2-arena -> dashboard), duur instelbaar ---------------
# De fuzz schaalt mee met de duur (~10% van het budget, 500-10000 partijen),
# zodat een korte run vooral arena-tijd overhoudt.
$numNacht = Maak-Minuten 45 120
$null = Maak-Knop "Nachtrun (fuzz + L2-arena)" 45 {
    if (-not (Bevestig-BijDrukte)) { return }
    $duur = [int]$numNacht.Value
    $fuzz = [Math]::Max(500, [Math]::Min(10000, $duur * 25))
    Start-Process powershell -WorkingDirectory $repo -ArgumentList @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$repo\arena_nacht.ps1",
        "-DuurMinuten", $duur, "-FuzzGames", $fuzz)
}

# --- Training (6 parallelle trainers via train_ai.bat), duur instelbaar ------
$numTrain = Maak-Minuten 90 60
$null = Maak-Knop "Training (6 facties)" 90 {
    if (-not (Bevestig-BijDrukte)) { return }
    Start-Process "$repo\train_ai.bat" -WorkingDirectory $repo -ArgumentList ([string][int]$numTrain.Value)
}

# --- Snelle arena-test (quick_l1, ~2 min) ------------------------------------
$null = Maak-Knop "Snelle arena-test (L1, ~2 min)" 135 {
    if (-not (Bevestig-BijDrukte)) { return }
    Start-Process powershell -WorkingDirectory $repo -ArgumentList @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$repo\arena.ps1",
        "-Config", "arena/arena_configs/quick_l1.json", "-Naam", ("test_" + (Get-Date -Format "HHmmss")))
}

# --- Volledige L2-matrix (~40 min) -------------------------------------------
$null = Maak-Knop "Volledige L2-matrix (~40 min)" 180 {
    if (-not (Bevestig-BijDrukte)) { return }
    Start-Process powershell -WorkingDirectory $repo -ArgumentList @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$repo\arena.ps1",
        "-Config", "arena/arena_configs/matrix_l2.json", "-Naam", ("l2matrix_" + (Get-Date -Format "MMdd_HHmm")))
}

# --- Fuzz-vangnet (500 partijen) ---------------------------------------------
$null = Maak-Knop "Fuzz-check (500 partijen)" 225 {
    if (-not (Bevestig-BijDrukte)) { return }
    Start-Process $godot -WorkingDirectory $repo -ArgumentList @(
        "--headless", "--path", ".", "res://arena/arena.tscn", "--", "--fuzz", "500")
}

# --- Dashboard bouwen + openen ------------------------------------------------
$null = Maak-Knop "Dashboard verversen + openen" 270 {
    try { & python "$repo\tools\dashboard\build_dashboard.py" | Out-Null } catch {}
    $pad = "$repo\results\dashboard.html"
    if (Test-Path $pad) { Invoke-Item $pad }
    else {
        [System.Windows.Forms.MessageBox]::Show("Nog geen dashboard - draai eerst een arena-run.",
            "Fog of War") | Out-Null
    }
}

# --- Alles stoppen -------------------------------------------------------------
$btnStop = Maak-Knop "STOP alle runs" 325 {
    $n = Aantal-Godots
    if ($n -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Er draait niets.", "Fog of War") | Out-Null
        return
    }
    $antwoord = [System.Windows.Forms.MessageBox]::Show(
        "$n Godot-proces(sen) stoppen? Trainingsvoortgang tot de laatste adoptie blijft bewaard.",
        "Fog of War", [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning)
    if ($antwoord -eq [System.Windows.Forms.DialogResult]::Yes) {
        Get-Process | Where-Object { $_.ProcessName -like "Godot*" } | Stop-Process -Force
    }
}
$btnStop.BackColor = [System.Drawing.Color]::MistyRose

# --- Statusklok ----------------------------------------------------------------
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 3000
$timer.Add_Tick({
    $n = Aantal-Godots
    if ($n -gt 0) {
        $lblStatus.Text = "Status: $n Godot-proces(sen) actief"
        $lblStatus.ForeColor = [System.Drawing.Color]::DarkGreen
    } else {
        $lblStatus.Text = "Status: niets actief"
        $lblStatus.ForeColor = [System.Drawing.Color]::DimGray
    }
})
$timer.Start()
$lblStatus.Text = "Status: ..."

$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()
$timer.Stop()

# Fog of War - controlepaneel: een paar simpele knoppen, gewone taal.
# Starten: dubbelklik "FogOfWar Paneel.bat" (of: powershell -STA -File paneel.ps1)
# Besluit Max 23-07: niets draait automatisch - alles start vanuit dit paneel.
# Herbouw 28-07 (Max: "ik ben het spoor bijster"): jargon eruit (4.1/4.2/L1),
# alleen de knoppen die Max echt gebruikt. Meet-gereedschap voor Claude
# (fuzz, losse matrix, 4.1-training) draait via de CLI, zie CLAUDE.md.
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
            "Er draait al iets. Toch nog een run starten?",
            "Fog of War", [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question)
        return ($antwoord -eq [System.Windows.Forms.DialogResult]::Yes)
    }
    return $true
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Fog of War"
$form.Size = New-Object System.Drawing.Size(430, 490)
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.StartPosition = "CenterScreen"

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Location = New-Object System.Drawing.Point(15, 12)
$lblStatus.Size = New-Object System.Drawing.Size(390, 22)
$lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($lblStatus)

function Maak-Knop([string]$tekst, [string]$uitleg, [int]$y, [scriptblock]$actie) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $tekst
    $b.Location = New-Object System.Drawing.Point(15, $y)
    $b.Size = New-Object System.Drawing.Size(280, 38)
    $b.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $b.Add_Click($actie)
    $form.Controls.Add($b)
    if ($uitleg -ne "") {
        $l = New-Object System.Windows.Forms.Label
        $l.Text = $uitleg
        $l.Location = New-Object System.Drawing.Point(17, ($y + 40))
        $l.Size = New-Object System.Drawing.Size(390, 16)
        $l.Font = New-Object System.Drawing.Font("Segoe UI", 8)
        $l.ForeColor = [System.Drawing.Color]::DimGray
        $form.Controls.Add($l)
    }
    return $b
}

function Maak-Minuten([int]$y, [int]$standaard) {
    $n = New-Object System.Windows.Forms.NumericUpDown
    $n.Location = New-Object System.Drawing.Point(305, ($y + 6))
    $n.Size = New-Object System.Drawing.Size(60, 26)
    $n.Minimum = 5
    $n.Maximum = 600
    $n.Value = $standaard
    $form.Controls.Add($n)
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "min"
    $lbl.Location = New-Object System.Drawing.Point(368, ($y + 11))
    $lbl.Size = New-Object System.Drawing.Size(35, 18)
    $form.Controls.Add($lbl)
    return $n
}

# Klein getal-veldje naast een knop (bv. het aantal potjes per matchup voor de
# regelzoeker). Zelfde vorm als Maak-Minuten, maar met een eigen label.
function Maak-Getal([int]$y, [int]$standaard, [int]$min, [int]$max, [string]$label, [int]$x) {
    $n = New-Object System.Windows.Forms.NumericUpDown
    $n.Location = New-Object System.Drawing.Point($x, ($y + 6))
    $n.Size = New-Object System.Drawing.Size(48, 26)
    $n.Minimum = $min
    $n.Maximum = $max
    $n.Value = $standaard
    $form.Controls.Add($n)
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $label
    $lbl.Location = New-Object System.Drawing.Point(($x + 50), ($y + 11))
    $lbl.Size = New-Object System.Drawing.Size(55, 18)
    $form.Controls.Add($lbl)
    return $n
}

# Gedeelde starter: 6 parallelle trainers (campagne-regels) met logbestanden
# per factie in results\training_<stamp>\.
function Start-Training([int]$minuten) {
    $stamp = Get-Date -Format "yyyyMMdd_HHmm"
    $logmap = Join-Path $repo ("results\training_" + $stamp)
    New-Item -ItemType Directory -Force $logmap | Out-Null
    $console = $godot -replace "\.exe$", "_console.exe"
    $basisSeed = [int]([DateTimeOffset]::Now.ToUnixTimeSeconds() % 900000000)
    $i = 0
    foreach ($f in @("mens", "muis", "leeuw", "beer", "wolf", "vos")) {
        $trainArgs = @("--headless", "--path", ".", "res://tools/capture.tscn", "--",
            "train", $minuten, 6, 6, $f, ($basisSeed + $i),
            "arena/arena_configs/rules_v42_campaign.json")
        if (Test-Path $console) {
            Start-Process $console -WorkingDirectory $repo -WindowStyle Hidden `
                -RedirectStandardOutput (Join-Path $logmap "train_$f.log") `
                -RedirectStandardError (Join-Path $logmap "train_$f.fouten.log") `
                -ArgumentList $trainArgs
        } else {
            Start-Process $godot -WorkingDirectory $repo -WindowStyle Minimized -ArgumentList $trainArgs
        }
        $i += 1
    }
}

# --- 1. De nacht-knop: bots leren, daarna meten, rapport klaar bij het ontbijt.
$btnNacht = Maak-Knop "TRAINING-NACHT (8 uur)" "Bots leren 7 uur, daarna meten ze zich en staat het rapport klaar." 45 {
    if (-not (Bevestig-BijDrukte)) { return }
    Start-Process powershell -WorkingDirectory $repo -WindowStyle Minimized -ArgumentList @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$repo\training_nacht.ps1",
        "-TrainMinuten", 420, "-ArenaMinuten", 60)
}
$btnNacht.BackColor = [System.Drawing.Color]::Honeydew

# --- 2. Korte training overdag, duur zelf te kiezen.
$numTrain = Maak-Minuten 110 60
$null = Maak-Knop "Bots laten leren" "Zes bots trainen tegelijk; elke verbetering wordt direct bewaard." 110 {
    if (-not (Bevestig-BijDrukte)) { return }
    Start-Training ([int]$numTrain.Value)
}

# --- 3. Losse meting: bots spelen tegen elkaar, cijfers voor het rapport.
$numMeet = Maak-Minuten 175 120
$null = Maak-Knop "Bots laten spelen (meting)" "Botgevechten voor winst-cijfers per factie; zie daarna het rapport." 175 {
    if (-not (Bevestig-BijDrukte)) { return }
    $duur = [int]$numMeet.Value
    $fuzz = [Math]::Max(500, [Math]::Min(10000, $duur * 25))
    Start-Process powershell -WorkingDirectory $repo -ArgumentList @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$repo\arena_nacht.ps1",
        "-DuurMinuten", $duur, "-FuzzGames", $fuzz)
}

# --- 4. Rapport bekijken.
# --- 3b. Regels uitproberen: zoekt zelf naar een betere ontwerp-balans.
$numBalans = Maak-Minuten 240 60
# Potjes per matchup: meer = minder ruis, maar tragere generaties. Onder de 2
# is het verschil tussen 25% en 40% winrate niet meer van toeval te scheiden.
$numPotjes = Maak-Getal 240 2 1 8 "potjes" 200
$null = Maak-Knop "Regels uitproberen (balans)" "Probeert automatisch andere CP- en versterkings-instellingen; komt met een voorstel." 240 {
    if (-not (Bevestig-BijDrukte)) { return }
    $duur = [int]$numBalans.Value
    $potjes = [int]$numPotjes.Value
    Start-Process powershell -WorkingDirectory $repo -ArgumentList @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command",
        "python `"$repo\tools\balans\regelzoeker.py`" --minuten $duur --potjes $potjes --kandidaten 6; Read-Host 'Klaar - druk op Enter'")
    [System.Windows.Forms.MessageBox]::Show(
        "De regelzoeker draait $duur minuten met $potjes potje(s) per matchup." +
        [Environment]::NewLine + [Environment]::NewLine +
        "Meer potjes = betrouwbaardere cijfers maar tragere generaties." +
        [Environment]::NewLine + [Environment]::NewLine +
        "Hij verandert NIETS aan het spel: hij zet zijn beste vondst als voorstel.json in " +
        "results\balans_<tijd>\, met een log van alles wat hij geprobeerd heeft. " +
        "Daarna kijken we samen wat je ervan overneemt.", "Fog of War") | Out-Null
}

$null = Maak-Knop "Bekijk het rapport" "Opent de resultaten-pagina met winst-percentages en trends." 305 {
    try { & python "$repo\tools\dashboard\build_dashboard.py" | Out-Null } catch {}
    $pad = "$repo\results\dashboard.html"
    if (Test-Path $pad) { Invoke-Item $pad }
    else {
        [System.Windows.Forms.MessageBox]::Show("Nog geen rapport - laat eerst de bots spelen of trainen.",
            "Fog of War") | Out-Null
    }
}

# --- 5. Alles stoppen.
$btnStop = Maak-Knop "STOP alles" "Stopt elke lopende run. Trainingsvoortgang blijft bewaard." 370 {
    $n = Aantal-Godots
    if ($n -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Er draait niets.", "Fog of War") | Out-Null
        return
    }
    $antwoord = [System.Windows.Forms.MessageBox]::Show(
        "$n proces(sen) stoppen? Trainingsvoortgang blijft bewaard.",
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
        $lblStatus.Text = "Status: bezig ($n proces(sen))"
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

# Fog of War - controlepaneel: een paar simpele knoppen, gewone taal.
# Starten: dubbelklik "FogOfWar Paneel.bat" (of: powershell -STA -File paneel.ps1)
# Besluit Max 23-07: niets draait automatisch - alles start vanuit dit paneel.
# Herbouw 28-07 (Max: "ik ben het spoor bijster"): jargon eruit (4.1/4.2/L1),
# alleen de knoppen die Max echt gebruikt. Meet-gereedschap voor Claude
# (fuzz, losse matrix, 4.1-training) draait via de CLI, zie CLAUDE.md.
#
# Herbouw 4-08 (Max: "nu lijkt het alsof potjes bij een andere knop hoort").
# Dat was ook zo, en het waren drie fouten tegelijk:
#   1. De invoervakjes stonden los in het formulier, met een x-positie die
#      OVER de knop erboven heen viel. Ze hoorden visueel nergens bij.
#   2. Het potjes-vakje hoorde bij de regelzoeker, maar de factiezoeker stuurde
#      hardgecodeerd 2 potjes mee - dus dat vakje deed daar niets.
#   3. Twee stuurtekens in de tekst (een kapotte \f en \v uit een eerdere
#      bewerking) maakten van "results\facties_<tijd>\voorstel.json" onleesbare
#      soep in het meldingsvenster.
# Nu staat elke knop met zijn eigen instellingen in een eigen kader. Wat in het
# kader staat, hoort bij die knop. Meer regel is het niet.
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
$form.Size = New-Object System.Drawing.Size(470, 838)
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.StartPosition = "CenterScreen"

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Location = New-Object System.Drawing.Point(15, 10)
$lblStatus.Size = New-Object System.Drawing.Size(420, 20)
$lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($lblStatus)

# --- bouwstenen ---------------------------------------------------------------
# Elk kader is een groepje: titel, een regel uitleg, en daaronder de knop met
# zijn eigen instellingen. Alles wat in het kader staat hoort bij die knop.

function Maak-Kader([string]$titel, [int]$y, [int]$hoogte) {
    $g = New-Object System.Windows.Forms.GroupBox
    $g.Text = $titel
    $g.Location = New-Object System.Drawing.Point(15, $y)
    $g.Size = New-Object System.Drawing.Size(425, $hoogte)
    $g.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($g)
    return $g
}

function Maak-Uitleg($kader, [string]$tekst) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $tekst
    $l.Location = New-Object System.Drawing.Point(12, 20)
    $l.Size = New-Object System.Drawing.Size(400, 16)
    $l.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $l.ForeColor = [System.Drawing.Color]::DimGray
    $kader.Controls.Add($l)
}

function Maak-Knop($kader, [string]$tekst, [scriptblock]$actie) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $tekst
    $b.Location = New-Object System.Drawing.Point(12, 42)
    $b.Size = New-Object System.Drawing.Size(185, 34)
    $b.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
    $b.Add_Click($actie)
    $kader.Controls.Add($b)
    return $b
}

# Getal-vakje MET zijn label, binnen hetzelfde kader als de knop. De x-positie
# is de enige parameter die verschuift, zodat twee vakjes naast elkaar passen.
function Maak-Getal($kader, [int]$x, [int]$standaard, [int]$min, [int]$max, [string]$label) {
    $n = New-Object System.Windows.Forms.NumericUpDown
    $n.Location = New-Object System.Drawing.Point($x, 47)
    $n.Size = New-Object System.Drawing.Size(52, 26)
    $n.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $n.Minimum = $min
    $n.Maximum = $max
    $n.Value = $standaard
    $kader.Controls.Add($n)
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $label
    $l.Location = New-Object System.Drawing.Point(($x + 54), 51)
    $l.Size = New-Object System.Drawing.Size(46, 18)
    $l.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $kader.Controls.Add($l)
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
$kadNacht = Maak-Kader "Een hele nacht" 36 86
Maak-Uitleg $kadNacht "Bots leren 7 uur, daarna meten ze zich en staat het rapport klaar."
$btnNacht = Maak-Knop $kadNacht "TRAINING-NACHT (8 uur)" {
    if (-not (Bevestig-BijDrukte)) { return }
    Start-Process powershell -WorkingDirectory $repo -WindowStyle Minimized -ArgumentList @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$repo\training_nacht.ps1",
        "-TrainMinuten", 420, "-ArenaMinuten", 60)
}
$btnNacht.BackColor = [System.Drawing.Color]::Honeydew

# --- 2. Korte training overdag, duur zelf te kiezen.
$kadTrain = Maak-Kader "Bots beter maken" 128 86
Maak-Uitleg $kadTrain "Zes bots trainen tegelijk; elke verbetering wordt direct bewaard."
$numTrain = Maak-Getal $kadTrain 205 60 5 600 "minuten"
$null = Maak-Knop $kadTrain "Bots laten leren" {
    if (-not (Bevestig-BijDrukte)) { return }
    Start-Training ([int]$numTrain.Value)
}

# --- 3. Losse meting: bots spelen tegen elkaar, cijfers voor het rapport.
$kadMeet = Maak-Kader "Meten hoe het ervoor staat" 220 86
Maak-Uitleg $kadMeet "Botgevechten voor winst-cijfers per factie; zie daarna het rapport."
$numMeet = Maak-Getal $kadMeet 205 120 5 600 "minuten"
$null = Maak-Knop $kadMeet "Bots laten spelen (meting)" {
    if (-not (Bevestig-BijDrukte)) { return }
    $duur = [int]$numMeet.Value
    $fuzz = [Math]::Max(500, [Math]::Min(10000, $duur * 25))
    Start-Process powershell -WorkingDirectory $repo -ArgumentList @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$repo\arena_nacht.ps1",
        "-DuurMinuten", $duur, "-FuzzGames", $fuzz)
}

# --- 4. Regels uitproberen: zoekt zelf naar een betere ontwerp-balans.
$kadRegels = Maak-Kader "Regels uitproberen" 312 86
Maak-Uitleg $kadRegels "Probeert andere CP- en versterkings-instellingen; komt met een voorstel."
$numRegels = Maak-Getal $kadRegels 205 60 5 600 "minuten"
# Potjes per matchup: meer = minder ruis, maar tragere generaties. Onder de 2
# is het verschil tussen 25% en 40% winrate niet meer van toeval te scheiden.
$numRegelsPotjes = Maak-Getal $kadRegels 306 2 1 8 "potjes"
$null = Maak-Knop $kadRegels "Regels uitproberen" {
    if (-not (Bevestig-BijDrukte)) { return }
    $duur = [int]$numRegels.Value
    $potjes = [int]$numRegelsPotjes.Value
    Start-Process powershell -WorkingDirectory $repo -ArgumentList @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$repo\balans.ps1",
        "-Soort", "regels", "-Minuten", $duur, "-Potjes", $potjes)
    [System.Windows.Forms.MessageBox]::Show(
        "De regelzoeker draait $duur minuten met $potjes potje(s) per matchup." +
        [Environment]::NewLine + [Environment]::NewLine +
        "Meer potjes = betrouwbaardere cijfers maar tragere generaties." +
        [Environment]::NewLine + [Environment]::NewLine +
        "Hij verandert NIETS aan het spel: hij zet zijn beste vondst als voorstel.json in " +
        'results\balans_<tijd>\, met een log van alles wat hij geprobeerd heeft. ' +
        "Daarna kijken we samen wat je ervan overneemt.", "Fog of War") | Out-Null
}

# --- 5. Facties uitproberen: zoekt aan de factie-eigenschappen zelf.
# Dit kader is hoger, want er hoort een derde instelling bij.
$kadFacties = Maak-Kader "Facties uitproberen" 404 122
Maak-Uitleg $kadFacties "Probeert kaartbudget, perks en legers per factie; komt met een voorstel."
$numFacties = Maak-Getal $kadFacties 205 480 5 600 "minuten"
# 2 potjes = 216 partijen per kandidaat. Met 1 potje schommelt een factie op
# ruis alleen al 20 procentpunt, en adopteert de zoeker toeval.
$numFactiesPotjes = Maak-Getal $kadFacties 306 2 1 8 "potjes"
# Welke facties mag hij aanraken? LEEG = alle zes, en dat is de aanbevolen
# stand. Gericht zoeken (bv. "2,3" = Leeuw en Beer) vindt sneller iets, want
# dan is elke kandidaat een wijziging aan een factie in plaats van een mengsel.
$lblFacties = New-Object System.Windows.Forms.Label
$lblFacties.Text = "facties"
$lblFacties.Location = New-Object System.Drawing.Point(12, 90)
$lblFacties.Size = New-Object System.Drawing.Size(46, 18)
$lblFacties.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$kadFacties.Controls.Add($lblFacties)
$txtFacties = New-Object System.Windows.Forms.TextBox
$txtFacties.Location = New-Object System.Drawing.Point(60, 86)
$txtFacties.Size = New-Object System.Drawing.Size(56, 24)
$txtFacties.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$txtFacties.Text = ""
$kadFacties.Controls.Add($txtFacties)
$lblFactiesHint = New-Object System.Windows.Forms.Label
$lblFactiesHint.Text = "leeg = alle zes   |   0 Varken 1 Muis 2 Leeuw 3 Beer 4 Wolf 5 Krokodil"
$lblFactiesHint.Location = New-Object System.Drawing.Point(124, 90)
$lblFactiesHint.Size = New-Object System.Drawing.Size(288, 18)
$lblFactiesHint.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$lblFactiesHint.ForeColor = [System.Drawing.Color]::DimGray
$kadFacties.Controls.Add($lblFactiesHint)
$null = Maak-Knop $kadFacties "Facties uitproberen" {
    if (-not (Bevestig-BijDrukte)) { return }
    $duur = [int]$numFacties.Value
    $potjes = [int]$numFactiesPotjes.Value
    # Leeg factie-veld = alle zes facties. Een lege string MAG NIET in de
    # argumentenlijst: Start-Process weigert die ("argument is null or empty").
    # Daarom bouwen we de lijst op en plakken we -Facties er alleen bij als er
    # echt iets ingevuld staat.
    $balansArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
        "$repo\balans.ps1", "-Soort", "facties", "-Minuten", "$duur", "-Potjes", "$potjes")
    $welke = $txtFacties.Text.Trim()
    if ($welke -ne "") { $balansArgs += @("-Facties", $welke) }
    Start-Process powershell -WorkingDirectory $repo -ArgumentList $balansArgs
    $watVoor = if ($welke -ne "") { " aan factie(s) $welke" } else { " aan alle zes de facties" }
    [System.Windows.Forms.MessageBox]::Show(
        "De factiezoeker draait $duur minuten$watVoor, met $potjes potje(s) per matchup." +
        [Environment]::NewLine + [Environment]::NewLine +
        "Potjes bepaalt hoe zeker de cijfers zijn, en dat kost tijd:" + [Environment]::NewLine +
        "  1 potje = 108 partijen, marge per factie 9 pp, ruim 9 min per generatie" + [Environment]::NewLine +
        "  2 potjes = 216 partijen, marge 6,5 pp, ruim 19 min per generatie" + [Environment]::NewLine +
        "  4 potjes = 432 partijen, marge 4,6 pp, ruim 37 min per generatie" + [Environment]::NewLine +
        "  6 potjes = 648 partijen, marge 3,7 pp, ruim 56 min per generatie" + [Environment]::NewLine +
        "Marge = hoeveel een winrate op toeval alleen al kan schommelen. Is de marge " +
        "groter dan de verbetering die je zoekt, dan adopteert de zoeker ruis." +
        [Environment]::NewLine + [Environment]::NewLine +
        "Hij schuift aan kaartbudget, kaarten per ronde, legersamenstelling en de perks, " +
        "met een rem erop: hoe verder van je oorspronkelijke ontwerp, hoe meer een kandidaat " +
        "moet opleveren. Anders maakt hij van zes facties zes klonen." +
        [Environment]::NewLine + [Environment]::NewLine +
        "Het voorstel komt in " + 'results\facties_<tijd>\voorstel.json' + " en verandert " +
        "NIETS aan het spel. Draai daarna het kijkgereedschap om te zien wat het doet.",
        "Fog of War") | Out-Null
}

# --- 6. Bekijken wat er nu geldt en wat eruit gekomen is.
$kadKijk = Maak-Kader "Bekijken" 530 160
Maak-Uitleg $kadKijk "Het rapport met winst-percentages, of de factie-instellingen van nu."
$null = Maak-Knop $kadKijk "Bekijk het rapport" {
    try { & python "$repo\tools\dashboard\build_dashboard.py" | Out-Null } catch {}
    $pad = "$repo\results\dashboard.html"
    if (Test-Path $pad) { Invoke-Item $pad }
    else {
        [System.Windows.Forms.MessageBox]::Show("Nog geen rapport - laat eerst de bots spelen of trainen.",
            "Fog of War") | Out-Null
    }
}
# Tweede knop in hetzelfde kader: welke factie-instellingen gelden er NU?
$btnFactieTabel = New-Object System.Windows.Forms.Button
$btnFactieTabel.Text = "Welke facties gelden nu?"
$btnFactieTabel.Location = New-Object System.Drawing.Point(210, 42)
$btnFactieTabel.Size = New-Object System.Drawing.Size(203, 34)
$btnFactieTabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$btnFactieTabel.Add_Click({
    $console = $godot -replace "\.exe$", "_console.exe"
    if (-not (Test-Path $console)) { $console = $godot }
    $uit = Join-Path $repo "results\facties_nu.txt"
    Start-Process $console -WorkingDirectory $repo -WindowStyle Hidden -Wait `
        -RedirectStandardOutput $uit `
        -ArgumentList @("--headless", "--path", ".", "res://tools/capture.tscn", "--", "facties")
    if (Test-Path $uit) { Invoke-Item $uit }
})
$kadKijk.Controls.Add($btnFactieTabel)
# Derde knop: de geluid-tracker opnieuw opbouwen en openen. Hij leest de mappen
# en de wishlist, dus wat je zojuist hebt opgenomen staat er meteen groen in.
$btnGeluidTracker = New-Object System.Windows.Forms.Button
$btnGeluidTracker.Text = "Welke geluiden ontbreken?"
$btnGeluidTracker.Location = New-Object System.Drawing.Point(12, 82)
$btnGeluidTracker.Size = New-Object System.Drawing.Size(401, 34)
$btnGeluidTracker.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$btnGeluidTracker.Add_Click({
    try { & python (Join-Path $repo "tools\bouw_geluid_tracker.py") | Out-Null } catch {}
    $pad = "$repo\sound-tracker.html"
    if (Test-Path $pad) { Invoke-Item $pad }
    else {
        [System.Windows.Forms.MessageBox]::Show("De tracker kon niet worden opgebouwd.",
            "Fog of War") | Out-Null
    }
})
$kadKijk.Controls.Add($btnGeluidTracker)
$lblKijkHint = New-Object System.Windows.Forms.Label
$lblKijkHint.Text = "Facties: draai voor en na het aannemen van een voorstel, een sterretje wijst het verschil aan. Geluid: per factie zien wat er nog mist, met de prompt erbij."
$lblKijkHint.Location = New-Object System.Drawing.Point(12, 122)
$lblKijkHint.Size = New-Object System.Drawing.Size(400, 28)
$lblKijkHint.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$lblKijkHint.ForeColor = [System.Drawing.Color]::DimGray
$kadKijk.Controls.Add($lblKijkHint)

# --- 7. Alles stoppen.
$kadStop = Maak-Kader "Noodrem" 694 86
Maak-Uitleg $kadStop "Stopt elke lopende run. Trainingsvoortgang blijft bewaard."
$btnStop = Maak-Knop $kadStop "STOP alles" {
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

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
Add-Type -AssemblyName Microsoft.VisualBasic
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
$form.Size = New-Object System.Drawing.Size(470, 1096)
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


# Waar de mapkiezer opengaat. Max wees eerst steeds assets aan en moest dan
# drie keer doorklikken; nu begint hij bij de map die hij het laatst koos, en
# anders bij de leveringsinbox.
$MapGeheugen = Join-Path $repo "results\laatste_map.txt"
function Kies-Startmap {
    if (Test-Path $MapGeheugen) {
        $laatst = Get-Content $MapGeheugen -TotalCount 1
        if ($laatst -and (Test-Path $laatst)) { return $laatst }
    }
    foreach ($kandidaat in @((Join-Path $repo "assets\new upload folder"), (Join-Path $repo "assets"))) {
        if (Test-Path $kandidaat) { return $kandidaat }
    }
    return $repo
}
function Onthoud-Map([string]$pad) {
    New-Item -ItemType Directory -Force (Split-Path $MapGeheugen) | Out-Null
    Set-Content -Path $MapGeheugen -Value $pad -Encoding utf8
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
$kadFacties = Maak-Kader "Facties uitproberen" 404 210
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

# Tweede knop: de zoeker voor een hele avond (22 september). Verschil met de
# knop hierboven: hij WACHT tot er niets meer draait, pakt de nieuwste
# nachtmatrix als achtergrond (dan hoeft hij alleen de 11 paren met die factie
# te spelen, ruim drie keer sneller) en kiest zelf de factie die het verst van
# 50% staat als je het veld leeg laat.
$btnZoekerAvond = New-Object System.Windows.Forms.Button
$btnZoekerAvond.Text = "Zoeker voor vanavond (wacht tot de rest klaar is)"
$btnZoekerAvond.Location = New-Object System.Drawing.Point(12, 114)
$btnZoekerAvond.Size = New-Object System.Drawing.Size(401, 34)
$btnZoekerAvond.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$btnZoekerAvond.Add_Click({
    $duur = [int]$numFacties.Value
    $potjes = [int]$numFactiesPotjes.Value
    $zoekArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
        "$repo\tools\balans\zoeker_vanavond.ps1", "-Minuten", "$duur", "-Potjes", "$potjes")
    $welke = $txtFacties.Text.Trim()
    if ($welke -ne "") { $zoekArgs += @("-Facties", $welke) }
    Start-Process powershell -WorkingDirectory $repo -WindowStyle Minimized -ArgumentList $zoekArgs
    $watVoor = if ($welke -ne "") { "factie(s) $welke" } else { "de factie die het verst van 50% staat" }
    [System.Windows.Forms.MessageBox]::Show(
        "De zoeker staat klaar voor $watVoor, $duur minuten met $potjes potje(s)." +
        [Environment]::NewLine + [Environment]::NewLine +
        "Hij begint pas als er geen arena- of trainingsprocessen meer draaien, dus je " +
        "kunt hem nu al starten en de meting die bezig is gewoon laten uitlopen." +
        [Environment]::NewLine + [Environment]::NewLine +
        "Als achtergrond pakt hij de nieuwste nachtmatrix: de 25 paren zonder die factie " +
        "komen daaruit, alleen de 11 paren MET die factie speelt hij zelf. Dat scheelt " +
        "ruim twee derde van de tijd." +
        [Environment]::NewLine + [Environment]::NewLine +
        "Zijn knoppen zijn grof: een kaart erbij is al ~25 procentpunt. Voor een " +
        "correctie van tien punten is 'Startpunten van een factie' de betere knop." +
        [Environment]::NewLine + [Environment]::NewLine +
        "Log: " + 'results\zoeker_<tijd>.log' + ", voorstel in " + 'results\facties_<tijd>\voorstel.json' + ".",
        "Fog of War") | Out-Null
})
$kadFacties.Controls.Add($btnZoekerAvond)

# Derde knop: de FIJNE knop. Startpunten (C11-budget_bonus) per factie, op de
# drie plekken tegelijk (crules.gd + de twee regels-jsons); een punt is ~5 pp,
# tegen ~25 voor een kaart. Eerst een droogloop tonen, dan pas schrijven.
$btnStartpunten = New-Object System.Windows.Forms.Button
$btnStartpunten.Text = "Startpunten van een factie (fijne knop)"
$btnStartpunten.Location = New-Object System.Drawing.Point(12, 154)
$btnStartpunten.Size = New-Object System.Drawing.Size(401, 34)
$btnStartpunten.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$btnStartpunten.Add_Click({
    $welke = $txtFacties.Text.Trim()
    if ($welke -notmatch '^[0-5]$') {
        [System.Windows.Forms.MessageBox]::Show(
            "Vul eerst EEN factie in het facties-vakje hierboven: 0 Varken, 1 Muis, " +
            "2 Leeuw, 3 Beer, 4 Wolf, 5 Krokodil.", "Fog of War") | Out-Null
        return
    }
    $antwoord = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Hoeveel startpunten krijgt factie $welke erbij?" + [Environment]::NewLine +
        "(Muis heeft 4, Beer 3, Wolf 2 + 4 CP, Krokodil 3; een punt is ongeveer 5 procentpunt. " +
        "0 haalt de bonus weg.)", "Startpunten", "2")
    if ($antwoord -eq "") { return }
    if ($antwoord -notmatch '^-?\d+$') {
        [System.Windows.Forms.MessageBox]::Show("Dat is geen getal.", "Fog of War") | Out-Null
        return
    }
    $uit = & python "$repo\tools\balans\zet_budget_bonus.py" $welke "--pt" $antwoord "--droogloop" 2>&1
    $bevestig = [System.Windows.Forms.MessageBox]::Show(
        ($uit -join [Environment]::NewLine) + [Environment]::NewLine + [Environment]::NewLine +
        "Dit is een REGELWIJZIGING: daarna moeten de goldens opnieuw, golden_sims.json " +
        "opnieuw geijkt, de testsuite draaien en de CHANGELOG bij. Doorzetten?",
        "Fog of War", [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning)
    if ($bevestig -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    $uit2 = & python "$repo\tools\balans\zet_budget_bonus.py" $welke "--pt" $antwoord 2>&1
    [System.Windows.Forms.MessageBox]::Show(
        ($uit2 -join [Environment]::NewLine) + [Environment]::NewLine + [Environment]::NewLine +
        "Zeg tegen Claude dat de startpunten zijn gezet; hij doet de goldens, de sims, " +
        "de testsuite en de CHANGELOG.", "Fog of War") | Out-Null
})
$kadFacties.Controls.Add($btnStartpunten)

# --- 6. Bekijken wat er nu geldt en wat eruit gekomen is.
$kadKijk = Maak-Kader "Bekijken" 618 200
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
$btnGeluidTracker.Size = New-Object System.Drawing.Size(196, 34)
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
# Vierde knop: de prop-tracker (het diorama om het bord, 8 september). Leest
# PROP-WISHLIST.md en de mappen props/ en bewoners/, dus een geleverde glb
# staat er meteen groen in, per team (rood arm, blauw rijk).
$btnPropTracker = New-Object System.Windows.Forms.Button
$btnPropTracker.Text = "Welke props ontbreken?"
$btnPropTracker.Location = New-Object System.Drawing.Point(217, 82)
$btnPropTracker.Size = New-Object System.Drawing.Size(196, 34)
$btnPropTracker.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$btnPropTracker.Add_Click({
    try { & python (Join-Path $repo "tools\bouw_prop_tracker.py") | Out-Null } catch {}
    $pad = "$repo\prop-tracker.html"
    if (Test-Path $pad) { Invoke-Item $pad }
    else {
        [System.Windows.Forms.MessageBox]::Show("De prop-tracker kon niet worden opgebouwd.",
            "Fog of War") | Out-Null
    }
})
$kadKijk.Controls.Add($btnPropTracker)
# Vijfde knop: de geluid-studio (18 september, Max: "alle prompts met een
# ElevenLabs-api-call, op Gebruiken drukken, prompts aanpassen, retry, een
# groot makkelijk overzicht"). Start tools/geluid_studio.py als lokale
# webpagina (127.0.0.1:8765) in een geminimaliseerd venster en opent de
# browser; het venster sluiten stopt hem.
$btnGeluidStudio = New-Object System.Windows.Forms.Button
$btnGeluidStudio.Text = "Geluid-studio: prompts naar ElevenLabs, luisteren, gebruiken"
$btnGeluidStudio.Location = New-Object System.Drawing.Point(12, 122)
$btnGeluidStudio.Size = New-Object System.Drawing.Size(401, 34)
$btnGeluidStudio.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$btnGeluidStudio.Add_Click({
    Start-Process python -WorkingDirectory $repo -WindowStyle Minimized `
        -ArgumentList @((Join-Path $repo "tools\geluid_studio.py"))
})
$kadKijk.Controls.Add($btnGeluidStudio)
$lblKijkHint = New-Object System.Windows.Forms.Label
$lblKijkHint.Text = "Facties: voor en na een voorstel. Geluid en props: zien wat er nog mist. De studio maakt de geluiden zelf (ElevenLabs-sleutel nodig)."
$lblKijkHint.Location = New-Object System.Drawing.Point(12, 162)
$lblKijkHint.Size = New-Object System.Drawing.Size(400, 28)
$lblKijkHint.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$lblKijkHint.ForeColor = [System.Drawing.Color]::DimGray
$kadKijk.Controls.Add($lblKijkHint)

# --- 7. Modellen bouwen uit de blend-inbox.
# Alleen de voorkant van tools/bouw_modellen.py: die doet per .blend de drie
# Blender-stappen (los wapen, karakter met het wapen erin, gibs + rechtdraaien).
$kadModellen = Maak-Kader "Modellen bouwen" 824 122
Maak-Uitleg $kadModellen "Een map met een .blend en de nieuwe texturen erin gaat in een keer het spel in."
# Hoofdknop: een complete levering (een map met de .blend EN de nieuwe texturen)
# in een keer verwerken. Eerst de droogloop tonen en om bevestiging vragen; die
# kost geen Blender en is dus meteen klaar. Zie tools/verwerk_levering.py.
$btnLevering = New-Object System.Windows.Forms.Button
$btnLevering.Text = "Map in het spel zetten"
$btnLevering.Location = New-Object System.Drawing.Point(12, 42)
$btnLevering.Size = New-Object System.Drawing.Size(185, 34)
$btnLevering.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$btnLevering.Add_Click({
    $kiezer = New-Object System.Windows.Forms.FolderBrowserDialog
    $kiezer.Description = "Kies de map met je .blend en de nieuwe texturen"
    $start = Kies-Startmap
    if (Test-Path $start) { $kiezer.SelectedPath = $start }
    if ($kiezer.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
    $gekozen = $kiezer.SelectedPath
    Onthoud-Map $gekozen
    $plan = Join-Path $repo "results\levering_plan.txt"
    New-Item -ItemType Directory -Force (Split-Path $plan) | Out-Null
    # De opdracht EERST in een variabele bouwen. Inline samenplakken binnen de
    # @()-lijst gaat mis bij een pad met spaties: het pad komt dan met een spatie
    # ervoor aan de andere kant uit ("Dat is geen map:  C:\...").
    $opdracht = "python tools/verwerk_levering.py --droogloop '" + $gekozen + "'"
    Start-Process powershell -WorkingDirectory $repo -WindowStyle Hidden -Wait `
        -RedirectStandardOutput $plan `
        -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $opdracht)
    $regels = @()
    if (Test-Path $plan) { $regels = @(Get-Content $plan) }
    if ($regels.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "Kon die map niet lezen. Staat Python op deze machine?", "Fog of War") | Out-Null
        return
    }
    $tekst = ($regels | Select-Object -First 22) -join [Environment]::NewLine
    $antwoord = [System.Windows.Forms.MessageBox]::Show(
        $tekst + [Environment]::NewLine + [Environment]::NewLine +
        "Elk model wordt uit zijn .blend gebouwd, en de nieuwe jas wordt eerst tegen " +
        "dat model gemeten. Past hij niet, dan gaat hij er NIET in en hoor je waarom." +
        [Environment]::NewLine + [Environment]::NewLine +
        "Daarna draait hij zelf de controles: importeren in Godot, zit het wapen " +
        "goed vast, zweeft er niets, en vindt de tuner het model." +
        [Environment]::NewLine + [Environment]::NewLine +
        "Bestaande modellen met dezelfde naam worden overschreven. Doorgaan?",
        "Fog of War", [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question)
    if ($antwoord -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    $bouwen = "python tools/verwerk_levering.py '" + $gekozen + "'"
    Start-Process powershell -WorkingDirectory $repo -ArgumentList @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-NoExit", "-Command", $bouwen)
})
$kadModellen.Controls.Add($btnLevering)
$lblModellenHint = New-Object System.Windows.Forms.Label
$lblModellenHint.Text = "Links: een map met je .blend en de nieuwe texturen erin, bouwen plus jassen plus controles. Rechts: het kale lijf eruit om te laten hertexturen."
$lblModellenHint.Location = New-Object System.Drawing.Point(12, 82)
$lblModellenHint.Size = New-Object System.Drawing.Size(400, 28)
$lblModellenHint.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$lblModellenHint.ForeColor = [System.Drawing.Color]::DimGray
$kadModellen.Controls.Add($lblModellenHint)
# Derde knop: een model klaarmaken om te laten hertexturen. Kies de map waar je
# .blend in staat; je krijgt het kale lijf terug (rusthouding, geen skelet, geen
# wapen) om te uploaden. Zie tools/maak_retexture.py.
$btnRetexture = New-Object System.Windows.Forms.Button
$btnRetexture.Text = "Model klaarmaken voor retexture"
$btnRetexture.Location = New-Object System.Drawing.Point(210, 42)
$btnRetexture.Size = New-Object System.Drawing.Size(203, 34)
$btnRetexture.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$btnRetexture.Add_Click({
    $kiezer = New-Object System.Windows.Forms.FolderBrowserDialog
    $kiezer.Description = "Kies de map waar je .blend in staat"
    $start = Kies-Startmap
    if (Test-Path $start) { $kiezer.SelectedPath = $start }
    if ($kiezer.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
    $gekozen = $kiezer.SelectedPath
    Onthoud-Map $gekozen
    $blends = @(Get-ChildItem -Path $gekozen -Filter *.blend -Recurse -File -ErrorAction SilentlyContinue)
    if ($blends.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "Geen .blend gevonden in die map (submappen zijn meegeteld)." +
            [Environment]::NewLine + [Environment]::NewLine +
            "Zet het bestand dat je wilt laten hertexturen daar neer en probeer opnieuw.",
            "Fog of War") | Out-Null
        return
    }
    # `$? met een backtick: anders vult PowerShell hem HIER al in (True/False)
    # in plaats van in het venster dat straks de opdracht draait.
    # De exports landen NAAST de .blend, dus de Verkenner opent de map die je zelf
    # koos. Zo staat alles van een model bij elkaar: blend, uploads, en straks de
    # png's die je terugkrijgt.
    $opdracht = "python tools/maak_retexture.py '" + $gekozen + "'; if (`$?) { explorer '" +
        $gekozen + "' }"
    Start-Process powershell -WorkingDirectory $repo -ArgumentList @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-NoExit", "-Command", $opdracht)
    [System.Windows.Forms.MessageBox]::Show(
        "$($blends.Count) blend-bestand(en) gevonden; ze worden klaargemaakt." +
        [Environment]::NewLine + [Environment]::NewLine +
        "Je krijgt het KALE LIJF: rusthouding, geen skelet, geen animaties, geen " +
        "ingebakken wapen. Dat is wat je uploadt." +
        [Environment]::NewLine + [Environment]::NewLine +
        "Vraag de retexture-dienst UITDRUKKELIJK om de UV-indeling te laten staan " +
        "(geen nieuwe unwrap). Doet hij dat toch, dan past de nieuwe jas niet meer " +
        "op je model en zie je dat pas in een partij." +
        [Environment]::NewLine + [Environment]::NewLine +
        "De twee .glb-bestanden komen NAAST je .blend te staan, in de map die je " +
        "zojuist koos: het lijf en het wapen apart, want die hebben elk hun eigen " +
        "UV-atlas." + [Environment]::NewLine + [Environment]::NewLine +
        "De png die je terugkrijgt zet je in de kleurmap (red of blue) naast die " +
        "blend. Claude meet daarna of hij past.",
        "Fog of War") | Out-Null
})
$kadModellen.Controls.Add($btnRetexture)

# --- 8. Alles stoppen.
$kadStop = Maak-Kader "Noodrem" 952 86
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

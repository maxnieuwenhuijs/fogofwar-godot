extends RefCounted

## UI-beweging (30 september 2026, Max: "geef ieder scherm en alles een
## subtiele inkom animatie en microinteractions"). EEN bewegingstaal voor de
## hele UI, op deze ene plek. Zonder class_name: aanspreken via
## `const Beweging := preload("res://scripts/ui/ui_beweging.gd")` (headless kent
## een nieuwe klasse pas als de editor hem inschreef).
##
## Drie patronen:
##   ERIN  een scherm of laag komt binnen (waas, plof, rijen, schuiven);
##   TIK   reactie op aanraken, keuze of waarde (indrukken, terugveren, plof,
##         punch, stempel, schud, optellen, duw);
##   WEG   alleen voor losse lagen die kort als spook mogen blijven hangen.
## Aankomen gaat ease-out, weggaan ease-in; BACK schiet ongeveer 10% van de
## verandering door, en dat is het veertje (Max: "speels, klein veertje").
##
## Huisregels (volgen uit de checks, zie het plan van 30 september):
##  1. Alleen beeld bovenop een staat die al klopt: nooit `visible`, teksten,
##     add_child, callbacks of submits uitstellen. render_digest leest visible,
##     titels en teksten, geen modulate, positie of schaal.
##  2. Verboden terrein: de root van een CardView, Kaartlaag.modulate,
##     CpZegel.modulate/size/position, de statkolommen, de _tap_area, de root
##     van de Overlay, nodenamen en de kindvolgorde onder Tijdlijn.
##  3. Containerkinderen: alleen alpha, en schaal of draai die op de rust
##     eindigt, met een expliciete startwaarde. Nooit positie of size. Vrij
##     geplaatste nodes mogen schuiven; hun rust wordt bij de start vastgelegd.
##  4. De rust gaat terug naar de vastgelegde waarde (alpha 0,9 blijft 0,9).
##  5. Elke tween: node.create_tween() alleen in de boom, ignore_time_scale
##     (hitstop zet de tijd op 0,05), speed_scale = tempo, meta "ub", een per
##     node per kanaal (de vorige wordt gestopt).
##  6. Staat de beweging uit (of headless zonder forceer), dan doet elke helper
##     niets. Alle headless-checks blijven daardoor byte-identiek.
##  7. Nooit de globale RNG.
##  8. Alles is binnen 0,45 s na het openen klaar (een beloning binnen 0,7 s).
##
## Geluid (30 september, Max: "korte UI geluiden ook nodig toch voor alle
## animaties en ploffen"): `klank()` speelt een kort geluid bij een animatie,
## alleen als de beweging aan staat, en nooit uit de globale RNG (variant en
## toon komen uit een eigen RNG; Audio.play doet anders randi/randf). Een
## stempel bonst op het moment van inslag, omdraaien zwiept, "+1" klinkt als een
## munt, nee-schud klopt twee keer, optellen tikt mee en loopt op in toon.
## De duw is stil; een rij en een golf klinken sinds 6 oktober met een paar
## plofjes (zie Landen); de schermen kiezen zelf waar een blad bij hoort en
## zetten `geluid` uit waar ze zelf al klinken. Categorieen ui_plof,
## ui_stempel, ui_draai, ui_tel, ui_munt, ui_error, ui_blad, ui_knop
## (placeholders uit tools/maak_ui_geluiden.py; echte opnames via de
## geluid-studio).
##
## Landen (6 oktober, Max: "laat alles wat invliegt en verschijnt een beetje
## ploffen, met ook een wolke of schaduw dat je ziet en dan een geluidje, beetje
## verschillend, bij alle animaties en hovers en kliks"). Wat binnenkomt LANDT:
## op het moment dat plof, inschuiven, stempel, omdraaien of een ding in een rij
## aankomt komt er een stofwolkje onder vandaan en klinkt een plofje (een andere
## variant dan de vorige keer, met een eigen toon; in een rij oplopend). Het
## geluid zit IN de tween (een callback op het landingsmoment), dus het valt
## samen met wat je ziet, ook als een inkom twee frames vastgehouden wordt; wordt
## de animatie afgebroken, dan landt er niets. Wat inschuift zonder veer deukt bij
## het landen even in (DEUK). Een knop: indrukken geeft een wolkje en een zacht
## houten tokje (ui_knop; het klikgeluid van de schermen zelf komt bij het
## loslaten), hover met een echte muis een schaduw eronder en ui_hover. Het stof
## en de schaduw zijn een eigen canvas-item ONDER dat van het ding
## (draw_behind_parent): het komt onder het ding vandaan, beweegt mee, en er komt
## geen node bij (kindlijsten, containers en render_digest blijven gelijk). Een
## begrenzer (KLANK_MIN_MS) laat hetzelfde geluid niet twee keer binnen 45 ms
## klinken, en een rij plaatst hooguit RIJ_KLANK_MAX plofjes. Stof en schaduw
## alleen bij volle beweging (rustig houdt het geluid); sterkte via de dev-knop
## `ui_wolk` (0 = uit).
##
## Standen (user://settings.cfg [ui] beweging): normaal = alles; rustig =
## alleen alpha op 60% van de duur, indrukken is kort donkerder; uit = niets.
## De dev-knop `ui_tempo` (sfeer-paneel) is de speed_scale: 0 uit, 0,5
## slowmo, 2 dubbel zo snel.

const UIT := 0
const RUSTIG := 1
const NORMAAL := 2
const STAND_NAMEN := {UIT: "uit", RUSTIG: "rustig", NORMAAL: "normaal"}

# --- Tokens (seconden; schaal als factor van de rust) ----------------------------
const DRUK_DUUR := 0.08          # knop indrukken (QUAD out)
const VEER_DUUR := 0.22          # loslaten, terugveren (BACK out)
const HOVER_DUUR := 0.12         # alleen met een echte muis (CUBIC out)
const IN_DUUR := 0.26            # een scherm ploft (BACK out) ...
const IN_ALFA_DUUR := 0.16       # ... en wordt zichtbaar (QUAD out)
const IN_VAN := 0.94
const DIM_DUUR := 0.18           # de waas achter een scherm
const WISSEL_DUUR := 0.16        # inhoud wisselt binnen een scherm
const WISSEL_VAN := 0.985
const RIJ_DUUR := 0.20           # een item in een lijst
const RIJ_STAP := 0.035          # tussen twee items ...
const RIJ_MAX_SPREIDING := 0.20  # ... en de hele lijst samen hooguit
const RIJ_VAN := 0.96
const SCHUIF_DUUR := 0.26        # vrij geplaatste stukken schuiven in (CUBIC out)
const POP_DUUR := 0.24           # keuze, nieuw icoon (BACK out)
const POP_VAN := 0.6
const PUNCH_OP := 0.07           # getal verandert: even groot ...
const PUNCH_NEER := 0.16         # ... en veert terug
const PUNCH_PIEK := 1.25
const DIP := 0.85
const STEMPEL_VAN := 1.45        # stempel: van groot ...
const STEMPEL_IN := 0.10         # ... erop (QUAD in) ...
const STEMPEL_UIT := 0.14        # ... en naveren (BACK out), draai -8 graden naar 0
const STEMPEL_DRAAI := -8.0
const TEL_DUUR := 0.5            # een getal loopt op
const DRAAI_DICHT := 0.09        # een kaart draait om: dicht ...
const DRAAI_OPEN := 0.15         # ... en open met een veertje
const SCHUD_STAP := 0.05         # "kan niet": vier zwaaien en terug
const DUW_NA := 6.0              # wacht op jou: na zoveel s niets doen ...
const DUW_ELKE := 8.0            # ... een zachte puls, niet vaker dan dit
const DUW_PIEK := 1.05
const DUW_DUUR := 0.5
const WEG_DUUR := 0.12           # spook-uitgang (QUAD in)
const WEG_NAAR := 0.96
const FLITS_DUUR := 0.5          # kleurflits die terugvalt naar de rust
const ZWEEF_DUUR := 0.6          # "+1" dat omhoog zweeft en vervaagt
const RUSTIG_FACTOR := 0.6       # rustig: zoveel van de duur, alleen alpha
const VASTHOUD_FRAMES := 2       # een inkom start pas na het (vaak zware) bouwframe
const PLOF_LAND := 0.37          # BACK out passeert zijn doel op 37% van de duur: daar landt het
const SCHUIF_LAND := 0.72        # CUBIC out is daar op 98%: het ding staat stil
const DEUK := 0.05               # wat inschuift deukt bij het landen hooguit zo plat ...
const DEUK_DUUR := 0.2           # ... en is zo snel weer rond
const WOLK_DUUR := 0.42          # een stofwolkje bij het landen
const WOLK_KLIK_DUUR := 0.3      # een kleintje onder een knop die je indrukt
const SCHADUW_DUUR := 0.12       # de schaduw onder een knop bij hover
const SCHADUW_DRUK := 0.35       # ingedrukt staat de knop op het papier: minder schaduw
const KLANK_MIN_MS := 45         # hetzelfde geluid hooguit zo vaak (de begrenzer)
const RIJ_KLANK_MAX := 4         # een rij: hooguit zoveel plofjes, oplopend in toon
const RIJ_WOLK_MAX := 8          # en hooguit zoveel wolkjes
const STOF := Color(0.97, 0.94, 0.88)         # de lichte kern van een plukje (zichtbaar op hout en bord)
const STOF_RAND := Color(0.36, 0.27, 0.2)     # zijn schaduwkant, rechtsonder (zichtbaar op perkament)
const SCHADUW_KLEUR := Color(0.1, 0.06, 0.03, 0.5)

# --- Schakelaar ---------------------------------------------------------------------
static var _stand: int = NORMAAL
static var _tempo: float = 1.0
static var _forceer: int = -1           # -1 automatisch (headless uit), 0 altijd uit, 1 ook headless aan
static var _headless: int = -1          # lui: -1 onbekend
static var _heeft_ratio: int = -1       # lui: kent Control pivot_offset_ratio?
static var _echte_muis: bool = true
static var _laatste_invoer_ms: int = 0
static var _weg_frame: int = -100
static var _rng_klank: RandomNumberGenerator = null   # eigen RNG voor variant en toon
static var _klanken: int = 0                          # wat klank() echt afspeelde (voor de check)
static var _klank_ms: Dictionary = {}                 # categorie -> geplande tijden (ms), voor de begrenzer
static var _klank_vorige: Dictionary = {}             # categorie -> de vorige variant
static var _rng_wolk: RandomNumberGenerator = null    # eigen RNG voor het stof
static var _wolk_sterkte: float = 1.0                 # dev-knop ui_wolk (0 = geen stof en schaduw)
static var _wolken: int = 0                           # hoeveel wolkjes er kwamen (voor de check)
static var _actief: Array = []                        # lopende wolkjes: {ci, node, waar, bron, ...}
static var _cirkel: PackedVector2Array = PackedVector2Array()
## Waar de stand staat; de check wijst een eigen bestand aan.
static var instellingen_pad: String = "user://settings.cfg"


## De stand uit settings.cfg (UiThema._ready).
static func laad() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(instellingen_pad) == OK:
		_stand = stand_uit_naam(String(cfg.get_value("ui", "beweging", "normaal")))


static func stand_uit_naam(naam: String) -> int:
	for s in STAND_NAMEN:
		if String(STAND_NAMEN[s]) == naam:
			return int(s)
	return NORMAAL


static func stand() -> int:
	return _stand


## Zet de stand en bewaar hem (andere secties van het bestand blijven staan).
static func zet_stand(s: int) -> void:
	_stand = clampi(s, UIT, NORMAAL)
	var cfg := ConfigFile.new()
	cfg.load(instellingen_pad)
	cfg.set_value("ui", "beweging", String(STAND_NAMEN[_stand]))
	cfg.save(instellingen_pad)


## De volgende stand in het rondje normaal -> rustig -> uit -> normaal.
static func volgende_stand() -> int:
	return NORMAAL if _stand == UIT else _stand - 1


## De vertaalsleutel van een stand (MENU_MOTION_NORMAL, _CALM, _OFF).
static func stand_sleutel(s: int) -> String:
	match s:
		UIT:
			return "MENU_MOTION_OFF"
		RUSTIG:
			return "MENU_MOTION_CALM"
	return "MENU_MOTION_NORMAL"


## Koos de speler "uit"? Dan gaan ook het uitdelen van de waaier en de fade
## van de tijdlijn direct. Headless nooit (dan blijven de checks gelijk,
## wat er ook in de settings van de speler staat).
static func uit_gekozen() -> bool:
	return _stand == UIT and (_forceer == 1 or not _is_headless())


static func zet_tempo(t: float) -> void:
	_tempo = maxf(0.0, t)


static func tempo() -> float:
	return _tempo


## -1 = automatisch (headless uit), 0 = altijd uit, 1 = ook headless aan (checks).
static func forceer(w: int) -> void:
	_forceer = w


static func _is_headless() -> bool:
	if _headless == -1:
		_headless = 1 if DisplayServer.get_name() == "headless" else 0
	return _headless == 1


## Beweegt er iets (normaal of rustig)?
static func aan() -> bool:
	if _forceer == 0 or _stand == UIT or _tempo <= 0.0:
		return false
	return _forceer == 1 or not _is_headless()


## Volle beweging: schaal, schuiven, veren, stempels.
static func vol() -> bool:
	return aan() and _stand == NORMAAL


## Rustig: alleen alpha.
static func rustig() -> bool:
	return aan() and _stand == RUSTIG


static func _duur(d: float) -> float:
	return d * RUSTIG_FACTOR if _stand == RUSTIG else d


## Een kort UI-geluid bij een animatie, `vertraging` na nu (in beeld-tijd, dus
## gedeeld door het tempo). Alleen als de beweging aan staat (rustig telt mee:
## minder beweging is niet minder geluid), nooit headless, en nooit uit de
## globale RNG. Elke keer een andere variant dan de vorige keer (Max: "beetje
## verschillende"); `toon` 0 = een kleine willekeurige toonhoogte. De begrenzer
## laat hetzelfde geluid niet binnen KLANK_MIN_MS van een ander klinken.
static func klank(cat: String, vertraging: float = 0.0, toon: float = 0.0) -> void:
	if not aan():
		return
	var n: int = Audio.variant_aantal(cat)
	if n <= 0:
		return
	var wacht: float = maxf(0.0, vertraging) / maxf(_tempo, 0.01)
	if not _klank_mag(cat, Time.get_ticks_msec() + int(wacht * 1000.0)):
		return
	if _rng_klank == null:
		_rng_klank = RandomNumberGenerator.new()
		_rng_klank.seed = 30092026
	var variant := _rng_klank.randi_range(0, n - 1)
	if n > 1 and variant == int(_klank_vorige.get(cat, -1)):
		variant = (variant + 1 + _rng_klank.randi_range(0, n - 2)) % n
	_klank_vorige[cat] = variant
	var pitch := toon if toon > 0.0 else _rng_klank.randf_range(0.93, 1.07)
	Audio.play(cat, wacht, variant, pitch)
	_klanken += 1


## De begrenzer: zes ploffen tegelijk klinken als een. Vergelijkt met wat er de
## laatste seconde gepland is (ook vooruit), dus de volgorde van plannen doet er
## niet toe. De tikjes van het optellen hebben hun eigen maat.
static func _klank_mag(cat: String, wanneer: int) -> bool:
	if cat == "ui_tel":
		return true
	var nu := Time.get_ticks_msec()
	var bewaar: Array = []
	for t in _klank_ms.get(cat, []):
		if int(t) > nu - 1000:
			bewaar.append(int(t))
	for t in bewaar:
		if absi(int(t) - wanneer) < KLANK_MIN_MS:
			_klank_ms[cat] = bewaar
			return false
	bewaar.append(wanneer)
	_klank_ms[cat] = bewaar
	return true


## Hoeveel geluiden klank() tot nu toe echt afspeelde (de inkomcheck telt mee).
static func klanken() -> int:
	return _klanken


# --- Invoer (UiThema._input) ----------------------------------------------------

## Onthoudt of de laatste muis echt was (touch komt als nagebootste muis binnen,
## en dan geen hover) en wanneer er voor het laatst iets gebeurde (duw).
static func zie_invoer(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch or ev is InputEventScreenDrag:
		_echte_muis = false
		_laatste_invoer_ms = Time.get_ticks_msec()
	elif ev is InputEventMouse:
		_echte_muis = ev.device != InputEvent.DEVICE_ID_EMULATION
		_laatste_invoer_ms = Time.get_ticks_msec()
	elif ev is InputEventKey:
		_laatste_invoer_ms = Time.get_ticks_msec()


static func echte_muis() -> bool:
	return _echte_muis


static func laatste_invoer_ms() -> int:
	return _laatste_invoer_ms


## Voor checks: doen alsof er zo lang niets gebeurd is.
static func zet_laatste_invoer_ms(ms: int) -> void:
	_laatste_invoer_ms = ms


## Een scherm verdween (vervangregel): komt er in dit of het volgende frame een
## ander binnen, dan blijft diens waas staan en beweegt alleen het paneel, anders
## flitst het bord er tussendoor.
static func meld_weg() -> void:
	_weg_frame = Engine.get_process_frames()


static func vervangt() -> bool:
	return Engine.get_process_frames() - _weg_frame <= 1


## Hoeveel UI-tweens lopen er nog (zonder de duw-lussen)? Voor checks.
static func bezig() -> int:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return 0
	var n := 0
	for tw in tree.get_processed_tweens():
		if tw.has_meta("ub") and not tw.has_meta("ub_lus") and tw.is_valid():
			n += 1
	return n


# --- Kern ---------------------------------------------------------------------------

## Mag deze node nu bewegen? Uit, weg, niet in de boom: dan niets, ook geen spil.
static func _mag(c: Object) -> bool:
	return aan() and c != null and is_instance_valid(c) and c is CanvasItem \
		and (c as Node).is_inside_tree() and not c.has_meta("ub_weg")


## Een verse tween op dit kanaal; de vorige op hetzelfde kanaal stopt.
## `vasthouden` (voor alles wat binnenkomt): de beginstand staat meteen, maar de
## tween start pas VASTHOUD_FRAMES frames later. Het frame waarin een scherm
## gebouwd wordt is vaak zwaar (kaarten, de hub), en een tween zet die lange
## delta anders in een stap: dan is de inkom voorbij voor je hem ziet. Directe
## feedback (indrukken, punch, schud) houdt niet vast. Headless niet (daar
## tekent niets en wachten de checks zelf).
static func _tween(node: Node, kanaal: String, vasthouden: bool = false) -> Tween:
	var sleutel := "ub_tw_" + kanaal
	_stop_kanaal(node, kanaal)
	var tw := node.create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_speed_scale(_tempo)
	tw.set_meta("ub", true)
	node.set_meta(sleutel, tw)
	if vasthouden and not _is_headless():
		tw.pause()
		_speel_na_frames(tw, VASTHOUD_FRAMES)
	return tw


static func _speel_na_frames(tw: Tween, frames: int) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or frames <= 0:
		if tw.is_valid():
			tw.play()
		return
	# Elke stap een nieuwe lambda (een one-shot mag zichzelf niet opnieuw verbinden).
	tree.process_frame.connect(func() -> void: _speel_na_frames(tw, frames - 1), CONNECT_ONE_SHOT)


static func _stop_kanaal(node: Node, kanaal: String) -> void:
	var sleutel := "ub_tw_" + kanaal
	if node.has_meta(sleutel):
		var oud = node.get_meta(sleutel)
		if oud is Tween and (oud as Tween).is_valid():
			(oud as Tween).kill()
		node.remove_meta(sleutel)


static func _loopt(node: Node, kanaal: String) -> bool:
	var sleutel := "ub_tw_" + kanaal
	if not node.has_meta(sleutel):
		return false
	var tw = node.get_meta(sleutel)
	# Geldig telt ook een tween die nog vastgehouden wordt (gepauzeerd).
	return tw is Tween and (tw as Tween).is_valid()


## De rust van een eigenschap: vastgelegd zolang er op dit kanaal iets loopt,
## anders de huidige waarde. Altijd VOOR _tween aanroepen (die stopt de vorige).
static func _rust(node: Node, prop: String, kanaal: String) -> Variant:
	var sleutel := "ub_rust_" + prop
	if _loopt(node, kanaal) and node.has_meta(sleutel):
		return node.get_meta(sleutel)
	if node.has_meta(sleutel) and node.has_meta("ub_vast_" + prop):
		return node.get_meta(sleutel)   # een knop die nog ingedrukt of gehoverd staat
	var v: Variant = node.get(prop)
	node.set_meta(sleutel, v)
	return v


## Aan het eind van een tween die op de rust eindigt: de vastgelegde rust weg.
static func _klaar(tw: Tween, node: Node, prop: String) -> void:
	tw.finished.connect(func() -> void:
		if is_instance_valid(node):
			node.remove_meta("ub_rust_" + prop)
			node.remove_meta("ub_vast_" + prop))


## Draaipunt: het midden (of `ratio`), tenzij de eigenaar zelf een spil zette.
static func _spil(c: Control, ratio: Vector2 = Vector2(0.5, 0.5)) -> void:
	if c.pivot_offset != Vector2.ZERO and not c.has_meta("ub_spil"):
		return
	if _heeft_ratio == -1:
		_heeft_ratio = 1 if c.get("pivot_offset_ratio") != null else 0
	if _heeft_ratio == 1:
		c.set("pivot_offset_ratio", ratio)
	else:
		c.pivot_offset = c.size * ratio
		c.set_meta("ub_spil", true)


## Van `van` maal de rust naar de rust. Met `land` (een wolkje: "onder",
## "rondom") en/of `cat` (een geluid, op toon `toon`) gebeurt er iets op het
## moment dat het ding aankomt: BACK passeert zijn doel op PLOF_LAND, de rest is
## daar op SCHUIF_LAND vrijwel stil. Het zit in de tween, dus het wacht mee met
## het vasthouden en valt weg als de animatie afgebroken wordt.
static func _schaal_van(c: Control, van: float, vertraging: float, duur: float,
		trans: int = Tween.TRANS_BACK, ratio: Vector2 = Vector2(0.5, 0.5),
		land: String = "", cat: String = "", toon: float = 0.0) -> void:
	_spil(c, ratio)
	var rust: Vector2 = _rust(c, "scale", "schaal")
	var tw := _tween(c, "schaal", true)
	c.scale = rust * van
	if vertraging > 0.0:
		tw.tween_interval(vertraging)
	tw.tween_property(c, "scale", rust, duur).from(rust * van) \
		.set_trans(trans).set_ease(Tween.EASE_OUT)
	if land != "" or cat != "":
		var t_land: float = (PLOF_LAND if trans == Tween.TRANS_BACK else SCHUIF_LAND) * duur
		tw.parallel().tween_callback(func() -> void: _geland(c, land, cat, toon)).set_delay(t_land)
	_klaar(tw, c, "scale")


## Het moment van landen: een wolkje (als `waar` niet leeg is) en een geluid.
static func _geland(c: Control, waar: String, cat: String, toon: float = 0.0) -> void:
	if waar != "" and is_instance_valid(c):
		wolkje(c, waar)
	if cat != "":
		klank(cat, 0.0, toon)


# --- ERIN -----------------------------------------------------------------------

## Van `van_alfa` naar de eigen alpha. `eigen` = self_modulate (alleen deze node,
## niet de kinderen), bv. de waas van een pop-up met het paneel erin.
static func fade_in(c: CanvasItem, vertraging: float = 0.0, duur: float = RIJ_DUUR,
		eigen: bool = false, van_alfa: float = 0.0) -> void:
	if not _mag(c):
		return
	var prop := "self_modulate" if eigen else "modulate"
	var rust: Color = _rust(c, prop, "alfa")
	var tw := _tween(c, "alfa", true)
	var start := rust
	start.a = rust.a * van_alfa
	c.set(prop, start)
	if vertraging > 0.0:
		tw.tween_interval(vertraging)
	tw.tween_property(c, prop + ":a", rust.a, _duur(duur)).from(start.a) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_klaar(tw, c, prop)


## Een scherm komt binnen: de waas faadt tot zijn eigen alpha, de laag (een node
## die NIET in een container staat: Center, Midden, de laag van een keuzescherm)
## ploft van 0,94 naar zijn rust.
static func inkom_scherm(waas: CanvasItem, laag: Control, vertraging: float = 0.0) -> void:
	if waas != null:
		fade_in(waas, vertraging, DIM_DUUR)
	if laag == null or not _mag(laag):
		return
	if vol():
		_schaal_van(laag, IN_VAN, vertraging, IN_DUUR)
	fade_in(laag, vertraging, IN_ALFA_DUUR)


## Inhoud wisselt binnen een scherm dat al open was: kort overvloeien.
static func wissel(c: Control, ratio: Vector2 = Vector2(0.5, 0.5)) -> void:
	if not _mag(c):
		return
	fade_in(c, 0.0, WISSEL_DUUR, false, 0.25)
	if vol():
		_schaal_van(c, WISSEL_VAN, 0.0, WISSEL_DUUR, Tween.TRANS_CUBIC, ratio)


## Items na elkaar: alpha plus een klein schaaltje (mag in een container: de
## schaal eindigt op de rust en heeft een expliciete start). Onzichtbare en
## al vrijgegeven items tellen niet mee. De DINGEN in de rij (knoppen, panelen,
## plaatjes; geen tekstregels of schuifjes) landen met een wolkje (hooguit
## RIJ_WOLK_MAX) en een paar plofjes die oplopen in toon (hooguit RIJ_KLANK_MAX,
## zo ver uit elkaar dat de begrenzer ze laat staan). `geluid`/`wolk` false voor
## een rij die zelf al klinkt of te dicht op elkaar staat (een tabel).
static func inkom_rij(items: Array, vertraging: float = 0.0, stap: float = RIJ_STAP,
		geluid: bool = true, wolk: bool = true) -> void:
	if not aan():
		return
	var lijst: Array = []
	for n in items:
		if n is CanvasItem and is_instance_valid(n) and (n as CanvasItem).visible \
				and not (n as Node).is_queued_for_deletion() and (n as Node).is_inside_tree():
			lijst.append(n)
	if lijst.is_empty():
		return
	var echte_stap: float = minf(stap, RIJ_MAX_SPREIDING / maxf(1.0, float(lijst.size() - 1)))
	var dingen: Array = []
	for n in lijst:
		if n is Control and _is_ding(n as Control):
			dingen.append(n)
	var met_wolk: Dictionary = {}
	if wolk:
		for j in mini(dingen.size(), RIJ_WOLK_MAX):
			met_wolk[dingen[_verdeel(j, mini(dingen.size(), RIJ_WOLK_MAX), dingen.size())]] = true
	var met_klank: Dictionary = {}
	if geluid and not dingen.is_empty():
		# elk zoveelste ding, zodat de plofjes minstens KLANK_MIN_MS uit elkaar liggen
		var elke: int = maxi(1, ceili(float(KLANK_MIN_MS) / 1000.0 / maxf(echte_stap, 0.001)))
		var j := 0
		for k in range(0, dingen.size(), elke):
			if j >= RIJ_KLANK_MAX:
				break
			met_klank[dingen[k]] = 1.0 + 0.05 * float(j)
			j += 1
	for i in lijst.size():
		var n: CanvasItem = lijst[i]
		var v: float = vertraging + echte_stap * float(i)
		fade_in(n, v, RIJ_DUUR)
		var cat: String = "ui_plof" if met_klank.has(n) else ""
		if vol() and n is Control:
			_schaal_van(n as Control, RIJ_VAN, v, RIJ_DUUR, Tween.TRANS_BACK, Vector2(0.5, 0.5),
				"onder" if met_wolk.has(n) else "", cat, float(met_klank.get(n, 0.0)))
		elif cat != "":
			klank(cat, v + PLOF_LAND * _duur(RIJ_DUUR), float(met_klank[n]))


## Het j-de van m, gelijk verdeeld over n plekken (0 en n-1 doen altijd mee).
static func _verdeel(j: int, m: int, n: int) -> int:
	if m <= 1 or n <= 1:
		return 0
	return int(round(float(j) * float(n - 1) / float(m - 1)))


## Een DING dat landt en dus stof geeft: knoppen, panelen, plaatjes en vlakken,
## of een wrapper met meta "ub_ding" (de kaarten op het onthulscherm); geen
## tekstregels, schuifjes of lege containers.
static func _is_ding(c: Control) -> bool:
	return c is BaseButton or c is Panel or c is PanelContainer or c is TextureRect \
		or c is NinePatchRect or c is ColorRect or bool(c.get_meta("ub_ding", false))


## Een vrij geplaatst stuk (niet in een container) schuift van `van` pixels
## naast zijn rust naar binnen en landt: een wolkje en een plofje (`geluid`),
## en zonder veer deukt het even in (met veer schiet het zelf al door).
static func schuif_in(n: Control, van: Vector2, vertraging: float = 0.0,
		duur: float = SCHUIF_DUUR, veer: bool = false, geluid: bool = true) -> void:
	if not _mag(n):
		return
	fade_in(n, vertraging, duur * 0.7)
	var t_land: float = (PLOF_LAND if veer else SCHUIF_LAND) * duur
	if not vol():
		if geluid:
			klank("ui_plof", vertraging + t_land * RUSTIG_FACTOR)
		return
	var rust: Vector2 = _rust(n, "position", "pos")
	var tw := _tween(n, "pos", true)
	n.position = rust + van
	if vertraging > 0.0:
		tw.tween_interval(vertraging)
	tw.tween_property(n, "position", rust, duur).from(rust + van) \
		.set_trans(Tween.TRANS_BACK if veer else Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_callback(func() -> void:
		if not veer:
			_deuk(n)
		_geland(n, "onder", "ui_plof" if geluid else "")).set_delay(t_land)
	_klaar(tw, n, "position")


## Wat stilvalt ploft even na: plat en breed op de onderrand, dan met een veertje
## rond. Grote stukken minder (hooguit DEUK, een paneel ~1,5%). Niet als er al
## iets met de schaal bezig is.
static func _deuk(c: Control) -> void:
	if not _mag(c) or not vol() or _loopt(c, "schaal"):
		return
	_spil(c, Vector2(0.5, 1.0))
	var rust: Vector2 = _rust(c, "scale", "schaal")
	var maat: float = clampf(14.0 / maxf(c.size.y, 1.0), 0.012, DEUK)
	var tw := _tween(c, "schaal")
	tw.tween_property(c, "scale", rust * Vector2(1.0 + maat, 1.0 - maat), DEUK_DUUR * 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", rust, DEUK_DUUR * 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_klaar(tw, c, "scale")


# --- TIK --------------------------------------------------------------------------

## Keuze of nieuw element ploft erin en landt met een wolkje (`wolk`) en een
## plofje (`geluid` false als het scherm er zelf al een geluid bij speelt).
## `met_alfa` false voor nodes waarvan de modulate een tint draagt (iconen,
## portretten): dan alleen schaal.
static func plof(c: Control, vertraging: float = 0.0, van: float = POP_VAN,
		met_alfa: bool = true, ratio: Vector2 = Vector2(0.5, 0.5), geluid: bool = true,
		wolk: bool = true) -> void:
	if not _mag(c):
		return
	if met_alfa:
		fade_in(c, vertraging, POP_DUUR * 0.6)
	if vol():
		_schaal_van(c, van, vertraging, POP_DUUR, Tween.TRANS_BACK, ratio,
			"onder" if wolk else "", "ui_plof" if geluid else "")
	elif geluid:
		klank("ui_plof", vertraging + PLOF_LAND * _duur(POP_DUUR))


## Getal verandert: even groot en terugveren (dip = even klein).
static func punch(c: Control, piek: float = PUNCH_PIEK, ratio: Vector2 = Vector2(0.5, 0.5)) -> void:
	if not _mag(c) or not vol():
		return
	_spil(c, ratio)
	var rust: Vector2 = _rust(c, "scale", "schaal")
	var tw := _tween(c, "schaal")
	tw.tween_property(c, "scale", rust * piek, PUNCH_OP).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", rust, PUNCH_NEER).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_klaar(tw, c, "scale")


static func dip(c: Control, ratio: Vector2 = Vector2(0.5, 0.5)) -> void:
	punch(c, DIP, ratio)


## Naar een schaal die de eigenaar kiest (bv. 1,04 bij selectie), met een
## veertje; uit of rustig: meteen.
static func naar_schaal(c: Control, doel: Vector2, duur: float = 0.16) -> void:
	if not _mag(c) or not vol():
		if c != null and is_instance_valid(c):
			_stop_kanaal(c, "schaal")
			c.scale = doel
		return
	if c.scale == doel and not _loopt(c, "schaal"):
		return
	_spil(c)
	var tw := _tween(c, "schaal")
	tw.tween_property(c, "scale", doel, duur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Een zachte, trage puls (de duw, of "klaar").
static func puls(c: Control, piek: float = DUW_PIEK, duur: float = DUW_DUUR) -> void:
	if not _mag(c) or not vol():
		return
	_spil(c)
	var rust: Vector2 = _rust(c, "scale", "schaal")
	var tw := _tween(c, "schaal")
	tw.tween_property(c, "scale", rust * piek, duur * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(c, "scale", rust, duur * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_klaar(tw, c, "scale")


## Kleurflits die terugvalt naar de rust (werkt ook in containers en in rustig:
## het is kleur, geen beweging).
static func flits(c: CanvasItem, kleur: Color, duur: float = FLITS_DUUR) -> void:
	if not _mag(c):
		return
	var rust: Color = _rust(c, "modulate", "alfa")
	var tw := _tween(c, "alfa")
	var start := kleur
	start.a = rust.a
	c.modulate = start
	tw.tween_property(c, "modulate", rust, _duur(duur)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_klaar(tw, c, "modulate")


## "Kan niet": vier kleine zwaaien om het midden en terug (draai, dus ook in een
## container veilig).
static func schud(c: Control) -> void:
	if not _mag(c):
		return
	klank("ui_error")   # ook bij rustig: minder beweging, niet minder feedback
	if not vol():
		return
	_spil(c)
	var rust: float = _rust(c, "rotation", "rot")
	var tw := _tween(c, "rot")
	var hoek := deg_to_rad(clampf(7.0 * 80.0 / maxf(c.size.x, 1.0), 1.5, 7.0))
	for i in 4:
		var teken := 1.0 if i % 2 == 0 else -1.0
		tw.tween_property(c, "rotation", rust + teken * hoek * (1.0 - 0.22 * float(i)), SCHUD_STAP) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(c, "rotation", rust, SCHUD_STAP).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_klaar(tw, c, "rotation")


## Stempel: van groot met een draai erop drukken en naveren; op de inslag het
## geluid en stof rondom. `verberg` houdt het ding tot de stempel valt op een
## schaal van bijna niets (nooit via modulate: die wordt gemeten). Alleen schaal
## en draai.
static func stempel(c: Control, vertraging: float = 0.0, verberg: bool = false, geluid: bool = true) -> void:
	if not _mag(c):
		return
	if not vol():
		if geluid:
			klank("ui_stempel", vertraging + STEMPEL_IN)
		return
	_spil(c)
	var rs: Vector2 = _rust(c, "scale", "schaal")
	var rr: float = _rust(c, "rotation", "rot")
	var tw := _tween(c, "schaal", true)
	var tw_rot := _tween(c, "rot", true)
	if verberg:
		c.scale = rs * 0.01
	if vertraging > 0.0:
		tw.tween_interval(vertraging)
		tw_rot.tween_interval(vertraging)
	tw.tween_callback(func() -> void: c.scale = rs * STEMPEL_VAN)
	tw.tween_property(c, "scale", rs * 0.94, STEMPEL_IN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: _geland(c, "rondom", "ui_stempel" if geluid else ""))
	tw.tween_property(c, "scale", rs, STEMPEL_UIT).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_rot.tween_callback(func() -> void: c.rotation = rr + deg_to_rad(STEMPEL_DRAAI))
	tw_rot.tween_property(c, "rotation", rr, STEMPEL_IN + STEMPEL_UIT).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_klaar(tw, c, "scale")
	_klaar(tw_rot, c, "rotation")


## Omdraaien als een kaart: smal naar 0 om het midden, halverwege `halverwege`
## (bv. de rug weg), en weer open met een veertje; als hij open klapt een
## wolkje eronder (de kaart slaat neer). Uit of rustig: meteen `halverwege`,
## zonder draai (rustig wel met het geluid).
static func draai_om(c: Control, halverwege: Callable, vertraging: float = 0.0) -> void:
	if not _mag(c) or not vol():
		if _mag(c):
			klank("ui_draai", vertraging)   # rustig: minder beweging, niet minder geluid
		if halverwege.is_valid():
			halverwege.call()
		return
	_spil(c)
	var rust: Vector2 = _rust(c, "scale", "schaal")
	var tw := _tween(c, "schaal", true)
	if vertraging > 0.0:
		tw.tween_interval(vertraging)
	tw.tween_callback(func() -> void: klank("ui_draai"))   # met de zwiep mee, ook na het vasthouden
	tw.tween_property(c, "scale", Vector2(0.0, rust.y), DRAAI_DICHT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if halverwege.is_valid():
		tw.tween_callback(halverwege)
	tw.tween_property(c, "scale", rust, DRAAI_OPEN).from(Vector2(0.0, rust.y)) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_callback(func() -> void: _geland(c, "onder", "")).set_delay(PLOF_LAND * DRAAI_OPEN)
	_klaar(tw, c, "scale")


## Een getal loopt op van `van` naar `naar`; de laatste tekst is altijd exact.
## `fmt` maakt van een int de tekst (standaard str). Niet op labels die een
## check leest (de regel "teksten meteen goed").
static func tel_op(l: Label, van: int, naar: int, duur: float = TEL_DUUR,
		fmt: Callable = Callable(), vertraging: float = 0.0, tik: String = "") -> void:
	if l == null or not is_instance_valid(l):
		return
	var tekst := func(v: int) -> String:
		return String(fmt.call(v)) if fmt.is_valid() else str(v)
	if not _mag(l) or not vol() or van == naar:
		l.text = tekst.call(naar)
		return
	var tw := _tween(l, "tekst", true)
	l.text = tekst.call(van)
	if tik != "":
		# Hooguit 8 tikjes, op de momenten dat het getal ze passeert (QUAD out:
		# waarde v op tijd 1 - sqrt(1 - v)), elk iets hoger.
		var n: int = mini(absi(naar - van), 8)
		for j in n:
			var v: float = float(j + 1) / float(n)
			klank(tik, vertraging + duur * (1.0 - sqrt(1.0 - v)), 1.0 + 0.035 * float(j))
	if vertraging > 0.0:
		tw.tween_interval(vertraging)
	tw.tween_method(func(f: float) -> void: l.text = tekst.call(int(round(f))),
		float(van), float(naar), duur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: l.text = tekst.call(naar))


## Wacht op jou: na DUW_NA s zonder invoer een zachte puls, dan niet vaker dan
## elke DUW_ELKE s. Stopt vanzelf met de knop (de tween hangt eraan).
static func duw(b: Control, na: float = DUW_NA) -> void:
	if not _mag(b) or not vol():
		return
	var tw := _tween(b, "duw")
	tw.set_meta("ub_lus", true)
	tw.set_loops()
	# De eerste puls mag `na` s na het verschijnen (daarna elke DUW_ELKE s).
	b.set_meta("ub_duw_ms", Time.get_ticks_msec() - int((DUW_ELKE - na) * 1000.0))
	tw.tween_interval(1.0)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(b) or not b.is_visible_in_tree():
			return
		if b is BaseButton and ((b as BaseButton).disabled or b.has_meta("ub_in")):
			return
		var nu := Time.get_ticks_msec()
		if nu - _laatste_invoer_ms < int(na * 1000.0):
			return
		if nu - int(b.get_meta("ub_duw_ms", 0)) < int(DUW_ELKE * 1000.0):
			return
		b.set_meta("ub_duw_ms", nu)
		puls(b))


## "+1" dat van `bij` omhoog zweeft en vervaagt, op `ouder` (vrij geplaatst,
## vangt geen invoer, ruimt zichzelf op).
static func zweef(tekst: String, bij: Control, ouder: Control, kleur: Color = Color(0.851, 0.722, 0.29),
		grootte: int = 28) -> void:
	if not _mag(ouder) or bij == null or not is_instance_valid(bij) or not bij.is_inside_tree():
		return
	klank("ui_munt")
	var l := Label.new()
	l.name = "Zweef"
	l.text = tekst
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", grootte)
	l.add_theme_color_override("font_color", kleur)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.05))
	l.add_theme_constant_override("outline_size", maxi(2, grootte / 5))
	var f := UiAssets.font("kop")
	if f != null:
		l.add_theme_font_override("font", f)
	ouder.add_child(l)
	l.reset_size()
	var midden: Vector2 = bij.get_global_rect().get_center()
	l.position = ouder.get_global_transform().affine_inverse() * midden - l.size * 0.5
	var tw := l.create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_speed_scale(_tempo)
	tw.set_meta("ub", true)
	tw.set_parallel(true)
	if vol():
		tw.tween_property(l, "position:y", l.position.y - float(grootte) * 1.4, ZWEEF_DUUR) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, ZWEEF_DUUR * 0.5).set_delay(ZWEEF_DUUR * 0.5)
	tw.chain().tween_callback(l.queue_free)


# --- STOF en SCHADUW (6 oktober) ---------------------------------------------------

## Stof en schaduw: alleen bij volle beweging (rustig houdt alleen het geluid)
## en met een sterkte boven 0.
static func wolk_aan() -> bool:
	return vol() and _wolk_sterkte > 0.0


## Dev-knop `ui_wolk` (sfeer-paneel): 0 = geen stof en schaduw, 1 = normaal,
## 2 = dubbel zo groot.
static func zet_wolk(s: float) -> void:
	_wolk_sterkte = clampf(s, 0.0, 2.0)


static func wolk_sterkte() -> float:
	return _wolk_sterkte


## Hoeveel wolkjes er tot nu toe kwamen (de inkomcheck telt mee).
static func wolken() -> int:
	return _wolken


## De wolkjes die nu lopen, elk {node, waar, bron (Rect2 in de ruimte van node)}.
## Voor checks.
static func actieve_wolken() -> Array:
	var uit: Array = []
	for info in _actief:
		uit.append({"node": info["node"], "waar": info["waar"], "bron": info["bron"]})
	return uit


## Een stofwolkje ACHTER `c`: een eigen canvas-item onder dat van c, met
## draw_behind_parent. Het stof komt onder het ding vandaan, beweegt en schaalt
## mee, wordt verborgen met het ding, en er komt geen node bij. `waar`: "onder"
## (landen), "rondom" (een stempel), "klik" (een knop indrukken). Ruimt zichzelf
## op na WOLK_DUUR, of meteen als c de boom verlaat.
static func wolkje(c: Control, waar: String = "onder") -> void:
	if not wolk_aan() or not _mag(c) or c.clip_contents or c.size.x < 2.0 or c.size.y < 2.0:
		return
	if _rng_wolk == null:
		_rng_wolk = RandomNumberGenerator.new()
		_rng_wolk.seed = 6102026
	var ci := RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(ci, c.get_canvas_item())
	RenderingServer.canvas_item_set_draw_behind_parent(ci, true)
	# Het canvas-item erft de modulate van c: een getint icoon (de rode sabels)
	# zou rood stof geven. Die tint delen we eruit (de alpha blijft meedoen).
	var tint: Color = c.modulate
	RenderingServer.canvas_item_set_modulate(ci, Color(1.0 / maxf(tint.r, 0.08), 1.0 / maxf(tint.g, 0.08),
		1.0 / maxf(tint.b, 0.08), 1.0))
	var plukjes := _plukjes(c.size, waar)
	var info := {"ci": ci, "node": c, "waar": waar, "bron": Rect2(Vector2.ZERO, c.size)}
	_actief.append(info)
	_wolken += 1
	var weg := func() -> void: _wolk_weg(info, true)
	info["weg"] = weg
	c.tree_exiting.connect(weg, CONNECT_ONE_SHOT)
	# Aan de boom, niet aan c: dan loopt hij af en ruimt hij op wat er ook met c gebeurt.
	var tw := c.get_tree().create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_speed_scale(_tempo)
	tw.set_meta("ub", true)
	info["tw"] = tw
	tw.tween_method(func(f: float) -> void: _teken_wolk(ci, plukjes, f), 0.0, 1.0,
		WOLK_KLIK_DUUR if waar == "klik" else WOLK_DUUR)
	tw.tween_callback(func() -> void: _wolk_weg(info, false))


## Een wolkje opruimen: het canvas-item weg, de haak los. `stop` = ook de tween
## stoppen (als c eerder de boom verlaat; aan het eind loopt hij zelf af).
## De lambda's houden `info` vast en `info` de tween en de haak: die sleutels
## gaan eruit, anders houden ze elkaar in leven (een lek per wolkje).
static func _wolk_weg(info: Dictionary, stop: bool) -> void:
	var i := _actief.find(info)
	if i < 0:
		return
	_actief.remove_at(i)
	if stop and info["tw"] is Tween and (info["tw"] as Tween).is_valid():
		(info["tw"] as Tween).kill()
	RenderingServer.free_rid(info["ci"])
	var c: Variant = info["node"]
	if is_instance_valid(c) and (c as Node).tree_exiting.is_connected(info["weg"]):
		(c as Node).tree_exiting.disconnect(info["weg"])
	info.erase("tw")
	info.erase("weg")


## De plukjes stof van een wolkje (begin, eind, straal, wanneer), uit een eigen
## rng. Een plukje is nooit groter dan zo; een groot paneel krijgt meer stof
## langs de rand, niet dikker stof.
static func _plukjes(maat: Vector2, waar: String) -> Array:
	var s: float = _wolk_sterkte
	var rng := _rng_wolk
	var uit: Array = []
	match waar:
		"rondom":
			# een stempel drukt de lucht weg: een kring plukjes die naar buiten waaien
			var r: float = clampf(minf(maat.x, maat.y) * 0.2, 8.0, 18.0) * s
			var n: int = clampi(int((maat.x + maat.y) * 2.0 / 45.0), 8, 18)
			var midden := maat * 0.5
			for i in n:
				var p := _op_rand(maat, (float(i) + rng.randf_range(0.0, 0.6)) / float(n))
				var weg := (p - midden).normalized()
				uit.append(_plukje(p + weg * r * 0.3, p + weg * r * rng.randf_range(1.3, 2.1), r, rng))
		"klik":
			# een knop die je indrukt: een paar plukjes bij de onderhoeken
			var r: float = clampf(maat.y * 0.18, 7.0, 16.0) * s
			for kant in [-1.0, 1.0]:
				for j in 2:
					var x: float = maat.x * 0.5 + kant * (maat.x * 0.5 + r * rng.randf_range(-0.6, 0.2))
					var p := Vector2(x, maat.y - r * rng.randf_range(0.0, 0.4))
					var naar := p + Vector2(kant * r * rng.randf_range(0.9, 1.7), -r * rng.randf_range(0.1, 0.6))
					uit.append(_plukje(p, naar, r * rng.randf_range(0.8, 1.1), rng))
		_:
			# landen: bij elke onderhoek waait een wolkje onder het ding vandaan
			# (een klontje van twee of drie plukjes die elkaar overlappen), nooit een
			# rij langs de hele rand
			var r: float = clampf(maat.y * 0.24, 10.0, 26.0) * s
			var n: int = 3 if maat.x > 160.0 else 2   # per hoek
			for kant in [-1.0, 1.0]:
				var hoek_x: float = maat.x * 0.5 + kant * maat.x * 0.5
				for j in n:
					var p := Vector2(hoek_x - kant * r * (0.55 * float(j) + rng.randf_range(-0.15, 0.25)),
						maat.y - r * rng.randf_range(0.05, 0.4))
					var naar := p + Vector2(kant * r * rng.randf_range(1.1, 2.0) * (1.0 - 0.18 * float(j)),
						r * (rng.randf_range(-0.65, -0.1) + 0.2 * float(j)))
					uit.append(_plukje(p, naar, r * (1.0 - 0.14 * float(j)) * rng.randf_range(0.8, 1.15), rng))
	return uit


static func _plukje(van: Vector2, naar: Vector2, r: float, rng: RandomNumberGenerator) -> Dictionary:
	return {"van": van, "naar": naar, "r0": r * 0.5, "r1": r * rng.randf_range(1.0, 1.4),
		"v": rng.randf_range(0.0, 0.1), "a": rng.randf_range(0.65, 0.85), "tint": rng.randf_range(-0.05, 0.02)}


## Een punt op de rand van een rechthoek, `u` van 0 tot 1 rond de omtrek.
static func _op_rand(maat: Vector2, u: float) -> Vector2:
	var d: float = fposmod(u, 1.0) * 2.0 * (maat.x + maat.y)
	if d < maat.x:
		return Vector2(d, 0.0)
	d -= maat.x
	if d < maat.y:
		return Vector2(maat.x, d)
	d -= maat.y
	if d < maat.x:
		return Vector2(maat.x - d, maat.y)
	return Vector2(0.0, maat.y - (d - maat.x))


## Een beeld van het wolkje op `f` (0..1): elk plukje waait naar buiten en iets
## omhoog, zwelt op en lost op. Eerst de schaduwkant van alle plukjes
## (rechtsonder, donker: zichtbaar op licht perkament), dan de lichte kernen
## (zichtbaar op hout en op het bord); samen lezen ze als een wolkje.
static func _teken_wolk(ci: RID, plukjes: Array, f: float) -> void:
	RenderingServer.canvas_item_clear(ci)
	for laag in 2:
		for p in plukjes:
			var v: float = float(p["v"])
			var lf: float = clampf((f - v) / maxf(1.0 - v, 0.01), 0.0, 1.0)
			if lf <= 0.0 or lf >= 1.0:
				continue
			var e: float = 1.0 - pow(1.0 - lf, 3.0)
			var alfa: float = float(p["a"]) * minf(lf / 0.1, 1.0) * (1.0 - smoothstep(0.4, 1.0, lf))
			var r: float = lerpf(float(p["r0"]), float(p["r1"]), e)
			var mid: Vector2 = (p["van"] as Vector2).lerp(p["naar"], e)
			if laag == 0:
				_schijf(ci, mid + Vector2(r * 0.12, r * 0.22), r * 1.08, Color(STOF_RAND, alfa * 0.45), 0.35)
			else:
				var t: float = float(p["tint"])
				_schijf(ci, mid, r, Color(STOF.r + t, STOF.g + t, STOF.b + t, alfa), 0.5)


## Een zachte schijf: vol tot `hard` maal de straal, dan naar doorzichtig (een
## waaier van driehoeken met een kleur per hoekpunt).
static func _schijf(ci: RID, mid: Vector2, r: float, kleur: Color, hard: float = 0.6) -> void:
	if _cirkel.is_empty():
		for i in 16:
			var h := TAU * float(i) / 16.0
			_cirkel.append(Vector2(cos(h), sin(h)))
	var n := _cirkel.size()
	var punten := PackedVector2Array()
	var kleuren := PackedColorArray()
	var hoeken := PackedInt32Array()
	var rand := Color(kleur, 0.0)
	punten.append(mid)
	kleuren.append(kleur)
	for d in _cirkel:
		punten.append(mid + d * r * hard)
		kleuren.append(kleur)
		punten.append(mid + d * r)
		kleuren.append(rand)
	for i in n:
		var a := 1 + 2 * i
		var b := 1 + 2 * ((i + 1) % n)
		hoeken.append_array(PackedInt32Array([0, a, b, a, a + 1, b + 1, a, b + 1, b]))
	RenderingServer.canvas_item_add_triangle_array(ci, hoeken, punten, kleuren)


## De schaduw onder een knop naar `doel` (0..1) laten gaan: een zachte ovaal
## onder de onderrand, ACHTER de knop (eigen canvas-item, geen node). Bij 0 gaat
## hij weg en wordt opgeruimd; verlaat de knop de boom, dan meteen.
static func _schaduw(b: BaseButton, doel: float) -> void:
	if not is_instance_valid(b):
		return
	var ci: RID = b.get_meta("ub_schaduw", RID())
	if doel <= 0.0:
		if not ci.is_valid():
			return
		if not _mag(b):
			_schaduw_weg(b)
			return
	else:
		if not wolk_aan() or not _mag(b):
			return
		if not ci.is_valid():
			ci = RenderingServer.canvas_item_create()
			RenderingServer.canvas_item_set_parent(ci, b.get_canvas_item())
			RenderingServer.canvas_item_set_draw_behind_parent(ci, true)
			RenderingServer.canvas_item_set_modulate(ci, Color(1, 1, 1, 0))
			b.set_meta("ub_schaduw", ci)
			b.set_meta("ub_schaduw_a", 0.0)
			var weg := func() -> void: _schaduw_weg(b)
			b.set_meta("ub_schaduw_weg", weg)
			b.tree_exiting.connect(weg, CONNECT_ONE_SHOT)
		# Elke keer opnieuw tekenen: de knop kan intussen een andere maat hebben.
		# Een ovaal net onder de onderrand, iets breder dan de knop: wat onder de
		# knop uitsteekt is de schaduw van een knop die loskomt van het papier.
		RenderingServer.canvas_item_clear(ci)
		var ry: float = clampf(b.size.y * 0.3, 8.0, 22.0)
		var midden := Vector2(b.size.x * 0.5, b.size.y + 2.0)
		RenderingServer.canvas_item_add_set_transform(ci,
			Transform2D(0.0, Vector2(b.size.x * 0.5 + 8.0, ry), 0.0, midden))
		var kleur := SCHADUW_KLEUR
		kleur.a = minf(SCHADUW_KLEUR.a * _wolk_sterkte, 0.8)
		_schijf(ci, Vector2.ZERO, 1.0, kleur, 0.45)
	var van: float = float(b.get_meta("ub_schaduw_a", 0.0))
	var tw := _tween(b, "schaduw")
	tw.tween_method(func(a: float) -> void: _schaduw_zet(b, ci, a), van, doel, SCHADUW_DUUR) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if doel <= 0.0:
		tw.tween_callback(func() -> void: _schaduw_weg(b, false))


static func _schaduw_zet(b: Object, ci: RID, a: float) -> void:
	RenderingServer.canvas_item_set_modulate(ci, Color(1, 1, 1, a))
	if is_instance_valid(b):
		(b as Node).set_meta("ub_schaduw_a", a)


## De schaduw weg en opgeruimd (verborgen, uit de boom, uitgezet, of aan het
## eind van het vervagen; dan `stop` false: die tween loopt zelf af).
static func _schaduw_weg(b: Object, stop: bool = true) -> void:
	if not is_instance_valid(b) or not (b as Node).has_meta("ub_schaduw"):
		return
	var n := b as Node
	if stop:
		_stop_kanaal(n, "schaduw")
	else:
		n.remove_meta("ub_tw_schaduw")
	RenderingServer.free_rid(n.get_meta("ub_schaduw"))
	var weg: Variant = n.get_meta("ub_schaduw_weg", null)
	if weg is Callable and n.tree_exiting.is_connected(weg):
		n.tree_exiting.disconnect(weg)
	n.remove_meta("ub_schaduw")
	n.remove_meta("ub_schaduw_a")
	n.remove_meta("ub_schaduw_weg")


## Heeft deze knop nu een schaduw, en hoe sterk (0..1)? Voor checks.
static func heeft_schaduw(b: Node) -> bool:
	return is_instance_valid(b) and b.has_meta("ub_schaduw")


static func schaduw_alfa(b: Node) -> float:
	return float(b.get_meta("ub_schaduw_a", 0.0)) if heeft_schaduw(b) else 0.0


# --- WEG --------------------------------------------------------------------------

## Een losse laag gaat weg: voor de logica meteen (nieuwe naam, meta ub_weg,
## invoer uit), voor het oog in WEG_DUUR. Staat de beweging uit: remove_child en
## queue_free zoals altijd.
static func spook_weg(laag: Control) -> void:
	if laag == null or not is_instance_valid(laag):
		return
	var ouder := laag.get_parent()
	if not _mag(laag) or ouder == null:
		if ouder != null:
			ouder.remove_child(laag)
		laag.queue_free()
		return
	laag.name = String(laag.name) + "_weg"
	laag.set_meta("ub_weg", true)
	_negeer_muis(laag)
	for kanaal in ["schaal", "alfa", "pos", "rot"]:
		_stop_kanaal(laag, kanaal)
	var tw := laag.create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_speed_scale(_tempo)
	tw.set_meta("ub", true)
	tw.set_parallel(true)
	tw.tween_property(laag, "modulate:a", 0.0, _duur(WEG_DUUR)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if vol():
		_spil(laag)
		tw.tween_property(laag, "scale", laag.scale * WEG_NAAR, WEG_DUUR).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(laag.queue_free)


static func _negeer_muis(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for kind in n.get_children():
		_negeer_muis(kind)


# --- Knoppen (UiThema._bij_nieuwe_node) ----------------------------------------------

## Elke knop deukt in en veert terug; hover alleen met een echte muis. Een keer
## per knop. Let op de volgorde van Godot: bij het loslaten komt `pressed` VOOR
## `button_up`, en een callback haalt de knop soms al uit de boom.
static func koppel_knop(b: BaseButton) -> void:
	if b == null or b.has_meta("ub_knop"):
		return
	if _forceer != 1 and _is_headless():
		return   # headless niets aanhaken: de checks blijven byte-identiek
	b.set_meta("ub_knop", true)
	b.button_down.connect(func() -> void: _druk(b))
	b.button_up.connect(func() -> void: _los(b))
	b.mouse_entered.connect(func() -> void: _hover_in(b))
	b.mouse_exited.connect(func() -> void: _hover_uit(b))
	b.visibility_changed.connect(func() -> void: _zichtbaar(b))
	b.draw.connect(func() -> void: _bij_teken(b))
	b.gui_input.connect(func(ev: InputEvent) -> void: _knop_invoer(b, ev))


## Opt-out (lui bekeken en onthouden): meta "ub_uit" op de knop of een voorouder,
## de Model-tuner en de Trainer, en knoppen die iemand anders geschaald of
## gedraaid heeft.
static func _uit(b: Control) -> bool:
	if b.has_meta("ub_uit_c"):
		return bool(b.get_meta("ub_uit_c"))
	var uit := false
	var n: Node = b
	while n != null:
		if n.has_meta("ub_uit"):
			uit = true
			break
		n = n.get_parent()
	if not uit and b.is_inside_tree() and b.get_tree().current_scene != null:
		var pad: String = b.get_tree().current_scene.scene_file_path
		if pad.ends_with("ModelTuner.tscn") or pad.ends_with("Trainer.tscn"):
			uit = true
	if not uit and not b.has_meta("ub_rust_scale") and (b.rotation != 0.0 or b.scale != Vector2.ONE):
		uit = true
	b.set_meta("ub_uit_c", uit)
	return uit


static func _druk_maat(b: Control) -> float:
	return clampf(1.0 - 10.0 / maxf(maxf(b.size.x, b.size.y), 1.0), 0.94, 0.985)


static func _hover_maat(b: Control) -> float:
	return 1.0 + clampf(8.0 / maxf(maxf(b.size.x, b.size.y), 1.0), 0.02, 0.05)


## Indrukken: de knop deukt in, er komt een wolkje onder vandaan en een zacht
## houten tokje (het klikgeluid van het scherm zelf komt bij het loslaten).
static func _druk(b: BaseButton) -> void:
	if not _mag(b) or _uit(b):
		return
	b.set_meta("ub_in", true)
	# Een echte druk zet press_attempt VOOR button_down; dan mag het vangnet in
	# _bij_teken loslaten zodra de knop niet meer ingedrukt is.
	if b.is_pressed() and not b.toggle_mode:
		b.set_meta("ub_in_echt", true)
	klank("ui_knop")   # ook bij rustig
	if rustig():
		_donker(b, true)
		return
	_spil(b)
	var rust: Vector2 = _rust(b, "scale", "schaal")
	b.set_meta("ub_vast_scale", true)
	var tw := _tween(b, "schaal")
	tw.tween_property(b, "scale", rust * _druk_maat(b), DRUK_DUUR).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	wolkje(b, "klik")
	if heeft_schaduw(b):
		_schaduw(b, SCHADUW_DRUK)


static func _los(b: BaseButton) -> void:
	if not is_instance_valid(b) or not b.has_meta("ub_in"):
		return
	b.remove_meta("ub_in")
	b.remove_meta("ub_in_echt")
	_donker(b, false)
	var hover := _echte_muis and _mag(b) and b.is_hovered() and not b.disabled and vol()
	if heeft_schaduw(b):
		_schaduw(b, 1.0 if hover else 0.0)
	if not b.has_meta("ub_rust_scale"):
		return
	var rust: Vector2 = b.get_meta("ub_rust_scale")
	if not _mag(b):
		# uit de boom gehaald (menu naar menu) of beweging uit: meteen in rust
		_zet_rust(b)
		return
	var doel := rust * (_hover_maat(b) if hover else 1.0)
	var tw := _tween(b, "schaal")
	if b.toggle_mode and b.button_pressed:
		tw.tween_property(b, "scale", doel * 1.06, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "scale", doel, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(b, "scale", doel, VEER_DUUR).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not hover:
		_klaar(tw, b, "scale")


## Hover (alleen een echte muis): een zacht geluidje (ook bij rustig), en bij
## volle beweging komt de knop iets naar voren met een schaduw eronder.
static func _hover_in(b: BaseButton) -> void:
	if not _mag(b) or not _echte_muis or b.disabled or b.has_meta("ub_in") or _uit(b):
		return
	klank("ui_hover")
	if not vol():
		return
	_spil(b)
	var rust: Vector2 = _rust(b, "scale", "schaal")
	b.set_meta("ub_vast_scale", true)
	var tw := _tween(b, "schaal")
	tw.tween_property(b, "scale", rust * _hover_maat(b), HOVER_DUUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_schaduw(b, 1.0)


static func _hover_uit(b: BaseButton) -> void:
	if not is_instance_valid(b) or b.has_meta("ub_in"):
		return
	_schaduw(b, 0.0)
	if not b.has_meta("ub_rust_scale"):
		return
	if not _mag(b):
		_zet_rust(b)
		return
	var rust: Vector2 = b.get_meta("ub_rust_scale")
	var tw := _tween(b, "schaal")
	tw.tween_property(b, "scale", rust, HOVER_DUUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_klaar(tw, b, "scale")


## Verborgen: meteen terug in rust (anders hangt de knop ingedrukt als hij terugkomt).
static func _zichtbaar(b: BaseButton) -> void:
	if is_instance_valid(b) and not b.visible:
		b.remove_meta("ub_in")
		b.remove_meta("ub_in_echt")
		_donker(b, false)
		_schaduw_weg(b)
		_zet_rust(b)


## Vangnet: uitgezet of weggescrold terwijl hij ingedrukt stond (Godot stuurt dan
## geen button_up). Toggles lopen via button_up.
static func _bij_teken(b: BaseButton) -> void:
	if b.has_meta("ub_in") and (b.disabled or (b.has_meta("ub_in_echt") and not b.is_pressed())):
		_los(b)


static func _knop_invoer(b: BaseButton, ev: InputEvent) -> void:
	if b.disabled and ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed \
			and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not _uit(b):
		schud(b)


static func _zet_rust(b: Control) -> void:
	_stop_kanaal(b, "schaal")
	if b.has_meta("ub_rust_scale"):
		b.scale = b.get_meta("ub_rust_scale")
		b.remove_meta("ub_rust_scale")
	b.remove_meta("ub_vast_scale")


## Rustig: indrukken is kort donkerder in plaats van kleiner.
static func _donker(b: CanvasItem, aan_: bool) -> void:
	if aan_:
		if not b.has_meta("ub_donker"):
			b.set_meta("ub_donker", b.self_modulate)
			b.self_modulate = b.self_modulate * Color(0.85, 0.85, 0.85, 1.0)
	elif b.has_meta("ub_donker"):
		b.self_modulate = b.get_meta("ub_donker")
		b.remove_meta("ub_donker")

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

# --- Schakelaar ---------------------------------------------------------------------
static var _stand: int = NORMAAL
static var _tempo: float = 1.0
static var _forceer: int = -1           # -1 automatisch (headless uit), 0 altijd uit, 1 ook headless aan
static var _headless: int = -1          # lui: -1 onbekend
static var _heeft_ratio: int = -1       # lui: kent Control pivot_offset_ratio?
static var _echte_muis: bool = true
static var _laatste_invoer_ms: int = 0
static var _weg_frame: int = -100
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


static func _schaal_van(c: Control, van: float, vertraging: float, duur: float,
		trans: int = Tween.TRANS_BACK, ratio: Vector2 = Vector2(0.5, 0.5)) -> void:
	_spil(c, ratio)
	var rust: Vector2 = _rust(c, "scale", "schaal")
	var tw := _tween(c, "schaal", true)
	c.scale = rust * van
	if vertraging > 0.0:
		tw.tween_interval(vertraging)
	tw.tween_property(c, "scale", rust, duur).from(rust * van) \
		.set_trans(trans).set_ease(Tween.EASE_OUT)
	_klaar(tw, c, "scale")


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
## al vrijgegeven items tellen niet mee.
static func inkom_rij(items: Array, vertraging: float = 0.0, stap: float = RIJ_STAP) -> void:
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
	for i in lijst.size():
		var n: CanvasItem = lijst[i]
		var v: float = vertraging + echte_stap * float(i)
		fade_in(n, v, RIJ_DUUR)
		if vol() and n is Control:
			_schaal_van(n as Control, RIJ_VAN, v, RIJ_DUUR)


## Een vrij geplaatst stuk (niet in een container) schuift van `van` pixels
## naast zijn rust naar binnen.
static func schuif_in(n: Control, van: Vector2, vertraging: float = 0.0,
		duur: float = SCHUIF_DUUR, veer: bool = false) -> void:
	if not _mag(n):
		return
	fade_in(n, vertraging, duur * 0.7)
	if not vol():
		return
	var rust: Vector2 = _rust(n, "position", "pos")
	var tw := _tween(n, "pos", true)
	n.position = rust + van
	if vertraging > 0.0:
		tw.tween_interval(vertraging)
	tw.tween_property(n, "position", rust, duur).from(rust + van) \
		.set_trans(Tween.TRANS_BACK if veer else Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_klaar(tw, n, "position")


# --- TIK --------------------------------------------------------------------------

## Keuze of nieuw element ploft erin. `met_alfa` false voor nodes waarvan de
## modulate een tint draagt (iconen, portretten): dan alleen schaal.
static func plof(c: Control, vertraging: float = 0.0, van: float = POP_VAN,
		met_alfa: bool = true, ratio: Vector2 = Vector2(0.5, 0.5)) -> void:
	if not _mag(c):
		return
	if met_alfa:
		fade_in(c, vertraging, POP_DUUR * 0.6)
	if vol():
		_schaal_van(c, van, vertraging, POP_DUUR, Tween.TRANS_BACK, ratio)


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
	if not _mag(c) or not vol():
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


## Stempel: van groot met een draai erop drukken en naveren. `verberg` houdt het
## ding tot de stempel valt op een schaal van bijna niets (nooit via modulate:
## die wordt gemeten). Alleen schaal en draai.
static func stempel(c: Control, vertraging: float = 0.0, verberg: bool = false) -> void:
	if not _mag(c) or not vol():
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
	tw.tween_property(c, "scale", rs, STEMPEL_UIT).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_rot.tween_callback(func() -> void: c.rotation = rr + deg_to_rad(STEMPEL_DRAAI))
	tw_rot.tween_property(c, "rotation", rr, STEMPEL_IN + STEMPEL_UIT).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_klaar(tw, c, "scale")
	_klaar(tw_rot, c, "rotation")


## Omdraaien als een kaart: smal naar 0 om het midden, halverwege `halverwege`
## (bv. de rug weg), en weer open met een veertje. Uit of rustig: meteen
## `halverwege`, zonder draai.
static func draai_om(c: Control, halverwege: Callable, vertraging: float = 0.0) -> void:
	if not _mag(c) or not vol():
		if halverwege.is_valid():
			halverwege.call()
		return
	_spil(c)
	var rust: Vector2 = _rust(c, "scale", "schaal")
	var tw := _tween(c, "schaal", true)
	if vertraging > 0.0:
		tw.tween_interval(vertraging)
	tw.tween_property(c, "scale", Vector2(0.0, rust.y), DRAAI_DICHT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if halverwege.is_valid():
		tw.tween_callback(halverwege)
	tw.tween_property(c, "scale", rust, DRAAI_OPEN).from(Vector2(0.0, rust.y)) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_klaar(tw, c, "scale")


## Een getal loopt op van `van` naar `naar`; de laatste tekst is altijd exact.
## `fmt` maakt van een int de tekst (standaard str). Niet op labels die een
## check leest (de regel "teksten meteen goed").
static func tel_op(l: Label, van: int, naar: int, duur: float = TEL_DUUR,
		fmt: Callable = Callable(), vertraging: float = 0.0) -> void:
	if l == null or not is_instance_valid(l):
		return
	var tekst := func(v: int) -> String:
		return String(fmt.call(v)) if fmt.is_valid() else str(v)
	if not _mag(l) or not vol() or van == naar:
		l.text = tekst.call(naar)
		return
	var tw := _tween(l, "tekst", true)
	l.text = tekst.call(van)
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


static func _druk(b: BaseButton) -> void:
	if not _mag(b) or _uit(b):
		return
	b.set_meta("ub_in", true)
	# Een echte druk zet press_attempt VOOR button_down; dan mag het vangnet in
	# _bij_teken loslaten zodra de knop niet meer ingedrukt is.
	if b.is_pressed() and not b.toggle_mode:
		b.set_meta("ub_in_echt", true)
	if rustig():
		_donker(b, true)
		return
	_spil(b)
	var rust: Vector2 = _rust(b, "scale", "schaal")
	b.set_meta("ub_vast_scale", true)
	var tw := _tween(b, "schaal")
	tw.tween_property(b, "scale", rust * _druk_maat(b), DRUK_DUUR).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func _los(b: BaseButton) -> void:
	if not is_instance_valid(b) or not b.has_meta("ub_in"):
		return
	b.remove_meta("ub_in")
	b.remove_meta("ub_in_echt")
	_donker(b, false)
	if not b.has_meta("ub_rust_scale"):
		return
	var rust: Vector2 = b.get_meta("ub_rust_scale")
	if not _mag(b):
		# uit de boom gehaald (menu naar menu) of beweging uit: meteen in rust
		_zet_rust(b)
		return
	var hover := _echte_muis and b.is_hovered() and not b.disabled and vol()
	var doel := rust * (_hover_maat(b) if hover else 1.0)
	var tw := _tween(b, "schaal")
	if b.toggle_mode and b.button_pressed:
		tw.tween_property(b, "scale", doel * 1.06, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "scale", doel, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(b, "scale", doel, VEER_DUUR).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not hover:
		_klaar(tw, b, "scale")


static func _hover_in(b: BaseButton) -> void:
	if not _mag(b) or not vol() or not _echte_muis or b.disabled or b.has_meta("ub_in") or _uit(b):
		return
	_spil(b)
	var rust: Vector2 = _rust(b, "scale", "schaal")
	b.set_meta("ub_vast_scale", true)
	var tw := _tween(b, "schaal")
	tw.tween_property(b, "scale", rust * _hover_maat(b), HOVER_DUUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


static func _hover_uit(b: BaseButton) -> void:
	if not is_instance_valid(b) or b.has_meta("ub_in") or not b.has_meta("ub_rust_scale"):
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

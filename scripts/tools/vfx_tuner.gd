extends Node3D

## VFX-tuner (6 oktober 2026, docs/VFX-studio.md; Max: "kan jij voor mij ook
## een studio maken voor allemaal wensen en vfx effecten zoals bloed, stof,
## vuurmonden, vuur, alle soorten eigenlijk"). Het echte bord in het licht van
## het spel, een schutter en een doel, en elk effect uit de catalogus
## (scripts/vfx/vfx_catalogus.gd) om af te spelen en bij te stellen. De
## effecten zelf komen uit dezelfde code als in het spel (scripts/vfx/vfx.gd en
## PawnView). De schuifjes zetten de knoppen live (PawnView.set_fx); Opslaan
## schrijft assets/models/effects_tuning.json, net als de Model-tuner.
##
## Starten: paneelknop "VFX-tuner", of
## `<godot> --path . res://scenes/tools/VfxTuner.tscn`.
## Checks: `-- vfxcheck` en `-- vfxshot <id> [map]` (capture.tscn).

const PAWN_SCENE := preload("res://scenes/game/pawn_view.tscn")
const BOARD_SCENE := preload("res://Board.tscn")
const VFX := preload("res://scripts/vfx/vfx.gd")
const Catalogus := preload("res://scripts/vfx/vfx_catalogus.gd")
const STIJL := preload("res://scripts/vfx/stijl.gd")

const PAWN_Y := 0.05
const SCHUTTER_TEGEL := Vector2i(5, 7)
const DOEL_TEGEL := Vector2i(5, 4)    # drie vakken: alles past tussen de panelen, ook wat erachter valt
const CHARGE_EIND := Vector2i(5, 5)   # de charge landt op het vak voor het doel
const GALOP_VAN := Vector2i(3, 6)     # de galop rijdt dwars door het beeld
const GALOP_NAAR := Vector2i(7, 6)
const SCHOT_NA := 0.25          # het vuurmoment na het begin van de aanval-clip
const DICHTBIJ_MAAT := 7.5      # orthografische maat van de close-up (het spel: 25,5)
const TEMPOS: Array = [1.0, 0.5, 0.25, 0.1]
const LETTER := 20
const BOVEN_HOOGTE := 300.0     # het paneel met de effecten
const ONDER_HOOGTE := 560.0     # het paneel met bediening en knoppen

var _bord: Node3D = null
var _cam: Camera3D = null
var _cam_spel := Transform3D.IDENTITY
var _cam_spel_maat := 25.5
var _cam_basis := Transform3D.IDENTITY   # waar de camera hoort; de schok wiebelt eromheen
var _zon: DirectionalLight3D = null
var _spot: SpotLight3D = null
var _rand: DirectionalLight3D = null
var _env: Environment = null
var _toneel: Node3D = null
var _stijl: MeshInstance3D = null   # de looks over het hele beeld (scripts/vfx/stijl.gd)
var _schutter: PawnView = null
var _doel: PawnView = null
var _rng := RandomNumberGenerator.new()
var _tabel: RulesConfig = null

var _gekozen := "schot_musket"
var _groep := "kruit"
var _fac_schutter: int = Constants.Doctrine.MENS
var _fac_doel: int = Constants.Doctrine.MUIS
var _gen := 0                   # elke keer afspelen telt op: oude callbacks doen dan niets meer
var _herhaal := false
var _donker := false
var _dichtbij := true
var _tempo := 1.0
var _schud_amt := 0.0
var _speelt := false

var _ui: Control = null
var _boven: PanelContainer = null
var _onder: PanelContainer = null
var _groep_knoppen: Dictionary = {}
var _effect_rij: HFlowContainer = null
var _effect_knoppen: Dictionary = {}
var _info: Label = null
var _melding: Label = null
var _speel_knop: Button = null
var _grid: GridContainer = null
var _sliders: Dictionary = {}
var _waarden: Dictionary = {}


func _ready() -> void:
	_rng.seed = 6102026
	_tabel = CRules.actieve_tabel()
	_bouw_wereld()
	_bouw_ui()
	_kies_groep(_groep)
	_kies(_gekozen)
	_bouw_toneel()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


# --- De wereld: bord, licht, camera ---------------------------------------------

func _bouw_wereld() -> void:
	_bord = BOARD_SCENE.instantiate() as Node3D
	add_child(_bord)
	for c in _bord.find_children("*", "Camera3D", true, false):
		_cam = c as Camera3D
		break
	_cam.current = true
	_cam_spel = _cam.transform
	_cam_spel_maat = _cam.size
	# Het licht van het spel (game._setup_battlefield_lighting, zelfde waarden).
	_zon = _bord.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if _zon != null:
		_zon.light_color = Color(1.0, 0.92, 0.8)
		_zon.shadow_enabled = false
	_spot = SpotLight3D.new()
	_spot.light_color = Color(1.0, 0.9, 0.74)
	_spot.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_spot.shadow_enabled = true
	_spot.shadow_blur = 1.2
	_bord.add_child(_spot)
	_rand = DirectionalLight3D.new()
	_rand.rotation_degrees = Vector3(-18.0, 145.0, 0.0)
	_rand.light_color = Color(0.7, 0.73, 0.8)
	_rand.light_specular = 1.4
	_bord.add_child(_rand)
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.58, 0.55, 0.5)
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.adjustment_enabled = true
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.07, 0.065, 0.06)
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_licht()
	_stijl = STIJL.zet_op(_cam)
	_toneel = Node3D.new()
	_toneel.name = "Toneel"
	_bord.add_child(_toneel)


## Het licht met de knoppen van het sfeer-paneel (game._apply_ambiance). Donker
## is een nachtstand om flitsen en vuur te beoordelen.
func _licht() -> void:
	var d: float = 0.3 if _donker else 1.0
	if _zon != null:
		_zon.light_energy = 0.65 * PawnView.fx("world_light", 1.0) * d
	_spot.light_energy = 3.4 * PawnView.fx("spot_light", 1.0) * d
	_spot.spot_range = 14.0 * PawnView.fx("spot_range", 1.0)
	_spot.spot_attenuation = PawnView.fx("spot_atten", 0.9)
	_spot.spot_angle = PawnView.fx("spot_angle", 60.0)
	_spot.spot_angle_attenuation = PawnView.fx("spot_angle_soft", 1.2)
	_spot.position = Vector3(PawnView.fx("spot_x", 5.0), PawnView.fx("spot_height", 7.5), PawnView.fx("spot_z", 5.0))
	var sh: float = PawnView.fx("shadow", 0.75)
	_spot.shadow_enabled = sh > 0.0
	_spot.shadow_opacity = clampf(sh, 0.0, 1.0)
	_spot.shadow_bias = PawnView.fx("shadow_bias", 0.03)
	_spot.shadow_normal_bias = 1.0
	_rand.light_energy = 0.45 * PawnView.fx("rim_light", 1.0) * d
	_env.ambient_light_energy = 0.32 * PawnView.fx("world_ambient", 1.0) * (0.35 if _donker else 1.0)
	var bg: float = 0.015 * PawnView.fx("bg_bright", 1.0)
	_env.background_color = Color(bg, bg, bg * 1.25)
	_env.adjustment_saturation = PawnView.fx("saturation", 0.88)
	_env.adjustment_contrast = PawnView.fx("contrast", 1.12)
	_env.fog_density = PawnView.fx("fog_density", 0.002)


## Spelbeeld (de camera van het bord) of dichtbij (dezelfde hoek, ingezoomd op
## schutter en doel). Het toneel komt midden in het stuk bord tussen de panelen.
func _zet_camera() -> void:
	if _cam == null:
		return
	if _dichtbij:
		var midden := (_tegel(SCHUTTER_TEGEL) + _tegel(DOEL_TEGEL)) * 0.5 + Vector3(0.0, 0.4, 0.0)
		_cam_basis = Transform3D(_cam_spel.basis, midden + _cam_spel.basis.z * 30.0)
		_cam.size = DICHTBIJ_MAAT
	else:
		_cam_basis = _cam_spel
		_cam.size = _cam_spel_maat
	_cam.transform = _cam_basis
	var hoog: float = maxf(get_viewport().get_visible_rect().size.y, 1.0)
	var boven: float = (_boven.size.y if _boven != null else 0.0) / hoog
	var onder: float = (_onder.size.y if _onder != null else 0.0) / hoog
	_cam.v_offset = -(0.5 - (boven + 1.0 - onder) * 0.5) * _cam.size


func _process(delta: float) -> void:
	if _cam == null:
		return
	# Schok (zoals game._update_screen_shake), in echte tijd uitdempend.
	if _schud_amt > 0.001:
		var off := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), 0.0) * _schud_amt
		_cam.transform = Transform3D(_cam_basis.basis, _cam_basis.origin + _cam_basis.basis * off)
		_schud_amt *= exp(-delta / maxf(Engine.time_scale, 0.01) * 14.0)
	elif _cam.transform != _cam_basis:
		_cam.transform = _cam_basis
		_schud_amt = 0.0


func _schud(kracht: float) -> void:
	_schud_amt = maxf(_schud_amt, 0.08 * clampf(kracht, 0.2, 1.6))


# --- Het toneel: schutter en doel ------------------------------------------------

func _tegel(t: Vector2i) -> Vector3:
	return Vector3(float(t.x), 0.0, float(t.y))


func _kent(fac: int, tp: int) -> bool:
	var comp: Array = _tabel.doctrine_data(fac).get("comp", [1, 1, 1])
	return tp >= 0 and tp < comp.size() and int(comp[tp]) > 0


## Een vers toneel: schutter en doel opnieuw, en alles van de vorige keer
## (lijken, bloed, rook, brokstukken) weg. Effecten hangen hun deeltjes aan de
## ouder van de pion of aan de ouder die ze meekrijgen: allebei het toneel.
func _bouw_toneel() -> void:
	if _toneel != null:
		_toneel.queue_free()
	_toneel = Node3D.new()
	_toneel.name = "Toneel"
	_bord.add_child(_toneel)
	# Wie er schiet of rijdt staat in de catalogus (schutter: musket, kanon, ruiter).
	var soort: String = String(Catalogus.effect(_gekozen).get("schutter", "musket"))
	var tp_s: int = Constants.UnitType.INFANTRY
	if soort == "kanon":
		tp_s = Constants.UnitType.ARTILLERY
	elif soort == "ruiter":
		tp_s = Constants.UnitType.CAVALRY
	var fac_s: int = _fac_schutter
	if not _kent(fac_s, tp_s):
		fac_s = Constants.Doctrine.MENS
	var galop: bool = Catalogus.effect(_gekozen).get("speel", "") == "galop_stof"
	_schutter = _pion(fac_s, tp_s, GALOP_VAN if galop else SCHUTTER_TEGEL,
		Vector2i(1, 0) if galop else Vector2i(0, -1), Constants.Team.RED)
	# Wat er geraakt wordt (doel: musket of kanon; een kanon pakt het Varken als
	# de factie er geen heeft).
	var tp_d: int = Constants.UnitType.ARTILLERY if String(Catalogus.effect(_gekozen).get("doel", "musket")) == "kanon" \
		else Constants.UnitType.INFANTRY
	var fac_d: int = _fac_doel if _kent(_fac_doel, tp_d) else Constants.Doctrine.MENS
	_doel = _pion(fac_d, tp_d, DOEL_TEGEL, Vector2i(0, 1), Constants.Team.BLUE)


func _pion(fac: int, tp: int, tegel: Vector2i, richting: Vector2i, team: int) -> PawnView:
	var pv: PawnView = PAWN_SCENE.instantiate()
	pv.team = team
	pv.position = _tegel(tegel) + Vector3(0.0, PAWN_Y, 0.0)
	_toneel.add_child(pv)
	pv.face_dir(richting)
	pv.set_unit_type(tp)
	pv.set_character(fac, tp, null)
	return pv


## De vuurmond van de schutter in de ruimte van het toneel (per model ingemeten
## in de Model-tuner), anders een schatting zoals game._fire_projectile.
func _loop(kanon: bool) -> Vector3:
	if _schutter != null and is_instance_valid(_schutter) and _schutter._tune_key != "":
		return _toneel.to_local(_schutter.muzzle_world())
	var start := _tegel(SCHUTTER_TEGEL)
	var richting := (_tegel(DOEL_TEGEL) - start).normalized()
	return start + richting * 0.35 + Vector3(0.0, 0.55 if kanon else 0.85, 0.0)


func _doelpunt() -> Vector3:
	return _tegel(DOEL_TEGEL) + Vector3(0.0, 0.55, 0.0)


# --- Afspelen -----------------------------------------------------------------------

## Speel het gekozen effect af op een vers toneel. Geeft de tijd terug die het
## ongeveer duurt (voor Herhaal en de checks); 0 = niets af te spelen.
func speel() -> float:
	var e: Dictionary = Catalogus.effect(_gekozen)
	var recept: String = String(e.get("speel", ""))
	if recept == "":
		_melding.text = "Dit effect is nog een wens: nog niets om af te spelen." \
			if String(e.get("status", "")) == "wens" else "Dit effect speelt nog niet in de tuner (%s)." % String(e.get("notitie", ""))
		return 0.0
	_gen += 1
	var gen := _gen
	_bouw_toneel()
	_melding.text = ""
	var duur := 2.5
	match recept:
		"schot_musket":
			_recept_schot(gen, false, false)
		"schot_kanon":
			_recept_schot(gen, true, false)
		"dood_musket":
			_recept_schot(gen, false, true)
			duur = 5.0
		"dood_kanon":
			_recept_schot(gen, true, true)
			duur = 5.0
		"kruitdamp":
			var loop := _loop(false)
			VFX.rook(_toneel, loop, 2, 0.09, (_doelpunt() - loop).normalized())
		"rook_wind":
			# een paar wolken die lang blijven hangen, zodat je de wind ziet
			VFX.rook(_toneel, _loop(false), 4, 0.12, Vector3.ZERO, 2.0)
			duur = 4.0
		"rookring":
			var loop_k := _loop(true)
			var dir_k := (_doelpunt() - loop_k).normalized()
			_schutter.play_attack()
			VFX.vuurmond(_toneel, loop_k, true)
			VFX.rookring(_toneel, loop_k, dir_k)
			VFX.pluim(_toneel, loop_k, dir_k)
			duur = 3.5
		"pankruit":
			var loop_p := _loop(false)
			_schutter.play_attack()
			VFX.pankruit(_toneel, VFX.slot_bij(loop_p, (_doelpunt() - loop_p).normalized()))
			duur = 1.5
		"propjes":
			var loop_v := _loop(false)
			VFX.propjes(_toneel, loop_v, (_doelpunt() - loop_v).normalized(), false)
			duur = 1.5
		"charge_stof":
			_recept_charge(gen)
			duur = 3.0
		"galop_stof":
			_schutter.play_rush()
			var rit := _schutter.create_tween()
			rit.tween_property(_schutter, "position", _tegel(GALOP_NAAR) + Vector3(0.0, PAWN_Y, 0.0), 1.0)
			rit.tween_callback(func() -> void:
				if is_instance_valid(_schutter):
					_schutter.play_idle())
			duur = 2.4
		"koppelwolkje":
			_doel.flash_ring(Color(0.5, 0.85, 1.0))
			var puff: int = int(round(4.0 * PawnView.fx("link_puff", 1.0)))
			if puff > 0:
				VFX.rook(_toneel, _doel.position + Vector3(0.0, 0.45, 0.0), puff, 0.2, Vector3.UP * 0.25, 1.3,
					"white_smoke")
		"vonken":
			VFX.vonken(_toneel, _doelpunt() + Vector3(0.0, 0.05, 0.0), 0.7, "impact_armor", _richting_naar_doel())
		"inslag_materiaal":
			_recept_materialen(gen)
			duur = 3.0
		"explosie":
			VFX.explosie(_toneel, _tegel(DOEL_TEGEL) + Vector3(0.9, 0.0, 0.0), 1.0, _schud)
			duur = 4.0
		"vuur":
			var brand: float = maxf(PawnView.fx("vuur_duur", 12.0), 2.0)
			VFX.vuur(_toneel, _tegel(DOEL_TEGEL) + Vector3(0.8, 0.0, 0.0), 1.0, brand)
			duur = brand + 1.0
		"treffer":
			_treffer(_richting_naar_doel(), 0.7, false)
		"stijl":
			# een look staat altijd aan; een schot laat hem in actie zien
			_recept_schot(gen, false, false)
		"schadegetal":
			VFX.schade_getal(_toneel, _tegel(DOEL_TEGEL) + Vector3(0.0, 1.5, 0.0), "-2")
		"dood_bajonet":
			_doel.play_death(_richting_naar_doel(), 0.7, "melee")
			duur = 5.0
		"doormidden":
			_doel.play_death(_richting_naar_doel(), 1.25, "charge")
			duur = 5.0
		_:
			_melding.text = "Onbekend recept: %s" % recept
			return 0.0
	if _herhaal:
		get_tree().create_timer(duur + 0.6).timeout.connect(func() -> void:
			if gen == _gen and _herhaal and is_inside_tree():
				speel())
	return duur


func _richting_naar_doel() -> Vector3:
	var d := _tegel(DOEL_TEGEL) - _tegel(SCHUTTER_TEGEL)
	return d.normalized() if d.length() > 0.001 else Vector3(0.0, 0.0, -1.0)


## Een schot zoals in het spel: de schutter speelt zijn aanval, op het vuurmoment
## de schot-keten (VFX.schot), bij aankomst vonken en de treffer of de dood
## (kracht als game._hit_feedback: musket 0,75, kanon 1,4 bij een kill).
func _recept_schot(gen: int, kanon: bool, dood: bool) -> void:
	if _schutter != null:
		_schutter.play_attack()
	await get_tree().create_timer(SCHOT_NA).timeout
	if gen != _gen or not is_instance_valid(_toneel):
		return
	var loop := _loop(kanon)
	var doel := _doelpunt()
	var duur: float = VFX.vlucht_duur(_tegel(SCHUTTER_TEGEL).distance_to(_tegel(DOEL_TEGEL)), kanon)
	VFX.schot(_toneel, loop, doel, kanon, duur, _schud)
	await get_tree().create_timer(duur).timeout
	if gen != _gen or not is_instance_valid(_doel):
		return
	var kracht: float = (1.4 if kanon else 0.75) if dood else (1.0 if kanon else 0.35)
	_treffer(_richting_naar_doel(), kracht, dood)


## Een charge zoals in het spel (PawnView.charge_tijdlijn, gedeeld met game.gd):
## de ruiter rijdt aan, springt zodat hij op het vak voor het doel landt (daar
## maakt PawnView zelf het stof), en de klap valt na de landing.
func _recept_charge(gen: int) -> void:
	var afstand: int = absi(SCHUTTER_TEGEL.y - CHARGE_EIND.y)
	var tl: Dictionary = _schutter.charge_tijdlijn(afstand)
	_schutter.play_rush()
	var rit := _schutter.create_tween()
	rit.tween_property(_schutter, "position", _tegel(CHARGE_EIND) + Vector3(0.0, PAWN_Y, 0.0),
		maxf(float(tl.rij_dur), 0.05))
	var sprong: float = float(tl.sprong_start)
	if sprong > 0.0:
		await get_tree().create_timer(sprong).timeout
	if gen != _gen or not is_instance_valid(_schutter):
		return
	_schutter.play_charge()
	await get_tree().create_timer(maxf(float(tl.klap_del) - sprong, 0.0)).timeout
	if gen != _gen or not is_instance_valid(_doel):
		return
	_doel.flash_hit()
	_doel.stagger(_richting_naar_doel())
	_doel.play_hit()


## Drie inslagen na elkaar op het doel, met hun naam erboven: vlees, hout,
## metaal (dezelfde indeling als het inslaggeluid).
func _recept_materialen(gen: int) -> void:
	var punt := _tegel(DOEL_TEGEL) + Vector3(0.0, 0.6, 0.0)
	for paar in [["impact_flesh", "vlees"], ["impact_wood", "hout"], ["impact_armor", "metaal"]]:
		if gen != _gen or not is_instance_valid(_toneel):
			return
		VFX.vonken(_toneel, punt, 0.8, String(paar[0]), _richting_naar_doel())
		VFX.schade_getal(_toneel, punt + Vector3(0.0, 0.9, 0.0), String(paar[1]), Color(1.0, 0.95, 0.85))
		_schud(0.5)
		await get_tree().create_timer(0.8).timeout


## De treffer (game._hit_feedback): vonken, schok, en dan de dood of de wond
## met het schadegetal.
func _treffer(richting: Vector3, kracht: float, dood: bool) -> void:
	VFX.vonken(_toneel, _tegel(DOEL_TEGEL) + Vector3(0.0, 0.6, 0.0), kracht,
		PawnView.impact_categorie(_doel._unit_type, _doel.archetype()), richting)
	_schud(kracht)
	if dood:
		_doel.play_death(richting, kracht, "shot")
		return
	_doel.flash_hit()
	_doel.stagger(richting)
	_doel.play_hit()
	_doel.play_wound(richting)
	VFX.schade_getal(_toneel, _tegel(DOEL_TEGEL) + Vector3(0.0, 1.5, 0.0), "-1")


# --- De bediening ---------------------------------------------------------------

func _bouw_ui() -> void:
	var laag := CanvasLayer.new()
	add_child(laag)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.set_meta("ub_uit", true)   # een werkbank: geen UI-beweging, geen tokjes
	_ui.theme = _thema()
	laag.add_child(_ui)

	_boven = PanelContainer.new()
	_boven.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_boven.custom_minimum_size = Vector2(0.0, BOVEN_HOOGTE)
	_ui.add_child(_boven)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 6)
	_boven.add_child(bv)
	var titel := Label.new()
	titel.text = "VFX-tuner: elk effect afspelen en bijstellen op het echte bord"
	titel.add_theme_font_size_override("font_size", LETTER + 4)
	bv.add_child(titel)
	var groepen := HFlowContainer.new()
	bv.add_child(groepen)
	for g in Catalogus.GROEPEN:
		var b := Button.new()
		b.text = String(g.naam)
		b.toggle_mode = true
		b.pressed.connect(_kies_groep.bind(String(g.id)))
		groepen.add_child(b)
		_groep_knoppen[String(g.id)] = b
	_effect_rij = HFlowContainer.new()
	bv.add_child(_effect_rij)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
	bv.add_child(_info)

	_onder = PanelContainer.new()
	_onder.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_onder.offset_top = -ONDER_HOOGTE
	_ui.add_child(_onder)
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 6)
	_onder.add_child(ov)
	var rij1 := HFlowContainer.new()
	ov.add_child(rij1)
	_speel_knop = Button.new()
	_speel_knop.text = "  SPEEL  "
	_speel_knop.add_theme_font_size_override("font_size", LETTER + 6)
	_speel_knop.pressed.connect(func() -> void: speel())
	rij1.add_child(_speel_knop)
	rij1.add_child(_vinkje("herhaal", false, func(aan: bool) -> void:
		_herhaal = aan
		if aan:
			speel()))
	var tempo := OptionButton.new()
	for t in TEMPOS:
		tempo.add_item("tempo %sx" % String.num(float(t), 2).replace(".", ","))
	tempo.item_selected.connect(func(i: int) -> void:
		_tempo = float(TEMPOS[i])
		Engine.time_scale = _tempo)
	rij1.add_child(tempo)
	rij1.add_child(_vinkje("donker", false, func(aan: bool) -> void:
		_donker = aan
		_licht()))
	rij1.add_child(_vinkje("dichtbij", true, func(aan: bool) -> void:
		_dichtbij = aan
		_zet_camera()))
	# De wind van het potje (in het spel geloot): hier met de hand, in graden.
	rij1.add_child(_tekst("wind"))
	var wind := HSlider.new()
	wind.min_value = 0.0
	wind.max_value = 359.0
	wind.step = 1.0
	wind.custom_minimum_size = Vector2(200.0, 36.0)
	wind.value = rad_to_deg(atan2(PawnView.wind_richting.z, PawnView.wind_richting.x)) + (360.0 if PawnView.wind_richting.z < 0.0 else 0.0)
	wind.value_changed.connect(func(graden: float) -> void:
		PawnView.wind_richting = Vector3(cos(deg_to_rad(graden)), 0.0, sin(deg_to_rad(graden))))
	rij1.add_child(wind)
	var rij2 := HFlowContainer.new()
	ov.add_child(rij2)
	rij2.add_child(_tekst("schutter"))
	rij2.add_child(_factie_keuze(_fac_schutter, func(d: int) -> void:
		_fac_schutter = d
		_bouw_toneel()))
	rij2.add_child(_tekst("doel"))
	rij2.add_child(_factie_keuze(_fac_doel, func(d: int) -> void:
		_fac_doel = d
		_bouw_toneel()))
	var standaard := Button.new()
	standaard.text = "standaard"
	standaard.tooltip_text = "De knoppen van dit effect terug naar de standaard uit de code"
	standaard.pressed.connect(_standaard)
	rij2.add_child(standaard)
	var opslaan := Button.new()
	opslaan.text = "OPSLAAN"
	opslaan.pressed.connect(opslaan_knoppen)
	rij2.add_child(opslaan)
	var terug := Button.new()
	terug.text = "terug naar het spel"
	terug.pressed.connect(func() -> void:
		Engine.time_scale = 1.0
		get_tree().change_scene_to_file("res://scenes/game/game.tscn"))
	rij2.add_child(terug)
	_melding = Label.new()
	_melding.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_melding.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	ov.add_child(_melding)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ov.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 12)
	scroll.add_child(_grid)
	# De camera pas richten als de panelen hun maat hebben (en opnieuw als die
	# verandert: een lange uitleg maakt het bovenpaneel hoger).
	_zet_camera.call_deferred()
	_boven.resized.connect(_zet_camera)
	_onder.resized.connect(_zet_camera)


func _vinkje(tekst: String, aan: bool, cb: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.text = tekst
	c.button_pressed = aan
	c.toggled.connect(cb)
	return c


func _tekst(t: String) -> Label:
	var l := Label.new()
	l.text = t
	return l


func _factie_keuze(huidig: int, cb: Callable) -> OptionButton:
	var o := OptionButton.new()
	for d in [Constants.Doctrine.MENS, Constants.Doctrine.MUIS, Constants.Doctrine.LEEUW,
			Constants.Doctrine.BEER, Constants.Doctrine.WOLF, Constants.Doctrine.VOS]:
		o.add_item(Constants.doctrine_display_name(d), d)
	o.select(o.get_item_index(huidig))
	o.item_selected.connect(func(i: int) -> void: cb.call(o.get_item_id(i)))
	return o


func _kies_groep(groep: String) -> void:
	_groep = groep
	for g in _groep_knoppen:
		(_groep_knoppen[g] as Button).set_pressed_no_signal(String(g) == groep)
	for k in _effect_rij.get_children():
		_effect_rij.remove_child(k)
		k.queue_free()
	_effect_knoppen.clear()
	for e in Catalogus.van_groep(groep):
		var b := Button.new()
		var status := String(e.status)
		b.text = String(e.naam) + ("  (wens)" if status == "wens" else ("  (diorama)" if status == "diorama" else ""))
		if status != "spel":
			b.add_theme_color_override("font_color", Color(0.7, 0.7, 0.66))
		b.toggle_mode = true
		b.button_pressed = String(e.id) == _gekozen
		b.pressed.connect(kies.bind(String(e.id)))
		_effect_rij.add_child(b)
		_effect_knoppen[String(e.id)] = b


## Kies een effect (ook voor de checks): de uitleg, zijn knoppen, en de schutter
## die erbij hoort (een kanon bij een kanonschot).
func kies(id: String) -> void:
	_kies(id)
	_bouw_toneel()
	if _herhaal:
		speel()


func _kies(id: String) -> void:
	var e: Dictionary = Catalogus.effect(id)
	if e.is_empty():
		return
	_gekozen = id
	if String(e.groep) != _groep:
		_kies_groep(String(e.groep))
	for k in _effect_knoppen:
		(_effect_knoppen[k] as Button).set_pressed_no_signal(String(k) == id)
	var status := String(e.status)
	var regel := "%s: %s." % [String(e.naam), String(e.wanneer)]
	match status:
		"wens":
			regel += " Nog te bouwen."
		"diorama":
			regel += " Zit in het diorama, nog met vaste waarden."
	if String(e.get("notitie", "")) != "":
		regel += " Let op: %s." % String(e.notitie)
	_info.text = regel
	_speel_knop.disabled = String(e.get("speel", "")) == ""
	_melding.text = ""
	_vul_knoppen(e)


func _vul_knoppen(e: Dictionary) -> void:
	for k in _grid.get_children():
		_grid.remove_child(k)
		k.queue_free()
	_sliders.clear()
	_waarden.clear()
	var lijst: Array = e.get("knoppen", [])
	if lijst.is_empty():
		_grid.add_child(_tekst("(nog geen knoppen)"))
		return
	for sleutel in lijst:
		var m: Dictionary = Catalogus.knop(String(sleutel))
		var naam := Label.new()
		naam.text = String(m.label)
		naam.tooltip_text = String(sleutel)
		naam.custom_minimum_size = Vector2(300.0, 0.0)
		_grid.add_child(naam)
		var s := HSlider.new()
		s.min_value = float(m.min)
		s.max_value = float(m.max)
		s.step = float(m.step)
		s.value = PawnView.fx(String(sleutel), float(m.def))
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.custom_minimum_size = Vector2(0.0, 36.0)
		s.value_changed.connect(_op_schuif.bind(String(sleutel)))
		_grid.add_child(s)
		var w := Label.new()
		w.custom_minimum_size = Vector2(90.0, 0.0)
		w.text = _getal(s.value)
		_grid.add_child(w)
		_sliders[String(sleutel)] = s
		_waarden[String(sleutel)] = w


func _getal(v: float) -> String:
	return String.num(v, 3).replace(".", ",")


func _op_schuif(waarde: float, sleutel: String) -> void:
	PawnView.set_fx(sleutel, snappedf(waarde, 0.001))
	STIJL.pas_toe(_stijl)
	if _waarden.has(sleutel):
		(_waarden[sleutel] as Label).text = _getal(waarde)


## Zet een knop (ook voor de checks): live, en de schuif volgt.
func zet_knop(sleutel: String, waarde: float) -> void:
	PawnView.set_fx(sleutel, waarde)
	STIJL.pas_toe(_stijl)
	if _sliders.has(sleutel):
		(_sliders[sleutel] as HSlider).set_value_no_signal(waarde)
		(_waarden[sleutel] as Label).text = _getal(waarde)


func _standaard() -> void:
	var e: Dictionary = Catalogus.effect(_gekozen)
	for sleutel in e.get("knoppen", []):
		zet_knop(String(sleutel), float(Catalogus.knop(String(sleutel)).def))
	_melding.text = "Standaard gezet (nog niet opgeslagen)."


## Schrijft alle knoppen naar effects_tuning.json (zoals de Model-tuner: het
## hele bestand, gesorteerd, dus ook wat andere tuners zetten blijft staan).
func opslaan_knoppen() -> void:
	var f := FileAccess.open(PawnView.EFFECTS_PATH, FileAccess.WRITE)
	if f == null:
		_melding.text = "Opslaan lukte niet: %s" % error_string(FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(PawnView.fx_all(), "\t") + "\n")
	f.close()
	_melding.text = "Opgeslagen in assets/models/effects_tuning.json."


func toneel() -> Node3D:
	return _toneel


## Het stuk beeld tussen de panelen (in de eenheden van de zichtbare rect): de
## opnames van de VFX-studio (`-- vfxstudio`) knippen alleen het bord eruit.
func beeld_rect() -> Rect2i:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var boven: float = _boven.size.y if _boven != null else 0.0
	var onder: float = _onder.size.y if _onder != null else 0.0
	return Rect2i(0, int(boven), int(vp.x), maxi(int(vp.y - boven - onder), 1))


## Een donker, compact thema voor de panelen (een werkbank, geen spelscherm).
func _thema() -> Theme:
	var th := Theme.new()
	th.default_font_size = LETTER
	var paneel := StyleBoxFlat.new()
	paneel.bg_color = Color(0.09, 0.1, 0.13, 0.9)
	paneel.set_content_margin_all(12.0)
	th.set_stylebox("panel", "PanelContainer", paneel)
	var knop := StyleBoxFlat.new()
	knop.bg_color = Color(0.18, 0.2, 0.26)
	knop.border_color = Color(0.34, 0.39, 0.52)
	knop.set_border_width_all(1)
	knop.set_corner_radius_all(3)
	knop.set_content_margin_all(8.0)
	var hover: StyleBoxFlat = knop.duplicate()
	hover.bg_color = Color(0.24, 0.27, 0.35)
	var druk: StyleBoxFlat = knop.duplicate()
	druk.bg_color = Color(0.36, 0.3, 0.16)
	druk.border_color = Color(0.85, 0.7, 0.35)
	for soort in ["Button", "OptionButton", "CheckButton"]:
		th.set_stylebox("normal", soort, knop)
		th.set_stylebox("hover", soort, hover)
		th.set_stylebox("pressed", soort, druk)
		th.set_stylebox("hover_pressed", soort, druk)
		th.set_stylebox("focus", soort, StyleBoxEmpty.new())
	return th

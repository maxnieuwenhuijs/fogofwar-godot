class_name Omgeving
extends Node3D

## Het diorama om het bord heen (8 september, Max: "de rest van het scherm
## ook een grasachtig landschap", "net als bij Hearthstone kleine props om
## op te klikken als je moet wachten, en het mag wel een beetje
## cinematografisch"). Alles hier wordt procedureel gebouwd, als kind van de
## kijk-pivot in game.gd: zo draait het met de camera mee en ziet speler 2
## hetzelfde kamp vooraan als speler 1.
##
## Lagen:
##   - grond: een groot vlak op de onderkant van het bord, naadloze grastegel
##     (assets/models/board/omgeving/gras.png, uit tools/maak_omgeving_texturen.py)
##     met een grove multiply-laag tegen het herhaal-effect;
##   - wolkenschaduw: een doorzichtig vlak net boven het gras dat met de
##     wind (PawnView.wind_richting) meedrijft; onder het bord onzichtbaar;
##   - vignet: donkere randen over het hele beeld, achter de UI;
##   - props: het kamp vooraan (kampvuur, trommel, ton, hoorn, bijl in een
##     stronk, kanonskogels, twee tenten) en de overkant (hek met een kraai,
##     plas met een kikker, wegwijzer, tent van de tegenstander). Trommel,
##     ton, bijl en hoorn zijn de gedeelde glb-props; de rest is primitieven
##     in het palet van het bord, per stuk te vervangen door een echt model.
##
## Klikken: game.gd vraagt `klik(schermpositie)` VOOR de beurt-check, zodat
## het ook werkt terwijl je op de tegenstander wacht. Een prop reageert met
## een korte tween (en een geluid als er een bestaande categorie past); een
## prop die nog bezig is slikt de klik en doet niets.
##
## Knoppen (sfeer-paneel, toets L): omgeving (aan/uit), omgeving_licht,
## wolken, vignet, props. Zie `pas_toe`.

func _init() -> void:
	_spel = Spelletjes.new(self)


const OMGEVING_DIR := "res://assets/models/board/omgeving/"
const PROPS_DIR := "res://assets/models/props/"
const GROND_Y := -0.23          # onderkant van het bord in bordruimte (top 0,05 - dikte 0,28)
const CENTRUM := Vector3(5.0, 0.0, 5.0)
const VLAK := 160.0             # het grondvlak in eenheden (orthocamera ziet ~14 x 26)
const KLIK_STRAAL := 46.0       # schermpixels, vingerdik

var _camera: Camera3D
var _grond: MeshInstance3D
var _grond_mat: StandardMaterial3D
var _wolken: MeshInstance3D
var _wolken_mat: StandardMaterial3D
var _wolk_offset := Vector2.ZERO
var _vignet: ColorRect
var _props_root: Node3D
var _props: Array = []          # {node, hoogte, straal, reageer, bezig, ...}
var _vuur_licht: OmniLight3D
var _vuur_basis := 1.3
var _lantaarns: Array = []      # OmniLight3D's die zachtjes flakkeren
var _kikker_keel: Node3D
var _kraai_kop: Node3D
var _kraai_kop_timer := 0.0
var _kraai_koppen: Array = []    # alle kraaienkoppen die af en toe omkijken
var _wieken: Array = []          # molenwieken die draaien
var _wiek_boost: Dictionary = {} # wiek -> extra snelheid (na een klik)
var _grond_tint := Color(1, 1, 1, 1)
var _diorama := 1
var _gebouwd := -1               # welk diorama er nu onder Props staat
var _tijd := 0.0
var _mat_cache: Dictionary = {}
# Eigen RNG (11 september): de omgeving trekt NOOIT uit de globale RNG. Die
# staat tussen seed(777) en de auto-opstelling van -- uispel; elk extra trekje
# (een boom die willekeurig draait) verschoof de hele partij.
var _rng := RandomNumberGenerator.new()
# de mini-games (12 september): kegelen, keilen, kanon, vissen, cadans
var _spel: Spelletjes
var _rivier_node: Node3D = null   # ouder voor kringen op de rivier (op GROND_Y)
# bewoners: de kleine poppetjes uit assets/models/bewoners/ (Bewoner)
const BEWONER_SLOTS_EIGEN: Array = [Vector3(0.7, GROND_Y, 14.6), Vector3(4.1, GROND_Y, 13.6),
		Vector3(2.5, GROND_Y, 15.4), Vector3(-1.3, GROND_Y, 12.5)]
const BEWONER_SLOTS_ANDER: Array = [Vector3(9.5, GROND_Y, -3.4), Vector3(6.3, GROND_Y, -2.1),
		Vector3(3.4, GROND_Y, -3.2)]
var _bewoners_root: Node3D
var _bewoners: Array = []
var _factie_eigen := -1
var _factie_ander := -1
# teams: het kamp vooraan draagt de kleur van jouw stoel (1 = rood, 2 = blauw);
# rood is het arme kamp, blauw het rijke (PROP-WISHLIST.md)
var _team_eigen := "red"
var _team_ander := "blue"
# ware hoogte (bordeenheden) waarop een geleverde prop-glb wordt geschaald,
# tenzij prop_<naam>.json zelf "hoogte" geeft
const PROP_HOOGTE: Dictionary = {
	"tent": 1.0, "fakkel": 0.8, "wagen": 1.0, "kookpot": 0.6, "hakblok": 0.3, "houtblok": 0.15,
	"kogels": 0.3, "hek": 0.4, "wegwijzer": 0.95, "plas": 0.04, "musketrek": 0.75, "kruitvat": 0.4,
	"waslijn": 0.85, "kanon": 0.6, "vogelverschrikker": 0.95, "boom": 1.7, "struik": 0.4,
	"muurtje": 0.35, "rots": 0.35, "bloemen": 0.12, "hooiberg": 0.7, "geit": 0.4, "kip": 0.18,
	"kaarttafel": 0.5, "kruk": 0.3, "bierton": 0.5, "wijnvat": 0.5, "troon": 0.7, "tapijt": 0.03,
	"kapotte_kar": 0.7, "waterput": 0.75, "aambeeld": 0.35, "werkbank": 0.5, "emmer": 0.25,
	"zaag": 0.2, "spit": 0.55, "takkenbos": 0.3, "ketel": 0.25, "veldbed": 0.35, "kandelaar": 0.4,
	"toilethuisje": 1.3, "molen": 2.0, "put": 1.2, "kruis": 0.85, "palm": 1.9, "sfinx": 0.5, "steiger_boot": 0.4,
	"ruine": 1.1, "fontein": 0.8, "marktkraam": 1.2, "sneeuwpop": 0.95, "lantaarnpaal": 1.5,
	"bel": 1.1, "glaswerk": 0.45,
}
# props uit de wishlist die geen placeholder hebben: ze verschijnen zodra
# prop_<naam>[_team].glb in assets/models/props/ ligt. Posities in het
# bordframe (vooraan z 12-17, overkant z -1,5..-4,6; x al gecorrigeerd voor de
# camera-yaw zoals de rest van het kamp). Een prop die maar voor een team
# bestaat lever je met het teamwoord (prop_hooiberg_red.glb): dan blijft het
# andere kamp leeg.
# placeholders die wijken voor een geleverde glb met dezelfde naam
const GLB_VERVANGBAAR: Array = ["toilethuisje", "molen", "kanon", "put", "kruis", "palm", "piramide",
	"sfinx", "steiger_boot", "ruine", "fontein", "marktkraam", "sneeuwpop", "hooiberg", "lantaarnpaal", "boom", "rots",
	"bel", "glaswerk", "aambeeld", "kookpot"]
# Tik-dingen (Max, 11 september: "minimaal 3 dingen die lekker dingen of pingen
# of dongen die je zo vaak als je klikt kunt klikken"): elke klik op ELKE prop
# geeft meteen een geluid en een schudding, ook als er nog een grote reactie
# loopt; deze namen tellen als dinger, en elk diorama heeft er minstens drie
# (omgevingcheck bewaakt dat).
const TIK_NAMEN: Array = ["trommel", "ton", "hoorn", "hakblok", "kogels", "toilethuisje", "kanon", "put",
	"lantaarnpaal", "fontein", "bel", "glaswerk", "aambeeld", "kookpot", "sneeuwpop", "marktkraam"]
# tik-geluid per prop (op de naam van de prop-node, zonder volgnummer): eerst
# de eigen categorie (prop_<naam>.wav in sounds/), dan een terugval die er ligt
const TIK_GELUID: Dictionary = {
	"prop_drum": ["prop_trom", "val_drum"], "prop_barrel": ["prop_ton", "impact_wood"],
	"prop_horn": ["prop_hoorn", "val_horn"], "Stronk": ["prop_bijl", "impact_wood"],
	"Kogels": ["prop_kogel", "impact_armor"], "Kampvuur": ["prop_vuur", "prop_tik"],
	"Tent": ["prop_doek", "prop_tik"], "Kraai": ["prop_kraai", "prop_tik"], "Vogel": ["prop_kraai", "prop_tik"],
	"Kikker": ["prop_kikker", "prop_tik"], "Wegwijzer": ["prop_wegwijzer", "impact_wood"],
	"Toilethuisje": ["prop_klop", "impact_wood"], "Molen": ["prop_molen", "cannon_wheel_loose"],
	"Kanon": ["prop_kanon_tik", "impact_armor"], "Put": ["prop_emmer", "impact_wood"], "Kruis": ["impact_wood"],
	"Palm": ["prop_ritsel", "prop_tik"], "Piramide": ["prop_zand", "prop_tik"], "Sfinx": ["prop_zand", "prop_tik"],
	"Steiger": ["prop_boot", "impact_wood"], "Ruine": ["prop_steen", "impact_wood"],
	"Fontein": ["prop_plons", "small_blood_splash"], "Marktkraam": ["impact_wood"],
	"Sneeuwpop": ["prop_sneeuw", "prop_tik"], "Hooiberg": ["prop_hooi", "prop_tik"],
	"Lantaarnpaal": ["prop_lantaarn", "impact_armor"], "Boom": ["prop_ritsel", "prop_tik"],
	"Bel": ["prop_bel", "haven_score"], "Glaswerk": ["prop_glas", "card_stat_up"],
	"Aambeeld": ["prop_aambeeld", "impact_armor"], "Kookpot": ["prop_kookpot", "impact_armor"],
	"Hek": ["prop_hek", "impact_wood"], "Plas": ["prop_plons", "small_blood_splash"], "Rots": ["prop_steen", "impact_wood"],
	"Kegelbal": ["prop_kogel", "impact_armor"], "Stenen": ["prop_steen", "impact_wood"],
	"Kruitvaten": ["prop_ton", "impact_wood"], "Hengel": ["prop_hengel", "prop_tik"],
}
const EXTRA_PROPS: Array = [
	{"naam": "fakkel", "eigen": [0.6, 16.2], "ander": [8.0, -4.3], "geluid": ["prop_vuur"]},
	{"naam": "houtblok", "eigen": [-0.4, 13.4], "geluid": ["prop_hout", "impact_wood"]},
	{"naam": "wagen", "eigen": [7.4, 15.9], "ander": [1.2, -4.2], "draai": -30.0, "draai_ander": 150.0, "geluid": ["prop_wagen", "impact_wood"]},
	{"naam": "kookpot", "eigen": [2.2, 13.4], "geluid": ["prop_kookpot", "impact_armor"]},
	{"naam": "musketrek", "eigen": [5.3, 12.6], "ander": [5.0, -2.5], "geluid": ["prop_musketrek", "impact_wood"]},
	{"naam": "kruitvat", "eigen": [4.9, 14.9], "geluid": ["prop_kruit"]},
	{"naam": "waslijn", "eigen": [-2.8, 13.0], "draai": 20.0, "geluid": []},
	{"naam": "kanon", "ander": [9.2, -3.9], "draai_ander": 170.0, "geluid": ["cannon_move"]},
	{"naam": "vogelverschrikker", "ander": [0.2, -3.0], "geluid": ["prop_kraai"]},
	{"naam": "boom", "eigen": [-3.4, 16.6], "ander": [11.0, -4.6], "geluid": []},
	{"naam": "struik", "eigen": [-3.0, 11.9], "ander": [3.9, -4.4], "geluid": []},
	{"naam": "muurtje", "ander": [11.4, -1.4], "draai_ander": 90.0, "geluid": ["impact_wood"]},
	{"naam": "rots", "eigen": [7.9, 12.1], "ander": [-0.8, -1.6], "geluid": []},
	{"naam": "bloemen", "eigen": [1.5, 11.9], "ander": [7.0, -1.5], "geluid": []},
	{"naam": "hooiberg", "eigen": [6.9, 17.0], "geluid": []},
	{"naam": "geit", "eigen": [-1.6, 12.2], "geluid": ["prop_geit"]},
	{"naam": "kip", "eigen": [3.6, 15.6], "geluid": ["prop_kip"]},
	{"naam": "kaarttafel", "eigen": [5.7, 14.6], "ander": [4.4, -3.6], "draai": 15.0, "draai_ander": 180.0, "geluid": ["impact_wood"]},
	{"naam": "kruk", "eigen": [6.3, 14.2], "ander": [5.1, -3.3], "geluid": ["impact_wood"]},
	{"naam": "bierton", "eigen": [4.9, 11.9], "geluid": ["prop_kruik", "impact_wood"]},
	{"naam": "wijnvat", "eigen": [4.9, 11.9], "geluid": ["prop_kruik", "impact_wood"]},
	{"naam": "troon", "eigen": [-0.4, 15.0], "ander": [3.0, -3.0], "draai": 30.0, "draai_ander": 200.0, "geluid": ["impact_wood"]},
	{"naam": "tapijt", "eigen": [-0.4, 15.0], "ander": [3.0, -3.0], "geluid": []},
	{"naam": "kapotte_kar", "eigen": [8.1, 16.2], "draai": -40.0, "geluid": ["prop_wagen", "impact_wood"]},
	{"naam": "waterput", "ander": [10.4, -4.3], "geluid": ["prop_emmer"]},
	{"naam": "aambeeld", "eigen": [1.2, 12.3], "geluid": ["prop_aambeeld", "impact_armor"]},
	{"naam": "werkbank", "eigen": [-2.6, 14.4], "draai": 90.0, "geluid": ["impact_wood"]},
	{"naam": "emmer", "eigen": [1.6, 12.6], "geluid": ["prop_emmer"]},
	{"naam": "zaag", "eigen": [-1.0, 14.3], "geluid": ["prop_zaag"]},
]


func bouw(camera: Camera3D, ui_laag: CanvasLayer) -> void:
	_rng.randomize()
	_camera = camera
	name = "Omgeving"
	_bouw_grond()
	_bouw_wolken()
	_props_root = Node3D.new()
	_props_root.name = "Props"
	add_child(_props_root)
	_bouw_props()
	if ui_laag != null:
		_bouw_vignet(ui_laag)
	pas_toe()


## Welke facties er spelen (game.gd roept dit bij de start van een potje en
## als de keuzes online binnenkomen): de bewoners van jouw factie komen in
## het kamp vooraan, die van de ander aan de overkant, factieloze altijd.
func zet_facties(eigen: int, ander: int, eigen_team: String = "") -> void:
	var team := eigen_team if eigen_team != "" else _team_eigen
	var ander_team := "blue" if team == "red" else "red"
	if eigen == _factie_eigen and ander == _factie_ander and team == _team_eigen and _bewoners_root != null and _gebouwd == _diorama:
		return
	_factie_eigen = eigen
	_factie_ander = ander
	_team_eigen = team
	_team_ander = ander_team
	_bouw_props()


func bewoners() -> Array:
	return _bewoners.duplicate()


## Alle sfeer-knoppen die dit diorama raken, in een keer (game._apply_ambiance).
func pas_toe() -> void:
	var aan: bool = PawnView.fx("omgeving", 1.0) > 0.5
	visible = aan
	var licht: float = PawnView.fx("omgeving_licht", 1.0)
	if _grond_mat != null:
		_grond_mat.albedo_color = Color(1.15 * licht * _grond_tint.r, 1.15 * licht * _grond_tint.g, 1.15 * licht * _grond_tint.b, 1.0)
	# een vast diorama uit het sfeer-paneel (0 = geloot per potje)
	var vast := int(PawnView.fx("diorama", 0.0))
	if vast > 0 and vast != _diorama and _props_root != null:
		zet_diorama(vast)
	if _wolken_mat != null:
		_wolken_mat.albedo_color.a = 0.6 * clampf(PawnView.fx("wolken", 1.0), 0.0, 3.0)
		_wolken.visible = _wolken_mat.albedo_color.a > 0.001
	if _props_root != null:
		_props_root.visible = PawnView.fx("props", 1.0) > 0.5
	if _vignet != null:
		_vignet.visible = aan
		(_vignet.material as ShaderMaterial).set_shader_parameter("sterkte", PawnView.fx("vignet", 0.5))


func _process(delta: float) -> void:
	_tijd += delta
	# wolkenschaduw drijft met de wereldwind mee (lokaal, want de pivot kan gedraaid staan)
	if _wolken_mat != null and _wolken.visible:
		var w: Vector3 = global_transform.basis.inverse() * PawnView.wind_richting
		_wolk_offset += Vector2(w.x, w.z) * 0.0045 * delta
		_wolken_mat.uv1_offset = Vector3(_wolk_offset.x, _wolk_offset.y, 0.0)
	# kampvuur flakkert
	if _vuur_licht != null:
		_vuur_licht.light_energy = _vuur_basis * (0.86 + 0.10 * sin(_tijd * 9.3) + 0.07 * sin(_tijd * 23.7) + 0.05 * sin(_tijd * 3.1))
	for l in _lantaarns:
		if is_instance_valid(l):
			(l as OmniLight3D).light_energy = 0.7 * (0.9 + 0.08 * sin(_tijd * 7.1 + l.position.x) + 0.04 * sin(_tijd * 17.0))
	# kikkerkeel
	if _kikker_keel != null:
		var s := 1.0 + 0.25 * maxf(0.0, sin(_tijd * 2.4))
		_kikker_keel.scale = Vector3(s, s, s)
	# de kraaien kijken af en toe om
	_kraai_kop_timer -= delta
	if _kraai_kop_timer <= 0.0:
		_kraai_kop_timer = _rng.randf_range(2.5, 6.0)
		for kop in _kraai_koppen:
			if is_instance_valid(kop) and _rng.randf() < 0.7:
				var tw := (kop as Node3D).create_tween()
				tw.tween_property(kop, "rotation:y", _rng.randf_range(-0.9, 0.9), 0.18).set_trans(Tween.TRANS_QUAD)
	# molenwieken draaien met de wind mee (en harder na een klik)
	for w in _wieken:
		if is_instance_valid(w):
			(w as Node3D).rotation.z += delta * (0.55 + float(_wiek_boost.get(w, 0.0)))
	_spel.process(delta)


## Klik op een prop? Kiest de dichtstbijzijnde binnen KLIK_STRAAL schermpixels
## (zelfde principe als game._pick_coord voor de tegels). Waar = geconsumeerd.
func klik(screen_pos: Vector2) -> bool:
	if _camera == null or not visible or _props_root == null or not _props_root.visible:
		return false
	var beste: Dictionary = {}
	var beste_d := 1e9
	for p in _props:
		var n: Node3D = p.node
		if not is_instance_valid(n) or not n.visible:
			continue
		var wp: Vector3 = n.to_global(p.get("midden", Vector3(0.0, float(p.hoogte) * 0.5, 0.0)))
		if _camera.is_position_behind(wp):
			continue
		var d := _camera.unproject_position(wp).distance_to(screen_pos)
		var straal: float = maxf(float(p.straal), float(p.get("omvang", 0.0)) * _px_per_eenheid() * 0.7)
		if d < straal and d < beste_d:
			beste = p
			beste_d = d
	if beste.is_empty():
		return false
	_tik(beste)
	if beste.has("spel"):
		# een spel-prop (12 september): de tik is gespeeld, de rest beslist
		# Spelletjes bij het loslaten (kort = de gewone reactie) of na de
		# hold-drempel (het spel zelf)
		_spel.druk(beste, screen_pos)
		return true
	if beste.bezig:
		return true
	beste.bezig = true
	_speel_willekeurig(beste)
	return true


## Vinger los (game.gd, elke linker-loslaat). Waar = een spel-prop deed er iets mee.
func laat_los(screen_pos: Vector2) -> bool:
	return _spel.laat_los(screen_pos)


## Vinger beweegt (game.gd): ver wegschuiven breekt een lopend richten af.
func beweeg(screen_pos: Vector2) -> void:
	_spel.beweeg(screen_pos)


# ---------------------------------------------------------------- lagen

func _bouw_grond() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(VLAK, VLAK)
	pm.add_uv2 = true
	_grond = MeshInstance3D.new()
	_grond.name = "Grond"
	_grond.mesh = pm
	_grond.position = CENTRUM + Vector3(0.0, GROND_Y, 0.0)
	_grond.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grond_mat = StandardMaterial3D.new()
	_grond_mat.roughness = 1.0
	_grond_mat.metallic_specular = 0.0
	var gras := _laad_textuur("gras.png")
	if gras != null:
		_grond_mat.albedo_texture = gras
		_grond_mat.uv1_scale = Vector3(VLAK / 12.0, VLAK / 12.0, 1.0)   # tegel van 12 eenheden
	else:
		_grond_mat.albedo_color = Color(0.40, 0.42, 0.22)
	var vlek := _laad_textuur("gras_vlekken.png")
	if vlek != null:
		_grond_mat.detail_enabled = true
		_grond_mat.detail_albedo = vlek
		_grond_mat.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
		_grond_mat.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
		_grond_mat.uv2_scale = Vector3(VLAK / 45.0, VLAK / 45.0, 1.0)
	_grond.material_override = _grond_mat
	add_child(_grond)


func _bouw_wolken() -> void:
	var tex := _laad_textuur("wolken.png")
	if tex == null:
		return
	var pm := PlaneMesh.new()
	pm.size = Vector2(VLAK, VLAK)
	_wolken = MeshInstance3D.new()
	_wolken.name = "Wolkenschaduw"
	_wolken.mesh = pm
	# net boven het gras, onder de bovenkant van het bord: het bord verbergt hem
	_wolken.position = CENTRUM + Vector3(0.0, GROND_Y + 0.03, 0.0)
	_wolken.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wolken_mat = StandardMaterial3D.new()
	_wolken_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_wolken_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_wolken_mat.albedo_texture = tex
	_wolken_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.6)
	_wolken_mat.uv1_scale = Vector3(2.0, 2.0, 1.0)
	_wolken.material_override = _wolken_mat
	add_child(_wolken)


func _bouw_vignet(ui_laag: CanvasLayer) -> void:
	_vignet = ColorRect.new()
	_vignet.name = "Vignet"
	_vignet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float sterkte : hint_range(0.0, 1.0) = 0.5;
uniform float straal = 0.58;
uniform float zacht = 0.62;
void fragment() {
	vec2 d = (UV - vec2(0.5)) * vec2(1.0, 1.25);
	float r = length(d);
	float v = smoothstep(straal, straal + zacht, r);
	COLOR = vec4(0.02, 0.016, 0.012, v * sterkte);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("sterkte", 0.5)
	_vignet.material = mat
	ui_laag.add_child(_vignet)
	ui_laag.move_child(_vignet, 0)   # achter alle UI


# ---------------------------------------------------------------- de twaalf diorama's
# Elk diorama: grond (gras, sneeuw, zand, modder, kei, bos, rots), een tint,
# extra's (sneeuw, water) en de props vooraan (kamp) en aan de overkant, als
# [naam, x, z, draai, {opties}] in het bordframe. De x is al gecorrigeerd
# voor de camera-yaw (vooraan schuift op het scherm naar rechts, de overkant
# naar links). Iconen uit de tijd van Napoleon: het kamp, de boerderij, de
# molen, het slagveld, de winter van 1812, de haven, het bos, de kapel, het
# marktplein, Egypte 1798, de Alpenpas van 1800 en de hoeve van Waterloo.
const DIORAMAS: Array = [
	{"naam": "Weidekamp", "grond": "gras", "sfeer": "het gewone kamp op de wei",
	 "kamp": [["kampvuur", 2.2, 13.4], ["trommel", 0.4, 12.7, 34, {"cadans": true}], ["ton", 4.3, 12.9, -23], ["hoorn", 4.95, 12.25, 69],
			  ["hakblok", -0.9, 13.9], ["kogels", 3.5, 14.4], ["tent", -1.9, 15.6, 20, {"lantaarn": true}],
			  ["tent", 5.9, 15.8, -25], ["toilethuisje", 8.3, 13.6, -35], ["glaswerk", 6.6, 12.6, 0],
			  ["kegelspel", 1.2, 17.0, 0]],
	 "overkant": [["hek_kraai", 2.2, -2.0], ["plas_kikker", 11.2, -2.4, 0, {"stenen": true}], ["wegwijzer", 7.6, -2.9], ["tent", 5.4, -3.9, 160]]},
	{"naam": "Boerenerf", "grond": "gras", "sfeer": "een boerderij achter de linies: hooi, kippen, de put",
	 "kamp": [["hooiberg", 6.6, 15.2], ["put", 2.6, 13.2, 15], ["toilethuisje", -1.2, 14.8, 30], ["hakblok", 0.8, 12.4],
			  ["kampvuur", 3.8, 13.9], ["kookpot", 3.8, 13.9], ["tent", -2.6, 16.4, 15, {"lantaarn": true}],
			  ["boom", 8.6, 16.6, 0, {"schaal": 1.2}], ["ton", 5.2, 12.4, 10], ["glaswerk", 4.6, 14.9, 20],
			  ["kegelspel", 1.4, 17.2, 0]],
	 "overkant": [["hek_kraai", 1.4, -2.0], ["plas_kikker", 10.6, -2.6, 0, {"stenen": true, "hengel": true}], ["boom", 6.0, -4.2, 0, {"schaal": 1.4}],
				  ["kruis", 3.6, -3.4, 10], ["wegwijzer", 8.4, -3.0]]},
	{"naam": "Dorpsrand met molen", "grond": "gras", "sfeer": "de rand van een dorp: de molen draait, de markt staat",
	 "kamp": [["molen", 7.2, 15.6, -20], ["marktkraam", 2.0, 13.6, 10], ["lantaarnpaal", 4.8, 12.6], ["put", -1.4, 13.4, 0],
			  ["kampvuur", 0.6, 15.0], ["tent", -2.8, 16.6, 20], ["toilethuisje", 9.4, 12.8, -60],
			  ["bel", 6.0, 13.2, 0], ["glaswerk", 2.9, 12.6, -20], ["kegelspel", 3.4, 17.4, 0]],
	 "overkant": [["wegwijzer", 2.4, -2.2], ["hek_kraai", 6.4, -2.0], ["boom", 10.4, -4.0, 0, {"schaal": 1.5}],
				  ["lantaarnpaal", 4.2, -3.6], ["plas_kikker", 0.2, -3.8, 0, {"stenen": true}]]},
	{"naam": "Na de slag", "grond": "modder", "tint": [0.92, 0.9, 0.88], "sfeer": "het veld de ochtend erna: kanonnen, kruisen, kraaien",
	 "kamp": [["kanon", 2.4, 13.2, -15], ["kampvuur", 5.6, 14.2, 0, {"smeulend": true}], ["kogels", 3.8, 12.4],
			  ["kruis", -1.0, 14.6, 10], ["kruis", 7.8, 15.4, -8], ["tent", -2.4, 16.4, 25], ["ton", 0.4, 12.6, 20],
			  ["trommel", 7.0, 13.6, 60, {"cadans": true}], ["kruitvaten", 8.2, 12.3, 0]],
	 "overkant": [["hek_kraai", 1.8, -2.0], ["kruis", 5.4, -3.2, 0], ["kruis", 8.8, -2.4, 12], ["plas_kikker", 11.0, -2.6],
				  ["boom", 3.4, -4.4, 0, {"schaal": 1.3, "kaal": true}], ["kanon", 9.6, -4.2, 175]]},
	{"naam": "Winterkamp", "grond": "sneeuw", "tint": [0.96, 0.98, 1.05], "extra": ["sneeuw"], "sfeer": "de winter van 1812: sneeuw, een klein vuur, een sneeuwpop",
	 "kamp": [["kampvuur", 2.2, 13.4], ["sneeuwpop", -1.4, 14.4, 15], ["tent", -2.4, 16.0, 20, {"lantaarn": true}],
			  ["tent", 5.9, 15.8, -25], ["hakblok", 0.2, 12.6], ["boom", 8.4, 16.2, 0, {"schaal": 1.5, "kaal": true}], ["kogels", 4.2, 13.0],
			  ["kookpot", 2.2, 13.4], ["bel", -2.9, 12.9, 0]],
	 "overkant": [["plas_kikker", 10.8, -2.6, 0, {"bevroren": true, "stenen": true}], ["hek_kraai", 2.0, -2.0], ["wegwijzer", 6.8, -3.0],
				  ["boom", 4.0, -4.6, 0, {"schaal": 1.6, "kaal": true}], ["sneeuwpop", 8.6, -3.8, 160]]},
	{"naam": "Rivierhaven", "grond": "gras", "extra": ["water"], "sfeer": "een kade aan de rivier: tonnen, een sloep, meeuwen",
	 "kamp": [["ton", 0.6, 12.6, 0], ["ton", 1.2, 13.2, 40], ["kampvuur", 3.6, 13.8], ["lantaarnpaal", 6.4, 12.4],
			  ["tent", -2.2, 15.8, 20], ["marktkraam", 7.6, 15.2, -30], ["toilethuisje", -0.6, 15.4, 40],
			  ["bel", 7.0, 12.9, 0], ["glaswerk", 1.9, 12.3, 30]],
	 "overkant": [["steiger_boot", 4.2, -2.2, 0], ["hek_kraai", 9.8, -1.9, 0, {"vogel": "wit"}], ["put", 0.2, -3.2, 0],
				  ["lantaarnpaal", 8.0, -3.4], ["stenen", 2.0, -1.45, 0], ["hengel", 6.6, -1.5, 0]]},
	{"naam": "Bosrand", "grond": "bos", "tint": [0.9, 0.95, 0.9], "sfeer": "een open plek aan de bosrand, houthakkers en een uil",
	 "kamp": [["boom", -2.6, 15.8, 0, {"schaal": 1.6}], ["boom", 8.2, 16.4, 0, {"schaal": 1.8}], ["boom", 6.6, 13.2, 0, {"schaal": 1.3}],
			  ["hakblok", 1.0, 13.4], ["kampvuur", 3.2, 14.2], ["kookpot", 3.2, 14.2], ["tent", -0.4, 15.9, 15, {"lantaarn": true}],
			  ["rots", 5.2, 12.2, 0, {"maat": 0.35}], ["ton", 4.6, 12.7, 0], ["trommel", 0.2, 12.3, 30, {"cadans": true}]],
	 "overkant": [["boom", 1.4, -3.2, 0, {"schaal": 1.7}], ["boom", 5.2, -4.4, 0, {"schaal": 1.5}], ["boom", 9.6, -3.0, 0, {"schaal": 1.6}],
				  ["hek_kraai", 3.6, -2.0], ["plas_kikker", 11.2, -2.2, 0, {"stenen": true}], ["kruis", 7.6, -2.6, 0]]},
	{"naam": "Kapelruine", "grond": "gras", "tint": [0.95, 0.95, 1.0], "sfeer": "een vervallen kapel: muren, een boog, een uil in het donker",
	 "kamp": [["ruine", 6.4, 15.0, -30], ["kruis", 3.6, 13.2, 0], ["lantaarnpaal", 1.0, 12.6], ["kampvuur", -0.6, 14.4],
			  ["tent", -2.6, 16.4, 20], ["boom", 9.2, 13.0, 0, {"schaal": 1.4}], ["bel", 5.2, 13.4, 0],
			  ["glaswerk", 0.2, 13.0, 15], ["ton", 2.0, 12.4, 0]],
	 "overkant": [["ruine", 2.6, -3.6, 160], ["hek_kraai", 6.8, -2.0], ["plas_kikker", 10.6, -2.6, 0, {"stenen": true}], ["wegwijzer", 9.0, -3.8],
				  ["kruis", 0.4, -2.6, 0]]},
	{"naam": "Marktplein", "grond": "kei", "sfeer": "het plein van een stadje: kramen, een fontein, lantaarns",
	 "kamp": [["marktkraam", 0.4, 13.4, 15], ["marktkraam", 4.6, 13.0, -10], ["fontein", 2.6, 15.2], ["lantaarnpaal", 7.0, 12.6],
			  ["put", -2.4, 15.2, 0], ["ton", 6.2, 14.6, 0], ["toilethuisje", 9.0, 15.6, -40],
			  ["glaswerk", 3.2, 12.4, -10], ["bel", 8.4, 13.6, 0], ["kegelspel", 4.4, 17.8, 0]],
	 "overkant": [["marktkraam", 2.4, -3.2, 170], ["lantaarnpaal", 6.0, -2.4], ["put", 8.8, -3.6, 0], ["hek_kraai", 10.6, -2.0],
				  ["wegwijzer", 0.2, -3.6]]},
	{"naam": "Egypte 1798", "grond": "zand", "tint": [1.05, 1.0, 0.92], "sfeer": "de veldtocht naar Egypte: piramiden, een sfinx, palmen",
	 "kamp": [["piramide", 8.4, 16.2, 0, {"maat": 1.4}], ["palm", -1.8, 15.4, 0], ["palm", 0.2, 13.2, 40], ["kampvuur", 3.2, 13.8],
			  ["tent", 5.6, 15.6, -25], ["sfinx", -2.8, 12.8, 30], ["ton", 1.8, 12.4, 0],
			  ["kookpot", 3.2, 13.8], ["trommel", 5.0, 12.4, 40, {"cadans": true}], ["glaswerk", -0.6, 12.2, 0]],
	 "overkant": [["piramide", 3.0, -4.4, 0, {"maat": 2.2}], ["piramide", 7.8, -4.6, 0, {"maat": 1.5}], ["sfinx", 10.4, -2.6, 180],
				  ["palm", 0.4, -2.4, 0], ["palm", 5.6, -2.2, 20]]},
	{"naam": "Alpenpas", "grond": "rots", "tint": [0.95, 0.97, 1.0], "sfeer": "over de Alpen in 1800: rotsen, een kanon op de pas, een wegkruis",
	 "kamp": [["rots", 7.6, 15.8, 0, {"maat": 0.9}], ["rots", -2.6, 14.6, 0, {"maat": 0.7}], ["kampvuur", 2.0, 13.4],
			  ["tent", 5.4, 15.4, -25], ["kanon", -0.6, 12.6, -20], ["kruis", 4.0, 12.2, 0], ["rots", 9.2, 12.4, 0, {"maat": 0.5}],
			  ["ton", 6.6, 12.9, 15], ["hakblok", 0.9, 14.7], ["kogels", 3.4, 14.4], ["bel", 8.2, 13.9, 0],
			  ["kruitvaten", 5.4, 11.8, 0]],
	 "overkant": [["rots", 2.0, -3.6, 0, {"maat": 1.1}], ["rots", 9.4, -4.0, 0, {"maat": 0.8}], ["wegwijzer", 6.2, -2.6],
				  ["hek_kraai", 0.8, -2.0], ["boom", 10.8, -2.4, 0, {"schaal": 1.2, "kaal": true}]]},
	{"naam": "Hoeve van Waterloo", "grond": "modder", "tint": [0.95, 0.94, 0.9], "sfeer": "de ommuurde hoeve: muren, een put, hooi en een kanon bij de poort",
	 "kamp": [["ruine", -1.4, 15.4, 25], ["hooiberg", 6.8, 15.6], ["put", 2.8, 13.0, 0], ["kanon", 4.6, 12.4, -10],
			  ["kampvuur", 0.4, 13.6], ["kruis", 8.6, 13.2, 0], ["tent", -2.8, 12.4, 50],
			  ["aambeeld", -0.4, 12.4, 20], ["ton", 6.0, 12.6, 0], ["glaswerk", 2.0, 15.0, 10],
			  ["kruitvaten", 9.8, 11.9, 0]],
	 "overkant": [["ruine", 5.2, -3.8, 165], ["hek_kraai", 1.6, -2.0], ["boom", 9.8, -3.6, 0, {"schaal": 1.6}],
				  ["plas_kikker", 11.0, -1.8, 0, {"stenen": true}], ["kruis", 3.2, -2.6, 0]]},
]


# ---------------------------------------------------------------- het kamp (vooraan)

## De camera kijkt met een yaw van ~20 graden (Board.tscn), dus wat verder
## naar voren staat (grote z) schuift op het scherm naar rechts en de
## overkant naar links: de x-posities zijn daarvoor gecorrigeerd zodat het
## kamp onder het bord in beeld staat en de overkant erboven.
## Een prop uit een diorama-regel neerzetten: [naam, x, z, draai_graden, {opties}].
func _plaats(spec: Array) -> void:
	var naam := String(spec[0])
	var pos := Vector3(float(spec[1]), GROND_Y, float(spec[2]))
	var draai := deg_to_rad(float(spec[3])) if spec.size() > 3 else 0.0
	var o: Dictionary = spec[4] if spec.size() > 4 else {}
	# Ligt er een geleverde glb voor deze prop (prop_<naam>[_team].glb)? Dan
	# die, met de generieke reacties (wiebel, hop, stof); de placeholders
	# hieronder zijn alleen voor wat er nog niet is. (Tent, hakblok, kogels,
	# wegwijzer, hek en plas kijken zelf, die houden hun kraai en kikker.)
	if GLB_VERVANGBAAR.has(naam):
		var hoogte: float = float(PROP_HOOGTE.get(naam, 0.8))
		if naam == "piramide":
			hoogte = float(o.get("maat", 1.2)) * 0.85
		elif naam == "boom":
			hoogte = 1.6 * float(o.get("schaal", 1.4))
		if _glb_prop(naam, pos, draai, _team_op(pos), ["prop_" + naam, "impact_wood"], hoogte) != null:
			return
	match naam:
		"kampvuur":
			_bouw_kampvuur(pos, bool(o.get("smeulend", false)))
		"trommel":
			var n_voor := _props.size()
			_bouw_glb_prop("prop_drum", pos, 0.42, draai, [_reageer_trommel, _reageer_trommel_roffel, _reageer_trommel_om])
			if bool(o.get("cadans", false)) and _props.size() == n_voor + 1:
				_spel.maak_cadans(_props.back(), _team_op(pos))   # de tamboer-cadans (12 september)
		"ton":
			_bouw_glb_prop("prop_barrel", pos, 0.56, draai, [_reageer_ton, _reageer_ton_appel, _reageer_ton_rol])
		"hoorn":
			_bouw_glb_prop("prop_horn", pos, 0.36, draai, [_reageer_hoorn, _reageer_hoorn_toeter, _reageer_hoorn_om])
		"hakblok":
			_bouw_bijl_stronk(pos)
		"kogels":
			_bouw_kogels(pos)
		"tent":
			_bouw_tent(pos, draai, bool(o.get("lantaarn", false)))
		"hek_kraai":
			_bouw_hek_met_kraai(pos, String(o.get("vogel", "zwart")))
		"plas_kikker":
			_bouw_plas_met_kikker(pos, bool(o.get("bevroren", false)), o)
		"wegwijzer":
			_bouw_wegwijzer(pos)
		"toilethuisje":
			_bouw_toilethuisje(pos, draai)
		"molen":
			_bouw_molen(pos, draai)
		"kanon":
			_bouw_kanon(pos, draai)
		"put":
			_bouw_put(pos, draai)
		"kruis":
			_bouw_kruis(pos, draai)
		"palm":
			_bouw_palm(pos, draai)
		"piramide":
			_bouw_piramide(pos, float(o.get("maat", 1.2)))
		"sfinx":
			_bouw_sfinx(pos, draai)
		"steiger_boot":
			_bouw_steiger_boot(pos, draai)
		"ruine":
			_bouw_ruine(pos, draai)
		"fontein":
			_bouw_fontein(pos)
		"marktkraam":
			_bouw_marktkraam(pos, draai)
		"sneeuwpop":
			_bouw_sneeuwpop(pos, draai)
		"hooiberg":
			_bouw_hooiberg(pos)
		"lantaarnpaal":
			_bouw_lantaarnpaal(pos)
		"boom":
			_bouw_boom(pos, float(o.get("schaal", 1.4)), bool(o.get("kaal", false)))
		"rots":
			_bouw_rots(pos, float(o.get("maat", 0.6)))
		"bel":
			_bouw_bel(pos, draai)
		"glaswerk":
			_bouw_glaswerk(pos, draai)
		"aambeeld":
			_bouw_aambeeld(pos, draai)
		"kookpot":
			_bouw_kookpot(pos)
		# de mini-games (12 september): de bal, de stenen, het doel van het kanon, de hengel
		"kegelspel":
			_spel.bouw_kegelspel(pos, draai)
		"kruitvaten":
			_spel.bouw_kruitvaten(pos, draai)
		"stenen":
			_spel.bouw_stenen(_props_root, pos, draai, _rivier_water())
		"hengel":
			_spel.bouw_hengel(_props_root, pos, draai, _rivier_water())
		_:
			push_warning("Omgeving: onbekende prop in het diorama: " + naam)


## Welk diorama (1..DIORAMAS.size()). Herbouwt alles onder Props.
func zet_diorama(i: int) -> void:
	_diorama = clampi(i, 1, DIORAMAS.size())
	if _props_root != null and _gebouwd != _diorama:
		_bouw_props()


## Per potje loten (game._loot_wind): zelfde seed op beide stoelen online.
## Een vast diorama uit het sfeer-paneel (knop `diorama` > 0) wint.
func loot_diorama(seed: int, herbouw: bool = true) -> void:
	var vast := int(PawnView.fx("diorama", 0.0))
	var i := vast if vast > 0 else 1 + posmod(seed, DIORAMAS.size())
	if herbouw:
		zet_diorama(i)
	else:
		_diorama = clampi(i, 1, DIORAMAS.size())   # zet_facties bouwt zo meteen


func diorama_index() -> int:
	return _diorama


func diorama_naam() -> String:
	return String(DIORAMAS[clampi(_diorama, 1, DIORAMAS.size()) - 1].naam)


static func aantal_dioramas() -> int:
	return DIORAMAS.size()


func _zet_grond(variant: String) -> void:
	if _grond_mat == null:
		return
	var tex: Texture2D = null
	if variant != "gras":
		tex = _laad_textuur("grond_%s.png" % variant)
	if tex == null:
		tex = _laad_textuur("gras.png")
	if tex != null:
		_grond_mat.albedo_texture = tex


func _bouw_kampvuur(pos: Vector3, smeulend: bool = false) -> void:
	var root := Node3D.new()
	root.name = "Kampvuur"
	root.position = pos
	_props_root.add_child(root)
	var hout := Color(0.33, 0.23, 0.14)
	for i in 4:
		var log := _mesh(_cilinder(0.035, 0.5), hout, root, Vector3(0.0, 0.05, 0.0))
		log.rotation = Vector3(deg_to_rad(80.0 + 8.0 * float(i % 2)), deg_to_rad(45.0 * float(i)), 0.0)
	for i in 7:
		var a := TAU * float(i) / 7.0
		var steen := _mesh(_bol(_rng.randf_range(0.045, 0.065)), Color(0.42, 0.40, 0.36), root, Vector3(cos(a) * 0.33, 0.03, sin(a) * 0.33))
		steen.scale = Vector3(1.0, 0.7, 1.0)
	var gloed := _mesh(_cilinder(0.14, 0.02), Color(0.9, 0.35, 0.08), root, Vector3(0.0, 0.03, 0.0))
	var gm := gloed.material_override as StandardMaterial3D
	gm.emission_enabled = true
	gm.emission = Color(1.0, 0.45, 0.1)
	gm.emission_energy_multiplier = 1.6
	_vuur_licht = OmniLight3D.new()
	_vuur_licht.light_color = Color(1.0, 0.68, 0.32)
	_vuur_basis = 0.45 if smeulend else 1.3
	_vuur_licht.light_energy = _vuur_basis
	_vuur_licht.omni_range = 4.0
	_vuur_licht.position = Vector3(0.0, 0.32, 0.0)
	root.add_child(_vuur_licht)
	# zuinig met additief: te veel overlappende vlammetjes worden wit
	var vlam := _deeltjes(18, 0.6, Vector3(0.0, 1.0, 0.0), 12.0, 0.35, 0.7, Vector3(0.0, 0.5, 0.0), 0.07, 0.13,
			[Color(1.0, 0.85, 0.4, 0.0), Color(1.0, 0.6, 0.15, 0.55), Color(0.85, 0.22, 0.05, 0.35), Color(0.2, 0.03, 0.0, 0.0)],
			[0.0, 0.15, 0.6, 1.0], true, 0.07)
	vlam.position = Vector3(0.0, 0.06, 0.0)
	vlam.visible = not smeulend
	vlam.emitting = not smeulend
	root.add_child(vlam)
	var rook := _deeltjes(9, 2.6, Vector3(0.0, 1.0, 0.0), 14.0, 0.28, 0.42, Vector3(0.0, 0.15, 0.0), 0.16, 0.34,
			[Color(0.5, 0.48, 0.45, 0.0), Color(0.45, 0.43, 0.4, 0.28), Color(0.4, 0.4, 0.4, 0.14), Color(0.4, 0.4, 0.4, 0.0)],
			[0.0, 0.15, 0.6, 1.0], false, 0.08)
	rook.position = Vector3(0.0, 0.35, 0.0)
	if smeulend:
		rook.amount = 22
	root.add_child(rook)
	var vonken := _deeltjes(40, 0.9, Vector3(0.0, 1.0, 0.0), 35.0, 1.4, 2.6, Vector3(0.0, -3.0, 0.0), 0.025, 0.04,
			[Color(1.0, 0.85, 0.4, 1.0), Color(1.0, 0.55, 0.15, 0.9), Color(0.6, 0.1, 0.0, 0.0)],
			[0.0, 0.5, 1.0], true, 0.05)
	vonken.one_shot = true
	vonken.explosiveness = 0.95
	vonken.emitting = false
	vonken.position = Vector3(0.0, 0.1, 0.0)
	root.add_child(vonken)
	_registreer(root, 0.5, [_reageer_kampvuur, _reageer_kampvuur_rook, _reageer_kampvuur_knal],
			{"vonken": vonken, "vlam": vlam, "rook": rook, "tik_extra": _tik_vuur})


func _bouw_glb_prop(naam: String, pos: Vector3, schaal: float, draai: float, reageer) -> void:
	var pad := Bestandsindex.vind(PROPS_DIR, naam + ".glb")
	if pad == "" or not ResourceLoader.exists(pad):
		return
	var ps: PackedScene = load(pad)
	if ps == null:
		return
	var inst: Node3D = ps.instantiate() as Node3D
	if inst == null:
		return
	var root := Node3D.new()
	root.name = naam
	root.position = pos
	root.rotation.y = draai
	_props_root.add_child(root)
	root.add_child(inst)
	inst.scale = Vector3(schaal, schaal, schaal)
	var aabb := _aabb_van(inst)
	# met de onderkant op het gras
	inst.position.y = -aabb.position.y * schaal
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_registreer(root, aabb.size.y * schaal, reageer, {"inst": inst})


func _bouw_bijl_stronk(pos: Vector3) -> void:
	if _glb_prop("hakblok", pos, 0.0, _team_op(pos), ["prop_bijl", "impact_wood"], 0.3) != null:
		return
	var root := Node3D.new()
	root.name = "Stronk"
	root.position = pos
	_props_root.add_child(root)
	var stronk := _mesh(_cilinder(0.19, 0.26), Color(0.40, 0.29, 0.18), root, Vector3(0.0, 0.13, 0.0))
	stronk.rotation.y = 0.4
	_mesh(_cilinder(0.165, 0.012), Color(0.62, 0.50, 0.33), root, Vector3(0.0, 0.265, 0.0))
	var pad := Bestandsindex.vind(PROPS_DIR, "prop_axe.glb")
	var bijl: Node3D = null
	if pad != "" and ResourceLoader.exists(pad):
		var ps: PackedScene = load(pad)
		if ps != null:
			bijl = ps.instantiate() as Node3D
	if bijl != null:
		var s := 0.46
		bijl.scale = Vector3(s, s, s)
		# op zijn kant op de stronk, steel naar buiten
		bijl.position = Vector3(0.06, 0.27 + 0.07 * s, 0.0)
		bijl.rotation = Vector3(0.0, deg_to_rad(35.0), deg_to_rad(-90.0))
		root.add_child(bijl)
	_registreer(root, 0.42, [_reageer_bijl, _reageer_bijl_hak, _reageer_bijl_valt], {"bijl": bijl})


func _bouw_kogels(pos: Vector3) -> void:
	if _glb_prop("kogels", pos, 0.0, "", ["prop_kogel", "impact_armor"], 0.3) != null:
		return
	var root := Node3D.new()
	root.name = "Kogels"
	root.position = pos
	_props_root.add_child(root)
	var r := 0.085
	var ijzer := Color(0.16, 0.16, 0.17)
	var basis: Array = []
	for i in 3:
		var a := TAU * float(i) / 3.0 + 0.3
		basis.append(Vector3(cos(a) * r * 1.02, r, sin(a) * r * 1.02))
	var basis_nodes: Array = []
	for b in basis:
		var k := _mesh(_bol(r), ijzer, root, b)
		(k.material_override as StandardMaterial3D).metallic = 0.6
		(k.material_override as StandardMaterial3D).roughness = 0.45
		basis_nodes.append(k)
	var rust := Vector3(0.0, r + r * 1.63, 0.0)
	var top := _mesh(_bol(r), ijzer, root, rust)
	(top.material_override as StandardMaterial3D).metallic = 0.6
	(top.material_override as StandardMaterial3D).roughness = 0.45
	_registreer(root, 0.4, [_reageer_kogels, _reageer_kogels_stort, _reageer_kogels_weg], {"top": top, "rust": rust, "zij": Vector3(0.42, r, 0.18), "basis": basis_nodes})


func _bouw_tent(pos: Vector3, draai: float, met_lantaarn: bool) -> void:
	var glb := _glb_prop("tent", pos, draai, _team_op(pos), ["prop_lantaarn"], 1.0,
			[_reageer_tent, _reageer_tent_zzz, _reageer_tent_laars], {"tik": TIK_GELUID["Tent"], "lantaarn": null})
	if glb != null:
		# de geleverde tent houdt de reacties van de placeholder: het doek is het
		# model zelf, en de lantaarn hangt aan de voorkant van zijn omhullende doos
		var gp: Dictionary = _props.back()
		gp["doek"] = gp.inst
		if met_lantaarn:
			var doos: AABB = _aabb_van(glb)
			gp["lantaarn"] = _hang_lantaarn(glb, Vector3(0.0, doos.end.y * 0.9, doos.end.z + 0.16))
		return
	var root := Node3D.new()
	root.name = "Tent%d" % (_props.size() + 1)
	root.position = pos
	root.rotation.y = draai
	_props_root.add_child(root)
	var pm := PrismMesh.new()
	pm.size = Vector3(1.35, 0.95, 1.6)
	var doek := _mesh(pm, Color(0.60, 0.54, 0.40), root, Vector3(0.0, 0.475, 0.0))
	doek.rotation.y = 0.0
	# nokbalk en twee palen
	_mesh(_cilinder(0.02, 1.7), Color(0.36, 0.26, 0.16), root, Vector3(0.0, 0.96, 0.0)).rotation.x = deg_to_rad(90.0)
	_mesh(_cilinder(0.025, 0.98), Color(0.36, 0.26, 0.16), root, Vector3(0.0, 0.49, 0.83))
	_mesh(_cilinder(0.025, 0.98), Color(0.36, 0.26, 0.16), root, Vector3(0.0, 0.49, -0.83))
	# donkere opening aan de voorkant
	var opening := _mesh(PrismMesh.new(), Color(0.10, 0.08, 0.06), root, Vector3(0.0, 0.22, 0.81))
	(opening.mesh as PrismMesh).size = Vector3(0.5, 0.45, 0.02)
	var lantaarn: Node3D = null
	if met_lantaarn:
		lantaarn = _hang_lantaarn(root, Vector3(0.0, 0.92, 1.16))
	_registreer(root, 0.95, [_reageer_tent, _reageer_tent_zzz, _reageer_tent_laars], {"lantaarn": lantaarn, "doek": doek})


## Een lantaarn aan een armpje op `plek` (in de ruimte van root); het armpje
## steekt 0,35 naar achteren, de tent in. Geeft de lantaarn-knoop terug (die
## zwaait in _reageer_tent); zijn licht flakkert mee in _process via _lantaarns.
func _hang_lantaarn(root: Node3D, plek: Vector3) -> Node3D:
	var arm := _mesh(_cilinder(0.012, 0.35), Color(0.36, 0.26, 0.16), root, plek + Vector3(0.0, 0.0, -0.16))
	arm.rotation.x = deg_to_rad(90.0)
	var lantaarn := Node3D.new()
	lantaarn.position = plek
	root.add_child(lantaarn)
	var lamp := _mesh(_bol(0.045), Color(1.0, 0.8, 0.4), lantaarn, Vector3(0.0, -0.12, 0.0))
	var lm := lamp.material_override as StandardMaterial3D
	lm.emission_enabled = true
	lm.emission = Color(1.0, 0.75, 0.35)
	lm.emission_energy_multiplier = 2.2
	_mesh(_cilinder(0.006, 0.1), Color(0.2, 0.18, 0.15), lantaarn, Vector3(0.0, -0.05, 0.0))
	var licht := OmniLight3D.new()
	licht.light_color = Color(1.0, 0.78, 0.45)
	licht.light_energy = 0.7
	licht.omni_range = 2.6
	licht.position = Vector3(0.0, -0.12, 0.0)
	lantaarn.add_child(licht)
	_lantaarns.append(licht)
	return lantaarn


# ---------------------------------------------------------------- de overkant

func _bouw_hek_met_kraai(pos: Vector3, kleur_naam: String = "zwart") -> void:
	var root := Node3D.new()
	root.name = "Hek"
	root.position = pos
	_props_root.add_child(root)
	var hout := Color(0.38, 0.29, 0.19)
	if _glb_prop("hek", pos, 0.0, "", ["impact_wood"], 0.4) == null:
		var hek := Node3D.new()
		hek.name = "Hek"
		root.add_child(hek)
		var paal_x: Array = [0.0, 0.9, 1.8, 2.7]
		for x in paal_x:
			_mesh(_box(Vector3(0.07, 0.36, 0.07)), hout, hek, Vector3(x, 0.18, 0.0))
		var latten: Array = []
		for h in [0.13, 0.28]:
			latten.append(_mesh(_box(Vector3(2.85, 0.035, 0.03)), hout, hek, Vector3(1.35, h, 0.0)))
		_registreer(hek, 0.36, [_reageer_hek_kraak], {"latten": latten, "tik_extra": _tik_hek})
	# de kraai (of meeuw) op de tweede paal
	var zwart: Color = Color(0.92, 0.92, 0.9) if String(kleur_naam) == "wit" else Color(0.07, 0.065, 0.08)
	var kraai := _maak_vogel(root, Vector3(0.9, 0.36, 0.0), zwart)
	kraai.name = "Kraai"
	kraai.rotation.y = deg_to_rad(-30.0)
	var vleugels: Array = kraai.get_meta("vleugels")
	_registreer(kraai, 0.16, [_reageer_kraai, _reageer_kraai_liefde, _reageer_kraai_geschoten], {"thuis": kraai.position, "vleugels": vleugels, "kleur": zwart})


func _bouw_plas_met_kikker(pos: Vector3, bevroren: bool = false, o: Dictionary = {}) -> void:
	var root := Node3D.new()
	root.name = "Plas"
	root.position = pos
	_props_root.add_child(root)
	# de mini-games aan de plas (12 september): keilen (op ijs: glijden) en vissen
	var water := {"soort": "plas", "root": root, "rx": 0.6, "rz": 0.43, "bevroren": bevroren, "ring_ouder": root}
	if bool(o.get("stenen", false)):
		_spel.bouw_stenen(root, Vector3(-0.78, 0.0, 0.3), atan2(-0.78, 0.3), water)
	if bool(o.get("hengel", false)) and not bevroren:
		_spel.bouw_hengel(root, Vector3(0.55, 0.0, 0.48), atan2(0.55, 0.48), water)
	if bevroren:
		var ijs := _mesh(_cilinder(0.6, 0.014), Color(0.78, 0.86, 0.92), root, Vector3(0.0, 0.007, 0.0))
		ijs.scale = Vector3(1.0, 1.0, 0.72)
		var imat := ijs.material_override as StandardMaterial3D
		imat.roughness = 0.2
		imat.metallic_specular = 0.8
		_registreer(root, 0.1, [_reageer_ijs_krak, _reageer_ijs_glij, _reageer_ijs_krak], {"ijs": ijs})
		return
	if _glb_prop("plas", pos, 0.0, "", [], 0.04) == null:
		# geen metaal: dat spiegelt de zwarte hemel en wordt een gat in het gras
		var plas := _mesh(_cilinder(0.6, 0.012), Color(0.46, 0.52, 0.54), root, Vector3(0.0, 0.006, 0.0))
		plas.scale = Vector3(1.0, 1.0, 0.72)
		var pmat := plas.material_override as StandardMaterial3D
		pmat.metallic = 0.0
		pmat.roughness = 0.35
		pmat.metallic_specular = 0.6
		_registreer(root, 0.05, [_reageer_plas_plons], {"tik_extra": _tik_plas})
	var kikker := Node3D.new()
	kikker.name = "Kikker"
	kikker.position = Vector3(-0.3, 0.012, 0.05)
	root.add_child(kikker)
	var groen := Color(0.36, 0.52, 0.22)
	var lijf := _mesh(_bol(0.055), groen, kikker, Vector3(0.0, 0.04, 0.0))
	lijf.scale = Vector3(1.0, 0.75, 1.25)
	_kikker_keel = _mesh(_bol(0.028), Color(0.62, 0.68, 0.40), kikker, Vector3(0.0, 0.03, 0.055))
	for kant in [-1.0, 1.0]:
		_mesh(_bol(0.016), Color(0.1, 0.1, 0.08), kikker, Vector3(kant * 0.03, 0.075, 0.04))
	var thuis: Vector3 = kikker.position
	var alt := Vector3(0.32, 0.012, -0.08)
	water["kikker"] = kikker   # de stenen laten hem wegduiken
	_registreer(kikker, 0.1, [_reageer_kikker, _reageer_kikker_kwaak, _reageer_kikker_duik], {"thuis": thuis, "alt": alt, "plas": root, "keel": _kikker_keel})


func _bouw_wegwijzer(pos: Vector3) -> void:
	if _glb_prop("wegwijzer", pos, deg_to_rad(12.0), "", ["prop_wegwijzer", "impact_wood"], 0.95) != null:
		return
	var root := Node3D.new()
	root.name = "Wegwijzer"
	root.position = pos
	root.rotation.y = deg_to_rad(12.0)
	_props_root.add_child(root)
	var hout := Color(0.42, 0.32, 0.20)
	_mesh(_cilinder(0.03, 0.95), hout, root, Vector3(0.0, 0.475, 0.0))
	var plank := _mesh(_box(Vector3(0.5, 0.1, 0.03)), Color(0.55, 0.45, 0.28), root, Vector3(0.18, 0.82, 0.0))
	plank.rotation.y = deg_to_rad(-20.0)
	var plank2 := _mesh(_box(Vector3(0.42, 0.1, 0.03)), Color(0.55, 0.45, 0.28), root, Vector3(-0.14, 0.66, 0.0))
	plank2.rotation.y = deg_to_rad(35.0)
	_registreer(root, 0.95, [_reageer_wegwijzer, _reageer_wegwijzer_draai, _reageer_wegwijzer_kraai], {})


# ---------------------------------------------------------------- props (her)bouwen

## Alles onder Props opnieuw: kamp, overkant, geleverde extra props en de
## bewoners, met de teams en facties van dit moment. De tweens van de
## reacties hangen aan hun eigen prop-node, dus die sterven netjes mee.
func _bouw_props() -> void:
	for kind in _props_root.get_children():
		# eerst uit de boom, dan vrijgeven: queue_free wacht tot het einde van
		# het frame en de nieuwe props zouden anders hun naam niet krijgen
		_props_root.remove_child(kind)
		kind.queue_free()
	_props.clear()
	_spel.reset()
	_rivier_node = null
	_bewoners.clear()
	_bewoners_root = null
	_lantaarns.clear()
	_kraai_koppen.clear()
	_wieken.clear()
	_wiek_boost.clear()
	_vuur_licht = null
	_kikker_keel = null
	_kraai_kop = null
	var d: Dictionary = DIORAMAS[clampi(_diorama, 1, DIORAMAS.size()) - 1]
	_gebouwd = _diorama
	_zet_grond(String(d.get("grond", "gras")))
	var tint: Array = d.get("tint", [1.0, 1.0, 1.0])
	_grond_tint = Color(float(tint[0]), float(tint[1]), float(tint[2]), 1.0)
	if _grond_mat != null:
		var licht: float = PawnView.fx("omgeving_licht", 1.0)
		_grond_mat.albedo_color = Color(1.15 * licht * _grond_tint.r, 1.15 * licht * _grond_tint.g, 1.15 * licht * _grond_tint.b, 1.0)
	for spec in d.get("kamp", []):
		_plaats(spec)
	for spec in d.get("overkant", []):
		_plaats(spec)
	for extra in d.get("extra", []):
		match String(extra):
			"sneeuw":
				_bouw_sneeuw()
			"water":
				_bouw_water()
	_bouw_extra_props()
	_spel.koppel_doelen()   # elk kanon kijkt naar zijn kruitvaten
	_bouw_bewoners()


## Het team van het kamp waar deze positie ligt (vooraan = eigen).
func _team_op(pos: Vector3) -> String:
	return _team_eigen if pos.z > 8.0 else _team_ander


## prop_<naam>_<team>.glb, anders prop_<naam>.glb, anders "".
func _prop_glb(naam: String, team: String) -> String:
	var kandidaten: Array = []
	if team != "":
		kandidaten.append("prop_%s_%s.glb" % [naam, team])
	kandidaten.append("prop_%s.glb" % naam)
	for k in kandidaten:
		var pad := Bestandsindex.vind(PROPS_DIR.trim_suffix("/"), String(k))
		if pad != "" and ResourceLoader.exists(pad):
			return pad
	return ""


## prop_<naam>_<team>.json als die er ligt, anders prop_<naam>.json, anders {}.
func _lees_prop_manifest(naam: String, team: String = "") -> Dictionary:
	var pad := ""
	if team != "":
		pad = Bestandsindex.vind(PROPS_DIR.trim_suffix("/"), "prop_%s_%s.json" % [naam, team])
	if pad == "":
		pad = Bestandsindex.vind(PROPS_DIR.trim_suffix("/"), "prop_%s.json" % naam)
	if pad == "":
		return {}
	var f := FileAccess.open(pad, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	return data if data is Dictionary else {}


## Ligt er een glb voor deze prop (per team of gedeeld)? Dan die in plaats van
## de primitieven: op zijn ware hoogte geschaald (PROP_HOOGTE of het manifest),
## voeten op het gras, en een wiebel met het geluid van de prop als klik. Geeft
## de wortel terug, null als er geen glb ligt. Met `reacties` en `extra` houdt
## een prop zijn EIGEN reacties in plaats van de generieke wiebel (de tent zijn
## lantaarn, Zzz en laars; 12 september, de eerste Tripo-tent); het geleverde
## model staat dan in `inst`, de bestandsnaam in `glb` (voor de check).
func _glb_prop(naam: String, pos: Vector3, draai: float, team: String, geluid: Array, hoogte_std: float,
		reacties: Array = [], extra: Dictionary = {}) -> Node3D:
	var pad := _prop_glb(naam, team)
	if pad == "":
		return null
	var ps: PackedScene = load(pad)
	if ps == null:
		return null
	var inst: Node3D = ps.instantiate() as Node3D
	if inst == null:
		return null
	var root := Node3D.new()
	# uniek per prop, net als Tent1/Tent2: twee gelijke namen onder Props laat
	# Godot anders zelf hernoemen tot @Node3D@123
	root.name = "prop_%s%d" % [naam, _props.size() + 1]
	root.position = pos
	root.rotation.y = draai
	_props_root.add_child(root)
	root.add_child(inst)
	var m := _lees_prop_manifest(naam, team)
	var hoogte := float(m.get("hoogte", PROP_HOOGTE.get(naam, hoogte_std)))
	var aabb := _aabb_van(inst)
	if aabb.size.y > 0.0001:
		var sc := hoogte / aabb.size.y
		inst.scale = Vector3(sc, sc, sc)
		inst.position.y = -aabb.position.y * sc + float(m.get("y", 0.0))
	inst.rotation.y = deg_to_rad(float(m.get("draai", 0.0)))
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var e := extra.duplicate()
	e["inst"] = inst
	e["geluid"] = geluid
	e["glb"] = pad.get_file()
	if not e.has("tik"):
		e["tik"] = geluid if not geluid.is_empty() else ["prop_tik", "ui_click"]
	var lijst: Array = reacties if not reacties.is_empty() else [_reageer_glb, _reageer_glb_hop, _reageer_glb_stof]
	_registreer(root, hoogte, lijst, e)
	return root


func _reageer_glb(p: Dictionary) -> void:
	var n: Node3D = p.inst
	_geluid(p.geluid)
	var tw := (p.node as Node3D).create_tween()
	var amp := 0.14
	for i in 3:
		tw.tween_property(n, "rotation:z", amp, 0.1).set_trans(Tween.TRANS_SINE)
		tw.tween_property(n, "rotation:z", -amp, 0.1).set_trans(Tween.TRANS_SINE)
		amp *= 0.5
	tw.tween_property(n, "rotation:z", 0.0, 0.1)
	tw.tween_callback(func() -> void: p.bezig = false)


## Wishlist-props zonder placeholder: alleen als hun glb er ligt.
func _bouw_extra_props() -> void:
	for e in EXTRA_PROPS:
		var naam := String(e.naam)
		var geluid: Array = e.get("geluid", [])
		if e.has("eigen"):
			var pe: Array = e.eigen
			_glb_prop(naam, Vector3(float(pe[0]), GROND_Y, float(pe[1])), deg_to_rad(float(e.get("draai", 0.0))),
					_team_eigen, geluid, 0.5)
		if e.has("ander"):
			var pa: Array = e.ander
			_glb_prop(naam, Vector3(float(pa[0]), GROND_Y, float(pa[1])), deg_to_rad(float(e.get("draai_ander", 180.0))),
					_team_ander, geluid, 0.5)


# ---------------------------------------------------------------- bewoners

func _bouw_bewoners() -> void:
	for b in _bewoners:
		if is_instance_valid(b):
			for i in range(_props.size() - 1, -1, -1):
				if _props[i].node == b:
					_props.remove_at(i)
			b.queue_free()
	_bewoners.clear()
	if _bewoners_root == null:
		_bewoners_root = Node3D.new()
		_bewoners_root.name = "Bewoners"
		_props_root.add_child(_bewoners_root)
	var slot: Dictionary = {"eigen": 0, "ander": 0}
	for n in Bewoner.alle_namen():
		var m := Bewoner.lees_manifest(String(n))
		var fac := Bewoner.factie_van(String(n), m)
		var team := Bewoner.team_van(String(n), m)
		# met factie: standaard aan beide kanten, bij wie die factie speelt;
		# zonder factie: standaard alleen vooraan; een teamwoord (red/blue)
		# beperkt tot het kamp met die kleur (rood arm, blauw rijk)
		var kant := String(m.get("kant", "beide" if fac >= 0 else "eigen"))
		var kanten: Array = []
		if fac < 0:
			kanten = ["eigen", "ander"] if kant == "beide" else [kant]
		else:
			if fac == _factie_eigen and kant != "ander":
				kanten.append("eigen")
			if fac == _factie_ander and kant != "eigen":
				kanten.append("ander")
		if team != "":
			kanten = kanten.filter(func(k): return (k == "eigen" and team == _team_eigen) or (k == "ander" and team == _team_ander))
		for k in kanten:
			var b := Bewoner.new()
			if not b.laad(String(n)):
				b.free()
				continue
			var plek_sleutel := "plek" if k == "eigen" else "plek_ander"
			if m.has(plek_sleutel):
				var pl: Array = m[plek_sleutel]
				b.position = Vector3(float(pl[0]), GROND_Y, float(pl[1]))
			else:
				var slots: Array = BEWONER_SLOTS_EIGEN if k == "eigen" else BEWONER_SLOTS_ANDER
				b.position = slots[int(slot[k]) % slots.size()]
				slot[k] = int(slot[k]) + 1
			var draai_std := 0.0 if k == "eigen" else 180.0
			b.rotation.y = deg_to_rad(float(m.get("draai", draai_std)))
			_bewoners_root.add_child(b)
			_bewoners.append(b)
			b.zet_cape(_team_eigen if k == "eigen" else _team_ander)
			_bouw_decor(b, m)
			_registreer(b, b.hoogte, [_reageer_bewoner, _reageer_bewoner, _reageer_bewoner_hart], {"bewoner": b})


## Sfeer-paneel: een cape-knop is verdraaid, elke bewoner opnieuw.
func herhang_capes() -> void:
	for b in _bewoners:
		if is_instance_valid(b):
			(b as Bewoner).zet_cape((b as Bewoner).kamp_team)


## Spulletjes bij een bewoner (manifest "decor": ["stronk", "houtstapel",
## "kist"]), als kinderen van het poppetje zodat ze meedraaien en meegaan.
func _bouw_decor(b: Node3D, m: Dictionary) -> void:
	var lijst: Array = Array(m.get("decor", []))
	var off: Array = Array(m.get("decor_offset", [0.0, 0.5]))
	var basis := Vector3(float(off[0]), 0.0, float(off[1]))
	var i := 0
	for d in lijst:
		var pos := basis + Vector3(0.35 * float(i), 0.0, 0.0)
		match String(d):
			"stronk":
				_mesh(_cilinder(0.15, 0.22), Color(0.40, 0.29, 0.18), b, pos + Vector3(0.0, 0.11, 0.0))
				_mesh(_cilinder(0.13, 0.012), Color(0.62, 0.50, 0.33), b, pos + Vector3(0.0, 0.225, 0.0))
				var blok := _mesh(_cilinder(0.045, 0.22), Color(0.55, 0.42, 0.26), b, pos + Vector3(0.0, 0.34, 0.0))
				blok.rotation.z = deg_to_rad(6.0)
			"houtstapel":
				for r in 3:
					for c in (3 - r):
						var log := _mesh(_cilinder(0.04, 0.32), Color(0.45, 0.33, 0.20), b,
								pos + Vector3(-0.09 + 0.09 * float(c) + 0.045 * float(r), 0.04 + 0.075 * float(r), 0.0))
						log.rotation.x = deg_to_rad(90.0)
			"kist":
				_mesh(_box(Vector3(0.36, 0.22, 0.26)), Color(0.42, 0.31, 0.19), b, pos + Vector3(0.0, 0.11, 0.0))
				_mesh(_box(Vector3(0.38, 0.03, 0.28)), Color(0.55, 0.42, 0.26), b, pos + Vector3(0.0, 0.235, 0.0))
			"vuurtje":
				var gloed := _mesh(_cilinder(0.1, 0.02), Color(0.9, 0.35, 0.08), b, pos + Vector3(0.0, 0.01, 0.0))
				var gm := gloed.material_override as StandardMaterial3D
				gm.emission_enabled = true
				gm.emission = Color(1.0, 0.45, 0.1)
				gm.emission_energy_multiplier = 1.4
				for j in 3:
					var st := _mesh(_cilinder(0.025, 0.28), Color(0.33, 0.23, 0.14), b, pos + Vector3(0.0, 0.03, 0.0))
					st.rotation = Vector3(deg_to_rad(82.0), deg_to_rad(60.0 * float(j)), 0.0)
			_:
				pass
		i += 1


func _reageer_bewoner(p: Dictionary) -> void:
	var b: Bewoner = p.bewoner
	if not is_instance_valid(b):
		p.bezig = false
		return
	if b.doe_actie():
		b.actie_klaar.connect(func() -> void: p.bezig = false, CONNECT_ONE_SHOT)
		return
	# geen actie-clip: een huppeltje, zodat een klik altijd iets doet
	var basis: Vector3 = b.scale
	var tw := (p.node as Node3D).create_tween()
	tw.tween_property(b, "scale", basis * Vector3(1.08, 0.9, 1.08), 0.08)
	tw.tween_property(b, "scale", basis, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: p.bezig = false)


# ---------------------------------------------------------------- reacties
# Elke prop heeft drie: de eerste is de oude, de andere twee zijn de variatie
# (11 september). Alle tweens hangen aan de prop-node, effecten ruimen zichzelf op.

func _klaar(p: Dictionary, tw: Tween) -> void:
	tw.tween_callback(func() -> void: p.bezig = false)


func _reageer_kampvuur_rook(p: Dictionary) -> void:
	# een dikke rookpluim, iemand hoest
	var root: Node3D = p.node
	_geluid(["prop_vuur"])
	_fx_wolk(root, Vector3(0.0, 0.35, 0.0), Color(0.45, 0.43, 0.4), 2.2)
	_fx_tekst(root, Vector3(0.3, 0.6, 0.2), "kuch kuch")
	var tw := root.create_tween()
	tw.tween_property(self, "_vuur_basis", 0.5, 0.3)
	tw.tween_interval(1.2)
	tw.tween_property(self, "_vuur_basis", 1.3, 1.0).set_trans(Tween.TRANS_SINE)
	_klaar(p, tw)


func _reageer_kampvuur_knal(p: Dictionary) -> void:
	# een dennenappel knalt: vonken opzij, het vuur schrikt
	var root: Node3D = p.node
	var vonken: GPUParticles3D = p.vonken
	_geluid(["prop_vuur", "impact_wood"])
	vonken.restart()
	vonken.emitting = true
	_fx_tekst(root, Vector3(-0.2, 0.55, 0.0), "Knal!", Color(1.0, 0.75, 0.3))
	var tw := root.create_tween()
	tw.tween_property(self, "_vuur_basis", 4.0, 0.06)
	tw.tween_property(self, "_vuur_basis", 0.7, 0.25)
	tw.tween_property(self, "_vuur_basis", 1.3, 1.2).set_trans(Tween.TRANS_SINE)
	_klaar(p, tw)


func _reageer_trommel_roffel(p: Dictionary) -> void:
	var n: Node3D = p.inst
	_geluid(["prop_trom", "val_drum"])
	_fx_tekst(p.node, Vector3(0.0, 0.5, 0.0), "rrrrom!")
	var tw := (p.node as Node3D).create_tween()
	var basis: Vector3 = n.scale
	for i in 10:
		tw.tween_property(n, "scale", basis * Vector3(1.05, 0.93, 1.05), 0.05)
		tw.tween_property(n, "scale", basis, 0.05)
	_klaar(p, tw)


func _reageer_trommel_om(p: Dictionary) -> void:
	# valt op zijn kant en rolt een stukje, komt terug
	var n: Node3D = p.inst
	_geluid(["prop_trom", "val_drum"])
	var tw := (p.node as Node3D).create_tween()
	tw.tween_property(n, "rotation:x", deg_to_rad(90.0), 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(n, "position:z", n.position.z + 0.3, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.6)
	tw.tween_property(n, "rotation:x", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(n, "position:z", n.position.z, 0.3)
	_klaar(p, tw)


func _reageer_ton_appel(p: Dictionary) -> void:
	# de deksel wipt, een appel springt eruit en rolt weg
	var root: Node3D = p.node
	_geluid(["prop_ton", "impact_wood"])
	var appel := _mesh(_bol(0.045), Color(0.8, 0.18, 0.12), root, Vector3(0.0, 0.5, 0.0))
	appel.scale = Vector3(0.01, 0.01, 0.01)
	var doel := Vector3(_rng.randf_range(-0.5, 0.5), 0.045, _rng.randf_range(0.3, 0.6))
	var tw := appel.create_tween()
	tw.tween_property(appel, "scale", Vector3.ONE, 0.08)
	tw.tween_method(_boog.bind(appel, Vector3(0.0, 0.5, 0.0), doel, 0.9), 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(appel, "rotation:x", 6.0, 0.55)
	tw.tween_interval(3.0)
	tw.tween_property(appel, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
	tw.tween_callback(appel.queue_free)
	var n: Node3D = p.inst
	var tw2 := root.create_tween()
	tw2.tween_property(n, "position:y", n.position.y + 0.08, 0.1)
	tw2.tween_property(n, "position:y", n.position.y, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_klaar(p, tw2)


func _reageer_ton_rol(p: Dictionary) -> void:
	var n: Node3D = p.inst
	_geluid(["prop_ton", "impact_wood"])
	var tw := (p.node as Node3D).create_tween()
	tw.tween_property(n, "rotation:x", deg_to_rad(88.0), 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "position:z", n.position.z + 0.55, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(n, "rotation:y", n.rotation.y + 3.0, 0.8)
	tw.tween_interval(1.5)
	tw.tween_property(n, "position:z", n.position.z, 0.5).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(n, "rotation:y", n.rotation.y, 0.5)
	tw.tween_property(n, "rotation:x", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_klaar(p, tw)


func _reageer_hoorn_toeter(p: Dictionary) -> void:
	# een signaalstoot: de hoorn springt op, iedereen schrikt (en de kraaien vliegen op)
	var n: Node3D = p.inst
	_geluid(["prop_hoorn", "initiative", "val_horn"])
	_fx_tekst(p.node, Vector3(0.0, 0.45, 0.0), "TOEOET!", Color(1.0, 0.85, 0.4))
	_schrik_vogels()
	var tw := (p.node as Node3D).create_tween()
	tw.tween_property(n, "rotation:x", -0.9, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(n, "position:y", n.position.y + 0.12, 0.15)
	for i in 3:
		tw.tween_property(n, "scale", n.scale * 1.1, 0.12)
		tw.tween_property(n, "scale", n.scale, 0.12)
	tw.tween_property(n, "rotation:x", 0.0, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(n, "position:y", n.position.y, 0.3)
	_klaar(p, tw)


func _reageer_hoorn_om(p: Dictionary) -> void:
	var n: Node3D = p.inst
	_geluid(["val_horn"])
	var tw := (p.node as Node3D).create_tween()
	tw.tween_property(n, "rotation:z", deg_to_rad(80.0), 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.8)
	tw.tween_property(n, "rotation:z", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_klaar(p, tw)


func _reageer_bijl_hak(p: Dictionary) -> void:
	# de bijl gaat omhoog en hakt: het blok op de stronk splijt in tweeen
	var root: Node3D = p.node
	var n: Node3D = p.bijl
	if n == null:
		_reageer_bijl(p)
		return
	var tw := root.create_tween()
	tw.tween_property(n, "position:y", n.position.y + 0.3, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "position:y", n.position.y, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		_geluid(["prop_bijl", "impact_wood"])
		_fx_wolk(root, Vector3(0.0, 0.3, 0.0), Color(0.6, 0.5, 0.35), 0.5)
		for kant in [-1.0, 1.0]:
			var helft := _mesh(_cilinder(0.03, 0.2), Color(0.62, 0.50, 0.33), root, Vector3(0.0, 0.32, 0.0))
			var doel := Vector3(kant * _rng.randf_range(0.25, 0.45), 0.03, _rng.randf_range(-0.2, 0.2))
			var ht := helft.create_tween()
			ht.tween_method(_boog.bind(helft, Vector3(0.0, 0.32, 0.0), doel, 0.5), 0.0, 1.0, 0.5).set_trans(Tween.TRANS_SINE)
			ht.parallel().tween_property(helft, "rotation", Vector3(_rng.randf_range(-3, 3), 0.0, kant * 1.5), 0.5)
			ht.tween_interval(2.5)
			ht.tween_property(helft, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
			ht.tween_callback(helft.queue_free))
	tw.tween_interval(0.4)
	_klaar(p, tw)


func _reageer_bijl_valt(p: Dictionary) -> void:
	var n: Node3D = p.bijl
	if n == null:
		_reageer_bijl(p)
		return
	_geluid(["val_prop", "impact_wood"])
	var thuis_pos: Vector3 = n.position
	var thuis_rot: Vector3 = n.rotation
	var tw := (p.node as Node3D).create_tween()
	tw.tween_property(n, "position", Vector3(0.32, 0.02, 0.15), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(n, "rotation", Vector3(0.0, deg_to_rad(80.0), 0.0), 0.35)
	tw.tween_interval(2.5)
	tw.tween_property(n, "position", thuis_pos, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(n, "rotation", thuis_rot, 0.4)
	_klaar(p, tw)


func _reageer_kogels_stort(p: Dictionary) -> void:
	# de hele stapel stort in en rolt uit elkaar, en wordt weer opgestapeld
	var root: Node3D = p.node
	var top: Node3D = p.top
	var rust: Vector3 = p.rust
	var basis: Array = p.basis
	_geluid(["prop_kogel", "impact_armor"])
	var alle: Array = basis.duplicate()
	alle.append(top)
	var thuis: Array = []
	for k in alle:
		thuis.append((k as Node3D).position)
	var tw := root.create_tween()
	for i in alle.size():
		var k: Node3D = alle[i]
		var doel := Vector3(_rng.randf_range(-0.55, 0.55), 0.085, _rng.randf_range(-0.45, 0.55))
		tw.parallel().tween_method(_boog.bind(k, thuis[i], doel, 0.25), 0.0, 1.0, _rng.randf_range(0.4, 0.7)).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(k, "rotation:x", (k as Node3D).rotation.x + _rng.randf_range(2.0, 5.0), 0.7)
	tw.chain().tween_interval(2.6)
	for i in alle.size():
		var k: Node3D = alle[i]
		tw.parallel().tween_method(_boog.bind(k, (k as Node3D).position, thuis[i], 0.3), 0.0, 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_delay(0.1 * float(i))
	tw.chain().tween_callback(func() -> void: top.position = rust)
	_klaar(p, tw)


func _reageer_kogels_weg(p: Dictionary) -> void:
	# een kogel rolt weg naar de tent, botst en komt terug
	var top: Node3D = p.top
	var rust: Vector3 = p.rust
	var zij: Vector3 = p.zij
	var ver := Vector3(-1.6, 0.085, 0.9)
	var tw := (p.node as Node3D).create_tween()
	tw.tween_method(_boog.bind(top, rust, zij, 0.25), 0.0, 1.0, 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(top, "position", ver, 1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(top, "rotation:x", top.rotation.x + 9.0, 1.3)
	tw.tween_callback(func() -> void:
		_geluid(["prop_kogel", "impact_wood"])
		_fx_tekst(p.node, ver + Vector3(0.0, 0.3, 0.0), "Au!"))
	tw.tween_interval(1.6)
	tw.tween_method(_boog.bind(top, ver, rust, 0.6), 0.0, 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	_klaar(p, tw)


func _reageer_tent_zzz(p: Dictionary) -> void:
	# er slaapt iemand: de tent ademt, Zzz stijgt op
	var root: Node3D = p.node
	var doek: Node3D = p.doek
	_geluid(["bewoner_snurken"])
	var basis: Vector3 = doek.scale
	var tw := root.create_tween()
	for i in 3:
		tw.tween_property(doek, "scale", basis * Vector3(1.02, 1.04, 1.02), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(func() -> void: _fx_tekst(root, Vector3(0.25, 0.9, 0.6), "Zzz", Color(0.85, 0.9, 1.0)))
		tw.tween_property(doek, "scale", basis, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_klaar(p, tw)


func _reageer_tent_laars(p: Dictionary) -> void:
	# een laars vliegt uit de opening: "Wegwezen!"
	var root: Node3D = p.node
	_geluid(["val_prop", "impact_wood"])
	var laars := Node3D.new()
	laars.position = Vector3(0.0, 0.25, 0.75)
	root.add_child(laars)
	_mesh(_box(Vector3(0.09, 0.16, 0.1)), Color(0.22, 0.16, 0.1), laars, Vector3(0.0, 0.08, 0.0))
	_mesh(_box(Vector3(0.09, 0.05, 0.17)), Color(0.22, 0.16, 0.1), laars, Vector3(0.0, 0.025, 0.05))
	var doel := Vector3(_rng.randf_range(-0.5, 0.5), 0.0, _rng.randf_range(1.3, 1.9))
	var tw := laars.create_tween()
	tw.tween_method(_boog.bind(laars, laars.position, doel, 0.9), 0.0, 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(laars, "rotation", Vector3(_rng.randf_range(-6, 6), _rng.randf_range(-3, 3), _rng.randf_range(-6, 6)), 0.7)
	tw.tween_callback(func() -> void: _fx_tekst(root, Vector3(0.0, 0.9, 0.8), "Wegwezen!", Color(1.0, 0.8, 0.7)))
	tw.tween_interval(3.0)
	tw.tween_property(laars, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
	tw.tween_callback(laars.queue_free)
	var tw2 := root.create_tween()
	tw2.tween_interval(1.2)
	_klaar(p, tw2)


func _reageer_kraai_liefde(p: Dictionary) -> void:
	# er komt een tweede kraai bij, hartjes, en na een tijdje vliegt die weer weg
	var n: Node3D = p.node
	var ouder: Node3D = n.get_parent()
	var kleur: Color = p.get("kleur", Color(0.07, 0.065, 0.08))
	_geluid(["prop_kraai"])
	var plek := n.position + Vector3(0.9, 0.0, 0.0)
	var ander := _maak_vogel(ouder, plek + Vector3(2.5, 3.0, -1.5), kleur)
	ander.rotation.y = n.rotation.y + PI
	_vlieg(ander, plek, 1.2, false)
	var tw := ouder.create_tween()
	tw.tween_interval(1.3)
	for i in 3:
		tw.tween_callback(func() -> void:
			_fx_hart(ouder, (n.position + plek) * 0.5 + Vector3(0.0, 0.25, 0.0), 1)
			_geluid(["prop_kraai"]))
		tw.tween_property(n, "scale", Vector3(1.1, 0.9, 1.1), 0.15)
		tw.parallel().tween_property(ander, "scale", Vector3(1.1, 0.9, 1.1), 0.15)
		tw.tween_property(n, "scale", Vector3.ONE, 0.25)
		tw.parallel().tween_property(ander, "scale", Vector3.ONE, 0.25)
		tw.tween_interval(0.5)
	tw.tween_interval(_rng.randf_range(2.0, 5.0))
	tw.tween_callback(func() -> void:
		if is_instance_valid(ander):
			_vlieg(ander, plek + Vector3(3.5, 3.4, -1.5), 1.6, true))
	tw.tween_interval(1.7)
	_klaar(p, tw)


func _reageer_kraai_geschoten(p: Dictionary) -> void:
	# een schot uit de verte: de kraai ploft in een verenbal en valt van de paal;
	# na een tijd zit er een nieuwe
	var n: Node3D = p.node
	var thuis: Vector3 = p.thuis
	var ouder: Node3D = n.get_parent()
	var kleur: Color = p.get("kleur", Color(0.07, 0.065, 0.08))
	_geluid(["prop_schot", "musket"])
	_fx_knal(ouder, n.position + Vector3(0.0, 0.12, 0.0), 0.5)
	_fx_veren(ouder, n.position + Vector3(0.0, 0.12, 0.0), 16, kleur)
	var tw := n.create_tween()
	tw.tween_property(n, "rotation:x", deg_to_rad(95.0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(n, "position:y", 0.02, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(n, "position:x", thuis.x + 0.25, 0.4)
	tw.tween_interval(2.5)
	tw.tween_property(n, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
	tw.tween_callback(func() -> void: n.visible = false)
	tw.tween_interval(_rng.randf_range(14.0, 24.0))
	tw.tween_callback(func() -> void:
		n.position = thuis
		n.rotation.x = 0.0
		n.visible = true)
	tw.tween_property(n, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_klaar(p, tw)


func _reageer_kikker_kwaak(p: Dictionary) -> void:
	var n: Node3D = p.node
	var keel: Node3D = p.get("keel", null)
	_geluid(["prop_kikker"])
	_fx_tekst(n, Vector3(0.0, 0.25, 0.0), "Kwaak!", Color(0.8, 1.0, 0.7))
	var tw := n.create_tween()
	for i in 3:
		if keel != null:
			tw.tween_property(keel, "scale", Vector3(2.4, 2.4, 2.4), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(keel, "scale", Vector3.ONE, 0.22)
		else:
			tw.tween_property(n, "scale", Vector3(1.15, 0.9, 1.15), 0.18)
			tw.tween_property(n, "scale", Vector3.ONE, 0.22)
	tw.tween_callback(func() -> void: _rimpel(p.plas, n.position))
	_klaar(p, tw)


func _reageer_kikker_duik(p: Dictionary) -> void:
	# duikt de plas in (spetters), komt na een paar tellen aan de andere kant boven
	var n: Node3D = p.node
	var plas: Node3D = p.plas
	var thuis: Vector3 = p.thuis
	var alt: Vector3 = p.alt
	var doel: Vector3 = alt if n.position.distance_to(thuis) < 0.01 else thuis
	_geluid(["prop_kikker", "small_blood_splash"])
	var tw := n.create_tween()
	tw.tween_property(n, "position:y", n.position.y + 0.2, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "position:y", -0.12, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		_fx_spetters(plas, Vector3(n.position.x, 0.02, n.position.z), 8)
		_rimpel(plas, n.position))
	tw.tween_interval(_rng.randf_range(1.5, 3.0))
	tw.tween_callback(func() -> void:
		n.position = Vector3(doel.x, -0.12, doel.z)
		_rimpel(plas, doel))
	tw.tween_property(n, "position:y", doel.y, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_klaar(p, tw)


func _reageer_wegwijzer_draai(p: Dictionary) -> void:
	# de planken draaien een rondje en wijzen dan weer een kant op
	var n: Node3D = p.node
	_geluid(["prop_wegwijzer", "impact_wood"])
	var tw := n.create_tween()
	tw.tween_property(n, "rotation:y", n.rotation.y + TAU, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: _fx_tekst(n, Vector3(0.0, 1.15, 0.0), "Die kant?"))
	tw.tween_interval(0.4)
	_klaar(p, tw)


func _reageer_wegwijzer_kraai(p: Dictionary) -> void:
	# er landt een kraai op de paal, kijkt rond en vliegt weer weg
	var n: Node3D = p.node
	_land_vogel(n, Vector3(0.0, 0.96, 0.0), _rng.randf_range(3.0, 6.0))
	var tw := n.create_tween()
	tw.tween_interval(2.0)
	_klaar(p, tw)


func _reageer_glb_hop(p: Dictionary) -> void:
	var n: Node3D = p.inst
	_geluid(p.geluid)
	var tw := (p.node as Node3D).create_tween()
	tw.tween_property(n, "position:y", n.position.y + 0.18, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "position:y", n.position.y, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_klaar(p, tw)


func _reageer_glb_stof(p: Dictionary) -> void:
	var n: Node3D = p.inst
	_geluid(p.geluid)
	_fx_wolk(p.node, Vector3(0.0, 0.05, 0.0), Color(0.55, 0.48, 0.36), 0.8)
	var tw := (p.node as Node3D).create_tween()
	var basis: Vector3 = n.scale
	tw.tween_property(n, "scale", basis * Vector3(1.06, 0.94, 1.06), 0.08)
	tw.tween_property(n, "scale", basis, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_klaar(p, tw)


func _reageer_bewoner_hart(p: Dictionary) -> void:
	# een hartje boven het hoofd, en dan toch zijn actie
	var b: Node3D = p.node
	_fx_hart(b, Vector3(0.0, 0.75, 0.0), 2)
	_reageer_bewoner(p)


func _reageer_kampvuur(p: Dictionary) -> void:
	var vonken: GPUParticles3D = p.vonken
	_geluid(["prop_vuur"])
	vonken.restart()
	vonken.emitting = true
	var tw := (p.node as Node3D).create_tween()
	tw.tween_property(self, "_vuur_basis", 3.2, 0.12)
	tw.tween_property(self, "_vuur_basis", 1.3, 1.4).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void: p.bezig = false)


func _reageer_trommel(p: Dictionary) -> void:
	var n: Node3D = p.inst
	var basis: Vector3 = n.scale
	_geluid(["prop_trom", "val_drum"])
	var tw := (p.node as Node3D).create_tween()
	tw.tween_property(n, "scale", basis * Vector3(1.14, 0.78, 1.14), 0.07)
	tw.tween_property(n, "scale", basis, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: p.bezig = false)


func _reageer_ton(p: Dictionary) -> void:
	var n: Node3D = p.inst
	_geluid(["prop_ton", "impact_wood"])
	var tw := (p.node as Node3D).create_tween()
	var amp := 0.22
	for i in 4:
		tw.tween_property(n, "rotation:z", amp, 0.11).set_trans(Tween.TRANS_SINE)
		tw.tween_property(n, "rotation:z", -amp, 0.11).set_trans(Tween.TRANS_SINE)
		amp *= 0.55
	tw.tween_property(n, "rotation:z", 0.0, 0.1)
	tw.tween_callback(func() -> void: p.bezig = false)


func _reageer_hoorn(p: Dictionary) -> void:
	var n: Node3D = p.inst
	_geluid(["prop_hoorn", "val_horn"])
	var tw := (p.node as Node3D).create_tween()
	tw.tween_property(n, "rotation:x", -0.5, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.35)
	tw.tween_property(n, "rotation:x", 0.0, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: p.bezig = false)


func _reageer_bijl(p: Dictionary) -> void:
	var n: Node3D = p.bijl
	_geluid(["prop_bijl", "impact_wood"])
	if n == null:
		p.bezig = false
		return
	var basis: float = n.rotation.y
	var tw := (p.node as Node3D).create_tween()
	var amp := 0.16
	for i in 3:
		tw.tween_property(n, "rotation:y", basis + amp, 0.09)
		tw.tween_property(n, "rotation:y", basis - amp, 0.09)
		amp *= 0.5
	tw.tween_property(n, "rotation:y", basis, 0.08)
	tw.tween_callback(func() -> void: p.bezig = false)


func _reageer_kogels(p: Dictionary) -> void:
	var top: Node3D = p.top
	var rust: Vector3 = p.rust
	var zij: Vector3 = p.zij
	var tw := (p.node as Node3D).create_tween()
	tw.tween_method(func(t: float) -> void:
		top.position = rust.lerp(zij, t) + Vector3(0.0, 0.3 * sin(t * PI), 0.0), 0.0, 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void: _geluid(["prop_kogel", "impact_armor"]))
	tw.tween_property(top, "rotation:x", top.rotation.x + 2.4, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.2)
	tw.tween_method(func(t: float) -> void:
		top.position = zij.lerp(rust, t) + Vector3(0.0, 0.32 * sin(t * PI), 0.0), 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void: p.bezig = false)


func _reageer_tent(p: Dictionary) -> void:
	var lantaarn: Node3D = p.lantaarn
	var doek: Node3D = p.doek
	_geluid(["prop_lantaarn"])
	var tw := (p.node as Node3D).create_tween()
	if lantaarn != null:
		var amp := 0.55
		for i in 5:
			tw.tween_property(lantaarn, "rotation:z", amp, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(lantaarn, "rotation:z", -amp, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			amp *= 0.6
		tw.tween_property(lantaarn, "rotation:z", 0.0, 0.3)
	else:
		# tent zonder lantaarn: het doek trilt even
		var basis: Vector3 = doek.scale
		tw.tween_property(doek, "scale", basis * Vector3(1.03, 0.97, 1.03), 0.08)
		tw.tween_property(doek, "scale", basis, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: p.bezig = false)


func _reageer_kraai(p: Dictionary) -> void:
	var n: Node3D = p.node
	var thuis: Vector3 = p.thuis
	var weg := thuis + Vector3(-3.5, 3.4, -1.5)
	_geluid(["prop_kraai"])
	for v in p.vleugels:
		var vt := (v as Node3D).create_tween().set_loops(8)
		vt.tween_property(v, "rotation:z", signf((v as Node3D).position.x) * 0.9, 0.1)
		vt.tween_property(v, "rotation:z", signf((v as Node3D).position.x) * -0.5, 0.1)
	var tw := (p.node as Node3D).create_tween()
	tw.tween_property(n, "position", thuis + Vector3(0.0, 0.25, 0.0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "position", weg, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(n, "rotation:y", n.rotation.y - 1.2, 0.6)
	tw.tween_callback(func() -> void: n.visible = false)
	tw.tween_interval(_rng.randf_range(16.0, 28.0))
	tw.tween_callback(func() -> void:
		n.position = thuis
		n.scale = Vector3(0.05, 0.05, 0.05)
		n.visible = true)
	tw.tween_property(n, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: p.bezig = false)


func _reageer_kikker(p: Dictionary) -> void:
	var n: Node3D = p.node
	var thuis: Vector3 = p.thuis
	var alt: Vector3 = p.alt
	var doel: Vector3 = alt if n.position.distance_to(thuis) < 0.01 else thuis
	var van: Vector3 = n.position
	n.rotation.y = atan2(doel.x - van.x, doel.z - van.z)
	_geluid(["prop_kikker"])
	var tw := (p.node as Node3D).create_tween()
	tw.tween_method(func(t: float) -> void:
		n.position = van.lerp(doel, t) + Vector3(0.0, 0.22 * sin(t * PI), 0.0), 0.0, 1.0, 0.42).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void: _rimpel(p.plas, doel))
	tw.tween_interval(0.3)
	tw.tween_callback(func() -> void: p.bezig = false)


func _reageer_wegwijzer(p: Dictionary) -> void:
	var n: Node3D = p.node
	_geluid(["prop_wegwijzer", "impact_wood"])
	var basis: float = n.rotation.z
	var tw := (p.node as Node3D).create_tween()
	var amp := 0.12
	for i in 3:
		tw.tween_property(n, "rotation:z", basis + amp, 0.12).set_trans(Tween.TRANS_SINE)
		tw.tween_property(n, "rotation:z", basis - amp, 0.12).set_trans(Tween.TRANS_SINE)
		amp *= 0.5
	tw.tween_property(n, "rotation:z", basis, 0.1)
	tw.tween_callback(func() -> void: p.bezig = false)


## Kringetje in de plas dat uitdijt en vervaagt.
func _rimpel(plas: Node3D, waar: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.05
	tm.outer_radius = 0.07
	tm.rings = 24
	tm.ring_segments = 6
	ring.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.8, 0.85, 0.9, 0.55)
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = Vector3(waar.x, 0.02, waar.z)
	ring.scale = Vector3(0.4, 0.15, 0.4)
	plas.add_child(ring)
	var tw := ring.create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector3(3.2, 0.15, 3.2), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.9)
	tw.chain().tween_callback(ring.queue_free)


# ---------------------------------------------------------------- nieuwe props (11 september)

func _prop_root(naam: String, pos: Vector3, draai: float) -> Node3D:
	var root := Node3D.new()
	root.name = naam
	root.position = pos
	root.rotation.y = draai
	_props_root.add_child(root)
	return root


## Het houten toilethuisje met het hartje in de deur.
func _bouw_toilethuisje(pos: Vector3, draai: float) -> void:
	var root := _prop_root("Toilethuisje", pos, draai)
	var hout := Color(0.42, 0.31, 0.19)
	_mesh(_box(Vector3(0.6, 0.95, 0.6)), hout, root, Vector3(0.0, 0.475, 0.0))
	var dak := _mesh(PrismMesh.new(), Color(0.28, 0.2, 0.13), root, Vector3(0.0, 1.1, 0.0))
	(dak.mesh as PrismMesh).size = Vector3(0.78, 0.32, 0.72)
	dak.rotation.y = deg_to_rad(90.0)
	# de deur hangt aan een scharnier, zodat hij open kan
	var scharnier := Node3D.new()
	scharnier.position = Vector3(-0.16, 0.0, 0.305)
	root.add_child(scharnier)
	_mesh(_box(Vector3(0.32, 0.72, 0.03)), Color(0.55, 0.42, 0.26), scharnier, Vector3(0.16, 0.4, 0.0))
	_hart(scharnier, Vector3(0.16, 0.6, 0.025), 0.07, Color(0.09, 0.06, 0.05))
	_mesh(_bol(0.012), Color(0.2, 0.18, 0.15), scharnier, Vector3(0.28, 0.4, 0.02))
	var pijp := _mesh(_cilinder(0.03, 0.3), Color(0.22, 0.22, 0.22), root, Vector3(0.2, 1.3, -0.15))
	_registreer(root, 1.2, [_reageer_wc_bezet, _reageer_wc_stank, _reageer_wc_kip],
			{"scharnier": scharnier, "pijp": pijp.position, "tik_extra": _tik_deur})


func _reageer_wc_bezet(p: Dictionary) -> void:
	var sch: Node3D = p.scharnier
	_geluid(["prop_wc", "impact_wood"])
	var tw := (p.node as Node3D).create_tween()
	tw.tween_property(sch, "rotation:y", deg_to_rad(-35.0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: _fx_tekst(p.node, Vector3(0.0, 1.25, 0.4), "Bezet!", Color(1.0, 0.7, 0.6)))
	tw.tween_interval(0.35)
	tw.tween_property(sch, "rotation:y", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: _geluid(["impact_wood"]))
	_klaar(p, tw)


func _reageer_wc_stank(p: Dictionary) -> void:
	var pijp: Vector3 = p.pijp
	_geluid(["prop_wc"])
	_fx_wolk(p.node, pijp + Vector3(0.0, 0.18, 0.0), Color(0.55, 0.62, 0.42), 1.4)
	_fx_tekst(p.node, pijp + Vector3(0.0, 0.5, 0.0), "Poeh!", Color(0.8, 0.95, 0.6))
	var tw := (p.node as Node3D).create_tween()
	tw.tween_interval(1.8)
	_klaar(p, tw)


func _reageer_wc_kip(p: Dictionary) -> void:
	var root: Node3D = p.node
	var sch: Node3D = p.scharnier
	_geluid(["prop_kip", "impact_wood"])
	var tw := root.create_tween()
	tw.tween_property(sch, "rotation:y", deg_to_rad(-80.0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		var kip := _maak_kip(root, Vector3(0.0, 0.0, 0.35))
		_fx_veren(root, Vector3(0.0, 0.2, 0.4), 8, Color(0.93, 0.9, 0.84))
		_fx_tekst(root, Vector3(0.0, 1.25, 0.4), "Tok tok!", Color(1.0, 0.9, 0.7))
		_ren_weg(kip, Vector3(_rng.randf_range(-0.6, 0.6), 0.0, 1.0), 1.8))
	tw.tween_interval(1.0)
	tw.tween_property(sch, "rotation:y", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_klaar(p, tw)


## De molen: de wieken draaien met de wind mee (in _process).
func _bouw_molen(pos: Vector3, draai: float) -> void:
	var root := _prop_root("Molen", pos, draai)
	var romp := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.22
	cm.bottom_radius = 0.36
	cm.height = 1.4
	cm.radial_segments = 8
	romp.mesh = cm
	romp.material_override = _materiaal(Color(0.72, 0.64, 0.5)).duplicate()
	romp.position = Vector3(0.0, 0.7, 0.0)
	root.add_child(romp)
	_mesh(_kegel(0.3, 0.32), Color(0.3, 0.22, 0.14), root, Vector3(0.0, 1.56, 0.0))
	_mesh(_box(Vector3(0.16, 0.3, 0.03)), Color(0.3, 0.22, 0.14), root, Vector3(0.0, 0.15, 0.35))
	var wiekas := Node3D.new()
	wiekas.position = Vector3(0.0, 1.4, 0.34)
	root.add_child(wiekas)
	var naaf := _mesh(_cilinder(0.04, 0.14), Color(0.3, 0.22, 0.14), wiekas, Vector3.ZERO)
	naaf.rotation.x = deg_to_rad(90.0)
	for i in 4:
		var houder := Node3D.new()
		houder.rotation.z = deg_to_rad(90.0 * float(i))
		wiekas.add_child(houder)
		_mesh(_box(Vector3(0.025, 0.95, 0.025)), Color(0.3, 0.22, 0.14), houder, Vector3(0.0, 0.47, 0.0))
		_mesh(_box(Vector3(0.14, 0.75, 0.012)), Color(0.85, 0.8, 0.68), houder, Vector3(0.07, 0.55, 0.02))
	_wieken.append(wiekas)
	_registreer(root, 1.9, [_reageer_molen_hard, _reageer_molen_vogel, _reageer_molen_zak], {"wiekas": wiekas})


func _reageer_molen_hard(p: Dictionary) -> void:
	var wiekas: Node3D = p.wiekas
	_geluid(["prop_molen", "cannon_wheel_loose"])
	_fx_tekst(p.node, Vector3(0.0, 2.1, 0.3), "Krrrk...", Color(0.9, 0.85, 0.7))
	var tw := (p.node as Node3D).create_tween()
	tw.tween_method(func(v: float) -> void: _wiek_boost[wiekas] = v, 0.0, 5.0, 0.7).set_trans(Tween.TRANS_QUAD)
	tw.tween_interval(1.5)
	tw.tween_method(func(v: float) -> void: _wiek_boost[wiekas] = v, 5.0, 0.0, 3.0).set_trans(Tween.TRANS_SINE)
	_klaar(p, tw)


func _reageer_molen_vogel(p: Dictionary) -> void:
	_land_vogel(p.node, Vector3(0.0, 1.9, 0.0), _rng.randf_range(3.0, 6.0))
	var tw := (p.node as Node3D).create_tween()
	tw.tween_interval(2.0)
	_klaar(p, tw)


func _reageer_molen_zak(p: Dictionary) -> void:
	# een zak meel valt uit het deurtje, stofwolk
	var root: Node3D = p.node
	_geluid(["val_prop", "impact_wood"])
	var zak := _mesh(_box(Vector3(0.14, 0.2, 0.1)), Color(0.85, 0.8, 0.68), root, Vector3(0.0, 0.5, 0.4))
	var doel := Vector3(_rng.randf_range(-0.3, 0.3), 0.1, _rng.randf_range(0.6, 0.9))
	var tw := zak.create_tween()
	tw.tween_method(_boog.bind(zak, zak.position, doel, 0.2), 0.0, 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		_fx_wolk(root, doel, Color(0.9, 0.86, 0.75), 0.8)
		_fx_tekst(root, doel + Vector3(0.0, 0.4, 0.0), "Oeps!"))
	tw.tween_interval(3.0)
	tw.tween_property(zak, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
	tw.tween_callback(zak.queue_free)
	var tw2 := root.create_tween()
	tw2.tween_interval(1.0)
	_klaar(p, tw2)


## Een veldkanon op affuit.
func _bouw_kanon(pos: Vector3, draai: float) -> void:
	var root := _prop_root("Kanon", pos, draai)
	var ijzer := Color(0.18, 0.18, 0.2)
	var hout := Color(0.35, 0.26, 0.16)
	var affuit := _mesh(_box(Vector3(0.24, 0.1, 0.55)), hout, root, Vector3(0.0, 0.22, -0.05))
	affuit.rotation.x = deg_to_rad(-8.0)
	var wielen: Array = []
	for kant in [-1.0, 1.0]:
		var wiel := _mesh(_cilinder(0.19, 0.05), hout, root, Vector3(kant * 0.17, 0.19, 0.1))
		wiel.rotation.z = deg_to_rad(90.0)
		wielen.append(wiel)
	var loop_node := Node3D.new()
	loop_node.position = Vector3(0.0, 0.33, 0.05)
	loop_node.rotation.x = deg_to_rad(-10.0)
	root.add_child(loop_node)
	var loop := _mesh(_cilinder(0.06, 0.75), ijzer, loop_node, Vector3(0.0, 0.0, 0.12))
	loop.rotation.x = deg_to_rad(90.0)
	(loop.material_override as StandardMaterial3D).metallic = 0.5
	(loop.material_override as StandardMaterial3D).roughness = 0.5
	var mond := Vector3(0.0, 0.33 + sin(deg_to_rad(10.0)) * 0.5, 0.05 + cos(deg_to_rad(10.0)) * 0.5)
	_registreer(root, 0.5, [_reageer_kanon_schot, _reageer_kanon_wiel, _reageer_kanon_kogel], {"wielen": wielen, "mond": mond})
	_spel.maak_kanon(_props.back(), loop_node)   # vasthouden = richten op de kruitvaten (12 september)


func _reageer_kanon_schot(p: Dictionary) -> void:
	var root: Node3D = p.node
	var mond: Vector3 = p.mond
	_geluid(["prop_kanon", "cannon_heavy"])
	_fx_knal(root, mond, 1.3)
	_fx_wolk(root, mond + Vector3(0.0, 0.05, 0.15), Color(0.8, 0.78, 0.72), 1.6)
	var tw := root.create_tween()
	var z0 := root.position.z
	var x0 := root.position.x
	var terug := -0.22
	tw.tween_property(root, "position", root.position + Vector3(-sin(root.rotation.y) * terug, 0.0, -cos(root.rotation.y) * terug), 0.08)
	tw.tween_property(root, "position", Vector3(x0, root.position.y, z0), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_klaar(p, tw)


func _reageer_kanon_wiel(p: Dictionary) -> void:
	_geluid(["cannon_wheel_loose", "impact_wood"])
	var tw := (p.node as Node3D).create_tween()
	for wiel in p.wielen:
		var w: Node3D = wiel
		var amp := 0.18
		for i in 3:
			tw.tween_property(w, "rotation:x", amp, 0.12).set_trans(Tween.TRANS_SINE)
			tw.tween_property(w, "rotation:x", -amp, 0.12).set_trans(Tween.TRANS_SINE)
			amp *= 0.5
		tw.tween_property(w, "rotation:x", 0.0, 0.1)
	_klaar(p, tw)


func _reageer_kanon_kogel(p: Dictionary) -> void:
	# een kogel rolt uit de loop en valt met een klap op de grond
	var root: Node3D = p.node
	var mond: Vector3 = p.mond
	var kogel := _mesh(_bol(0.055), Color(0.16, 0.16, 0.17), root, mond)
	(kogel.material_override as StandardMaterial3D).metallic = 0.6
	var doel := Vector3(_rng.randf_range(-0.2, 0.2), 0.055, mond.z + _rng.randf_range(0.3, 0.6))
	var tw := kogel.create_tween()
	tw.tween_method(_boog.bind(kogel, mond, doel, 0.05), 0.0, 1.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		_geluid(["prop_kogel", "impact_armor"])
		_fx_wolk(root, doel, Color(0.55, 0.48, 0.36), 0.5))
	tw.tween_property(kogel, "position:z", doel.z + 0.4, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(kogel, "rotation:x", 5.0, 0.9)
	tw.tween_interval(2.5)
	tw.tween_property(kogel, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
	tw.tween_callback(kogel.queue_free)
	var tw2 := root.create_tween()
	tw2.tween_interval(1.4)
	_klaar(p, tw2)


## Een waterput met dakje en emmer.
func _bouw_put(pos: Vector3, draai: float) -> void:
	var root := _prop_root("Put", pos, draai)
	var steen := Color(0.52, 0.5, 0.46)
	_mesh(_cilinder(0.3, 0.32), steen, root, Vector3(0.0, 0.16, 0.0))
	_mesh(_cilinder(0.24, 0.02), Color(0.08, 0.1, 0.12), root, Vector3(0.0, 0.33, 0.0))
	for kant in [-1.0, 1.0]:
		_mesh(_box(Vector3(0.05, 0.75, 0.05)), Color(0.36, 0.26, 0.16), root, Vector3(kant * 0.28, 0.65, 0.0))
	var dak := _mesh(PrismMesh.new(), Color(0.28, 0.2, 0.13), root, Vector3(0.0, 1.12, 0.0))
	(dak.mesh as PrismMesh).size = Vector3(0.8, 0.22, 0.5)
	var emmer := Node3D.new()
	emmer.position = Vector3(0.0, 0.55, 0.0)
	root.add_child(emmer)
	_mesh(_cilinder(0.006, 0.45), Color(0.6, 0.55, 0.4), emmer, Vector3(0.0, 0.3, 0.0))
	_mesh(_cilinder(0.07, 0.1), Color(0.36, 0.26, 0.16), emmer, Vector3(0.0, 0.05, 0.0))
	_registreer(root, 1.1, [_reageer_put_emmer, _reageer_put_kikker, _reageer_put_echo], {"emmer": emmer})


func _reageer_put_emmer(p: Dictionary) -> void:
	var emmer: Node3D = p.emmer
	var root: Node3D = p.node
	_geluid(["prop_emmer", "cannon_wheel_loose"])
	var tw := root.create_tween()
	tw.tween_property(emmer, "position:y", 0.02, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		_fx_spetters(root, Vector3(0.0, 0.36, 0.0), 7)
		_fx_tekst(root, Vector3(0.0, 0.9, 0.0), "Plons!", Color(0.7, 0.85, 1.0)))
	tw.tween_interval(0.8)
	tw.tween_property(emmer, "position:y", 0.55, 1.6).set_trans(Tween.TRANS_SINE)
	_klaar(p, tw)


func _reageer_put_kikker(p: Dictionary) -> void:
	var root: Node3D = p.node
	_geluid(["prop_kikker"])
	var kik := Node3D.new()
	kik.position = Vector3(0.0, 0.3, 0.0)
	root.add_child(kik)
	var lijf := _mesh(_bol(0.05), Color(0.36, 0.52, 0.22), kik, Vector3.ZERO)
	lijf.scale = Vector3(1.0, 0.75, 1.25)
	_fx_spetters(root, Vector3(0.0, 0.36, 0.0), 6)
	var doel := Vector3(_rng.randf_range(-0.6, 0.6), 0.03, _rng.randf_range(0.5, 0.8))
	var tw := kik.create_tween()
	tw.tween_method(_boog.bind(kik, kik.position, doel, 0.45), 0.0, 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void: _fx_tekst(root, doel + Vector3(0.0, 0.25, 0.0), "Kwaak!", Color(0.8, 1.0, 0.7)))
	var doel2 := doel + Vector3(_rng.randf_range(-0.4, 0.4), 0.0, 0.7)
	tw.tween_method(_boog.bind(kik, doel, doel2, 0.3), 0.0, 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(kik, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
	tw.tween_callback(kik.queue_free)
	var tw2 := root.create_tween()
	tw2.tween_interval(1.2)
	_klaar(p, tw2)


func _reageer_put_echo(p: Dictionary) -> void:
	var root: Node3D = p.node
	_fx_tekst(root, Vector3(0.0, 0.7, 0.0), "Hallo?", Color(1.0, 0.95, 0.8))
	var tw := root.create_tween()
	tw.tween_interval(0.9)
	tw.tween_callback(func() -> void: _fx_tekst(root, Vector3(0.1, 0.5, 0.0), "...hallo?", Color(0.8, 0.78, 0.7)))
	tw.tween_interval(0.9)
	tw.tween_callback(func() -> void: _fx_tekst(root, Vector3(0.2, 0.35, 0.0), "...lo?", Color(0.6, 0.58, 0.55)))
	tw.tween_interval(0.8)
	_klaar(p, tw)


## Een houten kruis met een hoed erop: een gevallen kameraad.
func _bouw_kruis(pos: Vector3, draai: float) -> void:
	var root := _prop_root("Kruis", pos, draai)
	var hout := Color(0.4, 0.3, 0.19)
	_mesh(_box(Vector3(0.06, 0.7, 0.06)), hout, root, Vector3(0.0, 0.35, 0.0))
	_mesh(_box(Vector3(0.4, 0.06, 0.06)), hout, root, Vector3(0.0, 0.52, 0.0))
	var hoed := Node3D.new()
	hoed.position = Vector3(0.0, 0.7, 0.0)
	root.add_child(hoed)
	_mesh(_cilinder(0.13, 0.02), Color(0.15, 0.13, 0.12), hoed, Vector3.ZERO)
	_mesh(_cilinder(0.08, 0.14), Color(0.15, 0.13, 0.12), hoed, Vector3(0.0, 0.07, 0.0))
	_registreer(root, 0.85, [_reageer_kruis_hoed, _reageer_kruis_vogel, _reageer_kruis_bloemen], {"hoed": hoed})


func _reageer_kruis_hoed(p: Dictionary) -> void:
	var hoed: Node3D = p.hoed
	var thuis: Vector3 = hoed.position
	_geluid(["hat_hit_floor_", "val_prop"])
	var doel := Vector3(_rng.randf_range(-0.6, 0.6), 0.0, _rng.randf_range(0.2, 0.6))
	var tw := (p.node as Node3D).create_tween()
	tw.tween_method(_boog.bind(hoed, thuis, doel, 0.35), 0.0, 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(hoed, "rotation:z", _rng.randf_range(-1.0, 1.0), 0.7)
	tw.tween_interval(3.0)
	tw.tween_method(_boog.bind(hoed, doel, thuis, 0.45), 0.0, 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(hoed, "rotation:z", 0.0, 0.6)
	_klaar(p, tw)


func _reageer_kruis_vogel(p: Dictionary) -> void:
	_land_vogel(p.node, Vector3(0.0, 0.86, 0.0), _rng.randf_range(3.0, 6.0))
	var tw := (p.node as Node3D).create_tween()
	tw.tween_interval(2.0)
	_klaar(p, tw)


func _reageer_kruis_bloemen(p: Dictionary) -> void:
	# iemand legt bloemen neer
	var root: Node3D = p.node
	for i in 4:
		var kleur: Color = [Color(0.95, 0.9, 0.85), Color(0.95, 0.8, 0.25), Color(0.85, 0.3, 0.3), Color(0.7, 0.5, 0.85)][i]
		var b := _mesh(_bol(0.035), kleur, root, Vector3(_rng.randf_range(-0.14, 0.14), 0.04, _rng.randf_range(0.08, 0.2)))
		b.scale = Vector3(0.01, 0.01, 0.01)
		var bt := b.create_tween()
		bt.tween_interval(0.15 * float(i))
		bt.tween_property(b, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		bt.tween_interval(20.0)
		bt.tween_property(b, "scale", Vector3(0.01, 0.01, 0.01), 0.5)
		bt.tween_callback(b.queue_free)
	_fx_hart(root, Vector3(0.0, 0.9, 0.0), 2)
	var tw := root.create_tween()
	tw.tween_interval(1.5)
	_klaar(p, tw)


## Een palm (Egypte).
func _bouw_palm(pos: Vector3, draai: float) -> void:
	var root := _prop_root("Palm", pos, draai)
	var stam := Color(0.5, 0.38, 0.24)
	for i in 4:
		var deel := _mesh(_cilinder(0.06 - 0.008 * float(i), 0.4), stam, root, Vector3(0.05 * float(i) * float(i) * 0.5, 0.2 + 0.38 * float(i), 0.0))
		deel.rotation.z = deg_to_rad(-6.0 * float(i))
	var kroon := Node3D.new()
	kroon.position = Vector3(0.36, 1.66, 0.0)
	root.add_child(kroon)
	for i in 6:
		var blad := _mesh(_bol(0.1), Color(0.3, 0.52, 0.22), kroon, Vector3.ZERO)
		blad.scale = Vector3(1.0, 0.25, 4.0)
		blad.rotation.y = deg_to_rad(60.0 * float(i))
		blad.rotation.x = deg_to_rad(28.0)
		blad.position = Vector3(sin(deg_to_rad(60.0 * float(i))) * 0.3, 0.0, cos(deg_to_rad(60.0 * float(i))) * 0.3)
	var kokos: Array = []
	for i in 3:
		kokos.append(_mesh(_bol(0.045), Color(0.4, 0.28, 0.16), kroon, Vector3(_rng.randf_range(-0.08, 0.08), -0.05, _rng.randf_range(-0.08, 0.08))))
	_registreer(root, 1.8, [_reageer_palm_wieg, _reageer_palm_kokos, _reageer_palm_vogel], {"kroon": kroon, "kokos": kokos})


func _reageer_palm_wieg(p: Dictionary) -> void:
	var kroon: Node3D = p.kroon
	var tw := (p.node as Node3D).create_tween()
	var amp := 0.14
	for i in 4:
		tw.tween_property(kroon, "rotation:z", amp, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(kroon, "rotation:z", -amp, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		amp *= 0.6
	tw.tween_property(kroon, "rotation:z", 0.0, 0.3)
	_klaar(p, tw)


func _reageer_palm_kokos(p: Dictionary) -> void:
	var root: Node3D = p.node
	var kroon: Node3D = p.kroon
	var lijst: Array = p.kokos
	var k: Node3D = lijst[_rng.randi() % lijst.size()]
	var start: Vector3 = kroon.position + k.position
	var thuis: Vector3 = k.position
	k.reparent(root, false)
	k.position = start
	var doel := Vector3(start.x + _rng.randf_range(-0.3, 0.3), 0.045, _rng.randf_range(0.2, 0.6))
	var tw := root.create_tween()
	tw.tween_method(_boog.bind(k, start, doel, 0.05), 0.0, 1.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		_geluid(["prop_kokos", "impact_wood"])
		_fx_tekst(root, doel + Vector3(0.0, 0.3, 0.0), "Bonk!", Color(1.0, 0.85, 0.6)))
	tw.tween_property(k, "position:y", 0.2, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(k, "position:y", 0.045, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(3.0)
	tw.tween_callback(func() -> void:
		k.reparent(kroon, false)
		k.position = thuis
		k.scale = Vector3(0.01, 0.01, 0.01))
	tw.tween_property(k, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_klaar(p, tw)


func _reageer_palm_vogel(p: Dictionary) -> void:
	var kroon: Node3D = p.kroon
	_land_vogel(p.node, kroon.position + Vector3(0.0, 0.1, 0.0), _rng.randf_range(2.5, 5.0), Color(0.85, 0.2, 0.15))
	var tw := (p.node as Node3D).create_tween()
	tw.tween_interval(2.0)
	_klaar(p, tw)


## Piramide en sfinx (Egypte 1798).
func _bouw_piramide(pos: Vector3, maat: float) -> void:
	var root := _prop_root("Piramide", pos, deg_to_rad(45.0))
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = maat
	m.height = maat * 0.85
	m.radial_segments = 4
	m.rings = 1
	var pir := _mesh(m, Color(0.8, 0.7, 0.5), root, Vector3(0.0, maat * 0.425, 0.0))
	pir.rotation.y = 0.0
	_registreer(root, maat * 0.85, [_reageer_piramide_zand, _reageer_piramide_vraag, _reageer_piramide_kever], {"maat": maat})


func _reageer_piramide_zand(p: Dictionary) -> void:
	var maat: float = p.maat
	_fx_wolk(p.node, Vector3(maat * 0.5, 0.05, maat * 0.5), Color(0.85, 0.75, 0.55), 1.2)
	_geluid(["prop_zand"])
	var tw := (p.node as Node3D).create_tween()
	tw.tween_interval(1.5)
	_klaar(p, tw)


func _reageer_piramide_vraag(p: Dictionary) -> void:
	var maat: float = p.maat
	_fx_tekst(p.node, Vector3(0.0, maat * 0.9, 0.0), "?", Color(1.0, 0.9, 0.6))
	var tw := (p.node as Node3D).create_tween()
	tw.tween_interval(1.5)
	_klaar(p, tw)


func _reageer_piramide_kever(p: Dictionary) -> void:
	# een scarabee kruipt uit het zand en schiet weg
	var root: Node3D = p.node
	var maat: float = p.maat
	var kever := _mesh(_bol(0.035), Color(0.12, 0.14, 0.1), root, Vector3(maat * 0.55, 0.03, maat * 0.55))
	kever.scale = Vector3(1.0, 0.6, 1.3)
	var doel := kever.position + Vector3(_rng.randf_range(0.6, 1.2), 0.0, _rng.randf_range(0.4, 1.0))
	var tw := kever.create_tween()
	tw.tween_property(kever, "position", doel, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(kever, "scale", Vector3(0.01, 0.01, 0.01), 0.2)
	tw.tween_callback(kever.queue_free)
	var tw2 := root.create_tween()
	tw2.tween_interval(1.0)
	_klaar(p, tw2)


func _bouw_sfinx(pos: Vector3, draai: float) -> void:
	var root := _prop_root("Sfinx", pos, draai)
	var zand := Color(0.74, 0.64, 0.46)
	_mesh(_box(Vector3(0.5, 0.24, 0.9)), zand, root, Vector3(0.0, 0.12, 0.0))
	for kant in [-1.0, 1.0]:
		_mesh(_box(Vector3(0.13, 0.12, 0.4)), zand, root, Vector3(kant * 0.18, 0.06, 0.55))
	var kop := Node3D.new()
	kop.position = Vector3(0.0, 0.34, 0.32)
	root.add_child(kop)
	_mesh(_bol(0.15), zand, kop, Vector3.ZERO)
	_mesh(_box(Vector3(0.34, 0.3, 0.1)), Color(0.66, 0.56, 0.38), kop, Vector3(0.0, 0.0, -0.08))
	_registreer(root, 0.5, [_reageer_piramide_vraag, _reageer_sfinx_zand, _reageer_sfinx_kijk], {"kop": kop, "maat": 0.6})


func _reageer_sfinx_zand(p: Dictionary) -> void:
	_fx_wolk(p.node, Vector3(0.0, 0.05, 0.6), Color(0.85, 0.75, 0.55), 0.9)
	var tw := (p.node as Node3D).create_tween()
	tw.tween_interval(1.5)
	_klaar(p, tw)


func _reageer_sfinx_kijk(p: Dictionary) -> void:
	var kop: Node3D = p.kop
	var tw := (p.node as Node3D).create_tween()
	tw.tween_property(kop, "rotation:y", 0.5, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(1.0)
	tw.tween_callback(func() -> void: _fx_tekst(p.node, Vector3(0.0, 0.7, 0.4), "...", Color(0.9, 0.85, 0.7)))
	tw.tween_property(kop, "rotation:y", 0.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_klaar(p, tw)


## Een steiger met een sloep (de rivierhaven; het water is een scene-extra).
func _bouw_steiger_boot(pos: Vector3, draai: float) -> void:
	var root := _prop_root("Steiger", pos, draai)
	var hout := Color(0.4, 0.3, 0.19)
	for i in 4:
		for kant in [-1.0, 1.0]:
			_mesh(_cilinder(0.035, 0.5), hout, root, Vector3(kant * 0.26, 0.2, -0.6 * float(i)))
	for i in 7:
		_mesh(_box(Vector3(0.62, 0.03, 0.24)), Color(0.5, 0.4, 0.27), root, Vector3(0.0, 0.32, 0.12 - 0.3 * float(i)))
	var boot := Node3D.new()
	boot.position = Vector3(0.75, 0.06, -1.1)
	boot.rotation.y = deg_to_rad(15.0)
	root.add_child(boot)
	var romp := _mesh(_bol(0.3), Color(0.32, 0.24, 0.15), boot, Vector3.ZERO)
	romp.scale = Vector3(0.9, 0.35, 2.0)
	_mesh(_box(Vector3(0.44, 0.03, 0.08)), Color(0.5, 0.4, 0.27), boot, Vector3(0.0, 0.08, 0.1))
	_mesh(_box(Vector3(0.44, 0.03, 0.08)), Color(0.5, 0.4, 0.27), boot, Vector3(0.0, 0.08, -0.25))
	var riemen: Array = []
	for kant in [-1.0, 1.0]:
		var riem := _mesh(_cilinder(0.012, 0.7), Color(0.55, 0.45, 0.3), boot, Vector3(kant * 0.3, 0.1, 0.0))
		riem.rotation.z = deg_to_rad(kant * 70.0)
		riemen.append(riem)
	_registreer(root, 0.4, [_reageer_boot_schommel, _reageer_boot_riem, _reageer_boot_vis], {"boot": boot, "riemen": riemen})


func _reageer_boot_schommel(p: Dictionary) -> void:
	var boot: Node3D = p.boot
	_geluid(["prop_boot", "impact_wood"])
	var tw := (p.node as Node3D).create_tween()
	var amp := 0.2
	for i in 4:
		tw.tween_property(boot, "rotation:z", amp, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(boot, "rotation:z", -amp, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		amp *= 0.6
	tw.tween_property(boot, "rotation:z", 0.0, 0.3)
	_klaar(p, tw)


func _reageer_boot_riem(p: Dictionary) -> void:
	var root: Node3D = p.node
	var boot: Node3D = p.boot
	_geluid(["prop_plons", "small_blood_splash"])
	var tw := root.create_tween()
	for riem in p.riemen:
		var r: Node3D = riem
		var basis: float = r.rotation.z
		tw.tween_property(r, "rotation:z", basis + signf(basis) * 0.5, 0.3).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(func() -> void: _fx_spetters(root, boot.position + Vector3(signf(basis) * 0.55, 0.0, 0.0), 6))
		tw.tween_property(r, "rotation:z", basis, 0.4).set_trans(Tween.TRANS_SINE)
	_klaar(p, tw)


func _reageer_boot_vis(p: Dictionary) -> void:
	# een vis springt naast de boot uit het water
	var root: Node3D = p.node
	var boot: Node3D = p.boot
	var start := boot.position + Vector3(-0.7, -0.05, 0.4)
	var vis := _mesh(_bol(0.05), Color(0.75, 0.8, 0.85), root, start)
	vis.scale = Vector3(0.6, 0.6, 1.6)
	(vis.material_override as StandardMaterial3D).metallic = 0.6
	(vis.material_override as StandardMaterial3D).roughness = 0.3
	var doel := start + Vector3(-0.5, 0.0, 0.3)
	_fx_spetters(root, start, 5)
	var tw := vis.create_tween()
	tw.tween_method(_boog.bind(vis, start, doel, 0.6), 0.0, 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(vis, "rotation:x", -3.0, 0.7)
	tw.tween_callback(func() -> void:
		_geluid(["prop_plons", "small_blood_splash"])
		_fx_spetters(root, doel, 8)
		_fx_tekst(root, doel + Vector3(0.0, 0.35, 0.0), "Plons!", Color(0.7, 0.85, 1.0)))
	tw.tween_callback(vis.queue_free)
	var tw2 := root.create_tween()
	tw2.tween_interval(1.2)
	_klaar(p, tw2)


## Een vervallen muur met een boog (kapel, hoeve).
func _bouw_ruine(pos: Vector3, draai: float) -> void:
	var root := _prop_root("Ruine", pos, draai)
	var steen := Color(0.55, 0.53, 0.48)
	var hoogtes: Array = [0.9, 0.55, 0.35, 0.7]
	for i in 4:
		var h: float = hoogtes[i]
		var tint := Color(steen.r + _rng.randf_range(-0.05, 0.05), steen.g + _rng.randf_range(-0.05, 0.05), steen.b + _rng.randf_range(-0.05, 0.05))
		_mesh(_box(Vector3(0.42, h, 0.22)), tint, root, Vector3(-0.85 + 0.44 * float(i), h * 0.5, 0.0))
	for kant in [-1.0, 1.0]:
		_mesh(_box(Vector3(0.2, 0.95, 0.24)), steen, root, Vector3(1.1 + kant * 0.3, 0.475, 0.0))
	var top := _mesh(_box(Vector3(0.82, 0.2, 0.26)), steen, root, Vector3(1.1, 1.05, 0.0))
	_registreer(root, 1.1, [_reageer_ruine_steen, _reageer_ruine_uil, _reageer_ruine_stof], {"top": top})


func _reageer_ruine_steen(p: Dictionary) -> void:
	var root: Node3D = p.node
	_geluid(["prop_steen", "impact_wood"])
	var steen := _mesh(_box(Vector3(0.16, 0.12, 0.14)), Color(0.55, 0.53, 0.48), root, Vector3(1.1, 1.2, 0.0))
	var doel := Vector3(1.1 + _rng.randf_range(-0.5, 0.5), 0.06, _rng.randf_range(0.3, 0.6))
	var tw := steen.create_tween()
	tw.tween_method(_boog.bind(steen, steen.position, doel, 0.1), 0.0, 1.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(steen, "rotation", Vector3(1.0, 0.5, 1.5), 0.5)
	tw.tween_callback(func() -> void: _fx_wolk(root, doel, Color(0.6, 0.58, 0.52), 0.6))
	tw.tween_interval(4.0)
	tw.tween_property(steen, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
	tw.tween_callback(steen.queue_free)
	var tw2 := root.create_tween()
	tw2.tween_interval(1.0)
	_klaar(p, tw2)


func _reageer_ruine_uil(p: Dictionary) -> void:
	# twee gele ogen in het donker van de boog, en een oehoe
	var root: Node3D = p.node
	_geluid(["prop_uil"])
	var ogen: Array = []
	for kant in [-1.0, 1.0]:
		var oog := _mesh(_bol(0.025), Color(1.0, 0.85, 0.2), root, Vector3(1.1 + kant * 0.05, 0.62, -0.05))
		var om := oog.material_override as StandardMaterial3D
		om.emission_enabled = true
		om.emission = Color(1.0, 0.8, 0.2)
		om.emission_energy_multiplier = 2.0
		oog.scale = Vector3(0.01, 0.01, 0.01)
		ogen.append(oog)
	var tw := root.create_tween()
	for oog in ogen:
		tw.parallel().tween_property(oog, "scale", Vector3.ONE, 0.3)
	tw.chain().tween_callback(func() -> void: _fx_tekst(root, Vector3(1.1, 1.3, 0.0), "Oehoe", Color(0.9, 0.85, 0.7)))
	tw.tween_interval(2.5)
	for oog in ogen:
		tw.parallel().tween_property(oog, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
	tw.chain().tween_callback(func() -> void:
		for oog in ogen:
			(oog as Node).queue_free())
	_klaar(p, tw)


func _reageer_ruine_stof(p: Dictionary) -> void:
	var top: Node3D = p.top
	_fx_wolk(p.node, top.position + Vector3(0.0, -0.3, 0.2), Color(0.6, 0.58, 0.52), 1.0)
	var tw := (p.node as Node3D).create_tween()
	var amp := 0.06
	for i in 3:
		tw.tween_property(top, "rotation:z", amp, 0.1)
		tw.tween_property(top, "rotation:z", -amp, 0.1)
		amp *= 0.5
	tw.tween_property(top, "rotation:z", 0.0, 0.1)
	_klaar(p, tw)


## Een fontein (marktplein) met een spuitende straal.
func _bouw_fontein(pos: Vector3) -> void:
	var root := _prop_root("Fontein", pos, 0.0)
	var steen := Color(0.6, 0.58, 0.54)
	_mesh(_cilinder(0.5, 0.14), steen, root, Vector3(0.0, 0.07, 0.0))
	var water := _mesh(_cilinder(0.44, 0.02), Color(0.36, 0.5, 0.6), root, Vector3(0.0, 0.14, 0.0))
	(water.material_override as StandardMaterial3D).roughness = 0.15
	(water.material_override as StandardMaterial3D).metallic_specular = 0.9
	_mesh(_cilinder(0.06, 0.52), steen, root, Vector3(0.0, 0.4, 0.0))
	_mesh(_cilinder(0.18, 0.06), steen, root, Vector3(0.0, 0.68, 0.0))
	var straal := _deeltjes(36, 1.1, Vector3(0.0, 1.0, 0.0), 22.0, 0.9, 1.4, Vector3(0.0, -2.8, 0.0), 0.02, 0.035,
			[Color(0.8, 0.9, 1.0, 0.0), Color(0.8, 0.9, 1.0, 0.9), Color(0.7, 0.85, 1.0, 0.7), Color(0.7, 0.85, 1.0, 0.0)],
			[0.0, 0.1, 0.8, 1.0], false, 0.03)
	straal.position = Vector3(0.0, 0.72, 0.0)
	root.add_child(straal)
	_registreer(root, 0.8, [_reageer_fontein_plons, _reageer_fontein_munt, _reageer_fontein_vogel], {"water": water})


func _reageer_fontein_plons(p: Dictionary) -> void:
	var root: Node3D = p.node
	_geluid(["prop_plons", "small_blood_splash"])
	_fx_spetters(root, Vector3(_rng.randf_range(-0.2, 0.2), 0.16, _rng.randf_range(-0.2, 0.2)), 9)
	_rimpel(root, Vector3(0.0, 0.14, 0.0))
	var tw := root.create_tween()
	tw.tween_interval(1.0)
	_klaar(p, tw)


func _reageer_fontein_munt(p: Dictionary) -> void:
	# een muntje in de fontein: een wens
	var root: Node3D = p.node
	var munt := _mesh(_cilinder(0.03, 0.006), Color(0.95, 0.8, 0.3), root, Vector3(0.7, 0.5, 0.4))
	var mm := munt.material_override as StandardMaterial3D
	mm.metallic = 0.8
	mm.roughness = 0.3
	var doel := Vector3(_rng.randf_range(-0.25, 0.25), 0.15, _rng.randf_range(-0.25, 0.25))
	var tw := munt.create_tween()
	tw.tween_method(_boog.bind(munt, munt.position, doel, 0.35), 0.0, 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(munt, "rotation:x", 8.0, 0.6)
	tw.tween_callback(func() -> void:
		_geluid(["prop_munt", "ui_click"])
		_fx_tekst(root, doel + Vector3(0.0, 0.35, 0.0), "Plink!", Color(1.0, 0.9, 0.5))
		_fx_hart(root, doel + Vector3(0.0, 0.5, 0.0), 1)
		_rimpel(root, doel))
	tw.tween_property(munt, "scale", Vector3(0.01, 0.01, 0.01), 0.6)
	tw.tween_callback(munt.queue_free)
	var tw2 := root.create_tween()
	tw2.tween_interval(1.2)
	_klaar(p, tw2)


func _reageer_fontein_vogel(p: Dictionary) -> void:
	_land_vogel(p.node, Vector3(0.42, 0.16, 0.0), _rng.randf_range(2.5, 5.0))
	var tw := (p.node as Node3D).create_tween()
	tw.tween_interval(2.0)
	_klaar(p, tw)


## Een marktkraam: het zeil in de kleur van het team.
func _bouw_marktkraam(pos: Vector3, draai: float) -> void:
	var root := _prop_root("Marktkraam", pos, draai)
	var hout := Color(0.45, 0.34, 0.21)
	for kant in [-1.0, 1.0]:
		for diep in [-0.2, 0.2]:
			_mesh(_box(Vector3(0.05, 0.5, 0.05)), hout, root, Vector3(kant * 0.4, 0.25, diep))
	_mesh(_box(Vector3(0.9, 0.05, 0.5)), Color(0.55, 0.43, 0.28), root, Vector3(0.0, 0.52, 0.0))
	for kant in [-1.0, 1.0]:
		_mesh(_box(Vector3(0.04, 1.15, 0.04)), hout, root, Vector3(kant * 0.44, 0.575, -0.22))
	var team := _team_op(pos)
	var zeilkleur := Color(0.75, 0.2, 0.2) if team == "red" else Color(0.25, 0.4, 0.75)
	var zeil := _mesh(_box(Vector3(1.0, 0.03, 0.7)), zeilkleur, root, Vector3(0.0, 1.16, 0.08))
	zeil.rotation.x = deg_to_rad(12.0)
	var waar: Array = []
	for i in 6:
		var kleur := Color(0.8, 0.18, 0.12) if i % 2 == 0 else Color(0.82, 0.68, 0.45)
		waar.append(_mesh(_bol(0.05), kleur, root, Vector3(-0.3 + 0.12 * float(i), 0.6, _rng.randf_range(-0.12, 0.12))))
	_registreer(root, 1.2, [_reageer_kraam_appel, _reageer_kraam_zeil, _reageer_kraam_roep], {"zeil": zeil, "waar": waar})


func _reageer_kraam_appel(p: Dictionary) -> void:
	var root: Node3D = p.node
	var lijst: Array = p.waar
	var a: Node3D = lijst[_rng.randi() % lijst.size()]
	var thuis: Vector3 = a.position
	_geluid(["val_prop"])
	var doel := Vector3(thuis.x + _rng.randf_range(-0.3, 0.3), 0.05, _rng.randf_range(0.5, 0.9))
	var tw := root.create_tween()
	tw.tween_method(_boog.bind(a, thuis, doel, 0.15), 0.0, 1.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: _fx_tekst(root, Vector3(0.0, 1.5, 0.2), "He!", Color(1.0, 0.85, 0.6)))
	tw.tween_property(a, "position:z", doel.z + 0.3, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.5)
	tw.tween_property(a, "position", thuis, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_klaar(p, tw)


func _reageer_kraam_zeil(p: Dictionary) -> void:
	var zeil: Node3D = p.zeil
	var tw := (p.node as Node3D).create_tween()
	var basis: float = zeil.rotation.x
	for i in 4:
		tw.tween_property(zeil, "rotation:x", basis + 0.25, 0.18).set_trans(Tween.TRANS_SINE)
		tw.tween_property(zeil, "rotation:x", basis - 0.1, 0.18).set_trans(Tween.TRANS_SINE)
	tw.tween_property(zeil, "rotation:x", basis, 0.2)
	_klaar(p, tw)


func _reageer_kraam_roep(p: Dictionary) -> void:
	var root: Node3D = p.node
	_geluid(["prop_koopman"])
	var teksten: Array = ["Verse appels!", "Twee voor een stuiver!", "Brood! Vers brood!"]
	_fx_tekst(root, Vector3(0.0, 1.5, 0.2), String(teksten[_rng.randi() % teksten.size()]), Color(1.0, 0.9, 0.7))
	var tw := root.create_tween()
	for w in p.waar:
		tw.parallel().tween_property(w, "position:y", 0.68, 0.15).set_delay(_rng.randf_range(0.0, 0.2))
	tw.chain()
	for w in p.waar:
		tw.parallel().tween_property(w, "position:y", 0.6, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(0.8)
	_klaar(p, tw)


## Een sneeuwpop (winterkamp).
func _bouw_sneeuwpop(pos: Vector3, draai: float) -> void:
	var root := _prop_root("Sneeuwpop", pos, draai)
	var wit := Color(0.94, 0.95, 0.97)
	var lijf := Node3D.new()
	root.add_child(lijf)
	_mesh(_bol(0.22), wit, lijf, Vector3(0.0, 0.2, 0.0))
	_mesh(_bol(0.17), wit, lijf, Vector3(0.0, 0.5, 0.0))
	_mesh(_bol(0.12), wit, lijf, Vector3(0.0, 0.74, 0.0))
	for kant in [-1.0, 1.0]:
		_mesh(_bol(0.02), Color(0.1, 0.1, 0.1), lijf, Vector3(kant * 0.045, 0.78, 0.1))
	var neus := _mesh(_kegel(0.02, 0.12), Color(0.95, 0.5, 0.1), lijf, Vector3(0.0, 0.73, 0.17))
	neus.rotation.x = deg_to_rad(90.0)
	for kant in [-1.0, 1.0]:
		var arm := _mesh(_cilinder(0.012, 0.35), Color(0.35, 0.25, 0.15), lijf, Vector3(kant * 0.28, 0.55, 0.0))
		arm.rotation.z = deg_to_rad(kant * -60.0)
	var hoed := Node3D.new()
	hoed.position = Vector3(0.0, 0.85, 0.0)
	root.add_child(hoed)
	_mesh(_cilinder(0.14, 0.02), Color(0.12, 0.12, 0.12), hoed, Vector3.ZERO)
	_mesh(_cilinder(0.09, 0.15), Color(0.12, 0.12, 0.12), hoed, Vector3(0.0, 0.08, 0.0))
	_registreer(root, 0.95, [_reageer_sneeuwpop_hoed, _reageer_sneeuwpop_smelt, _reageer_sneeuwpop_bal], {"hoed": hoed, "lijf": lijf})


func _reageer_sneeuwpop_hoed(p: Dictionary) -> void:
	var hoed: Node3D = p.hoed
	var thuis: Vector3 = hoed.position
	_geluid(["hat_hit_floor_", "val_prop"])
	var doel := Vector3(_rng.randf_range(-0.6, 0.6), 0.0, _rng.randf_range(0.3, 0.7))
	var tw := (p.node as Node3D).create_tween()
	tw.tween_method(_boog.bind(hoed, thuis, doel, 0.4), 0.0, 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(hoed, "rotation:z", _rng.randf_range(-1.5, 1.5), 0.7)
	tw.tween_interval(3.0)
	tw.tween_method(_boog.bind(hoed, doel, thuis, 0.5), 0.0, 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(hoed, "rotation:z", 0.0, 0.6)
	_klaar(p, tw)


func _reageer_sneeuwpop_smelt(p: Dictionary) -> void:
	var lijf: Node3D = p.lijf
	var hoed: Node3D = p.hoed
	var root: Node3D = p.node
	var tw := root.create_tween()
	tw.tween_property(lijf, "scale", Vector3(1.15, 0.75, 1.15), 1.2).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(hoed, "position:y", 0.62, 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void: _fx_tekst(root, Vector3(0.0, 1.1, 0.0), "Poef...", Color(0.85, 0.9, 1.0)))
	tw.tween_interval(1.0)
	tw.tween_property(lijf, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(hoed, "position:y", 0.85, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_klaar(p, tw)


func _reageer_sneeuwpop_bal(p: Dictionary) -> void:
	# een sneeuwbal vliegt weg en spat uiteen
	var root: Node3D = p.node
	_geluid(["prop_sneeuw"])
	var bal := _mesh(_bol(0.06), Color(0.96, 0.97, 1.0), root, Vector3(0.28, 0.6, 0.1))
	var doel := Vector3(_rng.randf_range(0.8, 1.6), 0.0, _rng.randf_range(0.8, 1.6))
	var tw := bal.create_tween()
	tw.tween_method(_boog.bind(bal, bal.position, doel, 0.7), 0.0, 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		_fx_wolk(root, doel, Color(0.96, 0.97, 1.0), 0.7)
		_fx_tekst(root, doel + Vector3(0.0, 0.3, 0.0), "Pats!", Color(0.85, 0.9, 1.0)))
	tw.tween_callback(bal.queue_free)
	var tw2 := root.create_tween()
	tw2.tween_interval(1.2)
	_klaar(p, tw2)


## Een hooiberg.
func _bouw_hooiberg(pos: Vector3) -> void:
	var root := _prop_root("Hooiberg", pos, _rng.randf_range(0.0, TAU))
	var hooi := _mesh(_kegel(0.5, 0.8), Color(0.78, 0.66, 0.36), root, Vector3(0.0, 0.4, 0.0))
	_mesh(_cilinder(0.025, 1.05), Color(0.4, 0.3, 0.19), root, Vector3(0.0, 0.5, 0.0))
	_registreer(root, 0.8, [_reageer_hooi_kip, _reageer_hooi_nies, _reageer_hooi_zzz], {"hooi": hooi})


func _reageer_hooi_kip(p: Dictionary) -> void:
	var root: Node3D = p.node
	_geluid(["prop_kip"])
	var kip := _maak_kip(root, Vector3(0.35, 0.0, 0.3))
	_fx_veren(root, Vector3(0.35, 0.2, 0.3), 8, Color(0.93, 0.9, 0.84))
	_fx_tekst(root, Vector3(0.3, 0.7, 0.3), "Tok tok!", Color(1.0, 0.9, 0.7))
	_ren_weg(kip, Vector3(_rng.randf_range(-0.6, 0.6), 0.0, 1.0), 1.8)
	var tw := root.create_tween()
	tw.tween_interval(1.4)
	_klaar(p, tw)


func _reageer_hooi_nies(p: Dictionary) -> void:
	var root: Node3D = p.node
	var hooi: Node3D = p.hooi
	_geluid(["prop_nies"])
	var tw := root.create_tween()
	tw.tween_property(hooi, "scale", Vector3(0.92, 1.08, 0.92), 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		_fx_wolk(root, Vector3(0.0, 0.5, 0.2), Color(0.85, 0.75, 0.45), 1.3)
		_fx_tekst(root, Vector3(0.0, 1.0, 0.0), "Hatsjoe!", Color(1.0, 0.9, 0.7)))
	tw.tween_property(hooi, "scale", Vector3(1.1, 0.9, 1.1), 0.1)
	tw.tween_property(hooi, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_klaar(p, tw)


func _reageer_hooi_zzz(p: Dictionary) -> void:
	var root: Node3D = p.node
	var hooi: Node3D = p.hooi
	_geluid(["bewoner_snurken"])
	var tw := root.create_tween()
	for i in 3:
		tw.tween_property(hooi, "scale", Vector3(1.02, 1.04, 1.02), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(func() -> void: _fx_tekst(root, Vector3(0.2, 0.9, 0.2), "Zzz", Color(0.85, 0.9, 1.0)))
		tw.tween_property(hooi, "scale", Vector3.ONE, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_klaar(p, tw)


## Een lantaarnpaal (dorp, markt, haven).
func _bouw_lantaarnpaal(pos: Vector3) -> void:
	var root := _prop_root("Lantaarnpaal", pos, 0.0)
	_mesh(_cilinder(0.03, 1.4), Color(0.16, 0.16, 0.17), root, Vector3(0.0, 0.7, 0.0))
	var lamp := Node3D.new()
	lamp.position = Vector3(0.0, 1.45, 0.0)
	root.add_child(lamp)
	var glas := _mesh(_box(Vector3(0.12, 0.18, 0.12)), Color(1.0, 0.82, 0.45), lamp, Vector3.ZERO)
	var gm := glas.material_override as StandardMaterial3D
	gm.emission_enabled = true
	gm.emission = Color(1.0, 0.75, 0.35)
	gm.emission_energy_multiplier = 1.8
	_mesh(_kegel(0.1, 0.08), Color(0.16, 0.16, 0.17), lamp, Vector3(0.0, 0.13, 0.0))
	var licht := OmniLight3D.new()
	licht.light_color = Color(1.0, 0.78, 0.45)
	licht.light_energy = 0.7
	licht.omni_range = 2.8
	lamp.add_child(licht)
	_lantaarns.append(licht)
	_registreer(root, 1.5, [_reageer_lantaarn_flakker, _reageer_lantaarn_zwaai, _reageer_lantaarn_mot], {"lamp": lamp, "licht": licht})


func _reageer_lantaarn_flakker(p: Dictionary) -> void:
	var licht: OmniLight3D = p.licht
	var tw := (p.node as Node3D).create_tween()
	for i in 4:
		tw.tween_property(licht, "light_energy", 0.05, 0.06)
		tw.tween_property(licht, "light_energy", 1.1, 0.12)
	tw.tween_property(licht, "light_energy", 0.7, 0.3)
	_klaar(p, tw)


func _reageer_lantaarn_zwaai(p: Dictionary) -> void:
	var lamp: Node3D = p.lamp
	_geluid(["prop_lantaarn"])
	var tw := (p.node as Node3D).create_tween()
	var amp := 0.4
	for i in 4:
		tw.tween_property(lamp, "rotation:z", amp, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(lamp, "rotation:z", -amp, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		amp *= 0.6
	tw.tween_property(lamp, "rotation:z", 0.0, 0.3)
	_klaar(p, tw)


func _reageer_lantaarn_mot(p: Dictionary) -> void:
	# een mot cirkelt om de lamp
	var lamp: Node3D = p.lamp
	var mot := _mesh(_box(Vector3(0.05, 0.005, 0.03)), Color(0.75, 0.7, 0.6), lamp, Vector3(0.2, 0.0, 0.0))
	var tw := mot.create_tween()
	tw.tween_method(func(t: float) -> void:
		mot.position = Vector3(cos(t * 9.0) * 0.2, sin(t * 13.0) * 0.08, sin(t * 9.0) * 0.2), 0.0, 1.0, 4.0)
	tw.tween_property(mot, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
	tw.tween_callback(mot.queue_free)
	var tw2 := (p.node as Node3D).create_tween()
	tw2.tween_interval(1.5)
	_klaar(p, tw2)


## Een boom (met blad, of kaal in de winter en na de slag).
func _bouw_boom(pos: Vector3, schaal: float, kaal: bool) -> void:
	var root := _prop_root("Boom", pos, _rng.randf_range(0.0, TAU))
	root.scale = Vector3(schaal, schaal, schaal)
	var stam := Color(0.36, 0.27, 0.17)
	_mesh(_cilinder(0.08, 0.9), stam, root, Vector3(0.0, 0.45, 0.0))
	var kroon := Node3D.new()
	kroon.position = Vector3(0.0, 0.9, 0.0)
	root.add_child(kroon)
	if kaal:
		for i in 5:
			var tak := _mesh(_cilinder(0.025, 0.55), stam, kroon, Vector3.ZERO)
			tak.rotation = Vector3(deg_to_rad(_rng.randf_range(-40.0, 40.0)), 0.0, deg_to_rad(_rng.randf_range(-50.0, 50.0)))
			tak.position = Vector3(sin(tak.rotation.z) * -0.25, 0.22, sin(tak.rotation.x) * 0.25)
	else:
		var groen := Color(0.3, 0.46, 0.2)
		_mesh(_bol(0.42), groen, kroon, Vector3(0.0, 0.25, 0.0))
		_mesh(_bol(0.32), groen.lightened(0.08), kroon, Vector3(0.25, 0.1, 0.1))
		_mesh(_bol(0.3), groen.darkened(0.08), kroon, Vector3(-0.22, 0.15, -0.12))
	_registreer(root, 1.6 * schaal, [_reageer_boom_blad, _reageer_boom_vogel, _reageer_boom_val], {"kroon": kroon, "kaal": kaal})


func _reageer_boom_blad(p: Dictionary) -> void:
	var root: Node3D = p.node
	var kaal: bool = p.kaal
	var kleur: Color = Color(0.95, 0.97, 1.0)
	if not kaal:
		kleur = [Color(0.6, 0.5, 0.15), Color(0.8, 0.45, 0.15), Color(0.4, 0.5, 0.2)][_rng.randi() % 3]
	_fx_veren(root, Vector3(0.0, 1.2, 0.0), 12, kleur)
	var kroon: Node3D = p.kroon
	var tw := root.create_tween()
	var amp := 0.06
	for i in 3:
		tw.tween_property(kroon, "rotation:z", amp, 0.25).set_trans(Tween.TRANS_SINE)
		tw.tween_property(kroon, "rotation:z", -amp, 0.25).set_trans(Tween.TRANS_SINE)
		amp *= 0.5
	tw.tween_property(kroon, "rotation:z", 0.0, 0.2)
	_klaar(p, tw)


func _reageer_boom_vogel(p: Dictionary) -> void:
	# er zat een vogel in: die vliegt op
	var root: Node3D = p.node
	_geluid(["prop_kraai"])
	var vogel := _maak_vogel(root, Vector3(0.1, 1.1, 0.1), Color(0.07, 0.065, 0.08))
	_vlieg(vogel, Vector3(-3.0, 3.6, -1.5), 1.6, true)
	var tw := root.create_tween()
	tw.tween_interval(1.7)
	_klaar(p, tw)


func _reageer_boom_val(p: Dictionary) -> void:
	# appels vallen (of, kaal, een tak)
	var root: Node3D = p.node
	var kaal: bool = p.kaal
	_geluid(["val_prop"])
	var n := 1 if kaal else 3
	for i in n:
		var ding: MeshInstance3D
		if kaal:
			ding = _mesh(_cilinder(0.02, 0.35), Color(0.36, 0.27, 0.17), root, Vector3(0.0, 1.2, 0.0))
		else:
			ding = _mesh(_bol(0.045), Color(0.8, 0.18, 0.12), root, Vector3(_rng.randf_range(-0.3, 0.3), 1.15, _rng.randf_range(-0.3, 0.3)))
		var doel := Vector3(_rng.randf_range(-0.6, 0.6), 0.045, _rng.randf_range(-0.2, 0.7))
		var tw := ding.create_tween()
		tw.tween_interval(0.15 * float(i))
		tw.tween_method(_boog.bind(ding, ding.position, doel, 0.05), 0.0, 1.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(ding, "rotation", Vector3(_rng.randf_range(-2, 2), 0.0, _rng.randf_range(-2, 2)), 0.55)
		tw.tween_property(ding, "position:y", 0.15, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(ding, "position:y", 0.045, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_interval(3.0)
		tw.tween_property(ding, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
		tw.tween_callback(ding.queue_free)
	var tw2 := root.create_tween()
	tw2.tween_interval(1.0)
	_klaar(p, tw2)


# ---------------------------------------------------------------- tik-dingen (11 september)

func _tik_vuur(p: Dictionary) -> void:
	# het vuur schrikt even op
	var tw := (p.node as Node3D).create_tween()
	tw.tween_property(self, "_vuur_basis", _vuur_basis + 1.2, 0.05)
	tw.tween_property(self, "_vuur_basis", 1.3, 0.35).set_trans(Tween.TRANS_SINE)


func _tik_deur(p: Dictionary) -> void:
	# klop klop: de deur rammelt
	var sch: Node3D = p.scharnier
	var tw := sch.create_tween()
	tw.tween_property(sch, "rotation:y", deg_to_rad(-6.0), 0.05)
	tw.tween_property(sch, "rotation:y", 0.0, 0.12).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## Een bel aan een galgje: ding.
func _bouw_bel(pos: Vector3, draai: float) -> void:
	var root := _prop_root("Bel", pos, draai)
	var hout := Color(0.36, 0.26, 0.16)
	for kant in [-1.0, 1.0]:
		_mesh(_box(Vector3(0.05, 0.95, 0.05)), hout, root, Vector3(kant * 0.22, 0.475, 0.0))
	_mesh(_box(Vector3(0.54, 0.05, 0.05)), hout, root, Vector3(0.0, 0.97, 0.0))
	var bel := Node3D.new()
	bel.position = Vector3(0.0, 0.94, 0.0)
	root.add_child(bel)
	var klok := _mesh(_kegel(0.13, 0.22), Color(0.78, 0.62, 0.3), bel, Vector3(0.0, -0.13, 0.0))
	var km := klok.material_override as StandardMaterial3D
	km.metallic = 0.7
	km.roughness = 0.35
	_mesh(_bol(0.03), Color(0.3, 0.28, 0.24), bel, Vector3(0.0, -0.26, 0.0))
	_registreer(root, 1.0, [_reageer_bel_luiden], {"bel": bel, "tik_extra": _tik_bel})


func _tik_bel(p: Dictionary) -> void:
	var bel: Node3D = p.bel
	var oud = p.get("bel_tween", null)
	if oud != null and (oud as Tween).is_valid():
		(oud as Tween).kill()
	var tw := bel.create_tween()
	tw.tween_property(bel, "rotation:z", 0.45, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(bel, "rotation:z", -0.3, 0.16).set_trans(Tween.TRANS_SINE)
	tw.tween_property(bel, "rotation:z", 0.12, 0.16).set_trans(Tween.TRANS_SINE)
	tw.tween_property(bel, "rotation:z", 0.0, 0.14).set_trans(Tween.TRANS_SINE)
	p.bel_tween = tw


func _reageer_bel_luiden(p: Dictionary) -> void:
	var root: Node3D = p.node
	var tw := root.create_tween()
	for i in 3:
		tw.tween_callback(func() -> void:
			_tik_geluid(p.tik, 1.0)
			_tik_bel(p))
		tw.tween_interval(0.45)
	tw.tween_callback(func() -> void: _fx_tekst(root, Vector3(0.0, 1.3, 0.0), "Ding dong!", Color(1.0, 0.9, 0.5)))
	tw.tween_interval(0.3)
	_klaar(p, tw)


## Een kist met flessen en glazen: klink.
func _bouw_glaswerk(pos: Vector3, draai: float) -> void:
	var root := _prop_root("Glaswerk", pos, draai)
	_mesh(_box(Vector3(0.5, 0.22, 0.34)), Color(0.45, 0.34, 0.21), root, Vector3(0.0, 0.11, 0.0))
	var flessen: Array = []
	var kleuren: Array = [Color(0.2, 0.42, 0.22), Color(0.45, 0.28, 0.12), Color(0.2, 0.42, 0.22), Color(0.55, 0.62, 0.66)]
	for i in 4:
		var f := Node3D.new()
		f.position = Vector3(-0.17 + 0.11 * float(i), 0.22, -0.06)
		root.add_child(f)
		var fles := _mesh(_cilinder(0.032, 0.2), kleuren[i], f, Vector3(0.0, 0.1, 0.0))
		(fles.material_override as StandardMaterial3D).roughness = 0.25
		(fles.material_override as StandardMaterial3D).metallic_specular = 0.9
		_mesh(_cilinder(0.014, 0.08), kleuren[i], f, Vector3(0.0, 0.24, 0.0))
		flessen.append(f)
	for i in 2:
		var g := Node3D.new()
		g.position = Vector3(-0.1 + 0.2 * float(i), 0.22, 0.1)
		root.add_child(g)
		var glas := _mesh(_cilinder(0.03, 0.09), Color(0.75, 0.82, 0.86), g, Vector3(0.0, 0.045, 0.0))
		(glas.material_override as StandardMaterial3D).roughness = 0.15
		flessen.append(g)
	_registreer(root, 0.5, [_reageer_glas_omval, _reageer_glas_proost], {"flessen": flessen, "tik_extra": _tik_glas})


func _tik_glas(p: Dictionary) -> void:
	for f in p.flessen:
		var n: Node3D = f
		if not is_instance_valid(n):
			continue
		var tw := n.create_tween()
		tw.tween_property(n, "rotation:z", _rng.randf_range(-0.16, 0.16), 0.06)
		tw.tween_property(n, "rotation:z", 0.0, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _reageer_glas_omval(p: Dictionary) -> void:
	# een fles valt om en rolt van de kist, komt daarna terug
	var root: Node3D = p.node
	var lijst: Array = p.flessen
	var f: Node3D = lijst[_rng.randi() % 4]
	var thuis: Vector3 = f.position
	var tw := root.create_tween()
	tw.tween_property(f, "rotation:x", deg_to_rad(88.0), 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: _tik_geluid(p.tik, 0.85))
	tw.tween_method(_boog.bind(f, thuis, Vector3(thuis.x, 0.03, 0.45), 0.05), 0.0, 1.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(f, "rotation:y", 4.0, 0.5)
	tw.tween_callback(func() -> void:
		_tik_geluid(p.tik, 1.2)
		_fx_tekst(root, Vector3(0.0, 0.6, 0.3), "Klink!", Color(0.85, 0.95, 1.0)))
	tw.tween_interval(2.5)
	tw.tween_property(f, "position", thuis, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(f, "rotation", Vector3.ZERO, 0.35)
	_klaar(p, tw)


func _reageer_glas_proost(p: Dictionary) -> void:
	# twee glazen gaan omhoog en klinken: Proost!
	var root: Node3D = p.node
	var lijst: Array = p.flessen
	var g1: Node3D = lijst[4]
	var g2: Node3D = lijst[5]
	var tw := root.create_tween()
	tw.tween_property(g1, "position:y", 0.45, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(g2, "position:y", 0.45, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(g1, "position:x", -0.03, 0.3)
	tw.parallel().tween_property(g2, "position:x", 0.03, 0.3)
	tw.tween_callback(func() -> void:
		_tik_geluid(p.tik, 1.35)
		_fx_tekst(root, Vector3(0.0, 0.75, 0.1), "Proost!", Color(1.0, 0.9, 0.6))
		_fx_hart(root, Vector3(0.0, 0.6, 0.1), 1))
	tw.tween_interval(0.6)
	tw.tween_property(g1, "position", Vector3(-0.1, 0.22, 0.1), 0.3).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(g2, "position", Vector3(0.1, 0.22, 0.1), 0.3).set_trans(Tween.TRANS_SINE)
	_klaar(p, tw)


## Aambeeld op een blok met een hamer: kleng.
func _bouw_aambeeld(pos: Vector3, draai: float) -> void:
	var root := _prop_root("Aambeeld", pos, draai)
	_mesh(_cilinder(0.17, 0.28), Color(0.4, 0.29, 0.18), root, Vector3(0.0, 0.14, 0.0))
	var ijzer := Color(0.22, 0.22, 0.24)
	var blok := _mesh(_box(Vector3(0.36, 0.12, 0.14)), ijzer, root, Vector3(0.0, 0.34, 0.0))
	(blok.material_override as StandardMaterial3D).metallic = 0.6
	var horen := _mesh(_kegel(0.06, 0.16), ijzer, root, Vector3(0.24, 0.36, 0.0))
	horen.rotation.z = deg_to_rad(-90.0)
	var hamer := Node3D.new()
	hamer.position = Vector3(-0.05, 0.4, 0.12)
	root.add_child(hamer)
	var steel := _mesh(_cilinder(0.014, 0.3), Color(0.5, 0.38, 0.24), hamer, Vector3(0.0, 0.15, 0.0))
	steel.rotation.z = 0.0
	_mesh(_box(Vector3(0.08, 0.06, 0.06)), ijzer, hamer, Vector3(0.0, 0.3, 0.0))
	hamer.rotation.x = deg_to_rad(-70.0)
	_registreer(root, 0.55, [_reageer_aambeeld_vonken, _reageer_aambeeld_hoefijzer], {"hamer": hamer, "tik_extra": _tik_hamer})


func _tik_hamer(p: Dictionary) -> void:
	var hamer: Node3D = p.hamer
	var root: Node3D = p.node
	var oud = p.get("hamer_tween", null)
	if oud != null and (oud as Tween).is_valid():
		(oud as Tween).kill()
	hamer.rotation.x = deg_to_rad(-70.0)
	var tw := hamer.create_tween()
	tw.tween_property(hamer, "rotation:x", deg_to_rad(-10.0), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: _fx_spetters(root, Vector3(0.0, 0.42, 0.0), 4, Color(1.0, 0.8, 0.3)))
	tw.tween_property(hamer, "rotation:x", deg_to_rad(-70.0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	p.hamer_tween = tw


func _reageer_aambeeld_vonken(p: Dictionary) -> void:
	var root: Node3D = p.node
	var tw := root.create_tween()
	for i in 4:
		tw.tween_callback(func() -> void:
			_tik_geluid(p.tik, 1.0 + 0.05 * float(i))
			_tik_hamer(p))
		tw.tween_interval(0.28)
	tw.tween_callback(func() -> void:
		_fx_spetters(root, Vector3(0.0, 0.45, 0.0), 14, Color(1.0, 0.75, 0.25))
		_fx_tekst(root, Vector3(0.0, 0.8, 0.0), "Kleng!", Color(1.0, 0.85, 0.5)))
	tw.tween_interval(0.4)
	_klaar(p, tw)


func _reageer_aambeeld_hoefijzer(p: Dictionary) -> void:
	# een hoefijzer springt van het aambeeld en blijft even liggen
	var root: Node3D = p.node
	_tik_hamer(p)
	_tik_geluid(p.tik, 1.1)
	var ijzer := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.035
	tm.outer_radius = 0.06
	tm.rings = 12
	tm.ring_segments = 6
	ijzer.mesh = tm
	ijzer.material_override = _materiaal(Color(0.3, 0.3, 0.32)).duplicate()
	ijzer.position = Vector3(0.0, 0.42, 0.0)
	root.add_child(ijzer)
	var doel := Vector3(_rng.randf_range(-0.4, 0.4), 0.02, _rng.randf_range(0.3, 0.6))
	var tw := ijzer.create_tween()
	tw.tween_method(_boog.bind(ijzer, ijzer.position, doel, 0.4), 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(ijzer, "rotation", Vector3(_rng.randf_range(-4, 4), 0.0, _rng.randf_range(-4, 4)), 0.55)
	tw.tween_callback(func() -> void: _tik_geluid(p.tik, 0.9))
	tw.tween_interval(3.0)
	tw.tween_property(ijzer, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
	tw.tween_callback(ijzer.queue_free)
	var tw2 := root.create_tween()
	tw2.tween_interval(1.0)
	_klaar(p, tw2)


## Een kookpot aan een driepoot (boven het vuur): bong.
func _bouw_kookpot(pos: Vector3) -> void:
	var root := _prop_root("Kookpot", pos, 0.0)
	var hout := Color(0.36, 0.26, 0.16)
	for i in 3:
		var a := TAU * float(i) / 3.0
		var stok := _mesh(_cilinder(0.018, 0.95), hout, root, Vector3(cos(a) * 0.16, 0.45, sin(a) * 0.16))
		stok.rotation = Vector3(deg_to_rad(-18.0) * sin(a) * -1.0, 0.0, deg_to_rad(18.0) * cos(a))
	var pot := Node3D.new()
	pot.position = Vector3(0.0, 0.42, 0.0)
	root.add_child(pot)
	var ketel := _mesh(_cilinder(0.14, 0.18), Color(0.16, 0.16, 0.17), pot, Vector3(0.0, 0.0, 0.0))
	(ketel.material_override as StandardMaterial3D).metallic = 0.5
	_mesh(_cilinder(0.006, 0.34), Color(0.2, 0.2, 0.2), pot, Vector3(0.0, 0.26, 0.0))
	var deksel := _mesh(_cilinder(0.15, 0.025), Color(0.22, 0.22, 0.24), pot, Vector3(0.0, 0.1, 0.0))
	_mesh(_bol(0.02), Color(0.22, 0.22, 0.24), deksel, Vector3(0.0, 0.03, 0.0))
	_registreer(root, 0.7, [_reageer_kookpot_kook, _reageer_kookpot_spat], {"pot": pot, "deksel": deksel, "tik_extra": _tik_deksel})


func _tik_deksel(p: Dictionary) -> void:
	var deksel: Node3D = p.deksel
	var oud = p.get("deksel_tween", null)
	if oud != null and (oud as Tween).is_valid():
		(oud as Tween).kill()
		deksel.position.y = 0.1
	var tw := deksel.create_tween()
	tw.tween_property(deksel, "position:y", 0.19, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(deksel, "position:y", 0.1, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	p.deksel_tween = tw


func _reageer_kookpot_kook(p: Dictionary) -> void:
	var root: Node3D = p.node
	var pot: Node3D = p.pot
	var tw := root.create_tween()
	for i in 4:
		tw.tween_callback(func() -> void:
			_tik_deksel(p)
			_fx_wolk(root, pot.position + Vector3(0.0, 0.16, 0.0), Color(0.9, 0.9, 0.9), 0.5))
		tw.tween_interval(0.35)
	tw.tween_callback(func() -> void: _fx_tekst(root, pot.position + Vector3(0.0, 0.5, 0.0), "Mmm...", Color(1.0, 0.9, 0.7)))
	tw.tween_interval(0.5)
	_klaar(p, tw)


func _reageer_kookpot_spat(p: Dictionary) -> void:
	var root: Node3D = p.node
	var pot: Node3D = p.pot
	_tik_deksel(p)
	_fx_spetters(root, pot.position + Vector3(0.0, 0.12, 0.0), 10, Color(0.6, 0.4, 0.2))
	_fx_tekst(root, pot.position + Vector3(0.0, 0.5, 0.0), "Hete soep!", Color(1.0, 0.8, 0.6))
	var tw := root.create_tween()
	tw.tween_interval(1.2)
	_klaar(p, tw)


## Rotsen: alleen een tok en wat stof.
func _bouw_rots(pos: Vector3, maat: float) -> void:
	var root := _prop_root("Rots", pos, _rng.randf_range(0.0, TAU))
	var grijs := Color(0.5, 0.49, 0.46)
	var a := _mesh(_bol(maat * 0.5), grijs, root, Vector3(0.0, maat * 0.28, 0.0))
	a.scale = Vector3(1.0, 0.65, 0.85)
	var b := _mesh(_bol(maat * 0.32), grijs.darkened(0.08), root, Vector3(maat * 0.4, maat * 0.18, maat * 0.2))
	b.scale = Vector3(1.0, 0.6, 1.0)
	_registreer(root, maat * 0.5, [_reageer_rots_stof], {"maat": maat})


func _tik_hek(p: Dictionary) -> void:
	for lat in p.latten:
		var l: Node3D = lat
		var tw := l.create_tween()
		tw.tween_property(l, "rotation:x", _rng.randf_range(-0.12, 0.12), 0.05)
		tw.tween_property(l, "rotation:x", 0.0, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _reageer_hek_kraak(p: Dictionary) -> void:
	# een lat schiet los en valt terug
	var lat: Node3D = p.latten[0]
	var thuis: Vector3 = lat.position
	var tw := (p.node as Node3D).create_tween()
	tw.tween_property(lat, "rotation:z", 0.12, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(lat, "position:y", thuis.y - 0.06, 0.2)
	tw.tween_callback(func() -> void: _tik_geluid(p.tik, 0.8))
	tw.tween_interval(1.5)
	tw.tween_property(lat, "rotation:z", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lat, "position:y", thuis.y, 0.3)
	_klaar(p, tw)


func _tik_plas(p: Dictionary) -> void:
	var root: Node3D = p.node
	_fx_spetters(root, Vector3(_rng.randf_range(-0.2, 0.2), 0.02, _rng.randf_range(-0.15, 0.15)), 4)
	_rimpel(root, Vector3(0.0, 0.0, 0.0))


func _reageer_plas_plons(p: Dictionary) -> void:
	var root: Node3D = p.node
	_fx_spetters(root, Vector3(0.0, 0.02, 0.0), 12)
	_rimpel(root, Vector3(0.0, 0.0, 0.0))
	_fx_tekst(root, Vector3(0.0, 0.3, 0.0), "Plons!", Color(0.7, 0.85, 1.0))
	var tw := root.create_tween()
	tw.tween_interval(1.0)
	_klaar(p, tw)


func _reageer_rots_stof(p: Dictionary) -> void:
	var root: Node3D = p.node
	var maat: float = p.maat
	_fx_wolk(root, Vector3(0.0, maat * 0.3, maat * 0.3), Color(0.6, 0.58, 0.52), 0.6)
	var tw := root.create_tween()
	tw.tween_interval(0.8)
	_klaar(p, tw)


# ---------------------------------------------------------------- scene-extra's

## Vallende sneeuw boven het hele beeld, driftend met de wind.
func _bouw_sneeuw() -> void:
	var gp := _deeltjes(600, 9.0, Vector3(0.0, -1.0, 0.0), 8.0, 0.35, 0.6, Vector3(0.0, -0.25, 0.0), 0.035, 0.06,
			[Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.0)], [0.0, 0.08, 0.9, 1.0], false, 0.1)
	var pm := gp.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(24.0, 0.3, 24.0)
	var w: Vector3 = global_transform.basis.inverse() * PawnView.wind_richting
	pm.direction = Vector3(w.x * 0.35, -1.0, w.z * 0.35)
	gp.position = CENTRUM + Vector3(0.0, 9.0, 0.0)
	gp.name = "Sneeuw"
	_props_root.add_child(gp)
	gp.emitting = true


## Water aan de overkant (rivierhaven): een vlak plus een stenen kade.
## De rivier als water voor de spelletjes (stenen, hengel): vanaf de kade (z -1,9).
func _rivier_water() -> Dictionary:
	return {"soort": "rivier", "z_rand": -1.9, "ring_ouder": _rivier_ouder()}


func _rivier_ouder() -> Node3D:
	if _rivier_node == null or not is_instance_valid(_rivier_node):
		_rivier_node = Node3D.new()
		_rivier_node.name = "Rivier"
		_rivier_node.position = Vector3(0.0, GROND_Y, 0.0)
		_props_root.add_child(_rivier_node)
	return _rivier_node


func _bouw_water() -> void:
	_rivier_ouder()
	var pm := PlaneMesh.new()
	pm.size = Vector2(70.0, 30.0)
	var w := MeshInstance3D.new()
	w.name = "Water"
	w.mesh = pm
	w.position = Vector3(CENTRUM.x, GROND_Y + 0.006, -1.8 - 15.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.38, 0.44)
	mat.roughness = 0.18
	mat.metallic = 0.05
	mat.metallic_specular = 0.8
	w.material_override = mat
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_props_root.add_child(w)
	_mesh(_box(Vector3(70.0, 0.14, 0.3)), Color(0.5, 0.48, 0.44), _props_root, Vector3(CENTRUM.x, GROND_Y + 0.07, -1.75))


# ---------------------------------------------------------------- effecten (eenmalig, ruimen zichzelf op)

## Boogje voor tween_method (via bind): t 0..1 van `van` naar `naar`, met een piek erbovenop.
func _boog(t: float, n: Node3D, van: Vector3, naar: Vector3, piek: float) -> void:
	var q := van.lerp(naar, t)
	q.y += piek * sin(t * PI)
	n.position = q


func _fx_tekst(ouder: Node3D, pos: Vector3, tekst: String, kleur: Color = Color(1.0, 0.95, 0.8)) -> void:
	var l := Label3D.new()
	l.text = tekst
	l.font_size = 96
	l.pixel_size = 0.005
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.outline_size = 14
	l.outline_modulate = Color(0.12, 0.08, 0.05, 1.0)
	l.modulate = kleur
	l.position = pos
	ouder.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", pos.y + 0.6, 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.7).set_delay(1.0)
	tw.tween_callback(l.queue_free)


## Een laagpoly hartje: twee bollen en een gekantelde kubus, plat in z.
func _hart(ouder: Node3D, pos: Vector3, maat: float, kleur: Color) -> Node3D:
	var h := Node3D.new()
	h.position = pos
	ouder.add_child(h)
	var mat := _materiaal(kleur).duplicate() as StandardMaterial3D
	for kant in [-1.0, 1.0]:
		var b := MeshInstance3D.new()
		b.mesh = _bol(maat * 0.5)
		b.material_override = mat
		b.position = Vector3(kant * maat * 0.42, maat * 0.35, 0.0)
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		h.add_child(b)
	var k := MeshInstance3D.new()
	k.mesh = _box(Vector3(maat * 0.82, maat * 0.82, maat * 0.82))
	k.material_override = mat
	k.rotation.z = PI / 4.0
	k.position = Vector3(0.0, -maat * 0.05, 0.0)
	k.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	h.add_child(k)
	h.scale = Vector3(1.0, 1.0, 0.45)
	return h


func _fx_hart(ouder: Node3D, pos: Vector3, aantal: int) -> void:
	for i in aantal:
		var h := _hart(ouder, pos + Vector3(_rng.randf_range(-0.1, 0.1), 0.0, 0.0), 0.16, Color(0.95, 0.3, 0.45))
		var mat := (h.get_child(0) as MeshInstance3D).material_override as StandardMaterial3D
		mat.emission_enabled = true
		mat.emission = Color(0.95, 0.3, 0.45)
		mat.emission_energy_multiplier = 0.5
		h.scale = Vector3(0.01, 0.01, 0.01)
		var tw := h.create_tween()
		tw.tween_interval(0.25 * float(i))
		tw.tween_property(h, "scale", Vector3(1.0, 1.0, 0.45), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(h, "position:y", pos.y + 0.6, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(h, "position:x", h.position.x + _rng.randf_range(-0.15, 0.15), 1.4).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(h, "scale", Vector3(0.01, 0.01, 0.01), 0.35).set_delay(1.05)
		tw.tween_callback(h.queue_free)


func _fx_veren(ouder: Node3D, pos: Vector3, aantal: int, kleur: Color) -> void:
	for i in aantal:
		var v := _mesh(_box(Vector3(0.05, 0.004, 0.026)), kleur, ouder, pos)
		v.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var doel := Vector3(pos.x + _rng.randf_range(-0.45, 0.45), 0.01, pos.z + _rng.randf_range(-0.45, 0.45))
		var duur := _rng.randf_range(1.0, 1.8)
		var tw := v.create_tween()
		tw.tween_method(_boog.bind(v, pos, doel, _rng.randf_range(0.1, 0.35)), 0.0, 1.0, duur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(v, "rotation", Vector3(_rng.randf_range(-6, 6), _rng.randf_range(-6, 6), _rng.randf_range(-6, 6)), duur)
		tw.tween_interval(1.2)
		tw.tween_property(v, "scale", Vector3(0.01, 0.01, 0.01), 0.4)
		tw.tween_callback(v.queue_free)


func _fx_wolk(ouder: Node3D, pos: Vector3, kleur: Color, groot: float = 1.0) -> void:
	var gp := _deeltjes(maxi(int(14.0 * groot), 6), 1.7, Vector3(0.0, 1.0, 0.0), 45.0, 0.25 * groot, 0.6 * groot,
			Vector3(0.0, 0.12, 0.0), 0.14 * groot, 0.3 * groot,
			[Color(kleur.r, kleur.g, kleur.b, 0.0), Color(kleur.r, kleur.g, kleur.b, 0.45),
			 Color(kleur.r, kleur.g, kleur.b, 0.2), Color(kleur.r, kleur.g, kleur.b, 0.0)],
			[0.0, 0.15, 0.6, 1.0], false, 0.08 * groot)
	gp.one_shot = true
	gp.explosiveness = 0.85
	gp.position = pos
	ouder.add_child(gp)
	gp.emitting = true
	var tw := gp.create_tween()
	tw.tween_interval(3.0)
	tw.tween_callback(gp.queue_free)


func _fx_spetters(ouder: Node3D, pos: Vector3, aantal: int, kleur: Color = Color(0.75, 0.85, 0.95)) -> void:
	for i in aantal:
		var d := _mesh(_bol(0.018), kleur, ouder, pos)
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var doel := Vector3(pos.x + _rng.randf_range(-0.35, 0.35), pos.y - 0.02, pos.z + _rng.randf_range(-0.35, 0.35))
		var tw := d.create_tween()
		tw.tween_method(_boog.bind(d, pos, doel, _rng.randf_range(0.12, 0.3)), 0.0, 1.0, _rng.randf_range(0.35, 0.55)).set_trans(Tween.TRANS_SINE)
		tw.tween_property(d, "scale", Vector3(0.01, 0.01, 0.01), 0.15)
		tw.tween_callback(d.queue_free)


func _fx_knal(ouder: Node3D, pos: Vector3, groot: float) -> void:
	var flits := _mesh(_bol(0.08 * groot), Color(1.0, 0.85, 0.4), ouder, pos)
	var fm := flits.material_override as StandardMaterial3D
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.7, 0.25)
	fm.emission_energy_multiplier = 3.0
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flits.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var licht := OmniLight3D.new()
	licht.light_color = Color(1.0, 0.78, 0.35)
	licht.light_energy = 2.5 * groot
	licht.omni_range = 2.5 * groot
	flits.add_child(licht)
	var tw := flits.create_tween()
	tw.tween_property(flits, "scale", Vector3(3.5, 3.5, 3.5), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(fm, "albedo_color:a", 0.0, 0.2)
	tw.parallel().tween_property(licht, "light_energy", 0.0, 0.3)
	tw.tween_callback(flits.queue_free)
	_fx_wolk(ouder, pos, Color(0.7, 0.68, 0.62), 0.8 * groot)


# ---------------------------------------------------------------- vogels en kippen

## Een kraai (of een andere vogel in een andere kleur): lijf, kop die omkijkt,
## snavel, staart en twee vleugels (meta "vleugels" en "kop").
func _maak_vogel(ouder: Node3D, pos: Vector3, kleur: Color) -> Node3D:
	var vogel := Node3D.new()
	vogel.name = "Vogel"
	vogel.position = pos
	ouder.add_child(vogel)
	var lijf := _mesh(_bol(0.055), kleur, vogel, Vector3(0.0, 0.07, 0.0))
	lijf.scale = Vector3(0.9, 0.8, 1.6)
	var kop := Node3D.new()
	kop.position = Vector3(0.0, 0.11, 0.07)
	vogel.add_child(kop)
	_mesh(_bol(0.032), kleur, kop, Vector3.ZERO)
	var snavel := _mesh(_kegel(0.012, 0.05), Color(0.25, 0.22, 0.14) if kleur.r < 0.5 else Color(0.9, 0.6, 0.15), kop, Vector3(0.0, -0.005, 0.045))
	snavel.rotation.x = deg_to_rad(90.0)
	var staart := _mesh(_box(Vector3(0.05, 0.012, 0.09)), kleur, vogel, Vector3(0.0, 0.075, -0.11))
	staart.rotation.x = deg_to_rad(-15.0)
	var vleugels: Array = []
	for kant in [-1.0, 1.0]:
		var v := _mesh(_box(Vector3(0.11, 0.008, 0.07)), kleur, vogel, Vector3(kant * 0.06, 0.09, 0.0))
		v.rotation.z = kant * deg_to_rad(8.0)
		vleugels.append(v)
	vogel.set_meta("vleugels", vleugels)
	vogel.set_meta("kop", kop)
	_kraai_koppen.append(kop)
	return vogel


## Vliegen met klapperende vleugels naar `doel` (in het frame van de ouder);
## met `verwijder` verdwijnt de vogel daar.
func _vlieg(n: Node3D, doel: Vector3, duur: float, verwijder: bool) -> void:
	var vleugels: Array = n.get_meta("vleugels", [])
	for v in vleugels:
		var vt := (v as Node3D).create_tween().set_loops(int(duur / 0.2) + 1)
		vt.tween_property(v, "rotation:z", signf((v as Node3D).position.x) * 0.9, 0.1)
		vt.tween_property(v, "rotation:z", signf((v as Node3D).position.x) * -0.5, 0.1)
	var van: Vector3 = n.position
	n.rotation.y = atan2(doel.x - van.x, doel.z - van.z)
	var tw := n.create_tween()
	tw.tween_method(_boog.bind(n, van, doel, 0.6), 0.0, 1.0, duur).set_trans(Tween.TRANS_SINE)
	if verwijder:
		tw.tween_callback(n.queue_free)
	else:
		tw.tween_callback(func() -> void:
			for v in vleugels:
				(v as Node3D).rotation.z = signf((v as Node3D).position.x) * deg_to_rad(8.0))


## Een vogel komt aangevlogen, zit `blijf` seconden en vliegt weer weg.
func _land_vogel(ouder: Node3D, pos: Vector3, blijf: float, kleur: Color = Color(0.07, 0.065, 0.08)) -> void:
	_geluid(["prop_kraai"])
	var vogel := _maak_vogel(ouder, pos + Vector3(2.5, 3.0, -1.5), kleur)
	_vlieg(vogel, pos, 1.3, false)
	var tw := vogel.create_tween()
	tw.tween_interval(1.3 + blijf)
	tw.tween_callback(func() -> void: _vlieg(vogel, pos + Vector3(-3.0, 3.4, -1.5), 1.6, true))


## Alle kraaien die er zitten vliegen op (bij de hoorn).
func _schrik_vogels() -> void:
	for p in _props:
		if p.has("vleugels") and not p.bezig:
			p.bezig = true
			_reageer_kraai(p)


func _maak_kip(ouder: Node3D, pos: Vector3) -> Node3D:
	var kip := Node3D.new()
	kip.position = pos
	ouder.add_child(kip)
	var lijf := Node3D.new()
	kip.add_child(lijf)
	var romp := _mesh(_bol(0.06), Color(0.93, 0.9, 0.84), lijf, Vector3(0.0, 0.07, 0.0))
	romp.scale = Vector3(1.0, 0.85, 1.2)
	_mesh(_bol(0.035), Color(0.93, 0.9, 0.84), lijf, Vector3(0.0, 0.13, 0.06))
	var snavel := _mesh(_kegel(0.012, 0.04), Color(0.9, 0.6, 0.15), lijf, Vector3(0.0, 0.125, 0.1))
	snavel.rotation.x = deg_to_rad(90.0)
	_mesh(_box(Vector3(0.01, 0.025, 0.03)), Color(0.85, 0.15, 0.1), lijf, Vector3(0.0, 0.165, 0.055))
	var staart := _mesh(_box(Vector3(0.03, 0.05, 0.02)), Color(0.75, 0.7, 0.62), lijf, Vector3(0.0, 0.11, -0.07))
	staart.rotation.x = deg_to_rad(-30.0)
	kip.set_meta("lijf", lijf)
	return kip


## De kip rent `afstand` weg in `richting` (stuiterend) en verdwijnt.
func _ren_weg(kip: Node3D, richting: Vector3, afstand: float) -> void:
	var r := richting.normalized()
	kip.rotation.y = atan2(r.x, r.z)
	var lijf: Node3D = kip.get_meta("lijf")
	var st := lijf.create_tween().set_loops(7)
	st.tween_property(lijf, "position:y", 0.06, 0.09).set_trans(Tween.TRANS_SINE)
	st.tween_property(lijf, "position:y", 0.0, 0.09).set_trans(Tween.TRANS_SINE)
	var tw := kip.create_tween()
	tw.tween_property(kip, "position", kip.position + r * afstand, 1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(kip, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
	tw.tween_callback(kip.queue_free)


# ---------------------------------------------------------------- ijs (bevroren plas)

func _reageer_ijs_krak(p: Dictionary) -> void:
	var root: Node3D = p.node
	_geluid(["prop_ijs", "impact_bone"])
	_fx_tekst(root, Vector3(0.0, 0.3, 0.0), "Krak!", Color(0.85, 0.92, 1.0))
	var barst := _mesh(_box(Vector3(0.5, 0.004, 0.02)), Color(0.55, 0.65, 0.75), root, Vector3(0.0, 0.016, 0.0))
	barst.rotation.y = _rng.randf_range(0.0, PI)
	var tw := barst.create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(barst, "scale", Vector3(0.01, 0.01, 0.01), 0.5)
	tw.tween_callback(barst.queue_free)
	var tw2 := root.create_tween()
	tw2.tween_interval(1.2)
	_klaar(p, tw2)


func _reageer_ijs_glij(p: Dictionary) -> void:
	# een steentje glijdt over het ijs
	var root: Node3D = p.node
	_geluid(["prop_ijs"])
	var steen := _mesh(_bol(0.03), Color(0.35, 0.34, 0.32), root, Vector3(-0.5, 0.035, 0.1))
	var tw := steen.create_tween()
	tw.tween_property(steen, "position", Vector3(0.5, 0.035, -0.1), 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(steen, "rotation:z", -8.0, 1.4)
	tw.tween_interval(2.0)
	tw.tween_property(steen, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
	tw.tween_callback(steen.queue_free)
	var tw2 := root.create_tween()
	tw2.tween_interval(1.5)
	_klaar(p, tw2)


# ---------------------------------------------------------------- hulpjes

## `reageer` is een Callable of een Array van Callables: per klik wordt er
## willekeurig een gespeeld (Max, 11 september: "je klikt op de vogel en dan
## vliegt ie weg, of er komt een andere vogel bij met een hartje, of hij
## wordt geschoten en ploft in een verenbal").
func _registreer(node: Node3D, hoogte: float, reageer, extra: Dictionary) -> void:
	var reacties: Array = reageer if reageer is Array else [reageer]
	var p := {"node": node, "hoogte": hoogte, "straal": KLIK_STRAAL, "reageer": reacties[0],
			"reacties": reacties, "laatste": -1, "bezig": false,
			"tik_basis": node.scale, "combo": 0, "combo_tijd": -10.0}
	for k in extra:
		p[k] = extra[k]
	if not p.has("tik"):
		var basisnaam := String(node.name).rstrip("0123456789")
		p["tik"] = TIK_GELUID.get(basisnaam, ["prop_tik", "ui_click"])
	# klikpunt op het midden van het model (niet op de wortel: een ruine of
	# steiger is breed) en een straal die met de omvang meegroeit
	var aabb := _aabb_van(node)
	if aabb.size.length() > 0.0001:
		p["midden"] = aabb.get_center()
		p["omvang"] = aabb.size.length() * 0.5
	else:
		p["midden"] = Vector3(0.0, hoogte * 0.5, 0.0)
		p["omvang"] = 0.0
	_props.append(p)


## Elke klik: meteen geluid en een schudding, hoe vaak je ook klikt. Snel
## doorklikken duwt de toon per klik iets omhoog (combo, valt na 0,7 s terug).
func _tik(p: Dictionary) -> void:
	var n: Node3D = p.node
	if not is_instance_valid(n):
		return
	# combo: binnen `tik_pauze` seconden telt de klik door en gaat de toon
	# omhoog; na een pauze herstart de ladder met een NET ander geluidje
	# (een andere variant van dezelfde categorie)
	var pauze: float = PawnView.fx("tik_pauze", 0.6)
	var stap: float = PawnView.fx("tik_toon", 0.07)
	var doorgeklikt: bool = _tijd - float(p.combo_tijd) < pauze
	p.combo = (int(p.combo) + 1) if doorgeklikt else 0
	p.combo_tijd = _tijd
	var toon := (1.0 + stap * float(mini(int(p.combo), 10))) * _rng.randf_range(0.985, 1.015)
	_tik_geluid_prop(p, toon, not doorgeklikt)
	var c: int = int(p.combo)
	if c > 0 and c % 5 == 0:
		# een klein feestje op elke vijfde: chime en een x5!
		if Audio.variant_aantal("prop_combo") > 0:
			Audio.play("prop_combo", 0.0, -1, 1.0 + 0.04 * float(c / 5))
		_fx_tekst(n, p.get("midden", Vector3(0.0, float(p.hoogte) * 0.5, 0.0)) + Vector3(0.0, 0.35, 0.0), "x%d!" % c, Color(1.0, 0.85, 0.3))
		if c >= 10:
			_fx_hart(n, p.get("midden", Vector3.ZERO) + Vector3(0.0, 0.5, 0.0), 1)
	var oud = p.get("tik_tween", null)
	if oud != null and (oud as Tween).is_valid():
		(oud as Tween).kill()
		n.scale = p.tik_basis
	var basis: Vector3 = p.tik_basis
	var tw := n.create_tween()
	tw.tween_property(n, "scale", basis * Vector3(1.1, 0.86, 1.1), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "scale", basis, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	p.tik_tween = tw
	if p.has("tik_extra"):
		(p.tik_extra as Callable).call(p)


func _tik_geluid(categorieen: Array, toon: float) -> void:
	for cat in categorieen:
		if Audio.variant_aantal(String(cat)) > 0:
			Audio.play(String(cat), 0.0, -1, toon)
			return
	if Audio.variant_aantal("ui_click") > 0:
		Audio.play("ui_click", 0.0, -1, toon)


## Het tik-geluid van een prop: de eerste categorie uit p.tik die bestaat.
## Binnen een combo dezelfde variant (een schone ladder), bij een herstart
## een andere variant dan de vorige keer.
func _tik_geluid_prop(p: Dictionary, toon: float, herstart: bool) -> void:
	var cat := ""
	for c in p.get("tik", []):
		if Audio.variant_aantal(String(c)) > 0:
			cat = String(c)
			break
	if cat == "":
		if Audio.variant_aantal("ui_click") > 0:
			Audio.play("ui_click", 0.0, -1, toon)
		return
	var n_var: int = Audio.variant_aantal(cat)
	var variant: int = int(p.get("variant", -1))
	if herstart or variant < 0 or variant >= n_var:
		if n_var > 1:
			variant = (variant + 1 + (_rng.randi() % (n_var - 1))) % n_var if variant >= 0 else _rng.randi() % n_var
		else:
			variant = 0
		p.variant = variant
	Audio.play(cat, 0.0, variant, toon)


## Hoeveel tik-dingen (TIK_NAMEN) een diorama heeft, uit de data (voor de check).
static func dinger_aantal(i: int) -> int:
	var d: Dictionary = DIORAMAS[clampi(i, 1, DIORAMAS.size()) - 1]
	var n := 0
	for spec in Array(d.get("kamp", [])) + Array(d.get("overkant", [])):
		if TIK_NAMEN.has(String(spec[0])):
			n += 1
	return n


## Schermpixels per bordeenheid (orthografische camera: hoogte van het beeld
## gedeeld door de camera-size), voor kliksstralen die met de prop meegroeien.
func _px_per_eenheid() -> float:
	if _camera == null or _camera.projection != Camera3D.PROJECTION_ORTHOGONAL or _camera.size <= 0.0:
		return 75.0
	return float(get_viewport().get_visible_rect().size.y) / _camera.size


## Willekeurig een van de reacties, nooit twee keer achter elkaar dezelfde.
func _speel_willekeurig(p: Dictionary) -> void:
	var lijst: Array = p.get("reacties", [p.reageer])
	var i := _rng.randi() % lijst.size()
	if lijst.size() > 1 and i == int(p.get("laatste", -1)):
		i = (i + 1 + _rng.randi() % (lijst.size() - 1)) % lijst.size()
	p.laatste = i
	(lijst[i] as Callable).call(p)


## Voor de check: reactie i van een prop direct spelen.
func speel_reactie(p: Dictionary, i: int) -> void:
	var lijst: Array = p.get("reacties", [p.reageer])
	p.bezig = true
	(lijst[i % lijst.size()] as Callable).call(p)


func props() -> Array:
	return _props


## Speelt de eerste categorie die bestaat: eerst de eigen prop-categorie
## (prop_vuur, prop_trom, ...: zet een `prop_<naam>.wav` in sounds/ en hij
## wordt gebruikt, zie SOUND-WISHLIST.md), dan de terugval uit het bestaande
## arsenaal; niets als er niets ligt.
func _geluid(categorieen: Array) -> void:
	for cat in categorieen:
		if Audio.variant_aantal(String(cat)) > 0:
			Audio.play(String(cat))
			return


func _laad_textuur(naam: String) -> Texture2D:
	var pad := Bestandsindex.vind(OMGEVING_DIR, naam)
	if pad == "" or not ResourceLoader.exists(pad):
		return null
	return load(pad) as Texture2D


func _materiaal(kleur: Color) -> StandardMaterial3D:
	var sleutel := kleur.to_html()
	if _mat_cache.has(sleutel):
		return _mat_cache[sleutel]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = kleur
	mat.roughness = 0.9
	mat.metallic_specular = 0.15
	_mat_cache[sleutel] = mat
	return mat


func _mesh(mesh: Mesh, kleur: Color, ouder: Node3D, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	# eigen kopie per stuk dat later aan zijn materiaal zit (gloed, metaal)
	mi.material_override = _materiaal(kleur).duplicate()
	mi.position = pos
	ouder.add_child(mi)
	return mi


func _bol(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 10
	m.rings = 5
	return m


func _cilinder(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 8
	m.rings = 1
	return m


func _kegel(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 6
	m.rings = 1
	return m


func _box(maat: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = maat
	return m


## Deeltjes-emitter (vlam, rook, vonken): quad-billboards met een kleurverloop.
func _deeltjes(aantal: int, leven: float, richting: Vector3, spreiding: float, v_min: float, v_max: float,
		zwaartekracht: Vector3, schaal_min: float, schaal_max: float, kleuren: Array, offsets: Array,
		additief: bool, straal: float) -> GPUParticles3D:
	var gp := GPUParticles3D.new()
	gp.amount = aantal
	gp.lifetime = leven
	gp.local_coords = true
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.direction = richting
	pm.spread = spreiding
	pm.initial_velocity_min = v_min
	pm.initial_velocity_max = v_max
	pm.gravity = zwaartekracht
	# De maat zit in de quad zelf; scale_min/max zijn alleen de spreiding
	# eromheen (gemeten 8 september: een quad van 1 bleef 1, wat de
	# schaal in het materiaal ook zei, en het vuur werd een witte blok).
	var maat := 0.5 * (schaal_min + schaal_max)
	pm.scale_min = schaal_min / maat
	pm.scale_max = schaal_max / maat
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = straal
	pm.damping_min = 0.2
	pm.damping_max = 0.6
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array(offsets)
	grad.colors = PackedColorArray(kleuren)
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	gp.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(maat, maat)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additief else BaseMaterial3D.BLEND_MODE_MIX
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	# zachte ronde vlek in plaats van een kale quad (die bleef als vierkantjes zichtbaar)
	mat.albedo_texture = _zachte_stip()
	quad.material = mat
	gp.draw_pass_1 = quad
	return gp


var _stip_tex: GradientTexture2D = null


## Radiale verloop-textuur (wit in het midden, doorzichtig aan de rand) voor
## deeltjes: een keer gebouwd, gedeeld door vlam, rook en vonken.
func _zachte_stip() -> GradientTexture2D:
	if _stip_tex != null:
		return _stip_tex
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	_stip_tex = GradientTexture2D.new()
	_stip_tex.gradient = grad
	_stip_tex.width = 64
	_stip_tex.height = 64
	_stip_tex.fill = GradientTexture2D.FILL_RADIAL
	_stip_tex.fill_from = Vector2(0.5, 0.5)
	_stip_tex.fill_to = Vector2(0.5, 0.0)
	return _stip_tex


## Omhullende doos van alle meshes onder een node, in de ruimte van die node.
func _aabb_van(root: Node3D) -> AABB:
	var result := AABB()
	var eerste := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D.IDENTITY
		var n: Node = mi
		while n != null and n != root:
			if n is Node3D:
				t = (n as Node3D).transform * t
			n = n.get_parent()
		var box: AABB = t * (mi as MeshInstance3D).get_aabb()
		if eerste:
			result = box
			eerste = false
		else:
			result = result.merge(box)
	return result

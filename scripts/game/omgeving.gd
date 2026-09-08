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
var _tijd := 0.0
var _mat_cache: Dictionary = {}
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
}
# props uit de wishlist die geen placeholder hebben: ze verschijnen zodra
# prop_<naam>[_team].glb in assets/models/props/ ligt. Posities in het
# bordframe (vooraan z 12-17, overkant z -1,5..-4,6; x al gecorrigeerd voor de
# camera-yaw zoals de rest van het kamp). Een prop die maar voor een team
# bestaat lever je met het teamwoord (prop_hooiberg_red.glb): dan blijft het
# andere kamp leeg.
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
	if eigen == _factie_eigen and ander == _factie_ander and team == _team_eigen and _bewoners_root != null:
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
		_grond_mat.albedo_color = Color(1.15 * licht, 1.15 * licht, 1.15 * licht, 1.0)
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
	# de kraai kijkt af en toe om
	if _kraai_kop != null:
		_kraai_kop_timer -= delta
		if _kraai_kop_timer <= 0.0:
			_kraai_kop_timer = randf_range(2.5, 6.0)
			var tw := _kraai_kop.create_tween()
			tw.tween_property(_kraai_kop, "rotation:y", randf_range(-0.9, 0.9), 0.18).set_trans(Tween.TRANS_QUAD)


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
		var wp: Vector3 = n.global_position + Vector3(0.0, float(p.hoogte) * 0.5, 0.0)
		if _camera.is_position_behind(wp):
			continue
		var d := _camera.unproject_position(wp).distance_to(screen_pos)
		if d < float(p.straal) and d < beste_d:
			beste = p
			beste_d = d
	if beste.is_empty():
		return false
	if beste.bezig:
		return true
	beste.bezig = true
	(beste.reageer as Callable).call(beste)
	return true


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


# ---------------------------------------------------------------- het kamp (vooraan)

## De camera kijkt met een yaw van ~20 graden (Board.tscn), dus wat verder
## naar voren staat (grote z) schuift op het scherm naar rechts en de
## overkant naar links: de x-posities zijn daarvoor gecorrigeerd zodat het
## kamp onder het bord in beeld staat en de overkant erboven.
func _bouw_kamp() -> void:
	_bouw_kampvuur(Vector3(2.2, GROND_Y, 13.4))
	_bouw_glb_prop("prop_drum", Vector3(0.4, GROND_Y, 12.7), 0.42, 0.6, Callable(self, "_reageer_trommel"))
	_bouw_glb_prop("prop_barrel", Vector3(4.3, GROND_Y, 12.9), 0.56, -0.4, Callable(self, "_reageer_ton"))
	_bouw_glb_prop("prop_horn", Vector3(4.95, GROND_Y, 12.25), 0.36, 1.2, Callable(self, "_reageer_hoorn"))
	_bouw_bijl_stronk(Vector3(-0.9, GROND_Y, 13.9))
	_bouw_kogels(Vector3(3.5, GROND_Y, 14.4))
	_bouw_tent(Vector3(-1.9, GROND_Y, 15.6), deg_to_rad(20.0), true)
	_bouw_tent(Vector3(5.9, GROND_Y, 15.8), deg_to_rad(-25.0), false)


func _bouw_overkant() -> void:
	_bouw_hek_met_kraai(Vector3(2.2, GROND_Y, -2.0))
	_bouw_plas_met_kikker(Vector3(11.2, GROND_Y, -2.4))
	_bouw_wegwijzer(Vector3(7.6, GROND_Y, -2.9))
	_bouw_tent(Vector3(5.4, GROND_Y, -3.9), deg_to_rad(160.0), false)


func _bouw_kampvuur(pos: Vector3) -> void:
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
		var steen := _mesh(_bol(randf_range(0.045, 0.065)), Color(0.42, 0.40, 0.36), root, Vector3(cos(a) * 0.33, 0.03, sin(a) * 0.33))
		steen.scale = Vector3(1.0, 0.7, 1.0)
	var gloed := _mesh(_cilinder(0.14, 0.02), Color(0.9, 0.35, 0.08), root, Vector3(0.0, 0.03, 0.0))
	var gm := gloed.material_override as StandardMaterial3D
	gm.emission_enabled = true
	gm.emission = Color(1.0, 0.45, 0.1)
	gm.emission_energy_multiplier = 1.6
	_vuur_licht = OmniLight3D.new()
	_vuur_licht.light_color = Color(1.0, 0.68, 0.32)
	_vuur_licht.light_energy = _vuur_basis
	_vuur_licht.omni_range = 4.0
	_vuur_licht.position = Vector3(0.0, 0.32, 0.0)
	root.add_child(_vuur_licht)
	# zuinig met additief: te veel overlappende vlammetjes worden wit
	var vlam := _deeltjes(18, 0.6, Vector3(0.0, 1.0, 0.0), 12.0, 0.35, 0.7, Vector3(0.0, 0.5, 0.0), 0.07, 0.13,
			[Color(1.0, 0.85, 0.4, 0.0), Color(1.0, 0.6, 0.15, 0.55), Color(0.85, 0.22, 0.05, 0.35), Color(0.2, 0.03, 0.0, 0.0)],
			[0.0, 0.15, 0.6, 1.0], true, 0.07)
	vlam.position = Vector3(0.0, 0.06, 0.0)
	root.add_child(vlam)
	var rook := _deeltjes(9, 2.6, Vector3(0.0, 1.0, 0.0), 14.0, 0.28, 0.42, Vector3(0.0, 0.15, 0.0), 0.16, 0.34,
			[Color(0.5, 0.48, 0.45, 0.0), Color(0.45, 0.43, 0.4, 0.28), Color(0.4, 0.4, 0.4, 0.14), Color(0.4, 0.4, 0.4, 0.0)],
			[0.0, 0.15, 0.6, 1.0], false, 0.08)
	rook.position = Vector3(0.0, 0.35, 0.0)
	root.add_child(rook)
	var vonken := _deeltjes(40, 0.9, Vector3(0.0, 1.0, 0.0), 35.0, 1.4, 2.6, Vector3(0.0, -3.0, 0.0), 0.025, 0.04,
			[Color(1.0, 0.85, 0.4, 1.0), Color(1.0, 0.55, 0.15, 0.9), Color(0.6, 0.1, 0.0, 0.0)],
			[0.0, 0.5, 1.0], true, 0.05)
	vonken.one_shot = true
	vonken.explosiveness = 0.95
	vonken.emitting = false
	vonken.position = Vector3(0.0, 0.1, 0.0)
	root.add_child(vonken)
	_registreer(root, 0.5, Callable(self, "_reageer_kampvuur"), {"vonken": vonken, "vlam": vlam})


func _bouw_glb_prop(naam: String, pos: Vector3, schaal: float, draai: float, reageer: Callable) -> void:
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
	if _glb_prop("hakblok", pos, 0.0, _team_op(pos), ["prop_bijl", "impact_wood"], 0.3):
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
	_registreer(root, 0.42, Callable(self, "_reageer_bijl"), {"bijl": bijl})


func _bouw_kogels(pos: Vector3) -> void:
	if _glb_prop("kogels", pos, 0.0, "", ["prop_kogel", "impact_armor"], 0.3):
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
	for b in basis:
		var k := _mesh(_bol(r), ijzer, root, b)
		(k.material_override as StandardMaterial3D).metallic = 0.6
		(k.material_override as StandardMaterial3D).roughness = 0.45
	var rust := Vector3(0.0, r + r * 1.63, 0.0)
	var top := _mesh(_bol(r), ijzer, root, rust)
	(top.material_override as StandardMaterial3D).metallic = 0.6
	(top.material_override as StandardMaterial3D).roughness = 0.45
	_registreer(root, 0.4, Callable(self, "_reageer_kogels"), {"top": top, "rust": rust, "zij": Vector3(0.42, r, 0.18)})


func _bouw_tent(pos: Vector3, draai: float, met_lantaarn: bool) -> void:
	if _glb_prop("tent", pos, draai, _team_op(pos), ["prop_lantaarn"], 1.0):
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
		var arm := _mesh(_cilinder(0.012, 0.35), Color(0.36, 0.26, 0.16), root, Vector3(0.0, 0.92, 1.0))
		arm.rotation.x = deg_to_rad(90.0)
		lantaarn = Node3D.new()
		lantaarn.position = Vector3(0.0, 0.92, 1.16)
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
	_registreer(root, 0.95, Callable(self, "_reageer_tent"), {"lantaarn": lantaarn, "doek": doek})


# ---------------------------------------------------------------- de overkant

func _bouw_hek_met_kraai(pos: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Hek"
	root.position = pos
	_props_root.add_child(root)
	var hout := Color(0.38, 0.29, 0.19)
	if not _glb_prop("hek", pos, 0.0, "", ["impact_wood"], 0.4):
		var paal_x: Array = [0.0, 0.9, 1.8, 2.7]
		for x in paal_x:
			_mesh(_box(Vector3(0.07, 0.36, 0.07)), hout, root, Vector3(x, 0.18, 0.0))
		for h in [0.13, 0.28]:
			_mesh(_box(Vector3(2.85, 0.035, 0.03)), hout, root, Vector3(1.35, h, 0.0))
	# de kraai op de tweede paal
	var kraai := Node3D.new()
	kraai.name = "Kraai"
	kraai.position = Vector3(0.9, 0.36, 0.0)
	kraai.rotation.y = deg_to_rad(-30.0)
	root.add_child(kraai)
	var zwart := Color(0.07, 0.065, 0.08)
	var lijf := _mesh(_bol(0.055), zwart, kraai, Vector3(0.0, 0.07, 0.0))
	lijf.scale = Vector3(0.9, 0.8, 1.6)
	_kraai_kop = Node3D.new()
	_kraai_kop.position = Vector3(0.0, 0.11, 0.07)
	kraai.add_child(_kraai_kop)
	_mesh(_bol(0.032), zwart, _kraai_kop, Vector3.ZERO)
	var snavel := _mesh(_kegel(0.012, 0.05), Color(0.25, 0.22, 0.14), _kraai_kop, Vector3(0.0, -0.005, 0.045))
	snavel.rotation.x = deg_to_rad(90.0)
	var staart := _mesh(_box(Vector3(0.05, 0.012, 0.09)), zwart, kraai, Vector3(0.0, 0.075, -0.11))
	staart.rotation.x = deg_to_rad(-15.0)
	var vleugels: Array = []
	for kant in [-1.0, 1.0]:
		var v := _mesh(_box(Vector3(0.11, 0.008, 0.07)), zwart, kraai, Vector3(kant * 0.06, 0.09, 0.0))
		v.rotation.z = kant * deg_to_rad(8.0)
		vleugels.append(v)
	_registreer(kraai, 0.16, Callable(self, "_reageer_kraai"), {"thuis": kraai.position, "vleugels": vleugels})


func _bouw_plas_met_kikker(pos: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Plas"
	root.position = pos
	_props_root.add_child(root)
	if not _glb_prop("plas", pos, 0.0, "", [], 0.04):
		# geen metaal: dat spiegelt de zwarte hemel en wordt een gat in het gras
		var plas := _mesh(_cilinder(0.6, 0.012), Color(0.46, 0.52, 0.54), root, Vector3(0.0, 0.006, 0.0))
		plas.scale = Vector3(1.0, 1.0, 0.72)
		var pmat := plas.material_override as StandardMaterial3D
		pmat.metallic = 0.0
		pmat.roughness = 0.35
		pmat.metallic_specular = 0.6
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
	_registreer(kikker, 0.1, Callable(self, "_reageer_kikker"), {"thuis": thuis, "alt": alt, "plas": root})


func _bouw_wegwijzer(pos: Vector3) -> void:
	if _glb_prop("wegwijzer", pos, deg_to_rad(12.0), "", ["prop_wegwijzer", "impact_wood"], 0.95):
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
	_registreer(root, 0.95, Callable(self, "_reageer_wegwijzer"), {})


# ---------------------------------------------------------------- props (her)bouwen

## Alles onder Props opnieuw: kamp, overkant, geleverde extra props en de
## bewoners, met de teams en facties van dit moment. De tweens van de
## reacties hangen aan hun eigen prop-node, dus die sterven netjes mee.
func _bouw_props() -> void:
	for kind in _props_root.get_children():
		kind.queue_free()
	_props.clear()
	_bewoners.clear()
	_bewoners_root = null
	_lantaarns.clear()
	_vuur_licht = null
	_kikker_keel = null
	_kraai_kop = null
	_bouw_kamp()
	_bouw_overkant()
	_bouw_extra_props()
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


func _lees_prop_manifest(naam: String) -> Dictionary:
	var pad := Bestandsindex.vind(PROPS_DIR.trim_suffix("/"), "prop_%s.json" % naam)
	if pad == "":
		return {}
	var f := FileAccess.open(pad, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	return data if data is Dictionary else {}


## Ligt er een glb voor deze prop (per team of gedeeld)? Dan die in plaats van
## de primitieven: op zijn ware hoogte geschaald (PROP_HOOGTE of het manifest),
## voeten op het gras, en een wiebel met het geluid van de prop als klik.
func _glb_prop(naam: String, pos: Vector3, draai: float, team: String, geluid: Array, hoogte_std: float) -> bool:
	var pad := _prop_glb(naam, team)
	if pad == "":
		return false
	var ps: PackedScene = load(pad)
	if ps == null:
		return false
	var inst: Node3D = ps.instantiate() as Node3D
	if inst == null:
		return false
	var root := Node3D.new()
	root.name = "prop_" + naam
	root.position = pos
	root.rotation.y = draai
	_props_root.add_child(root)
	root.add_child(inst)
	var m := _lees_prop_manifest(naam)
	var hoogte := float(m.get("hoogte", PROP_HOOGTE.get(naam, hoogte_std)))
	var aabb := _aabb_van(inst)
	if aabb.size.y > 0.0001:
		var sc := hoogte / aabb.size.y
		inst.scale = Vector3(sc, sc, sc)
		inst.position.y = -aabb.position.y * sc + float(m.get("y", 0.0))
	inst.rotation.y = deg_to_rad(float(m.get("draai", 0.0)))
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_registreer(root, hoogte, Callable(self, "_reageer_glb"), {"inst": inst, "geluid": geluid})
	return true


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
			_bouw_decor(b, m)
			_registreer(b, b.hoogte, Callable(self, "_reageer_bewoner"), {"bewoner": b})


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
	tw.tween_interval(randf_range(16.0, 28.0))
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


# ---------------------------------------------------------------- hulpjes

func _registreer(node: Node3D, hoogte: float, reageer: Callable, extra: Dictionary) -> void:
	var p := {"node": node, "hoogte": hoogte, "straal": KLIK_STRAAL, "reageer": reageer, "bezig": false}
	for k in extra:
		p[k] = extra[k]
	_props.append(p)


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

class_name PawnView
extends Node3D

@export var pawn_id: int = 0
@export var team: int = Constants.Team.RED
@export var grid_x: int = 0
@export var grid_z: int = 0

## Sleep hier een karaktermodel in (.glb of .tscn met een AnimationPlayer).
## Leeg = het placeholder-blokje.
@export var model_scene: PackedScene = null
## Animatie-namen zoals ze in JOUW model heten (pas aan naar je asset).
@export var anim_idle: String = "idle"
@export var anim_walk: String = "walk"
@export var anim_attack: String = "attack"
@export var anim_melee: String = "melee"
@export var anim_die: String = "die"
@export var anim_hit: String = "hit"

var _base_material: StandardMaterial3D
var _select_material: StandardMaterial3D
var _hover_material: StandardMaterial3D
var _dim_material: StandardMaterial3D
var _selected: bool = false
var _hovered: bool = false
var _dimmed: bool = false

var _model: Node3D = null
var _anim: AnimationPlayer = null
var _ring: CSGTorus3D
var _marker: CSGBox3D

## v4.1: speelstuk-scene per eenheidstype (0=Infanterie, 1=Cavalerie, 2=Artillerie).
const PIECE_SCENES: Dictionary = {
	0: preload("res://scenes/game/pieces/infantry_piece.tscn"),
	1: preload("res://scenes/game/pieces/cavalry_piece.tscn"),
	2: preload("res://scenes/game/pieces/artillery_piece.tscn"),
}

## Karaktermodellen per factie/type/archetype (zie MODEL-WISHLIST.md), Engelse
## namen: assets/models/<factie>/<type>_<archetype>.glb
##   bv. mouse/infantry_spd.glb · mouse/infantry_base.glb = neutraal/ongekoppeld
## Fallback-keten: exact archetype → base van dat type → geometrisch stuk
## (PIECE_SCENES) met een archetype-silhouet als placeholder.
const Bestandsindex := preload("res://scripts/core/bestandsindex.gd")
const MODELS_DIR := "res://assets/models/"
## Placeholder-silhouet zolang het .glb ontbreekt, in de visuele taal van
## MODEL-WISHLIST.md: dun/gestrekt = snel, laag/rond = taai, breed/gespierd =
## aanvallend. Verdwijnt vanzelf zodra het echte model er is.
const ARCHETYPE_SCALE: Dictionary = {
	"spd": Vector3(0.78, 1.14, 0.78),   # dun en hoog: schichtig, licht
	"hp": Vector3(1.22, 0.88, 1.22),    # laag en rond: massa, pantser
	"atk": Vector3(1.14, 1.04, 1.14),   # breed en iets hoger: gespierd, dreigend
	"mix": Vector3.ONE,
	"base": Vector3.ONE,
}

var _piece: Node3D = null
var _sokkel: CSGCylinder3D = null  # team-gekleurd voetstuk onder .glb-modellen
var _tint_nodes: Array = []  # delen in groep "team_tint" → teamkleur/status
var _unit_type: int = -1
var _char_key: String = ""   # laatst getoonde factie:type:archetype (idempotent)
var _variant_cache: Dictionary = {}  # basisclip -> [volledige variant-namen]
var _tune_key: String = ""   # "mouse/infantry_base" — sleutel in model_tuning.json
var _weapon_tune_key: String = "mouse/musket"   # actieve musket-tuning-sleutel
var _model_path: String = "" # pad van het geladen karaktermodel (voor _gibs.glb)
var _weapon: Node3D = null   # musket-prop aan de hand (vliegt weg bij dood)
## Wind (Max, 8 september): een richting per potje, alle vlaggen wapperen
## dezelfde kant op, ook die van de vijand. game.gd loot hem bij de start
## (_loot_wind); hier staat de wereld-richting (XZ, lengte 1). Puur visueel.
static var wind_richting: Vector3 = Vector3(1.0, 0.0, 0.0)
var _vlagdoek: MeshInstance3D = null   # het doek aan de stok, per frame in de wind gedraaid
var _cape: MeshInstance3D = null       # de cape op de rug (blauw team; knop cape_rood voor rood)
var _vlag_top: Vector3 = Vector3.ZERO  # top van de stok, in prop-ruimte
var _vlag_as: Vector3 = Vector3.UP     # stok-as (omhoog), in prop-ruimte
var _vlag_breedte: float = 0.0
var _vlag_zak: float = 0.0             # hoe ver het doek onder de top hangt
var _baked_wapens: Array = []  # zichtbare INGEBAKKEN muskets (geskinde MeshInstance3D's)
var swaps: int = 0  # diagnose (zweefcheck): hoe vaak dit stuk van model wisselde
var _baked_prop_pad: String = ""  # statische musket-glb die bij de dood vanaf de hand vliegt
var last_fit: Dictionary = {}  # laatste auto-fit meting (Model-tuner toont dit)
var _team_ring: CSGTorus3D = null  # plat gloeiend voetringetje in teamkleur
var _ring_mat_team: StandardMaterial3D = null  # gloeiende teamkleur (actief)
var _ring_mat_idle: StandardMaterial3D = null  # donkere ring (koppel-fase, nog niet gekoppeld)
var _last_clip_len: float = 0.0  # duur (sec, al gedeeld door speed) van de laatst gestarte clip

## Handmatige maat-correcties per model, ingemeten met de Model-tuner (hoofdmenu):
## { "muis/infanterie_basis": {"scale": 1.15, "y": 0.02}, ... }
## Wordt bovenop de auto-fit toegepast. Sleutel volgt het BESTAND dat geladen is
## (dus een archetype dat op _basis terugvalt, gebruikt de _basis-tuning).
const TUNING_PATH := "res://assets/models/model_tuning.json"
static var _tuning: Dictionary = {}
static var _tuning_loaded: bool = false


static func model_tuning() -> Dictionary:
	if not _tuning_loaded:
		_tuning_loaded = true
		if FileAccess.file_exists(TUNING_PATH):
			var f := FileAccess.open(TUNING_PATH, FileAccess.READ)
			if f != null:
				var parsed = JSON.parse_string(f.get_as_text())
				if parsed is Dictionary:
					_tuning = parsed
	return _tuning


static func set_model_tuning(key: String, data: Dictionary) -> void:
	model_tuning()[key] = data


## Effect-tuning (assets/models/effects_tuning.json): losse knopjes voor
## gibs/bloed/hoedje. Ontbrekende sleutels vallen terug op de code-default.
const EFFECTS_PATH := "res://assets/models/effects_tuning.json"
static var _fx: Dictionary = {}
static var _fx_loaded: bool = false


static func fx(key: String, def: float) -> float:
	if not _fx_loaded:
		_fx_loaded = true
		if FileAccess.file_exists(EFFECTS_PATH):
			var f := FileAccess.open(EFFECTS_PATH, FileAccess.READ)
			if f != null:
				var parsed = JSON.parse_string(f.get_as_text())
				if parsed is Dictionary:
					_fx = parsed
	return float(_fx.get(key, def))


## Herlaad de effect-tuning van schijf.
static func reload_effects() -> void:
	_fx_loaded = false


## Zet één effect-waarde (Model-tuner: live draaiknopjes).
static func set_fx(key: String, value: float) -> void:
	fx(key, 0.0)  # zorgt dat het bestand geladen is
	_fx[key] = value


## Het volledige effect-dict (voor opslaan vanuit de Model-tuner).
static func fx_all() -> Dictionary:
	fx("", 0.0)
	return _fx


## Genest effect-dict, bv. "death_pools" (per dood-clip: delay/grow/size/
## forward voor de bloedpoel). Leeg dict als de sleutel ontbreekt.
static func fx_dict(key: String) -> Dictionary:
	fx("", 0.0)
	var v = _fx.get(key)
	return v if v is Dictionary else {}


## Bloedspetter-textures: drop PNG's (met alpha) in assets/textures/blood/ en
## de plassen gebruiken ze automatisch (willekeurige keuze per plas). Map leeg
## = de simpele rode schijfjes. Export-veilig (.import/.remap remaps).
const BLOOD_TEX_DIR := "res://assets/textures/blood/"
static var _blood_textures: Array = []
static var _blood_tex_loaded: bool = false


## prefix filtert op bestandsnaam ("blood_pool" = volle plassen, "splat" =
## fijne spetters); geen match of geen prefix = kies uit alles.
static func _blood_texture(prefix: String = "") -> Texture2D:
	if not _blood_tex_loaded:
		_blood_tex_loaded = true
		var seen: Dictionary = {}
		var d := DirAccess.open(BLOOD_TEX_DIR)
		if d != null:
			for f in d.get_files():
				var fname := String(f).trim_suffix(".import").trim_suffix(".remap")
				if not fname.get_extension().to_lower() in ["png", "webp", "jpg", "jpeg"]:
					continue
				if seen.has(fname):
					continue
				seen[fname] = true
				if ResourceLoader.exists(BLOOD_TEX_DIR + fname):
					var tex = load(BLOOD_TEX_DIR + fname)
					if tex is Texture2D:
						_blood_textures.append({"name": fname.get_basename().to_lower(), "tex": tex})
	if _blood_textures.is_empty():
		return null
	var keuze: Array = []
	if prefix != "":
		for e in _blood_textures:
			if String(e.name).begins_with(prefix):
				keuze.append(e.tex)
	if keuze.is_empty():
		for e in _blood_textures:
			keuze.append(e.tex)
	return keuze[randi() % keuze.size()]


## Zwartkruit-rook: textures in assets/textures/smoke/ (elk formaat met
## alpha, OF "isolated on black" uit een AI-generator — zwart wordt bij het
## laden automatisch transparantie via helderheid=alpha). Map leeg = null
## en de spawner valt terug op grijze bol-wolkjes.
const SMOKE_TEX_DIR := "res://assets/textures/smoke/"
const FIRE_TEX_DIR := "res://assets/textures/fire/"
static var _vfx_cache: Dictionary = {}  # map-pad -> Array van {tex, cols, rows}


## Generieke VFX-loader: scant een map eenmalig, zet zwart-op-achtergrond om
## naar alpha (boost = dekking-versterking) en herkent sprite sheets aan een
## _<kolommen>x<rijen>-suffix in de naam. Entry = {tex, cols, rows}.
## `wens` = deel van een bestandsnaam (bv. "white_smoke"). Leeg = willekeurig
## uit de map, zoals altijd. Zo kan de spawn-pof een andere wolk krijgen dan de
## kruitrook van een musket (Max, 30 juli: "gebruik white_smoke als de spawn
## smoke texture"). Staat de gevraagde texture er niet, dan valt hij netjes
## terug op willekeurig.
static func _vfx_entry(dir_path: String, boost: float, wens: String = "") -> Dictionary:
	if not _vfx_cache.has(dir_path):
		var list: Array = []
		var seen: Dictionary = {}
		var d := DirAccess.open(dir_path)
		if d != null:
			for f in d.get_files():
				var fname := String(f).trim_suffix(".import").trim_suffix(".remap")
				if not fname.get_extension().to_lower() in ["png", "webp", "jpg", "jpeg"]:
					continue
				if seen.has(fname):
					continue
				seen[fname] = true
				if ResourceLoader.exists(dir_path + fname):
					var tex = load(dir_path + fname)
					if tex is Texture2D:
						var cols := 1
						var rows := 1
						var base := fname.get_basename().to_lower()
						var us := base.rfind("_")
						if us >= 0:
							var grid := base.substr(us + 1).split("x")
							if grid.size() == 2 and grid[0].is_valid_int() and grid[1].is_valid_int():
								cols = maxi(int(grid[0]), 1)
								rows = maxi(int(grid[1]), 1)
						list.append({"tex": _black_to_alpha(tex, boost), "cols": cols,
							"rows": rows, "naam": base})
		_vfx_cache[dir_path] = list
	var list2: Array = _vfx_cache[dir_path]
	if list2.is_empty():
		return {}
	if wens != "":
		var w := wens.to_lower()
		for e in list2:
			if String(e.get("naam", "")).contains(w):
				return e
	return list2[randi() % list2.size()]


static func _smoke_entry(wens: String = "") -> Dictionary:
	return _vfx_entry(SMOKE_TEX_DIR, 2.3, wens)


## Vuurflits aan de loop met een texture uit assets/textures/fire/ (billboard,
## kort en fel; sheets spelen hun frames binnen de flits-duur af). false =
## geen textures, de aanroeper tekent dan de klassieke bol-flits.
static func spawn_muzzle_fire(parent: Node3D, pos: Vector3, big: bool) -> bool:
	var e := _vfx_entry(FIRE_TEX_DIR, 1.5)
	if e.is_empty() or parent == null:
		return false
	var quad := MeshInstance3D.new()
	var q := QuadMesh.new()
	var qs := (0.55 if big else 0.32) * fx("fire_size", 1.0) * randf_range(0.9, 1.15)
	q.size = Vector2(qs, qs)
	quad.mesh = q
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = e.tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	var cols := int(e.cols)
	var rows := int(e.rows)
	if cols > 1 or rows > 1:
		mat.uv1_scale = Vector3(1.0 / cols, 1.0 / rows, 1.0)
		_sheet_frame(0, mat, cols, rows)
	elif randf() < 0.5:
		mat.uv1_scale = Vector3(-1.0, 1.0, 1.0)
	quad.material_override = mat
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(quad)
	quad.position = pos
	quad.scale = Vector3.ONE * 0.7
	var life := fx("fire_life", 0.14) * randf_range(0.85, 1.2)
	if cols * rows > 1:
		var anim_tw := quad.create_tween()
		anim_tw.tween_method(_sheet_frame.bind(mat, cols, rows), 0, cols * rows - 1, life)
	var tw := quad.create_tween()
	tw.set_parallel(true)
	tw.tween_property(quad, "scale", Vector3.ONE * randf_range(1.25, 1.5), life).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, life).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(quad.queue_free)
	return true


## Zet één frame van een rook-sprite-sheet (uv-offset binnen het grid).
static func _sheet_frame(frame: int, mat: StandardMaterial3D, cols: int, rows: int) -> void:
	var row := floori(float(frame) / float(cols))
	mat.uv1_offset = Vector3(float(frame % cols) / float(cols), float(row) / float(rows), 0.0)


## Texture op zwarte achtergrond -> alpha (helderheid = dekking). Heeft het
## plaatje al echte transparantie, dan blijft het ongemoeid. Eenmalig per
## texture bij het laden.
## boost > 1 maakt donkere rook dekkender (anders is donkergrijze rook per
## definitie doorzichtig en verbleekt hij boven witte tegels).
static func _black_to_alpha(tex: Texture2D, boost: float = 2.3) -> Texture2D:
	var img := tex.get_image()
	if img == null:
		return tex
	img.convert(Image.FORMAT_RGBA8)
	var data := img.get_data()
	var n := data.size()
	var i := 0
	while i < n:
		if data[i + 3] < 250:
			return tex  # heeft al alpha
		i += 4
	i = 0
	while i < n:
		var lum := maxi(data[i], maxi(data[i + 1], data[i + 2]))
		data[i + 3] = mini(int(float(lum) * boost), 255)
		i += 4
	var out := Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, data)
	return ImageTexture.create_from_image(out)


## Zwartkruit-rook aan de loop of op de inslag: billboard-flarden die vanuit
## een klein wolkje ECHT uitzetten (rook-groei), opstijgen en vervagen.
## pos is in de lokale ruimte van parent. Knoppen: rook-aantal/-maat/-groei/
## -duur. Zonder textures: grijze bol-wolkjes (zelfde gedrag).
static func spawn_powder_smoke(parent: Node3D, pos: Vector3, count: int, size: float,
		dir: Vector3 = Vector3.ZERO, life_mult: float = 1.0, tex_wens: String = "") -> void:
	if parent == null:
		return
	var amount := int(clampf(float(count) * fx("smoke_amount", 1.0), 0.0, 24.0))
	for i in amount:
		var e := _smoke_entry(tex_wens)
		var sheet_cols := 1
		var sheet_rows := 1
		var puff := MeshInstance3D.new()
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if not e.is_empty():
			var q := QuadMesh.new()
			var qs := size * 3.4 * fx("smoke_size", 1.0) * randf_range(0.8, 1.25)
			q.size = Vector2(qs, qs)
			puff.mesh = q
			mat.albedo_texture = e.tex
			mat.albedo_color = Color(1, 1, 1, randf_range(0.75, 0.95) * clampf(fx("smoke_alpha", 1.0), 0.05, 1.0))
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			mat.billboard_keep_scale = true
			sheet_cols = int(e.cols)
			sheet_rows = int(e.rows)
			if sheet_cols > 1 or sheet_rows > 1:
				# Sprite sheet: uv op frame 0; afspelen start verderop, zodra
				# de levensduur van deze wolk bekend is.
				mat.uv1_scale = Vector3(1.0 / sheet_cols, 1.0 / sheet_rows, 1.0)
				_sheet_frame(0, mat, sheet_cols, sheet_rows)
			elif randf() < 0.5:
				mat.uv1_scale = Vector3(-1.0, 1.0, 1.0)
		else:
			var mesh := SphereMesh.new()
			mesh.radial_segments = 8
			mesh.rings = 4
			var radius := size * fx("smoke_size", 1.0) * randf_range(0.75, 1.2)
			mesh.radius = radius
			mesh.height = radius * 2.0
			puff.mesh = mesh
			mat.albedo_color = Color(0.64, 0.64, 0.68, 0.7 * clampf(fx("smoke_alpha", 1.0), 0.05, 1.0))
		puff.material_override = mat
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(puff)
		puff.position = pos + Vector3(randf_range(-0.08, 0.08), randf_range(0.0, 0.08), randf_range(-0.08, 0.08))
		puff.scale = Vector3.ONE * 0.55
		var life := fx("smoke_life", 1.8) * life_mult * randf_range(0.75, 1.15)
		# rook-blijfkans: dit deel van de wolken blijft ~2.5x langer hangen.
		if randf() < fx("smoke_linger_chance", 0.25):
			life *= 2.5
		var drift := Vector3(randf_range(-0.18, 0.18),
			randf_range(0.25, 0.45) * fx("smoke_rise", 1.0), randf_range(-0.18, 0.18))
		if dir != Vector3.ZERO:
			# Rook wappert met het schot mee, van de loop af (rook-drift).
			drift += dir.normalized() * randf_range(0.3, 0.6) * fx("smoke_drift", 1.0)
		# Sprite sheets groeien zelf al in hun frames — de quad groeit dan
		# maar beperkt mee; losse plaatjes krijgen de volle rook-groei.
		var grow_target := fx("smoke_grow", 3.0)
		if sheet_cols * sheet_rows > 1:
			grow_target = 1.0 + (grow_target - 1.0) * 0.35
			var anim_tw := puff.create_tween()
			anim_tw.tween_method(_sheet_frame.bind(mat, sheet_cols, sheet_rows),
				0, sheet_cols * sheet_rows - 1, life)
		var tw := puff.create_tween()
		tw.set_parallel(true)
		tw.tween_property(puff, "position", puff.position + drift, life).set_ease(Tween.EASE_OUT)
		tw.tween_property(puff, "scale", Vector3.ONE * grow_target * randf_range(0.85, 1.2), life) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.chain().tween_callback(puff.queue_free)
		# rook-vervaag: tot die fractie van de levensduur blijft de wolk op
		# volle sterkte, daarna vervaagt hij (hoger = langer vol zichtbaar).
		var fade_start := life * clampf(fx("smoke_fade", 0.35), 0.0, 0.95)
		var fade_tw := puff.create_tween()
		fade_tw.tween_interval(fade_start)
		fade_tw.tween_property(puff.material_override, "albedo_color:a", 0.0, life - fade_start) \
			.set_ease(Tween.EASE_IN)

@onready var _mesh: CSGBox3D = $CSGBox3D
@onready var _label: Label3D = $Label3D


func _ready() -> void:
	var col := Color(0.85, 0.25, 0.28) if team == Constants.Team.RED else Color(0.2, 0.45, 0.9)
	_base_material = StandardMaterial3D.new()
	_base_material.albedo_color = col
	_select_material = StandardMaterial3D.new()
	_select_material.albedo_color = col
	_select_material.emission_enabled = true
	_select_material.emission = Color(0.3, 1.0, 0.4)
	_select_material.emission_energy_multiplier = 0.9
	_hover_material = StandardMaterial3D.new()
	_hover_material.albedo_color = col
	_hover_material.emission_enabled = true
	_hover_material.emission = Color(1.0, 1.0, 0.6)
	_hover_material.emission_energy_multiplier = 0.5
	_dim_material = StandardMaterial3D.new()
	_dim_material.albedo_color = col.darkened(0.6)
	_build_ring()
	_build_front_marker()
	_build_team_ring()
	_try_load_model()
	_update_material()
	set_stats_label(false, 0, 0)


# --- Selectie-/hover-ring (werkt met blokje én model) ------------------------

func _build_ring() -> void:
	_ring = CSGTorus3D.new()
	_ring.inner_radius = 0.30
	_ring.outer_radius = 0.42
	_ring.sides = 24
	_ring.ring_sides = 6
	_ring.position = Vector3(0.0, 0.04, 0.0)
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	_ring.material_override = mat
	_ring.visible = false
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)


## Plat gloeiend voetringetje in teamkleur: leesbaarheid op het donkere
## modder-bord + team-onderscheid (zoals een miniatuur-voetstukje). Verdwijnt
## als de pion sneuvelt (_become_debris).
func _build_team_ring() -> void:
	_team_ring = CSGTorus3D.new()
	_team_ring.inner_radius = 0.3
	_team_ring.outer_radius = 0.37
	_team_ring.sides = 24
	_team_ring.ring_sides = 4
	_team_ring.position = Vector3(0.0, 0.015, 0.0)
	_team_ring.scale = Vector3(1.0, 0.35, 1.0)  # plat plakkaatje
	var mat := StandardMaterial3D.new()
	if team == Constants.Team.RED:
		mat.albedo_color = Color(0.85, 0.2, 0.18)
		mat.emission = Color(0.9, 0.25, 0.2)
	else:
		mat.albedo_color = Color(0.2, 0.42, 0.9)
		mat.emission = Color(0.25, 0.5, 1.0)
	mat.emission_enabled = true
	mat.emission_energy_multiplier = 0.55 * fx("ring_glow", 1.0)
	_team_ring.material_override = mat
	_ring_mat_team = mat
	_ring_mat_idle = StandardMaterial3D.new()
	_ring_mat_idle.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat_idle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat_idle.albedo_color = Color(0.02, 0.02, 0.025, 0.55)
	_team_ring.visible = false  # verschijnt pas bij koppeling (zie _refresh_ring)
	_team_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_team_ring)


var _ring_active: bool = false     # gekoppeld aan een levende kaart
var _ring_link_state: int = 0      # koppel-fase: 0 normaal, 1 koppelbaar, 2 hover


## Actief (gekoppeld aan een levende kaart) = gloeiende team-ring;
## ongekoppeld of uitgeschakeld = hele doorzichtige donkere ring, net
## genoeg om de voet te markeren zonder aandacht te trekken.
func set_team_ring_active(active: bool) -> void:
	_ring_active = active
	_refresh_ring()


## Koppel-fase: 1 = koppelbaar (team-ring op halve gloed), 2 = hover
## (felle gloed + iets groter), 0 = terug naar normaal.
func set_ring_link_state(state_: int) -> void:
	if _ring_link_state == state_:
		return
	_ring_link_state = state_
	_refresh_ring()


## Live bijstellen van de ring-gloed vanuit het sfeer-paneel (toets L in-game).
func set_ring_glow(_mult: float) -> void:
	_refresh_ring()


func _refresh_ring() -> void:
	if _team_ring == null:
		return
	# Buiten de koppel-fase: alleen actieve (gekoppelde) pionnen een ring.
	_team_ring.visible = _ring_active or _ring_link_state > 0
	if not _team_ring.visible:
		return
	if _ring_link_state == 1 and not _ring_active:
		# Koppel-fase: donkere neutrale ring om nog niet gekoppelde pionnen.
		_team_ring.material_override = _ring_mat_idle
		_team_ring.scale = Vector3(1.0, 0.35, 1.0)
		return
	_team_ring.material_override = _ring_mat_team
	var glow := 0.55 * fx("ring_glow", 1.0)
	if _ring_link_state == 2:
		glow *= 2.2  # hover: fel
	if _ring_mat_team != null:
		_ring_mat_team.emission_energy_multiplier = glow
	_team_ring.scale = Vector3(1.15, 0.35, 1.15) if _ring_link_state == 2 else Vector3(1.0, 0.35, 1.0)


## Klein "neusje" aan de voorkant (-Z) zodat de kijkrichting zichtbaar is
## zolang er geen model is.
func _build_front_marker() -> void:
	_marker = CSGBox3D.new()
	_marker.size = Vector3(0.18, 0.18, 0.16)
	_marker.position = Vector3(0.0, 0.95, -0.28)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.95, 0.6)
	mat.emission_energy_multiplier = 0.35
	_marker.material_override = mat
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marker)


# --- Model + animaties -------------------------------------------------------

func _try_load_model() -> void:
	if model_scene == null:
		return
	_model = model_scene.instantiate()
	add_child(_model)
	# Verberg het placeholder-blokje + neusje; het model toont nu alles.
	_mesh.visible = false
	_marker.visible = false
	_anim = _find_anim_player(_model)
	_normaliseer_clipnamen()
	if _anim != null:
		_anim.animation_finished.connect(_on_anim_finished)
	play_idle()


func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_anim_player(child)
		if found != null:
			return found
	return null


func play_idle() -> void:
	_play_variant(anim_idle, true)


func play_walk() -> void:
	_play_variant(anim_walk, true)


func play_attack() -> void:
	_play_variant(anim_attack, false, 1.0, true)


## Melee-klap: eigen clip als het model die heeft, anders de (schiet)attack.
## Per-model gevechts-tuning: model_tuning.json "<factie>/<model>" ->
## {"melee": {...}} (Melee-tab in de tuner). Valt terug op de globale
## effects-knop en daarna de code-default - zonder per-model waarden
## verandert er dus niets.
func melee_fx(short_key: String, fx_key: String, def_val: float) -> float:
	var m: Dictionary = model_tuning().get(_tune_key, {}).get("melee", {})
	if m.has(short_key):
		return float(m[short_key])
	return fx(fx_key, def_val)


func play_melee() -> void:
	if _anim != null and not _variants_of(anim_melee).is_empty():
		# melee-tempo: bajonet/zwaard-clips zijn lang; sneller afspelen houdt
		# het gevecht strak (raakmoment stem je af met melee-raakmoment).
		_play_variant(anim_melee, false, melee_fx("speed", "melee_speed", 1.4), true)
	else:
		_play_variant(anim_attack, false, 1.0, true)


## Aanrij-loop tijdens de charge-beweging (26 aug): run-clip als het model
## die heeft (cavalerie: "Run"/"Run and jump" -> rush1/rush2), anders walk.
func play_rush() -> void:
	if _anim != null and not _variants_of("rush").is_empty():
		_play_variant("rush", true)
	else:
		play_walk()


## Charge-stoot (26 aug, Max: "jump en dan melee"): de sprong-aanval
## ("Standing Melee Run Jump Attack" -> "charge") als het model die heeft,
## anders de gewone melee-stoot. Raakmoment stem je af met charge_hit_delay.
func play_charge() -> void:
	if _anim != null and not _variants_of("charge").is_empty():
		_play_variant("charge", false, melee_fx("charge_speed", "charge_speed", 1.2), true)
	else:
		play_melee()


func play_die() -> void:
	_play_variant(anim_die, false, 1.0, true)


## Hit-reactie: korte incasseer-clip als de pion een klap/schot OVERLEEFT
## (hit1/hit2, random). Modellen zonder hit-clip doen gewoon niets extra's.
## Koppel-moment: het karakter maakt zich klaar (ready_up-clip) terwijl de
## pion omhoog hopt. Heeft het model de clip niet, dan gebeurt er niets.
func play_ready() -> void:
	_play_variant("ready", false, 1.0, true)


func play_hit() -> void:
	if _anim != null and not _variants_of(anim_hit).is_empty():
		_play_variant(anim_hit, false, melee_fx("hit_speed", "hit_speed", 1.0), true)


## Speel een willekeurige variant van een basisclip: "walk" kiest uit
## walk/walk2/walk3, "die" uit die/die2, enz. desync = start op een
## willekeurig punt in de clip, zodat 22 muizen nooit synchroon ademen
## of in de maat marcheren.
func _play_variant(base: String, desync: bool = false, speed: float = 1.0,
		herstart: bool = false) -> void:
	if _anim == null:
		return
	var variants := _variants_of(base)
	if variants.is_empty():
		return
	var full: String = variants[randi() % variants.size()]
	# Vaandeldrager staat RECHTOP en kijkt niet rond (besluit Max, 30 juli).
	# NIET op index kiezen: de exports zetten de idles per model in een andere
	# volgorde (gemeten 30 juli: bij atk zwiept "Idle 1" 123 graden met de kop,
	# bij spd is juist "Idle 1" de rustige). We meten dus welke variant de kop
	# het minst beweegt en pakken die.
	if _rol == "flag" and base == anim_idle:
		var stil := _stilste_idle_variant(variants)
		if stil != "":
			full = stil
	if _anim.current_animation == full:
		# BUG-FIX (Max, 30 juli: "de bajonet-melee werkt niet goed"): twee
		# stoten achter elkaar die dezelfde variant trekken lieten NIETS zien,
		# want de clip speelde al. Eenmalige clips (stoot, schot, dood, hit)
		# beginnen daarom opnieuw; idle/walk laten we juist doorlopen, anders
		# stottert het lopen bij elke aanroep.
		if herstart:
			_anim.seek(0.0, true)
			_last_clip_len = _anim.get_animation(full).length / maxf(speed, 0.01)
		return
	_anim.play(full, 0.2, speed)  # korte crossfade tussen houdingen
	_last_clip_len = _anim.get_animation(full).length / maxf(speed, 0.01)
	if desync:
		_anim.seek(randf() * _anim.get_animation(full).length, false)


## Duur van de laatst gestarte clip (voor timing: bv. oprukken pas na de
## bajonetstoot). Al gecorrigeerd voor de afspeelsnelheid.
## Naam van de clip die NU speelt ("" als er niets speelt). Voor checks als
## `-- meleecheck`: klopt het dat er echt een bajonet-clip loopt?
func huidige_clip() -> String:
	if _anim == null:
		return ""
	var n := String(_anim.current_animation)
	return n.get_slice("/", n.get_slice_count("/") - 1)


func last_clip_duration() -> float:
	return _last_clip_len


## Duur (sec) van de langste variant van een basisclip (bv. "die"), NIET
## gedeeld door de afspeelsnelheid - de aanroeper schaalt zelf met death_speed.
## 0 als de clip ontbreekt.
## True als het stuk momenteel een archetype-model toont (spd/hp/atk/mix),
## dus gekoppeld oogt; false voor het neutrale base-model of geen model.
func has_archetype_look() -> bool:
	return _char_key != "" and not _char_key.ends_with(":base")


func clip_duration(base: String) -> float:
	if _anim == null:
		return 0.0
	var longest := 0.0
	for v in _variants_of(base):
		var a := _anim.get_animation(v)
		if a != null:
			longest = maxf(longest, a.length)
	return longest


## Alle varianten van een basisnaam in het model: exact ("walk") of met
## volgnummer ("walk2"), inclusief bibliotheek-voorvoegsel ("lib/walk2").
## Synoniemen zoals clips uit Blender/Mixamo heten, zodat een model met
## "fire" of "death1/death2" werkt zonder hernoemen of her-export.
const ANIM_ALIASES: Dictionary = {
	"attack": ["fire", "shoot"],
	"die": ["death"],
	"melee": ["bayonet", "sword", "punch", "stab"],
	"hit": ["hurt", "flinch"],
	"ready": ["ready_up", "readyup"],
}


## Clipnamen van verse exports opschonen (Max, 29 juli). Mixamo levert
## "Death 1", "Rifile Walking", "Bayont Attack"; het spel zoekt death1,
## walk1, bayonet1. We hernoemen ALLEEN vuile namen (spatie of hoofdletter),
## zodat bestaande modellen exact blijven zoals ze zijn.
## De doelnamen zijn de namen die het spel ZELF afspeelt (anim_attack "attack",
## anim_die "die", anim_melee "melee", play_ready "ready"). Eerste treffer wint,
## dus de volgorde is de regel: "Bayonet attack" is melee, "Attack Firing Rifle"
## is schieten.
const CLIP_WOORDEN: Array = [
	{"woorden": ["idle"], "doel": "idle"},
	{"woorden": ["walk"], "doel": "walk"},
	{"woorden": ["death", "die"], "doel": "die"},
	{"woorden": ["aim", "ready"], "doel": "ready"},
	{"woorden": ["hit", "reaction", "flinch"], "doel": "hit"},
	# Cavalerie-charge (26 aug, Max: "jump en dan melee, dat is voor de
	# charge"): de sprong-aanval is de charge-stoot, de run-clips zijn de
	# aanrij-loop. VOOR de melee-regel, anders vangt "attack" ze weg.
	{"woorden": ["jump attack"], "doel": "charge"},
	{"woorden": ["run"], "doel": "rush"},
	# "fir" i.p.v. "fire": de HP-muis heet "Firing Rifile ankle shot".
	{"woorden": ["fir", "shoot", "shot"], "doel": "attack"},
	# "strike": de cavalerie-blends (16 aug) hebben een "Pommel strike"-clip.
	{"woorden": ["bayon", "butt", "stab", "melee", "attack", "strike"], "doel": "melee"},
]


static func _schone_clipnaam(n: String) -> bool:
	return not n.contains(" ") and n == n.to_lower()


static func _clip_doelnaam(n: String) -> String:
	var laag := n.to_lower()
	for regel in CLIP_WOORDEN:
		for w in regel["woorden"]:
			if laag.contains(String(w)):
				return String(regel["doel"])
	return ""


func _normaliseer_clipnamen() -> void:
	if _anim == null:
		return
	for lib_naam in _anim.get_animation_library_list():
		var lib: AnimationLibrary = _anim.get_animation_library(lib_naam)
		if lib == null:
			continue
		# Wat al netjes heet telt mee, zodat we niet over bestaande nummers heen gaan.
		var teller: Dictionary = {}
		for a in lib.get_animation_list():
			var n := String(a)
			if not _schone_clipnaam(n):
				continue
			var basis := n.rstrip("0123456789")
			var rest := n.substr(basis.length())
			var nr: int = int(rest) if rest.is_valid_int() else 1
			teller[basis] = maxi(int(teller.get(basis, 0)), nr)
		for a in lib.get_animation_list():
			var n := String(a)
			if _schone_clipnaam(n):
				continue
			var doel := _clip_doelnaam(n)
			if doel == "":
				continue
			var idx: int = int(teller.get(doel, 0)) + 1
			teller[doel] = idx
			var nieuw_naam := "%s%d" % [doel, idx]
			if not lib.has_animation(nieuw_naam):
				lib.rename_animation(a, nieuw_naam)
	_variant_cache.clear()


## Stilste idle-variant van dit model (voor de vaandeldrager). Gemeten op de
## kop/nek-rotatietracks: de variant met de kleinste uitslag staat het meest
## rechtop. Per model gecached, dus de meting gebeurt een keer.
## Handmatig overrulen kan met "vlag_idle" in effects_tuning.json (index in de
## variantenlijst; -1 = automatisch meten).
static var _stilste_idle_cache: Dictionary = {}


func _stilste_idle_variant(variants: Array) -> String:
	if variants.is_empty() or _anim == null:
		return ""
	var handmatig := int(fx("vlag_idle", -1.0))
	if handmatig >= 0 and handmatig < variants.size():
		return String(variants[handmatig])
	var sleutel := "%s|%d" % [_model_path, variants.size()]
	if _stilste_idle_cache.has(sleutel):
		return String(_stilste_idle_cache[sleutel])
	var beste := String(variants[0])
	var beste_uitslag := INF
	for v in variants:
		var a: Animation = _anim.get_animation(String(v))
		if a == null:
			continue
		var uitslag := _kop_uitslag(a)
		if uitslag < beste_uitslag:
			beste_uitslag = uitslag
			beste = String(v)
	_stilste_idle_cache[sleutel] = beste
	return beste


## Hoeveel graden draait de kop/nek in deze clip, van de rustpose af gemeten?
static func _kop_uitslag(a: Animation) -> float:
	var ergste := 0.0
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var pad := String(a.track_get_path(t)).to_lower()
		if not (pad.contains("head") or pad.contains("neck")):
			continue
		var n := a.track_get_key_count(t)
		if n < 2:
			continue
		var eerste: Quaternion = a.track_get_key_value(t, 0)
		for k in range(1, n):
			var q: Quaternion = a.track_get_key_value(t, k)
			ergste = maxf(ergste, absf(rad_to_deg(eerste.angle_to(q))))
	return ergste


func _variants_of(base: String) -> Array:
	if _variant_cache.has(base):
		return _variant_cache[base]
	var bases: Array = [base]
	bases.append_array(ANIM_ALIASES.get(base, []))
	var out: Array = []
	for a in _anim.get_animation_list():
		var n := String(a)
		n = n.get_slice("/", n.get_slice_count("/") - 1)
		for b in bases:
			var bs := String(b)
			if n == bs or (n.begins_with(bs) and n.substr(bs.length()).is_valid_int()):
				out.append(String(a))
				break
	_variant_cache[base] = out
	return out


## Sta- en loopclips horen te herhalen (glTF-clips loopen niet vanzelf).
func _make_loops() -> void:
	# "rush" (26 aug): de aanrij-loop van de cavalerie-charge loopt net als
	# walk door zolang de beweging duurt.
	for base in [anim_idle, anim_walk, "rush"]:
		for full in _variants_of(base):
			_anim.get_animation(full).loop_mode = Animation.LOOP_LINEAR


# --- Combat feel: stagger (knockback) + lichte ragdoll bij dood ---------------

## Korte "wankel"-schok: de pion schiet even terug in `world_dir` en herstelt.
## Geeft gewicht aan een niet-dodelijke treffer (Valheim-stijl stagger).
func stagger(world_dir: Vector3) -> void:
	var dir := world_dir
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = Vector3(0, 0, 1)
	dir = dir.normalized()
	var base := position
	var tw := create_tween()
	tw.tween_property(self, "position", base + dir * 0.16, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", base, 0.13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Dood: mét gibs-bestand valt het lijf ALTIJD uiteen in zijn brokstukken (het
## origineel verdwijnt meteen — geen dubbel omvallend lichaam); de klap-sterkte
## bepaalt hoe gewelddadig de delen wegvliegen. Zonder gibs-bestand (placeholder
## of factie zonder gezaagd model) valt de klassieke omvaller terug.
## strength: melee ~0.7, schot 0.75, kanon 1.4.
## force_die_clip: laat een SPECIFIEKE dood-clip spelen (Model-tuner) —
## leeg = willekeurige variant.
func play_death(world_dir: Vector3, strength: float = 0.7, kind: String = "melee", force_die_clip: String = "") -> void:
	_kreet_af = kreet_al_gespeeld   # game.gd deed de kanonkreet al vóór de inslag
	kreet_al_gespeeld = false
	_dodelijke_kracht = strength
	# Kreet-kans (besluit Max, 28 juli): niet elke dode gilt. Los van of er
	# gibs afvliegen -- puur een kans per sterfgeval, instelbaar via
	# effects_tuning.json ("kreet_kans"). In het SPEL speelt game.gd de
	# factie-kreet al bij elke dood (en zet kreet_al_gespeeld), dus deze poort
	# is er voor losse gevallen: de Model-tuner en tests. Een KANONtreffer
	# gilt altijd -- die kans geldt alleen voor musket- en meleedoden.
	if not _kreet_af and (strength >= 1.2 or randf() < fx("kreet_kans", 0.15)):
		_kreet_af = true
		_speel_doodskreet()
	_ring.visible = false
	set_hovered(false)
	var dir := world_dir
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = Vector3(0, 0, 1)
	dir = dir.normalized()
	_fling_weapon(dir)  # musket vliegt uit de handen
	# Kanon-kracht: ALTIJD grove bloedmist + druppel-fontein op het moment van
	# de knal - ook zonder gibs-bestand, zodat een nieuw model dat nog geen
	# _gibs.glb heeft tóch de kanon-gore toont. Mét gibs-bestand klapt het lijf
	# bovendien volledig uiteen; zonder valt het via de die-clip hieronder.
	if strength >= 1.2:
		var mist := fx("blood_mist", 1.0)
		if mist > 0.0:
			_spawn_blood_mist(global_position + Vector3.UP * 0.45, dir, mist)
			_spawn_blood_burst(global_position + Vector3.UP * 0.5, int(18.0 * mist), dir)
		_spawn_blood_burst(global_position + Vector3.UP * 0.4, int(16 * fx("blood_burst", 1.0)))
		if _spawn_gibs(dir, strength):
			if _piece != null:
				_piece.visible = false  # de brokstukken zíjn het lijk
			_become_debris()
			return
	# Lichtere kill (musket/melee): het lijf blijft HEEL. Heeft het model een
	# die-clip, dan speelt DIE het sterven (zichtbaar, geen tuimel erdoorheen)
	# en blijft het lijk in de eindpose van de animatie liggen.
	var die_variants: Array = _variants_of(anim_die) if _anim != null else []
	if not die_variants.is_empty():
		# Specifieke clip (tuner) of een willekeurige variant.
		var clip := ""
		if force_die_clip != "":
			for v in die_variants:
				if String(v).ends_with(force_die_clip):
					clip = String(v)
					break
		if clip == "":
			clip = die_variants[randi() % die_variants.size()]
		_anim.play(clip, 0.2, melee_fx("death_speed", "death_speed", 1.0))
		var base := clip.get_slice("/", clip.get_slice_count("/") - 1)
		var cfg: Dictionary = fx_dict("death_pools").get(base, {})
		# torso-afstand: van de voeten (pion-origin) naar waar de ROMP van dit
		# lijk ligt — in MODEL-richting (+ = achterover, - = voorover), dus
		# onafhankelijk van de schot-richting.
		var torso_off: float = float(cfg.get("torso", cfg.get("forward", 0.3)))
		# Bloedfontein uit de borst: 1-3 snelle stoten kort na elkaar, elk in
		# een andere richting en steeds meer met de vallende torso mee; elke
		# stoot laat zijn eigen spetter achter (via _spawn_blood_spurt).
		var pulses := 1 + randi() % 3
		for pi in pulses:
			var ptw := create_tween()
			ptw.tween_interval(0.04 + float(pi) * randf_range(0.12, 0.2))
			ptw.tween_callback(_spurt_pulse.bind(pi, pulses, dir, torso_off))
		_shed_parts(dir, kind)  # losse delen: zie _shed_parts voor de regels
		_become_debris()
		# Poel onder het lichaam — timing/groei/maat/plek per dood-clip
		# instelbaar via effects_tuning.json -> death_pools (tuner-rij
		# "Dood-poel"). Zo valt de plas precies wanneer dít lijf ligt.
		# Bons als het LIJF de grond raakt -- zelfde moment als waarop de
		# bloedplas begint (die timing is per dood-clip al ingesteld).
		Audio.play_getuned("body_hit_floor", float(cfg.get("delay", fx("death_blood_delay", 0.9))))
		_spawn_blood(global_position + transform.basis.z * torso_off, 1, 0.03,
			float(cfg.get("delay", fx("death_blood_delay", 0.9))),
			float(cfg.get("grow", 0.7)),
			float(cfg.get("size", 2.4)), "blood_pool")
		return
	# Fallback zonder die-clip (geometrische stukken): klassieke omvaller.
	var axis := Vector3.UP.cross(dir).normalized()
	if axis.length() < 0.01:
		axis = Vector3(1, 0, 0)
	var start_basis := transform.basis
	var start_pos := position
	var tw := create_tween()
	tw.tween_method(
		func(ang: float) -> void: transform.basis = start_basis.rotated(axis, ang),
		0.0, deg_to_rad(100.0), 0.35).set_ease(Tween.EASE_IN)
	var rest := start_pos + dir * 0.55
	rest.y = start_pos.y + 0.0
	var slide := create_tween()
	slide.tween_property(self, "position", start_pos + dir * 0.3 + Vector3(0, 0.18, 0), 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	slide.tween_property(self, "position", rest, 0.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_become_debris()
	_spawn_blood(global_position + dir * 0.35, 3, 0.3, 0.4)


## Het musket vliegt bij dood uit de handen: los van het skelet, boogje in de
## knockback-richting, tollend neer, even blijven liggen en wegzinken.
## Alleen tween_property's op het wapen zelf — de pion mag intussen ge-freed
## worden zonder dat de tween op een dode callable klapt.
## De kreet die bij deze dood hoort: een kanontreffer (kracht >= 1.2) klinkt
## anders dan een musketkogel of een bajonet.
func _speel_doodskreet() -> void:
	if _unit_type != Constants.UnitType.INFANTRY:
		return
	if _dodelijke_kracht >= 1.2:
		Audio.play_factie("inf_kanon_die", _doctrine, 0.0, 0.0, "inf_die", _archetype)
	else:
		Audio.play_factie("inf_die", _doctrine, 0.0, 0.0, "", _archetype)


## Welk kletter-geluid hoort bij wat er uit de handen vliegt? Trommel klinkt
## anders dan een musket. Zonder eigen bestand valt alles terug op "val_prop".
## Welk archetype draagt deze pion (hp/atk/spd/mix)? Nodig voor de
## materiaal-laag: de hp-pion draagt het kuras en klinkt metalig.
func archetype() -> String:
	return _archetype


## Welke materiaal-laag hoort bij een treffer op dit soort pion?
## EEN plek voor deze regel: game.gd speelt hem en de tuner laat hem horen.
## Zonder dit stond de regel dubbel en tunede je een geluid dat het spel
## nooit koos (opmerking uit de audit, 30 juli).
static func impact_categorie(unit_type: int, arch: String) -> String:
	if unit_type == Constants.UnitType.ARTILLERY:
		return "impact_wood"     # affuit en wielen
	if arch == "hp":
		return "impact_armor"    # de dikke pion draagt het kuras
	return "impact_flesh"


## Val-categorie van het handwapen/attribuut. STATISCH zodat de Model-tuner
## exact dezelfde regel gebruikt als het spel — nooit twee kopieen van een
## categorie-keuze (dat was precies de tuner/spel-divergentie die de audit
## van 30 juli voor impact_categorie heeft weggewerkt).
static func val_categorie_voor(unit_type: int, rol: String) -> String:
	if rol != "":
		return "val_" + rol
	if unit_type == Constants.UnitType.CAVALRY:
		return "val_melee"  # sabel/bijl/lans van de big bro
	return "val_musket"


func _val_categorie() -> String:
	return val_categorie_voor(_unit_type, _rol)


func _fling_weapon(world_dir: Vector3) -> void:
	var w: Node3D = _los_wapen_voor_worp()
	if w == null:
		return
	var xf := w.global_transform
	var land := Vector3(xf.origin.x, global_position.y + 0.04, xf.origin.z) + world_dir * 0.65
	var peak := xf.origin.lerp(land, 0.5) + Vector3.UP * 0.55
	# Tollen alleen tijdens de vlucht; daarna snel plat op de grond.
	var spin := w.create_tween()
	spin.tween_property(w, "rotation", w.rotation + Vector3(2.4, 1.2, 3.0), 0.44) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var arc := w.create_tween()
	arc.tween_property(w, "global_position", peak, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	arc.tween_property(w, "global_position", land, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# Kletter-geluid op het moment dat het voorwerp de grond raakt -- los van
	# de doodskreet, want die duurt korter dan de val (besluit Max, 28 juli).
	arc.tween_callback(func() -> void: Audio.play_getuned(_val_categorie()))
	arc.tween_property(w, "rotation", _flat_rotation(w), 0.12)
	# Het musket blijft op het bord liggen (opruiming via battlefield_debris).
	w.add_to_group("battlefield_debris")
	verduister_later(w)


## Maak het wapen los voor de doodsworp. Twee routes:
## 1) de hand-prop (muis, figuranten): loskoppelen en herouderen, zoals altijd;
## 2) het INGEBAKKEN musket (16 augustus): dat is geskind en kan dus niet los
##    slingeren — verberg het en zet de statische per-model musket-glb op de
##    plek van de rechterhand, precies waar de pion hem vasthield. Die vliegt.
## Retour: een scene-geouderd wapen klaar voor de worp, of null (niets te doen).
func _los_wapen_voor_worp() -> Node3D:
	var scene_parent := get_parent()
	if scene_parent == null:
		return null
	if _weapon != null and is_instance_valid(_weapon):
		var w: Node3D = _weapon
		_weapon = null
		var xf := w.global_transform
		w.get_parent().remove_child(w)
		scene_parent.add_child(w)
		w.global_transform = xf
		return w
	if _baked_wapens.is_empty():
		return null
	# 2a: BOT-GEPARENT musket (generator hangt hem aan mixamorig:RightHand;
	# Godot maakt daar bij import een BoneAttachment3D van). Dat is een gewone
	# rigide node — koppel hem los en gooi hem ZELF: exact de plek, stand,
	# maat en textuur waarmee de pion hem vasthield. Geen los bestand nodig.
	for mi in _baked_wapens:
		if not is_instance_valid(mi) or not (mi as MeshInstance3D).visible:
			continue
		var n: Node = mi.get_parent()
		var rigide := false
		while n != null and n != _piece:
			if n is BoneAttachment3D:
				rigide = true
				break
			n = n.get_parent()
		if not rigide:
			continue
		var skels: Array = _piece.find_children("*", "Skeleton3D", true, false)
		if not skels.is_empty():
			(skels[0] as Skeleton3D).force_update_all_bone_transforms()
		var wxf := (mi as Node3D).global_transform
		mi.get_parent().remove_child(mi)
		scene_parent.add_child(mi)
		(mi as Node3D).global_transform = wxf
		# Overige wapen-meshes (dubbele nodes) verbergen; er vliegt er één.
		for ander in _baked_wapens:
			if ander != mi and is_instance_valid(ander):
				(ander as MeshInstance3D).visible = false
		_baked_wapens = []
		return mi
	# 2b: GESKIND musket: kan niet los (de mesh hangt aan het hele skelet).
	# Verberg het en zet de statische per-model musket-glb op de hand-positie.
	if _baked_prop_pad == "":
		return null
	# Hand-positie meten VOOR we iets verbergen (skelet staat nog in de
	# leef-pose; de die-clip start pas na deze aanroep).
	var hand := _hand_positie()
	var had_zichtbaar := false
	for mi in _baked_wapens:
		if is_instance_valid(mi) and (mi as MeshInstance3D).visible:
			had_zichtbaar = true
			(mi as MeshInstance3D).visible = false
	_baked_wapens = []
	if not had_zichtbaar or not ResourceLoader.exists(_baked_prop_pad):
		return null
	var prop: Node3D = (load(_baked_prop_pad) as PackedScene).instantiate()
	scene_parent.add_child(prop)
	prop.force_update_transform()
	# Zelfde normalisatie als _attach_weapon: langste as -> ~0.55 wereld-unit.
	var ab := _combined_aabb(prop)
	var longest: float = maxf(ab.size.x, maxf(ab.size.y, ab.size.z))
	var parent_scale: float = prop.global_transform.basis.get_scale().x
	if parent_scale <= 0.0001 or not is_finite(parent_scale):
		parent_scale = 1.0
	if longest > 0.0001:
		var factor := 0.55 / (longest * parent_scale)
		prop.scale = Vector3(factor, factor, factor)
	prop.global_position = hand
	# Startstand maakt weinig uit (de worp tolt hem meteen rond); een
	# willekeurige draai voorkomt dat elke dode hetzelfde plaatje geeft.
	prop.rotation_degrees = Vector3(0.0, randf() * 360.0, 0.0)
	return prop


## Wereldpositie van de rechterhand (waar het musket zit); valt terug op
## borsthoogte als er geen skelet of hand-bot te vinden is.
func _hand_positie() -> Vector3:
	if _piece != null:
		var skels: Array = _piece.find_children("*", "Skeleton3D", true, false)
		if not skels.is_empty():
			var skel: Skeleton3D = skels[0]
			var bone := -1
			for cand in ["mixamorig:RightHand", "RightHand"]:
				bone = skel.find_bone(cand)
				if bone >= 0:
					break
			if bone < 0:
				for i in skel.get_bone_count():
					if String(skel.get_bone_name(i)).contains("RightHand"):
						bone = i
						break
			if bone >= 0:
				skel.force_update_all_bone_transforms()
				return (skel.global_transform * skel.get_bone_global_pose(bone)).origin
	return global_position + Vector3.UP * 0.35


## Het lijk/brokstuk blijft op het bord tot de volgende definieerfase;
## game._clear_debris() laat alles in de groep "battlefield_debris" wegzinken.
func _become_debris() -> void:
	if _team_ring != null:
		_team_ring.visible = false  # gesneuveld: geen team-ring meer
	add_to_group("battlefield_debris")
	verduister_later(_piece if _piece != null else self)
	if _cape != null and is_instance_valid(_cape):
		verduister_later(_cape)   # de cloth-cape hangt onder de PawnView, niet onder het stuk
	if _sokkel != null and is_instance_valid(_sokkel):
		_sokkel.visible = false  # geen team-marker onder een lijk (leest als pion)
	var area := get_node_or_null("Area3D")
	if area is Area3D:
		(area as Area3D).collision_layer = 0


## Bloedpoelen op het bord (roet bij artillerie): platte donkerrode schijfjes
## rond het inslagpunt. Ze verschijnen pas ná `delay` (als het stuk op de
## grond ligt) en lopen dan vol van een stipje naar volle grootte.
## Gaan mee in de debris-opruiming.
## grow_time > 0 = gesynchroniseerde poel (bloedspuit): geen extra wachttijd,
## de poel groeit in precies die duur naar vol — timing matcht de straal.
## size_mult schaalt de poel (romp groot, hoedje klein); tex_prefix forceert
## de texture-soort ("blood_pool"/"splat"), leeg = automatisch op spread.
func _spawn_blood(world_center: Vector3, amount: int, spread: float = 0.25, delay: float = 0.0, grow_time: float = -1.0, size_mult: float = 1.0, tex_prefix: String = "") -> void:
	var parent := get_parent()
	if parent == null:
		return
	var ground_y := global_position.y + 0.015
	var blood := _unit_type != 2  # kanonnen bloeden niet: roet/olie
	for i in amount:
		var disc := MeshInstance3D.new()
		var mat := StandardMaterial3D.new()
		# Kleine enkele inslag (druppel/spuit-restje) = spetter-texture,
		# grotere plas onder lijk/ledemaat = volle pool-texture.
		var tex := _blood_texture(tex_prefix if tex_prefix != "" else ("splat" if spread <= 0.05 else "blood_pool"))
		if tex != null:
			# Spetter-PNG op een plat vlak; donker getint bij roet (artillerie).
			var pm := PlaneMesh.new()
			var d := randf_range(0.14, 0.34) * fx("blood_size", 1.0) * size_mult
			pm.size = Vector2(d, d)
			disc.mesh = pm
			mat.albedo_texture = tex
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(1, 1, 1) if blood else Color(0.15, 0.15, 0.16)
		else:
			var m := CylinderMesh.new()
			m.top_radius = randf_range(0.05, 0.14) * fx("blood_size", 1.0) * size_mult
			m.bottom_radius = m.top_radius
			m.height = 0.004
			disc.mesh = m
			if blood:
				mat.albedo_color = Color(randf_range(0.32, 0.5), 0.02, 0.03)
			else:
				mat.albedo_color = Color(0.08, 0.08, 0.09)
		mat.roughness = 0.4
		disc.material_override = mat
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(disc)
		disc.add_to_group("battlefield_debris")
		disc.global_position = Vector3(
			world_center.x + randf_range(-spread, spread),
			ground_y + 0.001 + randf() * 0.006,
			world_center.z + randf_range(-spread, spread))
		disc.rotation.y = randf() * TAU
		# Vollopen: onzichtbaar tot het stuk ligt, dan uitvloeien.
		disc.visible = false
		disc.scale = Vector3(0.08, 1.0, 0.08)
		var tw := disc.create_tween()
		if grow_time > 0.0:
			tw.tween_interval(delay + randf() * 0.08)
			tw.tween_callback(disc.show)
			tw.tween_property(disc, "scale", Vector3.ONE, grow_time * randf_range(0.85, 1.0)) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		else:
			tw.tween_interval(delay + fx("blood_extra_delay", 0.4) + randf() * 0.3)
			tw.tween_callback(disc.show)
			tw.tween_property(disc, "scale", Vector3.ONE, randf_range(0.5, 0.9) * fx("blood_grow", 1.0)) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Gerichte bloedstraal: druppels spuiten kort achter elkaar in een kegel rond
## dir uit de wond (borst bij een schot, stomp-gat bij een verloren ledemaat),
## vallen in een boogje neer en verdwijnen. Laat één klein plasje achter.
## Overleef-wond: de klap komt aan maar de pion blijft staan. Een korte
## spetterstraal uit de romp met de klap mee (weg van de aanvaller) plus
## een zwakkere zijwaartse splash - druppels vliegen rond en laten kleine
## vlekjes achter. Knop "wond-bloed" (0 = uit) schaalt de hoeveelheid.
func play_wound(world_dir: Vector3) -> void:
	var amount := int(round(4.0 * fx("wound_blood", 1.0)))
	if amount <= 0:
		return
	# wond-vertraging: spetters pas even NA het raakmoment (0 = direct).
	var del: float = fx("wound_delay", 0.0)
	if del > 0.0:
		var tw := create_tween()
		tw.tween_interval(del)
		tw.tween_callback(_do_wound.bind(world_dir, amount))
	else:
		_do_wound(world_dir, amount)


func _do_wound(world_dir: Vector3, amount: int) -> void:
	var dir := world_dir
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = -global_transform.basis.z
	dir = dir.normalized()
	var origin := global_position + Vector3(0.0, 0.55, 0.0) + dir * 0.08
	_spawn_blood_spurt(origin, dir, amount)
	if amount >= 3:
		# Backsplash: zwakker straaltje schuin opzij voor een voller beeld.
		var side := dir.rotated(Vector3.UP, randf_range(-1.2, 1.2))
		_spawn_blood_spurt(origin + Vector3(0.0, -0.12, 0.0), side, amount / 2)


func _spawn_blood_spurt(origin: Vector3, dir: Vector3, amount: int) -> void:
	var parent := get_parent()
	if parent == null or amount <= 0:
		return
	var base_dir := dir
	base_dir.y = 0.0
	if base_dir.length() < 0.01:
		base_dir = Vector3(randf() - 0.5, 0.0, randf() - 0.5)
	base_dir = base_dir.normalized()
	for i in amount:
		var drop := MeshInstance3D.new()
		var m := SphereMesh.new()
		var r := randf_range(0.025, 0.06) * fx("drop_size", 1.0)
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = 5
		m.rings = 3
		drop.mesh = m
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(randf_range(0.35, 0.55), 0.02, 0.02)
		drop.material_override = mat
		parent.add_child(drop)
		drop.global_position = origin
		# Kegel rond de spuitrichting; druppels vertrekken vlak na elkaar,
		# zodat het een straal is en geen wolk.
		var v := (base_dir + Vector3(randf() - 0.5, randf() * 0.5, randf() - 0.5) * 0.5).normalized()
		var dist := randf_range(0.12, 0.45)
		var apex := origin + v * dist * 0.6 + Vector3.UP * randf_range(0.02, 0.12)
		var ground := origin + v * dist
		ground.y = global_position.y + 0.02
		var tw := drop.create_tween()
		tw.tween_interval(float(i) * randf_range(0.008, 0.03))
		tw.tween_property(drop, "global_position", apex, randf_range(0.08, 0.14)).set_ease(Tween.EASE_OUT)
		tw.tween_property(drop, "global_position", ground, randf_range(0.12, 0.22)) 			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(drop, "scale", Vector3(0.3, 0.3, 0.3), 0.3)
		tw.tween_callback(drop.queue_free)
	# Plasje waar de straal neerkomt: begint bij de eerste druppels en is op
	# zijn grootst precies wanneer de straal klaar is met neerkomen.
	_spawn_blood(Vector3(origin.x, global_position.y, origin.z) + base_dir * 0.3, 1, 0.05, 0.18, 0.42)


## Grove bloedmist (kanon): halfdoorzichtige donkerrode flarden die uitzetten,
## opzij/omhoog driften en in ~0.7s vervagen. Puur visueel, ruimt zichzelf op.
## power = de "bloedmist"-knop (0 = uit).
func _spawn_blood_mist(center: Vector3, dir: Vector3, power: float) -> void:
	var parent := get_parent()
	if parent == null or power <= 0.0:
		return
	var blast := dir
	blast.y = 0.0
	if blast.length() < 0.01:
		blast = Vector3(randf() - 0.5, 0.0, randf() - 0.5)
	blast = blast.normalized()
	# Met blood_mist*-textures in assets/textures/blood/: paar billboard-quads
	# met echte wolkflarden (rijker beeld, minder nodig); anders de bol-flarden.
	var mist_tex := _blood_texture("blood_mist")
	var count := int(clampf(2.0 + 1.5 * power, 2.0, 6.0)) if mist_tex != null \
		else int(clampf(4.0 + 3.0 * power, 3.0, 12.0))
	for i in count:
		var puff := MeshInstance3D.new()
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if mist_tex != null:
			var q := QuadMesh.new()
			var qs := randf_range(0.5, 0.85) * (0.7 + 0.3 * power)
			q.size = Vector2(qs, qs)
			puff.mesh = q
			mat.albedo_texture = _blood_texture("blood_mist")
			mat.albedo_color = Color(1, 1, 1, randf_range(0.8, 1.0))
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			mat.billboard_keep_scale = true
			if randf() < 0.5:
				mat.uv1_scale = Vector3(-1.0, 1.0, 1.0)  # gespiegeld = extra variatie
		else:
			var m := SphereMesh.new()
			var r := randf_range(0.10, 0.22) * (0.7 + 0.3 * power)
			m.radius = r
			m.height = r * 2.0
			m.radial_segments = 12
			m.rings = 6
			puff.mesh = m
			mat.albedo_color = Color(randf_range(0.35, 0.55), 0.01, 0.02, randf_range(0.55, 0.75))
		puff.material_override = mat
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(puff)
		# DOORSCHOT: de mist begint aan de inslagkant (vlak voor het lijf) en
		# wordt door de kogel meegesleurd — een uitwaaierende kegel die tot
		# mist-dracht tegels achter het slachtoffer eindigt. Voorste flarden
		# vertrekken eerst, verste flarden reiken het verst en leven langer.
		var t := float(i) / maxf(float(count - 1), 1.0)
		puff.global_position = center - blast * 0.25 + blast * (0.5 * t) \
			+ Vector3(randf() - 0.5, randf() * 0.5, randf() - 0.5) * 0.15
		var reach: float = fx("mist_travel", 1.6)
		var dist := (0.3 + reach * t) * randf_range(0.85, 1.15)
		var drift := blast * dist \
			+ Vector3((randf() - 0.5) * (0.15 + 0.5 * t), randf_range(0.1, 0.35), (randf() - 0.5) * (0.15 + 0.5 * t))
		var life := randf_range(0.45, 0.7) + 0.3 * t
		var tw := puff.create_tween()
		tw.tween_interval(t * 0.07)
		tw.set_parallel(true)
		tw.tween_property(puff, "global_position", puff.global_position + drift, life) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var groei := (randf_range(1.7, 2.4) if mist_tex != null else randf_range(2.2, 3.2)) * (1.0 + 0.5 * t)
		tw.tween_property(puff, "scale", Vector3.ONE * groei, life) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(puff.material_override, "albedo_color:a", 0.0, life) \
			.set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(puff.queue_free)


## Eén stoot van de borst-fontein: de oorsprong zakt mee met het vallende
## lijf richting de torso-plek, en elke stoot waaiert een andere kant op —
## steeds meer met de val mee. Elke stoot laat via _spawn_blood_spurt zijn
## eigen spetter achter.
func _spurt_pulse(index: int, total: int, dir: Vector3, torso_off: float) -> void:
	var t := 0.0 if total <= 1 else float(index) / float(total - 1)
	var fall := transform.basis.z * torso_off
	var origin := global_position + Vector3.UP * (0.55 - 0.22 * t) + fall * (0.6 * t)
	var pdir := dir.rotated(Vector3.UP, randf_range(-0.6, 0.6))
	if fall.length() > 0.01:
		pdir = (pdir * (1.0 - 0.5 * t) + fall.normalized() * (0.4 + 0.5 * t)).normalized()
	_spawn_blood_spurt(origin, pdir, int(10.0 * fx("blood_spurt", 1.0)))


## Rode bloedwolk: een pluim mini-bolletjes die naar buiten/omhoog spatten en
## dan naar de grond vallen en krimpen (kortstondig, ruimt zichzelf op). Voor
## de kanon-explosie (centrum) en het "bloeden" van weggerukte vlees-delen.
func _spawn_blood_burst(center: Vector3, amount: int, dir: Vector3 = Vector3.ZERO) -> void:
	var parent := get_parent()
	if parent == null or amount <= 0:
		return
	for i in amount:
		var drop := MeshInstance3D.new()
		var m := SphereMesh.new()
		var r := randf_range(0.03, 0.08) * fx("drop_size", 1.0)
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = 5
		m.rings = 3
		drop.mesh = m
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(randf_range(0.4, 0.6), 0.02, 0.02)
		mat.emission_enabled = true
		mat.emission = Color(0.5, 0.0, 0.0)
		mat.emission_energy_multiplier = 0.3
		drop.material_override = mat
		parent.add_child(drop)
		drop.global_position = center
		var out := Vector3(randf() - 0.5, randf() * 0.8, randf() - 0.5).normalized()
		if dir != Vector3.ZERO:
			# Blast-bias: de fontein spuit overwegend met de klap mee.
			out = (dir.normalized() * 0.9 + out * 0.7).normalized()
		var dist := randf_range(0.15, 0.55)
		var apex := center + out * dist + Vector3.UP * randf_range(0.1, 0.4)
		var ground := Vector3(apex.x, global_position.y + 0.02, apex.z)
		# druppel-duur schaalt de hele vlucht (lager = snappier vallen).
		var dtempo := fx("drop_fall_time", 1.0)
		var tw := drop.create_tween()
		tw.tween_property(drop, "global_position", apex, 0.16 * dtempo).set_ease(Tween.EASE_OUT)
		tw.tween_property(drop, "global_position", ground, randf_range(0.2, 0.32) * dtempo) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(drop, "scale", Vector3(0.25, 0.25, 0.25), 0.5 * dtempo)
		# druppel-vlekkans bepaalt welk deel een vlek achterlaat; de vlek
		# verschijnt vlek-wacht na de inslag en groeit aan in vlek-groei
		# (gesynchroniseerd pad, dus zonder de algemene plas-wachttijd).
		if randf() < fx("drop_stain_chance", 0.35):
			tw.tween_callback(_spawn_blood.bind(ground, 1, 0.03,
				fx("drop_stain_delay", 0.05), fx("drop_stain_grow", 0.25)))
		tw.tween_callback(drop.queue_free)


## Wereldpositie van de vuurmond (waar flits + rook ontstaan). Per model
## instelbaar via model_tuning "muzzle": [rechts, hoogte, voor] — in te
## meten op de Model-tab van de tuner. Zonder tuning: generieke plek per type.
func muzzle_world() -> Vector3:
	var right := 0.08
	var up := 0.85
	var fwd := 0.45
	if _unit_type == 2:
		right = 0.0
		up = 0.55
		fwd = 0.7
	var m = model_tuning().get(_tune_key, {}).get("muzzle", null)
	if m is Array and (m as Array).size() == 3:
		right = float(m[0])
		up = float(m[1])
		fwd = float(m[2])
	return global_position + transform.basis.x * right \
		+ transform.basis.y * up - transform.basis.z * fwd


## Random dismemberment bij dood, in proportie met de klap (zie play_death).
## Laadt <model>_gibs.glb: losse, statische delen (Hat/ArmL/ArmR/LegL/LegR/
## Torso...). Kanon (strength >= 1.2): ~45% klapt ALLES uit elkaar, anders 2-4
## delen. Musket/melee: ~40% geen delen (gewone omvaller), anders 1-2 — met
## voorkeur voor het hoedje. Retour: true bij een volledige gib.
func _spawn_gibs(dir: Vector3, strength: float) -> bool:
	if _model_path == "" or _piece == null:
		return false
	var gibs_path := _gibs_pad()
	if not ResourceLoader.exists(gibs_path):
		return false
	var scene_parent := get_parent()
	if scene_parent == null:
		return false
	# Volledige explosie (kanon): alle delen vliegen weg; een enkel deel
	# brokkelt ter plekke neer voor variatie.
	var violence := clampf(strength / 1.4, 0.5, 1.2)
	var parts_root: Node3D = (load(gibs_path) as PackedScene).instantiate()
	scene_parent.add_child(parts_root)
	# Zelfde maat/rotatie/plek als het getunede lijf.
	parts_root.global_transform = (_piece as Node3D).global_transform
	var maat_f2 := _gib_maat_correctie(parts_root)
	if not is_equal_approx(maat_f2, 1.0):
		parts_root.scale *= maat_f2   # gibs stonden op een andere schaal
	apply_albedo_to(parts_root, team_texture(_model_path, team, true))  # bloederige team-texture
	var parts: Array = parts_root.find_children("*", "MeshInstance3D", true, false)
	if parts.is_empty():
		parts_root.queue_free()
		return false
	for part in parts:
		if randf() < 0.15:
			_drop_part(part as Node3D)
		else:
			_fling_part(part as Node3D, dir, violence)
	parts_root.add_to_group("battlefield_debris")
	if _cape != null:
		cape_weg(_cape)
		_cape = null
	verduister_later(parts_root)
	return true


## Deelnaam zonder punten, streepjes, spaties of cijfers: "Arm.L" -> "arml".
static func _kale_deelnaam(n: String) -> String:
	var uit := ""
	for teken in n.to_lower():
		if teken >= "a" and teken <= "z":
			uit += teken
	return uit


## Gibs-bestand naast het model: "_gibs.glb" of ".gibs.glb" (zoals de
## exportpijplijn het schrijft). Leeg als er geen is.
func _gibs_pad() -> String:
	if _model_path == "":
		return ""
	for kandidaat in [_model_path.get_basename() + "_gibs.glb",
			_model_path.get_basename() + ".gibs.glb"]:
		if ResourceLoader.exists(kandidaat):
			return kandidaat
	return _model_path.get_basename() + "_gibs.glb"


func _is_hat(node: Node) -> bool:
	return String(node.name).to_lower().contains("hat")


## Poel-maat per brokstuk (multiplier): elk stuk krijgt precies EEN poel
## recht onder zijn landingsplek — de romp een grote, ledematen een normale,
## het hoedje een kleintje. (Het musket bloedt nooit: _fling_weapon spawnt
## geen bloed.)
func _blood_size_for(part: Node3D) -> float:
	var n := String(part.name).to_lower()
	if n.contains("torso") or n.contains("body"):
		return 2.2
	if n.contains("hat"):
		return 0.7
	return 1.2


## Doelrotatie die een brokstuk/wapen plat op de grond legt: de langste
## lokale as van de mesh komt horizontaal, met een willekeurige draai en een
## klein kanteltje voor een natuurlijke ligging. Zo staat een romp of musket
## nooit rechtop en tolt er niets door op de grond.
func _flat_rotation(part: Node3D) -> Vector3:
	var mi: MeshInstance3D = part as MeshInstance3D
	if mi == null:
		var found: Array = part.find_children("*", "MeshInstance3D", true, false)
		if not found.is_empty():
			mi = found[0]
	var yaw := randf() * TAU
	if mi == null:
		return Vector3(0.0, yaw, 0.0)
	# De DUNSTE lokale as moet verticaal komen te staan → het object ligt dan
	# plat op zijn breedste vlak (romp op de rug, musket languit).
	var sz := mi.get_aabb().size
	var base := Basis()
	if sz.y <= sz.x and sz.y <= sz.z:
		base = Basis()  # y al de dunne as → ligt al plat
	elif sz.x <= sz.z:
		base = Basis(Vector3(0, 0, 1), deg_to_rad(90.0))  # x-as → omhoog
	else:
		base = Basis(Vector3(1, 0, 0), deg_to_rad(-90.0))  # z-as → omhoog
	# Willekeurige yaw + klein kanteltje voor een natuurlijke ligging.
	var wobble := Basis.from_euler(Vector3(
		deg_to_rad(randf_range(-8.0, 8.0)), 0.0, deg_to_rad(randf_range(-8.0, 8.0))))
	return (Basis(Vector3.UP, yaw) * wobble * base).get_euler()


## Lichte kill op een model met losse delen (hat/armL/armR/legL/legR als
## eigen mesh-objecten): soms wipt de hoed eraf en soms vliegt er één
## ledemaat af — de echte mesh verdwijnt en de gib-tegenhanger vliegt, dus
## nooit dubbele delen. Modellen zonder losse delen: er gebeurt niets.
func _shed_parts(dir: Vector3, kind: String = "melee") -> void:
	if _piece == null:
		return
	var live: Array = _piece.find_children("*", "MeshInstance3D", true, false)
	# Musket-schot: OF het hoedje wipt eraf OF er vliegt een ledemaat af,
	# nooit beide. Melee: alleen een ledemaat — een sabelhouw slaat geen
	# hoedje van je hoofd.
	if kind == "shot" and randf() < fx("hat_pop_chance", 0.55):
		if _shed_one(live, "hat", dir, fx("hat_fling_power", 1.5), fx("hat_fling_time", 1.8)):
			return
	if randf() < fx("limb_shed_chance", 0.4):
		# Het ledemaat laat pas even NA de klap los, terwijl het lijf al inzakt
		# (en dus nooit exact tegelijk met het hoedje).
		var tw := create_tween()
		tw.tween_interval(randf_range(0.1, 0.4))
		tw.tween_callback(_shed_first_limb.bind(live, dir))


## Ruk het eerste aanwezige losse ledemaat af (willekeurige volgorde).
func _shed_first_limb(live: Array, dir: Vector3) -> void:
	var limbs: Array = ["arml", "armr", "legl", "legr"]
	limbs.shuffle()
	for limb in limbs:
		if _shed_one(live, String(limb), dir, fx("limb_fling_power", 0.9), fx("limb_fling_time", 1.0)):
			break


## Verberg het levende deel (naam bevat part_name) en slinger de
## gib-tegenhanger weg. false als het model dit deel niet los heeft.
func _shed_one(live: Array, part_name: String, dir: Vector3, violence: float, time_scale: float = 1.0) -> bool:
	# ALLE delen van dit ledemaat, niet alleen het eerste (Max, 7 september).
	# Een arm bestaat uit Arm.L + Forarm.L en een been uit Upleg.L + Leg.L; de
	# zoeksleutel "arml" zit in "arml" en in "forarml", "legl" in "legl" en in
	# "uplegl". Wie hier stopt bij de eerste match laat het halve ledemaat aan
	# het lijf hangen, en kan zelfs het ene segment verbergen terwijl het andere
	# wegvliegt. Verse exports heten "Arm.L" / "Upleg.R"; kaal maken zodat
	# "arml" en "legr" matchen (Max, 29 juli).
	var targets: Array = []
	for mi in live:
		if _kale_deelnaam(String(mi.name)).contains(part_name) and (mi as MeshInstance3D).visible:
			targets.append(mi)
	if targets.is_empty():
		return false
	# Factie-kreet (besluit Max, 28 juli): alleen ALS er echt iets afgaat --
	# een arm, een been of het hoedje. Zonder afgevallen deel blijft het bij
	# de algemene doodskreet die game.gd al speelt.
	var start: Variant = _fling_limb_gibs(part_name, dir, violence, time_scale)
	if start == null:
		return false
	for mi in targets:
		(mi as MeshInstance3D).visible = false
	if not part_name.contains("hat"):
		# Bloed spuit uit het gat waar het ledemaat zat, van het lijf af.
		var out: Vector3 = (start as Vector3) - global_position
		_spawn_blood_spurt(start as Vector3, out, int(7.0 * fx("blood_spurt", 1.0)))
	return true


## Laad het gibs-bestand en slinger ALLE delen van dit ledemaat weg (een arm is
## Arm.L + Forarm.L, een been Upleg.L + Leg.L); de rest blijft verborgen.
## Geeft de wond-plek terug: de startpositie van het deel dat het dichtst bij de
## romp zat. Dat wordt geometrisch bepaald en niet uit de naam geraden, want bij
## deze modellen is "Leg" het ONDERbeen en "Upleg" het bovenbeen. null als het
## ledemaat niet in het gibs-bestand zit.
func _fling_limb_gibs(part_name: String, dir: Vector3, violence: float, time_scale: float = 1.0) -> Variant:
	if _model_path == "" or _piece == null:
		return null
	var gibs_path := _gibs_pad()
	if not ResourceLoader.exists(gibs_path):
		return null
	var scene_parent := get_parent()
	if scene_parent == null:
		return null
	var parts_root: Node3D = (load(gibs_path) as PackedScene).instantiate()
	scene_parent.add_child(parts_root)
	parts_root.global_transform = (_piece as Node3D).global_transform
	var maat_f := _gib_maat_correctie(parts_root)
	if not is_equal_approx(maat_f, 1.0):
		parts_root.scale *= maat_f   # gibs stonden op een andere schaal
	apply_albedo_to(parts_root, team_texture(_model_path, team, true))  # bloederige team-texture
	var chosen: Array = []
	for part in parts_root.find_children("*", "MeshInstance3D", true, false):
		# KAAL vergelijken, net als de levende kant (_shed_one): Godot maakt
		# van "Arm.L.001" bij het importeren "Arm_L_001", en "arm_l_001"
		# bevat "arml" niet. Met to_lower() matchte hier dus alleen het
		# hoedje en vloog er NOOIT een ledemaat af, bij geen enkele factie
		# (gevonden 15 augustus, toen Max het bij de nieuwe modellen miste).
		if _kale_deelnaam(String(part.name)).contains(part_name):
			chosen.append(part as Node3D)
		else:
			(part as MeshInstance3D).visible = false
	if chosen.is_empty():
		parts_root.queue_free()
		return null
	# Wond-plek = het segment dat het dichtst bij de romp zat.
	var start: Vector3 = (chosen[0] as Node3D).global_position
	var dichtst: float = start.distance_to(global_position)
	for deel in chosen:
		var d: float = (deel as Node3D).global_position.distance_to(global_position)
		if d < dichtst:
			dichtst = d
			start = (deel as Node3D).global_position
	# Elk segment krijgt zijn eigen ruis mee in _fling_part, dus ze vliegen als
	# een groep dezelfde kant op zonder als een blok aan elkaar te plakken.
	for deel in chosen:
		_fling_part(deel as Node3D, dir, violence, time_scale)
	parts_root.add_to_group("battlefield_debris")
	if _cape != null:
		cape_weg(_cape)
		_cape = null
	verduister_later(parts_root)
	return start


## Eén brokstuk wegslingeren: boog in de klap-richting + radiale spreiding,
## tollend neerkomen en blijven liggen. Alleen tweens op het deel zelf.
## violence (0..1) schaalt de afstand en hoogte van de worp.
## time_scale rekt de vlucht- (en dus hang-)tijd op; het hoedje krijgt er meer
## zodat hij zwevend wegtolt i.p.v. meteen neer te ploffen.
func _fling_part(part: Node3D, dir: Vector3, violence: float = 1.0, time_scale: float = 1.0) -> void:
	# Elk deel valt nét anders: kracht en hangtijd krijgen per deel ruis, zodat
	# bij een explosie nooit twee armen synchroon wegvliegen of tegelijk landen.
	violence *= randf_range(0.85, 1.2)
	time_scale *= randf_range(0.75, 1.35)
	var radial := part.global_position - global_position
	radial.y = 0.0
	if radial.length() > 0.01:
		radial = radial.normalized()
	else:
		radial = Vector3(randf() - 0.5, 0.0, randf() - 0.5).normalized()
	var power := (0.5 + 0.85 * violence) * fx("gib_fling_power", 1.0)
	# Schot-richting domineert: alles knalt duidelijk WEG van de bron (schot van
	# links → debris naar rechts). Radiale spreiding + ruis alleen voor variatie.
	var fling := (dir * 1.15 + radial * 0.3 + Vector3(randf() - 0.5, 0.0, randf() - 0.5) * 0.3) * power
	fling.y = 0.0
	var from := part.global_position
	var land := Vector3(from.x, global_position.y + 0.06, from.z) + fling
	var peak := from.lerp(land, 0.5) + Vector3.UP * randf_range(0.35, 0.7) * power * time_scale
	# Bloeden: een vlees-deel (geen hoed/musket) spat druppels op het punt waar
	# het van het lijf wordt gerukt.
	if not _is_hat(part):
		_spawn_blood_burst(from, int(4 * fx("blood_burst", 1.0)))
	var t_up := randf_range(0.16, 0.24) * time_scale
	var t_down := randf_range(0.16, 0.24) * time_scale
	# Tollen alleen tíjdens de vlucht (stopt bij landen), en bescheiden:
	# ~een kwart tot halve omwenteling om één overheersende as.
	var euler := Vector3.ZERO
	euler[randi() % 3] = randf_range(1.5, 3.0) * (0.4 + 0.6 * violence) * fx("gib_spin", 1.0) * (1.0 if randf() < 0.5 else -1.0)
	euler += Vector3(randf_range(-0.35, 0.35), randf_range(-0.35, 0.35), randf_range(-0.35, 0.35))
	var spin := part.create_tween()
	spin.tween_property(part, "rotation", part.rotation + euler, t_up + t_down) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var arc := part.create_tween()
	arc.tween_property(part, "global_position", peak, t_up).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	arc.tween_property(part, "global_position", land, t_down).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# Het hoedje tikt hoorbaar op de grond (Max, 28 juli). Andere lichaamsdelen
	# krijgen geen eigen geluid: dat wordt een kakofonie bij een gib-explosie.
	if String(part.name).to_lower().contains("hat"):
		arc.tween_callback(func() -> void: Audio.play_getuned("val_hoed"))
	# Bij het landen snel plat op de grond draaien en blijven liggen.
	arc.tween_property(part, "rotation", _flat_rotation(part), 0.12)
	# Eén poel per stuk, recht onder de landingsplek. Timing strak en
	# tunebaar: gib-poel-wacht na het landen, volgroeid in gib-poel-groei.
	_spawn_blood(land, 1, 0.02, t_up + t_down + fx("gib_pool_delay", 0.1),
		fx("gib_pool_grow", 0.45), _blood_size_for(part), "blood_pool")


## Zacht in elkaar zakken: het deel ploft vrijwel ter plekke op de tegel met
## een kleine kantel — het "lijk op de grond"-gedeelte van een lichte gib.
func _drop_part(part: Node3D) -> void:
	var from := part.global_position
	var land := Vector3(
		from.x + randf_range(-0.08, 0.08),
		global_position.y + 0.05,
		from.z + randf_range(-0.08, 0.08))
	var drop := part.create_tween()
	drop.tween_property(part, "global_position", land, randf_range(0.15, 0.3)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Meteen plat neerleggen.
	drop.parallel().tween_property(part, "rotation", _flat_rotation(part), 0.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Eén poel per stuk, recht onder de landingsplek (zelfde timing-knoppen).
	_spawn_blood(land, 1, 0.02, 0.25 + fx("gib_pool_delay", 0.1),
		fx("gib_pool_grow", 0.45), _blood_size_for(part), "blood_pool")


func _on_anim_finished(anim_name: String) -> void:
	# Eenmalige animaties (aanval) keren terug naar idle; lopen stuurt game.gd zelf.
	# Voorvoegsel ("lib/attack") en variant-nummer ("attack2") strippen.
	var n := String(anim_name)
	n = n.get_slice("/", n.get_slice_count("/") - 1).rstrip("0123456789")
	# Eenmalige clips (schieten, melee, hit-reactie) keren terug naar idle —
	# ook onder hun synoniem-namen (fire, bayonet, sword, hurt, ...).
	var oneshots: Array = [anim_attack, anim_melee, anim_hit]
	oneshots.append_array(ANIM_ALIASES.get("attack", []))
	oneshots.append_array(ANIM_ALIASES.get("melee", []))
	oneshots.append_array(ANIM_ALIASES.get("hit", []))
	oneshots.append("ready")
	oneshots.append_array(ANIM_ALIASES.get("ready", []))
	if n in oneshots:
		play_idle()


# --- Facing ------------------------------------------------------------------

## Draai de pion zodat de voorkant (-Z) naar de grid-richting dir=(dx, dz) wijst.
func face_dir(dir: Vector2i) -> void:
	if dir == Vector2i.ZERO or not is_inside_tree():
		return
	var d := Vector3(float(dir.x), 0.0, float(dir.y))
	look_at(global_position + d, Vector3.UP)


# --- Selectie / hover / dim --------------------------------------------------

func set_selected(selected: bool) -> void:
	_selected = selected
	_update_material()


func set_hovered(hovered: bool) -> void:
	_hovered = hovered
	_update_material()


func set_dimmed(dimmed: bool) -> void:
	_dimmed = dimmed
	_update_material()


func _update_material() -> void:
	# Teamkleur + status op het blokje (fallback) én de team_tint-delen van het stuk.
	var mat: StandardMaterial3D
	if _selected:
		mat = _select_material
	elif _hovered:
		mat = _hover_material
	elif _dimmed:
		mat = _dim_material
	else:
		mat = _base_material
	_mesh.material_override = mat
	for node in _tint_nodes:
		node.material_override = mat
	# Ring (werkt ook met een model eroverheen).
	if _selected:
		_ring.visible = true
		_ring.material_override.albedo_color = Color(0.3, 1.0, 0.4)
		_ring.material_override.emission = Color(0.3, 1.0, 0.4)
	elif _hovered:
		_ring.visible = true
		_ring.material_override.albedo_color = Color(1.0, 0.95, 0.5)
		_ring.material_override.emission = Color(1.0, 0.95, 0.5)
	else:
		_ring.visible = false


## Korte witte flits op het hele stuk bij een treffer; daarna herstellen.
func flash_hit() -> void:
	var flash := StandardMaterial3D.new()
	flash.albedo_color = Color(1.0, 1.0, 1.0)
	flash.emission_enabled = true
	flash.emission = Color(1.0, 1.0, 1.0)
	flash.emission_energy_multiplier = 1.6
	_mesh.material_override = flash
	for node in _tint_nodes:
		node.material_override = flash
	var tween := create_tween()
	tween.tween_interval(0.12)
	tween.tween_callback(_update_material)


## Korte glim-flits (bv. bij koppelen); ring dooft na een moment weer uit.
func flash_ring(color: Color) -> void:
	_ring.visible = true
	_ring.material_override.albedo_color = color
	_ring.material_override.emission = color
	var tween := create_tween()
	tween.tween_interval(0.4)
	tween.tween_callback(func() -> void:
		if not _selected and not _hovered:
			_ring.visible = false)


func set_stats_label(_active: bool, _hp: int, _stamina: int) -> void:
	# HP en stamina worden getoond als blokjes-raster (game.gd). Het Label3D is
	# van de type-letter (set_unit_type) — hier dus níét meer wissen.
	pass


## v4.1: vast eenheidstype, voor beide spelers altijd zichtbaar.
## Instanceert het speelstuk (scenes/game/pieces/) — de vorm zelf toont het type
## (soldaat/paard/kanon), dus geen letter meer erboven.
func set_unit_type(unit_type: int) -> void:
	_label.text = ""
	_unit_type = unit_type
	if _model != null:
		return  # echt karaktermodel (model_scene): niets extra's nodig
	var scene: PackedScene = PIECE_SCENES.get(unit_type)
	if scene == null:
		return
	_swap_piece(scene)


## Karaktermodel op basis van factie + type + gekoppelde kaart (null = neutraal).
## De dominante stat van de kaart bepaalt het archetype: een Muis-kaart 1/5/1
## wordt bv. `muis/infanterie_spd.glb` (dunne schichtige muis). Ontbreekt het
## bestand, dan valt dit terug op `_basis.glb` en anders op het geometrische
## stuk met een subtiel archetype-silhouet. Aanroepen mag elke refresh
## (idempotent via _char_key).
## Figuranten (MODEL-WISHLIST 3d, besluit Max 28 juli): een pion ZONDER
## gekoppelde kaart vecht niet -- dat is de tamboer, de vaandeldrager, de
## marketentster. Het KARAKTERMODEL blijft gewoon infantry_base; alleen de
## prop in de hand wordt een trommel of vaandel (zelfde mechaniek als het
## musket). Puur cosmetisch; de staat verandert niet. Deterministisch op
## pion-id (nooit randi), dus replays zien er identiek uit. ROL_DICHTHEID 3 =
## ongeveer een op de drie ongekoppelde pionnen (1 = iedereen, 0 = uit).
## Sinds 12 september staat hij op 0 (Max: "sommige hebben nu wel een prop
## vast anders dan de vlag of trom, dat niet doen graag"): in het spel dragen
## ALLEEN de vaandeldrager en de tamboer een prop. De extra rollen blijven
## bestaan voor de Model-tuner (rol_override) en prop_for; het diorama
## gebruikt prop_drum/prop_barrel/prop_horn/prop_axe los van de pionnen.
## Elk leger heeft ALTIJD een vaandeldrager en een tamboer (besluit Max,
## 28 juli): de eerste twee infanteristen krijgen die rol vast. De rest van
## de figuranten wordt daarna uitgedund met ROL_DICHTHEID.
## Vlaggen en trommels worden RUIMTELIJK verdeeld (Max, 30 juli, met een foto
## van twee vaandels naast elkaar: "staan niet genoeg uit elkaar"). Een
## volgnummer in de rij zegt niets over waar een pion op het bord staat, dus
## game.gd rekent de afstanden uit en zet de rol hier in `rol_vast`. Minimaal 4
## vakken tussen twee gelijke rollen; zie `_verdeel_figurant_rollen` in game.gd.
const ROLLEN_EXTRA := ["horn", "sapper", "canteen", "drummajor"]
## Rol -> geleverde prop-naam (props/LEESMIJ.md); zie prop_for.
const PROP_ALIAS := {"sapper": "prop_axe", "canteen": "prop_barrel", "drummajor": "prop_mace"}
## Kleine legers krijgen maar een vaandel en een tamboer; vanaf dit aantal
## infanteristen komt het tweede stel erbij (besluit Max, 28 juli).
const TWEEDE_STEL_VANAF := 8
const ROL_DICHTHEID := 0   # hoorn/bijl/vat/staf: UIT sinds 12 september (was 5: sporadisch, na de vaste vier)


var _doctrine: int = 0  # factie van dit model (voor de factie-geluiden)
var _archetype: String = "base"  # base/spd/hp/atk/mix -- geluiden mogen per model
var _kreet_af: bool = false  # per dood maar één kreet
var _dodelijke_kracht: float = 0.7  # kracht van de dodelijke klap (kanon >= 1.2)
## game.gd zet dit als hij de kanonkreet al VOOR de inslag heeft gespeeld,
## zodat hij hier niet nog een keer klinkt. In de Model-tuner staat hij op
## false, dus daar hoor je de kreet die bij de gekozen kracht hoort.
var kreet_al_gespeeld: bool = false
var _rol: String = ""   # actieve figurant-rol ("" = gewone soldaat met musket)

## Model-tuner: forceer een figurant-rol ongeacht de kaart ("" = normaal
## gedrag). Zo kun je een trommel of vaandel in de hand fijnafstellen.
var rol_override: String = ""

## Rol die game.gd ruimtelijk heeft toegewezen ("flag"/"drum"/""). Staat los van
## rol_override (tuner) en van de dichtheidsregel voor de extra props.
## COSMETISCH: verhuist als een drager sneuvelt of koppelt, en verschijnt alleen
## op ongekoppelde pionnen.
@export var rol_vast: String = ""

## De ECHTE rol uit Pawn.rol ("flag"/"drum"/""), toegewezen in de opstelfase.
## Verhuist nooit en levert buit op als de pion sneuvelt (C15 / 4.3.2).
##
## Anders dan rol_vast is dit geen aankleding maar een eigenschap van de pion.
## Het PROP in de hand verdwijnt wel zodra hij koppelt -- dan vecht hij en hoort
## zijn musket erin -- maar het rol-icoon onder de HP-blokjes blijft staan, zodat
## je ziet dat hier nog steeds buit te halen valt.
@export var rol_echt: String = ""


## Volgnummer van deze pion binnen het EIGEN leger (0 = eerste infanterist).
## game.gd zet dit bij het bouwen van de view; -1 = geen rol (bv. de
## opstellings-schaduw). Per leger, niet globaal, zodat beide kanten hun
## eigen vaandeldrager en tamboer hebben.
@export var figurant_index: int = -1

## Aantal infanteristen in dit leger (game.gd vult dit): bepaalt of het tweede
## vaandel/tamboer-stel erbij komt.
@export var figurant_totaal: int = 0


func _rol_voor_pion() -> String:
	if figurant_index < 0:
		return ""
	# Vaandel en trommel komen van game.gd: die kent de posities en zet ze
	# minimaal 4 vakken uit elkaar.
	if rol_vast != "":
		return rol_vast
	# De sporadische extra's (hoorn, bijl, vat, staf) mogen wel op volgnummer:
	# die hoeven niet verspreid te staan, ze zijn juist toevallige aankleding.
	if ROL_DICHTHEID <= 0 or ROLLEN_EXTRA.is_empty():
		return ""
	if figurant_index % ROL_DICHTHEID != 0:
		return ""
	return ROLLEN_EXTRA[(figurant_index / ROL_DICHTHEID) % ROLLEN_EXTRA.size()]


## Attribuut-prop bij een rol: eerst een factie-eigen variant, anders de
## gedeelde set in assets/models/props/. Leeg = niets gevonden (dan pakt
## _attach_weapon gewoon het musket, zodat een half afgemaakte set niets breekt).
static func prop_for(rol: String, fac: String) -> Dictionary:
	# Alias: het vaandel is in de praktijk gewoon een stok, dus prop_pole telt
	# ook als prop_flag (zo hoeft niemand bestanden te hernoemen).
	var namen: Array = ["prop_" + rol]
	if rol == "flag":
		namen.append("prop_pole")
	# De extra figuranten heten in de code naar hun rol (sapper, canteen,
	# drummajor) maar de props zijn geleverd onder de naam van het VOORWERP
	# (props/LEESMIJ.md: prop_axe = sapeur, prop_barrel = marketentster,
	# prop_mace = tamboer-majeur). Zonder deze aliassen vond geen van de drie
	# ooit zijn prop, verborg _attach_weapon het ingebakken musket en hing
	# hij een onafgestelde losse musket op: het "zwevende wapen" naast een
	# ontkoppelde basispion (Max, 8 september).
	if PROP_ALIAS.has(rol):
		namen.append(String(PROP_ALIAS[rol]))
	for naam in namen:
		# Eerst een factie-eigen prop, dan de gedeelde set. De sleutel blijft
		# "<factie>/<naam>" of "props/<naam>" -- dus onafhankelijk van de map
		# waarin het bestand ligt, anders raakt bestaande tuning los.
		for paar in [[MODELS_DIR + fac, fac], [MODELS_DIR + "props", "props"]]:
			for ext in [".glb", ".fbx"]:
				var pad := Bestandsindex.vind(String(paar[0]), String(naam) + ext)
				if pad != "" and ResourceLoader.exists(pad):
					return {"file": pad, "key": "%s/%s" % [String(paar[1]), naam]}
	return {"file": "", "key": ""}


func set_character(doctrine: int, unit_type: int, card) -> void:
	if _model != null:
		return
	var arch: String = "base"
	if card != null:
		arch = Constants.card_archetype(card.hp, card.stamina, card.attack)
	# Figurant-rol: het KARAKTER blijft gewoon base; alleen de prop in de hand
	# wordt een trommel/vaandel.
	if rol_override != "":
		_rol = rol_override  # tuner: vaste rol, ook mét kaart
	elif unit_type == Constants.UnitType.INFANTRY and card == null:
		# Ongekoppeld: de ECHTE drager toont zijn vaandel of trom; heeft hij geen
		# echte rol, dan de cosmetische aankleding (hoorn, bijl, vat, staf).
		_rol = rol_echt if rol_echt != "" else _rol_voor_pion()
	else:
		# GEKOPPELD (besluit Max, 7 september): het prop gaat weg en je ziet het
		# vecht-karakter dat bij die kaart hoort, met zijn musket in de handen.
		# Dat hij drager is blijft zichtbaar aan het rol-icoon onder de
		# HP-blokjes -- dat staat er altijd, gekoppeld of niet. Zo klopt het
		# beeld ("deze man vecht nu") met de regel ("en is nog steeds 2 punten
		# waard"), zonder dat er een trom in zijn hand hangt tijdens een melee.
		_rol = ""
	var key := "%d:%d:%s:%s" % [doctrine, unit_type, arch, _rol]
	if key == _char_key:
		return
	_char_key = key
	_unit_type = unit_type
	_doctrine = doctrine
	_archetype = arch
	var fac: String = Constants.doctrine_folder(doctrine)
	var tname: String = Constants.unit_type_file(unit_type)
	# Zoekvolgorde (Max, 29 juli -- de nieuwe export is de leidraad): eerst de
	# korte naam, dan de naam zoals de exportpijplijn hem levert
	# (<type>_<archetype>_<factie>.glb), dan terugval op base.
	# Alleen BESTANDSNAMEN: Bestandsindex zoekt ze op onder de factie-map, in
	# welke submap ze ook liggen (infanterie/, wapens/, ...). Zo kan de indeling
	# veranderen zonder dat het spel eraan hoeft (Max, 30 juli).
	var candidates: Array = []
	for naam in ["%s_%s.glb" % [tname, arch], "%s_%s_%s.glb" % [tname, arch, fac],
			"%s_base.glb" % tname, "%s_base_%s.glb" % [tname, fac]]:
		var gevonden := Bestandsindex.vind(MODELS_DIR + fac, String(naam))
		if gevonden != "":
			candidates.append(gevonden)
	for path in candidates:
		if ResourceLoader.exists(path):
			_tune_key = "%s/%s" % [fac, String(path).get_file().get_basename()]
			_model_path = path
			_preload_gib_assets(path)  # gib-glb + gore alvast op de achtergrond laden
			_swap_piece(load(path), true)  # auto-fit: schaal/grond/180°
			_attach_weapon(fac)
			return
	# Nog geen model-bestand: geometrisch stuk + archetype-silhouet.
	if _piece == null:
		var scene: PackedScene = PIECE_SCENES.get(unit_type)
		if scene != null:
			_swap_piece(scene)
	if _piece != null:
		_piece.scale = ARCHETYPE_SCALE.get(arch, Vector3.ONE)


## Vervang het huidige stuk door een nieuwe scene (geometrisch of .glb) en
## verzamel de team-kleurbare delen. GeometryInstance3D dekt zowel CSG-vormen
## (huidige stukken) als MeshInstance3D (geïmporteerde .glb-modellen).
## auto_fit: normaliseer een (AI-gegenereerd) model naar tegelmaat/richting.
func _swap_piece(scene: PackedScene, auto_fit: bool = false) -> void:
	if _piece != null:
		_piece.queue_free()
		_piece = null
		swaps += 1
	if _sokkel != null:
		_sokkel.queue_free()
		_sokkel = null
	_tint_nodes = []
	_piece = scene.instantiate()
	add_child(_piece)
	# AnimationPlayer in het stuk aanhaken (bv. een .glb met idle/walk/attack/die).
	# De geometrische stukken hebben er geen — dan blijft _anim gewoon null.
	_anim = _find_anim_player(_piece)
	_variant_cache = {}
	# Verse exports leveren Mixamo-namen ("Death 1"); opschonen zodat het spel
	# ze vindt. Al nette namen blijven onaangeroerd.
	_normaliseer_clipnamen()
	if _anim != null:
		_anim.animation_finished.connect(_on_anim_finished)
	if auto_fit:
		# Meet in de houding die de speler ook ZIET: het eerste idle-frame.
		# De rustpose (A-pose) van de generator wijkt daar soms fors van af —
		# dan stond het model alleen in T-pose goed, en op het bord zwevend
		# en uit het midden (de -0.4/x/z-compensaties van eerder).
		if _anim != null:
			var idles := _variants_of(anim_idle)
			if not idles.is_empty():
				_anim.play(idles[0])
				_anim.seek(0.0, true)
		_auto_fit_model(_piece)
	if _anim != null:
		_make_loops()
		play_idle()
	for node in _piece.find_children("*", "GeometryInstance3D", true, false):
		if node.is_in_group("team_tint"):
			_tint_nodes.append(node)
	_apply_team_texture()
	# Geen team-sokkel meer onder .glb-modellen (besluit 6 juli): het
	# team-onderscheid komt straks van de _team1/_team2-textures.
	# Placeholder-blokje + neusje verbergen; het stuk heeft zelf een voorkant (-Z).
	_mesh.visible = false
	_marker.visible = false
	_update_material()


## Bepaal welke wapen-mesh + tuning-sleutel bij een model horen. Voorkeur:
## een per-model wapen naast het model (<model>_<soort>.glb, eigen sleutel),
## anders het factie-wapen (<factie>/<soort>.glb). Zo krijgt elk model dat met
## z'n eigen wapen wordt geleverd dat automatisch, met eigen fijnafstelling.
## soort = "musket" (infanterie) of "melee" (big bro: cavalry_<arch>_melee.glb,
## zie MODEL-WISHLIST 3c-2 -- ingebouwd 16 augustus).
static func weapon_for(model_path: String, fac: String, soort: String = "musket") -> Dictionary:
	var basis := model_path.get_file().get_basename()
	for ext in [".glb", ".fbx"]:
		var per := Bestandsindex.vind(MODELS_DIR + fac, basis + "_" + soort + ext)
		if per != "" and ResourceLoader.exists(per):
			return {"file": per, "key": "%s/%s_%s" % [fac, basis, soort]}
	for ext in [".glb", ".fbx"]:
		var fp := Bestandsindex.vind(MODELS_DIR + fac, soort + ext)
		if fp != "" and ResourceLoader.exists(fp):
			return {"file": fp, "key": "%s/%s" % [fac, soort]}
	return {"file": "", "key": "%s/%s" % [fac, soort]}


## Wapen-prop (musket) aan de rechterhand van het karaktermodel. Conventie:
## assets/models/<factie>/musket.glb of .fbx (statische mesh). De prop wordt
## automatisch op musketlengte (~0.55 wereld-unit) geschaald; fijnafstelling
## via model_tuning.json sleutel "<factie>/musket":
##   {"scale": 1.0, "pos": [x,y,z], "rot": [graden x,y,z]}
## Lichaamsdelen die we kennen; al het andere geskinde meshje in het model is
## meegebakken uitrusting (het musket zit als los meshje aan RightHand).
const LIJF_DELEN: Array = ["arm", "forarm", "leg", "upleg", "body", "head", "hat", "tail", "foot"]


## Naamwoorden die een INGEBAKKEN wapen verraden: de generator levert het als
## tripo_node_<uuid>, maar na een Blender-bewerking kan het ook gewoon
## "musket" of "sabre" heten. Melee-woorden erbij sinds 16 augustus: de big
## bros komen net als de infanterie met hun wapen vast in het geanimeerde
## model (zonder herkenning zou het wapen dubbel staan: ingebakken + prop).
## "blade" staat er bewust NIET in (shoulder_blade zou vals matchen).
const WAPEN_WOORDEN: Array = ["musket", "rifle", "gun", "weapon", "triponode",
	"sabre", "saber", "sword", "axe", "lance", "pike", "spear", "cutlass",
	"scythe", "hatchet", "falchion", "dagger"]


## Alle INGEBAKKEN wapen-meshes in het model (de tripo_node/wapen-meshes die
## de generator meelevert). Herkenning: een wapenwoord of een naamloos
## generator-meshje, en NOOIT iets dat als lijfdeel herkend wordt — onbekende
## lijfdelen van oudere modellen blijven zo gewoon staan. Artillerie doet
## niet mee: het kanon IS het model, en mesh-namen als "gunner" of
## "gun_carriage" zouden vals als handwapen matchen.
func _vind_ingebakken_wapens() -> Array:
	var uit: Array = []
	if _piece == null or _unit_type == Constants.UnitType.ARTILLERY:
		return uit
	for mi in _piece.find_children("*", "MeshInstance3D", true, false):
		var kaal := _kale_deelnaam(String(mi.name))
		var is_lijf := false
		for deel in LIJF_DELEN:
			if kaal.contains(String(deel)):
				is_lijf = true
				break
		if is_lijf:
			continue
		for woord in WAPEN_WOORDEN:
			if kaal.contains(String(woord)):
				uit.append(mi)
				break
	return uit


## Diagnose (zweefcheck, 8 september): waar hangt het wapen ten opzichte van de
## rechterhand? {afstand, wapen, bron}; afstand -1 als er geen wapen of geen
## hand-bot is. bron = "ingebakken" (geskind/bot-geparent mesh) of "prop".
func wapen_hand_afstand() -> Dictionary:
	var uit: Dictionary = {"afstand": -1.0, "wapen": "", "bron": ""}
	if _piece == null:
		return uit
	var skels: Array = _piece.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return uit
	var skel: Skeleton3D = skels[0]
	var bone := -1
	for cand in ["mixamorig:RightHand", "RightHand"]:
		bone = skel.find_bone(cand)
		if bone >= 0:
			break
	if bone < 0:
		for i in skel.get_bone_count():
			if String(skel.get_bone_name(i)).contains("RightHand"):
				bone = i
				break
	if bone < 0:
		return uit
	var hand: Vector3 = (skel.global_transform * skel.get_bone_global_pose(bone)).origin
	var wapen: Node3D = null
	if _weapon != null and is_instance_valid(_weapon):
		wapen = _weapon
		uit.bron = "prop"
	elif not _baked_wapens.is_empty() and is_instance_valid(_baked_wapens[0]):
		wapen = _baked_wapens[0]
		uit.bron = "ingebakken"
	if wapen == null:
		return uit
	var mi: MeshInstance3D = wapen as MeshInstance3D
	if mi == null:
		var kinderen: Array = wapen.find_children("*", "MeshInstance3D", true, false)
		if kinderen.is_empty():
			return uit
		mi = kinderen[0]
	var midden: Vector3 = mi.global_transform * mi.get_aabb().get_center()
	uit.afstand = midden.distance_to(hand)
	uit.wapen = String(mi.name)
	return uit


## Het meegebakken musket verbergen — alleen nog voor de PROP-route (muis,
## figuranten, modellen zonder eigen musket-glb): daar hangen we zelf een prop
## in de hand en zou het ingebakken wapen dubbel staan. Sinds 16 augustus is
## de hoofdroute juist om het ingebakken musket te LATEN staan (zie
## _attach_weapon): geskind beweegt het met richten en steken mee.
func _verberg_ingebakken_wapen() -> void:
	for mi in _vind_ingebakken_wapens():
		(mi as MeshInstance3D).visible = false


func _attach_weapon(fac: String) -> void:
	if _unit_type == Constants.UnitType.ARTILLERY:
		return  # het kanon IS het model; geen handwapen
	# Infanterie draagt het musket; de big bro (cavalerie) zijn melee-wapen
	# (sabel/bijl/lans, MODEL-WISHLIST 3c-2 -- ingebouwd 16 augustus). Zodra
	# cavalry_<arch>_melee.glb of <factie>/melee.glb naast het model ligt,
	# hangt hij vanzelf in de hand; tot die tijd vecht de big bro met blote
	# handen (wp.file leeg = nette no-op).
	var soort := "melee" if _unit_type == Constants.UnitType.CAVALRY else "musket"
	_baked_wapens = []
	_baked_prop_pad = ""
	# Besluit Max (16 augustus): draagt het model zijn musket MEEGEBAKKEN, dan
	# is dát het wapen. Het is geskind, dus het richt, draagt en steekt met de
	# animaties mee — precies wat een stijve hand-prop nooit kan. Geen prop
	# erbovenop; bij de dood verbergt _los_wapen_voor_worp dit mesh en vliegt
	# de statische musket-glb vanaf de hand weg. Figuranten (trommel/vaandel)
	# en modellen zonder eigen musket-glb houden de oude prop-route.
	var ingebakken: Array = _vind_ingebakken_wapens()
	# Vangrail: alleen wapens die echt MEEBEWEGEN (geskind, of bot-geparent →
	# BoneAttachment3D). Een statisch meegebakken musket (sommige oudere
	# modellen) zou stokstijf in de lucht hangen — die blijven op de prop-route.
	var meebewegend: Array = []
	for mi in ingebakken:
		var beweegt: bool = mi.get_parent() is Skeleton3D
		var n: Node = mi.get_parent()
		while n != null and n != _piece and not beweegt:
			if n is BoneAttachment3D:
				beweegt = true
			n = n.get_parent()
		if beweegt:
			meebewegend.append(mi)
	# Een rol telt hier alleen mee als er ook echt een prop voor ligt. Een rol
	# ZONDER prop (bestand weg of verkeerd genoemd) houdt gewoon zijn
	# ingebakken musket: de oude terugval (musket verbergen en een statische
	# musket-glb ophangen) zette op een baked model een wapen zonder
	# afstelling 0,44 naast de hand (8 september).
	var rp: Dictionary = {"file": "", "key": ""}
	if _rol != "":
		rp = prop_for(_rol, fac)
	var rol_met_prop: bool = String(rp["file"]) != ""
	if not rol_met_prop and not meebewegend.is_empty() and meebewegend.size() == ingebakken.size():
		var bp := weapon_for(_model_path, fac, soort)
		if String(bp["file"]) != "":
			_baked_wapens = meebewegend
			_baked_prop_pad = String(bp["file"])
			# Sleutel WEL zetten, ook al leest de baked-route geen tuning: de
			# Model-tuner toont en bewerkt _weapon_tune_key, en zonder deze
			# regel bleef de declaratie-default "mouse/musket" actief — elke
			# hand-schuifje-draai op een baked model zou dan stilletjes de
			# MUIS-afstelling overschrijven (gevonden in review, 16 augustus).
			_weapon_tune_key = String(bp["key"])
			# Warm laden (zelfde patroon als _preload_gib_assets): de doodsworp
			# pakt hem straks zonder frame-hapering uit de cache.
			ResourceLoader.load_threaded_request(_baked_prop_pad)
			# NU pas kan de wapenjas erop: _apply_team_texture draaide in
			# _swap_piece, toen _baked_prop_pad nog leeg was.
			_zet_wapenjas()
			return
	_verberg_ingebakken_wapen()
	var wp := weapon_for(_model_path, fac, soort)
	if rol_met_prop:
		# Figurant: trommel/vaandel/attribuut in plaats van het musket. Een
		# rol zonder prop komt hier alleen nog op een model ZONDER ingebakken
		# musket (oude modellen) en krijgt dan het gewone, afgestelde wapen.
		wp = rp
	var path: String = wp["file"]
	_weapon_tune_key = wp["key"]
	if path == "":
		return
	var skels: Array = _piece.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return
	var skel: Skeleton3D = skels[0]
	var bone := -1
	for cand in ["mixamorig:RightHand", "RightHand"]:
		bone = skel.find_bone(cand)
		if bone >= 0:
			break
	if bone < 0:
		for i in skel.get_bone_count():
			if String(skel.get_bone_name(i)).contains("RightHand"):
				bone = i
				break
	if bone < 0:
		return
	var att := BoneAttachment3D.new()
	skel.add_child(att)
	att.bone_idx = bone
	var prop: Node3D = (load(path) as PackedScene).instantiate()
	att.add_child(prop)
	# Auto-schaal: langste as van de prop → ~0.55 wereld-unit (musketlengte),
	# gecorrigeerd voor alle ouder-schalen (skelet/auto-fit).
	# BUG-FIX (Max, 30 juli: reuzengeweer bij het plaatsen van versterkingen).
	# De prop wordt genormaliseerd op de SCHAAL VAN DE OUDER, en die komt uit de
	# bot-aanhechting. Bij een vers gespawnde pion waren de bot-transforms nog
	# niet doorgerekend: dan leest hij 1.0 in plaats van ~0.008 en wordt de
	# normalisatie honderden malen te groot. Skelet forceren voor we meten.
	skel.force_update_all_bone_transforms()
	att.force_update_transform()
	prop.force_update_transform()
	var ab := _combined_aabb(prop)
	var longest: float = maxf(ab.size.x, maxf(ab.size.y, ab.size.z))
	var parent_scale: float = prop.global_transform.basis.get_scale().x
	if parent_scale <= 0.0001 or not is_finite(parent_scale):
		parent_scale = 1.0
	if longest > 0.0001 and parent_scale > 0.0001:
		var factor := 0.55 / (longest * parent_scale)
		prop.scale = Vector3(factor, factor, factor)
	# Fijnafstelling uit de tuning: pos ≈ wereld-units langs de hand-assen
	# (gecorrigeerd voor skelet-schaal), rotatie in graden.
	var t: Dictionary = model_tuning().get(_weapon_tune_key, {})
	prop.scale *= float(t.get("scale", 1.0))
	var pos: Array = t.get("pos", [0.0, 0.0, 0.0])
	var rot: Array = t.get("rot", [0.0, 0.0, 0.0])
	prop.position = Vector3(float(pos[0]), float(pos[1]), float(pos[2])) / maxf(parent_scale, 0.0001)
	prop.rotation_degrees = Vector3(float(rot[0]), float(rot[1]), float(rot[2]))
	# VANGRAIL (Max, 30 juli: "hoe kan die musket dan ook zo groot worden?").
	# De normalisatie hierboven zet elk voorwerp op ~0.55 wereld-units, maar de
	# tuning mag daar bovenop schalen. Een uitschieter (of een verkeerd bewaarde
	# waarde) zou een reuzenwapen op het bord zetten. Boven prop_max keren we
	# terug naar de norm: liever een voorwerp dat iets te klein staat dan een
	# stok van drie tegels. prop_max = veelvoud van de normale voorwerp-lengte.
	var grens: float = 0.55 * fx("prop_max", 3.0)
	var nu_lang: float = maxf(_combined_aabb(prop).size.x,
			maxf(_combined_aabb(prop).size.y, _combined_aabb(prop).size.z)) 			* prop.global_transform.basis.get_scale().x
	if nu_lang > grens and nu_lang > 0.0001:
		var terug: float = grens / nu_lang
		prop.scale *= terug
		push_warning("Prop %s was %.2f lang (max %.2f) -- teruggeschaald" % [
			_weapon_tune_key, nu_lang, grens])
	if _rol == "flag":
		_hang_vlagdoek(prop)
	_weapon = prop


# --- Vlaggendoek (besluit Max, 28 juli) ---------------------------------------
# De prop `prop_flag` is alleen de KALE STOK; het doek maken we hier, zodat we
# maat, kleur en (later) embleem in code kunnen sturen i.p.v. vastgebakken in
# een glb. Het wappert met een vertex-shader — geen echte cloth-physics: dat is
# duur, jittert en voegt niets toe op een bord dat je van bovenaf ziet. Puur
# visueel; de staat verandert niet, dus replays blijven identiek.
## Doekmaat als fractie van de poollengte. Kleiner gezet op verzoek van Max
## (30 juli: "de vlag wat kleiner op de prop"); afstelbaar via
## effects_tuning.json ("vlag_breedte"/"vlag_hoogte") zodat je er geen code
## meer voor hoeft aan te raken.
const VLAG_BREEDTE := 0.42   # x poollengte
const VLAG_HOOGTE := 0.26    # x poollengte
const VLAG_ZAKT := 0.06      # x poollengte onder de top van de stok

const VLAG_SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform vec4 kleur : source_color = vec4(0.85, 0.25, 0.28, 1.0);
uniform float amp = 0.16;
uniform float snelheid = 3.6;
uniform float golf = 7.0;
uniform float vuil = 0.55;    // 0 = schoon fabrieksdoek, 1 = smerig veldvaandel
uniform float rafel = 1.0;    // hapjes uit de vrije rand (0 = strak afgezoomd)
uniform float dim = 1.0;      // 1 = normaal, lager = gevallen vaandel (verduister_later)

varying float golfhoogte;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ruis(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * ruis(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	float t = clamp(UV.x, 0.0, 1.0);
	float stijf = t * t;                    // aan de mast staat het doek stil
	float g = sin(TIME * snelheid + t * golf);
	VERTEX.z += g * amp * stijf;
	VERTEX.y += sin(TIME * snelheid * 0.8 + t * golf * 0.7) * amp * 0.35 * stijf;
	golfhoogte = g * stijf;
}

void fragment() {
	vec2 uv = UV;
	// Weefsel: fijne draad-structuur, net zichtbaar van dichtbij.
	float weefsel = 0.94 + 0.06 * sin(uv.y * 420.0) * sin(uv.x * 260.0);
	// Vuil en slijtage: grove vlekken (modder, kruitdamp) plus fijne korrel.
	float vlekken = fbm(uv * 6.0);
	float korrel = ruis(uv * 180.0);
	float sleets = mix(1.0, 0.55 + 0.45 * vlekken, vuil);
	// Randen verbleken: zon, wrijving en rook slaan het hardst toe aan de
	// vrije zijde en langs boven- en onderrand.
	float randslijt = smoothstep(0.55, 1.0, uv.x) * 0.35
		+ smoothstep(0.75, 1.0, abs(uv.y - 0.5) * 2.0) * 0.25;
	vec3 doek = kleur.rgb * weefsel * sleets;
	doek = mix(doek, doek * 1.25 + vec3(0.06), randslijt);
	doek *= 0.92 + 0.08 * korrel;
	// Vouwen: bollingen vangen licht, dalen lopen donker weg.
	doek *= 0.85 + 0.3 * (golfhoogte * 0.5 + 0.5);
	ALBEDO = doek * dim;
	ROUGHNESS = 0.95;
	SPECULAR = 0.05;
	// Achterkant net zo belicht als de voorkant (het is maar een vlak).
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	// Gerafelde buitenrand: onregelmatige hapjes uit het doek.
	float rand = fbm(uv * vec2(14.0, 30.0));
	if (uv.x > 1.0 - rafel * 0.09 * rand) {
		discard;
	}
}
"""


## Hang een wapperend doek in de teamkleur aan de top van de vlaggenstok.
func _hang_vlagdoek(pool: Node3D) -> void:
	var ab := _combined_aabb(pool)
	var lengte: float = maxf(ab.size.x, maxf(ab.size.y, ab.size.z))
	if lengte <= 0.0001:
		return
	# Langste as = de stok; het doek hangt aan de top en steekt opzij uit.
	var as_i := 1
	if ab.size.x >= ab.size.y and ab.size.x >= ab.size.z:
		as_i = 0
	elif ab.size.z >= ab.size.y and ab.size.z >= ab.size.x:
		as_i = 2
	var midden := ab.position + ab.size * 0.5
	var top := midden
	top[as_i] = ab.position[as_i] + ab.size[as_i]
	var breedte := lengte * fx("vlag_breedte", VLAG_BREEDTE)
	var hoogte := lengte * fx("vlag_hoogte", VLAG_HOOGTE)
	var doek := MeshInstance3D.new()
	doek.name = "Vlagdoek"
	var vlak := PlaneMesh.new()
	vlak.orientation = PlaneMesh.FACE_Z   # staand vlak in het XY-vlak
	vlak.size = Vector2(breedte, hoogte)
	vlak.subdivide_width = 12
	vlak.subdivide_depth = 6
	doek.mesh = vlak
	var sh := Shader.new()
	sh.code = VLAG_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("kleur",
		Color(0.85, 0.25, 0.28) if team == Constants.Team.RED else Color(0.2, 0.45, 0.9))
	mat.set_shader_parameter("dim", 1.0)
	doek.material_override = mat
	# Vanaf de mast zijwaarts uitsteken (halve breedte opzij), net onder de top.
	doek.position = top + Vector3(breedte * 0.5, 0.0, 0.0)
	doek.position[as_i] -= lengte * VLAG_ZAKT + hoogte * 0.5
	pool.add_child(doek)
	# Wind: onthoud stok-top en stok-as in prop-ruimte; _richt_vlag draait het
	# doek per frame zo dat het in de wereld met de wind mee steekt.
	_vlagdoek = doek
	_vlag_top = top
	_vlag_as = Vector3.ZERO
	_vlag_as[as_i] = 1.0
	_vlag_breedte = breedte
	_vlag_zak = lengte * VLAG_ZAKT + hoogte * 0.5
	_richt_vlag()


func _process(delta: float) -> void:
	if _vlagdoek != null:
		_richt_vlag()
	if _cape != null:
		if is_instance_valid(_cape):
			cape_process(_cape, delta)
		else:
			_cape = null


## Draai het doek in de wind: de wereld-richting (PawnView.wind_richting) naar
## prop-ruimte, geprojecteerd op het vlak loodrecht op de stok, en dan het
## doek met zijn vrije zijde die kant op. De stok hangt aan een bot dat met
## elke animatie meebeweegt, vandaar per frame; het is één basis-berekening
## per drager. Stok plat (dood, gevallen)? Dan blijft de vorige stand staan.
func _richt_vlag() -> void:
	if not is_instance_valid(_vlagdoek):
		_vlagdoek = null
		return
	var ouder: Node3D = _vlagdoek.get_parent() as Node3D
	if ouder == null or not ouder.is_inside_tree():
		return
	var g: Basis = ouder.global_transform.basis.orthonormalized()
	var wl: Vector3 = g.inverse() * wind_richting
	wl -= _vlag_as * wl.dot(_vlag_as)
	if wl.length() < 0.05:
		return
	wl = wl.normalized()
	_vlagdoek.transform = Transform3D(Basis(wl, _vlag_as, wl.cross(_vlag_as)),
		_vlag_top + wl * _vlag_breedte * 0.5 - _vlag_as * _vlag_zak)


# --- Cape (Max, 12 september: "alle blauwe team karakters een blauwe cape, -----
# vanuit Godot") ---------------------------------------------------------------
# Geen Blender: een lap (PlaneMesh) aan het bovenste rugbot (mixamorig:Spine2)
# in de teamkleur, met een vertex-shader die de lap vormt (smalle kraag bij de
# nek, over de schouders naar volle breedte, plooien vanuit de kraag die naar
# de zoom dieper worden, zijkanten om de schouders gewikkeld, echte normalen
# op de plooien), de zoom laat wapperen en met de wind meeneemt
# (PawnView.wind_richting). De KRAAG zit aan het bot en gaat met elke
# animatie mee; de LAP hangt per frame aan de zwaartekracht (cape_process:
# recht naar beneden vanaf de kraag, een gedempte slinger die tegen de
# beweging in sleept en met de wind meegaat, nooit door de rug naar voren;
# Max, 13 september: "kan ie niet meer hangen echt"). Geen cloth-physics
# (duur, jittert, en op bordafstand zie je het verschil niet).
# Puur visueel: geen staat, geen RNG. Standaard alleen het blauwe team
# (pompeus en rijk: goudgalon, lichte voering); rood via de knop cape_rood.
# Knoppen in het sfeer-paneel: cape_blauw, cape_rood (0/1), cape_lengte en
# cape_breedte (x pionhoogte), cape_wapper, cape_wind. De bewoners van het
# diorama gebruiken dezelfde maak_cape (Bewoner.zet_cape).
const CAPE_SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform vec4 kleur : source_color = vec4(0.16, 0.34, 0.86, 1.0);
uniform vec4 voering : source_color = vec4(0.78, 0.72, 0.55, 1.0);   // binnenkant
uniform vec4 zoom : source_color = vec4(0.88, 0.70, 0.28, 1.0);      // galon langs de rand
uniform float zoom_breedte = 0.07;   // fractie van de lap (0 = geen galon)
uniform float hoogte = 0.45;         // laplengte in mesh-eenheden (top = +hoogte/2)
uniform float halfbreedte = 0.18;    // halve schouderbreedte van de lap (mesh-eenheden)
uniform float amp = 0.03;            // wapper-uitslag onderaan, mesh-eenheden
uniform float snelheid = 2.2;
uniform float golf = 4.0;
uniform float fase = 0.0;
uniform float nek = 0.35;            // kraagbreedte t.o.v. de schouders (de punten lopen naar de nek toe)
uniform float schouder = 0.22;       // na dit deel van de lengte ligt de lap op schouderbreedte
uniform float flare = 1.45;          // zoom breder dan de schouders
uniform float bol = 0.05;            // hoe ver de zoom van de rug af staat
uniform float voor = 0.0;            // kraag naar de nek toe
uniform float wikkel = 0.05;         // zijkanten bovenaan om de schouders heen
uniform float plooi = 0.03;          // diepte van de plooien bij de zoom
uniform float plooien = 2.6;         // aantal plooien over de breedte (x pi)
uniform vec3 wind = vec3(0.0);       // windverzet onderaan, in mesh-ruimte
uniform float dim = 1.0;             // 1 = normaal, lager = lijk (verduister_later)
uniform sampler2D textuur : source_color, hint_default_white;  // geleverd plaatje (cape_blue.png), boven = kraag
uniform float heeft_textuur = 0.0;   // 1 = het plaatje is de buitenkant (galon zit er dan in)
uniform float sim = 0.0;             // 1 = cloth-simulatie vormt de lap, de shader kleurt alleen
uniform float voering_goud = 1.0;    // 1 = de binnenkant is goudzijde (Max: "doen we daar vol goud?"), 0 = plaatje/voering

varying float vouw;
varying float tv;

void vertex() {
	if (sim > 0.5) {
		// cloth-simulatie: de physics vormt de lap, hier alleen de galon-coordinaat
		vouw = 0.0;
		tv = UV.y;
	} else {
	float W = max(halfbreedte, 0.0001);
	float L = max(hoogte, 0.0001);
	float u = clamp(VERTEX.x / W, -1.0, 1.0);
	float t = clamp(0.5 - VERTEX.y / L, 0.0, 1.0);   // 0 kraag, 1 zoom
	float los = t * t;                                 // bovenaan zit de lap vast
	float bo = 1.0 - t;
	// Breedte: smal om de nek, over de schouders naar volle breedte, dan uitlopend.
	float w = mix(nek, 1.0, smoothstep(0.0, schouder, t)) * mix(1.0, flare, t);
	float xn = u * w;
	VERTEX.x = xn * W;
	// Plooien vanuit de kraag, dieper naar de zoom; bovenaan om de schouders gewikkeld.
	float k = plooien * 3.14159;
	float pl = plooi * t * sin(k * xn + fase);
	float wik = -wikkel * xn * xn * bo * bo;
	float g = sin(TIME * snelheid + t * golf + fase);
	float g2 = sin(TIME * snelheid * 0.73 + t * golf * 0.6 + fase * 1.7);
	VERTEX.z += bol * t + pl + wik - voor * bo * bo * bo + g * amp * los + wind.z * los;
	VERTEX.x += g2 * amp * 0.5 * los + wind.x * los;
	// De zoom hangt in het midden iets lager, en wappert mee.
	VERTEX.y += wind.y * los - abs(g) * amp * 0.25 * los - 0.5 * plooi * los * (0.5 + 0.5 * cos(3.14159 * xn));
	// Normaal uit de plooien, de wikkel en de bolling, zodat het licht de drape laat zien.
	float dz_du = (plooi * t * k * cos(k * xn + fase) - 2.0 * wikkel * xn * bo * bo) * w;
	float dz_dt = plooi * sin(k * xn + fase) + 2.0 * wikkel * xn * xn * bo + bol + 3.0 * voor * bo * bo;
	NORMAL = normalize(vec3(-dz_du / W, dz_dt / L, 1.0));
	vouw = g * los;
	tv = t;
	}
}

void fragment() {
	float weefsel = 0.95 + 0.05 * sin(UV.y * 380.0) * sin(UV.x * 240.0);
	vec3 basis = FRONT_FACING ? kleur.rgb : voering.rgb;
	// Galon langs de zoom, de twee zijranden en (smaller) de kraag.
	float rand = min(min(UV.x, 1.0 - UV.x), min(1.0 - tv, tv * 1.6));
	float galon = 1.0 - smoothstep(zoom_breedte * 0.8, zoom_breedte, rand);
	if (zoom_breedte <= 0.0001) {
		galon = 0.0;
	}
	vec3 doek = mix(basis, zoom.rgb, galon) * weefsel;
	if (heeft_textuur > 0.5 && (FRONT_FACING || sim > 0.5)) {
		// cloth: het plaatje op beide kanten (vanaf de speler zie je bij de
		// vijand vooral de binnenkant; met alleen de voering leek de cape kaal)
		doek = texture(textuur, UV).rgb;
		if (!FRONT_FACING) {
			doek *= 0.8;
		}
	}
	bool goudzijde = !FRONT_FACING && voering_goud > 0.5;
	if (goudzijde) {
		// binnenkant: goudzijde, iets donkerder naar de kraag toe
		doek = zoom.rgb * weefsel * (0.9 + 0.1 * smoothstep(0.0, 0.3, tv));
	}
	// Wapper-plooien vangen licht; schaduw onder de kraag.
	doek *= 0.9 + 0.15 * (vouw * 0.5 + 0.5);
	doek *= 0.8 + 0.2 * smoothstep(0.0, 0.25, tv);
	ALBEDO = doek * dim;
	ROUGHNESS = goudzijde ? 0.45 : 0.9;   // zijde glanst, wol niet
	SPECULAR = goudzijde ? 0.35 : 0.08;
	if (sim > 0.5) {
		// cloth: de normaal uit de schermafgeleiden (de soft body levert er
		// geen bruikbare aan), altijd naar de camera toe, dus voor beide kanten
		vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
		if (n.z < 0.0) {
			n = -n;
		}
		NORMAL = n;
	} else if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
"""

const CAPE_BOTTEN: Array = ["mixamorig:Spine2", "Spine2", "mixamorig:Spine1", "Spine1",
	"mixamorig:Neck", "Neck", "mixamorig:Spine", "Spine"]
const CAPE_LAAG := 1 << 19   # physics-laag 20: alleen capes en hun lijf-capsules
const CAPE_RUG := 0.09       # kraag zo ver achter het rugbot (x pionhoogte), net buiten de romp-capsule


## Cape aan het bovenste rugbot van een geanimeerd model (pion of bewoner).
## root = de glb-instantie (voorkant +Z, zoals elke generator hem levert),
## hoogte_w = hoogte van het model in wereld-eenheden. Maten uit de knoppen
## (x hoogte). Geeft het doek terug; null als er geen skelet of rugbot is.
static func maak_cape(root: Node3D, hoogte_w: float, blauw: bool, fase_bron: int = 0) -> MeshInstance3D:
	if root == null or not root.is_inside_tree() or hoogte_w <= 0.01:
		return null
	var skels: Array = root.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return null
	var skel: Skeleton3D = skels[0]
	var bone := -1
	for cand in CAPE_BOTTEN:
		bone = skel.find_bone(String(cand))
		if bone >= 0:
			break
	if bone < 0:
		for i in skel.get_bone_count():
			var bn := String(skel.get_bone_name(i))
			if bn.contains("Spine2") or bn.contains("Neck"):
				bone = i
				break
	if bone < 0:
		return null
	skel.force_update_all_bone_transforms()
	var lengte: float = hoogte_w * fx("cape_lengte", 0.5)
	var breedte: float = hoogte_w * fx("cape_breedte", 0.4)
	var tex: Texture2D = cape_textuur(blauw)
	if tex != null and tex.get_height() > 0:
		# Met een plaatje volgt de lap de verhouding daarvan (3:4, 2:3, 1:1,
		# ...), zodat de rand overal even dik blijft; de lengte blijft de knop.
		breedte = clampf(lengte * float(tex.get_width()) / float(tex.get_height()), lengte * 0.4, lengte * 1.3)
	# Ruimte van het bot in RUST (T-pose): daarin hangt de lap recht naar
	# beneden, en daarna volgt hij het bot door elke animatie heen. De pose
	# van dit moment is minder geschikt: die kan midden in een clip staan
	# (leunend, schietend), en dan hing de cape in idle scheef.
	var rust_w: Basis = skel.global_transform.basis * skel.get_bone_global_rest(bone).basis
	var inv: Basis = rust_w.inverse()
	var achter_w: Vector3 = (root.global_transform.basis * Vector3(0.0, 0.0, -1.0)).normalized()
	var achter_l: Vector3 = (inv * achter_w).normalized()
	var op_l: Vector3 = (inv * Vector3.UP).normalized()
	var rechts_l: Vector3 = op_l.cross(achter_l).normalized()
	op_l = achter_l.cross(rechts_l).normalized()
	# Schaal van de ouder (skelet x auto-fit): mesh-eenheden = wereld-eenheden.
	var s_ouder: float = rust_w.get_scale().x
	if s_ouder <= 0.000001 or not is_finite(s_ouder):
		s_ouder = 1.0
	var att := BoneAttachment3D.new()
	att.name = "CapeBot"
	skel.add_child(att)
	att.bone_idx = bone
	var doek := MeshInstance3D.new()
	doek.name = "Cape"
	var vlak := PlaneMesh.new()
	vlak.orientation = PlaneMesh.FACE_Z
	vlak.size = Vector2(breedte, lengte)
	vlak.subdivide_width = 8
	vlak.subdivide_depth = 14
	doek.mesh = vlak
	doek.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var sh := Shader.new()
	sh.code = CAPE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("kleur", Color(0.16, 0.34, 0.86) if blauw else Color(0.66, 0.16, 0.18))
	mat.set_shader_parameter("voering", Color(0.78, 0.72, 0.55) if blauw else Color(0.42, 0.3, 0.24))
	mat.set_shader_parameter("zoom", Color(0.88, 0.7, 0.28) if blauw else Color(0.5, 0.42, 0.3))
	mat.set_shader_parameter("zoom_breedte", 0.07 if blauw else 0.0)
	mat.set_shader_parameter("voering_goud", fx("cape_voering_goud", 1.0) if blauw else 0.0)
	mat.set_shader_parameter("hoogte", lengte)
	mat.set_shader_parameter("halfbreedte", breedte * 0.5)
	mat.set_shader_parameter("amp", lengte * 0.09 * fx("cape_wapper", 1.0))
	mat.set_shader_parameter("bol", hoogte_w * 0.06)
	# Drape (Max, 12 september: "nu is het erg strak"): plooien vanuit de kraag
	# en de zijkanten om de schouders; knop cape_drape schaalt allebei.
	var drape: float = fx("cape_drape", 1.0)
	mat.set_shader_parameter("wikkel", hoogte_w * 0.06 * drape)
	mat.set_shader_parameter("plooi", hoogte_w * 0.045 * drape)
	mat.set_shader_parameter("fase", float(absi(fase_bron) % 97) * 0.35)
	mat.set_shader_parameter("dim", 1.0)
	if tex != null:
		mat.set_shader_parameter("textuur", tex)
		mat.set_shader_parameter("heeft_textuur", 1.0)
	doek.material_override = mat
	doek.set_meta("cape_lengte", lengte)
	doek.set_meta("cape_root", root)
	doek.set_meta("cape_hang", Vector3.DOWN)
	doek.set_meta("cape_hang_v", Vector3.ZERO)
	doek.set_meta("cape_anker_w", Vector3.ZERO)
	# Top van de lap op de schouderlijn (het nekbot als het er is, anders een
	# tiende pionhoogte boven het rugbot), een stukje achter de rug.
	var nek_op: float = hoogte_w * 0.1
	var nek := skel.find_bone("mixamorig:Neck")
	if nek < 0:
		nek = skel.find_bone("Neck")
	if nek >= 0 and nek != bone:
		var d_w: Vector3 = skel.global_transform.basis * (skel.get_bone_global_rest(nek).origin - skel.get_bone_global_rest(bone).origin)
		nek_op = clampf(d_w.y, 0.0, hoogte_w * 0.2)
	doek.set_meta("cape_breedte", breedte)
	if _cape_sim_beschikbaar():
		doek.free()   # de vlakke lap is niet nodig: de physics vormt de stof
		return _maak_cape_sim(root, skel, bone, att, mat, inv, lengte, breedte, hoogte_w, nek_op, achter_w)
	var offset_w: Vector3 = Vector3.UP * (nek_op - lengte * 0.5) + achter_w * (hoogte_w * 0.06)
	doek.transform = Transform3D(Basis(rechts_l, op_l, achter_l).scaled(Vector3.ONE / s_ouder), inv * offset_w)
	# het kraagpunt in bot-ruimte: daar hangt cape_process de lap elke frame aan
	doek.set_meta("cape_anker", inv * (Vector3.UP * nek_op + achter_w * (hoogte_w * 0.06)))
	att.add_child(doek)
	return doek


static var _cape_tex_cache: Dictionary = {}


## Geleverde cape-textuur: `cape_blue.png` / `cape_red.png` ergens onder
## assets/models (aanrader: assets/models/props/, prompts in de LEESMIJ daar).
## Rechthoekig plaatje, boven = kraag, onder = zoom, de galon zit in het
## plaatje; de shader vormt, plooit en belicht hem. Null = de shader kleurt.
static func cape_textuur(blauw: bool) -> Texture2D:
	var naam := "cape_blue.png" if blauw else "cape_red.png"
	if _cape_tex_cache.has(naam):
		return _cape_tex_cache[naam]
	var tex: Texture2D = null
	for map in [MODELS_DIR + "props", MODELS_DIR.trim_suffix("/")]:
		var pad := Bestandsindex.vind(String(map), naam)
		if pad != "" and ResourceLoader.exists(pad):
			tex = load(pad) as Texture2D
			break
	_cape_tex_cache[naam] = tex
	return tex


## De cape per frame (13 september): de kraag volgt het bot, de lap hangt aan
## de zwaartekracht. Doelrichting = omlaag, een beetje van de rug af, tegen
## de beweging van de kraag in (de lap sleept) en met de wind mee; een
## gedempte slinger (veer + demping) loopt daar achteraan, zodat hij
## nazwaait bij een uitval of een draai. Nooit door de rug naar voren. Het
## doek krijgt zijn wereld-transform; Godot rekent dat terug naar het bot.
## Puur visueel: geen RNG, niets in de digest. Knoppen: cape_slinger (hoe
## ver hij sleept), cape_wind.
static func cape_process(doek: MeshInstance3D, dt: float) -> void:
	if doek == null or not is_instance_valid(doek) or not doek.is_inside_tree():
		return
	if bool(doek.get_meta("cape_sim", false)):
		_cape_sim_process(doek)
		return
	var att: Node3D = doek.get_parent() as Node3D
	var root: Node3D = doek.get_meta("cape_root", null) as Node3D
	if att == null or root == null or not is_instance_valid(root):
		return
	var lengte: float = float(doek.get_meta("cape_lengte", 0.45))
	var anker_l: Vector3 = doek.get_meta("cape_anker", Vector3.ZERO)
	var anker_w: Vector3 = att.global_transform * anker_l
	var achter_w: Vector3 = (root.global_transform.basis * Vector3(0.0, 0.0, -1.0)).normalized()
	# snelheid van de kraag: het lijf beweegt, de lap sleept erachteraan
	var vorige: Vector3 = doek.get_meta("cape_anker_w", Vector3.ZERO)
	var v := Vector3.ZERO
	if vorige != Vector3.ZERO and dt > 0.0001:
		v = (anker_w - vorige) / dt
		if v.length() > 6.0:   # een sprong (spawn, herbouw, teleport) is geen beweging
			v = Vector3.ZERO
	doek.set_meta("cape_anker_w", anker_w)
	var slinger: float = fx("cape_slinger", 1.0)
	# omlaag, een flink stuk van de rug af (het achterwerk steekt achter de
	# loodlijn vanaf de schouders uit), een vijfde van het bot mee (leunen),
	# tegen de beweging in, met de wind mee
	var bot_omlaag: Vector3 = -att.global_transform.basis.y.normalized()
	var doel: Vector3 = Vector3.DOWN * 0.8 + bot_omlaag * 0.2 + achter_w * 0.28 - v * 0.35 * slinger + wind_richting * 0.12 * fx("cape_wind", 1.0)
	var voor: Vector3 = -achter_w
	if doel.dot(voor) > 0.0:
		doel -= voor * doel.dot(voor)
	doel = doel.normalized()
	var hang: Vector3 = doek.get_meta("cape_hang", Vector3.DOWN)
	var hang_v: Vector3 = doek.get_meta("cape_hang_v", Vector3.ZERO)
	var stap: float = minf(maxf(dt, 0.0), 0.05)
	hang_v += (doel - hang) * 60.0 * stap
	hang_v *= exp(-7.0 * stap)
	hang = hang + hang_v * stap
	if hang.dot(voor) > 0.0:
		hang -= voor * hang.dot(voor)
	if hang.length() < 0.001:
		hang = Vector3.DOWN
	hang = hang.normalized()
	doek.set_meta("cape_hang", hang)
	doek.set_meta("cape_hang_v", hang_v)
	var op: Vector3 = -hang
	var z: Vector3 = achter_w - op * achter_w.dot(op)
	if z.length() < 0.01:
		return
	z = z.normalized()
	var x: Vector3 = op.cross(z).normalized()
	var basis := Basis(x, op, z)
	doek.global_transform = Transform3D(basis, anker_w - op * (lengte * 0.5))
	# wind in doek-ruimte voor de zoom-wapper; nooit door de rug (lokale -Z)
	var mat := doek.material_override as ShaderMaterial
	if mat != null:
		var w: Vector3 = basis.inverse() * (wind_richting * lengte * 0.3 * fx("cape_wind", 1.0))
		w.z = maxf(w.z, 0.0)
		mat.set_shader_parameter("wind", w)


## Is de cloth-cape mogelijk? Knop cape_sim (1) en Jolt als physics-engine:
## de oude Godot-physics laat soft bodies ontploffen.
static func _cape_sim_beschikbaar() -> bool:
	if fx("cape_sim", 1.0) < 0.5:
		return false
	return String(ProjectSettings.get_setting("physics/3d/physics_engine", "")).begins_with("Jolt")


## De cloth-cape (13 september, Max: "je hebt geen cloth iets van simulatie??
## lightweight iets"): een SoftBody3D van 7 x 10 punten op Jolt, drie
## solver-iteraties, geen wind, geen grond. De KRAAGRIJ is vastgepind en gaat
## elke frame via de PhysicsServer mee met het rugbot (het attachment-pad
## van SoftBody3D zelf laat de punten in 4.7 gewoon vallen); twee capsules
## (romp: heup-nek, bekken en bovenbenen: heup-omlaag) houden de stof van het
## lijf. De lap staat onder de PawnView of de Bewoner (schaal 1: een soft
## body onder het geschaalde skelet gaat mis), niet onder het bot; cape_weg
## ruimt lap, bot-anker en capsules samen op. De shader kleurt alleen (sim=1).
static func _maak_cape_sim(root: Node3D, skel: Skeleton3D, bone: int, att: BoneAttachment3D, mat: ShaderMaterial,
		inv: Basis, lengte: float, breedte: float, hoogte_w: float, nek_op: float, achter_w: Vector3) -> MeshInstance3D:
	var ouder: Node3D = root.get_parent() as Node3D
	if ouder == null:
		return null
	# De lap: kolommen x rijen, smal bij de kraag, over de schouders naar
	# volle breedte, uitlopend naar de zoom. Rij 0 is de kraag.
	var kol := 7
	var rij := 10
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for r in rij:
		var t: float = float(r) / float(rij - 1)
		var w: float = lerpf(0.35, 1.0, smoothstep(0.0, 0.22, t)) * lerpf(1.0, 1.45, t)
		for c in kol:
			var u: float = float(c) / float(kol - 1)
			vs.append(Vector3((u - 0.5) * breedte * w, lengte * 0.5 - t * lengte, 0.0))
			ns.append(Vector3(0.0, 0.0, 1.0))
			uvs.append(Vector2(u, t))
	for r in rij - 1:
		for c in kol - 1:
			var a: int = r * kol + c
			var b: int = a + 1
			var c2: int = a + kol
			var d: int = c2 + 1
			# winding zo dat de BUITENKANT (weg van de rug) de voorkant is; met
			# de andere volgorde zag je van achteren de voering (13 september)
			idx.append_array(PackedInt32Array([a, b, c2, b, d, c2]))
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_NORMAL] = ns
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var soft := SoftBody3D.new()
	soft.name = "Cape"
	soft.mesh = mesh
	mat.set_shader_parameter("sim", 1.0)
	mat.set_shader_parameter("wind", Vector3.ZERO)
	soft.material_override = mat
	soft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# Stevig doek (Max: "iets te los"): volle stijfheid, flinke demping en
	# luchtweerstand, vijf iteraties (nog steeds licht: 70 punten).
	soft.simulation_precision = clampi(int(fx("cape_sim_precisie", 5.0)), 1, 10)
	soft.total_mass = 0.15
	soft.linear_stiffness = 1.0
	soft.damping_coefficient = 0.15
	soft.drag_coefficient = 0.2
	soft.collision_layer = CAPE_LAAG
	soft.collision_mask = CAPE_LAAG
	# Beginstand: kraag op de schouderlijn achter de rug, lap recht naar
	# beneden, buitenkant naar achteren. Uit de rusthouding; de eerste frame
	# zet de kraag op de echte pose.
	var bot_w: Vector3 = skel.global_transform * skel.get_bone_global_rest(bone).origin
	# de kraag net BUITEN de romp-capsule (straal 0,085): begint de stof erin,
	# dan duwt de solver hem soms naar voren door het lijf (Max: "gaat door
	# de body heen af en toe")
	var kraag_w: Vector3 = bot_w + Vector3.UP * nek_op + achter_w * (hoogte_w * CAPE_RUG)
	var z_w: Vector3 = (achter_w - Vector3.UP * achter_w.dot(Vector3.UP)).normalized()
	var x_w: Vector3 = Vector3.UP.cross(z_w).normalized()
	var wereld := Transform3D(Basis(x_w, Vector3.UP, z_w), kraag_w - Vector3.UP * (lengte * 0.5))
	soft.transform = ouder.global_transform.affine_inverse() * wereld
	ouder.add_child(soft)
	# Kraagrij vastpinnen. Ze volgen het rugbot alleen in POSITIE; de rij
	# zelf staat dwars op de kijkrichting van het model (cape_kraag_punten).
	# Draaide de rij met het bot mee, dan zwaaide de lap bij een gedraaid
	# bovenlijf (de rifle-idle) om de pion heen en zag je de voering.
	var kraag_idx := PackedInt32Array()
	var kraag_x := PackedFloat32Array()
	for c in kol:
		soft.set_point_pinned(c, true)
		kraag_idx.append(c)
		kraag_x.append(vs[c].x)
	# Het lijf voor de botsing: capsules tussen botten, maat uit de
	# rusthouding (botten rekken niet, dus Jolt bouwt de vorm nooit opnieuw):
	# romp heup-nek, bekken en bovenbenen heup-omlaag, en de bovenarmen
	# (die zwaaien bij het mikken en de bajonetstoot door de lap).
	var heup := _cape_bot(skel, ["mixamorig:Hips", "Hips"], "Hips", bone)
	var nek := _cape_bot(skel, ["mixamorig:Neck", "Neck"], "Neck", bone)
	var capsules: Array = []
	var specs: Array = [
		{"naam": "CapeRomp", "a": heup, "b": nek, "rek": hoogte_w * 0.04, "r": hoogte_w * 0.085},
		{"naam": "CapeBenen", "a": heup, "b": -1, "omlaag": hoogte_w * 0.32, "r": hoogte_w * 0.08},
	]
	for kant in ["Left", "Right"]:
		var arm := skel.find_bone("mixamorig:%sArm" % kant)
		var onderarm := skel.find_bone("mixamorig:%sForeArm" % kant)
		if arm >= 0 and onderarm >= 0:
			specs.append({"naam": "CapeArm" + kant, "a": arm, "b": onderarm, "rek": hoogte_w * 0.02, "r": hoogte_w * 0.045})
	for sp in specs:
		var a_w: Vector3 = skel.global_transform * skel.get_bone_global_rest(int(sp.a)).origin
		var b_w: Vector3
		if int(sp.b) < 0:
			b_w = a_w + Vector3.DOWN * float(sp.get("omlaag", 0.0))
		else:
			b_w = skel.global_transform * skel.get_bone_global_rest(int(sp.b)).origin
		var lengte_c: float = maxf(a_w.distance_to(b_w) + 2.0 * float(sp.get("rek", 0.0)), hoogte_w * 0.1)
		var body := _cape_capsule(ouder, float(sp.r), lengte_c)
		body.name = String(sp.naam)
		capsules.append({"body": body, "a": int(sp.a), "b": int(sp.b), "omlaag": float(sp.get("omlaag", 0.0)), "rek": float(sp.get("rek", 0.0))})
	soft.set_meta("cape_sim", true)
	soft.set_meta("cape_capsules", capsules)
	soft.set_meta("cape_bot", att)
	soft.set_meta("cape_bone", bone)
	soft.set_meta("cape_skel", skel)
	soft.set_meta("cape_heup", heup)
	soft.set_meta("cape_nek", nek)
	soft.set_meta("cape_kraag_idx", kraag_idx)
	soft.set_meta("cape_kraag_x", kraag_x)
	soft.set_meta("cape_nek_op", nek_op)
	soft.set_meta("cape_rug", hoogte_w * CAPE_RUG)
	soft.set_meta("cape_root", root)
	soft.set_meta("cape_lengte", lengte)
	soft.set_meta("cape_breedte", breedte)
	soft.set_meta("cape_hoogte", hoogte_w)
	# GEEN _cape_sim_process hier: soft_body_move_point voordat Jolt het
	# lichaam heeft aangemaakt verminkt de vrije punten (zoom 2 eenheden
	# weg, gemeten 13 september). De eerste _process-frame zet de kraag.
	return soft


static func _cape_bot(skel: Skeleton3D, namen: Array, deel: String, terugval: int) -> int:
	for n in namen:
		var i := skel.find_bone(String(n))
		if i >= 0:
			return i
	for i in skel.get_bone_count():
		if String(skel.get_bone_name(i)).contains(deel):
			return i
	return terugval


## Een capsule op de cape-laag; _zet_capsule zet hem per frame tussen twee
## botten. Hoogte vast (botten rekken niet), dus Jolt hoeft de vorm nooit
## opnieuw te bouwen. AnimatableBody3D met sync_to_physics: dan kent Jolt
## de snelheid van het lijf en drukt een uitval de stof weg in plaats van
## erdoorheen te springen.
static func _cape_capsule(ouder: Node3D, r: float, hoogte: float) -> AnimatableBody3D:
	var body := AnimatableBody3D.new()
	body.name = "CapeLijf"
	body.sync_to_physics = true
	body.collision_layer = CAPE_LAAG
	body.collision_mask = 0
	var vorm := CollisionShape3D.new()
	var caps := CapsuleShape3D.new()
	caps.radius = r
	caps.height = maxf(hoogte, 2.0 * r + 0.001)
	vorm.shape = caps
	body.add_child(vorm)
	ouder.add_child(body)
	return body


static func _zet_capsule(body: PhysicsBody3D, a: Vector3, b: Vector3) -> void:
	if body == null or not is_instance_valid(body) or not body.is_inside_tree():
		return
	var d: Vector3 = b - a
	if d.length() < 0.0001:
		return
	var y: Vector3 = d.normalized()
	var x: Vector3 = y.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z: Vector3 = x.cross(y).normalized()
	body.global_transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)


## Per frame voor de cloth-cape: kraagrij op het bot, capsules op het lijf.
## Is het lijf weg (gibs, modelwissel), dan gaat de lap mee weg.
static func _cape_sim_process(doek: MeshInstance3D) -> void:
	var att: Node3D = doek.get_meta("cape_bot", null) as Node3D
	var skel: Skeleton3D = doek.get_meta("cape_skel", null) as Skeleton3D
	if att == null or not is_instance_valid(att) or not att.is_inside_tree() or skel == null or not is_instance_valid(skel):
		cape_weg(doek)
		return
	var soft := doek as SoftBody3D
	if soft == null:
		return
	var rid: RID = soft.get_physics_rid()
	var kraag_idx: PackedInt32Array = doek.get_meta("cape_kraag_idx")
	var punten: PackedVector3Array = cape_kraag_punten(doek)
	for k in mini(kraag_idx.size(), punten.size()):
		PhysicsServer3D.soft_body_move_point(rid, kraag_idx[k], punten[k])
	for c in doek.get_meta("cape_capsules", []):
		var cd: Dictionary = c
		var a_w: Vector3 = skel.global_transform * skel.get_bone_global_pose(int(cd.a)).origin
		var b_w: Vector3
		if int(cd.b) < 0:
			b_w = a_w + Vector3.DOWN * float(cd.omlaag)
			a_w += Vector3.UP * float(doek.get_meta("cape_hoogte", 0.9)) * 0.02
		else:
			b_w = skel.global_transform * skel.get_bone_global_pose(int(cd.b)).origin
			var richting: Vector3 = (b_w - a_w).normalized()
			a_w -= richting * float(cd.rek)
			b_w += richting * float(cd.rek)
		_zet_capsule(cd.body as PhysicsBody3D, a_w, b_w)


## Waar de kraagpunten van een cloth-cape NU horen (wereld): op het rugbot
## (positie rechtstreeks uit het skelet; het bot-anker loopt een frame
## achter), een nekhoogte omhoog, een stukje achter de rug, en de rij dwars
## op de kijkrichting van het model. De check gebruikt dezelfde functie.
static func cape_kraag_punten(doek: MeshInstance3D) -> PackedVector3Array:
	var uit := PackedVector3Array()
	var skel: Skeleton3D = doek.get_meta("cape_skel", null) as Skeleton3D
	var root: Node3D = doek.get_meta("cape_root", null) as Node3D
	if skel == null or root == null or not is_instance_valid(skel) or not is_instance_valid(root):
		return uit
	var bone: int = int(doek.get_meta("cape_bone", -1))
	if bone < 0:
		return uit
	var bot_w: Vector3 = skel.global_transform * skel.get_bone_global_pose(bone).origin
	var achter_w: Vector3 = root.global_transform.basis * Vector3(0.0, 0.0, -1.0)
	achter_w.y = 0.0
	achter_w = achter_w.normalized() if achter_w.length() > 0.001 else Vector3.BACK
	var rechts_w: Vector3 = Vector3.UP.cross(achter_w).normalized()
	var midden: Vector3 = bot_w + Vector3.UP * float(doek.get_meta("cape_nek_op", 0.09)) + achter_w * float(doek.get_meta("cape_rug", 0.05))
	var xs: PackedFloat32Array = doek.get_meta("cape_kraag_x")
	for x in xs:
		uit.append(midden + rechts_w * x)
	return uit


## Ruimt een cape op (beide soorten): het doek, zijn bot-anker en de capsules.
static func cape_weg(doek: MeshInstance3D) -> void:
	if doek == null or not is_instance_valid(doek):
		return
	if doek.has_meta("cape_bot"):
		var n = doek.get_meta("cape_bot")
		if n is Node and is_instance_valid(n):
			(n as Node).name = "CapeOud"
			(n as Node).queue_free()
	for c in doek.get_meta("cape_capsules", []):
		var b = (c as Dictionary).get("body", null)
		if b is Node and is_instance_valid(b):
			(b as Node).name = "CapeOud"
			(b as Node).queue_free()
	var ouder: Node = doek.get_parent()
	doek.name = "CapeOud"   # de verse lap van deze frame mag weer "Cape" heten
	if ouder is BoneAttachment3D and ouder.name == "CapeBot":
		ouder.name = "CapeBotOud"
		ouder.queue_free()   # de vlakke shader-lap hangt onder zijn eigen bot-anker
	else:
		doek.queue_free()


## De cape van deze pion: bouwen of weghalen volgens team en knoppen.
## Idempotent; loopt na elke modelwissel (via _apply_team_texture) en bij een
## knopwijziging in het sfeer-paneel (herhang_cape).
func _hang_cape() -> void:
	cape_weg(_cape)
	_cape = null
	if _piece == null or _unit_type == Constants.UnitType.ARTILLERY or not is_inside_tree():
		return
	var aan: bool = (fx("cape_blauw", 1.0) > 0.5) if team == Constants.Team.BLUE else (fx("cape_rood", 0.0) > 0.5)
	if not aan:
		return
	var h: float = float(last_fit.get("h", 0.0)) * float(last_fit.get("s", 0.0))
	if h <= 0.01:
		h = 1.1 if _unit_type == Constants.UnitType.CAVALRY else 0.9
	_cape = maak_cape(_piece, h, team == Constants.Team.BLUE, pawn_id)


## Sfeer-paneel: een cape-knop is verdraaid, hang hem opnieuw.
func herhang_cape() -> void:
	_hang_cape()


## Teamwissel NA het bouwen (checks, gereedschap): jas en cape gaan mee.
func zet_team(t: int) -> void:
	team = t
	_apply_team_texture()


## Normaliseer een geïmporteerd model naar bord-maat: meet de gezamenlijke AABB,
## schaal uniform (hoogte ~0.9, voetafdruk binnen de tegel), zet de voeten op
## y=0, centreer op de tegel en draai 180° — AI-generators leveren modellen die
## naar de kijker (+Z) kijken, terwijl onze voorkant -Z is (face_dir).
func _auto_fit_model(root: Node3D) -> void:
	var aabb := _combined_aabb(root)
	if aabb.size.y <= 0.0001:
		return
	# Slim meten op botnamen: de VOETEN bepalen de grond en het tegel-midden,
	# de staart telt nergens in mee. Zonder dit trok een lange staart het
	# centrum naar achteren (model uit het midden), telde hij mee als breedte
	# (model te klein geschaald) en hing hij onder de voeten (model zwevend) —
	# precies de drie dingen die eerder handmatig weggetuned moesten worden.
	var m := _measure_bones(root)
	var ground_y: float = m.get("ground", aabb.position.y)
	var top_y: float = m.get("top", aabb.end.y)
	var center: Vector3 = m.get("center", aabb.get_center())
	var footprint: float = m.get("footprint", maxf(aabb.size.x, aabb.size.z))
	var target_h: float = 1.1 if _unit_type == 1 else (0.8 if _unit_type == 2 else 0.9)
	var s: float = target_h / maxf(top_y - ground_y, 0.0001)
	if footprint > 0.0001:
		s = minf(s, 0.95 / footprint)  # armen/loop mogen de buur-tegel niet in
	root.scale = Vector3(s, s, s)
	root.rotation.y = PI
	# Na rotatie om Y (x,z → -x,-z): voeten-midden op de tegel, zolen op de grond.
	root.position = Vector3(s * center.x, -s * ground_y, s * center.z)
	last_fit = {"s": s, "h": top_y - ground_y, "fp": footprint, "ground": ground_y,
		"cx": center.x, "cz": center.z, "bones": not m.is_empty()}
	# Handmatige correctie uit de Model-tuner bovenop de auto-fit. x/z schuiven
	# het model binnen het vak in TEGEL-ruimte: onafhankelijk van de kijkrichting,
	# zodat rood en blauw (die tegengesteld kijken) én de tuner exact gelijk staan.
	var t: Dictionary = model_tuning().get(_tune_key, {})
	if not t.is_empty():
		var extra: float = float(t.get("scale", 1.0))
		root.scale *= extra
		root.position *= extra  # grond/centrering schalen mee
		# x/z corrigeren de SCHEEFHEID van het model zelf (pose leunt naar een
		# kant) en horen dus mee te draaien met de kijkrichting: zo staat het
		# lijf voor rood en blauw identiek op de eigen tegel.
		root.position += Vector3(float(t.get("x", 0.0)), float(t.get("y", 0.0)), float(t.get("z", 0.0)))


## Team-texture: naast het model kan een <basis>_red.png / <basis>_blue.png
## staan (uit Blender/de generator). Rood team krijgt _red, blauw _blue; is
## er geen variant voor dit team, dan blijft de originele model-texture staan
## (dus het neutrale basismodel = default). Zo één geanimeerd model, per team
## een andere jas.
static var _team_tex_cache: Dictionary = {}


## Laad de gib-assets (gibs-glb + gore-textures) alvast op de ACHTERGROND
## zodra het model verschijnt, zodat het eerste gib-moment niet hapert: de
## eerste load van schijf + GPU-upload zou anders een frame-freeze geven.
## Threaded; een latere load() pakt de al-warme resource uit de cache.
static func _preload_gib_assets(model_path: String) -> void:
	if model_path == "":
		return
	var b := model_path.get_basename()
	for path in [b + "_gibs.glb", b + "_red_gore.png", b + "_blue_gore.png"]:
		if ResourceLoader.exists(path):
			ResourceLoader.load_threaded_request(path)


## Team-texture voor een model. gore=true zoekt eerst de bloederige variant
## (<model>_red_gore.png / _blue_gore.png) en valt terug op de gewone team-
## texture; ontbreken beide, dan null (het model houdt z'n glb-texture).
static func team_texture(model_path: String, team_v: int, gore: bool = false) -> Texture2D:
	var suffix := "_red" if team_v == Constants.Team.RED else "_blue"
	var candidates: Array = []
	if gore:
		candidates.append(model_path.get_basename() + suffix + "_gore.png")
	candidates.append(model_path.get_basename() + suffix + ".png")
	for path in candidates:
		if not _team_tex_cache.has(path):
			_team_tex_cache[path] = load(path) if ResourceLoader.exists(path) else null
		if _team_tex_cache[path] != null:
			return _team_tex_cache[path]
	return null


## Zet een albedo-texture op alle MeshInstance3D-delen onder root (per-instantie
## material_override, dus gedeelde glb-materialen blijven schoon).
static func apply_albedo_to(root: Node, tex: Texture2D) -> void:
	if tex == null or root == null:
		return
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		apply_albedo_to_mesh(mi as MeshInstance3D, tex)


## Idem, maar op EEN mesh. find_children() slaat de root zelf over, dus zonder
## deze variant kun je geen texture op een losse wapen-mesh zetten.
static func apply_albedo_to_mesh(mi: MeshInstance3D, tex: Texture2D) -> void:
	if tex == null or mi == null:
		return
	var m := mi.get_active_material(0)
	if m is BaseMaterial3D:
		var dup := (m as BaseMaterial3D).duplicate()
		(dup as BaseMaterial3D).albedo_texture = tex
		mi.material_override = dup


## Teamjas voor het WAPEN: <wapen-glb zonder extensie>_red.png / _blue.png,
## bijvoorbeeld infantry_mix_musket_red.png naast infantry_mix_musket.glb.
## Elke factie draagt een iets andere musket-stijl (Max, 7 september); zonder
## zo'n bestand houdt het wapen gewoon de atlas uit zijn glb.
static var _wapen_tex_cache: Dictionary = {}


static func weapon_team_texture(wapen_pad: String, team_v: int) -> Texture2D:
	if wapen_pad == "":
		return null
	var pad := wapen_pad.get_basename() + ("_red" if team_v == Constants.Team.RED else "_blue") + ".png"
	if not _wapen_tex_cache.has(pad):
		_wapen_tex_cache[pad] = load(pad) if ResourceLoader.exists(pad) else null
	return _wapen_tex_cache[pad]


func _apply_team_texture() -> void:
	if _piece == null or _model_path == "":
		return
	apply_albedo_to(_piece, team_texture(_model_path, team, false))
	# Het team-uniform hoort alleen op het LIJF. Het ingebakken musket heeft
	# zijn eigen texture-atlas: met de team-png van het lijf erover wordt het
	# een bonte vlek.
	#
	# Ligt er WEL een eigen wapen-jas naast de wapen-glb
	# (<wapen>_red.png / _blue.png), dan krijgt het wapen die -- zo draagt elke
	# factie zijn eigen musket-stijl. Anders gaat de override eraf en houdt het
	# wapen zijn glb-materiaal, precies zoals voorheen.
	_zet_wapenjas()
	_hang_cape()


## De teamjas op het INGEBAKKEN wapen, of de override eraf als die er niet is.
##
## Apart van _apply_team_texture, en om een vervelende reden: die draait aan het
## eind van _swap_piece(), en _attach_weapon() komt pas DAARNA -- daar wordt
## _baked_prop_pad gezet. Bij het opbouwen is het wapenpad dus nog leeg. Daarom
## roept _attach_weapon dit nog een keer aan zodra het pad bekend is.
func _zet_wapenjas() -> void:
	var jas: Texture2D = weapon_team_texture(_baked_prop_pad, team)
	for mi in _vind_ingebakken_wapens():
		if jas != null:
			apply_albedo_to_mesh(mi as MeshInstance3D, jas)
		else:
			(mi as MeshInstance3D).material_override = null


## Alles wat op het slagveld blijft liggen wordt na een tijdje donker: een lijk
## of een brokstuk hoort niet even fel mee te schreeuwen als een levende pion.
## Na een paar rondes is het bord anders een bonte bende waarin je de stukken
## die er nog toe doen niet meer terugvindt.
##
## Geen aparte shader: albedo_color vermenigvuldigt met de texture, dus die van
## wit naar donkergrijs tweenen dimt het hele stuk. Dat werkt ook bovenop de
## gore-textures die er dan al op liggen.
##
## Knoppen (effects_tuning.json, Model-tuner tab Gore):
##   debris_donker_na    seconden voordat het begint
##   debris_donker_duur  hoe lang het verlopen duurt
##   debris_donker       hoe donker (0 = onveranderd, 1 = zwart)
static func verduister_later(root: Node) -> void:
	if root == null or not is_instance_valid(root):
		return
	var kracht: float = clampf(fx("debris_donker", 0.7), 0.0, 1.0)
	if kracht <= 0.001:
		return
	var na: float = maxf(fx("debris_donker_na", 4.0), 0.0)
	var duur: float = maxf(fx("debris_donker_duur", 2.5), 0.05)
	var doel := Color(1.0 - kracht, 1.0 - kracht, 1.0 - kracht, 1.0)
	var meshes: Array = []
	if root is MeshInstance3D:
		meshes.append(root)
	meshes.append_array(root.find_children("*", "MeshInstance3D", true, false))
	for mi in meshes:
		var m3 := mi as MeshInstance3D
		# Per-instantie materiaal, anders verkleur je het GEDEELDE glb-materiaal
		# en wordt elke levende pion met datzelfde model ook donker.
		var mat: Material = m3.material_override
		if mat is ShaderMaterial:
			# Eigen shader (cape, vlaggendoek): die draagt een dim-uniform en
			# is al per instantie, dus gewoon die tweenen.
			var sm := mat as ShaderMaterial
			if sm.get_shader_parameter("dim") != null:
				var tws := m3.create_tween()
				tws.tween_interval(na)
				tws.tween_property(sm, "shader_parameter/dim", 1.0 - kracht, duur).from(1.0)
			continue
		if not (mat is BaseMaterial3D):
			var actief := m3.get_active_material(0)
			if not (actief is BaseMaterial3D):
				continue
			mat = (actief as BaseMaterial3D).duplicate()
			m3.material_override = mat
		var bm := mat as BaseMaterial3D
		var tw := m3.create_tween()
		tw.tween_interval(na)
		tw.tween_property(bm, "albedo_color", doel, duur).from(bm.albedo_color)


## Meet het skelet met kennis van botnamen (in root-lokale ruimte):
## - zwaartepunt van alle lijf-botten = waar het model visueel "staat"
## - voeten/tenen: laagste punt = grond
## - staart-botten worden overal genegeerd (vertekenen centrum, breedte en grond)
## Leeg dict als er geen skelet is; _auto_fit_model valt dan terug op de AABB.
func _measure_bones(root: Node3D) -> Dictionary:
	var inv: Transform3D = root.global_transform.affine_inverse()
	var feet: Array = []
	var body_min := Vector3.INF
	var body_max := -Vector3.INF
	var body_sum := Vector3.ZERO
	var body_n := 0
	for sk in root.find_children("*", "Skeleton3D", true, false):
		(sk as Skeleton3D).force_update_all_bone_transforms()
		var xf: Transform3D = inv * (sk as Skeleton3D).global_transform
		for i in (sk as Skeleton3D).get_bone_count():
			var bname := (sk as Skeleton3D).get_bone_name(i).to_lower()
			if bname.contains("tail"):
				continue
			var p: Vector3 = (xf * (sk as Skeleton3D).get_bone_global_pose(i)).origin
			body_min = body_min.min(p)
			body_max = body_max.max(p)
			body_sum += p
			body_n += 1
			if bname.contains("foot") or bname.contains("toe"):
				feet.append(p)
	if body_n == 0:
		return {}
	# Horizontaal centreren op het ZWAARTEPUNT van de lijf-botten: een pose die
	# leunt (rifle-idle) hangt anders visueel naast zijn tegel, ook al staan de
	# voeten wiskundig exact in het midden — het oog beoordeelt op het lijf.
	var center := body_sum / float(body_n)
	var ground := body_min.y
	if not feet.is_empty():
		ground = INF
		for p in feet:
			ground = minf(ground, p.y)
	return {
		"ground": ground,
		"top": body_max.y,
		"center": center,
		"footprint": maxf(body_max.x - body_min.x, body_max.z - body_min.z),
	}


## Gezamenlijke AABB van alle zichtbare delen, in de lokale ruimte van root.
## Skinned modellen (AI-generators): mesh-AABB's staan in bind-ruimte en zeggen
## niks over de gerenderde maat (skelet schaalt ze op) → meet dan via de
## bot-posities van het skelet, die staan wél in echte ruimte.
## Hoogte (wereld-units) van alles wat er onder deze node getekend wordt.
## Voor de gibs-maatcorrectie hieronder: 0.0 als er niets te meten is.
static func _mesh_hoogte(root: Node3D) -> float:
	var box := AABB()
	var eerste := true
	for kind in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = kind
		if mi.mesh == null:
			continue
		var ab: AABB = mi.global_transform * mi.get_aabb()
		if eerste:
			box = ab
			eerste = false
		else:
			box = box.merge(ab)
	return 0.0 if eerste else box.size.y


## BUG-FIX (Max, 30 juli: "een gigantisch geweer komt opeens tevoorschijn").
## Niet elk gibs-bestand staat op dezelfde schaal als zijn model: gemeten staat
## `infantry_base` 0,006 hoog en zijn gibs 1,275 -- factor 200. De gibs kregen
## de transform van het model, dus die factor sloeg er vol in en er vloog een
## reuzenarm (of musket) door het beeld. Precies bij base, en dat is het model
## dat vaandeldragers en tamboers dragen -- vandaar de indruk dat het met de
## figuranten te maken had. We meten de verhouding en corrigeren, per
## model-pad gecached.
static var _gib_maat_cache: Dictionary = {}


func _gib_maat_correctie(parts_root: Node3D) -> float:
	if _model_path == "":
		return 1.0
	if _gib_maat_cache.has(_model_path):
		return float(_gib_maat_cache[_model_path])
	# CORRECTIE (30 juli, tweede poging): NIET twee verse bestanden vergelijken.
	# Een geskinde mesh meet in bind-space (de muis-base leest dan 0,006 terwijl
	# hij op het bord 0,9 hoog staat), dus die vergelijking rekende 200x de
	# verkeerde kant op. We gebruiken wat de auto-fit al heeft GEMETEN aan het
	# skelet (`last_fit.h`, in modelruimte) x de toegepaste schaal: dat is de
	# hoogte die de speler ziet, pose-onafhankelijk. De gibs hebben op dit
	# moment al de transform van het model, dus hun gemeten hoogte is direct
	# vergelijkbaar.
	var f := 1.0
	var gibs_h := _mesh_hoogte(parts_root)
	var piece_scale: float = (_piece as Node3D).global_transform.basis.get_scale().y
	var pion_h: float = float(last_fit.get("h", 0.0)) * piece_scale
	if pion_h > 0.0001 and gibs_h > 0.0001:
		var verhouding := pion_h / gibs_h
		# Alleen bij een echte mismatch ingrijpen (meer dan 25% scheel), en
		# nooit wilder dan factor 100 -- anders verstoppen we een fout.
		if verhouding < 0.8 or verhouding > 1.25:
			f = clampf(verhouding, 0.01, 100.0)
	_gib_maat_cache[_model_path] = f
	return f


func _combined_aabb(root: Node3D) -> AABB:
	var inv: Transform3D = root.global_transform.affine_inverse()
	var skels: Array = root.find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty():
		var result := AABB()
		var first := true
		for sk in skels:
			(sk as Skeleton3D).force_update_all_bone_transforms()
			var xf: Transform3D = inv * (sk as Skeleton3D).global_transform
			for i in (sk as Skeleton3D).get_bone_count():
				var p: Vector3 = (xf * (sk as Skeleton3D).get_bone_global_pose(i)).origin
				if first:
					result = AABB(p, Vector3.ZERO)
					first = false
				else:
					result = result.expand(p)
		# Botten liggen ín het lichaam (huid/hoed steekt uit) → kleine marge.
		return result.grow(result.size.y * 0.05)
	var result2 := AABB()
	var first2 := true
	for vi in root.find_children("*", "VisualInstance3D", true, false):
		var ab: AABB = (inv * (vi as VisualInstance3D).global_transform) * (vi as VisualInstance3D).get_aabb()
		if first2:
			result2 = ab
			first2 = false
		else:
			result2 = result2.merge(ab)
	return result2

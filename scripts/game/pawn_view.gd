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
var _model_path: String = "" # pad van het geladen karaktermodel (voor _gibs.glb)
var _weapon: Node3D = null   # musket-prop aan de hand (vliegt weg bij dood)
var last_fit: Dictionary = {}  # laatste auto-fit meting (Model-tuner toont dit)
var _team_ring: CSGTorus3D = null  # plat gloeiend voetringetje in teamkleur
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
static func _vfx_entry(dir_path: String, boost: float) -> Dictionary:
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
						list.append({"tex": _black_to_alpha(tex, boost), "cols": cols, "rows": rows})
		_vfx_cache[dir_path] = list
	var list2: Array = _vfx_cache[dir_path]
	if list2.is_empty():
		return {}
	return list2[randi() % list2.size()]


static func _smoke_entry() -> Dictionary:
	return _vfx_entry(SMOKE_TEX_DIR, 2.3)


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
static func spawn_powder_smoke(parent: Node3D, pos: Vector3, count: int, size: float, dir: Vector3 = Vector3.ZERO, life_mult: float = 1.0) -> void:
	if parent == null:
		return
	var amount := int(clampf(float(count) * fx("smoke_amount", 1.0), 0.0, 24.0))
	for i in amount:
		var e := _smoke_entry()
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
	_team_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_team_ring)


## Team-ring alleen onder pionnen die meedoen (gekoppeld aan een levende
## kaart). Ongekoppelde of uitgeschakelde pionnen staan er kaal bij.
func set_team_ring_visible(v: bool) -> void:
	if _team_ring != null:
		_team_ring.visible = v


## Live bijstellen van de ring-gloed vanuit het sfeer-paneel (toets L in-game).
func set_ring_glow(mult: float) -> void:
	if _team_ring == null:
		return
	var mat := _team_ring.material_override as StandardMaterial3D
	if mat != null:
		mat.emission_energy_multiplier = 0.55 * mult


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
	_play_variant(anim_attack)


## Melee-klap: eigen clip als het model die heeft, anders de (schiet)attack.
func play_melee() -> void:
	if _anim != null and not _variants_of(anim_melee).is_empty():
		# melee-tempo: bajonet/zwaard-clips zijn lang; sneller afspelen houdt
		# het gevecht strak (raakmoment stem je af met melee-raakmoment).
		_play_variant(anim_melee, false, fx("melee_speed", 1.4))
	else:
		_play_variant(anim_attack)


func play_die() -> void:
	_play_variant(anim_die)


## Hit-reactie: korte incasseer-clip als de pion een klap/schot OVERLEEFT
## (hit1/hit2, random). Modellen zonder hit-clip doen gewoon niets extra's.
func play_hit() -> void:
	if _anim != null and not _variants_of(anim_hit).is_empty():
		_play_variant(anim_hit)


## Speel een willekeurige variant van een basisclip: "walk" kiest uit
## walk/walk2/walk3, "die" uit die/die2, enz. desync = start op een
## willekeurig punt in de clip, zodat 22 muizen nooit synchroon ademen
## of in de maat marcheren.
func _play_variant(base: String, desync: bool = false, speed: float = 1.0) -> void:
	if _anim == null:
		return
	var variants := _variants_of(base)
	if variants.is_empty():
		return
	var full: String = variants[randi() % variants.size()]
	if _anim.current_animation == full:
		return
	_anim.play(full, 0.2, speed)  # korte crossfade tussen houdingen
	_last_clip_len = _anim.get_animation(full).length / maxf(speed, 0.01)
	if desync:
		_anim.seek(randf() * _anim.get_animation(full).length, false)


## Duur van de laatst gestarte clip (voor timing: bv. oprukken pas na de
## bajonetstoot). Al gecorrigeerd voor de afspeelsnelheid.
func last_clip_duration() -> float:
	return _last_clip_len


## Alle varianten van een basisnaam in het model: exact ("walk") of met
## volgnummer ("walk2"), inclusief bibliotheek-voorvoegsel ("lib/walk2").
## Synoniemen zoals clips uit Blender/Mixamo heten, zodat een model met
## "fire" of "death1/death2" werkt zonder hernoemen of her-export.
const ANIM_ALIASES: Dictionary = {
	"attack": ["fire", "shoot"],
	"die": ["death"],
	"melee": ["bayonet", "sword", "punch", "stab"],
	"hit": ["hurt", "flinch"],
}


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
	for base in [anim_idle, anim_walk]:
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
	_ring.visible = false
	set_hovered(false)
	var dir := world_dir
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = Vector3(0, 0, 1)
	dir = dir.normalized()
	_fling_weapon(dir)  # musket vliegt uit de handen
	# Alleen kanon-kracht klapt het lijf volledig uiteen in zijn brokstukken.
	if strength >= 1.2 and _spawn_gibs(dir, strength):
		if _piece != null:
			_piece.visible = false  # de brokstukken zíjn het lijk
		_become_debris()
		# Grove bloedmist + druppel-fontein op het moment van de knal; de
		# druppels regenen neer en laten vlekken achter op het bord.
		var mist := fx("blood_mist", 1.0)
		if mist > 0.0:
			_spawn_blood_mist(global_position + Vector3.UP * 0.45, dir, mist)
			_spawn_blood_burst(global_position + Vector3.UP * 0.5, int(18.0 * mist), dir)
		_spawn_blood_burst(global_position + Vector3.UP * 0.4, int(16 * fx("blood_burst", 1.0)))
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
		_anim.play(clip, 0.2)
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
func _fling_weapon(world_dir: Vector3) -> void:
	if _weapon == null or not is_instance_valid(_weapon):
		return
	var w: Node3D = _weapon
	_weapon = null
	var scene_parent := get_parent()
	if scene_parent == null:
		return
	var xf := w.global_transform
	w.get_parent().remove_child(w)
	scene_parent.add_child(w)
	w.global_transform = xf
	var land := Vector3(xf.origin.x, global_position.y + 0.04, xf.origin.z) + world_dir * 0.65
	var peak := xf.origin.lerp(land, 0.5) + Vector3.UP * 0.55
	# Tollen alleen tijdens de vlucht; daarna snel plat op de grond.
	var spin := w.create_tween()
	spin.tween_property(w, "rotation", w.rotation + Vector3(2.4, 1.2, 3.0), 0.44) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var arc := w.create_tween()
	arc.tween_property(w, "global_position", peak, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	arc.tween_property(w, "global_position", land, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	arc.tween_property(w, "rotation", _flat_rotation(w), 0.12)
	# Het musket blijft op het bord liggen (opruiming via battlefield_debris).
	w.add_to_group("battlefield_debris")


## Het lijk/brokstuk blijft op het bord tot de volgende definieerfase;
## game._clear_debris() laat alles in de groep "battlefield_debris" wegzinken.
func _become_debris() -> void:
	if _team_ring != null:
		_team_ring.visible = false  # gesneuveld: geen team-ring meer
	add_to_group("battlefield_debris")
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
	var gibs_path := _model_path.get_basename() + "_gibs.glb"
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
	return true


func _is_hat(node: Node) -> bool:
	return String(node.name).to_lower().contains("hat")


## Poel-maat per brokstuk (multiplier): elk stuk krijgt precies EEN poel
## recht onder zijn landingsplek — de romp een grote, ledematen een normale,
## het hoedje een kleintje. (Het musket bloedt nooit: _fling_weapon spawnt
## geen bloed.)
func _blood_size_for(part: Node3D) -> float:
	var n := String(part.name).to_lower()
	if n.contains("torso"):
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
	var target: MeshInstance3D = null
	for mi in live:
		if String(mi.name).to_lower().contains(part_name):
			target = mi
			break
	if target == null or not target.visible:
		return false
	var start: Variant = _fling_single_gib(part_name, dir, violence, time_scale)
	if start == null:
		return false
	target.visible = false
	if not part_name.contains("hat"):
		# Bloed spuit uit het gat waar het ledemaat zat, van het lijf af.
		var out: Vector3 = (start as Vector3) - global_position
		_spawn_blood_spurt(start as Vector3, out, int(7.0 * fx("blood_spurt", 1.0)))
	return true


## Laad het gibs-bestand en slinger alléén het deel met deze naam weg;
## de rest blijft verborgen. Geeft de startpositie van het deel terug
## (= de wond-plek op het lijf), of null als het deel niet bestaat.
func _fling_single_gib(part_name: String, dir: Vector3, violence: float, time_scale: float = 1.0) -> Variant:
	if _model_path == "" or _piece == null:
		return null
	var gibs_path := _model_path.get_basename() + "_gibs.glb"
	if not ResourceLoader.exists(gibs_path):
		return null
	var scene_parent := get_parent()
	if scene_parent == null:
		return null
	var parts_root: Node3D = (load(gibs_path) as PackedScene).instantiate()
	scene_parent.add_child(parts_root)
	parts_root.global_transform = (_piece as Node3D).global_transform
	var chosen: Node3D = null
	for part in parts_root.find_children("*", "MeshInstance3D", true, false):
		if chosen == null and String(part.name).to_lower().contains(part_name):
			chosen = part as Node3D
		else:
			(part as MeshInstance3D).visible = false
	if chosen == null:
		parts_root.queue_free()
		return null
	var start := chosen.global_position
	_fling_part(chosen, dir, violence, time_scale)
	parts_root.add_to_group("battlefield_debris")
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
func set_character(doctrine: int, unit_type: int, card) -> void:
	if _model != null:
		return
	var arch: String = "base"
	if card != null:
		arch = Constants.card_archetype(card.hp, card.stamina, card.attack)
	var key := "%d:%d:%s" % [doctrine, unit_type, arch]
	if key == _char_key:
		return
	_char_key = key
	_unit_type = unit_type
	var fac: String = Constants.doctrine_folder(doctrine)
	var tname: String = Constants.unit_type_file(unit_type)
	var candidates: Array = [
		"%s%s/%s_%s.glb" % [MODELS_DIR, fac, tname, arch],
		"%s%s/%s_base.glb" % [MODELS_DIR, fac, tname],
	]
	for path in candidates:
		if ResourceLoader.exists(path):
			_tune_key = "%s/%s" % [fac, String(path).get_file().get_basename()]
			_model_path = path
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


## Wapen-prop (musket) aan de rechterhand van het karaktermodel. Conventie:
## assets/models/<factie>/musket.glb of .fbx (statische mesh). De prop wordt
## automatisch op musketlengte (~0.55 wereld-unit) geschaald; fijnafstelling
## via model_tuning.json sleutel "<factie>/musket":
##   {"scale": 1.0, "pos": [x,y,z], "rot": [graden x,y,z]}
func _attach_weapon(fac: String) -> void:
	if _unit_type != 0:
		return  # v1: alleen infanterie draagt het musket
	var path := ""
	for ext in [".glb", ".fbx"]:
		var p := "%s%s/musket%s" % [MODELS_DIR, fac, ext]
		if ResourceLoader.exists(p):
			path = p
			break
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
	var ab := _combined_aabb(prop)
	var longest: float = maxf(ab.size.x, maxf(ab.size.y, ab.size.z))
	var parent_scale: float = prop.global_transform.basis.get_scale().x
	if longest > 0.0001 and parent_scale > 0.0001:
		var factor := 0.55 / (longest * parent_scale)
		prop.scale = Vector3(factor, factor, factor)
	# Fijnafstelling uit de tuning: pos ≈ wereld-units langs de hand-assen
	# (gecorrigeerd voor skelet-schaal), rotatie in graden.
	var t: Dictionary = model_tuning().get("%s/musket" % fac, {})
	prop.scale *= float(t.get("scale", 1.0))
	var pos: Array = t.get("pos", [0.0, 0.0, 0.0])
	var rot: Array = t.get("rot", [0.0, 0.0, 0.0])
	prop.position = Vector3(float(pos[0]), float(pos[1]), float(pos[2])) / maxf(parent_scale, 0.0001)
	prop.rotation_degrees = Vector3(float(rot[0]), float(rot[1]), float(rot[2]))
	_weapon = prop


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


func _apply_team_texture() -> void:
	if _piece == null or _model_path == "":
		return
	var suffix := "_red" if team == Constants.Team.RED else "_blue"
	var tex_path := _model_path.get_basename() + suffix + ".png"
	if not _team_tex_cache.has(tex_path):
		_team_tex_cache[tex_path] = load(tex_path) if ResourceLoader.exists(tex_path) else null
	var tex: Texture2D = _team_tex_cache[tex_path]
	if tex == null:
		return
	for mi in _piece.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).get_active_material(0)
		if m is BaseMaterial3D:
			var dup := (m as BaseMaterial3D).duplicate()
			(dup as BaseMaterial3D).albedo_texture = tex
			(mi as MeshInstance3D).material_override = dup


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

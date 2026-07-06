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
	add_child(_ring)


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
		_play_variant(anim_melee)
	else:
		_play_variant(anim_attack)


func play_die() -> void:
	_play_variant(anim_die)


## Speel een willekeurige variant van een basisclip: "walk" kiest uit
## walk/walk2/walk3, "die" uit die/die2, enz. desync = start op een
## willekeurig punt in de clip, zodat 22 muizen nooit synchroon ademen
## of in de maat marcheren.
func _play_variant(base: String, desync: bool = false) -> void:
	if _anim == null:
		return
	var variants := _variants_of(base)
	if variants.is_empty():
		return
	var full: String = variants[randi() % variants.size()]
	if _anim.current_animation == full:
		return
	_anim.play(full, 0.2)  # korte crossfade tussen houdingen
	if desync:
		_anim.seek(randf() * _anim.get_animation(full).length, false)


## Alle varianten van een basisnaam in het model: exact ("walk") of met
## volgnummer ("walk2"), inclusief bibliotheek-voorvoegsel ("lib/walk2").
func _variants_of(base: String) -> Array:
	if _variant_cache.has(base):
		return _variant_cache[base]
	var out: Array = []
	for a in _anim.get_animation_list():
		var n := String(a)
		n = n.get_slice("/", n.get_slice_count("/") - 1)
		if n == base or (n.begins_with(base) and n.substr(base.length()).is_valid_int()):
			out.append(String(a))
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
func play_death(world_dir: Vector3, strength: float = 0.7) -> void:
	_ring.visible = false
	set_hovered(false)
	var dir := world_dir
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = Vector3(0, 0, 1)
	dir = dir.normalized()
	_fling_weapon(dir)  # musket vliegt uit de handen
	if _spawn_gibs(dir, strength):
		if _piece != null:
			_piece.visible = false  # de brokstukken zíjn het lijk
		_become_debris()
		_spawn_blood(global_position + dir * 0.25, 3 + int(strength * 2.5), 0.3)
		return
	# Fallback zonder gibs: klassieke omvaller die blijft liggen.
	play_die()  # echte model-anim indien aanwezig
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
	rest.y = start_pos.y - 0.02
	var slide := create_tween()
	slide.tween_property(self, "position", start_pos + dir * 0.3 + Vector3(0, 0.18, 0), 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	slide.tween_property(self, "position", rest, 0.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_become_debris()
	_spawn_blood(global_position + dir * 0.35, 3, 0.3)


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
	var land := Vector3(xf.origin.x, global_position.y, xf.origin.z) + world_dir * 0.65
	var peak := xf.origin.lerp(land, 0.5) + Vector3.UP * 0.55
	var spin := w.create_tween()
	spin.tween_property(w, "rotation", w.rotation + Vector3(3.5, 1.7, 4.6), 0.95)
	var arc := w.create_tween()
	arc.tween_property(w, "global_position", peak, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	arc.tween_property(w, "global_position", land, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# Het musket blijft op het bord liggen (opruiming via battlefield_debris).
	w.add_to_group("battlefield_debris")


## Het lijk/brokstuk blijft op het bord tot de volgende definieerfase;
## game._clear_debris() laat alles in de groep "battlefield_debris" wegzinken.
func _become_debris() -> void:
	add_to_group("battlefield_debris")
	if _sokkel != null and is_instance_valid(_sokkel):
		_sokkel.visible = false  # geen team-marker onder een lijk (leest als pion)
	var area := get_node_or_null("Area3D")
	if area is Area3D:
		(area as Area3D).collision_layer = 0


## Bloedspetters op het bord (roet bij artillerie): platte donkerrode schijfjes
## rond het inslagpunt, plat op de tegel. Gaan mee in de debris-opruiming.
func _spawn_blood(world_center: Vector3, amount: int, spread: float = 0.25) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var ground_y := global_position.y - 0.035
	var blood := _unit_type != 2  # kanonnen bloeden niet: roet/olie
	for i in amount:
		var disc := MeshInstance3D.new()
		var m := CylinderMesh.new()
		m.top_radius = randf_range(0.05, 0.14)
		m.bottom_radius = m.top_radius
		m.height = 0.004
		disc.mesh = m
		var mat := StandardMaterial3D.new()
		if blood:
			mat.albedo_color = Color(randf_range(0.32, 0.5), 0.02, 0.03)
		else:
			mat.albedo_color = Color(0.08, 0.08, 0.09)
		mat.roughness = 0.4
		disc.material_override = mat
		parent.add_child(disc)
		disc.add_to_group("battlefield_debris")
		disc.global_position = Vector3(
			world_center.x + randf_range(-spread, spread),
			ground_y,
			world_center.z + randf_range(-spread, spread))
		disc.rotation.y = randf() * TAU


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
	# Het lijf valt ALTIJD uiteen in zijn delen; de klap bepaalt hoe gewelddadig:
	# kanon (1.4) slingert vrijwel alles ver weg, musket/melee laat het meeste
	# ter plekke in elkaar zakken met hooguit een paar vliegende delen
	# (het hoedje het eerst).
	var violence := clampf((strength - 0.45) / 0.95, 0.18, 1.0)
	var parts_root: Node3D = (load(gibs_path) as PackedScene).instantiate()
	scene_parent.add_child(parts_root)
	# Zelfde maat/rotatie/plek als het getunede lijf.
	parts_root.global_transform = (_piece as Node3D).global_transform
	var parts: Array = parts_root.find_children("*", "MeshInstance3D", true, false)
	if parts.is_empty():
		parts_root.queue_free()
		return false
	var pool: Array = parts.duplicate()
	pool.shuffle()
	pool.sort_custom(func(a, b): return _is_hat(a) and not _is_hat(b))
	var i := 0
	for part in pool:
		var fly := randf() < violence or (i == 0 and randf() < 0.85)
		if fly:
			_fling_part(part as Node3D, dir, violence)
		else:
			_drop_part(part as Node3D)
		i += 1
	parts_root.add_to_group("battlefield_debris")
	return true


func _is_hat(node: Node) -> bool:
	return String(node.name).to_lower().contains("hat")


## Eén brokstuk wegslingeren: boog in de klap-richting + radiale spreiding,
## tollend neerkomen en blijven liggen. Alleen tweens op het deel zelf.
## violence (0..1) schaalt de afstand en hoogte van de worp.
func _fling_part(part: Node3D, dir: Vector3, violence: float = 1.0) -> void:
	var radial := part.global_position - global_position
	radial.y = 0.0
	if radial.length() > 0.01:
		radial = radial.normalized()
	else:
		radial = Vector3(randf() - 0.5, 0.0, randf() - 0.5).normalized()
	var power := 0.5 + 0.85 * violence
	var fling := (dir * 0.7 + radial * 0.5 + Vector3(randf() - 0.5, 0.0, randf() - 0.5) * 0.4) * power
	fling.y = 0.0
	var from := part.global_position
	var land := Vector3(from.x, global_position.y, from.z) + fling
	var peak := from.lerp(land, 0.5) + Vector3.UP * randf_range(0.35, 0.7) * power
	var spin := part.create_tween()
	spin.tween_property(part, "rotation", part.rotation + Vector3(
		randf_range(-6.0, 6.0), randf_range(-4.0, 4.0), randf_range(-6.0, 6.0)), 1.0)
	var arc := part.create_tween()
	arc.tween_property(part, "global_position", peak, randf_range(0.2, 0.3)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	arc.tween_property(part, "global_position", land, randf_range(0.2, 0.3)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# Het deel blijft liggen waar het landt (opruiming via battlefield_debris).
	_spawn_blood(land, 1, 0.08)


## Zacht in elkaar zakken: het deel ploft vrijwel ter plekke op de tegel met
## een kleine kantel — het "lijk op de grond"-gedeelte van een lichte gib.
func _drop_part(part: Node3D) -> void:
	var from := part.global_position
	var land := Vector3(
		from.x + randf_range(-0.08, 0.08),
		global_position.y - 0.02,
		from.z + randf_range(-0.08, 0.08))
	var tumble := part.create_tween()
	tumble.tween_property(part, "rotation", part.rotation + Vector3(
		randf_range(-1.2, 1.2), randf_range(-0.8, 0.8), randf_range(-1.2, 1.2)), 0.3)
	var drop := part.create_tween()
	drop.tween_property(part, "global_position", land, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_spawn_blood(land, 1, 0.07)


func _on_anim_finished(anim_name: String) -> void:
	# Eenmalige animaties (aanval) keren terug naar idle; lopen stuurt game.gd zelf.
	# Voorvoegsel ("lib/attack") en variant-nummer ("attack2") strippen.
	var n := String(anim_name)
	n = n.get_slice("/", n.get_slice_count("/") - 1).rstrip("0123456789")
	if n == anim_attack or n == anim_melee:
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
	if auto_fit:
		_auto_fit_model(_piece)
	# AnimationPlayer in het stuk aanhaken (bv. een .glb met idle/walk/attack/die).
	# De geometrische stukken hebben er geen — dan blijft _anim gewoon null.
	_anim = _find_anim_player(_piece)
	_variant_cache = {}
	if _anim != null:
		_anim.animation_finished.connect(_on_anim_finished)
		_make_loops()
		play_idle()
	for node in _piece.find_children("*", "GeometryInstance3D", true, false):
		if node.is_in_group("team_tint"):
			_tint_nodes.append(node)
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
	var target_h: float = 1.1 if _unit_type == 1 else (0.8 if _unit_type == 2 else 0.9)
	var footprint: float = maxf(aabb.size.x, aabb.size.z)
	var s: float = target_h / aabb.size.y
	if footprint > 0.0001:
		s = minf(s, 0.95 / footprint)  # armen/loop mogen de buur-tegel niet in
	root.scale = Vector3(s, s, s)
	root.rotation.y = PI
	# Na rotatie om Y (x,z → -x,-z): centreer het AABB-midden op de tegel en
	# zet de onderkant op de grond.
	var center := aabb.get_center()
	root.position = Vector3(s * center.x, -s * aabb.position.y, s * center.z)
	# Handmatige correctie uit de Model-tuner bovenop de auto-fit. x/z schuiven
	# het model binnen het vak (lokale ruimte, draait dus mee met de kijkrichting).
	var t: Dictionary = model_tuning().get(_tune_key, {})
	if not t.is_empty():
		var extra: float = float(t.get("scale", 1.0))
		root.scale *= extra
		root.position *= extra  # grond/centrering schalen mee
		root.position += Vector3(float(t.get("x", 0.0)), float(t.get("y", 0.0)), float(t.get("z", 0.0)))


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

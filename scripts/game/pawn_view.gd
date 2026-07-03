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
var _piece: Node3D = null
var _tint_nodes: Array = []  # CSG-delen in groep "team_tint" → teamkleur/status

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
	_play(anim_idle)


func play_walk() -> void:
	_play(anim_walk)


func play_attack() -> void:
	_play(anim_attack)


func play_die() -> void:
	_play(anim_die)


func _play(anim_name: String) -> void:
	if _anim != null and _anim.has_animation(anim_name) and _anim.current_animation != anim_name:
		_anim.play(anim_name)


func _on_anim_finished(anim_name: String) -> void:
	# Eenmalige animaties (aanval) keren terug naar idle; lopen stuurt game.gd zelf.
	if anim_name == anim_attack:
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
	if _model != null:
		return  # echt karaktermodel (model_scene): niets extra's nodig
	if _piece != null:
		_piece.queue_free()
		_piece = null
		_tint_nodes = []
	var scene: PackedScene = PIECE_SCENES.get(unit_type)
	if scene == null:
		return
	_piece = scene.instantiate()
	add_child(_piece)
	# Team-kleurbare delen verzamelen (groep "team_tint" in de stuk-scene).
	for node in _piece.find_children("*", "CSGShape3D", true, false):
		if node.is_in_group("team_tint"):
			_tint_nodes.append(node)
	# Placeholder-blokje + neusje verbergen; het stuk heeft zelf een voorkant (-Z).
	_mesh.visible = false
	_marker.visible = false
	_update_material()

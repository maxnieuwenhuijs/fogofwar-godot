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

## Karaktermodellen per factie/type/archetype (zie MODEL-WISHLIST.md):
##   assets/models/<factie>/<type>_<archetype>.glb   bv. muis/infanterie_spd.glb
##   assets/models/<factie>/<type>_basis.glb         neutraal / ongekoppeld
## Fallback-keten: exact archetype → basis van dat type → geometrisch stuk
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
	"basis": Vector3.ONE,
}

var _piece: Node3D = null
var _sokkel: CSGCylinder3D = null  # team-gekleurd voetstuk onder .glb-modellen
var _tint_nodes: Array = []  # delen in groep "team_tint" → teamkleur/status
var _unit_type: int = -1
var _char_key: String = ""   # laatst getoonde factie:type:archetype (idempotent)

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


## Lichte ragdoll: de pion valt om in de knockback-richting, glijdt een stukje
## door en zinkt daarna in de grond weg. Ruimt zichzelf op (queue_free) aan het
## eind. Geen echte physics — een goedkope, voorspelbare "topple".
func play_death(world_dir: Vector3) -> void:
	_ring.visible = false
	set_hovered(false)
	play_die()  # echte model-anim indien aanwezig
	var dir := world_dir
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = Vector3(0, 0, 1)
	dir = dir.normalized()
	# Kantel-as staat loodrecht op de valrichting (omvallen "voorover").
	var axis := Vector3.UP.cross(dir).normalized()
	if axis.length() < 0.01:
		axis = Vector3(1, 0, 0)
	var start_basis := transform.basis
	var start_pos := position
	var tw := create_tween().set_parallel(true)
	# Omvallen (~100°) in ~0.35s.
	tw.tween_method(
		func(ang: float) -> void: transform.basis = start_basis.rotated(axis, ang),
		0.0, deg_to_rad(100.0), 0.35).set_ease(Tween.EASE_IN)
	# Doorglijden + kleine stuiter omhoog en neer.
	tw.tween_property(self, "position", start_pos + dir * 0.5 + Vector3(0, 0.2, 0), 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Daarna wegzinken door het bord en verdwijnen.
	tw.chain().tween_interval(0.25)
	tw.chain().tween_property(self, "position:y", start_pos.y - 1.2, 0.35).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)


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
	var arch: String = "basis"
	if card != null:
		arch = Constants.card_archetype(card.hp, card.stamina, card.attack)
	var key := "%d:%d:%s" % [doctrine, unit_type, arch]
	if key == _char_key:
		return
	_char_key = key
	_unit_type = unit_type
	var fac: String = Constants.doctrine_name(doctrine).to_lower()
	var tname: String = Constants.unit_type_name(unit_type).to_lower()
	var candidates: Array = [
		"%s%s/%s_%s.glb" % [MODELS_DIR, fac, tname, arch],
		"%s%s/%s_basis.glb" % [MODELS_DIR, fac, tname],
	]
	for path in candidates:
		if ResourceLoader.exists(path):
			_swap_piece(load(path), true)  # auto-fit: schaal/grond/180°
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
	if _anim != null:
		_anim.animation_finished.connect(_on_anim_finished)
		play_idle()
	for node in _piece.find_children("*", "GeometryInstance3D", true, false):
		if node.is_in_group("team_tint"):
			_tint_nodes.append(node)
	# Kale .glb-modellen hebben geen "team_tint"-groep (groepen zitten in .tscn's,
	# niet in glTF) → automatisch een team-gekleurd sokkeltje eronder, zodat
	# rood/blauw altijd te zien is (ook bij Muis-tegen-Muis). Als child van de
	# PawnView zelf, zodat de auto-fit-schaal van het model hem niet verkleint.
	if _tint_nodes.is_empty():
		_sokkel = CSGCylinder3D.new()
		_sokkel.radius = 0.34
		_sokkel.height = 0.08
		_sokkel.position = Vector3(0.0, 0.04, 0.0)
		add_child(_sokkel)
		_tint_nodes.append(_sokkel)
	# Placeholder-blokje + neusje verbergen; het stuk heeft zelf een voorkant (-Z).
	_mesh.visible = false
	_marker.visible = false
	_update_material()


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

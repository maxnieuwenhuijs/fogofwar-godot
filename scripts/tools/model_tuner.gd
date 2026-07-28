extends Node3D

## Model-tuner: meet per factie/type/archetype in hoe groot een karaktermodel
## op het bord staat, met sliders voor schaal en hoogte. "Opslaan" schrijft
## naar assets/models/model_tuning.json; het spel past die correcties daarna
## automatisch toe (PawnView._auto_fit_model). Te openen via het hoofdmenu.

const PAWN_SCENE := preload("res://scenes/game/pawn_view.tscn")
const SAVE_PATH := "res://assets/models/model_tuning.json"

const ARCHS: Array = ["base", "spd", "hp", "atk", "mix"]
## Kaart-stats die het gewenste archetype forceren (dominante stat).
const ARCH_CARDS: Dictionary = {
	"spd": [1, 3, 1], "hp": [3, 1, 1], "atk": [1, 1, 3], "mix": [2, 2, 1],
}
## Effect-knopjes (effects_tuning.json): label, bereik en standaardwaarde.
const FX_DEFS: Array = [
	{"cat": "bajonet", "key": "melee_speed", "label": "stoot-tempo", "min": 0.2, "max": 10.0, "step": 0.01, "def": 1.4},
	{"cat": "bajonet", "key": "melee_hit_delay", "label": "raakmoment", "min": 0.0, "max": 3.0, "step": 0.01, "def": 1.0},
	{"cat": "bajonet", "key": "melee_yaw", "label": "aanvaller-draai", "min": -180.0, "max": 180.0, "step": 1.0, "def": 0.0},
	{"cat": "bajonet", "key": "melee_advance_delay", "label": "opruk-vertraging", "min": 0.0, "max": 3.0, "step": 0.01, "def": 0.5},
	{"cat": "bajonet", "key": "melee_move_wait", "label": "opruk-wacht (dood)", "min": 0.0, "max": 1.5, "step": 0.01, "def": 0.3},
	{"cat": "bajonet", "key": "hit_speed", "label": "hit-tempo", "min": 0.2, "max": 10.0, "step": 0.01, "def": 1.0},
	{"cat": "bajonet", "key": "death_speed", "label": "sterf-tempo", "min": 0.2, "max": 10.0, "step": 0.01, "def": 1.0},
	{"cat": "bajonet", "key": "melee_retaliation_delay", "label": "terugslag-vertraging", "min": 0.0, "max": 3.0, "step": 0.01, "def": 0.1},
	{"cat": "gore", "key": "hat_fling_power", "label": "hoed-kracht", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.5},
	{"cat": "gore", "key": "hat_fling_time", "label": "hoed-hangtijd", "min": 0.1, "max": 10.0, "step": 0.01, "def": 1.8},
	{"cat": "gore", "key": "hat_pop_chance", "label": "hoed-kans", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.55},
	{"cat": "gore", "key": "limb_shed_chance", "label": "ledemaat-kans", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.4},
	{"cat": "gore", "key": "limb_fling_power", "label": "ledemaat-kracht", "min": 0.0, "max": 10.0, "step": 0.01, "def": 0.9},
	{"cat": "gore", "key": "limb_fling_time", "label": "ledemaat-hangtijd", "min": 0.1, "max": 10.0, "step": 0.01, "def": 1.0},
	{"cat": "gore", "key": "gib_fling_power", "label": "gib-worpkracht", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.0},
	{"cat": "gore", "key": "gib_spin", "label": "gib-tolling", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.0},
	{"cat": "bloed", "key": "blood_burst", "label": "wond-druppels", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.0},
	{"cat": "bloed", "key": "blood_spurt", "label": "spuit-straal", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.0},
	{"cat": "bloed", "key": "blood_mist", "label": "kanon-mist", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.0},
	{"cat": "bloed", "key": "mist_travel", "label": "mist-dracht", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.6},
	{"cat": "bloed", "key": "drop_fall_time", "label": "druppel-duur", "min": 0.1, "max": 10.0, "step": 0.01, "def": 1.0},
	{"cat": "bloed", "key": "drop_size", "label": "druppel-maat", "min": 0.1, "max": 10.0, "step": 0.01, "def": 1.0},
	{"cat": "bloed", "key": "wound_blood", "label": "wond-bloed (overleven)", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.0},
	{"cat": "bloed", "key": "wound_delay", "label": "wond-vertraging", "min": 0.0, "max": 3.0, "step": 0.01, "def": 0.0},
	{"cat": "bloed", "key": "drop_stain_chance", "label": "druppel-vlekkans", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.35},
	{"cat": "bloed", "key": "drop_stain_delay", "label": "vlek-wacht", "min": 0.0, "max": 10.0, "step": 0.01, "def": 0.05},
	{"cat": "bloed", "key": "drop_stain_grow", "label": "vlek-groei", "min": 0.05, "max": 10.0, "step": 0.01, "def": 0.25},
	{"cat": "bloed", "key": "gib_pool_delay", "label": "gib-poel-wacht", "min": 0.0, "max": 10.0, "step": 0.01, "def": 0.1},
	{"cat": "bloed", "key": "gib_pool_grow", "label": "gib-poel-groei", "min": 0.05, "max": 10.0, "step": 0.01, "def": 0.45},
	{"cat": "bloed", "key": "blood_extra_delay", "label": "plas-wacht", "min": 0.0, "max": 10.0, "step": 0.01, "def": 0.4},
	{"cat": "bloed", "key": "blood_grow", "label": "plas-groei", "min": 0.05, "max": 10.0, "step": 0.01, "def": 1.0},
	{"cat": "bloed", "key": "blood_size", "label": "plas-maat", "min": 0.05, "max": 10.0, "step": 0.01, "def": 1.0},
	{"cat": "bloed", "key": "death_blood_delay", "label": "lijkpoel-fallback", "min": 0.0, "max": 10.0, "step": 0.01, "def": 0.9},
	{"cat": "rook", "key": "smoke_amount", "label": "rook-aantal", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.0},
	{"cat": "rook", "key": "smoke_size", "label": "rook-maat", "min": 0.1, "max": 10.0, "step": 0.01, "def": 1.0},
	{"cat": "rook", "key": "smoke_grow", "label": "rook-groei", "min": 0.5, "max": 10.0, "step": 0.01, "def": 3.0},
	{"cat": "rook", "key": "smoke_life", "label": "rook-duur", "min": 0.1, "max": 10.0, "step": 0.01, "def": 1.8},
	{"cat": "rook", "key": "smoke_drift", "label": "rook-drift", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.0},
	{"cat": "rook", "key": "smoke_alpha", "label": "rook-alpha", "min": 0.05, "max": 1.0, "step": 0.01, "def": 1.0},
	{"cat": "rook", "key": "smoke_fade", "label": "rook-vervaag", "min": 0.0, "max": 0.95, "step": 0.01, "def": 0.35},
	{"cat": "rook", "key": "smoke_linger_chance", "label": "rook-blijfkans", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.25},
	{"cat": "rook", "key": "smoke_rise", "label": "rook-stijg", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.0},
	{"cat": "rook", "key": "impact_smoke_life", "label": "inslag-rook-duur", "min": 0.05, "max": 5.0, "step": 0.01, "def": 0.6},
	{"cat": "rook", "key": "fire_size", "label": "vuur-maat", "min": 0.1, "max": 10.0, "step": 0.01, "def": 1.0},
	{"cat": "rook", "key": "fire_life", "label": "vuur-duur", "min": 0.03, "max": 2.0, "step": 0.01, "def": 0.14},
	{"cat": "rook", "key": "fire_light", "label": "vuur-licht", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.6},
	{"cat": "rook", "key": "fire_shake", "label": "vuur-schok", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.0},
]

var _pawn: PawnView = null
var _ref: PawnView = null
var _fac_btn: OptionButton
var _type_btn: OptionButton
var _arch_btn: OptionButton
var _scale_slider: HSlider
var _y_slider: HSlider
var _scale_spin: SpinBox
var _y_spin: SpinBox
var _x_spin: SpinBox
var _z_spin: SpinBox
var _weapon_spins: Dictionary = {}  # "scale"/"px"/"py"/"pz"/"rx"/"ry"/"rz" -> SpinBox
var _muzzle_spins: Dictionary = {}  # vuurmond "x"/"y"/"z" -> SpinBox
var _muzzle_gizmo: Node3D = null    # oranje merkteken op de vuurmond

# --- Sleep-gizmo (besluit Max, 28 juli): drie assen die je met de muis pakt,
# i.p.v. cijfers tikken. Werkt op wat er in de hand zit (musket of prop) of op
# de vuurmond; schrijft exact dezelfde tuning-waarden als de spinboxen.
var _sleep_btn: OptionButton = null
var _sleep_gizmo: Node3D = null
var _sleep_armen: Array = []          # 3x MeshInstance3D (X rood, Y groen, Z blauw)
var _sleep_as: int = -1               # 0/1/2 tijdens slepen, anders -1
var _sleep_modus: String = ""         # "hand" of "vuurmond" tijdens het slepen
var _sleep_oorsprong := Vector3.ZERO  # aangrijppunt bij het begin van de sleep
var _sleep_richting := Vector3.ZERO   # wereldrichting van de gepakte as
var _sleep_start_t: float = 0.0       # parameter langs de as bij muis-neer
var _sleep_start_waarde := Vector3.ZERO
var _sleep_ringen: Array = []         # 3x TorusMesh om te draaien (alleen hand-modus)
var _sleep_draaien: bool = false      # true = ring gepakt (draaien), false = arm (verplaatsen)
var _sleep_start_hoek: float = 0.0
var _sleep_start_euler := Vector3.ZERO
var _hover_as: int = -1               # as onder de muis (voor de highlight)
var _hover_draai: bool = false
var _gizmo_hint: Label = null
const SLEEP_TREFFER_PX := 14.0
const RING_FACTOR := 1.35             # ringstraal t.o.v. de armlengte
const ARM_START := 0.30               # armen beginnen buiten het midden (daar liggen de ringen)
const GIZMO_KLEUREN := [Color(0.95, 0.35, 0.35), Color(0.4, 0.9, 0.45), Color(0.45, 0.65, 1.0)]
const AS_NAMEN := ["X", "Y", "Z"]
var _tuner_light: DirectionalLight3D = null
var _tuner_env: WorldEnvironment = null
var _fx_spins: Dictionary = {}      # effect-sleutel -> SpinBox
var _die_btn: OptionButton          # dood-clip keuze (death_pools-tuning)
var _dp_spins: Dictionary = {}      # "delay"/"grow"/"size"/"forward" -> SpinBox
var _cam: Camera3D = null           # wisselbare camera (spel/close-up/voorkant)
var _hand_btn: OptionButton = null      # wat de pion vasthoudt (musket of een figuranten-prop)
var _hand_label: Label = null           # "In de hand (trommel): schaal" — zegt wat je nu bijstelt
var _view_btn: OptionButton = null

## Figuranten-props (MODEL-WISHLIST 3d): label -> rol ("" = gewoon musket).
const HAND_OPTIES := [
	{"label": "musket", "rol": ""},
	{"label": "vaandel", "rol": "flag"},
	{"label": "trommel", "rol": "drum"},
	{"label": "hoorn", "rol": "horn"},
	{"label": "bijl", "rol": "sapper"},
	{"label": "vat", "rol": "canteen"},
	{"label": "staf", "rol": "drummajor"},
]
var _my_fac_btn: OptionButton = null   # formatie: mijn factie
var _opp_fac_btn: OptionButton = null  # formatie: tegenstander
var _formation_btn: Button = null      # formatie aan/uit (toggle)
var _formation_pawns: Array = []

## Exact de kijkhoek van de bordcamera (Board.tscn) — de spel-view is WYSIWYG.
const CAM_BASIS := Basis(
	Vector3(0.9396926, 0.0, 0.34202012),
	Vector3(0.2513556, 0.67815965, -0.69059384),
	Vector3(-0.23194425, 0.7349146, 0.6372616))
var _info: Label

var _updating := false  # geen slider-events tijdens het her-instellen
var _melee_cycle := 0   # melee-knop bladert door de varianten (bayonet1, 2, ...)


func _ready() -> void:
	_build_world()
	_build_ui()
	_reload_pawns()
	if "gibshot" in OS.get_cmdline_user_args():
		var gs_args := OS.get_cmdline_user_args()
		for a in gs_args:
			var ai := ARCHS.find(a)
			if ai > 0:
				_arch_btn.select(ai)
				_reload_pawns()
		var gs_strength := 1.4
		var gs_kind := "shot"
		if "musket" in gs_args:
			gs_strength = 0.75
		elif "melee" in gs_args:
			gs_strength = 0.7
			gs_kind = "melee"
		await get_tree().create_timer(1.0).timeout
		if _pawn != null and is_instance_valid(_pawn):
			_pawn.play_death(Vector3(0.3, 0.0, 1.0).normalized(), gs_strength, gs_kind)
		await get_tree().create_timer(1.0 if gs_strength < 1.2 else 0.32).timeout
		get_viewport().get_texture().get_image().save_png("res://_shot_gibs.png")
		get_tree().quit()
	if "shot" in OS.get_cmdline_user_args():
		var shot_args := OS.get_cmdline_user_args()
		for a in shot_args:
			var ai := ARCHS.find(a)
			if ai > 0:
				_arch_btn.select(ai)
				_reload_pawns()
		if "voorkant" in shot_args:
			_view_btn.select(2)
		elif "closeup" in shot_args:
			_view_btn.select(1)
		if "formatie" in shot_args:
			_formation_btn.set_pressed(true)
		if "rook" in shot_args:
			_on_smoke_test(4, 0.16)
		if "melee" in shot_args:
			_on_clip("melee")
		if "donker" in shot_args:
			_on_dark_toggled(true)
		if "vuur" in shot_args:
			_on_fire_test()
		_apply_camera()
		await get_tree().create_timer(1.4).timeout
		get_viewport().get_texture().get_image().save_png("res://_shot_tuner.png")
		get_tree().quit()


# --- Wereld: tegels, licht, camera --------------------------------------------

## Gizmo volgt elk frame de actuele vuurmond van het tuning-model.
func _process(_dt: float) -> void:
	if _muzzle_gizmo == null:
		return
	if _pawn != null and is_instance_valid(_pawn) and _pawn._tune_key != "":
		_muzzle_gizmo.visible = true
		# Tijdens een vuurmond-sleep stuurt de muis het merkteken; anders volgt
		# het de opgeslagen waarde.
		if not (_sleep_as >= 0 and _sleep_modus == "vuurmond"):
			_muzzle_gizmo.global_position = _pawn.muzzle_world()
		_muzzle_gizmo.global_rotation = _pawn.global_rotation
	else:
		_muzzle_gizmo.visible = false
	_werk_sleep_gizmo_bij()


func _build_world() -> void:
	for x in range(-2, 3):
		for z in range(-1, 2):
			var tile := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(1.0, 0.1, 1.0)
			tile.mesh = mesh
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.92, 0.92, 0.9) if (x + z) % 2 == 0 else Color(0.18, 0.18, 0.2)
			tile.material_override = mat
			# Zelfde plaatsing als het echte bord: tegel gecentreerd op y=0
			# (top op +0.05), zodat de pion-origin exact op de tegel-top staat.
			tile.position = Vector3(float(x), 0.0, float(z))
			add_child(tile)
	# Debug-hulplijnen: rand + middenkruis van de modeltegel, net boven het
	# oppervlak — zo zie je direct of het model echt gecentreerd staat.
	var dbg := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.albedo_color = Color(1.0, 0.35, 0.2)
	im.surface_begin(Mesh.PRIMITIVE_LINES, dm)
	var ly := 0.052
	var corners := [Vector3(-0.5, ly, -0.5), Vector3(0.5, ly, -0.5),
		Vector3(0.5, ly, 0.5), Vector3(-0.5, ly, 0.5)]
	for ci in 4:
		im.surface_add_vertex(corners[ci])
		im.surface_add_vertex(corners[(ci + 1) % 4])
	im.surface_add_vertex(Vector3(-0.12, ly, 0.0))
	im.surface_add_vertex(Vector3(0.12, ly, 0.0))
	im.surface_add_vertex(Vector3(0.0, ly, -0.12))
	im.surface_add_vertex(Vector3(0.0, ly, 0.12))
	im.surface_end()
	dbg.mesh = im
	add_child(dbg)
	# Vuurmond-gizmo: oranje bolletje + richtingspijltje op de plek waar
	# vuur + rook ontstaan; volgt live de Vuurmond-spinboxen (Model-tab).
	_muzzle_gizmo = Node3D.new()
	var gz_ball := MeshInstance3D.new()
	var gz_mesh := SphereMesh.new()
	gz_mesh.radius = 0.035
	gz_mesh.height = 0.07
	gz_mesh.radial_segments = 10
	gz_mesh.rings = 5
	gz_ball.mesh = gz_mesh
	var gz_mat := StandardMaterial3D.new()
	gz_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gz_mat.albedo_color = Color(1.0, 0.55, 0.1)
	gz_ball.material_override = gz_mat
	gz_ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_muzzle_gizmo.add_child(gz_ball)
	var gz_arrow := MeshInstance3D.new()
	var gz_box := BoxMesh.new()
	gz_box.size = Vector3(0.012, 0.012, 0.16)
	gz_arrow.mesh = gz_box
	gz_arrow.position = Vector3(0.0, 0.0, -0.11)
	gz_arrow.material_override = gz_mat
	gz_arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_muzzle_gizmo.add_child(gz_arrow)
	add_child(_muzzle_gizmo)
	_tuner_light = DirectionalLight3D.new()
	_tuner_light.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	_tuner_light.light_energy = 1.2
	add_child(_tuner_light)
	var env := WorldEnvironment.new()
	_tuner_env = env
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.25, 0.26, 0.28)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.8, 0.85)
	e.ambient_light_energy = 0.7
	env.environment = e
	add_child(env)
	# Camera wisselbaar via de Cam:-keuze (spel / close-up / voorkant).
	# Default = exact de bordcamera (orthograaf, zelfde hoek): WYSIWYG.
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(_cam)
	_cam.current = true
	_apply_camera()
	_bouw_sleep_gizmo()


## Zet de camera volgens de gekozen view; in formatie-modus zoomt elke view
## uit zodat beide linies (3 vs 3 op tegels) volledig in beeld staan.
func _apply_camera() -> void:
	if _cam == null:
		return
	var view := 0 if _view_btn == null else _view_btn.selected
	var big := not _formation_pawns.is_empty()
	match view:
		1:  # close-up: zelfde spel-hoek, strak op het model
			_cam.size = 8.5 if big else 1.5
			_cam.transform = Transform3D(CAM_BASIS, Vector3(0.0, 0.55, 0.0) + CAM_BASIS.z * 8.0)
		2:  # voorkant: recht van voren, licht van boven (linies vallen vrij)
			_cam.size = 9.0 if big else 1.7
			_cam.transform = Transform3D(Basis(), Vector3(0.0, 1.2, 3.6))
			_cam.look_at(Vector3(0.0, 0.45, 0.0), Vector3.UP)
		_:  # spel-camera (bordhoek)
			_cam.size = 12.5 if big else 2.9
			_cam.transform = Transform3D(CAM_BASIS, Vector3(0.0, 0.6, 0.0) + CAM_BASIS.z * 8.0)


# --- UI -------------------------------------------------------------------------

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -430.0
	panel.offset_left = 6.0
	panel.offset_right = -6.0
	panel.offset_bottom = -6.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.11, 0.15, 0.96)
	style.border_color = Color(0.38, 0.44, 0.60, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)
	ui.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	# --- Bovenbalk: model-selectie · camera · vergelijk-formatie -------------
	var row1 := HBoxContainer.new()
	box.add_child(row1)
	_fac_btn = OptionButton.new()
	for d in Constants.DOCTRINE_DATA.keys():
		_fac_btn.add_item(Constants.doctrine_name(d), int(d))
	_fac_btn.select(1)  # Muis heeft het eerste model
	row1.add_child(_fac_btn)
	_type_btn = OptionButton.new()
	for tp in [0, 1, 2]:
		_type_btn.add_item(Constants.unit_type_name(tp), tp)
	row1.add_child(_type_btn)
	_arch_btn = OptionButton.new()
	for a in ARCHS:
		_arch_btn.add_item(a)
	row1.add_child(_arch_btn)
	for b in [_fac_btn, _type_btn, _arch_btn]:
		(b as OptionButton).item_selected.connect(_on_model_select_changed)
	row1.add_child(_make_label("  Cam:"))
	_view_btn = OptionButton.new()
	for v in ["spel", "close-up", "voorkant"]:
		_view_btn.add_item(v)
	_view_btn.item_selected.connect(func(_i: int) -> void: _apply_camera())
	row1.add_child(_view_btn)
	var dark_btn := CheckButton.new()
	dark_btn.text = "donker"
	dark_btn.toggled.connect(_on_dark_toggled)
	row1.add_child(dark_btn)
	row1.add_child(_make_label("  Vergelijk:"))
	_my_fac_btn = OptionButton.new()
	_opp_fac_btn = OptionButton.new()
	for d in Constants.DOCTRINE_DATA.keys():
		_my_fac_btn.add_item(Constants.doctrine_name(d), int(d))
		_opp_fac_btn.add_item(Constants.doctrine_name(d), int(d))
	_my_fac_btn.select(1)   # Muis
	_opp_fac_btn.select(0)  # Varken
	row1.add_child(_my_fac_btn)
	row1.add_child(_make_label(" vs "))
	row1.add_child(_opp_fac_btn)
	_formation_btn = Button.new()
	_formation_btn.text = "formatie"
	_formation_btn.toggle_mode = true
	_formation_btn.toggled.connect(_on_formation_toggled)
	row1.add_child(_formation_btn)
	for fb in [_my_fac_btn, _opp_fac_btn]:
		(fb as OptionButton).item_selected.connect(func(_i: int) -> void:
			if _formation_btn.button_pressed:
				_build_formation())

	# --- Preview-strip: altijd zichtbaar, welke tab je ook open hebt ----------
	# Elke druk onderbreekt de vorige preview direct (zie _interrupt_previews).
	var rowp := HBoxContainer.new()
	box.add_child(rowp)
	rowp.add_child(_make_label("Clip: "))
	for clip in ["idle", "walk", "attack", "melee", "hit", "ready", "die"]:
		var pbtn := Button.new()
		pbtn.text = clip
		pbtn.pressed.connect(_on_clip.bind(clip))
		rowp.add_child(pbtn)
	var freeze_btn := Button.new()
	freeze_btn.text = "stilzetten"
	freeze_btn.pressed.connect(_freeze_pose)
	rowp.add_child(freeze_btn)
	var rowt := HBoxContainer.new()
	box.add_child(rowt)
	rowt.add_child(_make_label("Test: "))
	var fire_btn := Button.new()
	fire_btn.text = "vuur"
	fire_btn.pressed.connect(_on_fire_test)
	rowt.add_child(fire_btn)
	var impact_btn := Button.new()
	impact_btn.text = "inslag (kanon)"
	impact_btn.pressed.connect(_on_impact_test)
	rowt.add_child(impact_btn)
	var gib_btn := Button.new()
	gib_btn.text = "gibs (kanon)"
	gib_btn.pressed.connect(_on_gib_test.bind(1.4, "shot"))
	rowt.add_child(gib_btn)
	var gib_btn2 := Button.new()
	gib_btn2.text = "gibs (musket)"
	gib_btn2.pressed.connect(_on_gib_test.bind(0.75, "shot"))
	rowt.add_child(gib_btn2)
	var gib_btn3 := Button.new()
	gib_btn3.text = "gibs (melee)"
	gib_btn3.pressed.connect(_on_gib_test.bind(0.7, "melee"))
	rowt.add_child(gib_btn3)
	var smoke_btn := Button.new()
	smoke_btn.text = "rook (musket)"
	smoke_btn.pressed.connect(_on_smoke_test.bind(2, 0.09))
	rowt.add_child(smoke_btn)
	var smoke_btn2 := Button.new()
	smoke_btn2.text = "rook (kanon)"
	smoke_btn2.pressed.connect(_on_smoke_test.bind(4, 0.16))
	rowt.add_child(smoke_btn2)
	var duel_btn := Button.new()
	duel_btn.text = "duel (dood)"
	duel_btn.pressed.connect(_on_duel_test.bind(true))
	rowt.add_child(duel_btn)
	var duel_btn2 := Button.new()
	duel_btn2.text = "duel (overleeft)"
	duel_btn2.pressed.connect(_on_duel_test.bind(false))
	rowt.add_child(duel_btn2)

	# --- Tabs per categorie ---------------------------------------------------
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(0, 230)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(tabs)

	# Tab MODEL: maat/positie + musket.
	var tab_model := VBoxContainer.new()
	tab_model.name = "Model"
	tab_model.add_theme_constant_override("separation", 8)
	tabs.add_child(tab_model)
	var row2 := HBoxContainer.new()
	tab_model.add_child(row2)
	row2.add_child(_make_label("Schaal"))
	_scale_slider = HSlider.new()
	_scale_slider.min_value = 0.4
	_scale_slider.max_value = 2.5
	_scale_slider.step = 0.01
	_scale_slider.value = 1.0
	_scale_slider.custom_minimum_size = Vector2(280, 0)
	_scale_slider.value_changed.connect(_on_slider_paired.bind("scale"))
	row2.add_child(_scale_slider)
	_scale_spin = _make_spin(row2, 0.4, 2.5, 0.01, 1.0, _on_spin_paired.bind("scale"))
	row2.add_child(_make_label("  Hoogte"))
	_y_slider = HSlider.new()
	_y_slider.min_value = -0.4
	_y_slider.max_value = 0.4
	_y_slider.step = 0.005
	_y_slider.value = 0.0
	_y_slider.custom_minimum_size = Vector2(200, 0)
	_y_slider.value_changed.connect(_on_slider_paired.bind("y"))
	row2.add_child(_y_slider)
	_y_spin = _make_spin(row2, -0.4, 0.4, 0.005, 0.0, _on_spin_paired.bind("y"))
	row2.add_child(_make_label("  X"))
	_x_spin = _make_spin(row2, -0.5, 0.5, 0.01, 0.0, _on_tuning_changed)
	row2.add_child(_make_label(" Z"))
	_z_spin = _make_spin(row2, -0.5, 0.5, 0.01, 0.0, _on_tuning_changed)
	# --- Tab IN DE HAND: musket en figuranten-props (Max, 28 juli) ----------
	var tab_hand := VBoxContainer.new()
	tab_hand.name = "In de hand"
	tab_hand.add_theme_constant_override("separation", 8)
	tabs.add_child(tab_hand)
	var rowk := HBoxContainer.new()
	tab_hand.add_child(rowk)
	rowk.add_child(_make_label("Voorwerp"))
	_hand_btn = OptionButton.new()
	for o in HAND_OPTIES:
		_hand_btn.add_item(String(o["label"]))
	_hand_btn.tooltip_text = "Musket of een figuranten-prop. Alleen infanterie draagt iets in de hand."
	_hand_btn.item_selected.connect(func(_i: int) -> void:
		# Alleen infanterie draagt iets: kies je een prop, dan schakelt het
		# type automatisch mee (anders zie je niets gebeuren).
		if _hand_rol() != "" and _type_btn.get_selected_id() != Constants.UnitType.INFANTRY:
			for i in _type_btn.item_count:
				if _type_btn.get_item_id(i) == Constants.UnitType.INFANTRY:
					_type_btn.select(i)
					break
		_reload_pawns())
	rowk.add_child(_hand_btn)
	rowk.add_child(_make_label("   Sleep-assen"))
	_sleep_btn = OptionButton.new()
	for lbl in ["uit", "voorwerp", "vuurmond"]:
		_sleep_btn.add_item(lbl)
	_sleep_btn.select(1)
	_sleep_btn.tooltip_text = "Pak een gekleurde arm om te verschuiven of een ring om te draaien (X rood, Y groen, Z blauw)."
	rowk.add_child(_sleep_btn)

	var roww := HBoxContainer.new()
	tab_hand.add_child(roww)
	_hand_label = _make_label("In de hand (musket): schaal")
	roww.add_child(_hand_label)
	_weapon_spins["scale"] = _make_spin(roww, 0.1, 3.0, 0.05, 1.0, _on_weapon_changed)
	var roww2 := HBoxContainer.new()
	tab_hand.add_child(roww2)
	roww2.add_child(_make_label("positie  X"))
	_weapon_spins["px"] = _make_spin(roww2, -0.6, 0.6, 0.01, 0.0, _on_weapon_changed)
	roww2.add_child(_make_label(" Y"))
	_weapon_spins["py"] = _make_spin(roww2, -0.6, 0.6, 0.01, 0.0, _on_weapon_changed)
	roww2.add_child(_make_label(" Z"))
	_weapon_spins["pz"] = _make_spin(roww2, -0.6, 0.6, 0.01, 0.0, _on_weapon_changed)
	roww2.add_child(_make_label("    draai°  X"))
	_weapon_spins["rx"] = _make_spin(roww2, -180.0, 180.0, 5.0, 0.0, _on_weapon_changed)
	roww2.add_child(_make_label(" Y"))
	_weapon_spins["ry"] = _make_spin(roww2, -180.0, 180.0, 5.0, 0.0, _on_weapon_changed)
	roww2.add_child(_make_label(" Z"))
	_weapon_spins["rz"] = _make_spin(roww2, -180.0, 180.0, 5.0, 0.0, _on_weapon_changed)
	_gizmo_hint = _make_label("Sleep een arm om te verschuiven, een ring om te draaien. Loslaten = opslaan.")
	_gizmo_hint.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	tab_hand.add_child(_gizmo_hint)

	# Vuurmond: waar flits + rook ontstaan, in model-ruimte (rechts/hoogte/
	# voor). Per model opgeslagen; "test vuur" toont het direct.
	var rowm := HBoxContainer.new()
	tab_hand.add_child(rowm)
	rowm.add_child(_make_label("Vuurmond: rechts"))
	_muzzle_spins["x"] = _make_spin(rowm, -1.0, 1.0, 0.01, 0.08, _on_muzzle_changed)
	rowm.add_child(_make_label(" hoogte"))
	_muzzle_spins["y"] = _make_spin(rowm, 0.0, 2.0, 0.01, 0.85, _on_muzzle_changed)
	rowm.add_child(_make_label(" voor"))
	_muzzle_spins["z"] = _make_spin(rowm, -1.0, 1.5, 0.01, 0.45, _on_muzzle_changed)
	var muzzle_test := Button.new()
	muzzle_test.text = "test vuur"
	muzzle_test.pressed.connect(_on_fire_test)
	rowm.add_child(muzzle_test)

	# Tabs GORE / BLOED / ROOK: effect-knoppen per categorie in een net raster.
	var cats: Array = [["Melee", "bajonet"], ["Gore", "gore"], ["Bloed", "bloed"], ["Rook", "rook"]]
	for cat in cats:
		var tab := VBoxContainer.new()
		tab.name = String(cat[0])
		tab.add_theme_constant_override("separation", 8)
		tabs.add_child(tab)
		var grid := GridContainer.new()
		grid.columns = 8
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 6)
		tab.add_child(grid)
		for d in FX_DEFS:
			if String(d.get("cat", "")) != String(cat[1]):
				continue
			grid.add_child(_make_label(String(d.label)))
			var spin := _make_spin(grid, float(d.min), float(d.max), float(d.step),
				PawnView.fx(String(d.key), float(d.def)), _on_fx_changed)
			_fx_spins[String(d.key)] = spin
		if String(cat[1]) == "bajonet":
			tab.add_child(_make_label("Melee-timing geldt voor ALLE modellen (zelfde clips). Preview: duel-knoppen in de Test-rij bovenin."))
		if String(cat[1]) == "bloed":
			# Dood-poel: per dood-clip de lijkpoel timen.
			var rowd := HBoxContainer.new()
			tab.add_child(rowd)
			rowd.add_child(_make_label("Dood-poel: "))
			_die_btn = OptionButton.new()
			_die_btn.item_selected.connect(func(_i: int) -> void: _load_death_pool_values())
			rowd.add_child(_die_btn)
			rowd.add_child(_make_label(" wacht"))
			_dp_spins["delay"] = _make_spin(rowd, 0.0, 10.0, 0.01, 0.9, _on_death_pool_changed)
			rowd.add_child(_make_label(" groei"))
			_dp_spins["grow"] = _make_spin(rowd, 0.05, 10.0, 0.01, 0.7, _on_death_pool_changed)
			rowd.add_child(_make_label(" maat"))
			_dp_spins["size"] = _make_spin(rowd, 0.1, 10.0, 0.01, 2.4, _on_death_pool_changed)
			rowd.add_child(_make_label(" torso-afstand"))
			_dp_spins["torso"] = _make_spin(rowd, -2.0, 2.0, 0.01, 0.3, _on_death_pool_changed)
			var dp_test := Button.new()
			dp_test.text = "test dood-poel"
			dp_test.pressed.connect(_on_death_pool_test)
			rowd.add_child(dp_test)

	# --- Vaste onderbalk: opslaan ---------------------------------------------
	var row3 := HBoxContainer.new()
	box.add_child(row3)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row3.add_child(spacer)
	var save_btn := Button.new()
	save_btn.text = "  OPSLAAN  "
	save_btn.pressed.connect(_save)
	row3.add_child(save_btn)
	var back_btn := Button.new()
	back_btn.text = "Terug naar het spel"
	back_btn.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/game/game.tscn"))
	row3.add_child(back_btn)

	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_info)

func _make_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


func _make_spin(parent: Node, minv: float, maxv: float, step: float, def: float, cb: Callable) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = minv
	s.max_value = maxv
	s.step = step
	s.value = def
	s.value_changed.connect(cb)
	parent.add_child(s)
	return s


## Dropdown gewisseld: normaal het model herladen; in formatie-modus blijft
## de opstelling staan en schakelen alleen de sliders naar het gekozen model.
func _on_model_select_changed(_i: int) -> void:
	if _formation_pawns.is_empty():
		_reload_pawns()
	else:
		_sync_sliders_from_tuning()


## De tuning-sleutel van het model dat de sliders nu sturen: het losse
## tuning-model, of in formatie-modus de pion die matcht met de dropdowns
## (factie + type). Leeg als die combinatie niet in de formatie staat.
func _tune_target_key() -> String:
	if _pawn != null and is_instance_valid(_pawn):
		return _pawn._tune_key
	return _formation_target_key()


## Model in de formatie dat bij de dropdowns hoort (factie+type+archetype),
## met terugval op alleen factie+type.
func _formation_target_key() -> String:
	var fac := _fac_btn.get_selected_id()
	var tp := _type_btn.get_selected_id()
	var arch: String = ARCHS[_arch_btn.selected]
	for e in _formation_pawns:
		if int(e.fac) == fac and int(e.tp) == tp and String(e.get("arch", "base")) == arch and is_instance_valid(e.pv):
			return (e.pv as PawnView)._tune_key
	for e in _formation_pawns:
		if int(e.fac) == fac and int(e.tp) == tp and is_instance_valid(e.pv):
			return (e.pv as PawnView)._tune_key
	return ""


## Actieve musket-tuning-sleutel van het doelmodel (per-model of factie).
func _weapon_target_key() -> String:
	if _pawn != null and is_instance_valid(_pawn) and _pawn._weapon_tune_key != "":
		return _pawn._weapon_tune_key
	var fac := _fac_btn.get_selected_id()
	var tp := _type_btn.get_selected_id()
	var arch: String = ARCHS[_arch_btn.selected]
	for e in _formation_pawns:
		if int(e.fac) == fac and int(e.tp) == tp and String(e.get("arch", "base")) == arch and is_instance_valid(e.pv):
			return (e.pv as PawnView)._weapon_tune_key
	for e in _formation_pawns:
		if int(e.fac) == fac and int(e.tp) == tp and is_instance_valid(e.pv):
			return (e.pv as PawnView)._weapon_tune_key
	return "%s/musket" % _fac_name()


## Sliders/spinboxen vullen met de opgeslagen tuning van het doelmodel.
func _sync_sliders_from_tuning() -> void:
	var key := _tune_target_key()
	_updating = true
	var t: Dictionary = PawnView.model_tuning().get(key, {})
	_scale_slider.value = float(t.get("scale", 1.0))
	_scale_spin.value = float(t.get("scale", 1.0))
	_y_slider.value = float(t.get("y", 0.0))
	_y_spin.value = float(t.get("y", 0.0))
	_x_spin.value = float(t.get("x", 0.0))
	_z_spin.value = float(t.get("z", 0.0))
	var mz_def: Array = [0.0, 0.55, 0.7] if _type_btn.get_selected_id() == 2 else [0.08, 0.85, 0.45]
	var mz: Array = t.get("muzzle", mz_def)
	if mz.size() != 3:
		mz = mz_def
	_muzzle_spins["x"].value = float(mz[0])
	_muzzle_spins["y"].value = float(mz[1])
	_muzzle_spins["z"].value = float(mz[2])
	var w: Dictionary = PawnView.model_tuning().get(_weapon_target_key(), {})
	_weapon_spins["scale"].value = float(w.get("scale", 1.0))
	var wpos: Array = w.get("pos", [0.0, 0.0, 0.0])
	var wrot: Array = w.get("rot", [0.0, 0.0, 0.0])
	for i in 3:
		_weapon_spins[["px", "py", "pz"][i]].value = float(wpos[i])
		_weapon_spins[["rx", "ry", "rz"][i]].value = float(wrot[i])
	# Onmiskenbaar maken WAT je nu bijstelt en WAAR het heen wordt geschreven.
	if _hand_label != null:
		var wat: String = "musket"
		if _hand_btn != null and _hand_btn.selected >= 0:
			wat = String(HAND_OPTIES[_hand_btn.selected]["label"])
		_hand_label.text = "In de hand (%s → %s): schaal" % [wat, _weapon_target_key()]
	_updating = false
	if not _formation_pawns.is_empty() and key == "":
		_info.text = "Model %s/%s staat niet in de formatie — kies een van de vergeleken facties linksboven om te tunen." % [
			_fac_name(), Constants.unit_type_name(_type_btn.get_selected_id())]


## Pas tuning toe op wat er staat: formatie herbouwen of het losse model.
func _retune_target() -> void:
	if not _formation_pawns.is_empty():
		_build_formation()
	else:
		_respawn_model()


## Huidige factie-naam in kleine letters ("muis") — sleutels in model_tuning.json.
func _fac_name() -> String:
	return Constants.doctrine_folder(_fac_btn.get_selected_id())


func _on_weapon_changed(_v: float) -> void:
	if _updating:
		return
	if _pawn == null and _formation_pawns.is_empty():
		return
	PawnView.set_model_tuning(_weapon_target_key(), {
		"scale": snappedf(_weapon_spins["scale"].value, 0.01),
		"pos": [snappedf(_weapon_spins["px"].value, 0.01),
			snappedf(_weapon_spins["py"].value, 0.01),
			snappedf(_weapon_spins["pz"].value, 0.01)],
		"rot": [snappedf(_weapon_spins["rx"].value, 1.0),
			snappedf(_weapon_spins["ry"].value, 1.0),
			snappedf(_weapon_spins["rz"].value, 1.0)],
	})
	_retune_target()


# --- Model laden / bijstellen ---------------------------------------------------

## Gekozen rol uit de Hand-dropdown ("" = musket).
func _hand_rol() -> String:
	if _hand_btn == null or _hand_btn.selected < 0:
		return ""
	return String(HAND_OPTIES[_hand_btn.selected]["rol"])


func _current_card() -> Card:
	var arch: String = ARCHS[_arch_btn.selected]
	if not ARCH_CARDS.has(arch):
		return null
	var s: Array = ARCH_CARDS[arch]
	return Card.new(0, 0, 0, int(s[0]), int(s[1]), int(s[2]))


## Formatie aan: vervang het tuning-model door 3 vs 3 (inf/cav/art) van de
## twee gekozen facties, tegenover elkaar op tegels — net als in het spel.
func _on_formation_toggled(on: bool) -> void:
	if on:
		_build_formation()
	else:
		_clear_formation()
		_reload_pawns()
	_apply_camera()


func _clear_formation() -> void:
	for e in _formation_pawns:
		if is_instance_valid(e.pv):
			e.pv.queue_free()
	_formation_pawns = []


func _build_formation() -> void:
	_clear_formation()
	if _pawn != null and is_instance_valid(_pawn):
		_pawn.queue_free()
	_pawn = null
	if _ref != null and is_instance_valid(_ref):
		_ref.queue_free()
	_ref = null
	var facs: Array = [_my_fac_btn.get_selected_id(), _opp_fac_btn.get_selected_id()]
	# Kolommen = archetypes (base/spd/hp/atk/mix), rijen = eenheidstype
	# (infanterie vooraan, dan cavalerie, dan artillerie). Jouw factie
	# tegenover de tegenstander, zelfde type recht tegenover elkaar.
	var col_x := 1.4   # afstand tussen archetype-kolommen
	var row_z := [1.3, 2.9, 4.5]  # diepte per type (infanterie het dichtst bij het midden)
	for side in 2:
		var sgn := 1.0 if side == 0 else -1.0
		for tp in 3:  # 0=infanterie, 1=cavalerie, 2=artillerie
			for ci in ARCHS.size():
				var arch: String = ARCHS[ci]
				var card = null
				if ARCH_CARDS.has(arch):
					var st: Array = ARCH_CARDS[arch]
					card = Card.new(0, 0, 0, int(st[0]), int(st[1]), int(st[2]))
				var pv: PawnView = PAWN_SCENE.instantiate()
				pv.team = Constants.Team.RED if side == 0 else Constants.Team.BLUE
				pv.position = Vector3((float(ci) - 2.0) * col_x, 0.05, sgn * row_z[tp])
				add_child(pv)
				pv.face_dir(Vector2i(0, -1) if side == 0 else Vector2i(0, 1))
				pv.set_unit_type(tp)
				pv.set_character(facs[side], tp, card)
				_formation_pawns.append({"pv": pv, "fac": int(facs[side]), "tp": tp, "arch": arch})
	_info.text = "Formatie: %s (rood) vs %s (blauw). Kolommen = base/spd/hp/atk/mix, rijen = infanterie/cavalerie/artillerie (voor naar achter). Sliders tunen het model uit de dropdowns (factie + type + archetype)." % [
		Constants.doctrine_name(facs[0]), Constants.doctrine_name(facs[1])]
	_sync_sliders_from_tuning()
	_apply_camera()


func _reload_pawns() -> void:
	if _formation_btn != null and _formation_btn.button_pressed:
		_formation_btn.set_pressed_no_signal(false)
	_clear_formation()
	if _pawn != null:
		_pawn.queue_free()
	if _ref != null:
		_ref.queue_free()
	var doctrine: int = _fac_btn.get_selected_id()
	var unit_type: int = _type_btn.get_selected_id()
	# Referentie: het geometrische stuk op de linker tegel (maatvergelijking).
	_ref = PAWN_SCENE.instantiate()
	_ref.team = Constants.Team.RED
	_ref.position = Vector3(-1.0, 0.05, 0.0)
	add_child(_ref)
	_ref.face_dir(Vector2i(0, 1))
	_ref.set_unit_type(unit_type)
	# Het echte model in het midden, via exact dezelfde route als in het spel.
	_pawn = PAWN_SCENE.instantiate()
	_pawn.team = Constants.Team.BLUE
	_pawn.position = Vector3(0.0, 0.05, 0.0)
	add_child(_pawn)
	_pawn.face_dir(Vector2i(0, 1))  # neus naar de camera
	_pawn.set_unit_type(unit_type)
	_pawn.rol_override = _hand_rol()
	_pawn.set_character(doctrine, unit_type, _current_card())
	_freeze_pose()
	# Sliders op de opgeslagen waarden zetten (zonder events af te vuren).
	_sync_sliders_from_tuning()
	_fill_die_options()
	_refresh_info()
	_apply_camera()


## Vul het dood-clip menu met de die-varianten van het huidige model en
## laad de bijbehorende death_pools-waarden.
func _fill_die_options() -> void:
	_die_btn.clear()
	if _pawn != null and _pawn._anim != null:
		for v in _pawn._variants_of(_pawn.anim_die):
			var n := String(v)
			_die_btn.add_item(n.get_slice("/", n.get_slice_count("/") - 1))
	_load_death_pool_values()


func _load_death_pool_values() -> void:
	if _die_btn.item_count == 0:
		return
	var clip := _die_btn.get_item_text(_die_btn.selected)
	var cfg: Dictionary = PawnView.fx_dict("death_pools").get(clip, {})
	_updating = true
	_dp_spins["delay"].value = float(cfg.get("delay", 0.9))
	_dp_spins["grow"].value = float(cfg.get("grow", 0.7))
	_dp_spins["size"].value = float(cfg.get("size", 2.4))
	_dp_spins["torso"].value = float(cfg.get("torso", cfg.get("forward", 0.3)))
	_updating = false


func _on_death_pool_changed(_v: float) -> void:
	if _updating or _die_btn.item_count == 0:
		return
	var clip := _die_btn.get_item_text(_die_btn.selected)
	var pools: Dictionary = PawnView.fx_all().get("death_pools", {})
	pools[clip] = {
		"delay": snappedf(_dp_spins["delay"].value, 0.01),
		"grow": snappedf(_dp_spins["grow"].value, 0.01),
		"size": snappedf(_dp_spins["size"].value, 0.01),
		"torso": snappedf(_dp_spins["torso"].value, 0.01),
	}
	PawnView.fx_all()["death_pools"] = pools


## Speel precies de GEKOZEN dood-clip met de ingestelde poel-timing.
func _on_death_pool_test() -> void:
	_interrupt_previews(true, true)
	if _pawn == null or not is_instance_valid(_pawn) or _die_btn.item_count == 0:
		return
	var clip := _die_btn.get_item_text(_die_btn.selected)
	_pawn.play_death(Vector3(0.2, 0.0, 1.0).normalized(), 0.75, "shot", clip)
	_pawn = null
	var gen := _preview_gen
	var t := create_tween()
	t.tween_interval(4.0)
	t.tween_callback(func() -> void:
		if gen == _preview_gen:
			_respawn_model(false))


## Slider bewogen → spin bijwerken, dan toepassen.
func _on_slider_paired(v: float, key: String) -> void:
	if _updating:
		return
	_updating = true
	if key == "scale":
		_scale_spin.value = v
	else:
		_y_spin.value = v
	_updating = false
	_on_tuning_changed(v)


## Spin gewijzigd → slider bijwerken, dan toepassen.
func _on_spin_paired(v: float, key: String) -> void:
	if _updating:
		return
	_updating = true
	if key == "scale":
		_scale_slider.value = v
	else:
		_y_slider.value = v
	_updating = false
	_on_tuning_changed(v)


func _on_tuning_changed(_v: float) -> void:
	if _updating:
		return
	if _pawn == null and _formation_pawns.is_empty():
		return
	var key := _tune_target_key()
	if key == "":
		_refresh_info()
		return
	var entry: Dictionary = PawnView.model_tuning().get(key, {})
	entry["scale"] = snappedf(_scale_slider.value, 0.01)
	entry["y"] = snappedf(_y_slider.value, 0.005)
	entry["x"] = snappedf(_x_spin.value, 0.01)
	entry["z"] = snappedf(_z_spin.value, 0.01)
	PawnView.set_model_tuning(key, entry)
	_retune_target()


## Herlaad het model zodat auto-fit + tuning exact zo draaien als in het spel.
var _preview_gen: int = 0


## Elke preview-druk onderbreekt de vorige DIRECT: lopende duel-/gib-timers
## worden ongeldig via de generatie-teller, oude test-resten geruimd en als
## het model dood/weg is komt er meteen een vers exemplaar - nooit wachten.
func _interrupt_previews(clear_debris: bool, need_pawn: bool) -> void:
	_preview_gen += 1
	_clear_duel()
	if clear_debris:
		for n in get_tree().get_nodes_in_group("battlefield_debris"):
			n.queue_free()
	if need_pawn and (_pawn == null or not is_instance_valid(_pawn)):
		_respawn_model(false)


func _respawn_model(clear_debris: bool = true) -> void:
	var doctrine: int = _fac_btn.get_selected_id()
	var unit_type: int = _type_btn.get_selected_id()
	if clear_debris:
		for n in get_tree().get_nodes_in_group("battlefield_debris"):
			n.queue_free()
	if _pawn != null and is_instance_valid(_pawn):
		_pawn.queue_free()
	_pawn = PAWN_SCENE.instantiate()
	_pawn.team = Constants.Team.BLUE
	_pawn.position = Vector3(0.0, 0.05, 0.0)
	add_child(_pawn)
	_pawn.face_dir(Vector2i(0, 1))  # neus naar de camera
	_pawn.set_unit_type(unit_type)
	# BUGFIX (Max, 28 juli): bij elke slider-wijziging bouwt de tuner het model
	# opnieuw op; zonder deze regel viel de gekozen prop terug op het musket.
	_pawn.rol_override = _hand_rol()
	_pawn.set_character(doctrine, unit_type, _current_card())
	_freeze_pose()
	_refresh_info()


## Vaste pose om tegen uit te lijnen: altijd de éérste idle-variant, bevroren
## op een vast frame. Zonder dit kiest elke herlaad een willekeurige variant op
## een willekeurig startpunt (het bord-desync-systeem) en verspringt de houding
## bij elke tuning-wijziging.
func _freeze_pose() -> void:
	if _pawn == null or _pawn._anim == null:
		return
	var variants: Array = _pawn._variants_of(_pawn.anim_idle)
	if variants.is_empty():
		return
	_pawn._anim.play(String(variants[0]))
	_pawn._anim.seek(0.4, true)
	_pawn._anim.pause()


## Test de dood-met-dismemberment op kanon- (1.4) of musket-kracht (0.75);
## daarna komt het model vanzelf terug.
## De draaiknopjes zetten de waarden direct in het actieve effect-dict; de
## eerstvolgende gib-test gebruikt ze meteen. OPSLAAN schrijft ze naar schijf.
func _on_fx_changed(_v: float) -> void:
	if _updating:
		return
	for key in _fx_spins:
		PawnView.set_fx(String(key), snappedf((_fx_spins[key] as SpinBox).value, 0.001))


## Vuur-test: attack-clip + loop-rook op het vuur-moment (maat past bij het
## geselecteerde type: artillerie = kanon-rook).
func _on_fire_test() -> void:
	_interrupt_previews(false, true)
	if _pawn == null or not is_instance_valid(_pawn):
		return
	if _pawn._anim != null:
		_pawn._anim.stop()
	_pawn.play_attack()
	var gen := _preview_gen
	var tw := create_tween()
	tw.tween_interval(0.25)
	tw.tween_callback(func() -> void:
		if gen == _preview_gen:
			_fire_smoke())


## Donker-stand: nachtelijke scene om de vuurflits op intensiteit te beoordelen.
func _on_dark_toggled(on: bool) -> void:
	_tuner_light.light_energy = 0.22 if on else 1.2
	_tuner_env.environment.background_color = Color(0.05, 0.055, 0.07) if on else Color(0.25, 0.26, 0.28)
	_tuner_env.environment.ambient_light_energy = 0.12 if on else 0.7


## Korte camera-schok in de tuner (zelfde gevoel als de shake in het spel).
func _shake_camera(strength: float) -> void:
	if _cam == null or strength <= 0.0:
		return
	var base := _cam.transform
	var tw := create_tween()
	for i in 5:
		var off := Vector3(randf() - 0.5, randf() - 0.5, 0.0) * 0.055 * strength
		tw.tween_property(_cam, "transform",
			Transform3D(base.basis, base.origin + base.basis * off), 0.03)
	tw.tween_property(_cam, "transform", base, 0.05)


func _fire_smoke() -> void:
	var is_art := _type_btn.get_selected_id() == 2
	var muzzle := Vector3(0.0, 0.5, 0.75) if is_art else Vector3(0.08, 0.6, 0.55)
	if _pawn != null and is_instance_valid(_pawn):
		muzzle = _pawn.muzzle_world()  # per model ingemeten (Vuurmond-rij)
	PawnView.spawn_muzzle_fire(self, muzzle, is_art)
	_shake_camera((0.55 if is_art else 0.3) * PawnView.fx("fire_shake", 1.0))
	# Zelfde lichtpuls als in het spel (vuur-licht knop).
	var fl := OmniLight3D.new()
	fl.light_color = Color(1.0, 0.78, 0.35)
	fl.light_energy = (2.6 if is_art else 1.6) * PawnView.fx("fire_light", 1.6)
	fl.omni_range = 2.8
	add_child(fl)
	fl.position = muzzle
	var ltw := create_tween()
	ltw.tween_property(fl, "light_energy", 0.0, 0.18)
	ltw.tween_callback(fl.queue_free)
	PawnView.spawn_powder_smoke(self, muzzle, 4 if is_art else 2,
		0.16 if is_art else 0.09, Vector3(0.12, 0.0, 1.0).normalized())


## Kanon-inslag: een kogel-streep vliegt in, inslag-rook + volledige gib-dood
## - exact de keten die het spel bij een artillerie-treffer afspeelt.
func _on_impact_test() -> void:
	_interrupt_previews(true, true)
	if _pawn == null or not is_instance_valid(_pawn):
		return
	var gen := _preview_gen
	var from := Vector3(-2.4, 0.5, -1.3)
	var to := Vector3(0.0, 0.45, 0.0)
	var proj := MeshInstance3D.new()
	var pm := SphereMesh.new()
	pm.radius = 0.07
	pm.height = 0.14
	proj.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.16, 0.18)
	mat.metallic = 0.5
	proj.material_override = mat
	add_child(proj)
	proj.look_at_from_position(from, to, Vector3.UP)
	proj.scale = Vector3(0.6, 0.6, 4.0)
	var tw := create_tween()
	tw.tween_property(proj, "position", to, 0.16)
	tw.tween_callback(proj.queue_free)
	tw.tween_callback(func() -> void:
		if gen == _preview_gen:
			_impact_hit((to - from).normalized()))


func _impact_hit(dir: Vector3) -> void:
	_shake_camera(1.2 * PawnView.fx("fire_shake", 1.0))
	PawnView.spawn_powder_smoke(self, Vector3(0.0, 0.4, 0.0), 3, 0.14, dir)
	if _pawn == null or not is_instance_valid(_pawn):
		return
	_pawn.play_death(dir, 1.4, "shot")
	_pawn = null
	var gen := _preview_gen
	var t := create_tween()
	t.tween_interval(4.0)
	t.tween_callback(func() -> void:
		if gen == _preview_gen:
			_respawn_model(false))


## Vuurmond gewijzigd: opslaan in de model-tuning (merge, behoudt de rest).
func _on_muzzle_changed(_v: float) -> void:
	if _updating:
		return
	var key := _tune_target_key()
	if key == "":
		return
	var entry: Dictionary = PawnView.model_tuning().get(key, {})
	entry["muzzle"] = [snappedf(_muzzle_spins["x"].value, 0.01),
		snappedf(_muzzle_spins["y"].value, 0.01),
		snappedf(_muzzle_spins["z"].value, 0.01)]
	PawnView.set_model_tuning(key, entry)


## Rooktest aan de loop van het tuning-model (musket- of kanon-maat).
func _on_smoke_test(count: int, size: float) -> void:
	_interrupt_previews(false, false)
	PawnView.spawn_powder_smoke(self, Vector3(0.05, 0.55, 0.3), count, size,
		Vector3(0.3, 0.0, 1.0).normalized())


func _on_gib_test(strength: float, kind: String = "shot") -> void:
	# Vorige preview direct afbreken; oude resten weg, het NIEUWE lijk blijft.
	_interrupt_previews(true, true)
	if _pawn == null or not is_instance_valid(_pawn):
		return
	_pawn.play_death(Vector3(0.2, 0.0, 1.0).normalized(), strength, kind)
	_pawn = null
	# Levend model komt terug, tenzij er intussen een nieuwe preview draait.
	var gen := _preview_gen
	var t := create_tween()
	t.tween_interval(4.0)
	t.tween_callback(func() -> void:
		if gen == _preview_gen:
			_respawn_model(false))


func _on_clip(clip: String) -> void:
	_interrupt_previews(false, true)
	if _pawn == null:
		return
	if _pawn._anim != null:
		_pawn._anim.stop()  # zelfde clip nogmaals = direct opnieuw starten
	match clip:
		"idle": _pawn.play_idle()
		"walk": _pawn.play_walk()
		"attack": _pawn.play_attack()
		"melee":
			# Blader door de melee-varianten: elke druk de volgende clip.
			var variants: Array = _pawn._variants_of(_pawn.anim_melee)
			if variants.is_empty():
				_pawn.play_melee()
			else:
				var full := String(variants[_melee_cycle % variants.size()])
				_melee_cycle += 1
				_pawn._anim.play(full, 0.2)
				_info.text = "melee-clip: %s (%d van %d) — druk nogmaals voor de volgende variant" % [
					full, ((_melee_cycle - 1) % variants.size()) + 1, variants.size()]
		"hit": _pawn.play_hit()
		"ready": _pawn.play_ready()
		"die": _pawn.play_die()


func _refresh_info() -> void:
	if _pawn == null:
		return
	if _pawn._tune_key == "":
		_info.text = "Geen .glb gevonden voor deze combinatie — placeholder-stuk. Drop eerst een model (zie MODEL-WISHLIST.md)."
	else:
		var fit := ""
		if not _pawn.last_fit.is_empty():
			var lf: Dictionary = _pawn.last_fit
			fit = "  ·  meting: %s h=%.2f voet=%.2f grond=%+.3f midden=(%+.2f, %+.2f) s=%.3f" % [
				"botten" if lf.get("bones", false) else "AABB", float(lf.get("h", 0.0)),
				float(lf.get("fp", 0.0)), float(lf.get("ground", 0.0)),
				float(lf.get("cx", 0.0)), float(lf.get("cz", 0.0)), float(lf.get("s", 0.0))]
		_info.text = "%s  ·  schaal %.2f  ·  hoogte %+.3f  ·  x %+.2f  ·  z %+.2f%s" % [
			_pawn._tune_key, _scale_slider.value, _y_slider.value, _x_spin.value, _z_spin.value, fit]


## Per-model melee-knop gewijzigd: schrijf naar model_tuning["<key>"]["melee"]
## (in het geheugen; OPSLAAN zet het op schijf). Werkt direct in duel/spel.
func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		_info.text = "OPSLAAN MISLUKT: kan %s niet schrijven" % SAVE_PATH
		return
	f.store_string(JSON.stringify(PawnView.model_tuning(), "\t") + "\n")
	var f2 := FileAccess.open(PawnView.EFFECTS_PATH, FileAccess.WRITE)
	if f2 != null:
		f2.store_string(JSON.stringify(PawnView.fx_all(), "\t") + "\n")
	_info.text = "Opgeslagen → model_tuning.json + effects_tuning.json (geldt direct in het spel)"


# --- Duel-test: bajonet-choreografie live afstemmen ---------------------------

var _duel_root: Node3D = null


## Verdediger (vergelijk-factie) verschijnt recht tegenover het model. De
## aanvaller draait (aanvaller-draai), stoot (stoot-tempo), de verdediger
## reageert op het raakmoment (val bij dood, terugdeins bij overleven) en bij
## een kill rukt de aanvaller na de opruk-vertraging op - exact dezelfde
## timing-route als in het spel.
func _on_duel_test(kill: bool) -> void:
	_interrupt_previews(true, true)
	if _pawn == null or not is_instance_valid(_pawn):
		return
	if _pawn._anim != null:
		_pawn._anim.stop()
	_pawn.position = Vector3(0.0, 0.05, 0.0)
	_duel_root = Node3D.new()
	add_child(_duel_root)
	var def_pv: PawnView = PAWN_SCENE.instantiate()
	def_pv.team = Constants.Team.RED
	def_pv.position = Vector3(0.0, 0.05, 1.0)
	_duel_root.add_child(def_pv)
	def_pv.set_unit_type(_type_btn.get_selected_id())
	def_pv.set_character(_opp_fac_btn.get_selected_id(), _type_btn.get_selected_id(), null)
	def_pv.face_dir(Vector2i(0, -1))
	# Aanvaller: exact dezelfde route als in het spel.
	_pawn.face_dir(Vector2i(0, 1))
	_pawn.rotate_y(deg_to_rad(_pawn.melee_fx("yaw", "melee_yaw", 0.0)))
	_pawn.play_melee()
	var gen := _preview_gen
	var hd: float = _pawn.melee_fx("hit_delay", "melee_hit_delay", 0.55)
	get_tree().create_timer(hd).timeout.connect(func() -> void:
		if gen != _preview_gen or def_pv == null or not is_instance_valid(def_pv):
			return
		if kill:
			def_pv.play_death(Vector3(0.0, 0.0, 1.0), 0.7, "melee")
		else:
			def_pv.play_hit()
			def_pv.play_wound(Vector3(0.0, 0.0, 1.0)))
	if kill:
		var move_del: float = maxf(hd + 0.12, _pawn.last_clip_duration())
		var dsp2: float = def_pv.melee_fx("death_speed", "death_speed", 1.0)
		var death_dur2: float = def_pv.clip_duration("die") / maxf(dsp2, 0.01)
		move_del = maxf(move_del, hd + death_dur2 * _pawn.melee_fx("move_wait", "melee_move_wait", 1.0))
		move_del += _pawn.melee_fx("advance_delay", "melee_advance_delay", 0.35)
		get_tree().create_timer(move_del).timeout.connect(func() -> void:
			if gen != _preview_gen or _pawn == null or not is_instance_valid(_pawn):
				return
			_pawn.play_walk()
			var tw := create_tween()
			tw.tween_property(_pawn, "position", Vector3(0.0, 0.05, 1.0), 0.3)
			tw.tween_callback(func() -> void:
				if _pawn != null and is_instance_valid(_pawn):
					_pawn.play_idle()))


func _clear_duel() -> void:
	if _duel_root != null and is_instance_valid(_duel_root):
		_duel_root.queue_free()
	_duel_root = null


# =========================================================================
# Sleep-gizmo: drie assen pakken met de muis (Max, 28 juli)
# =========================================================================

## Bouw de drie as-armen. Ze tekenen altijd bovenop het model (no_depth_test)
## zodat je ze ook ziet als ze in een arm of in het lijf verdwijnen.
func _bouw_sleep_gizmo() -> void:
	_sleep_gizmo = Node3D.new()
	add_child(_sleep_gizmo)
	var kleuren := GIZMO_KLEUREN
	for i in 3:
		var arm := MeshInstance3D.new()
		var cil := CylinderMesh.new()
		cil.top_radius = 0.012
		cil.bottom_radius = 0.012
		cil.height = 1.0
		arm.mesh = cil
		var mat := StandardMaterial3D.new()
		mat.albedo_color = kleuren[i]
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		mat.render_priority = 20
		arm.material_override = mat
		_sleep_gizmo.add_child(arm)
		_sleep_armen.append(arm)
		# Draai-ring om dezelfde as (iets doorzichtiger, zodat de arm leidend blijft).
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.99
		torus.outer_radius = 1.0
		torus.rings = 48
		torus.ring_segments = 6
		ring.mesh = torus
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color(kleuren[i].r, kleuren[i].g, kleuren[i].b, 0.85)
		rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rmat.no_depth_test = true
		rmat.render_priority = 19
		ring.material_override = rmat
		_sleep_gizmo.add_child(ring)
		_sleep_ringen.append(ring)


## Waar de gizmo staat en welke drie wereldrichtingen zijn assen zijn.
## "hand": de prop/musket in de hand, assen = die van de hand-aanhechting.
## "vuurmond": het punt waar flits en rook ontstaan, assen = die van de pion.
func _sleep_doel() -> Dictionary:
	if _pawn == null or not is_instance_valid(_pawn) or _sleep_btn == null:
		return {}
	var modus: String = ["uit", "hand", "vuurmond"][_sleep_btn.selected]  # label "voorwerp" = hand
	if modus == "hand":
		var w = _pawn._weapon
		if w == null or not is_instance_valid(w):
			return {}
		var ouder := (w as Node3D).get_parent() as Node3D
		if ouder == null:
			return {}
		var b := ouder.global_transform.basis.orthonormalized()
		return {"modus": modus, "pos": (w as Node3D).global_position,
			"assen": [b.x, b.y, b.z]}
	if modus == "vuurmond":
		var b2 := _pawn.global_transform.basis.orthonormalized()
		var pos: Vector3 = _muzzle_gizmo.global_position if (_sleep_as >= 0 and _sleep_modus == "vuurmond") \
			else _pawn.muzzle_world()
		return {"modus": modus, "pos": pos, "assen": [b2.x, b2.y, -b2.z]}
	return {}


func _sleep_armlengte() -> float:
	# Compact houden: bij de spel-camera (uitgezoomd) zou 10% van het beeld
	# een arm van bijna een meter geven -- die overschaduwt het model.
	return clampf((_cam.size if _cam != null else 2.0) * 0.06, 0.10, 0.30)


func _werk_sleep_gizmo_bij() -> void:
	if _sleep_gizmo == null:
		return
	var doel := _sleep_doel()
	if doel.is_empty():
		_sleep_gizmo.visible = false
		return
	_sleep_gizmo.visible = true
	var lengte := _sleep_armlengte()
	var draaibaar: bool = String(doel["modus"]) == "hand"   # een punt draai je niet
	for i in 3:
		# Highlight: de as die je vasthebt (of waar je overheen zweeft) licht op
		# en wordt dikker; de rest dimt weg.
		var arm_actief: bool = (_sleep_as == i and not _sleep_draaien) \
			or (_sleep_as < 0 and _hover_as == i and not _hover_draai)
		var ring_actief: bool = (_sleep_as == i and _sleep_draaien) \
			or (_sleep_as < 0 and _hover_as == i and _hover_draai)
		var iets_actief: bool = _sleep_as >= 0 or _hover_as >= 0
		_kleur_deel(_sleep_armen[i], i, arm_actief, iets_actief)
		_plaats_arm(_sleep_armen[i], doel["pos"], doel["assen"][i], lengte, 2.2 if arm_actief else 1.0)
		var ring: MeshInstance3D = _sleep_ringen[i]
		ring.visible = draaibaar
		if draaibaar:
			_kleur_deel(ring, i, ring_actief, iets_actief)
			_plaats_ring(ring, doel["pos"], doel["assen"][i], lengte * RING_FACTOR)
	_werk_gizmo_hint_bij()


## Oplichten (actief), normaal, of wegdimmen als er iets anders actief is.
func _kleur_deel(mi: MeshInstance3D, as_i: int, actief: bool, iets_actief: bool) -> void:
	var mat := mi.material_override as StandardMaterial3D
	if mat == null:
		return
	var basis: Color = GIZMO_KLEUREN[as_i]
	if actief:
		mat.albedo_color = Color(1.0, 0.95, 0.35)      # geel = dit heb je vast
	elif iets_actief:
		mat.albedo_color = Color(basis.r, basis.g, basis.b, 0.35)
	else:
		mat.albedo_color = basis


## Regeltje onder de schuifjes: welke as en wat hij doet.
func _werk_gizmo_hint_bij() -> void:
	if _gizmo_hint == null:
		return
	var as_i := _sleep_as if _sleep_as >= 0 else _hover_as
	var draai := _sleep_draaien if _sleep_as >= 0 else _hover_draai
	if as_i < 0:
		_gizmo_hint.text = "Sleep een arm om te verschuiven, een ring om te draaien. Loslaten = opslaan."
		_gizmo_hint.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
		return
	_gizmo_hint.text = "%s %s-as%s" % [
		"DRAAIEN om de" if draai else "VERSCHUIVEN langs de", AS_NAMEN[as_i],
		"  (sleep met de muis)" if _sleep_as < 0 else "  -- bezig..."]
	_gizmo_hint.add_theme_color_override("font_color", Color(1.0, 0.95, 0.35))


func _plaats_arm(arm: MeshInstance3D, oorsprong: Vector3, richting: Vector3,
		lengte: float, dik: float = 1.0) -> void:
	var d: Vector3 = (richting as Vector3).normalized()
	var hulp := Vector3.UP if absf(d.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var z := hulp.cross(d).normalized()
	var x := d.cross(z).normalized()
	# De arm loopt van ARM_START tot het uiteinde: het midden is ring-gebied,
	# zodat verschuiven en draaien elkaar niet in de weg zitten.
	var start := lengte * ARM_START
	var lijf := lengte - start
	var b := Basis(x, d, z).scaled(Vector3(dik, lijf, dik))
	arm.global_transform = Transform3D(b, oorsprong + d * (start + lijf * 0.5))


## Een ring ligt in het vlak loodrecht op zijn as (TorusMesh draait om Y).
func _plaats_ring(ring: MeshInstance3D, oorsprong: Vector3, richting: Vector3, straal: float) -> void:
	var d: Vector3 = (richting as Vector3).normalized()
	var hulp := Vector3.UP if absf(d.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var z := hulp.cross(d).normalized()
	var x := d.cross(z).normalized()
	ring.global_transform = Transform3D(Basis(x, d, z).scaled(Vector3(straal, straal, straal)), oorsprong)


## Twee loodrechte richtingen in het vlak van een as (voor hoekmeting/ring-punten).
func _vlak_assen(as_richting: Vector3) -> Array:
	var d := as_richting.normalized()
	var hulp := Vector3.UP if absf(d.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var u := hulp.cross(d).normalized()
	return [u, d.cross(u).normalized()]


## Hoek van de muis rond een as, gemeten in het vlak door de oorsprong.
func _ring_hoek(muis: Vector2, oorsprong: Vector3, as_richting: Vector3) -> float:
	if _cam == null:
		return 0.0
	var d := as_richting.normalized()
	var ro := _cam.project_ray_origin(muis)
	var rd := _cam.project_ray_normal(muis)
	var noemer := d.dot(rd)
	if absf(noemer) < 0.0001:
		return 0.0
	var punt := ro + rd * (d.dot(oorsprong - ro) / noemer)
	var vlak := _vlak_assen(d)
	var v := punt - oorsprong
	return atan2(v.dot(vlak[1]), v.dot(vlak[0]))


## Afstand van de muis tot een ring, in schermpixels (ring als veelhoek).
func _afstand_tot_ring(muis: Vector2, oorsprong: Vector3, as_richting: Vector3, straal: float) -> float:
	if _cam == null:
		return 9999.0
	var vlak := _vlak_assen(as_richting)
	var beste := 9999.0
	var vorig := Vector2.ZERO
	for i in 25:
		var hoek := TAU * float(i) / 24.0
		var wp: Vector3 = oorsprong + (vlak[0] as Vector3) * (cos(hoek) * straal) \
			+ (vlak[1] as Vector3) * (sin(hoek) * straal)
		var sp := _cam.unproject_position(wp)
		if i > 0:
			beste = minf(beste, _punt_naar_segment(muis, vorig, sp))
		vorig = sp
	return beste


## Afstand van een punt tot een lijnstuk in schermcoördinaten (voor het pakken).
func _punt_naar_segment(punt: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var lengte2 := ab.length_squared()
	if lengte2 < 0.0001:
		return punt.distance_to(a)
	var t := clampf((punt - a).dot(ab) / lengte2, 0.0, 1.0)
	return punt.distance_to(a + ab * t)


## Wat ligt er onder de muis? {"as": 0-2, "draai": bool} of {} als er niets
## binnen bereik is. Armen en ringen strijden op afstand-in-pixels, dus je
## pakt altijd wat er visueel het dichtst bij ligt.
func _gizmo_treffer(muis: Vector2) -> Dictionary:
	var doel := _sleep_doel()
	if doel.is_empty() or _cam == null:
		return {}
	var lengte := _sleep_armlengte()
	var beste := SLEEP_TREFFER_PX
	var uit: Dictionary = {}
	for i in 3:
		var a: Vector3 = doel["assen"][i]
		var p0 := _cam.unproject_position(doel["pos"] + a * (lengte * ARM_START))
		var p1 := _cam.unproject_position(doel["pos"] + a * lengte)
		var d := _punt_naar_segment(muis, p0, p1)
		if d < beste:
			beste = d
			uit = {"as": i, "draai": false}
	if String(doel["modus"]) == "hand":
		var straal := lengte * RING_FACTOR
		for i in 3:
			var dr := _afstand_tot_ring(muis, doel["pos"], doel["assen"][i], straal)
			if dr < beste:
				beste = dr
				uit = {"as": i, "draai": true}
	return uit


## Positie langs de as waar de muisstraal het dichtst bij komt (lijn-lijn).
func _as_parameter(muis: Vector2, oorsprong: Vector3, as_richting: Vector3) -> float:
	if _cam == null:
		return 0.0
	var ro := _cam.project_ray_origin(muis)
	var rd := _cam.project_ray_normal(muis)
	var w0 := oorsprong - ro
	var a := as_richting.dot(as_richting)
	var b := as_richting.dot(rd)
	var c := rd.dot(rd)
	var d := as_richting.dot(w0)
	var e := rd.dot(w0)
	var noemer := a * c - b * b
	if absf(noemer) < 0.00001:
		return 0.0
	return (b * e - c * d) / noemer


func _unhandled_input(event: InputEvent) -> void:
	if _sleep_gizmo == null or not _sleep_gizmo.visible:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			var doel := _sleep_doel()
			if doel.is_empty():
				return
			var treffer := _gizmo_treffer(mb.position)
			if treffer.is_empty():
				return
			var as_i: int = int(treffer["as"])
			var draaien: bool = bool(treffer["draai"])
			_sleep_as = as_i
			_sleep_draaien = draaien
			_sleep_modus = String(doel["modus"])
			_sleep_oorsprong = doel["pos"]
			_sleep_richting = (doel["assen"][as_i] as Vector3).normalized()
			if draaien:
				_sleep_start_hoek = _ring_hoek(mb.position, _sleep_oorsprong, _sleep_richting)
				_sleep_start_euler = Vector3(
					deg_to_rad(_weapon_spins["rx"].value),
					deg_to_rad(_weapon_spins["ry"].value),
					deg_to_rad(_weapon_spins["rz"].value))
			else:
				_sleep_start_t = _as_parameter(mb.position, _sleep_oorsprong, _sleep_richting)
				_sleep_start_waarde = _huidige_sleep_waarde()
			get_viewport().set_input_as_handled()
		elif _sleep_as >= 0:
			_sleep_afronden(mb.position)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _sleep_as >= 0:
			_sleep_verplaats(mm.position, false)
			get_viewport().set_input_as_handled()
		else:
			# Zweven: laat zien wat je zou pakken.
			var tr := _gizmo_treffer(mm.position)
			_hover_as = int(tr["as"]) if not tr.is_empty() else -1
			_hover_draai = bool(tr["draai"]) if not tr.is_empty() else false


## De waarde die we slepen, zoals hij nu in de spinboxen staat.
func _huidige_sleep_waarde() -> Vector3:
	if _sleep_modus == "hand":
		return Vector3(_weapon_spins["px"].value, _weapon_spins["py"].value, _weapon_spins["pz"].value)
	return Vector3(_muzzle_spins["x"].value, _muzzle_spins["y"].value, _muzzle_spins["z"].value)


## Live meebewegen tijdens het slepen; bij loslaten schrijven we de waarde
## via de gewone spinbox-route, zodat opslaan en herladen precies hetzelfde
## gaan als bij het tikken van cijfers.
func _sleep_verplaats(muis: Vector2, definitief: bool) -> void:
	if _sleep_draaien:
		_sleep_draai(muis, definitief)
		return
	var t := _as_parameter(muis, _sleep_oorsprong, _sleep_richting)
	var delta := t - _sleep_start_t
	var nieuw := _sleep_start_waarde
	nieuw[_sleep_as] = _sleep_start_waarde[_sleep_as] + delta
	if _sleep_modus == "hand":
		var sleutels := ["px", "py", "pz"]
		if definitief:
			for i in 3:
				_weapon_spins[sleutels[i]].value = snappedf(nieuw[i], 0.01)
		else:
			for i in 3:
				_weapon_spins[sleutels[i]].set_value_no_signal(snappedf(nieuw[i], 0.01))
			var w = _pawn._weapon
			if w != null and is_instance_valid(w):
				(w as Node3D).global_position = _sleep_oorsprong + _sleep_richting * delta
	else:
		var sleutels2 := ["x", "y", "z"]
		if definitief:
			for i in 3:
				_muzzle_spins[sleutels2[i]].value = snappedf(nieuw[i], 0.01)
		else:
			for i in 3:
				_muzzle_spins[sleutels2[i]].set_value_no_signal(snappedf(nieuw[i], 0.01))
			if _muzzle_gizmo != null:
				_muzzle_gizmo.global_position = _sleep_oorsprong + _sleep_richting * delta


## Draaien om de gepakte ring. De opgeslagen rotatie staat in de ruimte van de
## hand-aanhechting, dus we vermenigvuldigen VOOR met een draai om die as --
## precies wat je verwacht als je aan de ring trekt.
func _sleep_draai(muis: Vector2, definitief: bool) -> void:
	var hoek := _ring_hoek(muis, _sleep_oorsprong, _sleep_richting)
	var theta := wrapf(hoek - _sleep_start_hoek, -PI, PI)
	var lokale_as := Vector3.ZERO
	lokale_as[_sleep_as] = 1.0
	var nieuwe_basis := Basis(lokale_as, theta) * Basis.from_euler(_sleep_start_euler)
	var euler := nieuwe_basis.get_euler()
	var graden := Vector3(rad_to_deg(euler.x), rad_to_deg(euler.y), rad_to_deg(euler.z))
	var sleutels := ["rx", "ry", "rz"]
	if definitief:
		for i in 3:
			_weapon_spins[sleutels[i]].value = snappedf(graden[i], 1.0)
	else:
		for i in 3:
			_weapon_spins[sleutels[i]].set_value_no_signal(snappedf(graden[i], 1.0))
		var w = _pawn._weapon
		if w != null and is_instance_valid(w):
			(w as Node3D).rotation = euler


func _sleep_afronden(muis: Vector2) -> void:
	_sleep_verplaats(muis, true)
	_sleep_as = -1
	_sleep_draaien = false
	_sleep_modus = ""

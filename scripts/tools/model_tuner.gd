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
	{"key": "hat_fling_power", "label": "hoed-kracht", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.5},
	{"key": "hat_fling_time", "label": "hoed-hangtijd", "min": 0.1, "max": 10.0, "step": 0.01, "def": 1.8},
	{"key": "hat_pop_chance", "label": "hoed-kans", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.55},
	{"key": "limb_shed_chance", "label": "ledemaat-kans", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.4},
	{"key": "limb_fling_power", "label": "ledemaat-kracht", "min": 0.0, "max": 10.0, "step": 0.01, "def": 0.9},
	{"key": "limb_fling_time", "label": "ledemaat-hangtijd", "min": 0.1, "max": 10.0, "step": 0.01, "def": 1.0},
	{"key": "gib_fling_power", "label": "gib-worpkracht", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.0},
	{"key": "gib_spin", "label": "gib-tolling", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.0},
	{"key": "blood_burst", "label": "wond-druppels", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.0},
	{"key": "blood_spurt", "label": "spuit-straal", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.0},
	{"key": "blood_mist", "label": "kanon-mist", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.0},
	{"key": "mist_travel", "label": "mist-dracht", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.6},
	{"key": "drop_fall_time", "label": "druppel-duur", "min": 0.1, "max": 10.0, "step": 0.01, "def": 1.0},
	{"key": "drop_size", "label": "druppel-maat", "min": 0.1, "max": 10.0, "step": 0.01, "def": 1.0},
	{"key": "drop_stain_chance", "label": "druppel-vlekkans", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.35},
	{"key": "drop_stain_delay", "label": "vlek-wacht", "min": 0.0, "max": 10.0, "step": 0.01, "def": 0.05},
	{"key": "drop_stain_grow", "label": "vlek-groei", "min": 0.05, "max": 10.0, "step": 0.01, "def": 0.25},
	{"key": "gib_pool_delay", "label": "gib-poel-wacht", "min": 0.0, "max": 10.0, "step": 0.01, "def": 0.1},
	{"key": "gib_pool_grow", "label": "gib-poel-groei", "min": 0.05, "max": 10.0, "step": 0.01, "def": 0.45},
	{"key": "smoke_amount", "label": "rook-aantal", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.0},
	{"key": "smoke_size", "label": "rook-maat", "min": 0.1, "max": 10.0, "step": 0.01, "def": 1.0},
	{"key": "smoke_grow", "label": "rook-groei", "min": 0.5, "max": 10.0, "step": 0.01, "def": 3.0},
	{"key": "smoke_life", "label": "rook-duur", "min": 0.1, "max": 10.0, "step": 0.01, "def": 1.8},
	{"key": "smoke_drift", "label": "rook-drift", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.0},
	{"key": "blood_extra_delay", "label": "plas-wacht", "min": 0.0, "max": 10.0, "step": 0.01, "def": 0.4},
	{"key": "blood_grow", "label": "plas-groei", "min": 0.05, "max": 10.0, "step": 0.01, "def": 1.0},
	{"key": "blood_size", "label": "plas-maat", "min": 0.05, "max": 10.0, "step": 0.01, "def": 1.0},
	{"key": "death_blood_delay", "label": "lijkpoel-fallback", "min": 0.0, "max": 10.0, "step": 0.01, "def": 0.9},
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
var _fx_spins: Dictionary = {}      # effect-sleutel -> SpinBox
var _die_btn: OptionButton          # dood-clip keuze (death_pools-tuning)
var _dp_spins: Dictionary = {}      # "delay"/"grow"/"size"/"forward" -> SpinBox
var _cam: Camera3D = null           # wisselbare camera (spel/close-up/voorkant)
var _view_btn: OptionButton = null
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


func _ready() -> void:
	_build_world()
	_build_ui()
	_reload_pawns()
	if "gibshot" in OS.get_cmdline_user_args():
		var gs_args := OS.get_cmdline_user_args()
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
		if "voorkant" in shot_args:
			_view_btn.select(2)
		elif "closeup" in shot_args:
			_view_btn.select(1)
		if "formatie" in shot_args:
			_formation_btn.set_pressed(true)
		if "rook" in shot_args:
			_on_smoke_test(4, 0.16)
		_apply_camera()
		await get_tree().create_timer(1.4).timeout
		get_viewport().get_texture().get_image().save_png("res://_shot_tuner.png")
		get_tree().quit()


# --- Wereld: tegels, licht, camera --------------------------------------------

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
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	light.light_energy = 1.2
	add_child(light)
	var env := WorldEnvironment.new()
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


## Zet de camera volgens de gekozen view; in formatie-modus zoomt elke view
## uit zodat beide linies (3 vs 3 op tegels) volledig in beeld staan.
func _apply_camera() -> void:
	if _cam == null:
		return
	var view := 0 if _view_btn == null else _view_btn.selected
	var big := not _formation_pawns.is_empty()
	match view:
		1:  # close-up: zelfde spel-hoek, strak op het model
			_cam.size = 4.2 if big else 1.5
			_cam.transform = Transform3D(CAM_BASIS, Vector3(0.0, 0.55, 0.0) + CAM_BASIS.z * 8.0)
		2:  # voorkant: recht van voren, licht van boven (linies vallen vrij)
			_cam.size = 4.6 if big else 1.7
			_cam.transform = Transform3D(Basis(), Vector3(0.0, 1.2, 3.6))
			_cam.look_at(Vector3(0.0, 0.45, 0.0), Vector3.UP)
		_:  # spel-camera (bordhoek)
			_cam.size = 6.2 if big else 2.9
			_cam.transform = Transform3D(CAM_BASIS, Vector3(0.0, 0.45, 0.0) + CAM_BASIS.z * 8.0)


# --- UI -------------------------------------------------------------------------

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -525.0
	ui.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)

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
	# Camera-views: spel (bordhoek, WYSIWYG), close-up, voorkant.
	row1.add_child(_make_label("  Cam:"))
	_view_btn = OptionButton.new()
	for v in ["spel", "close-up", "voorkant"]:
		_view_btn.add_item(v)
	_view_btn.item_selected.connect(func(_i: int) -> void: _apply_camera())
	row1.add_child(_view_btn)
	# Formatie-vergelijk: 3 vs 3 (inf/cav/art) van twee facties tegenover
	# elkaar, allemaal via dezelfde auto-fit — schaal direct vergelijkbaar.
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

	var row2 := HBoxContainer.new()
	box.add_child(row2)
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
	# X/Z: het model binnen het vak schuiven (bv. als het uit het midden staat).
	row2.add_child(_make_label("  X"))
	_x_spin = _make_spin(row2, -0.5, 0.5, 0.01, 0.0, _on_tuning_changed)
	row2.add_child(_make_label(" Z"))
	_z_spin = _make_spin(row2, -0.5, 0.5, 0.01, 0.0, _on_tuning_changed)

	# Musket-rij: schaal, positie (wereld-units langs de hand-assen), rotatie.
	var roww := HBoxContainer.new()
	box.add_child(roww)
	roww.add_child(_make_label("Musket: schaal"))
	_weapon_spins["scale"] = _make_spin(roww, 0.1, 3.0, 0.05, 1.0, _on_weapon_changed)
	roww.add_child(_make_label(" pos"))
	for k in ["px", "py", "pz"]:
		_weapon_spins[k] = _make_spin(roww, -0.6, 0.6, 0.01, 0.0, _on_weapon_changed)
	roww.add_child(_make_label(" rot°"))
	for k in ["rx", "ry", "rz"]:
		_weapon_spins[k] = _make_spin(roww, -180.0, 180.0, 5.0, 0.0, _on_weapon_changed)

	# Effect-rijen: alle knopjes uit effects_tuning.json, live toegepast.
	var fxrow: HBoxContainer = null
	for i in FX_DEFS.size():
		if i % 4 == 0:
			fxrow = HBoxContainer.new()
			box.add_child(fxrow)
			fxrow.add_child(_make_label("Effect: " if i == 0 else "        "))
		var d: Dictionary = FX_DEFS[i]
		fxrow.add_child(_make_label(" %s" % d.label))
		var spin := _make_spin(fxrow, float(d.min), float(d.max), float(d.step),
			PawnView.fx(String(d.key), float(d.def)), _on_fx_changed)
		_fx_spins[String(d.key)] = spin

	# Dood-poel rij: per dood-clip de bloedpoel timen (wacht/groei/maat/
	# afstand in de valrichting). OPSLAAN schrijft dit mee (death_pools).
	var rowd := HBoxContainer.new()
	box.add_child(rowd)
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

	var row3 := HBoxContainer.new()
	box.add_child(row3)
	for clip in ["idle", "walk", "attack", "die"]:
		var btn := Button.new()
		btn.text = clip
		btn.pressed.connect(_on_clip.bind(clip))
		row3.add_child(btn)
	var freeze_btn := Button.new()
	freeze_btn.text = "stilzetten"
	freeze_btn.pressed.connect(_freeze_pose)
	row3.add_child(freeze_btn)
	var gib_btn := Button.new()
	gib_btn.text = "gibs (kanon)"
	gib_btn.pressed.connect(_on_gib_test.bind(1.4, "shot"))
	row3.add_child(gib_btn)
	var gib_btn2 := Button.new()
	gib_btn2.text = "gibs (musket)"
	gib_btn2.pressed.connect(_on_gib_test.bind(0.75, "shot"))
	row3.add_child(gib_btn2)
	var gib_btn3 := Button.new()
	gib_btn3.text = "gibs (melee)"
	gib_btn3.pressed.connect(_on_gib_test.bind(0.7, "melee"))
	row3.add_child(gib_btn3)
	var smoke_btn := Button.new()
	smoke_btn.text = "rook (musket)"
	smoke_btn.pressed.connect(_on_smoke_test.bind(2, 0.09))
	row3.add_child(smoke_btn)
	var smoke_btn2 := Button.new()
	smoke_btn2.text = "rook (kanon)"
	smoke_btn2.pressed.connect(_on_smoke_test.bind(4, 0.16))
	row3.add_child(smoke_btn2)
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
	var fac := _fac_btn.get_selected_id()
	var tp := _type_btn.get_selected_id()
	for e in _formation_pawns:
		if int(e.fac) == fac and int(e.tp) == tp and is_instance_valid(e.pv):
			return (e.pv as PawnView)._tune_key
	return ""


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
	var w: Dictionary = PawnView.model_tuning().get("%s/musket" % _fac_name(), {})
	_weapon_spins["scale"].value = float(w.get("scale", 1.0))
	var wpos: Array = w.get("pos", [0.0, 0.0, 0.0])
	var wrot: Array = w.get("rot", [0.0, 0.0, 0.0])
	for i in 3:
		_weapon_spins[["px", "py", "pz"][i]].value = float(wpos[i])
		_weapon_spins[["rx", "ry", "rz"][i]].value = float(wrot[i])
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
	PawnView.set_model_tuning("%s/musket" % _fac_name(), {
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
	for side in 2:
		var z := 1.0 if side == 0 else -1.0
		for tp in 3:  # 0=infanterie, 1=cavalerie, 2=artillerie
			var pv: PawnView = PAWN_SCENE.instantiate()
			pv.team = Constants.Team.RED if side == 0 else Constants.Team.BLUE
			pv.position = Vector3(float(tp - 1), 0.05, z)
			add_child(pv)
			pv.face_dir(Vector2i(0, -1) if side == 0 else Vector2i(0, 1))
			pv.set_unit_type(tp)
			pv.set_character(facs[side], tp, null)
			_formation_pawns.append({"pv": pv, "fac": int(facs[side]), "tp": tp})
	_info.text = "Formatie: %s (rood, onder) vs %s (blauw, boven) — schaal 1-op-1. Sliders tunen het model uit de dropdowns linksboven (factie + type)." % [
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
	if _pawn == null or not is_instance_valid(_pawn) or _die_btn.item_count == 0:
		return
	for n in get_tree().get_nodes_in_group("battlefield_debris"):
		n.queue_free()
	var clip := _die_btn.get_item_text(_die_btn.selected)
	_pawn.play_death(Vector3(0.2, 0.0, 1.0).normalized(), 0.75, "shot", clip)
	_pawn = null
	var t := create_tween()
	t.tween_interval(4.0)
	t.tween_callback(_respawn_model.bind(false))


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
	PawnView.set_model_tuning(key, {
		"scale": snappedf(_scale_slider.value, 0.01),
		"y": snappedf(_y_slider.value, 0.005),
		"x": snappedf(_x_spin.value, 0.01),
		"z": snappedf(_z_spin.value, 0.01),
	})
	_retune_target()


## Herlaad het model zodat auto-fit + tuning exact zo draaien als in het spel.
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


## Rooktest aan de loop van het tuning-model (musket- of kanon-maat).
func _on_smoke_test(count: int, size: float) -> void:
	PawnView.spawn_powder_smoke(self, Vector3(0.05, 0.55, 0.3), count, size,
		Vector3(0.3, 0.0, 1.0).normalized())


func _on_gib_test(strength: float, kind: String = "shot") -> void:
	if _pawn == null or not is_instance_valid(_pawn):
		return
	# (Geen reload van effects_tuning.json hier: de knopjes in de tuner zijn
	# de waarheid; herladen zou niet-opgeslagen wijzigingen terugdraaien.)
	# Vorige test-resten ruimen; het NIEUWE lijk laten we juist liggen.
	for n in get_tree().get_nodes_in_group("battlefield_debris"):
		n.queue_free()
	_pawn.play_death(Vector3(0.2, 0.0, 1.0).normalized(), strength, kind)
	_pawn = null
	# Levend model komt terug, maar de gibs/bloed/musket BLIJVEN liggen
	# (net als op het echte bord tot de nieuwe cyclus).
	var t := create_tween()
	t.tween_interval(4.0)
	t.tween_callback(_respawn_model.bind(false))


func _on_clip(clip: String) -> void:
	if _pawn == null:
		return
	match clip:
		"idle": _pawn.play_idle()
		"walk": _pawn.play_walk()
		"attack": _pawn.play_attack()
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

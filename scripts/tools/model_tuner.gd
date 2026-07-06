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
	{"key": "hat_fling_power", "label": "hoedkracht", "min": 0.0, "max": 3.0, "step": 0.1, "def": 1.5},
	{"key": "hat_fling_time", "label": "hoedhangtijd", "min": 0.5, "max": 4.0, "step": 0.1, "def": 1.8},
	{"key": "hat_pop_chance", "label": "hoedkans", "min": 0.0, "max": 1.0, "step": 0.05, "def": 0.55},
	{"key": "gib_fling_power", "label": "worpkracht", "min": 0.2, "max": 2.5, "step": 0.05, "def": 1.0},
	{"key": "gib_spin", "label": "tolling", "min": 0.0, "max": 2.5, "step": 0.05, "def": 1.0},
	{"key": "blood_extra_delay", "label": "bloed-wacht", "min": 0.0, "max": 2.0, "step": 0.05, "def": 0.4},
	{"key": "blood_grow", "label": "bloed-groei", "min": 0.2, "max": 3.0, "step": 0.1, "def": 1.0},
	{"key": "blood_size", "label": "bloed-maat", "min": 0.2, "max": 3.0, "step": 0.1, "def": 1.0},
	{"key": "death_blood_delay", "label": "dood-bloed", "min": 0.0, "max": 2.0, "step": 0.05, "def": 0.9},
]

var _pawn: PawnView = null
var _ref: PawnView = null
var _fac_btn: OptionButton
var _type_btn: OptionButton
var _arch_btn: OptionButton
var _scale_slider: HSlider
var _y_slider: HSlider
var _x_spin: SpinBox
var _z_spin: SpinBox
var _weapon_spins: Dictionary = {}  # "scale"/"px"/"py"/"pz"/"rx"/"ry"/"rz" -> SpinBox
var _fx_spins: Dictionary = {}      # effect-sleutel -> SpinBox
var _info: Label

var _updating := false  # geen slider-events tijdens het her-instellen


func _ready() -> void:
	_build_world()
	_build_ui()
	_reload_pawns()
	if "gibshot" in OS.get_cmdline_user_args():
		var gs_strength := 0.75 if "musket" in OS.get_cmdline_user_args() else 1.4
		await get_tree().create_timer(1.0).timeout
		if _pawn != null and is_instance_valid(_pawn):
			_pawn.play_death(Vector3(0.3, 0.0, 1.0).normalized(), gs_strength)
		await get_tree().create_timer(1.0 if gs_strength < 1.2 else 0.32).timeout
		get_viewport().get_texture().get_image().save_png("res://_shot_gibs.png")
		get_tree().quit()
	if "shot" in OS.get_cmdline_user_args():
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
			tile.position = Vector3(float(x), -0.05, float(z))
			add_child(tile)
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
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 1.6, 2.6)
	add_child(cam)
	cam.look_at(Vector3(0.0, 0.45, 0.0), Vector3.UP)
	cam.current = true


# --- UI -------------------------------------------------------------------------

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -330.0
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
		(b as OptionButton).item_selected.connect(func(_i: int) -> void: _reload_pawns())

	var row2 := HBoxContainer.new()
	box.add_child(row2)
	row2.add_child(_make_label("Schaal"))
	_scale_slider = HSlider.new()
	_scale_slider.min_value = 0.4
	_scale_slider.max_value = 2.5
	_scale_slider.step = 0.01
	_scale_slider.value = 1.0
	_scale_slider.custom_minimum_size = Vector2(340, 0)
	_scale_slider.value_changed.connect(_on_tuning_changed)
	row2.add_child(_scale_slider)
	row2.add_child(_make_label("  Hoogte"))
	_y_slider = HSlider.new()
	_y_slider.min_value = -0.4
	_y_slider.max_value = 0.4
	_y_slider.step = 0.005
	_y_slider.value = 0.0
	_y_slider.custom_minimum_size = Vector2(240, 0)
	_y_slider.value_changed.connect(_on_tuning_changed)
	row2.add_child(_y_slider)
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
	gib_btn.pressed.connect(_on_gib_test.bind(1.4))
	row3.add_child(gib_btn)
	var gib_btn2 := Button.new()
	gib_btn2.text = "gibs (musket)"
	gib_btn2.pressed.connect(_on_gib_test.bind(0.75))
	row3.add_child(gib_btn2)
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


## Huidige factie-naam in kleine letters ("muis") — sleutels in model_tuning.json.
func _fac_name() -> String:
	return Constants.doctrine_folder(_fac_btn.get_selected_id())


func _on_weapon_changed(_v: float) -> void:
	if _updating or _pawn == null:
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
	_respawn_model()


# --- Model laden / bijstellen ---------------------------------------------------

func _current_card() -> Card:
	var arch: String = ARCHS[_arch_btn.selected]
	if not ARCH_CARDS.has(arch):
		return null
	var s: Array = ARCH_CARDS[arch]
	return Card.new(0, 0, 0, int(s[0]), int(s[1]), int(s[2]))


func _reload_pawns() -> void:
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
	_updating = true
	var t: Dictionary = PawnView.model_tuning().get(_pawn._tune_key, {})
	_scale_slider.value = float(t.get("scale", 1.0))
	_y_slider.value = float(t.get("y", 0.0))
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
	_refresh_info()


func _on_tuning_changed(_v: float) -> void:
	if _updating or _pawn == null:
		return
	if _pawn._tune_key == "":
		_refresh_info()
		return
	PawnView.set_model_tuning(_pawn._tune_key, {
		"scale": snappedf(_scale_slider.value, 0.01),
		"y": snappedf(_y_slider.value, 0.005),
		"x": snappedf(_x_spin.value, 0.01),
		"z": snappedf(_z_spin.value, 0.01),
	})
	_respawn_model()


## Herlaad het model zodat auto-fit + tuning exact zo draaien als in het spel.
func _respawn_model() -> void:
	var doctrine: int = _fac_btn.get_selected_id()
	var unit_type: int = _type_btn.get_selected_id()
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


func _on_gib_test(strength: float) -> void:
	if _pawn == null or not is_instance_valid(_pawn):
		return
	_pawn.play_death(Vector3(0.2, 0.0, 1.0).normalized(), strength)
	_pawn = null
	var t := create_tween()
	t.tween_interval(2.4)
	t.tween_callback(_respawn_model)


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
		_info.text = "%s  ·  schaal %.2f  ·  hoogte %+.3f  ·  x %+.2f  ·  z %+.2f   (links = referentiestuk; OPSLAAN schrijft model_tuning.json)" % [
			_pawn._tune_key, _scale_slider.value, _y_slider.value, _x_spin.value, _z_spin.value]


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

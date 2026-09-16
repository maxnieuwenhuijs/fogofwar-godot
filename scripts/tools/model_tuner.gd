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
	{"cat": "bajonet", "key": "hit_speed", "label": "hit-tempo", "min": 0.2, "max": 10.0, "step": 0.01, "def": 1.0},
	{"cat": "bajonet", "key": "death_speed", "label": "sterf-tempo", "min": 0.2, "max": 10.0, "step": 0.01, "def": 1.0},
	{"cat": "bajonet", "key": "melee_retaliation_delay", "label": "terugslag-vertraging", "min": 0.0, "max": 3.0, "step": 0.01, "def": 0.1},
	# Cavalerie-charge (16 september): de sprong begint zoveel vakken voor de
	# aankomst en de klap valt zoveel seconden voor het einde van de sprong-clip.
	{"cat": "bajonet", "key": "charge_speed", "label": "sprong-tempo", "min": 0.2, "max": 10.0, "step": 0.01, "def": 1.2},
	{"cat": "bajonet", "key": "charge_klap_na_landing", "label": "sprong-klap na de landing (s)", "min": 0.0, "max": 1.5, "step": 0.01, "def": 0.12},
	{"cat": "gore", "key": "debris_donker_na", "label": "donker na (s)", "min": 0.0, "max": 30.0, "step": 0.5, "def": 4.0},
	{"cat": "gore", "key": "debris_donker_duur", "label": "donker duur (s)", "min": 0.1, "max": 15.0, "step": 0.1, "def": 2.5},
	{"cat": "gore", "key": "debris_donker", "label": "hoe donker", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.7},
	{"cat": "gore", "key": "debris_doorzicht", "label": "hoe doorzichtig", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.55},
	{"cat": "gore", "key": "debris_zak", "label": "zakt in bord", "min": 0.0, "max": 0.5, "step": 0.01, "def": 0.08},
	{"cat": "gore", "key": "hat_fling_power", "label": "hoed-kracht", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.5},
	{"cat": "gore", "key": "hat_fling_time", "label": "hoed-hangtijd", "min": 0.1, "max": 10.0, "step": 0.01, "def": 1.8},
	{"cat": "gore", "key": "hat_pop_chance", "label": "hoed-kans", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.55},
	{"cat": "gore", "key": "limb_shed_chance", "label": "ledemaat-kans", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.4},
	{"cat": "gore", "key": "limb_fling_power", "label": "ledemaat-kracht", "min": 0.0, "max": 10.0, "step": 0.01, "def": 0.9},
	{"cat": "gore", "key": "limb_fling_time", "label": "ledemaat-hangtijd", "min": 0.1, "max": 10.0, "step": 0.01, "def": 1.0},
	{"cat": "gore", "key": "gib_fling_power", "label": "gib-worpkracht", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.0},
	{"cat": "gore", "key": "gib_spin", "label": "gib-tolling", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.0},
	# Doormidden (16 september): de sabelhouw snijdt het lijf in twee helften.
	{"cat": "gore", "key": "slice_kans_sabel", "label": "doormidden-kans (sabel)", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.85},
	{"cat": "gore", "key": "slice_kans_bajonet", "label": "doormidden-kans (bajonet)", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.35},
	{"cat": "gore", "key": "slice_hoogte", "label": "snijhoogte (deel van de pion)", "min": 0.15, "max": 0.85, "step": 0.01, "def": 0.55},
	{"cat": "gore", "key": "slice_hoek", "label": "snijhoek sabel (graden)", "min": 0.0, "max": 70.0, "step": 1.0, "def": 35.0},
	{"cat": "gore", "key": "slice_hoek_bajonet", "label": "snijhoek bajonet (graden)", "min": 0.0, "max": 70.0, "step": 1.0, "def": 10.0},
	{"cat": "gore", "key": "slice_sta", "label": "benen staan nog (s)", "min": 0.0, "max": 2.0, "step": 0.01, "def": 0.35},
	{"cat": "gore", "key": "slice_los", "label": "losse stukjes (wolkje)", "min": 0.0, "max": 4.0, "step": 1.0, "def": 2.0},
	{"cat": "gore", "key": "slice_kracht", "label": "helft-worpkracht", "min": 0.0, "max": 5.0, "step": 0.01, "def": 1.0},
	{"cat": "gore", "key": "slice_tuimel", "label": "salto's van de romp", "min": 0.0, "max": 3.0, "step": 0.5, "def": 1.0},
	{"cat": "bloed", "key": "blood_burst", "label": "wond-druppels", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.0},
	{"cat": "bloed", "key": "blood_spurt", "label": "spuit-straal", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.0},
	{"cat": "bloed", "key": "blood_mist", "label": "kanon-mist", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.0},
	{"cat": "bloed", "key": "mist_travel", "label": "mist-dracht", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.6},
	{"cat": "bloed", "key": "drop_fall_time", "label": "druppel-duur", "min": 0.1, "max": 10.0, "step": 0.01, "def": 1.0},
	{"cat": "bloed", "key": "drop_size", "label": "druppel-maat", "min": 0.1, "max": 10.0, "step": 0.01, "def": 1.0},
	{"cat": "bloed", "key": "wound_blood", "label": "wond-bloed (overleven)", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.0},
	{"cat": "bloed", "key": "wound_delay", "label": "wond-vertraging", "min": 0.0, "max": 3.0, "step": 0.01, "def": 0.0},
	{"cat": "bloed", "key": "wound_straal", "label": "wond-straaltje (lengte)", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.22},
	{"cat": "bloed", "key": "wound_straal_dikte", "label": "straaltje dikte (voet)", "min": 0.005, "max": 0.1, "step": 0.001, "def": 0.022},
	{"cat": "bloed", "key": "wound_straal_op", "label": "straaltje op (s)", "min": 0.01, "max": 0.5, "step": 0.01, "def": 0.07},
	{"cat": "bloed", "key": "wound_straal_duur", "label": "straaltje terug (s)", "min": 0.05, "max": 2.0, "step": 0.01, "def": 0.3},
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
var _snd_lijst: VBoxContainer = null   # geluid-tab: rij per categorie
const SLEEP_TREFFER_PX := 14.0
const RING_FACTOR := 1.35             # ringstraal t.o.v. de armlengte
const ARM_START := 0.30               # armen beginnen buiten het midden (daar liggen de ringen)
const GIZMO_KLEUREN := [Color(0.95, 0.35, 0.35), Color(0.4, 0.9, 0.45), Color(0.45, 0.65, 1.0)]
const AS_NAMEN := ["X", "Y", "Z"]
var _tuner_light: DirectionalLight3D = null
var _tuner_env: WorldEnvironment = null
var _team_btn: OptionButton = null      # rood / blauw / rood vs blauw
var _alles_btn: Button = null           # alle facties naast elkaar
var _bord_btn: Button = null            # het echte bord eronder
var _bord: Node3D = null                # de Board.tscn-instantie, als hij aan staat
var _tuner_vloer: Node3D = null         # de eigen 5x3 tegels + hulpkruis (uit als het bord aan is)
var _legers_btn: Button = null          # bord + beide legers in de spel-opstelling
var _alles_modus: bool = false          # staat de alle-facties-opstelling aan?
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
	if "wondshot" in OS.get_cmdline_user_args():
		# Overleefde klap (16 september): incasseer-clip + wond met het spitse
		# bloedstraaltje aan het rompbot. Print of het straaltje er hangt en
		# aan welk bot, schrijft _shot_wond.png op het hoogtepunt en meet of
		# hij zich daarna weer opruimt. Headless bruikbaar (dan geen plaatje).
		await get_tree().create_timer(1.0).timeout
		var ws_fouten := 0
		if _pawn == null or not is_instance_valid(_pawn):
			print("[WOND] FOUT: geen pion")
			ws_fouten += 1
		else:
			_pawn.flash_hit()
			# Zijwaarts, zodat het straaltje op het plaatje niet naar de camera wijst.
			_pawn.stagger(Vector3(1.0, 0.0, 0.2).normalized())
			_pawn.play_hit()
			_pawn.play_wound(Vector3(1.0, 0.0, 0.2).normalized())
			await get_tree().create_timer(PawnView.fx("wound_straal_op", 0.07) + 0.02).timeout
			var ws_att: Array = _pawn.find_children("Bloedstraal", "BoneAttachment3D", true, false)
			if ws_att.is_empty():
				var ws_skels: Array = _pawn.find_children("*", "Skeleton3D", true, false)
				var ws_namen := PackedStringArray()
				if not ws_skels.is_empty():
					for bi in (ws_skels[0] as Skeleton3D).get_bone_count():
						ws_namen.append((ws_skels[0] as Skeleton3D).get_bone_name(bi))
				print("[WOND] FOUT: geen Bloedstraal-attachment aan het skelet (skeletten %d, botten: %s)" % [ws_skels.size(), ", ".join(ws_namen)])
				ws_fouten += 1
			else:
				var ws_a: BoneAttachment3D = ws_att[0]
				var ws_skel := ws_a.get_parent() as Skeleton3D
				var ws_straal: MeshInstance3D = ws_a.find_children("Straal", "MeshInstance3D", true, false)[0]
				var ws_maat: Node3D = ws_straal.get_parent()
				var ws_bot := ws_skel.get_bone_name(ws_a.bone_idx) if ws_skel != null else "?"
				var ws_h: float = (ws_straal.mesh as CylinderMesh).height
				var ws_top: Vector3 = ws_straal.global_transform * Vector3(0.0, ws_h * 0.5, 0.0)
				var ws_voet: Vector3 = ws_maat.global_position
				print("[WOND] straaltje aan bot %s: voet y=%.2f, punt op %.2f eenheden, schaal y=%.2f" % [
					ws_bot, ws_voet.y, ws_voet.distance_to(ws_top), ws_maat.scale.y])
				if ws_maat.scale.y < 0.8:
					print("[WOND] FOUT: het straaltje staat op het hoogtepunt niet uit (schaal %.2f)" % ws_maat.scale.y)
					ws_fouten += 1
			if not OS.has_feature("headless") and DisplayServer.get_name() != "headless":
				get_viewport().get_texture().get_image().save_png("res://_shot_wond.png")
			await get_tree().create_timer(PawnView.fx("wound_straal_duur", 0.3) + 0.3).timeout
			if not _pawn.find_children("Bloedstraal", "BoneAttachment3D", true, false).is_empty():
				print("[WOND] FOUT: het straaltje ruimt zich niet op")
				ws_fouten += 1
		print("[WOND] %s: %d fout(en)" % ["PASS" if ws_fouten == 0 else "FAIL", ws_fouten])
		get_tree().quit(1 if ws_fouten > 0 else 0)
		return
	if "snijcheck" in OS.get_cmdline_user_args():
		# Doormidden (16 september): de sabelhouw snijdt het lijf in twee
		# helften. Controleert dat de gibs in Body_boven / Benen_onder zijn
		# verdeeld, dat de romp door het vlak is verdubbeld (twee snij-
		# materialen), dat de losse stukjes en het bloed er zijn, dat de
		# bovenste helft wegvliegt en de onderste omkiept, en dat alles in de
		# debris-groep zit. Met venster: _shot_snij.png halverwege de vlucht.
		# Headless bruikbaar (geen plaatje). Default model: muis-infanterie.
		if "closeup" in OS.get_cmdline_user_args():
			_view_btn.select(1)
			_apply_camera()
		await get_tree().create_timer(1.0).timeout
		var sn_fouten := 0
		if _pawn == null or not is_instance_valid(_pawn):
			print("[SNIJ] FOUT: geen pion")
			sn_fouten += 1
		elif not ResourceLoader.exists(_pawn._gibs_pad()):
			print("[SNIJ] FOUT: dit model heeft geen gibs-bestand (%s)" % _pawn._gibs_pad())
			sn_fouten += 1
		else:
			PawnView.set_fx("slice_kans_sabel", 1.0)
			var sn_dir := Vector3(0.3, 0.0, 1.0).normalized()
			var sn_bloed_voor: int = get_tree().get_nodes_in_group("battlefield_debris").size()
			_pawn.play_death(sn_dir, 1.25, "charge")
			await get_tree().process_frame
			var sn_boven: Array = find_children("Body_boven", "Node3D", true, false)
			var sn_onder: Array = find_children("Benen_onder", "Node3D", true, false)
			if sn_boven.is_empty() or sn_onder.is_empty():
				print("[SNIJ] FOUT: geen twee helften (boven %d, onder %d)" % [sn_boven.size(), sn_onder.size()])
				sn_fouten += 1
			else:
				var sn_b: Node3D = sn_boven[0]
				var sn_o: Node3D = sn_onder[0]
				var sn_root: Node3D = sn_b.get_parent()
				var sn_snedes := 0
				var sn_meshes := 0
				for mi in sn_root.find_children("*", "MeshInstance3D", true, false):
					sn_meshes += 1
					var sm := (mi as MeshInstance3D).material_override as ShaderMaterial
					if sm != null and sm.get_shader_parameter("snij_n") != null:
						sn_snedes += 1
				var sn_los := 0
				for kind in sn_root.get_children():
					if kind is MeshInstance3D:
						sn_los += 1
				print("[SNIJ] delen %d (boven %d, onder %d, los %d), snijvlakken %d" % [
					sn_meshes, sn_b.get_child_count(), sn_o.get_child_count(), sn_los, sn_snedes])
				if sn_snedes < 2:
					print("[SNIJ] FOUT: de romp is niet door het vlak verdubbeld (snijvlakken %d, verwacht minstens 2)" % sn_snedes)
					sn_fouten += 1
				if sn_b.get_child_count() < 2 or sn_o.get_child_count() < 2:
					print("[SNIJ] FOUT: een helft is te leeg (boven %d, onder %d delen)" % [sn_b.get_child_count(), sn_o.get_child_count()])
					sn_fouten += 1
				if sn_los < 1:
					print("[SNIJ] FOUT: geen los stukje (het gibs-wolkje)")
					sn_fouten += 1
				if not sn_root.is_in_group("battlefield_debris"):
					print("[SNIJ] FOUT: de helften zitten niet in battlefield_debris")
					sn_fouten += 1
				if not _pawn.is_in_group("battlefield_debris") or (_pawn._piece != null and _pawn._piece.visible):
					print("[SNIJ] FOUT: het originele lijf is niet weg")
					sn_fouten += 1
				var sn_start_b: Vector3 = sn_b.global_position
				var sn_start_o: Basis = sn_o.global_basis
				await get_tree().create_timer(0.22).timeout
				if not OS.has_feature("headless") and DisplayServer.get_name() != "headless":
					get_viewport().get_texture().get_image().save_png("res://_shot_snij.png")
				await get_tree().create_timer(0.5).timeout
				var sn_verplaatst: float = sn_b.global_position.distance_to(sn_start_b)
				print("[SNIJ] bovenste helft verplaatst %.2f, y nu %.2f" % [sn_verplaatst, sn_b.global_position.y])
				if sn_verplaatst < 0.15:
					print("[SNIJ] FOUT: de bovenste helft vliegt niet weg")
					sn_fouten += 1
				await get_tree().create_timer(PawnView.fx("slice_sta", 0.35) + 0.6).timeout
				var sn_kiep: float = rad_to_deg((sn_start_o * Vector3.UP).angle_to(sn_o.global_basis * Vector3.UP))
				print("[SNIJ] onderste helft gekiept %.0f graden" % sn_kiep)
				if sn_kiep < 60.0:
					print("[SNIJ] FOUT: de onderste helft kiept niet om (%.0f graden)" % sn_kiep)
					sn_fouten += 1
				if not OS.has_feature("headless") and DisplayServer.get_name() != "headless":
					await get_tree().create_timer(0.4).timeout
					get_viewport().get_texture().get_image().save_png("res://_shot_snij_laat.png")
				var sn_bloed_na: int = get_tree().get_nodes_in_group("battlefield_debris").size()
				print("[SNIJ] debris-nodes: %d -> %d (bloed, helften, stukjes)" % [sn_bloed_voor, sn_bloed_na])
				if sn_bloed_na - sn_bloed_voor < 4:
					print("[SNIJ] FOUT: nauwelijks bloed of debris bijgekomen")
					sn_fouten += 1
		print("[SNIJ] %s: %d fout(en)" % ["PASS" if sn_fouten == 0 else "FAIL", sn_fouten])
		get_tree().quit(1 if sn_fouten > 0 else 0)
		return
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
		elif "sabel" in gs_args:
			# De charge-kill (16 september): 0,85 + 0,4 voor de kill, kind "charge"
			# -> doormidden (kans op 1 gezet voor een reproduceerbaar plaatje).
			gs_strength = 1.25
			gs_kind = "charge"
			PawnView.set_fx("slice_kans_sabel", 1.0)
		await get_tree().create_timer(1.0).timeout
		if _pawn != null and is_instance_valid(_pawn):
			_pawn.play_death(Vector3(0.3, 0.0, 1.0).normalized(), gs_strength, gs_kind)
		await get_tree().create_timer(1.0 if gs_strength < 1.2 else 0.32).timeout
		get_viewport().get_texture().get_image().save_png("res://_shot_gibs.png")
		if "laat" in gs_args:
			# Het lijk na het verduisteren/doorzichtig worden/wegzakken (16 september).
			await get_tree().create_timer(PawnView.fx("debris_donker_na", 4.0) + PawnView.fx("debris_donker_duur", 2.5) + 0.5).timeout
			get_viewport().get_texture().get_image().save_png("res://_shot_gibs_laat.png")
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
		if "legers" in shot_args:
			_legers_btn.set_pressed(true)
			_type_btn.select(Constants.UnitType.CAVALRY)
			_fac_btn.select(_my_fac_btn.selected)
		if "charge" in shot_args:
			_on_charge_test(true)
		if "rook" in shot_args:
			_on_smoke_test(4, 0.16)
		if "melee" in shot_args:
			_on_clip("melee")
		if "donker" in shot_args:
			_on_dark_toggled(true)
		if "vuur" in shot_args:
			_on_fire_test()
		_apply_camera()
		await get_tree().create_timer(2.6 if "charge" in shot_args else 1.4).timeout
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
	# De eigen tegels en het hulpkruis onder een node, zodat het bord ze kan
	# verbergen (ze lagen op dezelfde hoogte als het bordoppervlak en
	# flikkerden er dwars doorheen, 16 september).
	_tuner_vloer = Node3D.new()
	add_child(_tuner_vloer)
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
			_tuner_vloer.add_child(tile)
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
	_tuner_vloer.add_child(dbg)
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
	# "bord": de camera uit Board.tscn zelf, dus precies wat de speler ziet.
	# Zonder bord valt hij terug op de spel-hoek van de tuner.
	var bord_cam: Camera3D = _bord_camera()
	if view == 3 and bord_cam != null:
		bord_cam.current = true
		return
	if bord_cam != null:
		bord_cam.current = false
	_cam.current = true
	# Zes rijen facties passen niet in het formatie-kader, dus die krijgen meer.
	var big := not _formation_pawns.is_empty()
	var alles := _alles_modus or _legers_modus()
	match view:
		1:  # close-up: zelfde spel-hoek, strak op het model
			_cam.size = (19.0 if alles else 8.5) if big else 1.5
			_cam.transform = Transform3D(CAM_BASIS, Vector3(0.0, 0.55, 0.0) + CAM_BASIS.z * 8.0)
		2:  # voorkant: recht van voren, licht van boven (linies vallen vrij)
			_cam.size = (20.0 if alles else 9.0) if big else 1.7
			_cam.transform = Transform3D(Basis(), Vector3(0.0, 1.2, 3.6))
			_cam.look_at(Vector3(0.0, 0.45, 0.0), Vector3.UP)
		_:  # spel-camera (bordhoek)
			_cam.size = (23.0 if alles else 12.5) if big else 2.9
			_cam.transform = Transform3D(CAM_BASIS, Vector3(0.0, 0.6, 0.0) + CAM_BASIS.z * 8.0)


# --- UI -------------------------------------------------------------------------

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var panel := PanelContainer.new()
	# Aan de ONDERKANT hangen met een hoogte in pixels, sleepbaar via de greep
	# bovenin. Een vast aandeel van het scherm werkt niet: op Max' staande venster
	# (1080x1920) is 56% ruim 1000 px en blijft er van het model een streepje
	# over. Een vast aantal pixels werkt ook niet, want schermen verschillen.
	# Dus: zelf slepen, en de keuze onthouden.
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 4.0
	panel.offset_right = -4.0
	panel.offset_bottom = -4.0
	panel.theme = _tuner_thema()
	_paneel = panel
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.11, 0.15, 0.96)
	style.border_color = Color(0.38, 0.44, 0.60, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", style)
	ui.add_child(panel)
	# Vaste knoppen RECHTSBOVEN (Max, 28 juli): het paneel onderin groeit mee
	# met de tabs, waardoor de oude onderbalk buiten beeld kon vallen.
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top.anchor_left = 1.0
	top.offset_left = -330.0
	top.offset_right = -10.0
	top.offset_top = 10.0
	top.offset_bottom = 46.0
	top.alignment = BoxContainer.ALIGNMENT_END
	top.add_theme_constant_override("separation", 8)
	ui.add_child(top)
	var save_top := Button.new()
	save_top.text = "  OPSLAAN  "
	save_top.add_theme_font_size_override("font_size", 13)
	save_top.pressed.connect(_save)
	top.add_child(save_top)
	var back_top := Button.new()
	back_top.text = "Terug naar het spel"
	back_top.add_theme_font_size_override("font_size", 13)
	back_top.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/game/game.tscn"))
	top.add_child(back_top)

	var box := VBoxContainer.new()
	box.add_child(_maak_sleepgreep())
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	# --- Bovenbalk: model-selectie · camera · vergelijk-formatie -------------
	# HFlowContainer (16 september, Max: "alle knoppen beter in beeld"): de
	# rijen breken af naar een volgende regel in plaats van rechts buiten
	# beeld te lopen op een smal of staand venster.
	var row1 := HFlowContainer.new()
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
	for v in ["spel", "close-up", "voorkant", "bord"]:
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
	# Team-keuze (Max, 7 september): alles in rood of alles in blauw bekijken.
	# Tot nu toe kon je alleen rood TEGENOVER blauw zien, en dan staat de ene
	# jas altijd van je af.
	row1.add_child(_make_label("  Team:"))
	_team_btn = OptionButton.new()
	for tn in ["rood vs blauw", "alles rood", "alles blauw"]:
		_team_btn.add_item(tn)
	_team_btn.item_selected.connect(func(_i: int) -> void: _herbouw_huidige())
	row1.add_child(_team_btn)
	# Alle facties naast elkaar: zes rijen, vijf kolommen. De formatie-knop toont
	# er maar twee, en de schaalvraag ("is de beer te groot naast de muis?") gaat
	# juist over alle zes tegelijk.
	_alles_btn = Button.new()
	_alles_btn.text = "alle modellen"
	_alles_btn.toggle_mode = true
	_alles_btn.toggled.connect(_on_alles_toggled)
	row1.add_child(_alles_btn)
	# Het echte bord eronder, met zijn eigen textures en licht.
	_bord_btn = Button.new()
	_bord_btn.text = "bord"
	_bord_btn.toggle_mode = true
	_bord_btn.toggled.connect(_zet_bord)
	row1.add_child(_bord_btn)
	# Het bord MET beide legers in de spel-opstelling (16 september, Max:
	# "voeg gewoon een bord toe met alle pionnen net als in het spel zelf").
	_legers_btn = Button.new()
	_legers_btn.text = "bord + legers"
	_legers_btn.toggle_mode = true
	_legers_btn.toggled.connect(_on_legers_toggled)
	row1.add_child(_legers_btn)
	for fb in [_my_fac_btn, _opp_fac_btn]:
		(fb as OptionButton).item_selected.connect(func(_i: int) -> void:
			if _formation_btn.button_pressed:
				_build_formation()
			elif _legers_btn.button_pressed:
				_bouw_legers())

	# --- Preview-strip: altijd zichtbaar, welke tab je ook open hebt ----------
	# Elke druk onderbreekt de vorige preview direct (zie _interrupt_previews).
	var rowp := HFlowContainer.new()
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
	var rowt := HFlowContainer.new()
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
	# Doormidden (16 september): de sabel-kill zoals in het spel (0,85 + 0,4).
	var gib_btn4 := Button.new()
	gib_btn4.text = "doormidden (sabel)"
	gib_btn4.pressed.connect(_on_gib_test.bind(1.25, "charge"))
	rowt.add_child(gib_btn4)
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
	var charge_btn := Button.new()
	charge_btn.text = "charge (dood)"
	charge_btn.pressed.connect(_on_charge_test.bind(true))
	rowt.add_child(charge_btn)
	var charge_btn2 := Button.new()
	charge_btn2.text = "charge (overleeft)"
	charge_btn2.pressed.connect(_on_charge_test.bind(false))
	rowt.add_child(charge_btn2)

	# --- Tabs per categorie ---------------------------------------------------
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(0, 160)
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
	_scale_slider.custom_minimum_size = Vector2(120, 0)
	_scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scale_slider.value_changed.connect(_on_slider_paired.bind("scale"))
	row2.add_child(_scale_slider)
	_scale_spin = _make_spin(row2, 0.4, 2.5, 0.01, 1.0, _on_spin_paired.bind("scale"))
	row2.add_child(_make_label("  Hoogte"))
	_y_slider = HSlider.new()
	_y_slider.min_value = -0.4
	_y_slider.max_value = 0.4
	_y_slider.step = 0.005
	_y_slider.value = 0.0
	_y_slider.custom_minimum_size = Vector2(100, 0)
	_y_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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

	# --- Tab GELUID: alles horen wat bij dit model hoort (Max, 28 juli) -----
	var tab_snd := VBoxContainer.new()
	tab_snd.name = "Geluid"
	tab_snd.add_theme_constant_override("separation", 6)
	tabs.add_child(tab_snd)
	_snd_lijst = VBoxContainer.new()
	_snd_lijst.add_theme_constant_override("separation", 4)
	tab_snd.add_child(_snd_lijst)
	var snd_uitleg := _make_label("Klik om te horen. dB = volume, vertraging = later (+) of eerder (-) afspelen; wordt bewaard in sounds/sound_tuning.json. Test met \"test dood\" op de Melee-tab.")
	snd_uitleg.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	tab_snd.add_child(snd_uitleg)

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

	# Elke tab in een ScrollContainer. Zonder dit viel alles wat niet paste
	# gewoon weg -- geen balk, geen melding (Max, 7 september).
	for tab_kind in tabs.get_children():
		if tab_kind is ScrollContainer:
			continue
		var tab_ctrl := tab_kind as Control
		var tab_naam := tab_ctrl.name
		tabs.remove_child(tab_ctrl)
		var scroll := ScrollContainer.new()
		scroll.name = tab_naam
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tab_ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(tab_ctrl)
		tabs.add_child(scroll)

	_zet_paneelhoogte(_lees_paneelhoogte(), false)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_font_size_override("font_size", 11)
	_info.add_theme_color_override("font_color", Color(0.66, 0.71, 0.82))
	box.add_child(_info)


# --- Team, alle modellen, bord (Max, 7 september) ---------------------------

## Welk team hoort bij deze kant? kant 0 = links/eigen, 1 = tegenover.
## "alles rood" en "alles blauw" negeren de kant: dan draagt ELK model dezelfde
## jas, zodat je een hele factie in een teamkleur kunt beoordelen.
func _team_voor(kant: int) -> int:
	match (0 if _team_btn == null else _team_btn.selected):
		1:
			return Constants.Team.RED
		2:
			return Constants.Team.BLUE
		_:
			return Constants.Team.RED if kant == 0 else Constants.Team.BLUE


## Bouw opnieuw op wat er NU staat: de alle-modellen-opstelling, de formatie,
## of het losse model. Gebruikt door de team-keuze.
func _herbouw_huidige() -> void:
	if _alles_btn != null and _alles_btn.button_pressed:
		_bouw_alle_modellen()
	elif _legers_modus():
		_bouw_legers()
	elif _formation_btn != null and _formation_btn.button_pressed:
		_build_formation()
	else:
		_reload_pawns()


func _on_alles_toggled(aan: bool) -> void:
	if aan and _formation_btn != null and _formation_btn.button_pressed:
		_formation_btn.set_pressed_no_signal(false)
	if aan and _legers_btn != null and _legers_btn.button_pressed:
		_legers_btn.set_pressed_no_signal(false)
	if aan:
		_bouw_alle_modellen()
	else:
		_clear_formation()
		_alles_modus = false
		_reload_pawns()


## ALLES tegelijk: zes facties in RIJEN (naar achteren), en per rij vijftien
## kolommen -- infanterie base/spd/hp/atk/mix, dan cavalerie, dan artillerie.
## Negentig pionnen. Zo staat de muis-base naast de beer-base EN naast zijn eigen
## kanon, en zie je in een blik of de schaalverhoudingen kloppen.
##
## Waarom niet het type uit de dropdown (eerste versie, 7 september): dan zie je
## zes facties van EEN type, en zolang de meeste modellen nog niet geleverd zijn
## vallen die allemaal terug op hetzelfde placeholder-blokje. Dan lijkt het of je
## steeds hetzelfde model ziet -- precies wat Max meldde.
##
## Tussen de drie type-groepen zit een gaatje, anders is het een muur van vijftien
## en zie je niet waar de cavalerie begint.
##
## Bij "rood vs blauw" krijgt elke tweede factie-rij de andere jas; kies je
## "alles rood" of "alles blauw", dan draagt de hele opstelling die ene.
func _bouw_alle_modellen() -> void:
	_clear_formation()
	if _pawn != null and is_instance_valid(_pawn):
		_pawn.queue_free()
		_pawn = null
	if _ref != null and is_instance_valid(_ref):
		_ref.queue_free()
		_ref = null
	_alles_modus = true
	var facties: Array = Constants.DOCTRINE_DATA.keys()
	var kol := 1.15
	var gat := 0.7   # extra ruimte tussen infanterie | cavalerie | artillerie
	var rij := 1.7
	# Eerst de kolom-x'en uitrekenen, dan pas plaatsen: zo staat de hele rij
	# netjes gecentreerd, ook met de gaten ertussen.
	var kolom_x: Array = []
	var x := 0.0
	for tp in [0, 1, 2]:
		if tp > 0:
			x += gat
		for _ai in ARCHS.size():
			kolom_x.append(x)
			x += kol
	var breed: float = kolom_x[kolom_x.size() - 1]
	for i in kolom_x.size():
		kolom_x[i] = float(kolom_x[i]) - breed * 0.5
	for fi in facties.size():
		var k := 0
		for tp in [0, 1, 2]:
			for ai in ARCHS.size():
				var arch: String = ARCHS[ai]
				var card = null
				if ARCH_CARDS.has(arch):
					var st: Array = ARCH_CARDS[arch]
					card = Card.new(0, 0, 0, int(st[0]), int(st[1]), int(st[2]))
				var pv: PawnView = PAWN_SCENE.instantiate()
				pv.team = _team_voor(fi % 2)
				pv.position = Vector3(float(kolom_x[k]), 0.05,
					(float(fi) - (facties.size() - 1) * 0.5) * rij)
				add_child(pv)
				pv.face_dir(Vector2i(0, 1))  # allemaal naar de camera
				pv.set_unit_type(tp)
				pv.set_character(int(facties[fi]), tp, card)
				_formation_pawns.append({"pv": pv, "fac": int(facties[fi]), "tp": tp, "arch": arch})
				k += 1
	_info.text = "Alle modellen: %d pionnen. Rijen = %s (voor naar achter), kolommen = infanterie, cavalerie, artillerie, elk base/spd/hp/atk/mix. Een placeholder-blokje betekent dat dat model nog niet geleverd is." % [
		_formation_pawns.size(),
		", ".join(facties.map(func(d): return Constants.doctrine_name(int(d))))]
	_sync_sliders_from_tuning()
	_apply_camera()


## Het echte bord eronder (Board.tscn): tegels, bordmodel en zijn eigen licht.
## Het bord is 11x11 tegels van 1x0.1x1 met de Board-node op (-5, 0, -5), dus de
## oorsprong is de middelste tegel en het tegeloppervlak ligt op y = 0,05 -- net
## waar de tuner zijn pionnen al neerzet. Verschuiven hoeft dus niet.
##
## De camera van Board.tscn zetten we UIT, anders neemt die het beeld over van
## de tuner-camera. Het tuner-licht gaat omlaag zodat het bord-licht de sfeer
## bepaalt; uit zetten we het niet, want dan valt de voorkant van de modellen weg.
func _zet_bord(aan: bool) -> void:
	if _bord != null and is_instance_valid(_bord):
		_bord.queue_free()
		_bord = null
	if _tuner_vloer != null:
		_tuner_vloer.visible = not aan
	if not aan:
		if _tuner_light != null:
			_tuner_light.light_energy = 1.2
		return
	var scene: PackedScene = load("res://Board.tscn")
	if scene == null:
		push_warning("Board.tscn niet gevonden; bord-view overgeslagen")
		_bord_btn.set_pressed_no_signal(false)
		return
	_bord = scene.instantiate() as Node3D
	add_child(_bord)
	move_child(_bord, 0)  # onder de pionnen in de boom, telt niet voor 3D
	for cam in _bord.find_children("*", "Camera3D", true, false):
		(cam as Camera3D).current = false
	if _tuner_light != null:
		_tuner_light.light_energy = 0.55


func _bord_camera() -> Camera3D:
	if _bord == null or not is_instance_valid(_bord):
		return null
	for cam in _bord.find_children("*", "Camera3D", true, false):
		return cam as Camera3D
	return null


func _legers_modus() -> bool:
	return _legers_btn != null and _legers_btn.button_pressed


## Bord-tegel (x, z) naar tuner-wereld: Board.tscn staat op (-5, 0, -5), dus
## tegel (5, 5) is de oorsprong en het tegeloppervlak ligt op y = 0,05.
func _tegel_positie(x: int, z: int) -> Vector3:
	return Vector3(float(x) - 5.0, 0.05, float(z) - 5.0)


## Bord + legers (16 september, Max: "voeg gewoon een bord toe met alle
## pionnen net als in het spel zelf... ik moet in het spel op het bord zien
## en tunen net als normaal in het spel"). Het echte Board.tscn eronder en
## beide legers in de standaard-opstelling van het spel: dezelfde regels
## (v42_default.json + het doctrines-blok), dezelfde
## GameState.default_placement, dezelfde tegels, rood (Vergelijk links,
## speler 1) op de rijen 9-10 kijkend naar -z, blauw op 0-1. De eerste
## infanterist per leger draagt het vaandel, de tweede de trom, zoals de
## opstelfase ze standaard aanwijst. De sliders tunen het model uit de
## dropdowns (factie + type; archetype base, want niemand is gekoppeld) en
## de duel-/charge-knoppen spelen op de ruiter of infanterist van die
## factie op het bord.
func _bouw_legers() -> void:
	_clear_formation()
	if _pawn != null and is_instance_valid(_pawn):
		_pawn.queue_free()
		_pawn = null
	if _ref != null and is_instance_valid(_ref):
		_ref.queue_free()
		_ref = null
	_alles_modus = false
	if not _bord_btn.button_pressed:
		_bord_btn.set_pressed(true)  # roept _zet_bord aan
	var regels := RulesConfig.load_from_file("res://arena/arena_configs/v42_default.json")
	var facties := CRules.facties_uit_bestand()
	if not facties.is_empty():
		regels.doctrines = facties
	var st := GameState.new()
	st.rules = regels
	st.doctrines[Constants.PLAYER_1] = _my_fac_btn.get_selected_id()
	st.doctrines[Constants.PLAYER_2] = _opp_fac_btn.get_selected_id()
	var totaal := 0
	for kant in 2:
		var speler: int = Constants.PLAYER_1 if kant == 0 else Constants.PLAYER_2
		var fac: int = st.doctrines[speler]
		var richting := Vector2i(0, -1) if kant == 0 else Vector2i(0, 1)
		var inf_nr := 0
		var inf_totaal := 0
		for pl in st.default_placement(speler):
			if int(pl.type) == Constants.UnitType.INFANTRY:
				inf_totaal += 1
		for pl in st.default_placement(speler):
			var tp: int = int(pl.type)
			var pos: Vector2i = pl.pos
			var pv: PawnView = PAWN_SCENE.instantiate()
			pv.team = _team_voor(kant)
			pv.position = _tegel_positie(pos.x, pos.y)
			if tp == Constants.UnitType.INFANTRY:
				pv.figurant_index = inf_nr
				pv.figurant_totaal = inf_totaal
				pv.rol_echt = "flag" if inf_nr == 0 else ("drum" if inf_nr == 1 else "")
				inf_nr += 1
			add_child(pv)
			pv.face_dir(richting)
			pv.set_unit_type(tp)
			pv.set_character(fac, tp, null)
			_formation_pawns.append({"pv": pv, "fac": fac, "tp": tp, "arch": "base",
				"kant": kant, "thuis": pv.position, "richting": richting})
			totaal += 1
	if _view_btn != null and _view_btn.selected != 3:
		_view_btn.select(3)
	_info.text = "Bord + legers: %s (rood, onder) tegen %s (blauw, boven), %d pionnen in de standaard-opstelling van het spel. Sliders tunen het model uit de dropdowns; duel/charge spelen op het bord." % [
		Constants.doctrine_name(st.doctrines[Constants.PLAYER_1]),
		Constants.doctrine_name(st.doctrines[Constants.PLAYER_2]), totaal]
	_sync_sliders_from_tuning()
	_apply_camera()


func _on_legers_toggled(aan: bool) -> void:
	if aan:
		if _formation_btn != null and _formation_btn.button_pressed:
			_formation_btn.set_pressed_no_signal(false)
		if _alles_btn != null and _alles_btn.button_pressed:
			_alles_btn.set_pressed_no_signal(false)
			_alles_modus = false
		_bouw_legers()
	else:
		_clear_formation()
		if _view_btn != null and _view_btn.selected == 3:
			_view_btn.select(0)
		_reload_pawns()
		_apply_camera()


## De aanvaller voor een duel-/charge-test: het losse tuning-model, of op
## het bord (en in een formatie) de pion die bij de dropdowns hoort (factie
## + type), liefst aan de rode kant. Retour {} als er geen is.
func _test_aanvaller() -> Dictionary:
	if _pawn != null and is_instance_valid(_pawn):
		return {"pv": _pawn, "thuis": Vector3(0.0, 0.05, 0.0), "richting": Vector2i(0, 1)}
	var fac := _fac_btn.get_selected_id()
	var tp := _type_btn.get_selected_id()
	var beste: Dictionary = {}
	for e in _formation_pawns:
		if not is_instance_valid(e.pv) or int(e.fac) != fac or int(e.tp) != tp:
			continue
		if beste.is_empty() or int(e.get("kant", 0)) < int(beste.get("kant", 0)):
			beste = e
	if beste.is_empty():
		return {}
	var pv: PawnView = beste.pv
	var thuis: Vector3 = beste.get("thuis", pv.position)
	# Formatie (geen bord): rood staat op +z en kijkt naar -z.
	var richting: Vector2i = beste.get("richting", Vector2i(0, -1) if pv.position.z > 0.0 else Vector2i(0, 1))
	return {"pv": pv, "thuis": thuis, "richting": richting}


## Een verse vijand op een plek, kijkend naar de aanvaller; hangt onder
## _duel_root en verdwijnt bij de volgende test.
func _test_verdediger(pos: Vector3, richting: Vector2i, aanv_team: int) -> PawnView:
	_duel_root = Node3D.new()
	add_child(_duel_root)
	var def_pv: PawnView = PAWN_SCENE.instantiate()
	def_pv.team = Constants.Team.RED if aanv_team == Constants.Team.BLUE else Constants.Team.BLUE
	def_pv.position = pos
	_duel_root.add_child(def_pv)
	def_pv.set_unit_type(_type_btn.get_selected_id())
	def_pv.set_character(_opp_fac_btn.get_selected_id(), _type_btn.get_selected_id(), null)
	def_pv.face_dir(-richting)
	return def_pv


# --- Sleepbare paneelhoogte -------------------------------------------------
# Max wil zelf bepalen hoeveel scherm het paneel pakt: veel bij het afstellen,
# weinig als hij het model wil zien. Bewaard in user://tuner_ui.cfg, want
# model_tuning.json is speldata die de engine leest -- daar hoort geen
# vensterstand in.

const UI_CFG := "user://tuner_ui.cfg"
const PANEEL_MIN := 130.0
const PANEEL_STANDAARD := 300.0
const PANEEL_COMPACT := 150.0

var _paneel: PanelContainer = null
var _paneel_hoogte: float = PANEEL_STANDAARD
var _sleept: bool = false


## De greep bovenaan het paneel: een dun balkje dat je op en neer sleept.
## Dubbelklik wisselt tussen compact en de laatst gebruikte hoogte.
func _maak_sleepgreep() -> Control:
	var greep := Panel.new()
	greep.custom_minimum_size = Vector2(0, 12)
	greep.mouse_default_cursor_shape = Control.CURSOR_VSIZE
	greep.tooltip_text = "Sleep omhoog of omlaag om het paneel groter of kleiner te maken (dubbelklik: compact)"
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.30, 0.35, 0.46, 1.0)
	st.set_corner_radius_all(3)
	st.content_margin_top = 0.0
	st.content_margin_bottom = 0.0
	greep.add_theme_stylebox_override("panel", st)
	greep.gui_input.connect(_op_greep_input)
	return greep


func _op_greep_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := e as InputEventMouseButton
		if mb.double_click:
			# Compact <-> ruim, zodat je met een dubbelklik het model vrij maakt.
			var doel: float = PANEEL_COMPACT if _paneel_hoogte > PANEEL_COMPACT + 20.0 else PANEEL_STANDAARD
			_zet_paneelhoogte(doel)
		_sleept = mb.pressed
	elif e is InputEventMouseMotion and _sleept:
		# Omhoog slepen = groter paneel, dus relative.y eraf halen.
		_zet_paneelhoogte(_paneel_hoogte - (e as InputEventMouseMotion).relative.y)


func _zet_paneelhoogte(h: float, bewaren: bool = true) -> void:
	if _paneel == null:
		return
	var scherm: float = float(get_viewport().get_visible_rect().size.y)
	# Nooit hoger dan 85% van het scherm: er moet altijd model zichtbaar blijven.
	_paneel_hoogte = clampf(h, PANEEL_MIN, maxf(PANEEL_MIN, scherm * 0.85))
	_paneel.offset_top = -_paneel_hoogte

	if bewaren:
		var cfg := ConfigFile.new()
		cfg.set_value("tuner", "paneel_hoogte", _paneel_hoogte)
		cfg.save(UI_CFG)


func _lees_paneelhoogte() -> float:
	var cfg := ConfigFile.new()
	if cfg.load(UI_CFG) != OK:
		return PANEEL_STANDAARD
	return float(cfg.get_value("tuner", "paneel_hoogte", PANEEL_STANDAARD))


## Eén thema voor het hele tunerpaneel: kleiner lettertype en vlakke knoppen.
## Op het paneel gezet, dus alles eronder erft het -- labels, knoppen,
## spinboxes en de tabbladen tegelijk. Scheelt een override per widget.
func _tuner_thema() -> Theme:
	var th := Theme.new()
	th.default_font_size = 12
	for soort in ["Button", "OptionButton", "CheckBox", "CheckButton", "Label",
			"SpinBox", "LineEdit", "TabContainer"]:
		th.set_font_size("font_size", soort, 12)
	var knop := StyleBoxFlat.new()
	knop.bg_color = Color(0.18, 0.20, 0.26, 1.0)
	knop.border_color = Color(0.34, 0.39, 0.52, 1.0)
	knop.set_border_width_all(1)
	knop.set_corner_radius_all(3)
	knop.content_margin_left = 8.0
	knop.content_margin_right = 8.0
	knop.content_margin_top = 3.0
	knop.content_margin_bottom = 3.0
	var hover: StyleBoxFlat = knop.duplicate()
	hover.bg_color = Color(0.24, 0.27, 0.35, 1.0)
	var druk: StyleBoxFlat = knop.duplicate()
	druk.bg_color = Color(0.13, 0.15, 0.20, 1.0)
	for soort in ["Button", "OptionButton"]:
		th.set_stylebox("normal", soort, knop)
		th.set_stylebox("hover", soort, hover)
		th.set_stylebox("pressed", soort, druk)
		th.set_stylebox("focus", soort, hover)
	return th

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
		_herbouw_huidige()  # formatie, alle modellen of bord + legers
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
	if on and _legers_btn != null and _legers_btn.button_pressed:
		_legers_btn.set_pressed_no_signal(false)
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
				pv.team = _team_voor(side)
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
	_ref.team = _team_voor(0)
	_ref.position = Vector3(-1.0, 0.05, 0.0)
	add_child(_ref)
	_ref.face_dir(Vector2i(0, 1))
	_ref.set_unit_type(unit_type)
	# Het echte model in het midden, via exact dezelfde route als in het spel.
	_pawn = PAWN_SCENE.instantiate()
	_pawn.team = _team_voor(1)
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
	_vul_geluidlijst()
	_refresh_info()
	_apply_camera()


## Vul het dood-clip menu met de die-varianten van het huidige model en
## laad de bijbehorende death_pools-waarden.
func _fill_die_options() -> void:
	_die_btn.clear()
	if _pawn != null and _pawn._anim != null:
		for v in _pawn._variants_of(_pawn.anim_die):
			var n := String(v)
			var kort := n.get_slice("/", n.get_slice_count("/") - 1)
			# Duur erbij (Max, 28 juli): handig om sterfgeluiden op te maken.
			var duur := 0.0
			if _pawn._anim.has_animation(n):
				duur = _pawn._anim.get_animation(n).length
			_die_btn.add_item("%s  (%.2fs)" % [kort, duur])
	_load_death_pool_values()


func _load_death_pool_values() -> void:
	if _die_btn.item_count == 0:
		return
	var clip := _die_btn.get_item_text(_die_btn.selected).get_slice("  (", 0)
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
	# Geluid-afstelling schrijft zichzelf al bij elke wijziging weg; hier nog
	# een keer, zodat OPSLAAN echt alles vastlegt.
	Audio.bewaar_geluid_tuning()
	_info.text = "Opgeslagen → model_tuning.json + effects_tuning.json + sound_tuning.json"


# --- Duel-test: bajonet-choreografie live afstemmen ---------------------------

var _duel_root: Node3D = null


## Verdediger (vergelijk-factie) verschijnt recht tegenover het model. De
## aanvaller draait (aanvaller-draai), stoot (stoot-tempo), de verdediger
## reageert op het raakmoment (val bij dood, terugdeins bij overleven) en bij
## een kill rukt de aanvaller na de opruk-vertraging op - exact dezelfde
## timing-route als in het spel.
func _on_duel_test(kill: bool) -> void:
	_interrupt_previews(true, _formation_pawns.is_empty())
	var a := _test_aanvaller()
	if a.is_empty():
		_info.text = "Duel: geen %s van %s op het bord; kies links een factie die meespeelt." % [
			Constants.unit_type_name(_type_btn.get_selected_id()), _fac_name()]
		return
	var aanv: PawnView = a.pv
	var richting: Vector2i = a.richting
	var stap := Vector3(float(richting.x), 0.0, float(richting.y))
	if aanv._anim != null:
		aanv._anim.stop()
	aanv.position = a.thuis
	var def_pv := _test_verdediger(aanv.position + stap, richting, aanv.team)
	# Aanvaller: exact dezelfde route als in het spel.
	aanv.face_dir(richting)
	aanv.rotate_y(deg_to_rad(aanv.melee_fx("yaw", "melee_yaw", 0.0)))
	aanv.play_melee()
	var gen := _preview_gen
	var hd: float = aanv.melee_fx("hit_delay", "melee_hit_delay", 0.55)
	get_tree().create_timer(hd).timeout.connect(func() -> void:
		if gen != _preview_gen or def_pv == null or not is_instance_valid(def_pv):
			return
		if kill:
			def_pv.play_death(stap, 0.7, "melee")
		else:
			def_pv.play_hit()
			def_pv.play_wound(stap))
	if kill:
		# Zelfde vaste timing als in het spel (Max, 30 juli): stoot-frame plus
		# opruk-vertraging, niet de lengte van de dood-clip.
		var move_del: float = hd + 2.0 * aanv.melee_fx("advance_delay", "melee_advance_delay", 0.35)
		get_tree().create_timer(move_del).timeout.connect(func() -> void:
			if gen != _preview_gen or aanv == null or not is_instance_valid(aanv):
				return
			aanv.play_walk()
			var tw := create_tween()
			tw.tween_property(aanv, "position", a.thuis + stap, 0.3)
			tw.tween_callback(func() -> void:
				if aanv != null and is_instance_valid(aanv):
					aanv.play_idle()))


## Charge-test (16 september, Max: "laat dan wel in de tuner een enemy zien
## en dan de aanval op gepaste afstand starten"): de verdediger staat recht
## voor het model, het model rijdt CHARGE_RIT vakken aan op de rush-clip
## (zelfde tween als game._animate_move), de sprong-clip begint
## charge_aanloop_vakken voor de aankomst en de klap valt
## charge_raak_voor_einde voor het einde van de sprong: exact de tijdlijn
## van het spel (PawnView.charge_tijdlijn). De info-regel meldt de tijden.
const CHARGE_RIT: int = 3

func _on_charge_test(kill: bool) -> void:
	_interrupt_previews(true, _formation_pawns.is_empty())
	var a := _test_aanvaller()
	if a.is_empty():
		_info.text = "Charge: geen %s van %s op het bord; kies links een factie die meespeelt." % [
			Constants.unit_type_name(_type_btn.get_selected_id()), _fac_name()]
		return
	var aanv: PawnView = a.pv
	var richting: Vector2i = a.richting
	var stap := Vector3(float(richting.x), 0.0, float(richting.y))
	if aanv._anim != null:
		aanv._anim.stop()
	# Los model: de rit eindigt op de thuistegel (zodat hij in beeld blijft);
	# op het bord vertrekt hij van zijn eigen vak en rijdt hij het veld in.
	var start: Vector3 = a.thuis - stap * float(CHARGE_RIT) if _formation_pawns.is_empty() else a.thuis
	var aankomst: Vector3 = start + stap * float(CHARGE_RIT)
	var def_pv := _test_verdediger(aankomst + stap, richting, aanv.team)
	aanv.position = start
	aanv.face_dir(richting)
	var tl: Dictionary = aanv.charge_tijdlijn(CHARGE_RIT)
	var gen := _preview_gen
	# De rit: rush-clip en dezelfde sine-tween als in het spel; aan het eind
	# geen idle, de sprong loopt dan nog en keert zelf terug.
	aanv.play_rush()
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(aanv, "position", aankomst, float(tl.rij_dur))
	var start_sprong := func() -> void:
		if gen != _preview_gen or aanv == null or not is_instance_valid(aanv):
			return
		aanv.face_dir(richting)
		aanv.play_charge()
	if float(tl.sprong_start) <= 0.0:
		start_sprong.call()
	else:
		get_tree().create_timer(float(tl.sprong_start)).timeout.connect(start_sprong)
	get_tree().create_timer(float(tl.klap_del)).timeout.connect(func() -> void:
		if gen != _preview_gen or def_pv == null or not is_instance_valid(def_pv):
			return
		if kill:
			def_pv.play_death(stap, 0.85 + 0.4, "charge")  # sabel: doormidden (16 september)
		else:
			def_pv.flash_hit()
			def_pv.stagger(stap)
			def_pv.play_hit()
			def_pv.play_wound(stap))
	var sprong_txt := "%.2f s" % float(tl.sprong_duur) if float(tl.sprong_duur) > 0.0 else "geen sprong-clip, melee-stoot"
	_info.text = "charge: rit %d vakken in %.2f s, sprong start op %.2f s (%s), klap op %.2f s" % [
		CHARGE_RIT, float(tl.rij_dur), float(tl.sprong_start), sprong_txt, float(tl.klap_del)]


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
	var was_modus := _sleep_modus
	_sleep_verplaats(muis, true)
	# BUG-FIX (Max, 30 juli: "als ik opsla slaat hij niet op hoe de musket nu
	# zit"). Tijdens het slepen zetten we de spinboxen STIL bij (geen signaal,
	# anders bouwt hij bij elke muisbeweging het model opnieuw op). Bij
	# loslaten zetten we dezelfde waarde nog eens "met signaal" -- maar Godot
	# stuurt value_changed niet als het getal al klopt, dus de schrijfactie
	# bleef uit en OPSLAAN bewaarde de OUDE stand. Daarom schrijven we hier
	# expliciet weg.
	if was_modus == "hand":
		_on_weapon_changed(0.0)
	elif was_modus == "vuurmond":
		_on_muzzle_changed(0.0)
	_sleep_as = -1
	_sleep_draaien = false
	_sleep_modus = ""


# =========================================================================
# Geluid-tab: horen wat er bij dit model hoort (Max, 28 juli)
# =========================================================================

## Categorieen die bij het huidige model horen, in speelvolgorde.
func _geluid_rijen() -> Array:
	var fac := _fac_name()
	var tp: int = _type_btn.get_selected_id()
	var rijen: Array = []
	if tp == Constants.UnitType.INFANTRY:
		rijen.append({"cat": "musket_fire", "wat": "musket afvuren"})
		rijen.append({"cat": "musket_hit", "wat": "kogel slaat in"})
		rijen.append({"cat": "inf_die_" + fac, "wat": "doodskreet (factie)", "terugval": "inf_die"})
		rijen.append({"cat": "inf_kanon_die_" + fac, "wat": "kreet bij kanontreffer", "terugval": "inf_die_" + fac})
	elif tp == Constants.UnitType.CAVALRY:
		rijen.append({"cat": "charge_yell", "wat": "charge"})
		rijen.append({"cat": "horse_die_" + fac, "wat": "doodskreet (factie)", "terugval": "horse_die"})
	else:
		rijen.append({"cat": "cannon_fire", "wat": "kanon afvuren"})
		rijen.append({"cat": "cannon_hit", "wat": "inslag"})
		rijen.append({"cat": "cannon_die_" + fac, "wat": "vernietigd (factie)", "terugval": "cannon_die"})
		rijen.append({"cat": "cannon_wheel_loose", "wat": "wiel schiet los (60%)"})
	rijen.append({"cat": "body_hit_floor", "wat": "lijf raakt de grond"})
	if tp == Constants.UnitType.INFANTRY or tp == Constants.UnitType.CAVALRY:
		# Zelfde regel als het spel (PawnView.val_categorie_voor) -- nooit
		# een eigen kopie van de categorie-keuze (audit 30 juli); cavalerie
		# krijgt zo vanzelf val_melee (sabel/bijl die uit de handen valt).
		var rol := _hand_rol() if tp == Constants.UnitType.INFANTRY else ""
		var vc := PawnView.val_categorie_voor(tp, rol)
		rijen.append({"cat": vc, "wat": "voorwerp valt", "terugval": "val_prop"})
	if tp == Constants.UnitType.INFANTRY:
		rijen.append({"cat": "val_hoed", "wat": "hoedje valt"})
	rijen.append({"cat": "blood_splash", "wat": "bloedspat"})
	# Materiaal-laag: exact de categorie die het spel voor DIT model kiest,
	# plus de twee losse gevallen (botbreuk bij een dodelijke klap, afketser
	# als er geen schade valt).
	var mat := PawnView.impact_categorie(tp, ARCHS[_arch_btn.selected])
	rijen.append({"cat": mat, "wat": "treffer op dit model"})
	rijen.append({"cat": "impact_bone", "wat": "botbreuk (dodelijke klap)"})
	rijen.append({"cat": "ricochet", "wat": "afketser (schot overleefd)"})
	return rijen


func _vul_geluidlijst() -> void:
	if _snd_lijst == null:
		return
	for kind in _snd_lijst.get_children():
		kind.queue_free()
	for rij in _geluid_rijen():
		var cat := String(rij["cat"])
		var aantal: int = Audio.variant_aantal(cat)
		var terugval := String(rij.get("terugval", ""))
		# Wat het SPEL zou spelen (incl. lenen van de muis): zo hoor je in de
		# tuner exact hetzelfde als op het bord.
		var doc: int = _fac_btn.get_selected_id()
		var arch: String = ARCHS[_arch_btn.selected]
		var echt := Audio.effectieve_categorie(cat, doc, terugval, arch)
		var valt_terug := aantal == 0 and echt != "" and echt != cat
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		var knop := Button.new()
		knop.text = "\u25B6 %s" % String(rij["wat"])
		knop.custom_minimum_size = Vector2(210, 0)
		knop.disabled = echt == ""
		var speel_cat := echt if echt != "" else cat
		knop.pressed.connect(func() -> void: Audio.play(speel_cat))
		hb.add_child(knop)
		# Volume en vertraging per categorie: meteen te horen met de speelknop,
		# en opgeslagen in sounds/sound_tuning.json.
		hb.add_child(_make_label(" dB"))
		var db_spin := _make_spin(hb, -24.0, 12.0, 0.5, Audio.volume_correctie(speel_cat),
			func(_v: float) -> void: pass)
		var basis := Audio.basis_vertraging(speel_cat)
		hb.add_child(_make_label(" vertraging (basis %.2fs) " % basis))
		var vt_spin := _make_spin(hb, -2.0, 3.0, 0.01, Audio.extra_vertraging(speel_cat),
			func(_v: float) -> void: pass)
		var bewaar := func(_v: float) -> void:
			if _updating:
				return
			Audio.zet_geluid_tuning(speel_cat, db_spin.value, vt_spin.value)
		db_spin.value_changed.connect(bewaar)
		vt_spin.value_changed.connect(bewaar)
		var info := Label.new()
		info.add_theme_font_size_override("font_size", 12)
		if aantal > 0:
			info.text = "%s  -  %d variant(en), %.2fs" % [cat, aantal, Audio.langste_duur(cat)]
			info.add_theme_color_override("font_color", Color(0.75, 0.85, 0.78))
		elif valt_terug:
			var reden := "leent van de muis" if echt.contains("_mouse") else "valt terug"
			info.text = "%s ontbreekt  -  %s: %s (%d var, %.2fs)" % [
				cat, reden, echt, Audio.variant_aantal(echt), Audio.langste_duur(echt)]
			info.add_theme_color_override("font_color", Color(0.85, 0.8, 0.55))
		else:
			info.text = "%s  -  geen bestand" % cat
			info.add_theme_color_override("font_color", Color(0.6, 0.58, 0.6))
			db_spin.editable = false
			vt_spin.editable = false
		hb.add_child(info)
		_snd_lijst.add_child(hb)

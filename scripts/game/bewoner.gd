class_name Bewoner
extends Node3D

## Een klein 3D-poppetje in het diorama om het bord (8 september, Max: "kan
## jij dat bijv als ik een peasant_mouse aanlever die bij hout hakt als je om
## hem drukt"). Laadt een glb met clips uit assets/models/bewoners/, laat een
## idle-clip lopen en speelt bij een klik een ACTIE-clip een keer, met
## geluid als er een categorie voor ligt. Daarna weer idle.
##
## De regel voor de maker is dezelfde als bij de pionnen: clipnamen gaan door
## PawnView.CLIP_WOORDEN ("Idle 2" is idle, "Death 1" is die). Alles wat het
## spel NIET kent (Chopping, Axe swing, Cheer, Drink) is een actie. Idle,
## walk, die, hit, rush en charge zijn dat nooit. Geen idle-clip = het
## poppetje staat stil; geen actie-clip = een huppeltje bij een klik.
##
## De factie komt uit een woord in de naam: peasant_mouse is van Muis en
## verschijnt alleen in het kamp van wie Muis speelt (vooraan bij jou,
## aan de overkant bij de tegenstander). Zonder factiewoord staat hij er
## altijd. Manifest (<naam>.json naast de glb, alles optioneel): zie
## assets/models/bewoners/LEESMIJ.md.

const BEWONERS_DIR := "res://assets/models/bewoners"
const MODELS_DIR := "res://assets/models"
const GEEN_ACTIE: Array = ["idle", "walk", "die", "hit", "rush", "charge"]
const FACTIEWOORDEN: Dictionary = {
	"mouse": Constants.Doctrine.MUIS, "muis": Constants.Doctrine.MUIS,
	"pig": Constants.Doctrine.MENS, "varken": Constants.Doctrine.MENS, "mens": Constants.Doctrine.MENS,
	"lion": Constants.Doctrine.LEEUW, "leeuw": Constants.Doctrine.LEEUW,
	"bear": Constants.Doctrine.BEER, "beer": Constants.Doctrine.BEER,
	"wolf": Constants.Doctrine.WOLF,
	"croc": Constants.Doctrine.VOS, "crocodile": Constants.Doctrine.VOS,
	"krokodil": Constants.Doctrine.VOS, "vos": Constants.Doctrine.VOS,
}

signal actie_klaar

var naam := ""
var manifest: Dictionary = {}
var factie: int = -1          # Constants.Doctrine, -1 = voor iedereen
var hoogte := 0.62            # meters op het bord; de glb wordt hierop geschaald
var bezig := false
var _anim: AnimationPlayer = null
var _model: Node3D = null
var _idles: Array = []
var _acties: Array = []
var _geluid: Array = []
var _geluid_moment := 0.0
var _rng := RandomNumberGenerator.new()   # nooit de globale RNG (zie Omgeving)
var kamp_team := ""            # kleur van het kamp waarin hij staat ("red"/"blue"), voor de cape
var _cape: MeshInstance3D = null


## Alle namen die in assets/models/bewoners/ liggen: een glb, of een json
## die met "model" naar een glb elders wijst (zo kan een bestaand model
## meedoen zonder kopie).
static func alle_namen() -> Array:
	var namen: Dictionary = {}
	for f in Bestandsindex.alles(BEWONERS_DIR, ".glb"):
		namen[String(f).get_basename()] = true
	for f in Bestandsindex.alles(BEWONERS_DIR, ".json"):
		namen[String(f).get_basename()] = true
	var uit: Array = namen.keys()
	uit.sort()
	return uit


static func lees_manifest(n: String) -> Dictionary:
	var pad := Bestandsindex.vind(BEWONERS_DIR, n + ".json")
	if pad == "":
		return {}
	var f := FileAccess.open(pad, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	return data if data is Dictionary else {}


static func factie_uit_woord(tekst: String) -> int:
	for w in tekst.to_lower().replace("-", "_").split("_"):
		if FACTIEWOORDEN.has(w):
			return FACTIEWOORDEN[w]
	return -1


static func factie_van(n: String, m: Dictionary) -> int:
	if m.has("factie"):
		return factie_uit_woord(String(m.factie))
	return factie_uit_woord(n)


## Teamwoord in de naam (peasant_mouse_red): "red", "blue" of "" (elk team).
## Rood is het arme kamp, blauw het rijke (PROP-WISHLIST.md).
static func team_uit_woord(tekst: String) -> String:
	for w in tekst.to_lower().replace("-", "_").split("_"):
		if w == "red" or w == "rood":
			return "red"
		if w == "blue" or w == "blauw":
			return "blue"
	return ""


static func team_van(n: String, m: Dictionary) -> String:
	if m.has("team"):
		return team_uit_woord(String(m.team))
	return team_uit_woord(n)


func laad(n: String) -> bool:
	_rng.randomize()
	naam = n
	name = "Bewoner_" + n
	manifest = lees_manifest(n)
	factie = factie_van(n, manifest)
	hoogte = float(manifest.get("hoogte", 0.62))
	var modelnaam := String(manifest.get("model", n))
	var pad := Bestandsindex.vind(BEWONERS_DIR, modelnaam + ".glb")
	if pad == "":
		pad = Bestandsindex.vind(MODELS_DIR, modelnaam + ".glb")
	if pad == "" or not ResourceLoader.exists(pad):
		push_warning("Bewoner %s: geen %s.glb gevonden" % [n, modelnaam])
		return false
	var ps: PackedScene = load(pad)
	if ps == null:
		return false
	_model = ps.instantiate() as Node3D
	if _model == null:
		return false
	add_child(_model)
	# maat: op hoogte schalen, voeten op de grond (elk generator-model heeft
	# zijn eigen maat; de pionnen lossen dat op in de tuner, hier automatisch)
	var aabb := _aabb_van(_model)
	if aabb.size.y > 0.0001:
		var s := hoogte / aabb.size.y * float(manifest.get("schaal", 1.0))
		_model.scale = Vector3(s, s, s)
		_model.position.y = -aabb.position.y * s
	_model.rotation.y = deg_to_rad(float(manifest.get("draai_model", 0.0)))
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var g = manifest.get("geluid", [])
	_geluid = [String(g)] if g is String else Array(g)
	_geluid_moment = float(manifest.get("geluid_moment", 0.0))
	_anim = _zoek_anim(_model)
	_eigen_clips()
	_sorteer_clips()
	if _anim != null:
		_anim.animation_finished.connect(_on_klaar)
		_speel_idle()
	return true


## Cape in de kleur van het kamp waarin hij staat (Omgeving zet dit na het
## plaatsen; 12 september, Max: "alle blauwe team karakters een blauwe
## cape"). Dezelfde lap als de pionnen (PawnView.maak_cape), dus dezelfde
## knoppen in het sfeer-paneel; standaard alleen blauw.
func zet_cape(team: String) -> void:
	kamp_team = team
	PawnView.cape_weg(_cape)
	_cape = null
	if _model == null or not is_inside_tree():
		return
	var aan := false
	if team == "blue":
		aan = PawnView.fx("cape_blauw", 1.0) > 0.5
	elif team == "red":
		aan = PawnView.fx("cape_rood", 0.0) > 0.5
	if not aan:
		return
	_cape = PawnView.maak_cape(_model, hoogte, team == "blue", naam.hash())


func _process(delta: float) -> void:
	if _cape != null:
		if is_instance_valid(_cape):
			PawnView.cape_process(_cape, delta)
		else:
			_cape = null


## Eigen kopie van de animatiebibliotheken, met de clipnamen van het spel.
## Waarom: alle instanties van een glb delen hun AnimationLibrary en hun
## Animation-objecten. PawnView hernoemt daarin de vuile Mixamo-namen
## ("Idle  2" -> idle1) zodra de eerste pion van dat model verschijnt, en zet
## loop-modes op de clips. Een bewoner die op hetzelfde model draait (zoals
## soldaat_mouse op de muis-infanterist) speelde dan een clip die onder hem
## verdween: segfault, 4 s na de start van een potje (8 september). Met een
## diepe kopie raakt niemand elkaar; de hernoeming hier is dezelfde als in
## PawnView._normaliseer_clipnamen, zodat de namen overal gelijk zijn.
func _eigen_clips() -> void:
	if _anim == null:
		return
	for lib_naam in _anim.get_animation_library_list():
		var lib: AnimationLibrary = _anim.get_animation_library(lib_naam)
		if lib == null:
			continue
		var kopie: AnimationLibrary = lib.duplicate(true)
		_anim.remove_animation_library(lib_naam)
		_anim.add_animation_library(lib_naam, kopie)
		var teller: Dictionary = {}
		for a in kopie.get_animation_list():
			var n := String(a)
			if not PawnView._schone_clipnaam(n):
				continue
			var basis := n.rstrip("0123456789")
			var rest := n.substr(basis.length())
			teller[basis] = maxi(int(teller.get(basis, 0)), int(rest) if rest.is_valid_int() else 1)
		for a in kopie.get_animation_list():
			var n := String(a)
			if PawnView._schone_clipnaam(n):
				continue
			var doel := PawnView._clip_doelnaam(n)
			if doel == "":
				continue
			var idx: int = int(teller.get(doel, 0)) + 1
			teller[doel] = idx
			var nieuw := "%s%d" % [doel, idx]
			if not kopie.has_animation(nieuw):
				kopie.rename_animation(a, nieuw)


## Deelt deze bewoner nog clips met een andere instantie van hetzelfde glb?
## (bewonercheck) Waar = fout: dan kan een pion zijn clip onder hem weghalen.
func deelt_clips_met(ander: AnimationPlayer) -> bool:
	if _anim == null or ander == null:
		return false
	for lib_naam in _anim.get_animation_library_list():
		var mijn: AnimationLibrary = _anim.get_animation_library(lib_naam)
		var zijn: AnimationLibrary = ander.get_animation_library(lib_naam)
		if zijn == null:
			continue
		if mijn == zijn:
			return true
		for a in mijn.get_animation_list():
			for b in zijn.get_animation_list():
				if mijn.get_animation(a) == zijn.get_animation(b):
					return true
	return false


func idles() -> Array:
	return _idles.duplicate()


func acties() -> Array:
	return _acties.duplicate()


func speelt_idle() -> bool:
	return _anim != null and _anim.is_playing() and _idles.has(_anim.current_animation)


## Speelt een actie-clip (willekeurig als er meer zijn). Onwaar als hij al
## bezig is of geen actie-clip heeft.
func doe_actie() -> bool:
	if bezig or _anim == null or _acties.is_empty():
		return false
	bezig = true
	var clip: String = _acties[_rng.randi() % _acties.size()]
	_anim.get_animation(clip).loop_mode = Animation.LOOP_NONE
	_anim.play(clip, 0.15)
	if not _geluid.is_empty():
		if _geluid_moment > 0.0:
			get_tree().create_timer(_geluid_moment).timeout.connect(_speel_geluid)
		else:
			_speel_geluid()
	return true


func _on_klaar(anim_naam: StringName) -> void:
	# Niet vanuit het animation_finished-signaal zelf een nieuwe clip starten
	# (met blend): uitgesteld naar het einde van het frame.
	if _acties.has(String(anim_naam)):
		bezig = false
		_speel_idle.call_deferred()
		actie_klaar.emit()
	elif _idles.has(String(anim_naam)):
		_speel_idle.call_deferred()


func _speel_idle() -> void:
	if _anim == null or _idles.is_empty():
		return
	var clip: String = _idles[_rng.randi() % _idles.size()]
	# idle loopt door; met meer idles wisselen we per einde (om en om), dus
	# geen LOOP_LINEAR: dan zou animation_finished nooit komen
	_anim.get_animation(clip).loop_mode = Animation.LOOP_NONE if _idles.size() > 1 else Animation.LOOP_LINEAR
	_anim.play(clip, 0.3)


func _speel_geluid() -> void:
	for cat in _geluid:
		if Audio.variant_aantal(String(cat)) > 0:
			Audio.play(String(cat))
			return


## idle-clips en actie-clips uit elkaar halen, met dezelfde woordenlijst als
## de pionnen; manifest "idle" (een clipnaam) en "acties" (doelnamen of
## clipnamen) mogen het overrulen.
func _sorteer_clips() -> void:
	_idles.clear()
	_acties.clear()
	if _anim == null:
		return
	var wil: Array = Array(manifest.get("acties", []))
	for a in _anim.get_animation_list():
		var vol := String(a)
		var kort := vol.get_slice("/", vol.get_slice_count("/") - 1)
		var doel := doel_van(kort)
		if doel == "idle":
			_idles.append(vol)
		elif GEEN_ACTIE.has(doel):
			continue
		elif wil.is_empty() or wil.has(doel) or wil.has(kort) or wil.has(vol):
			_acties.append(vol)
	var idle_naam := String(manifest.get("idle", ""))
	if idle_naam != "" and _anim.has_animation(idle_naam):
		_idles = [idle_naam]
	# geen idle herkend maar wel clips: de eerste clip die geen actie is,
	# anders de eerste actie als "idle" (beter dan een bevroren T-pose)
	if _idles.is_empty() and _anim.get_animation_list().size() > 0:
		var lijst: Array = _anim.get_animation_list()
		for a in lijst:
			if not _acties.has(String(a)):
				_idles.append(String(a))
				break
		if _idles.is_empty():
			_idles.append(String(lijst[0]))
			_acties.erase(String(lijst[0]))


## De naam die het spel van een clip maakt: schone namen op hun basis
## (idle2 -> idle, chop -> chop), vuile Mixamo-namen door de woordenlijst
## ("Idle 2" -> idle, "Death 1" -> die), onbekend = "" = een actie.
static func doel_van(kort: String) -> String:
	if PawnView._schone_clipnaam(kort):
		var basis := kort.rstrip("0123456789")
		return basis if basis != "" else kort
	return PawnView._clip_doelnaam(kort)


static func _zoek_anim(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for kind in node.get_children():
		var gevonden := _zoek_anim(kind)
		if gevonden != null:
			return gevonden
	return null


static func _aabb_van(root: Node3D) -> AABB:
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

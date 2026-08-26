# Wapen-check (16 augustus): licht alle infanterie- EN cavalerie-modellen
# door voor het ingebakken-wapen-systeem. Per model:
#   - draagt het een INGEBAKKEN wapen-mesh (zelfde naam-regels als pawn_view)?
#   - beweegt dat mesh mee (geskind onder Skeleton3D of via BoneAttachment3D)?
#   - heeft het een eigen albedo-texture (anders wordt het een grijs blok)?
#   - zit er een wapen in de _gibs.glb (mag NIET: dubbel vliegend wapen)?
#   - ligt er een losse wapen-glb voor de doodsworp (musket / melee)?
# Een ONTBREKEND cavalerie-model is geen fout (nog niet elke factie is
# gegenereerd); een ontbrekend infanterie-model wel (die set is compleet).
# Draaien (NA --import, geen autoloads nodig):
#   <godot> --headless --path . --script tools/_wapencheck.gd
extends SceneTree

const LIJF_DELEN: Array = ["arm", "forarm", "leg", "upleg", "body", "head", "hat", "tail", "foot"]
const WAPEN_WOORDEN: Array = ["musket", "rifle", "gun", "weapon", "triponode",
	"sabre", "saber", "sword", "axe", "lance", "pike", "spear", "cutlass",
	"scythe", "hatchet", "falchion", "dagger"]
const FACTIES: Array = ["mouse", "pig", "lion", "bear", "wolf", "crocodile"]
const ARCHS: Array = ["base", "spd", "hp", "atk", "mix"]

var fouten := 0
var met_wapen := 0
var prop_route := 0
var ontbreekt_cav := 0


static func kale_naam(n: String) -> String:
	var uit := ""
	for teken in n.to_lower():
		if teken >= "a" and teken <= "z":
			uit += teken
	return uit


static func is_wapen_naam(n: String) -> bool:
	var kaal := kale_naam(n)
	for deel in LIJF_DELEN:
		if kaal.contains(String(deel)):
			return false
	for woord in WAPEN_WOORDEN:
		if kaal.contains(String(woord)):
			return true
	return false


static func zoek_bestand(map: String, naam: String) -> String:
	# Recursief op bestandsnaam zoeken (mini-versie van Bestandsindex).
	var dir := DirAccess.open(map)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var sub: Array = []
	while true:
		var f := dir.get_next()
		if f == "":
			break
		if dir.current_is_dir():
			if not f.begins_with("."):
				sub.append(map + "/" + f)
		elif f == naam:
			return map + "/" + f
	dir.list_dir_end()
	for s in sub:
		var r := zoek_bestand(String(s), naam)
		if r != "":
			return r
	return ""


static func wapen_info(scene_pad: String) -> Dictionary:
	if not ResourceLoader.exists(scene_pad):
		return {"bestaat": false}
	var ps: PackedScene = load(scene_pad)
	if ps == null:
		return {"bestaat": false}
	var root := ps.instantiate()
	var wapens: Array = []
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		if not is_wapen_naam(String(mi.name)):
			continue
		# Meebewegen kan op twee manieren: geskind (mesh direct onder het
		# Skeleton3D) of bot-geparent (BoneAttachment3D in de ouder-keten).
		var beweegt: bool = mi.get_parent() is Skeleton3D
		var n: Node = mi.get_parent()
		while n != null and not beweegt:
			if n is BoneAttachment3D:
				beweegt = true
			n = n.get_parent()
		var tex := false
		var m: Material = null
		if (mi as MeshInstance3D).mesh != null and (mi as MeshInstance3D).mesh.get_surface_count() > 0:
			m = (mi as MeshInstance3D).get_active_material(0)
		if m is BaseMaterial3D and (m as BaseMaterial3D).albedo_texture != null:
			tex = true
		wapens.append({"naam": String(mi.name), "beweegt": beweegt, "texture": tex})
	root.free()
	return {"bestaat": true, "wapens": wapens}


func check_model(tsoort: String, fac: String, arch: String) -> void:
	var basis := "res://assets/models/" + fac
	var model := ""
	for naam in ["%s_%s.glb" % [tsoort, arch], "%s_%s_%s.glb" % [tsoort, arch, fac]]:
		model = zoek_bestand(basis, String(naam))
		if model != "":
			break
	if model == "":
		if tsoort == "infantry":
			print("%s %s/%s: GEEN MODEL" % [tsoort, fac, arch])
			fouten += 1
		else:
			ontbreekt_cav += 1
		return
	var info := wapen_info(model)
	var regel := "%s %s/%s: " % [tsoort, fac, arch]
	var wapens: Array = info.get("wapens", [])
	if wapens.is_empty():
		regel += "geen ingebakken wapen (prop-route)"
		prop_route += 1
	else:
		met_wapen += 1
		for w in wapens:
			regel += "%s beweegt-mee=%s texture=%s  " % [w["naam"], w["beweegt"], w["texture"]]
			if not bool(w["beweegt"]):
				regel += "!! BEWEEGT NIET MEE "
				fouten += 1
			if not bool(w["texture"]):
				regel += "!! GEEN TEXTURE "
				fouten += 1
	# Gibs: mag GEEN wapen bevatten.
	var gibs_pad := model.get_basename() + "_gibs.glb"
	var gi := wapen_info(gibs_pad)
	if bool(gi.get("bestaat", false)):
		var gw: Array = gi.get("wapens", [])
		if not gw.is_empty():
			regel += "!! WAPEN IN GIBS: "
			for w in gw:
				regel += String(w["naam"]) + " "
			fouten += 1
	else:
		regel += "(geen gibs) "
	# Losse wapen-glb voor de doodsworp: musket bij infanterie, melee bij
	# de big bro (zelfde zoekvolgorde als weapon_for in pawn_view).
	var soort := "melee" if tsoort == "cavalry" else "musket"
	var worp := ""
	var mbasis: String = model.get_file().get_basename()
	for ext in [".glb", ".fbx"]:
		worp = zoek_bestand(basis, mbasis + "_" + soort + ext)
		if worp != "":
			break
	if worp == "":
		for ext in [".glb", ".fbx"]:
			worp = zoek_bestand(basis, soort + ext)
			if worp != "":
				break
	if worp == "":
		regel += "!! GEEN WORP-WAPEN"
		fouten += 1
	print(regel)


func _init() -> void:
	for tsoort in ["infantry", "cavalry"]:
		for fac in FACTIES:
			for arch in ARCHS:
				check_model(String(tsoort), String(fac), String(arch))
	print("---")
	print("SAMENVATTING: %d met ingebakken wapen, %d prop-route, %d cavalerie nog niet geleverd, %d fouten" % [met_wapen, prop_route, ontbreekt_cav, fouten])
	print("WAPENCHECK " + ("PASS" if fouten == 0 else "FAIL"))
	quit(0 if fouten == 0 else 1)

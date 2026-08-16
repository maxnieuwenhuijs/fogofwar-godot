# Wapen-check (16 augustus): licht alle infanterie-modellen door voor het
# ingebakken-musket-systeem. Per model:
#   - draagt het een INGEBAKKEN wapen-mesh (zelfde naam-regels als pawn_view)?
#   - is dat mesh geskind (kind van een Skeleton3D — anders beweegt het niet mee)?
#   - heeft het een eigen albedo-texture (anders wordt het een grijs blok)?
#   - zit er een wapen in de _gibs.glb (mag NIET: dubbel vliegend musket)?
#   - ligt er een losse musket-glb/fbx voor de doodsworp?
# Draaien (NA --import, geen autoloads nodig):
#   <godot> --headless --path . --script tools/_wapencheck.gd
extends SceneTree

const LIJF_DELEN: Array = ["arm", "forarm", "leg", "upleg", "body", "head", "hat", "tail", "foot"]
const FACTIES: Array = ["mouse", "pig", "lion", "bear", "wolf", "crocodile"]
const ARCHS: Array = ["base", "spd", "hp", "atk", "mix"]


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
	return kaal.contains("musket") or kaal.contains("rifle") or kaal.contains("gun") or kaal.contains("weapon") or kaal.contains("triponode")


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
		var geskind: bool = mi.get_parent() is Skeleton3D
		var n: Node = mi.get_parent()
		while n != null and not geskind:
			if n is BoneAttachment3D:
				geskind = true
			n = n.get_parent()
		var tex := false
		var m: Material = null
		if (mi as MeshInstance3D).mesh != null and (mi as MeshInstance3D).mesh.get_surface_count() > 0:
			m = (mi as MeshInstance3D).get_active_material(0)
		if m is BaseMaterial3D and (m as BaseMaterial3D).albedo_texture != null:
			tex = true
		wapens.append({"naam": String(mi.name), "geskind": geskind, "texture": tex})
	root.free()
	return {"bestaat": true, "wapens": wapens}


func _init() -> void:
	var fouten := 0
	var met_musket := 0
	var prop_route := 0
	for fac in FACTIES:
		for arch in ARCHS:
			var basis := "res://assets/models/" + String(fac)
			var model := ""
			for naam in ["infantry_%s.glb" % arch, "infantry_%s_%s.glb" % [arch, fac]]:
				model = zoek_bestand(basis, String(naam))
				if model != "":
					break
			if model == "":
				print("%s/%s: GEEN MODEL" % [fac, arch])
				fouten += 1
				continue
			var info := wapen_info(model)
			var regel := "%s/%s: " % [fac, arch]
			var wapens: Array = info.get("wapens", [])
			if wapens.is_empty():
				regel += "geen ingebakken wapen (prop-route)"
				prop_route += 1
			else:
				met_musket += 1
				for w in wapens:
					regel += "%s beweegt-mee=%s texture=%s  " % [w["naam"], w["geskind"], w["texture"]]
					if not bool(w["geskind"]):
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
			# Losse musket voor de doodsworp.
			var worp := ""
			var mbasis: String = model.get_file().get_basename()
			for ext in [".glb", ".fbx"]:
				worp = zoek_bestand(basis, mbasis + "_musket" + ext)
				if worp != "":
					break
			if worp == "":
				for ext in [".glb", ".fbx"]:
					worp = zoek_bestand(basis, "musket" + ext)
					if worp != "":
						break
			if worp == "":
				regel += "!! GEEN WORP-MUSKET"
				fouten += 1
			print(regel)
	print("---")
	print("SAMENVATTING: %d met ingebakken musket, %d prop-route, %d fouten" % [met_musket, prop_route, fouten])
	print("WAPENCHECK " + ("PASS" if fouten == 0 else "FAIL"))
	quit(0 if fouten == 0 else 1)

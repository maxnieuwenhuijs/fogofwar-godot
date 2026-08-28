extends SceneTree

# Gib-controle (15 augustus, verbreed 26 augustus): staan de gib-delen van
# ALLE modellen (infanterie EN cavalerie) echt LOS en op hun plek? Per
# gibs-bestand:
#   - aantal delen (1 mesh = geen losse delen = kapotte export)
#   - stapel-detectie: delen op exact dezelfde plek = kapotte export
#   - verticale spreiding (kop hoort boven de benen)
#   - naam-dekking via KALE namen (zoals het spel matcht): arml/armr/legl/
#     legr/body/head moeten vindbaar zijn, anders schiet er nooit een
#     ledemaat af (_shed_parts) en faalt de enkele-gib-worp.
# Draaien (NA import): <godot> --headless --path . --script tools/_gibcheck.gd
const FACTIES: Array = ["mouse", "pig", "lion", "bear", "wolf", "crocodile"]
const ARCHS: Array = ["base", "spd", "hp", "atk", "mix"]
const DELEN_VERPLICHT: Array = ["arml", "armr", "legl", "legr", "body", "head"]


static func kale_naam(n: String) -> String:
	var uit := ""
	for teken in n.to_lower():
		if teken >= "a" and teken <= "z":
			uit += teken
	return uit


func _init() -> void:
	var fouten := 0
	var gecheckt := 0
	for tsoort in ["infantry", "cavalry"]:
		for fac in FACTIES:
			for arch in ARCHS:
				var pad := "res://assets/models/%s/%s/%s_%s_gibs.glb" % [fac, tsoort, tsoort, arch]
				if not ResourceLoader.exists(pad):
					# Ander pad-schema (oudere mappen) of nog niet geleverd:
					# alleen melden als het MODEL er wel is.
					continue
				gecheckt += 1
				var wortel: Node3D = (load(pad) as PackedScene).instantiate()
				var delen: Array = wortel.find_children("*", "MeshInstance3D", true, false)
				var regel := "[GIB] %s %s/%s: %d delen" % [tsoort, fac, arch, delen.size()]
				if delen.size() < 2:
					regel += " !! GEEN LOSSE DELEN"
					fouten += 1
				# Stapel-detectie + verticale spreiding op de zwaartepunten.
				var middens: Array = []
				for d in delen:
					var mi := d as MeshInstance3D
					var aabb := mi.get_aabb()
					middens.append(mi.global_transform * (aabb.position + aabb.size * 0.5))
				var stapels := 0
				for i in middens.size():
					for j in range(i + 1, middens.size()):
						if (middens[i] as Vector3).distance_to(middens[j]) < 0.001:
							stapels += 1
				if stapels > 0:
					regel += " !! %d DELEN OP DEZELFDE PLEK" % stapels
					fouten += 1
				var laag := INF
				var hoog := -INF
				for m in middens:
					laag = minf(laag, (m as Vector3).y)
					hoog = maxf(hoog, (m as Vector3).y)
				if middens.size() >= 2 and hoog - laag < 0.01:
					regel += " !! GEEN VERTICALE SPREIDING"
					fouten += 1
				# Naam-dekking: kan het spel elke verplichte gib vinden?
				var mist: Array = []
				for verplicht in DELEN_VERPLICHT:
					var gevonden := false
					for d in delen:
						if kale_naam(String(d.name)).contains(String(verplicht)):
							gevonden = true
							break
					if not gevonden:
						mist.append(verplicht)
				if not mist.is_empty():
					regel += " !! MIST: " + ", ".join(mist)
					fouten += 1
				wortel.free()
				print(regel)
	print("---")
	print("[GIB] %d bestanden gecheckt, %d fouten" % [gecheckt, fouten])
	print("GIBCHECK " + ("PASS" if fouten == 0 else "FAIL"))
	quit(0 if fouten == 0 else 1)

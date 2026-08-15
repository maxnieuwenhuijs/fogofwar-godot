extends SceneTree

# Tijdelijke controle (15 augustus): staan de gib-delen van de nieuwe facties
# echt LOS en op hun plek? Per gibs-bestand: aantal delen, de verticale
# spreiding van de zwaartepunten (hoed hoort boven, benen onder) en of er
# delen op exact dezelfde plek staan (stapel-op-nul = kapotte export).
# De muis is de referentie die in het spel bewezen werkt.
func _initialize() -> void:
	for fac in ["mouse", "bear", "crocodile", "wolf"]:
		for arch in ["base", "atk"]:
			var pad := "res://assets/models/%s/infantry/infantry_%s_gibs.glb" % [fac, arch]
			if not ResourceLoader.exists(pad):
				print("[GIB] %s/%s: BESTAND ONTBREEKT" % [fac, arch])
				continue
			var wortel: Node3D = (load(pad) as PackedScene).instantiate()
			var delen: Array = wortel.find_children("*", "MeshInstance3D", true, false)
			var middens: Array = []
			for d in delen:
				var mi := d as MeshInstance3D
				var aabb := mi.get_aabb()
				var midden: Vector3 = mi.transform * (aabb.position + aabb.size * 0.5)
				middens.append(midden)
			var laag := 1e9
			var hoog := -1e9
			var dubbel := 0
			for i in middens.size():
				laag = minf(laag, middens[i].y)
				hoog = maxf(hoog, middens[i].y)
				for j in range(i + 1, middens.size()):
					if (middens[i] as Vector3).distance_to(middens[j]) < 0.01:
						dubbel += 1
			print("[GIB] %s/%s: %d delen, hoogte-spreiding %.2f, %d op dezelfde plek" % [
				fac, arch, delen.size(), hoog - laag, dubbel])
			wortel.free()
	quit()

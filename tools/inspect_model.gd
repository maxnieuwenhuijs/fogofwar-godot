extends SceneTree

## Debug: print maat en materiaal van het muis-karaktermodel.
## Draaien: godot --headless -s res://tools/inspect_model.gd

func _init() -> void:
	var ps: PackedScene = load("res://assets/models/muis/infanterie_basis.glb")
	var inst: Node = ps.instantiate()
	root.add_child(inst)
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		print("MESH ", mi.name, " aabb=", (mi as MeshInstance3D).get_aabb())
		var m: Material = (mi as MeshInstance3D).get_active_material(0)
		if m is BaseMaterial3D:
			var bm := m as BaseMaterial3D
			print("MAT metallic=", bm.metallic, " roughness=", bm.roughness,
				" albedo_tex=", bm.albedo_texture != null, " albedo=", bm.albedo_color)
	for sk in inst.find_children("*", "Skeleton3D", true, false):
		var mn := Vector3(1e9, 1e9, 1e9)
		var mx := -mn
		for i in (sk as Skeleton3D).get_bone_count():
			var p: Vector3 = (sk as Skeleton3D).get_bone_global_pose(i).origin
			mn = mn.min(p)
			mx = mx.max(p)
		print("BONES ", sk.name, " min=", mn, " max=", mx, " scale=", (sk as Skeleton3D).scale)
	for ap in inst.find_children("*", "AnimationPlayer", true, false):
		print("CLIPS ", (ap as AnimationPlayer).get_animation_list())
	quit()

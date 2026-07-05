extends SceneTree

func _init() -> void:
	var ps: PackedScene = load("res://assets/models/muis/musket.fbx")
	if ps == null:
		print("KON NIET LADEN")
		quit()
		return
	var inst: Node = ps.instantiate()
	root.add_child(inst)
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		print("MESH ", mi.name, " aabb=", (mi as MeshInstance3D).get_aabb())
		var m: Material = (mi as MeshInstance3D).get_active_material(0)
		if m is BaseMaterial3D:
			print("MAT albedo_tex=", (m as BaseMaterial3D).albedo_texture != null)
	print("SKELETONS: ", inst.find_children("*", "Skeleton3D", true, false).size())
	quit()

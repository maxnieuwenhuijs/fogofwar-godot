extends Node3D

const PawnViewScript = preload("res://scripts/game/pawn_view.gd")

func _ready() -> void:
	for arch in ["atk", "hp", "spd", "mix"]:
		var pv: Node3D = PawnViewScript.new()
		add_child(pv)
		pv.set_character("mouse", 0, arch)
		await get_tree().process_frame
		var namen: Array = []
		var an: AnimationPlayer = pv.get("_anim")
		if an != null:
			namen = Array(an.get_animation_list())
			namen.sort()
		print("[CLIPS] %s: %s" % [arch, str(namen)])
		pv.queue_free()
	get_tree().quit()

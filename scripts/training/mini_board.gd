class_name MiniBoard
extends Control

# Tekent een GameState als klein top-down bordje: rood = P1, blauw = P2,
# donkerder = inactief (ongelinkt). Vorm = piontype: cirkel = infanterie,
# driehoek = cavalerie (paard), langwerpige rechthoek = artillerie (kanon).
# Voor het Trainer-dashboard.

var state: GameState = null


func set_state(s: GameState) -> void:
	state = s
	queue_redraw()


func _draw() -> void:
	var n: int = Constants.BOARD_SIZE
	var s: float = minf(size.x, size.y)
	var cell: float = s / float(n)
	var ox: float = (size.x - s) * 0.5
	var oy: float = (size.y - s) * 0.5

	for y in n:
		for x in n:
			var c := Color(0.17, 0.18, 0.21) if (x + y) % 2 == 0 else Color(0.10, 0.11, 0.13)
			draw_rect(Rect2(ox + x * cell, oy + y * cell, cell, cell), c)
	for h in Constants.HAVEN_P1:
		draw_rect(Rect2(ox + h.x * cell, oy + h.y * cell, cell, cell), Color(0.9, 0.3, 0.3, 0.28))
	for h in Constants.HAVEN_P2:
		draw_rect(Rect2(ox + h.x * cell, oy + h.y * cell, cell, cell), Color(0.3, 0.55, 1.0, 0.28))

	if state == null:
		return
	for pawn in state.pawns.values():
		if pawn.is_eliminated:
			continue
		var col := Color(0.93, 0.32, 0.3) if pawn.owner_id == Constants.PLAYER_1 else Color(0.3, 0.55, 1.0)
		if not pawn.is_active:
			col = col.darkened(0.45)
		var center := Vector2(ox + (pawn.position.x + 0.5) * cell, oy + (pawn.position.y + 0.5) * cell)
		var r: float = cell * 0.36
		match pawn.unit_type:
			Constants.UnitType.CAVALRY:
				# Driehoek, punt richting de vijand (P1 speelt omhoog, P2 omlaag).
				var dir: float = -1.0 if pawn.owner_id == Constants.PLAYER_1 else 1.0
				var points := PackedVector2Array([
					center + Vector2(0.0, dir * r * 1.15),
					center + Vector2(-r, -dir * r * 0.85),
					center + Vector2(r, -dir * r * 0.85),
				])
				draw_colored_polygon(points, col)
			Constants.UnitType.ARTILLERY:
				# Langwerpige rechthoek (kanonsloop), richting de vijand.
				draw_rect(Rect2(center.x - r * 0.45, center.y - r * 1.15, r * 0.9, r * 2.3), col)
			_:
				draw_circle(center, r, col)

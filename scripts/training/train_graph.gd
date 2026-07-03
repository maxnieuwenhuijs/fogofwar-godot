class_name TrainGraph
extends Control

# Tekent de winrate van de uitdager per generatie; groene stip = geadopteerd.

var history: Array = []   # winrate 0..1 per generatie
var adopted: Array = []   # bool per generatie


func push(winrate: float, was_adopted: bool) -> void:
	history.append(clampf(winrate, 0.0, 1.0))
	adopted.append(was_adopted)
	if history.size() > 240:
		history.pop_front()
		adopted.pop_front()
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), Color(0.1, 0.11, 0.14))
	# break-even lijn op 0.5
	draw_line(Vector2(0, h * 0.5), Vector2(w, h * 0.5), Color(0.32, 0.34, 0.42), 1.0)
	var n := history.size()
	if n < 1:
		return
	var dx := w / float(maxi(1, n - 1))
	var pts: Array = []
	for i in n:
		pts.append(Vector2(i * dx, h - float(history[i]) * h))
	for i in n - 1:
		draw_line(pts[i], pts[i + 1], Color(0.4, 0.7, 1.0), 2.0)
	for i in n:
		if adopted[i]:
			draw_circle(pts[i], 4.5, Color(0.42, 0.9, 0.5))
		else:
			draw_circle(pts[i], 2.5, Color(0.55, 0.78, 1.0))

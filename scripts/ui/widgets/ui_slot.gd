extends Control

## Een hangslotje, getekend (de levering van milestone 4 toont er een bij
## "CHAT" en boven "SEALED FOR THE DEAD", maar bevat het icoon niet). Kleur
## en maat van buiten; het slot vult de hoogte van de node.
##
##   const SLOT := preload("res://scripts/ui/widgets/ui_slot.gd")
##   var s := SLOT.new()
##   s.kleur = Color("#F1E6CF")
##   s.custom_minimum_size = Vector2(18, 22)

var kleur: Color = Color("#F1E6CF"):
	set(v):
		kleur = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var h: float = size.y
	var b: float = minf(size.x, h * 0.82)
	var x0: float = (size.x - b) * 0.5
	# het lijf: de onderste 58%
	var lijf := Rect2(x0, h * 0.42, b, h * 0.58)
	draw_rect(lijf, kleur)
	# de beugel: een halve boog met twee pootjes
	var dikte: float = maxf(1.5, b * 0.16)
	var straal: float = b * 0.30
	var midden := Vector2(size.x * 0.5, h * 0.30)
	draw_arc(midden, straal, PI, TAU, 16, kleur, dikte, true)
	draw_line(midden + Vector2(-straal, 0.0), Vector2(midden.x - straal, lijf.position.y + 1.0), kleur, dikte)
	draw_line(midden + Vector2(straal, 0.0), Vector2(midden.x + straal, lijf.position.y + 1.0), kleur, dikte)
	# het sleutelgat
	var gat := Color(0.0, 0.0, 0.0, 0.55)
	draw_circle(Vector2(size.x * 0.5, lijf.position.y + lijf.size.y * 0.42), b * 0.11, gat)
	draw_rect(Rect2(size.x * 0.5 - b * 0.045, lijf.position.y + lijf.size.y * 0.42, b * 0.09, lijf.size.y * 0.3), gat)

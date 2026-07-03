class_name Overlay
extends Control

@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _buttons: VBoxContainer = %Buttons

var _cb: Callable = Callable()


## Toon een modaal keuzescherm. options = knop-labels; cb.call(index) bij keuze.
## accent kleurt de titel (bv. de kleur van de winnaar).
## body_left: lange uitlegteksten links uitlijnen en breder laten wrappen.
func show_choice(title: String, body: String, options: Array, cb: Callable = Callable(), accent: Color = Color.WHITE, body_left: bool = false) -> void:
	visible = true
	_title.text = title
	_title.add_theme_color_override("font_color", accent)
	_body.text = body
	_body.visible = body != ""
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if body_left else HORIZONTAL_ALIGNMENT_CENTER
	_body.custom_minimum_size = Vector2(820, 0) if body_left else Vector2(0, 0)
	# Kan aangeroepen worden vanuit een button-pressed-signaal (menu → menu);
	# de knop is dan nog locked, dus niet hard free()-en.
	for child in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
	for i in options.size():
		var button := Button.new()
		button.text = str(options[i])
		button.custom_minimum_size = Vector2(320, 60)
		button.add_theme_font_size_override("font_size", 26)
		var idx := i
		button.pressed.connect(func() -> void: _pick(idx))
		_buttons.add_child(button)
	_cb = cb


func _pick(index: int) -> void:
	Audio.play("ui_click")
	visible = false
	if _cb.is_valid():
		_cb.call(index)

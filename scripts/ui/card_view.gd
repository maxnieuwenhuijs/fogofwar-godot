class_name CardView
extends PanelContainer

signal stats_changed
signal tapped(card: CardView)

@export var card_index: int = 0

var data: CardData = CardData.new()
var _editable: bool = true
var _selected: bool = false

@onready var _title: Label = %Title
@onready var _hp_value: Label = %HpValue
@onready var _sta_value: Label = %StaValue
@onready var _atk_value: Label = %AtkValue
@onready var _pool_label: Label = %PoolLabel
@onready var _linked_label: Label = %LinkedLabel
@onready var _tap_area: Button = %TapArea
@onready var _buttons: Array[Button] = [
	%HpMinus, %HpPlus, %StaMinus, %StaPlus, %AtkMinus, %AtkPlus,
]


func _ready() -> void:
	mouse_entered.connect(move_to_front)
	_tap_area.pressed.connect(func() -> void: tapped.emit(self))
	_refresh()


func set_editable(enabled: bool) -> void:
	_editable = enabled
	for button in _buttons:
		button.visible = enabled
	_refresh()


func set_selectable(enabled: bool) -> void:
	_tap_area.visible = enabled


func set_selected_visual(selected: bool) -> void:
	_selected = selected
	_update_tint()


func set_linked(linked: bool) -> void:
	data.is_linked = linked
	if linked:
		_tap_area.visible = false
		_selected = false
	_refresh()


func _refresh() -> void:
	_title.text = "Kaart %d" % (card_index + 1)
	_hp_value.text = str(data.hp)
	_sta_value.text = str(data.stamina)
	_atk_value.text = str(data.attack)
	_pool_label.visible = false
	_linked_label.visible = data.is_linked
	_update_tint()


func _update_tint() -> void:
	if data.is_linked:
		modulate = Color(0.5, 0.52, 0.58)
	elif _selected:
		modulate = Color(1.0, 0.95, 0.55)
	else:
		modulate = Color.WHITE


func _on_hp_plus_pressed() -> void:
	_adjust_stat(&"hp", 1)


func _on_hp_minus_pressed() -> void:
	_adjust_stat(&"hp", -1)


func _on_sta_plus_pressed() -> void:
	_adjust_stat(&"stamina", 1)


func _on_sta_minus_pressed() -> void:
	_adjust_stat(&"stamina", -1)


func _on_atk_plus_pressed() -> void:
	_adjust_stat(&"attack", 1)


func _on_atk_minus_pressed() -> void:
	_adjust_stat(&"attack", -1)


func _adjust_stat(field: StringName, delta: int) -> void:
	if not _editable:
		return
	var changed := false
	if delta > 0:
		# +stat: haal een punt weg bij de grootste andere stat (>1).
		var donor := _biggest_other(field, 1)
		var cap: int = data.budget - 2 * Constants.MIN_STAT
		# Beer: Speed-limiet bij definitie.
		if field == &"stamina" and data.speed_max > 0:
			cap = mini(cap, data.speed_max)
		if donor != &"" and int(data.get(field)) < cap:
			data.set(field, int(data.get(field)) + 1)
			data.set(donor, int(data.get(donor)) - 1)
			changed = true
	else:
		# -stat: geef het punt aan de kleinste andere stat (die nog mag groeien).
		if int(data.get(field)) > Constants.MIN_STAT:
			var receiver := _smallest_other(field)
			if receiver == &"stamina" and data.speed_max > 0 and data.stamina >= data.speed_max:
				receiver = &"hp" if field != &"hp" else &"attack"
			data.set(field, int(data.get(field)) - 1)
			data.set(receiver, int(data.get(receiver)) + 1)
			changed = true
	if changed:
		Audio.play("card_stat_up" if delta > 0 else "card_stat_down")
		_refresh()
		stats_changed.emit()


func _other_fields(field: StringName) -> Array:
	var fields: Array = [&"hp", &"stamina", &"attack"]
	fields.erase(field)
	return fields


## Grootste andere stat met waarde > min_value; &"" als geen.
func _biggest_other(field: StringName, min_value: int) -> StringName:
	var best := &""
	var best_val := min_value
	for other in _other_fields(field):
		var v := int(data.get(other))
		if v > best_val:
			best_val = v
			best = other
	return best


func _smallest_other(field: StringName) -> StringName:
	var others := _other_fields(field)
	var best: StringName = others[0]
	for other in others:
		if int(data.get(other)) < int(data.get(best)):
			best = other
	return best

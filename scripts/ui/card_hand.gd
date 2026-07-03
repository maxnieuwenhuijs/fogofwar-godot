class_name CardHand
extends Control

signal define_confirmed(cards: Array[CardData])
signal card_picked(index: int)

const CARD_VIEW_SCENE := preload("res://scenes/ui/card_view.tscn")
const CARD_SIZE := Vector2(300, 430)

## Definieer-layout: plat naast elkaar (geen waaier, geen overlap)
@export var fan_rotation_deg: float = 0.0
@export var fan_x_spacing: float = 340.0
@export var fan_base_y_factor: float = 0.80
@export var fan_y_arc: float = 0.0
## Koppel-layout (compacte rij onderaan)
@export var link_y_factor: float = 0.88
@export var link_spacing: float = 250.0
@export var link_scale: float = 0.6

var phase: int = Constants.UiPhase.DEFINE
var _cards: Array[CardView] = []
var _selected_index: int = -1

# v4.1: aantal kaarten, budget en Speed-limiet volgen uit de doctrine.
var _card_count: int = Constants.CARDS_PER_ROUND
var _budget: int = Constants.STAT_TOTAL
var _speed_max: int = 0

@onready var _cards_root: Control = %Cards
@onready var _phase_label: Label = %PhaseLabel
@onready var _hint_label: Label = %HintLabel
@onready var _confirm_button: Button = %ConfirmButton


func _ready() -> void:
	_build_cards()
	_confirm_button.pressed.connect(_on_confirm_pressed)
	# De HUD bovenaan (game.gd) toont fase + prompt; deze balk is dubbelop.
	_phase_label.visible = false
	_hint_label.visible = false
	_layout_fan(false)
	_set_phase(Constants.UiPhase.DEFINE)


## Stel de hand in op de doctrine van de speler (aantal × budget, Speed-limiet).
func configure(card_count: int, budget: int, speed_max: int = 0) -> void:
	_budget = budget
	_speed_max = speed_max
	if card_count != _card_count:
		_card_count = card_count
		for card in _cards:
			card.queue_free()
		_cards = []
		_build_cards()
	for card in _cards:
		card.data.budget = _budget
		card.data.speed_max = _speed_max


func _build_cards() -> void:
	for i in _card_count:
		var card_view: CardView = CARD_VIEW_SCENE.instantiate()
		card_view.card_index = i
		card_view.custom_minimum_size = CARD_SIZE
		card_view.size = CARD_SIZE
		card_view.pivot_offset = CARD_SIZE * 0.5
		card_view.stats_changed.connect(_on_card_stats_changed)
		card_view.tapped.connect(_on_card_tapped)
		card_view.data.budget = _budget
		card_view.data.speed_max = _speed_max
		_cards_root.add_child(card_view)
		_cards.append(card_view)


func _screen() -> Vector2:
	return get_viewport_rect().size


# --- Layouts -----------------------------------------------------------------

func _layout_fan(animate: bool = true) -> void:
	var screen := _screen()
	var count := _cards.size()
	var cx := screen.x * 0.5
	var base_y := screen.y * fan_base_y_factor
	# Dynamisch: bij meer dan 3 kaarten (Muis: 4) kleiner schalen en dichter op
	# elkaar — maar NOOIT overlappen, anders vangt de buurkaart de +/−-klikken.
	var scl: float = minf(1.0, (screen.x - 40.0) / (float(count) * (CARD_SIZE.x + 10.0)))
	var spacing: float = minf(fan_x_spacing, (screen.x - 20.0 - CARD_SIZE.x * scl) / maxf(1.0, float(count - 1)))
	for i in count:
		var t := i - (count - 1) / 2.0
		var angle := deg_to_rad(fan_rotation_deg) * t
		var center := Vector2(cx + t * spacing, base_y + absf(t) * fan_y_arc)
		_place(_cards[i], center, angle, scl, animate)


func _layout_linking(animate: bool = true) -> void:
	var screen := _screen()
	var count := _cards.size()
	for i in count:
		var t := i - (count - 1) / 2.0
		var center := Vector2(screen.x * 0.5 + t * link_spacing, screen.y * link_y_factor)
		_place(_cards[i], center, 0.0, link_scale, animate)


func _place(card: CardView, center: Vector2, rot: float, scl: float, animate: bool) -> void:
	card.pivot_offset = CARD_SIZE * 0.5
	var target_pos := center - CARD_SIZE * 0.5
	var target_scale := Vector2(scl, scl)
	if animate:
		var tween := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "position", target_pos, 0.4)
		tween.tween_property(card, "rotation", rot, 0.4)
		tween.tween_property(card, "scale", target_scale, 0.4)
	else:
		card.position = target_pos
		card.rotation = rot
		card.scale = target_scale


# --- Define ------------------------------------------------------------------

func open_for_define() -> void:
	visible = true
	_set_phase(Constants.UiPhase.DEFINE)
	_layout_fan(false)
	# Kaarten "uitdelen": per kaart een korte deal-klap met oplopende delay.
	for i in _cards.size():
		Audio.play("card_deal", 0.08 * float(i))


func _set_phase(new_phase: int) -> void:
	phase = new_phase
	_selected_index = -1
	if new_phase == Constants.UiPhase.DEFINE:
		_phase_label.text = "Definieer je kaarten"
		_hint_label.text = "Verdeel %d punten (min. 1 per stat). Druk op Bevestigen." % _budget
		_confirm_button.visible = true
		_confirm_button.disabled = true
		for card in _cards:
			card.data.reset_stats()
			card.set_editable(true)
			card.set_selectable(false)
			card.set_selected_visual(false)
			card.set_linked(false)
	_update_confirm_button()


func get_card_views() -> Array[CardView]:
	return _cards


func get_defined_dicts() -> Array:
	var out: Array = []
	for card in _cards:
		out.append({"hp": card.data.hp, "stamina": card.data.stamina, "attack": card.data.attack})
	return out


func _all_cards_valid() -> bool:
	for card in _cards:
		if not card.data.is_valid():
			return false
	return true


func _update_confirm_button() -> void:
	if phase != Constants.UiPhase.DEFINE:
		return
	_confirm_button.disabled = not _all_cards_valid()


func _on_card_stats_changed() -> void:
	_update_confirm_button()


func _on_confirm_pressed() -> void:
	if not _all_cards_valid():
		return
	Audio.play("card_confirm")
	var card_data: Array[CardData] = []
	for card in _cards:
		card_data.append(card.data)
	define_confirmed.emit(card_data)


# --- Linking -----------------------------------------------------------------

## linked_flags: bool per kaart (index-uitgelijnd met de onthulde kaarten).
func open_for_linking(linked_flags: Array) -> void:
	visible = true
	phase = Constants.UiPhase.LINKING
	_selected_index = -1
	_phase_label.text = "Koppel je kaarten"
	_hint_label.text = "Kies een kaart, tik dan een pion."
	_confirm_button.visible = false
	for i in _cards.size():
		var card := _cards[i]
		card.set_editable(false)
		var linked: bool = i < linked_flags.size() and bool(linked_flags[i])
		card.set_linked(linked)
		card.set_selectable(not linked)
		card.set_selected_visual(false)
	_layout_linking(false)


func _on_card_tapped(card: CardView) -> void:
	if phase != Constants.UiPhase.LINKING:
		return
	var index := _cards.find(card)
	if index < 0:
		return
	_selected_index = index
	Audio.play("card_select")
	for i in _cards.size():
		_cards[i].set_selected_visual(i == index)
	card_picked.emit(index)

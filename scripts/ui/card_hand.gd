class_name CardHand
extends Control

signal define_confirmed(cards: Array[CardData])
signal card_picked(index: int)
## Slepen in de koppel-fase (16 september): een kaart van de hand naar een
## pion. `pos` is de schermpositie van muis of vinger; game.gd tekent de
## pijl, licht de pion op en koppelt bij het loslaten.
signal drag_moved(index: int, pos: Vector2)
signal drag_dropped(index: int, pos: Vector2)
signal drag_cancelled(index: int)

const CARD_VIEW_SCENE := preload("res://scenes/ui/card_view.tscn")
## UI-beweging (30 september): stempel en bevestigknop bij het uitdelen.
const Beweging := preload("res://scripts/ui/ui_beweging.gd")
## De maat waarin de hand rekent (posities, tussenruimte, overlap): de halve
## kaart. De kaart zelf tekent op UiAssets.KAART_MAAT (645x989) en wordt met
## KAART_SCHAAL maal de schaalfactor van de layout getoond.
const CARD_SIZE := Vector2(322, 494)
const KAART_SCHAAL := 0.5

## Definieer-layout: een waaier zoals je hem in je hand houdt (16 september,
## Max: "meer in een waaier alsof je die in je hand hebt"). Draai per kaart
## vanaf het midden, een boog (buitenste kaarten lager, alsof ze om een spil
## onder het scherm draaien) en overlap: de volgende kaart ligt op
## `fan_overlap` maal de kaartbreedte, rechts bovenop. Door de overlap passen
## de kaarten GROTER dan plat naast elkaar (Muis, vijf kaarten: 0,63 -> 0,82).
## De kaart onder de muis of je vinger komt naar voren (`_zet_focus`).
@export var fan_rotation_deg: float = 5.5
@export var fan_x_spacing: float = 340.0
@export var fan_base_y_factor: float = 0.78
@export var fan_overlap: float = 0.72
@export var fan_max_scale: float = 1.0
## Naar voren gehaalde kaart: zoveel pixels omhoog (maal de schaal) en zo
## veel groter.
const FOCUS_LIFT := 34.0
const FOCUS_SCHAAL := 1.06
## Aangeklikte kaart (definieerfase): schuift dit deel van zijn hoogte omhoog
## en blijft staan, met de knoppen vrij (Max: "als je op een klikt schuift
## hij naar boven en kan je makkelijker de knoppen indrukken").
const ACTIEF_LIFT := 0.22
const ACTIEF_SCHAAL := 1.08
## Gesleepte kaart (koppel-fase): tilt zoveel van zijn hoogte op.
const SLEEP_LIFT := 0.12
## Gekozen kaart in de koppel-fase: schuift zoveel van zijn hoogte omhoog.
const LINK_LIFT := 0.14
## Zoveel pixels bewegen voordat een druk op een kaart een sleep wordt.
const DRAG_DREMPEL := 18.0
const DEAL_STAP := 0.08   # seconden tussen twee kaarten bij het uitdelen (= Audio card_deal)
## Koppel-layout: dezelfde waaier, kleiner (geen knoppen nodig) en lager (geen
## bevestigknop eronder). De gekozen kaart schuift omhoog (`LINK_LIFT`).
@export var link_y_factor: float = 0.86
@export var link_max_scale: float = 0.84

var phase: int = Constants.UiPhase.DEFINE
var _cards: Array[CardView] = []
var _selected_index: int = -1
# Waaier: per kaart zijn plek {center, rot, scl}; welke kaart onder de muis
# ligt (_focus, kleine lift) en welke is aangeklikt (_actief, schuift omhoog).
var _plekken: Array = []
var _focus: int = -1
var _actief: int = -1
# Slepen (koppel-fase): kaart onder de ingedrukte muis, waar de druk begon,
# en of de beweging al voorbij de drempel is.
var _drag_index: int = -1
var _drag_van: Vector2 = Vector2.ZERO
var _drag_actief: bool = false

# v4.1: aantal kaarten, budget en Speed-limiet volgen uit de doctrine.
var _card_count: int = Constants.CARDS_PER_ROUND
var _budget: int = Constants.STAT_TOTAL
var _factie_bonus: Array = []   # [hp, speed, attack] van de factie (16 september)
var _speed_max: int = 0
# Eigenaar van de hand (teamkleur en embleem op de kaarten); -1 = onbekend.
var _speler_id: int = -1
var _doctrine: int = -1

@onready var _cards_root: Control = %Cards
@onready var _phase_label: Label = %PhaseLabel
@onready var _hint_label: Label = %HintLabel
@onready var _confirm_button: Button = %ConfirmButton


func _ready() -> void:
	# De hand hangt onder de CanvasLayer van het bord; daar komt het
	# venster-thema van UiThema niet doorheen (alleen via Control/Window-ouders).
	if theme == null:
		theme = UiAssets.thema()
	_build_cards()
	_confirm_button.pressed.connect(_on_confirm_pressed)
	# De HUD bovenaan (game.gd) toont fase + prompt; deze balk is dubbelop.
	_phase_label.visible = false
	_hint_label.visible = false
	_layout_fan(false)
	_set_phase(Constants.UiPhase.DEFINE)


## Stel de hand in op de doctrine van de speler (aantal × budget, Speed-limiet).
## F2.6 (v4.2): bonus_kaarten = aantal kaarten met budget+1 (de blinde CP-inzet,
## D1) - de eerste kaarten in de waaier dragen het extra punt en het CP-zegel.
## speler_id/doctrine: eigenaar voor teamkleur en embleem (-1 = laat staan).
func configure(card_count: int, budget: int, speed_max: int = 0, bonus_kaarten: int = 0,
		speler_id: int = -1, doctrine: int = -1, factie_bonus: Array = []) -> void:
	_budget = budget
	_speed_max = speed_max
	if not factie_bonus.is_empty():
		_factie_bonus = factie_bonus
	if speler_id != -1:
		_speler_id = speler_id
	if doctrine != -1:
		_doctrine = doctrine
	if card_count != _card_count:
		_card_count = card_count
		for card in _cards:
			card.queue_free()
		_cards = []
		_build_cards()
	for i in _cards.size():
		_cards[i].data.budget = _budget + (1 if i < bonus_kaarten else 0)
		_cards[i].data.speed_max = _speed_max
		if _speler_id != -1:
			_cards[i].set_speler(_speler_id)
		if _doctrine != -1:
			_cards[i].set_doctrine(_doctrine)
		_cards[i].set_cp_inzet(i < bonus_kaarten)
		_cards[i].set_kaart_aantal(card_count)
		if _factie_bonus.size() == 3:
			_cards[i].set_bonus(int(_factie_bonus[0]), int(_factie_bonus[1]), int(_factie_bonus[2]))


func _build_cards() -> void:
	for i in _card_count:
		var card_view: CardView = CARD_VIEW_SCENE.instantiate()
		card_view.card_index = i
		card_view.custom_minimum_size = UiAssets.KAART_MAAT
		card_view.size = UiAssets.KAART_MAAT
		card_view.pivot_offset = UiAssets.KAART_MAAT * 0.5
		card_view.stats_changed.connect(_on_card_stats_changed)
		card_view.tapped.connect(_on_card_tapped)
		card_view.data.budget = _budget
		card_view.data.speed_max = _speed_max
		if _speler_id != -1:
			card_view.set_speler(_speler_id)
		if _doctrine != -1:
			card_view.set_doctrine(_doctrine)
		_cards_root.add_child(card_view)
		_cards.append(card_view)


func _screen() -> Vector2:
	return get_viewport_rect().size


# --- Layouts -----------------------------------------------------------------

func _layout_fan(animate: bool = true, uitdelen: bool = false) -> void:
	_layout_waaier(fan_max_scale, fan_base_y_factor, animate, uitdelen)


func _layout_linking(animate: bool = true) -> void:
	_layout_waaier(link_max_scale, link_y_factor, animate, false)


## De waaier zelf, voor beide fasen: draai per kaart vanaf het midden, een
## boog (buitenste kaarten lager, alsof ze om een spil onder het scherm
## draaien) en overlap, rechts bovenop.
func _layout_waaier(max_schaal: float, y_factor: float, animate: bool, uitdelen: bool) -> void:
	var screen := _screen()
	var count := _cards.size()
	var cx := screen.x * 0.5
	var base_y := screen.y * y_factor
	# De kaarten overlappen (zoals in een hand), dus ze mogen groter dan plat
	# naast elkaar. De buitenste kaart staat gedraaid, en een gedraaide kaart
	# steekt verder uit dan zijn breedte (de hoek zwaait naar buiten), dus dat
	# telt mee: halve span = t_max * overlap * w + (w/2) cos a + (h/2) sin a.
	var stap := deg_to_rad(fan_rotation_deg)
	var t_max: float = (count - 1) / 2.0
	var hoek_max: float = stap * t_max
	var halve_span_per_schaal: float = (t_max * fan_overlap * CARD_SIZE.x
		+ 0.5 * CARD_SIZE.x * cos(hoek_max) + 0.5 * CARD_SIZE.y * sin(hoek_max))
	var scl: float = clampf((screen.x * 0.5 - 20.0) / maxf(halve_span_per_schaal, 1.0), 0.3, max_schaal)
	var spacing: float = minf(fan_x_spacing, fan_overlap * CARD_SIZE.x * scl)
	# Boog: alsof de kaarten om een spil onder het scherm draaien. De straal
	# volgt uit de tussenruimte en de draaistap, zodat draai en boog bij
	# elkaar horen (een grote hand buigt meer dan drie kaarten).
	var straal: float = spacing / maxf(sin(stap), 0.001) if stap > 0.0 else 0.0
	# De buitenste kaart hangt lager; schuif de hele hand zoveel omhoog dat de
	# onderkant van de laagste kaart niet onder de bevestigknop komt.
	var zak_max: float = straal * (1.0 - cos(hoek_max)) if stap > 0.0 else 0.0
	base_y -= zak_max * 0.5
	_plekken.resize(count)
	_focus = -1
	_actief = -1
	for i in count:
		var t := i - t_max
		var angle := stap * t
		var zak: float = straal * (1.0 - cos(angle)) if stap > 0.0 else 0.0
		var center := Vector2(cx + t * spacing, base_y + zak)
		_plekken[i] = {"center": center, "rot": angle, "scl": scl}
		var d := _plek_doel(i)
		if uitdelen:
			# Uitdelen: van onder het scherm naar zijn plek, een voor een, op de
			# klap van het deel-geluid (open_for_define speelt ze met dezelfde stap).
			_cards[i].position = center + Vector2(0.0, screen.y * 0.6) - UiAssets.KAART_MAAT * 0.5
			_cards[i].rotation = angle
			_cards[i].scale = Vector2.ONE * (scl * KAART_SCHAAL)
			_place(_cards[i], center, angle, scl, true, 0.45, DEAL_STAP * float(i))
		else:
			_place(_cards[i], d.center, float(d.rot), float(d.scl), animate)
	_werk_volgorde_bij()


func _place(card: CardView, center: Vector2, rot: float, scl: float, animate: bool,
		duur: float = 0.4, vertraging: float = 0.0) -> void:
	# De kaart is 645x989 met de spil in het midden; de hand toont hem op de
	# halve maat (CARD_SIZE) maal de schaalfactor van de layout.
	card.pivot_offset = UiAssets.KAART_MAAT * 0.5
	var target_pos := center - UiAssets.KAART_MAAT * 0.5
	var target_scale := Vector2.ONE * (scl * KAART_SCHAAL)
	# Hooguit een lopende tween per kaart: hover, uitdelen en een nieuwe
	# layout vechten anders om dezelfde eigenschappen.
	if card.has_meta("hand_tween"):
		var vorige = card.get_meta("hand_tween")
		if vorige is Tween and (vorige as Tween).is_valid():
			(vorige as Tween).kill()
	if animate:
		var tween := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "position", target_pos, duur).set_delay(vertraging)
		tween.tween_property(card, "rotation", rot, duur).set_delay(vertraging)
		tween.tween_property(card, "scale", target_scale, duur).set_delay(vertraging)
		card.set_meta("hand_tween", tween)
	else:
		card.position = target_pos
		card.rotation = rot
		card.scale = target_scale


# --- Naar voren halen (definieerfase) -----------------------------------------

## Welke kaart ligt onder dit schermpunt? Van boven naar beneden in de
## tekenvolgorde (laatste kind bovenop), met de draai van de kaart mee.
func _kaart_onder(punt: Vector2) -> int:
	var kinderen := _cards_root.get_children()
	for k in range(kinderen.size() - 1, -1, -1):
		var card := kinderen[k] as CardView
		if card == null or not card.visible:
			continue
		var lokaal: Vector2 = card.get_global_transform().affine_inverse() * punt
		if Rect2(Vector2.ZERO, UiAssets.KAART_MAAT).has_point(lokaal):
			return _cards.find(card)
	return -1


## Tekenvolgorde terug naar de hand: rechts bovenop, zoals je een waaier houdt.
func _herstel_volgorde() -> void:
	for i in _cards.size():
		if _cards[i].get_parent() == _cards_root:
			_cards_root.move_child(_cards[i], i)


## Waar hoort kaart i NU: zijn plek in de waaier, met de lift van hover
## (klein), klik (groot, blijft staan) of sleep (koppel-fase) erbij.
func _plek_doel(i: int) -> Dictionary:
	var p: Dictionary = _plekken[i]
	var center: Vector2 = p.center
	var scl: float = float(p.scl)
	if phase == Constants.UiPhase.LINKING:
		if i == _drag_index and _drag_actief:
			center.y -= SLEEP_LIFT * CARD_SIZE.y * scl
			scl *= FOCUS_SCHAAL
		elif i == _selected_index:
			center.y -= LINK_LIFT * CARD_SIZE.y * scl
		elif i == _focus and not _cards[i].data.is_linked:
			center.y -= FOCUS_LIFT * scl
	elif i == _actief:
		center.y -= ACTIEF_LIFT * CARD_SIZE.y * scl
		scl *= ACTIEF_SCHAAL
	elif i == _focus:
		center.y -= FOCUS_LIFT * scl
		scl *= FOCUS_SCHAAL
	return {"center": center, "rot": p.rot, "scl": scl}


func _werk_kaart_bij(i: int) -> void:
	if i < 0 or i >= _cards.size() or i >= _plekken.size():
		return
	var d := _plek_doel(i)
	_place(_cards[i], d.center, float(d.rot), float(d.scl), true, 0.18)


## Tekenvolgorde: de hand (rechts bovenop), daarboven de aangeklikte kaart,
## daarboven de kaart onder de muis, en een gesleepte kaart helemaal bovenop.
## move_to_front en niet z_index: de GUI kiest wie de klik krijgt op de
## boomvolgorde, en een kaartwortel vangt zijn hele vlak (mouse_filter STOP),
## dus wat je ziet is wat je raakt. Een halfbedekte kaart haal je met een
## tik op zijn zichtbare deel naar voren; die tik raakt geen knop.
func _werk_volgorde_bij() -> void:
	_herstel_volgorde()
	var laatste := _cards_root.get_child_count() - 1
	if phase == Constants.UiPhase.LINKING and _selected_index >= 0 and _selected_index < _cards.size():
		_cards_root.move_child(_cards[_selected_index], laatste)
	if _actief >= 0 and _actief < _cards.size():
		_cards_root.move_child(_cards[_actief], laatste)
	if _focus >= 0 and _focus < _cards.size() and _focus != _actief:
		_cards_root.move_child(_cards[_focus], laatste)
	if _drag_actief and _drag_index >= 0 and _drag_index < _cards.size():
		_cards_root.move_child(_cards[_drag_index], laatste)


## De kaart onder de muis komt iets naar voren; -1 = geen.
func _zet_focus(index: int) -> void:
	if index == _focus:
		return
	var oud := _focus
	_focus = index
	_werk_volgorde_bij()
	_werk_kaart_bij(oud)
	_werk_kaart_bij(index)


## Aangeklikte kaart: schuift omhoog en blijft staan tot je een andere kiest.
func _zet_actief(index: int) -> void:
	if index == _actief:
		return
	var oud := _actief
	_actief = index
	_werk_volgorde_bij()
	_werk_kaart_bij(oud)
	_werk_kaart_bij(index)


## Schermpunt bovenaan het midden van kaart `index` (begin van de sleep-pijl).
func kaart_punt(index: int) -> Vector2:
	if index < 0 or index >= _cards.size():
		return Vector2.ZERO
	return _cards[index].get_global_transform() * Vector2(UiAssets.KAART_MAAT.x * 0.5, 0.0)


## Een lopende sleep afbreken (de hand gaat dicht, de fase wisselt).
func annuleer_sleep() -> void:
	if _drag_actief:
		var i := _drag_index
		_drag_actief = false
		_drag_index = -1
		_werk_volgorde_bij()
		_werk_kaart_bij(i)
		drag_cancelled.emit(i)
	_drag_index = -1
	_drag_actief = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible and is_inside_tree():
		annuleer_sleep()


## Muis en vinger (Android geeft via de muis-emulatie dezelfde events): in de
## definieerfase hover = kleine lift en klik = omhoog schuiven; in de
## koppel-fase begint een druk op een vrije kaart een sleep zodra je voorbij
## de drempel beweegt. Niets wordt hier opgegeten: de plus-knoppen en het
## tikvlak van de kaart krijgen hun klik gewoon, en het bord zijn beweging.
func _input(event: InputEvent) -> void:
	if not visible or _cards.is_empty():
		return
	if phase == Constants.UiPhase.DEFINE:
		if event is InputEventMouseMotion:
			_zet_focus(_kaart_onder((event as InputEventMouseMotion).position))
		elif event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			# Bij het LOSLATEN: een plus-knop vuurt ook bij het loslaten, en de
			# kaart schuift pas daarna weg onder de muis vandaan.
			if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
				var i := _kaart_onder(mb.position)
				if i >= 0:
					_zet_actief(i)
	elif phase == Constants.UiPhase.LINKING:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index != MOUSE_BUTTON_LEFT:
				return
			if mb.pressed:
				var i := _kaart_onder(mb.position)
				if i >= 0 and not _cards[i].data.is_linked:
					_drag_index = i
					_drag_van = mb.position
					_drag_actief = false
			elif _drag_actief:
				var gesleept := _drag_index
				_drag_actief = false
				_drag_index = -1
				_werk_volgorde_bij()
				_werk_kaart_bij(gesleept)
				drag_dropped.emit(gesleept, mb.position)
			else:
				_drag_index = -1
		elif event is InputEventMouseMotion and _drag_index < 0:
			_zet_focus(_kaart_onder((event as InputEventMouseMotion).position))
		elif event is InputEventMouseMotion and _drag_index >= 0:
			var mm := event as InputEventMouseMotion
			if not _drag_actief and mm.position.distance_to(_drag_van) >= DRAG_DREMPEL:
				_drag_actief = true
				# De sleep kiest de kaart langs dezelfde weg als een tik, tilt hem
				# op en meldt vanaf nu elke beweging (pijl en doelpion in game.gd).
				Audio.play("card_select")
				_kies(_drag_index)
				card_picked.emit(_drag_index)
			if _drag_actief:
				drag_moved.emit(_drag_index, mm.position)


# --- Define ------------------------------------------------------------------

func open_for_define() -> void:
	visible = true
	_set_phase(Constants.UiPhase.DEFINE)
	# Kaarten uitdelen: ze vliegen een voor een vanaf onderen in, en per kaart
	# een korte deal-klap met dezelfde oplopende delay. Animaties uit: meteen
	# op hun plek (de klapjes blijven).
	if Beweging.uit_gekozen():
		_layout_fan(false, false)
	else:
		_layout_fan(true, true)
	for i in _cards.size():
		Audio.play("card_deal", DEAL_STAP * float(i))
		# UI-beweging: het CP-zegel stempelt als de kaart landt.
		_cards[i].stempel_cp(0.45 + DEAL_STAP * float(i))
	# De bevestigknop ploft als de laatste kaart ligt, en duwt als je wacht.
	Beweging.plof(_confirm_button, 0.45 + DEAL_STAP * float(maxi(0, _cards.size() - 1)), 0.92, false,
		Vector2(0.5, 0.5), true)
	Beweging.duw(_confirm_button)


func _set_phase(new_phase: int) -> void:
	annuleer_sleep()
	phase = new_phase
	_selected_index = -1
	_focus = -1
	_actief = -1
	if new_phase == Constants.UiPhase.DEFINE:
		_phase_label.text = tr("CARD_DEFINE_TITLE")
		_hint_label.text = tr("CARD_DEFINE_HINT") % _budget
		_confirm_button.visible = true
		_confirm_button.disabled = true
		for card in _cards:
			card.data.reset_stats()
			card.set_editable(true)
			card.set_selectable(false)
			card.set_selected_visual(false)
			card.set_linked(false)
			card.set_onthuld(false)
			card.set_verborgen(false)
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
## Vrij = SELECTABLE (los lint), gekoppeld = LINKED (kettingzegel, gedimd).
func open_for_linking(linked_flags: Array) -> void:
	annuleer_sleep()
	visible = true
	phase = Constants.UiPhase.LINKING
	_selected_index = -1
	_phase_label.text = tr("CARD_LINK_TITLE")
	_hint_label.text = tr("CARD_LINK_HINT")
	_confirm_button.visible = false
	for i in _cards.size():
		var card := _cards[i]
		card.set_editable(false)
		var linked: bool = i < linked_flags.size() and bool(linked_flags[i])
		card.set_linked(linked)
		card.set_selectable(not linked)
		card.set_selected_visual(false)
	_focus = -1
	_herstel_volgorde()
	_layout_linking(false)


## Kies kaart `index` alsof erop getikt is, maar zonder signaal: game.gd zet
## zo de keuze terug die over de beurt van de tegenstander heen bleef staan
## (Max, 12 september: "houd mijn kaart geselecteerd").
func selecteer(index: int) -> void:
	if phase != Constants.UiPhase.LINKING or index < 0 or index >= _cards.size():
		return
	if _cards[index].data.is_linked:
		return
	_kies(index)


## De gekozen kaart (koppel-fase): gouden rand, omhoog en bovenop.
func _kies(index: int) -> void:
	var oud := _selected_index
	_selected_index = index
	for i in _cards.size():
		_cards[i].set_selected_visual(i == index)
	_werk_volgorde_bij()
	if oud != index:
		_werk_kaart_bij(oud)
	_werk_kaart_bij(index)


func _on_card_tapped(card: CardView) -> void:
	if phase != Constants.UiPhase.LINKING:
		return
	var index := _cards.find(card)
	if index < 0 or card.data.is_linked:
		return
	Audio.play("card_select")
	_kies(index)
	card_picked.emit(index)

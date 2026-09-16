class_name KoppelPijl
extends Control
## Gebogen pijl van de gesleepte kaart naar je vinger of naar de doelpion
## (16 september, Max: "een drag-en-drop-link die highlight op welk poppetje
## je hem dropt, zeker op mobiel met swipen moet goed zichtbaar zijn welke je
## koppelt, met een soort gebogen arc van een pijl").
##
## Puur beeld: game.gd zet hem met `toon` op elke sleepbeweging en haalt hem
## met `verberg` weg. De boog is een kwadratische bezier met een buik omhoog
## (`boogpunt`, ook gebruikt door de kaart die na het loslaten naar de pion
## vliegt). Streepjes lopen naar de punt toe zodat de richting ook stilstaand
## leest; boven een koppelbare pion wordt hij goud met een pulserende ring om
## de kop, anders de lichte teamkleur. Vangt nooit invoer (MOUSE_FILTER_IGNORE).

const DIKTE := 7.0
const GLOED := 16.0
const STREEP := 18.0
const GAT := 10.0
const KOP := 30.0
const BOL := 9.0
const SNELHEID := 90.0   # pixels per seconde waarmee de streepjes naar de punt lopen

var _van := Vector2.ZERO
var _naar := Vector2.ZERO
var _raak := false
var _kleur := Color.WHITE
var _tijd := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func _process(delta: float) -> void:
	if visible:
		_tijd += delta
		queue_redraw()


## Zet de pijl van `van` (de kaart) naar `naar` (vinger of pion); `raak` =
## er ligt een koppelbare pion onder.
func toon(van: Vector2, naar: Vector2, raak: bool, kleur: Color) -> void:
	_van = van
	_naar = naar
	_raak = raak
	_kleur = kleur
	visible = true
	queue_redraw()


func verberg() -> void:
	visible = false


func is_raak() -> bool:
	return visible and _raak


## Punt op de boog tussen `van` en `naar` bij t in 0..1: kwadratische bezier
## met de buik omhoog, hoger naarmate de afstand groter is.
static func boogpunt(van: Vector2, naar: Vector2, t: float) -> Vector2:
	var buik: float = clampf(van.distance_to(naar) * 0.35, 40.0, 240.0)
	var stuur: Vector2 = (van + naar) * 0.5 + Vector2(0.0, -buik)
	var u: float = 1.0 - t
	return van * (u * u) + stuur * (2.0 * u * t) + naar * (t * t)


func _draw() -> void:
	var kleur: Color = UiAssets.SELECTIE_GOUD if _raak else _kleur
	var stappen := 96
	var punten: PackedVector2Array = []
	var lengtes: PackedFloat32Array = []
	var lengte := 0.0
	for i in stappen + 1:
		var p := boogpunt(_van, _naar, float(i) / float(stappen))
		if i > 0:
			lengte += p.distance_to(punten[i - 1])
		punten.append(p)
		lengtes.append(lengte)
	if lengte < 1.0:
		return
	# Zachte gloed onder de hele boog, zodat hij ook op een drukke ondergrond
	# (het bord, de pionnen) leesbaar blijft.
	draw_polyline(punten, Color(kleur.r, kleur.g, kleur.b, 0.28), DIKTE + GLOED, true)
	# Streepjes die naar de punt toe lopen: per punt het vakje in het
	# streep-gat-ritme, aaneengesloten stukken in hetzelfde vakje als een lijn.
	var ritme := STREEP + GAT
	var offset: float = fmod(_tijd * SNELHEID, ritme)
	var stuk: PackedVector2Array = []
	var stuk_aan := false
	for i in punten.size():
		var aan: bool = fmod(lengtes[i] - offset + ritme * 4.0, ritme) < STREEP
		if aan:
			if not stuk_aan:
				stuk = PackedVector2Array()
				stuk_aan = true
			stuk.append(punten[i])
		elif stuk_aan:
			if stuk.size() >= 2:
				draw_polyline(stuk, kleur, DIKTE, true)
			stuk_aan = false
	if stuk_aan and stuk.size() >= 2:
		draw_polyline(stuk, kleur, DIKTE, true)
	# Kop: driehoek in de richting van de boog aan het eind.
	var richting: Vector2 = (punten[stappen] - punten[stappen - 3]).normalized()
	var dwars := Vector2(-richting.y, richting.x)
	var kop := KOP * (1.15 if _raak else 1.0)
	draw_colored_polygon(PackedVector2Array([
		_naar + richting * kop * 0.35,
		_naar - richting * kop * 0.65 + dwars * kop * 0.55,
		_naar - richting * kop * 0.65 - dwars * kop * 0.55,
	]), kleur)
	# Boven een koppelbare pion: pulserende ring om de kop, zodat je onder je
	# vinger ziet welke pion hem krijgt.
	if _raak:
		var straal: float = 34.0 + 6.0 * sin(_tijd * 7.0)
		draw_arc(_naar, straal, 0.0, TAU, 48, Color(kleur.r, kleur.g, kleur.b, 0.9), 4.0, true)
		draw_arc(_naar, straal + 9.0, 0.0, TAU, 48, Color(kleur.r, kleur.g, kleur.b, 0.35), 3.0, true)
	# Begin: een bolletje op de kaart.
	draw_circle(_van, BOL, kleur)

class_name LedgerScreen
extends Control

# F3.3-rest — het Grootboek: de campagne-boekhouding als sorteerbare tabel.
# Het ledger is bewust volledig openbaar (C-spec, "Among Us-boekhouding"):
# saldi zijn voor iedereen afleidbaar; de fog zit in de duels, niet hier.

const KOLOMMEN := [
	{"key": "naam", "titel": "Naam", "breedte": 168},
	{"key": "team", "titel": "Team", "breedte": 56},
	{"key": "status", "titel": "Status", "breedte": 96},
	{"key": "inf", "titel": "Sold.", "breedte": 56},
	{"key": "cav", "titel": "Cav.", "breedte": 56},
	{"key": "art", "titel": "Kan.", "breedte": 56},
	{"key": "pool", "titel": "Totaal", "breedte": 64},
	{"key": "cp", "titel": "CP", "breedte": 48},
	{"key": "punten", "titel": "Punten", "breedte": 64},
]

var _c: CState
var _mens_id: int = 0
var _kolom: String = "punten"
var _tabel: VBoxContainer
var _headers: HBoxContainer


## Gesorteerde rij-data uit de staat; puur en los testbaar.
static func rijen(c: CState, kolom: String) -> Array:
	var uit: Array = []
	for id in c.spelers:
		var sp: Dictionary = c.spelers[id]
		var pool: Dictionary = c.pool_van(int(id))
		uit.append({"id": int(id), "naam": String(sp.naam), "team": int(sp.team),
			"status": String(sp.status), "inf": int(pool.inf), "cav": int(pool.cav),
			"art": int(pool.art), "pool": c.pool_totaal_van(int(id)),
			"cp": c.cp_van(int(id)), "punten": c.punten_van(int(id))})
	uit.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if kolom == "naam":
			return String(a.naam) < String(b.naam)
		if kolom == "team":
			if int(a.team) != int(b.team):
				return int(a.team) < int(b.team)
			return int(a.id) < int(b.id)
		if kolom == "status":
			if String(a.status) != String(b.status):
				return String(a.status) == "actief"
			return int(a.id) < int(b.id)
		if int(a[kolom]) != int(b[kolom]):
			return int(a[kolom]) > int(b[kolom])
		return int(a.id) < int(b.id))
	return uit


## Bouw het scherm over de hele oppervlakte; sluiten = queue_free.
func open(c: CState, mens_id: int) -> void:
	_c = c
	_mens_id = mens_id
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var achtergrond := ColorRect.new()
	achtergrond.color = Color(0.05, 0.06, 0.09, 0.97)
	achtergrond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(achtergrond)
	var wortel := VBoxContainer.new()
	wortel.name = "Grootboek"
	wortel.set_anchors_preset(Control.PRESET_FULL_RECT)
	wortel.offset_left = 12
	wortel.offset_right = -12
	wortel.offset_top = 10
	wortel.offset_bottom = -10
	wortel.add_theme_constant_override("separation", 8)
	add_child(wortel)
	var kop := HBoxContainer.new()
	var titel := Label.new()
	titel.text = "GROOTBOEK — de campagne-boekhouding"
	titel.add_theme_font_size_override("font_size", 18)
	titel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kop.add_child(titel)
	var sluit := Button.new()
	sluit.name = "GrootboekSluit"
	sluit.text = "Sluiten"
	sluit.pressed.connect(func() -> void: queue_free())
	kop.add_child(sluit)
	wortel.add_child(kop)
	var uitleg := Label.new()
	uitleg.text = "De boekhouding is openbaar: elke donatie, elk verlies en elk testament staat erin. Tik een kolom om te sorteren."
	uitleg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	uitleg.add_theme_font_size_override("font_size", 12)
	uitleg.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	wortel.add_child(uitleg)
	_headers = HBoxContainer.new()
	wortel.add_child(_headers)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wortel.add_child(scroll)
	_tabel = VBoxContainer.new()
	_tabel.name = "GrootboekTabel"
	_tabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_tabel)
	_herbouw()


func _herbouw() -> void:
	for kind in _headers.get_children():
		kind.queue_free()
	for kol in KOLOMMEN:
		var b := Button.new()
		var sleutel: String = String(kol.key)
		b.text = String(kol.titel) + (" v" if sleutel == _kolom else "")
		b.custom_minimum_size = Vector2(int(kol.breedte), 0)
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(func() -> void:
			_kolom = sleutel
			_herbouw())
		_headers.add_child(b)
	for kind in _tabel.get_children():
		kind.queue_free()
	for rij in rijen(_c, _kolom):
		var hbox := HBoxContainer.new()
		var dood: bool = String(rij.status) != "actief"
		var waarden: Array = [
			String(rij.naam) + ("  (jij)" if int(rij.id) == _mens_id else ""),
			str(int(rij.team)),
			"actief" if not dood else "gevallen",
			str(int(rij.inf)), str(int(rij.cav)), str(int(rij.art)),
			str(int(rij.pool)), str(int(rij.cp)), str(int(rij.punten)),
		]
		for i in waarden.size():
			var l := Label.new()
			l.text = String(waarden[i])
			l.custom_minimum_size = Vector2(int(KOLOMMEN[i].breedte), 0)
			l.add_theme_font_size_override("font_size", 13)
			if int(rij.id) == _mens_id:
				l.add_theme_color_override("font_color", Color(0.98, 0.85, 0.4))
			elif dood:
				l.add_theme_color_override("font_color", Color(0.55, 0.5, 0.55))
			hbox.add_child(l)
		_tabel.add_child(hbox)

class_name LedgerScreen
extends Control

# F3.3-rest: het Grootboek: de campagne-boekhouding als sorteerbare tabel.
# Het ledger is bewust volledig openbaar (C-spec, "Among Us-boekhouding"):
# saldi zijn voor iedereen afleidbaar; de fog zit in de duels, niet hier.
#
# UI-assetpack (3 september 2026): een regimentsboek op de veldtafel. Eén
# perkamenten blad (Frame_3) met de kop, de uitleg, de kolomkoppen als
# perkamentknoppen met icoon, en per speler een rij met portret en inkt.
# Jouw rij in diep rood, gevallen spelers in oud bruin met een schedel.
# rijen() is de pure databron en blijft onveranderd (tests).

## "titel" is een vertaalsleutel; tr() gebeurt bij het bouwen van de koppen.
## "icoon" = spec-id op de kolomkop ("" = alleen tekst). Breedtes tellen op
## tot ~930 px: het blad heeft 1040 px, de lijst van Frame_3 eet er ~90 van.
const KOLOMMEN := [
	{"key": "naam", "titel": "LEDGER_COL_NAME", "breedte": 186, "icoon": ""},
	{"key": "team", "titel": "LEDGER_COL_TEAM", "breedte": 120, "icoon": ""},
	{"key": "status", "titel": "LEDGER_COL_STATUS", "breedte": 130, "icoon": "alive"},
	{"key": "inf", "titel": "LEDGER_COL_INF", "breedte": 68, "icoon": "unit-infantry"},
	{"key": "cav", "titel": "LEDGER_COL_CAV", "breedte": 68, "icoon": "unit-cavalry"},
	{"key": "art", "titel": "LEDGER_COL_ART", "breedte": 68, "icoon": "unit-artillery"},
	{"key": "pool", "titel": "LEDGER_COL_TOTAL", "breedte": 80, "icoon": "pool"},
	{"key": "cp", "titel": "LEDGER_COL_CP", "breedte": 68, "icoon": "cp"},
	{"key": "punten", "titel": "LEDGER_COL_POINTS", "breedte": 92, "icoon": "score"},
]
## Tussenruimte tussen de cellen (koppen en rijen gelijk, anders verspringen ze).
const CEL_RUIMTE := 6
## Het portret vóór de naam en de status-icoon: die snoepen van hun kolom.
const PORTRET := 28
const STATUS_ICOON := 24
const RAND := 20.0
## Hoogte van de kolomkoppen (de ronde icoonknop blijft vierkant).
const KOP_HOOGTE := 64

var _c: CState
var _mens_id: int = 0
var _kolom: String = "punten"
var _tabel: VBoxContainer
var _headers: HBoxContainer


## "?" voor wat je niet mag zien (verborgen saldo is als -1 opgeslagen).
static func _getal(rij: Dictionary, sleutel: String) -> String:
	if not bool(rij.get("saldo_zichtbaar", true)):
		return "?"
	return str(int(rij[sleutel]))


## Gesorteerde rij-data uit de staat; puur en los testbaar.
## `kijker` = wie het grootboek opslaat. Voorraad en CP van de VIJAND zijn
## verborgen (spec 6/D12, aangescherpt 30 juli na Max: "bij ieder potje kan je
## wel zien wat de reserve is en de CP van je tegenstander"). Roem blijft
## publiek; wie zelf uitgevallen is ziet alles.
static func rijen(c: CState, kolom: String, kijker: int = -1) -> Array:
	var uit: Array = []
	for id in c.spelers:
		var sp: Dictionary = c.spelers[id]
		var pool: Dictionary = c.pool_van(int(id))
		var zien: bool = kijker < 0 or CView.mag_saldo_zien(c, kijker, int(id))
		uit.append({"id": int(id), "naam": String(sp.naam), "team": int(sp.team),
			"status": String(sp.status),
			"inf": int(pool.inf) if zien else -1, "cav": int(pool.cav) if zien else -1,
			"art": int(pool.art) if zien else -1,
			# Versterkingspunten (soldaat 1, ruiter 2, kanon 3), hetzelfde getal
			# als onder de tent in de hub (27 september; was het aantal stukken).
			"pool": maxi(0, int(pool.inf) + 2 * int(pool.cav) + 3 * int(pool.art)) if zien else -1,
			"cp": c.cp_van(int(id)) if zien else -1,
			"punten": c.punten_van(int(id)), "saldo_zichtbaar": zien})
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


## UI-beweging (30 september): inkom, sorteren en sluiten (scripts/ui/ui_beweging.gd).
const Beweging := preload("res://scripts/ui/ui_beweging.gd")


## Bouw het scherm over de hele oppervlakte; sluiten = queue_free.
func open(c: CState, mens_id: int) -> void:
	_c = c
	_mens_id = mens_id
	# Anchors EN offsets: set_anchors_preset alleen zet de node op zijn
	# minimumgrootte als hij onder een kale Node hangt (capture-flow). Het
	# thema staat op het venster, maar die overerving stopt daar ook: zelf
	# zetten is dezelfde resource.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	theme = UiAssets.thema()
	var achtergrond := ColorRect.new()
	achtergrond.color = UiAssets.VELDTAFEL
	achtergrond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(achtergrond)
	var wortel := VBoxContainer.new()
	wortel.name = "Grootboek"
	wortel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wortel.offset_left = RAND
	wortel.offset_right = -RAND
	wortel.offset_top = RAND
	wortel.offset_bottom = -RAND
	add_child(wortel)
	# Het blad: Frame_3 met smallere inhoudsmarges dan het thema geeft, zodat
	# negen kolommen naast elkaar passen.
	var blad := PanelContainer.new()
	blad.name = "GrootboekBlad"
	blad.theme_type_variation = "PaneelPapier"
	var stijl := UiAssets.paneel_stijl("papier")
	if stijl != null:
		stijl.content_margin_left = 44
		stijl.content_margin_right = 44
		stijl.content_margin_top = 46
		stijl.content_margin_bottom = 46
		blad.add_theme_stylebox_override("panel", stijl)
	blad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wortel.add_child(blad)
	var inhoud := VBoxContainer.new()
	inhoud.add_theme_constant_override("separation", 12)
	blad.add_child(inhoud)
	var kop := HBoxContainer.new()
	kop.add_theme_constant_override("separation", 16)
	var titel := Label.new()
	titel.theme_type_variation = "LabelKopInkt"
	titel.text = tr("LEDGER_TITLE")
	titel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	kop.add_child(titel)
	var sluit := Button.new()
	sluit.name = "GrootboekSluit"
	sluit.theme_type_variation = "KnopBreed"
	sluit.text = tr("LEDGER_CLOSE_BTN")
	sluit.custom_minimum_size = Vector2(220, 84)
	sluit.add_theme_font_size_override("font_size", 22)
	sluit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# UI-beweging: voor de logica meteen weg, voor het oog in 0,12 s.
	sluit.pressed.connect(func() -> void:
		Audio.play("ui_back")
		Beweging.spook_weg(self))
	kop.add_child(sluit)
	inhoud.add_child(kop)
	var uitleg := Label.new()
	uitleg.theme_type_variation = "LabelInkt"
	uitleg.text = tr("LEDGER_EXPLAIN")
	uitleg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	uitleg.add_theme_font_size_override("font_size", 20)
	inhoud.add_child(uitleg)
	_headers = HBoxContainer.new()
	_headers.name = "GrootboekKoppen"
	_headers.add_theme_constant_override("separation", CEL_RUIMTE)
	inhoud.add_child(_headers)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inhoud.add_child(scroll)
	_tabel = VBoxContainer.new()
	_tabel.name = "GrootboekTabel"
	_tabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabel.add_theme_constant_override("separation", 6)
	scroll.add_child(_tabel)
	_herbouw()
	# UI-beweging: het hout faadt over de hub, het blad ploft, de rijen komen
	# erna (samen binnen 0,45 s: de shot kijkt na 0,5 s en telt 16 rijen).
	Audio.play("ui_open")
	Beweging.fade_in(achtergrond, 0.0, Beweging.DIM_DUUR)
	Beweging.inkom_scherm(null, wortel)
	Beweging.inkom_rij(_tabel.get_children(), 0.04, 0.2 / 15.0)


## Kolomkop, zo breed als zijn kolom. Tekstkolommen (naam, team) zijn de
## gewone perkamentknop; de smalle kolommen krijgen de ronde icoonknop
## (KnopRond, vierkant gehouden) met het icoon van het pack, want de
## hoekplaten van de 9-patch passen niet in 68 px. De sorteerkolom staat
## ingedrukt. Tik = sorteren op die kolom.
func _kop_knop(kol: Dictionary) -> Control:
	var b := Button.new()
	var sleutel: String = String(kol.key)
	var icoon_id: String = String(kol.get("icoon", ""))
	var tex: Texture2D = UiAssets.icoon(icoon_id) if icoon_id != "" else null
	b.tooltip_text = tr(String(kol.titel))
	b.toggle_mode = true
	b.button_pressed = sleutel == _kolom
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void:
		_kolom = sleutel
		Audio.play("ui_toggle")
		_herbouw()
		# UI-beweging: de rijen komen kort opnieuw binnen (de oude, al
		# vrijgegeven rijen slaat inkom_rij over).
		Beweging.inkom_rij(_tabel.get_children(), 0.0, 0.01))
	if tex == null:
		b.text = tr(String(kol.titel))
		b.add_theme_font_size_override("font_size", 18)
		b.custom_minimum_size = Vector2(int(kol.breedte), KOP_HOOGTE)
		return b
	b.theme_type_variation = "KnopRond"
	b.icon = tex
	b.expand_icon = false
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", 32)
	b.custom_minimum_size = Vector2(KOP_HOOGTE, KOP_HOOGTE)
	var cel := CenterContainer.new()
	cel.custom_minimum_size = Vector2(int(kol.breedte), KOP_HOOGTE)
	cel.add_child(b)
	return cel


## Een cel: inkt op perkament, getallen gecentreerd, kleur per rij.
static func _cel(tekst: String, breedte: int, kleur: Color, midden: bool) -> Label:
	var l := Label.new()
	l.theme_type_variation = "LabelInkt"
	l.text = tekst
	l.custom_minimum_size = Vector2(breedte, 0)
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", kleur)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if midden:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _herbouw() -> void:
	for kind in _headers.get_children():
		kind.queue_free()
	for kol in KOLOMMEN:
		_headers.add_child(_kop_knop(kol))
	for kind in _tabel.get_children():
		kind.queue_free()
	var mijn_team: int = int(_c.spelers.get(_mens_id, {}).get("team", 0))
	for rij in rijen(_c, _kolom, _mens_id):
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", CEL_RUIMTE)
		var dood: bool = String(rij.status) != "actief"
		var kleur: Color = UiAssets.INKT
		if int(rij.id) == _mens_id:
			kleur = UiAssets.DIEP_ROOD
		elif dood:
			kleur = UiAssets.OUD_BRUIN
		# Het schild uit de hub vóór de naam (blauw = jouw team, rood = de
		# vijand); de doctrine komt apart uit de staat, rijen() blijft zoals de
		# tests hem kennen.
		var doctrine: int = int(_c.spelers.get(int(rij.id), {}).get("doctrine", 0))
		var eigen: bool = int(rij.team) == mijn_team
		var portret := HubAssets.portret(doctrine, eigen, dood, PORTRET)
		portret.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(portret)
		hbox.add_child(_cel(String(rij.naam) + (tr("LEDGER_YOU_SUFFIX") if int(rij.id) == _mens_id else ""),
			int(KOLOMMEN[0].breedte) - PORTRET - CEL_RUIMTE, kleur, false))
		# Jouw team of de vijand, in de kleur van de kolommen in de hub.
		var team_cel := _cel(tr("LEDGER_TEAM_OWN") if eigen else tr("LEDGER_TEAM_ENEMY"),
			int(KOLOMMEN[1].breedte), kleur if dood else (HubAssets.BLAUW if eigen else HubAssets.ROOD), true)
		hbox.add_child(team_cel)
		var status_icoon := UiAssets.icoon_rect("dead" if dood else "alive", STATUS_ICOON, kleur)
		status_icoon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(status_icoon)
		hbox.add_child(_cel(tr("LEDGER_STATUS_FALLEN") if dood else tr("LEDGER_STATUS_ACTIVE"),
			int(KOLOMMEN[2].breedte) - STATUS_ICOON - CEL_RUIMTE, kleur, false))
		hbox.add_child(_cel(_getal(rij, "inf"), int(KOLOMMEN[3].breedte), kleur, true))
		hbox.add_child(_cel(_getal(rij, "cav"), int(KOLOMMEN[4].breedte), kleur, true))
		hbox.add_child(_cel(_getal(rij, "art"), int(KOLOMMEN[5].breedte), kleur, true))
		hbox.add_child(_cel(_getal(rij, "pool"), int(KOLOMMEN[6].breedte), kleur, true))
		hbox.add_child(_cel(_getal(rij, "cp"), int(KOLOMMEN[7].breedte), kleur, true))
		hbox.add_child(_cel(str(int(rij.punten)), int(KOLOMMEN[8].breedte), kleur, true))
		_tabel.add_child(hbox)

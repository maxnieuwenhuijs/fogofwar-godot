extends Control

## Het inzet-scherm (10 november): CP-bod en versterkingen in EEN compact
## scherm met plus en min. Max: "less is more, te veel tekst en te vaag wat is
## wat. Je kan er ook 1 scherm van maken met CP en een plus of min, en
## daaronder reinforcements -1+ per categorie."
##
## Het ziet eruit als de legerbouwer (leger_bouwer.gd; Max: "legerbouw is ook
## goed voor in game the cp en reinforcements scherm, die stijl is goed"):
## hetzelfde perkament, dezelfde rij (icoon, naam met de prijs erachter, de
## min en plus van de kaarten, het cijfer ertussen), dezelfde vette stand en
## dezelfde groene knop met het vinkje. Wie hier iets aan de vorm verandert,
## verandert het daar ook.
##
##              CP 2/4        Versterkingen 5/6          <- je totaal, nu/vol
##   [medaille]  CP inzetten                 [-]  2  [+]
##               +1 kaartbudget per CP
##   ---------------------------------------------------
##   [soldaat]   Soldaat (1 pt)              [-]  1  [+]
##   [ruiter]    Big bro (2 pt)              [-]  0  [+]
##   [kanon]     Kanon (3 pt)                [-]  0  [+]
##                  nog 1 deze cyclus
##                     [ v  KLAAR ]
##
## Bovenaan staat wat je hebt (Max: "bovenaan het kaartje zie je totaal CP en
## totaal reinforcement"), als nu/vol zoals op het pionpaneel: het loopt mee
## terwijl je kiest.
##
## Welke helft er staat hangt van het moment af: aan het begin van een cyclus
## (de versterkingsfase) allebei, voor de tweede en derde ronde alleen CP,
## zonder CP-saldo alleen de versterkingen. Het scherm kiest niets zelf: het
## telt, en geeft bij KLAAR de CP-inzet en de gekozen types (in de volgorde
## waarin je ze koos) terug aan game.gd.
##
##   _inzet = INZET_SCHERM.new()
##   $UI.add_child(_inzet)
##   _inzet.open({"cp": {"saldo": 4, "max": 3},
##                "spawn": {"punten": 6, "cap": 2, "kosten": [1, 2, 3], "types": [0, 1]}},
##                func(cp: int, keuze: Array) -> void: ...)
##
## Voor de checks: stand(), druk_cp(+1/-1), druk_type(type, +1/-1), druk_klaar().

const Beweging := preload("res://scripts/ui/ui_beweging.gd")

## De maten van de legerbouwer.
const PANEEL_BREEDTE := 900.0
const ICOON := 64.0
const NAAM_BREEDTE := 330.0
const KNOP := Vector2(72.0, 72.0)
const GETAL_BREEDTE := 90.0
const KLAAR_MAAT := Vector2(600.0, 96.0)
## Per type: [icoon, naam], dezelfde namen als in de legerbouwer.
const TYPEN := [
	["unit-infantry", "STRAT_TYPE_INF"],
	["unit-cavalry", "STRAT_TYPE_CAV"],
	["unit-artillery", "STRAT_TYPE_ART"],
]

var cp: int = 0
var keuze: Array = []            # gekozen types, in de volgorde van kopen
var delen: Array = []            # "cp" en/of "spawn": wat er nu staat

var _cp_opties: Dictionary = {}
var _spawn_opties: Dictionary = {}
var _klaar: Callable = Callable()
var _geldig: Callable = Callable()   # nog het goede moment? anders sluit het scherm zichzelf
var _dim: ColorRect = null
var _midden: CenterContainer = null
var _inhoud: VBoxContainer = null
var _cp_getal: Label = null
var _cp_min: Button = null
var _cp_plus: Button = null
var _spawn_onder: Label = null
var _totaal_cp: Label = null       # "CP 2/4": wat er van je CP over is / wat je had
var _totaal_punten: Label = null   # "Versterkingen 5/6": punten over / die je had
var _stand_cp: String = ""         # alleen de breuk ("2/4"), voor stand()
var _stand_punten: String = ""
var _rijen: Dictionary = {}        # type -> {getal, min, plus}
var _klaar_knop: Button = null


func _init() -> void:
	name = "InzetScherm"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.62)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	_midden = CenterContainer.new()
	_midden.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_midden.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_midden)


## Open het scherm. opties: {"cp": {saldo, max}, "spawn": {punten, cap,
## kosten, types}}; een helft die ontbreekt of leeg is staat er niet.
## klaar.call(cp, keuze) bij KLAAR (cp = 0 als de CP-helft er niet stond).
## geldig.call() -> bool: is dit nog het moment? Zo niet (de fase schoof door
## via een timeout, een opgave, het einde), dan gaat het scherm vanzelf dicht.
func open(opties: Dictionary, klaar: Callable, geldig: Callable = Callable()) -> void:
	var vers: bool = not visible
	_cp_opties = opties.get("cp", {})
	_spawn_opties = opties.get("spawn", {})
	_klaar = klaar
	_geldig = geldig
	cp = 0
	keuze = []
	delen = []
	if not _cp_opties.is_empty() and int(_cp_opties.get("max", 0)) > 0:
		delen.append("cp")
	if not _spawn_opties.is_empty():
		delen.append("spawn")
	_bouw()
	visible = true
	_ververs()
	if vers:
		Audio.play("ui_open")
		Beweging.inkom_scherm(_dim, _midden)


func sluit() -> void:
	if not visible:
		return
	visible = false
	Beweging.meld_weg()


func _process(_delta: float) -> void:
	if visible and _geldig.is_valid() and not bool(_geldig.call()):
		sluit()


func _label(variant: String, grootte: int, tekst: String = "") -> Label:
	var l := Label.new()
	l.theme_type_variation = variant
	l.add_theme_font_size_override("font_size", grootte)
	l.text = tekst
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## De min of plus van de kaarten ("KnopMin" / "KnopPlus").
func _stap_knop(variant: String) -> Button:
	var b := Button.new()
	b.theme_type_variation = variant
	b.custom_minimum_size = KNOP
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


## Een rij zoals in de legerbouwer: icoon, naam, min, cijfer, plus. `onder` is
## een klein regeltje onder de naam (alleen bij de CP: wat een punt oplevert).
func _rij(icoon_id: String, naam: String, onder: String = "") -> Dictionary:
	var rij := HBoxContainer.new()
	rij.add_theme_constant_override("separation", 18)
	rij.alignment = BoxContainer.ALIGNMENT_CENTER
	var icoon := UiAssets.icoon_rect(icoon_id, ICOON, UiAssets.INKT)
	icoon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rij.add_child(icoon)
	var kolom := VBoxContainer.new()
	kolom.custom_minimum_size = Vector2(NAAM_BREEDTE, 0.0)
	kolom.alignment = BoxContainer.ALIGNMENT_CENTER
	kolom.add_theme_constant_override("separation", -6)
	kolom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kolom.add_child(_label("LabelInkt", 28, naam))
	if onder != "":
		kolom.add_child(_label("LabelInktZacht", 20, onder))
	rij.add_child(kolom)
	var minknop := _stap_knop("KnopMin")
	rij.add_child(minknop)
	var getal := _label("LabelCijfer", 44, "0")
	getal.custom_minimum_size = Vector2(GETAL_BREEDTE, 0.0)
	getal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	getal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rij.add_child(getal)
	var plusknop := _stap_knop("KnopPlus")
	rij.add_child(plusknop)
	_inhoud.add_child(rij)
	return {"rij": rij, "getal": getal, "min": minknop, "plus": plusknop}


func _lijn() -> void:
	var l := ColorRect.new()
	l.color = Color(UiAssets.INKT, 0.22)
	l.custom_minimum_size = Vector2(0.0, 2.0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inhoud.add_child(l)


func _bouw() -> void:
	for kind in _midden.get_children():
		_midden.remove_child(kind)
		kind.queue_free()
	_rijen = {}
	_cp_getal = null
	_spawn_onder = null
	_totaal_cp = null
	_totaal_punten = null
	_stand_cp = ""
	_stand_punten = ""
	var paneel := PanelContainer.new()
	paneel.name = "Paneel"
	paneel.theme_type_variation = "PaneelVeldtafel"
	paneel.custom_minimum_size = Vector2(PANEEL_BREEDTE, 0.0)
	_midden.add_child(paneel)
	_inhoud = VBoxContainer.new()
	_inhoud.add_theme_constant_override("separation", 16)
	paneel.add_child(_inhoud)
	# bovenaan: wat je hebt, als de stand van de legerbouwer
	var totaal := HBoxContainer.new()
	totaal.name = "Totaal"
	totaal.alignment = BoxContainer.ALIGNMENT_CENTER
	totaal.add_theme_constant_override("separation", 48)
	_inhoud.add_child(totaal)
	if delen.has("cp"):
		_totaal_cp = _label("LabelKopInkt", 34)
		totaal.add_child(_totaal_cp)
	if delen.has("spawn"):
		_totaal_punten = _label("LabelKopInkt", 34)
		totaal.add_child(_totaal_punten)
	if delen.has("cp"):
		var r: Dictionary = _rij("cp", tr("INZET_CP_TITLE"), tr("INZET_CP_SUB"))
		_cp_getal = r.getal
		_cp_min = r.min
		_cp_plus = r.plus
		_cp_min.name = "CpMin"
		_cp_plus.name = "CpPlus"
		_cp_min.pressed.connect(func() -> void: druk_cp(-1))
		_cp_plus.pressed.connect(func() -> void: druk_cp(1))
	if delen.has("cp") and delen.has("spawn"):
		_lijn()
	if delen.has("spawn"):
		for t in _spawn_opties.get("types", []):
			var type: int = int(t)
			var soort: Array = TYPEN[clampi(type, 0, 2)]
			var r: Dictionary = _rij(String(soort[0]),
				tr("STRAT_TYPE_PRICE") % [tr(String(soort[1])), int(_spawn_opties.kosten[type])])
			(r.min as Button).name = "Min_%d" % type
			(r.plus as Button).name = "Plus_%d" % type
			(r.min as Button).pressed.connect(func() -> void: druk_type(type, -1))
			(r.plus as Button).pressed.connect(func() -> void: druk_type(type, 1))
			_rijen[type] = r
		_spawn_onder = _label("LabelInktZacht", 22)
		_spawn_onder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_inhoud.add_child(_spawn_onder)
	_klaar_knop = Button.new()
	_klaar_knop.name = "KlaarKnop"
	_klaar_knop.theme_type_variation = "KnopBevestig"
	_klaar_knop.text = tr("INZET_KLAAR")
	_klaar_knop.custom_minimum_size = KLAAR_MAAT
	_klaar_knop.add_theme_font_size_override("font_size", 28)
	_klaar_knop.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_klaar_knop.focus_mode = Control.FOCUS_NONE
	var vink := UiAssets.icoon("check")
	if vink != null:
		_klaar_knop.icon = vink
		_klaar_knop.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_klaar_knop.expand_icon = false
		_klaar_knop.add_theme_constant_override("icon_max_width", 48)
	_klaar_knop.pressed.connect(druk_klaar)
	_inhoud.add_child(_klaar_knop)


func _besteed() -> int:
	var som := 0
	for t in keuze:
		som += int(_spawn_opties.kosten[int(t)])
	return som


func punten_over() -> int:
	return int(_spawn_opties.get("punten", 0)) - _besteed()


func _mag_kopen(type: int) -> bool:
	return keuze.size() < int(_spawn_opties.get("cap", 0)) \
		and punten_over() >= int(_spawn_opties.kosten[type])


func _ververs() -> void:
	if _cp_getal != null:
		_cp_getal.text = str(cp)
		var saldo: int = int(_cp_opties.get("saldo", 0))
		_stand_cp = "%d/%d" % [saldo - cp, saldo]
		_zet_totaal(_totaal_cp, "%s %s" % [tr("INZET_CHIP_CP"), _stand_cp])
		_cp_min.disabled = cp <= 0
		_cp_plus.disabled = cp >= int(_cp_opties.get("max", 0))
	if _spawn_onder != null:
		_spawn_onder.text = tr("INZET_SPAWN_SUB") % (int(_spawn_opties.get("cap", 0)) - keuze.size())
		_stand_punten = "%d/%d" % [punten_over(), int(_spawn_opties.get("punten", 0))]
		_zet_totaal(_totaal_punten, "%s %s" % [tr("PHASE_SPAWN_TITLE"), _stand_punten])
		for type in _rijen:
			var r: Dictionary = _rijen[type]
			(r.getal as Label).text = str(keuze.count(type))
			(r.min as Button).disabled = keuze.count(type) <= 0
			(r.plus as Button).disabled = not _mag_kopen(int(type))


## Het totaal bovenaan bijwerken; verandert het, dan springt het even op.
func _zet_totaal(l: Label, tekst: String) -> void:
	if l == null or l.text == tekst:
		return
	var leeg: bool = l.text == ""
	l.text = tekst
	if not leeg:
		Beweging.punch(l, 1.12)


func druk_cp(stap: int) -> void:
	if not delen.has("cp"):
		return
	var nieuw: int = clampi(cp + stap, 0, int(_cp_opties.get("max", 0)))
	if nieuw == cp:
		return
	cp = nieuw
	_ververs()
	Audio.play("ui_click")
	Beweging.punch(_cp_getal, 1.25)


func druk_type(type: int, stap: int) -> void:
	if not _rijen.has(type):
		return
	if stap > 0:
		if not _mag_kopen(type):
			return
		keuze.append(type)
	else:
		var i: int = keuze.rfind(type)
		if i < 0:
			return
		keuze.remove_at(i)
	_ververs()
	Audio.play("ui_click")
	Beweging.punch(_rijen[type].getal, 1.25)


func druk_klaar() -> void:
	if not visible:
		return
	var uit_cp: int = cp if delen.has("cp") else 0
	var uit_keuze: Array = keuze.duplicate()
	Audio.play("ui_click")
	sluit()
	if _klaar.is_valid():
		_klaar.call(uit_cp, uit_keuze)


func stand() -> Dictionary:
	var plussen: Dictionary = {}
	for type in _rijen:
		plussen[int(type)] = not (_rijen[type].plus as Button).disabled
	return {
		"zichtbaar": visible,
		"delen": delen.duplicate(),
		"cp": cp,
		"cp_max": int(_cp_opties.get("max", 0)) if delen.has("cp") else 0,
		"keuze": keuze.duplicate(),
		"punten_over": punten_over() if delen.has("spawn") else 0,
		"types": _rijen.keys(),
		"totaal_cp": _stand_cp,
		"totaal_punten": _stand_punten,
		"plus_aan": plussen,
	}

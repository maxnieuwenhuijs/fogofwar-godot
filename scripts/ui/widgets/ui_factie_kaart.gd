class_name UiFactieKaart
extends Button

## Een factie als "regimentskaart" om te kiezen (brief §6: 6 regiment-kaarten
## met embleem, comp, kaarten x budget en pro/con). Gebruikt door het
## doctrine-menu en het tegenstander-menu op het bord en door de factiekeuze
## in de campagne-hub. Het is een Button (theme-variant KnopGroot) met de
## inhoud eroverheen; de inhoud negeert de muis, dus tikken werkt overal.
##
##   var k := UiFactieKaart.new(doctrine, CRules.actieve_tabel().doctrine_data(doctrine))
##   k.pressed.connect(...)
##   k.gekozen(true)   # goud randje (bv. huidige keuze)

var doctrine: int = Constants.Doctrine.MENS
var portret: UiPortret
var _rand: Panel


func _init(p_doctrine: int, data: Dictionary, toon_procon: bool = true) -> void:
	doctrine = p_doctrine
	theme_type_variation = "KnopGroot"
	text = ""
	custom_minimum_size = Vector2(0, 210)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_NONE
	var marge := MarginContainer.new()
	marge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marge.add_theme_constant_override("margin_left", 52)
	marge.add_theme_constant_override("margin_right", 52)
	marge.add_theme_constant_override("margin_top", 30)
	marge.add_theme_constant_override("margin_bottom", 26)
	add_child(marge)
	var rij := HBoxContainer.new()
	rij.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rij.add_theme_constant_override("separation", 22)
	marge.add_child(rij)
	portret = UiPortret.new(140)
	portret.zet(doctrine, "")
	portret.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rij.add_child(portret)
	var kolom := VBoxContainer.new()
	kolom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kolom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kolom.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kolom.add_theme_constant_override("separation", 4)
	rij.add_child(kolom)
	var naam := Label.new()
	naam.theme_type_variation = "LabelKopInkt"
	naam.text = Constants.doctrine_display_name(doctrine).to_upper()
	naam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kolom.add_child(naam)
	var comp: Array = data.get("comp", [0, 0, 0])
	var feiten := HBoxContainer.new()
	feiten.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feiten.add_theme_constant_override("separation", 18)
	var kaarten := UiIcoonTekst.new("phase-define",
		tr("UI_FACTION_CARDS") % [int(data.get("cards", 3)), int(data.get("budget", 7))], 26, UiAssets.INKT)
	kaarten.label.add_theme_font_size_override("font_size", 20)
	feiten.add_child(kaarten)
	var types := [["unit-infantry", int(comp[0])], ["unit-cavalry", int(comp[1])], ["unit-artillery", int(comp[2])]]
	for tp in types:
		var eenheid := UiIcoonTekst.new(String(tp[0]), str(int(tp[1])), 26, UiAssets.INKT)
		eenheid.label.add_theme_font_size_override("font_size", 20)
		feiten.add_child(eenheid)
	kolom.add_child(feiten)
	if toon_procon:
		var pro := Label.new()
		pro.theme_type_variation = "LabelInkt"
		pro.text = "+ " + Constants.doctrine_pro(doctrine)
		pro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pro.add_theme_font_size_override("font_size", 18)
		pro.mouse_filter = Control.MOUSE_FILTER_IGNORE
		kolom.add_child(pro)
		var con := Label.new()
		con.theme_type_variation = "LabelInktZacht"
		con.text = "- " + Constants.doctrine_con(doctrine)
		con.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		con.add_theme_font_size_override("font_size", 18)
		con.mouse_filter = Control.MOUSE_FILTER_IGNORE
		kolom.add_child(con)
	# Gouden selectierand (Selection Gold Light), standaard onzichtbaar.
	_rand = Panel.new()
	_rand.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = UiAssets.SELECTIE_GOUD
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(UiAssets.SELECTIE_GOUD, 0.45)
	sb.shadow_size = 14
	_rand.add_theme_stylebox_override("panel", sb)
	_rand.visible = false
	add_child(_rand)


## Goud randje aan/uit (huidige of gemaakte keuze).
func gekozen(aan: bool) -> void:
	_rand.visible = aan

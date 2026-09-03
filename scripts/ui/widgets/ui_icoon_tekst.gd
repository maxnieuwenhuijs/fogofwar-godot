class_name UiIcoonTekst
extends HBoxContainer

## Icoon + tekst op een rij: "iconen boven tekst" (brief §1) in een handzaam
## bouwsteentje. Ontbreekt het icoon (nog niet geleverd), dan staat er alleen
## tekst; niets breekt.
##
##   var r := UiIcoonTekst.new("pool", "12", 28, UiAssets.INKT)
##   r.zet("cp", "3")
##   r.label.add_theme_font_size_override("font_size", 24)

var icoon: TextureRect
var label: Label


func _init(icoon_id: String = "", tekst: String = "", grootte: float = 28.0,
		kleur: Color = UiAssets.WARM_IVOOR) -> void:
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	icoon = UiAssets.icoon_rect(icoon_id, grootte, kleur)
	add_child(icoon)
	label = Label.new()
	label.text = tekst
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", kleur)
	add_child(label)


func zet(icoon_id: String, tekst: String) -> void:
	icoon.texture = UiAssets.icoon(icoon_id)
	icoon.visible = icoon.texture != null
	label.text = tekst


func zet_tekst(tekst: String) -> void:
	label.text = tekst


func zet_kleur(kleur: Color) -> void:
	icoon.modulate = kleur
	label.add_theme_color_override("font_color", kleur)

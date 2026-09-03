class_name BracketView
extends VBoxContainer

# F3.3-rest: de burgeroorlog zichtbaar: wie vecht nu, wie wacht in de
# wachtrij, wie leeft nog. Leest alleen de (openbare) campagne-staat.
#
# UI-assetpack (3 september 2026): staat op de veldtafel, dus ivoor. De kop
# draagt de gekruiste sabels; de duels van nu in vol ivoor, de wachtrij en
# de voetregel gedempt. De duel-regels blijven Labels met "vs" erin (capture).

## Gedempt ivoor voor wat nog niet aan de beurt is.
const IVOOR_ZACHT := Color(UiAssets.WARM_IVOOR, 0.85)


func vul(c: CState) -> void:
	for kind in get_children():
		kind.queue_free()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	theme = UiAssets.thema()  # zelfde resource als op het venster; ook los onder een Node
	add_theme_constant_override("separation", 6)
	var kop := HBoxContainer.new()
	kop.add_theme_constant_override("separation", 12)
	var sabels := UiAssets.icoon_rect("act-melee", 32, UiAssets.WARM_IVOOR)
	sabels.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kop.add_child(sabels)
	var titel := Label.new()
	titel.theme_type_variation = "LabelKop"
	titel.text = tr("BRACKET_TITLE")
	titel.add_theme_font_size_override("font_size", 30)
	titel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kop.add_child(titel)
	add_child(kop)
	for duel in c.duels_deze_ronde:
		var r := Label.new()
		var status := tr("BRACKET_DONE") if bool(duel.klaar) else tr("BRACKET_NOW_PLAYING")
		r.text = tr("BRACKET_DUEL_ROW") % [String(c.spelers[int(duel.p1)].naam),
			String(c.spelers[int(duel.p2)].naam), status]
		r.add_theme_font_size_override("font_size", 22)
		if bool(duel.klaar):
			r.add_theme_color_override("font_color", IVOOR_ZACHT)
		add_child(r)
	for paar in c.bracket:
		var w := Label.new()
		w.text = tr("BRACKET_QUEUE_ROW") % [String(c.spelers[int(paar[0])].naam),
			String(c.spelers[int(paar[1])].naam)]
		w.add_theme_font_size_override("font_size", 22)
		w.add_theme_color_override("font_color", IVOOR_ZACHT)
		add_child(w)
	var over: Array = []
	for id in c.spelers:
		if String(c.spelers[id].status) == "actief":
			over.append(String(c.spelers[id].naam))
	var voet := Label.new()
	voet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	voet.add_theme_font_size_override("font_size", 22)
	voet.add_theme_color_override("font_color", IVOOR_ZACHT)
	voet.text = tr("BRACKET_REMAINING") % ", ".join(over)
	add_child(voet)

class_name BracketView
extends VBoxContainer

# F3.3-rest — de burgeroorlog zichtbaar: wie vecht nu, wie wacht in de
# wachtrij, wie leeft nog. Leest alleen de (openbare) campagne-staat.


func vul(c: CState) -> void:
	for kind in get_children():
		kind.queue_free()
	var titel := Label.new()
	titel.text = tr("BRACKET_TITLE")
	titel.add_theme_font_size_override("font_size", 16)
	titel.add_theme_color_override("font_color", Color(1.0, 0.6, 0.4))
	add_child(titel)
	for duel in c.duels_deze_ronde:
		var r := Label.new()
		var status := tr("BRACKET_DONE") if bool(duel.klaar) else tr("BRACKET_NOW_PLAYING")
		r.text = tr("BRACKET_DUEL_ROW") % [String(c.spelers[int(duel.p1)].naam),
			String(c.spelers[int(duel.p2)].naam), status]
		add_child(r)
	for paar in c.bracket:
		var w := Label.new()
		w.text = tr("BRACKET_QUEUE_ROW") % [String(c.spelers[int(paar[0])].naam),
			String(c.spelers[int(paar[1])].naam)]
		w.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
		add_child(w)
	var over: Array = []
	for id in c.spelers:
		if String(c.spelers[id].status) == "actief":
			over.append(String(c.spelers[id].naam))
	var voet := Label.new()
	voet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	voet.add_theme_font_size_override("font_size", 12)
	voet.text = tr("BRACKET_REMAINING") % ", ".join(over)
	add_child(voet)

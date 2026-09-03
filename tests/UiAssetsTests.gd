extends TestSuite

# UI-assetpack (3 september 2026): elk concept uit de spec vindt zijn bestand,
# de zes emblemen zijn er, de 9-patch-marges passen in hun texture, het thema
# bouwt met alle varianten, en de gedeelde widgets komen zonder scene tot
# leven. Verhuis je bestanden onder assets/ui, dan bewaakt dit dat niets
# stilletjes wegvalt.


func _class_name() -> String:
	return "UiAssetsTests"


func test_alle_bekende_iconen_laden() -> void:
	for id in UiAssets.icoon_ids():
		assert_true(UiAssets.icoon(String(id)) != null, "icoon " + String(id))


func test_ontbrekende_iconen_zijn_precies_de_gemelde() -> void:
	var ontbreekt: Array = UiAssets.ontbrekende_iconen()
	var verwacht: Array = UiAssets.NOG_NIET_GELEVERD.duplicate()
	verwacht.sort()
	assert_eq(ontbreekt, verwacht, "alleen de acht campagne/tijd-iconen ontbreken")
	assert_true(UiAssets.icoon("vote") == null, "niet-geleverd icoon geeft null")
	assert_true(UiAssets.icoon("bestaat-niet") == null, "onbekend id geeft null")


func test_fase_iconen_dekken_alle_fasen() -> void:
	for phase in [Phase.Type.PLACEMENT, Phase.Type.ACTION, Phase.Type.CYCLE_SPAWN, Phase.Type.GAME_OVER]:
		var id := UiAssets.fase_icoon_id(phase)
		assert_true(id != "" and UiAssets.icoon(id) != null, "fase %d" % phase)


func test_embleem_per_factie_en_uniek() -> void:
	var paden: Dictionary = {}
	for d in Constants.DOCTRINE_DATA.keys():
		var tex := UiAssets.embleem(int(d))
		assert_true(tex != null, "embleem factie %d" % int(d))
		if tex != null:
			paden[tex.resource_path] = true
	assert_eq(paden.size(), 6, "zes verschillende emblemen")


func test_krokodil_typo_in_pack_wordt_herkend() -> void:
	# Het pack heet 'Croccodile.png'; een verbeterde drop 'Crocodile.png' werkt ook.
	assert_true(UiAssets.embleem(Constants.Doctrine.VOS) != null)
	assert_true(UiAssets.knop_stijl("breed", "geblokkeerd") != null, "button_2_bloccked")
	assert_true(UiAssets.knop_stijl("rood", "geblokkeerd") != null, "button_5_bloccked")


func test_kaartdelen_aanwezig() -> void:
	for deel in UiAssets.KAART.keys():
		assert_true(UiAssets.kaart(String(deel)) != null, "kaartdeel " + String(deel))


func test_knopstijlen_marges_passen_in_texture() -> void:
	for variant in UiAssets.KNOPPEN.keys():
		for staat in UiAssets.KNOP_STATEN.keys():
			var sb := UiAssets.knop_stijl(String(variant), String(staat))
			assert_true(sb != null, "knop %s/%s" % [variant, staat])
			if sb == null:
				continue
			var maat: Vector2 = sb.texture.get_size()
			assert_true(sb.texture_margin_left * 2 < maat.x, "marge x past: %s" % variant)
			assert_true(sb.texture_margin_top * 2 < maat.y, "marge y past: %s" % variant)
			assert_true(sb.get_content_margin(SIDE_LEFT) >= 0, "inhoudsmarge gezet")


func test_paneelstijlen_marges_passen_in_texture() -> void:
	for naam in UiAssets.PANELEN.keys():
		var sb := UiAssets.paneel_stijl(String(naam))
		assert_true(sb != null, "paneel " + String(naam))
		if sb == null:
			continue
		var maat: Vector2 = sb.texture.get_size()
		assert_true(sb.texture_margin_left * 2 < maat.x, "marge x past: %s" % naam)
		assert_true(sb.texture_margin_top * 2 < maat.y, "marge y past: %s" % naam)


func test_fonts_in_repo_laden() -> void:
	# Roboto Slab (Regular + Bold) zit in de repo; Rye en SemiBold zijn een
	# latere drop. Het thema mag daar nooit op stuklopen.
	assert_true(UiAssets.font("tekst") != null, "tekstfont")
	assert_true(UiAssets.font("kop") != null, "kopfont")
	assert_true(UiAssets.font("cijfers") != null, "cijferfont (terugval op Roboto Slab Bold)")
	assert_true(UiAssets.font_bron("tekst") != "", "bron van het tekstfont")


func test_thema_bouwt_met_alle_varianten() -> void:
	var t := UiAssets.thema()
	assert_true(t != null)
	assert_true(t.has_stylebox("normal", "Button"), "Button normal")
	assert_true(t.has_stylebox("pressed", "Button"), "Button pressed")
	assert_true(t.has_stylebox("disabled", "Button"), "Button disabled")
	for variant in ["KnopGroot", "KnopBreed", "KnopKleinBreed", "KnopRood", "KnopRond", "KnopVierkant", "KnopPlus", "KnopMin"]:
		assert_eq(String(t.get_type_variation_base(variant)), "Button", variant)
		assert_true(t.has_stylebox("normal", variant), variant + " normal")
	for variant in ["PaneelBalk", "PaneelVeldtafel", "PaneelPapier", "PaneelNaamplaat", "PaneelSpecs",
			"PaneelSpecsNaam", "PaneelPerkament", "PaneelDonker", "PaneelKaartjeRood", "PaneelKaartjeBlauw"]:
		assert_eq(String(t.get_type_variation_base(variant)), "PanelContainer", variant)
		assert_true(t.has_stylebox("panel", variant), variant + " panel")
	for variant in ["LabelInkt", "LabelInktZacht", "LabelKop", "LabelKopInkt", "LabelCijfer", "LabelCijferIvoor"]:
		assert_eq(String(t.get_type_variation_base(variant)), "Label", variant)
		assert_true(t.has_color("font_color", variant), variant + " kleur")
	assert_true(t.has_color("default_color", "RichInkt"), "RichInkt")
	assert_true(t.has_icon("checked", "CheckBox"), "lakzegel-vinkje")
	assert_true(t.default_font != null, "default_font uit assets/ui/fonts")
	assert_true(UiAssets.thema() == t, "thema wordt gecachet")


func test_knoptekst_inkt_op_perkament_ivoor_op_donker() -> void:
	var t := UiAssets.thema()
	assert_eq(t.get_color("font_color", "Button"), UiAssets.INKT)
	assert_eq(t.get_color("font_color", "KnopRood"), UiAssets.WARM_IVOOR)
	assert_eq(t.get_color("font_color", "KnopRond"), UiAssets.WARM_IVOOR)


func test_teamkleuren_verschillen_en_volgen_de_seat() -> void:
	assert_true(UiAssets.team_kleur(Constants.PLAYER_1) != UiAssets.team_kleur(Constants.PLAYER_2))
	assert_eq(UiAssets.team_naam(Constants.PLAYER_1), "rood")
	assert_eq(UiAssets.team_naam(Constants.PLAYER_2), "blauw")
	assert_true(UiAssets.kaart("lint_" + UiAssets.team_naam(Constants.PLAYER_2)) != null)
	var rood := UiAssets.kaartje_stijl(Constants.PLAYER_1)
	assert_eq(rood.border_width_left, 8, "teamrand links")
	assert_eq(rood.border_color, UiAssets.TEAM_ROOD)


func test_kaartmaten_liggen_binnen_het_frame() -> void:
	var frame := UiAssets.kaart("frame")
	assert_true(frame != null)
	if frame != null:
		assert_eq(frame.get_size(), UiAssets.KAART_MAAT, "frame is 645x989")
	for x in UiAssets.KAART_SPECS_X:
		assert_true(float(x) + 169.0 <= UiAssets.KAART_MAAT.x, "specs-kolom binnen de kaart")
	assert_true(UiAssets.KAART_CP_MIDDEN.y < UiAssets.KAART_MAAT.y)
	# Het losse lint en het lint-met-zegel zetten hun strook op dezelfde x.
	assert_eq(UiAssets.KAART_LINT_X - UiAssets.KAART_GEKOPPELD_X, 57.0, "lintstrook uitgelijnd")


func test_widgets_bouwen_zonder_scene() -> void:
	var p := UiPortret.new(64)
	p.zet(Constants.Doctrine.WOLF, "blauw", true)
	assert_true(p.get_child_count() == 3, "portret: krans, embleem, dood")
	p.free()
	var r := UiIcoonTekst.new("cp", "3", 24, UiAssets.INKT)
	assert_eq(r.label.text, "3")
	assert_true(r.icoon.visible, "cp-icoon zichtbaar")
	r.zet("vote", "stem")
	assert_false(r.icoon.visible, "niet-geleverd icoon verbergt zich, tekst blijft")
	assert_eq(r.label.text, "stem")
	r.free()
	var tabel := CRules.actieve_tabel()
	for d in Constants.DOCTRINE_DATA.keys():
		var k := UiFactieKaart.new(int(d), tabel.doctrine_data(int(d)))
		assert_eq(k.doctrine, int(d))
		assert_eq(String(k.theme_type_variation), "KnopGroot")
		k.gekozen(true)
		k.free()


func test_icoon_rect_is_getint_en_houdt_aspect() -> void:
	var rect := UiAssets.icoon_rect("stat-hp", 32, UiAssets.INKT)
	assert_true(rect.texture != null)
	assert_eq(rect.modulate, UiAssets.INKT)
	assert_eq(rect.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	assert_eq(rect.custom_minimum_size, Vector2(32, 32))
	rect.free()
	var leeg := UiAssets.icoon_rect("clock", 32)
	assert_false(leeg.visible, "ontbrekend icoon: rect onzichtbaar")
	leeg.free()


func test_thema_bereikt_controls_onder_canvaslayer_en_node() -> void:
	# Bevinding 3 september: een thema erft alleen door Control/Window-ouders.
	# UiThema hangt het daarom aan elke Control die onder een CanvasLayer of
	# kale Node de boom in komt (zoals $UI in game.tscn en capture.tscn).
	var verwacht: StyleBox = UiAssets.thema().get_stylebox("normal", "Button")
	var laag := CanvasLayer.new()
	var knop := Button.new()
	laag.add_child(knop)
	_runner.add_child(laag)
	assert_true(knop.get_theme_stylebox("normal") == verwacht, "knop onder CanvasLayer krijgt de perkamentstijl")
	var kaal := Node.new()
	var paneel := PanelContainer.new()
	var label := Label.new()
	paneel.add_child(label)
	kaal.add_child(paneel)
	_runner.add_child(kaal)
	assert_true(paneel.get_theme_stylebox("panel") == UiAssets.thema().get_stylebox("panel", "PanelContainer"),
		"paneel onder kale Node krijgt het kaartje")
	assert_eq(label.get_theme_color("font_color"), UiAssets.WARM_IVOOR, "label erft via het paneel")
	assert_true(UiThema.is_thema_wortel(knop), "knop onder CanvasLayer is een thema-wortel")
	assert_false(UiThema.is_thema_wortel(label), "label onder een Control is dat niet")
	laag.queue_free()
	kaal.queue_free()

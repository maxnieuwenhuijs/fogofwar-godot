extends RefCounted

## `-- vfxcheck` (capture.tscn, headless of met venster; 6 oktober 2026,
## docs/VFX-studio.md): de catalogus klopt (ids uniek, groepen en statussen
## bestaan, elke knop heeft een label, bereik en standaard binnen dat bereik),
## en de VFX-tuner speelt elk effect met een recept af: er verschijnt iets op
## het toneel, een volgend afspelen ruimt het oude toneel op, en een knop die je
## zet komt aan bij PawnView.fx. Exit 1 bij een fout; de grep op "SCRIPT ERROR"
## hoort erbij.
##
## `-- vfxshot <id> [map] [tempo]` (met venster): plaatjes van een effect op
## vaste momenten, voor de concept-webpagina en om naar te kijken.

const Catalogus := preload("res://scripts/vfx/vfx_catalogus.gd")
const VFX := preload("res://scripts/vfx/vfx.gd")
const STATUSSEN := ["spel", "wens", "diorama"]
## De texturen die de studio levert en die de code via VFX._geleverde laadt:
## map, naam, boost, hooguit-px, bijsnijden, vierkant. Sinds 9 oktober de lijst
## van VFX zelf (VFX.VOORAF, dezelfde sleutels als de effecten en het vooraf
## klaarmaken), dus hij kan niet meer uit de pas lopen.
const GELEVERD := VFX.VOORAF

static var _fouten := 0
static var _host: Node = null


static func _ok(voorwaarde: bool, wat: String) -> void:
	if voorwaarde:
		print("[VFX]   ok   %s" % wat)
	else:
		_fouten += 1
		print("[VFX]   FOUT %s" % wat)


static func _wacht(s: float) -> void:
	await _host.get_tree().create_timer(s, true, false, true).timeout
	await _host.get_tree().process_frame


static func run(host: Node) -> int:
	_fouten = 0
	_host = host
	_catalogus()
	_geleverd()
	await _tuner()
	await _sfeer()
	print("[VFX] %s: %d fouten" % ["PASS" if _fouten == 0 else "FAIL", _fouten])
	return _fouten


## De looks staan ook in het sfeer-paneel van het spel (toets L): een schuif zet
## de knop live en het vlak over het spelbeeld volgt meteen (6 oktober, Max: "de
## tilt shift zie ik niet echt"; een look over het hele beeld beoordeel je het
## best in het spel zelf).
static func _sfeer() -> void:
	print("[VFX] sfeer-paneel")
	var game: Node = load("res://scenes/game/game.tscn").instantiate()
	_host.add_child(game)
	await _wacht(0.5)
	game.call("_toggle_ambiance_panel")
	var paneel: Control = game.get("_ambiance_panel")
	var schuif: HSlider = null
	var rijen := 0
	if paneel != null:
		for rij in paneel.find_children("*", "HBoxContainer", true, false):
			var l := rij.get_child(0) as Label
			if l != null and l.text.begins_with("stijl: "):
				rijen += 1
				if l.text.contains("tilt-shift"):
					schuif = rij.get_child(1) as HSlider
	_ok(rijen == Catalogus.STIJL.KNOPPEN.size(), "elke look een schuif in het sfeer-paneel (%d)" % rijen)
	var cam: Camera3D = game.get("_camera")
	var vlak: MeshInstance3D = cam.get_node_or_null(Catalogus.STIJL.NAAM) if cam != null else null
	_ok(schuif != null and vlak != null, "de miniatuur-schuif en het vlak over het spelbeeld zijn er")
	if schuif != null and vlak != null:
		var oud: float = PawnView.fx("stijl_miniatuur", 0.0)
		var mat := vlak.material_override as ShaderMaterial
		schuif.value = 1.0
		_ok(vlak.visible and is_equal_approx(float(mat.get_shader_parameter("miniatuur")), 1.0),
			"de schuif zet de miniatuur live aan op het spelbeeld")
		_ok(mat.get_shader_parameter("beeld") == null, "in het spel rekent de band in het hele scherm")
		schuif.value = oud
		_ok(is_equal_approx(float(mat.get_shader_parameter("miniatuur")), oud), "en terug (%.2f)" % oud)
	game.queue_free()
	await _wacht(0.3)


static func _catalogus() -> void:
	print("[VFX] catalogus")
	var groepen: Dictionary = {}
	for g in Catalogus.GROEPEN:
		groepen[String(g.id)] = true
	var ids: Dictionary = {}
	var fout_regels: Array = []
	for e in Catalogus.EFFECTEN:
		var id := String(e.id)
		if ids.has(id):
			fout_regels.append("%s dubbel" % id)
		ids[id] = true
		if not groepen.has(String(e.groep)):
			fout_regels.append("%s: onbekende groep %s" % [id, e.groep])
		if not STATUSSEN.has(String(e.status)):
			fout_regels.append("%s: onbekende status %s" % [id, e.status])
		if String(e.status) == "spel" and String(e.get("speel", "")) == "" and String(e.get("notitie", "")) == "":
			fout_regels.append("%s: zit in het spel maar speelt niet in de tuner, zonder notitie waarom" % id)
		for k in e.knoppen:
			if not Catalogus.bekend(String(k)):
				fout_regels.append("%s: knop %s zonder metadata" % [id, k])
		for k in e.get("demo", {}):
			if not (e.knoppen as Array).has(k):
				fout_regels.append("%s: demo-knop %s hoort niet bij dit effect" % [id, k])
		for o in e.get("onderdelen", []):
			if Catalogus.onderdeel(String(o)).is_empty():
				fout_regels.append("%s: onbekend onderdeel %s" % [id, o])
	for oid in Catalogus.ONDERDELEN:
		var od: Dictionary = Catalogus.ONDERDELEN[oid]
		for veld in ["naam", "map", "bestand", "uitleg", "prompt"]:
			if String(od.get(veld, "")) == "":
				fout_regels.append("onderdeel %s: %s ontbreekt" % [oid, veld])
		if not ["flipbook", "varianten", "vast"].has(String(od.get("soort", ""))):
			fout_regels.append("onderdeel %s: onbekende soort %s" % [oid, od.get("soort", "")])
		if not ["zwart", "alpha"].has(String(od.get("achtergrond", ""))):
			fout_regels.append("onderdeel %s: onbekende achtergrond %s" % [oid, od.get("achtergrond", "")])
	var alle: Dictionary = Catalogus.KNOPPEN.duplicate()
	alle.merge(Catalogus.STIJL.KNOPPEN)
	for k in alle:
		var m: Dictionary = alle[k]
		if not (float(m.min) <= float(m.def) and float(m.def) <= float(m.max)) or float(m.step) <= 0.0:
			fout_regels.append("knop %s: standaard buiten het bereik of stap 0" % k)
	_ok(fout_regels.is_empty(), "%d effecten in %d groepen, %d knoppen, %d onderdelen%s" % [Catalogus.EFFECTEN.size(),
		Catalogus.GROEPEN.size(), Catalogus.KNOPPEN.size(), Catalogus.ONDERDELEN.size(),
		"" if fout_regels.is_empty() else ": " + "; ".join(fout_regels)])
	var data: Dictionary = Catalogus.als_data()
	_ok((data.effecten as Array).size() == Catalogus.EFFECTEN.size(), "als_data levert alle effecten met hun waarden")


## De geleverde texturen (krater, stof, vlam, wielspoor): elk bestand in de map
## komt klaar uit de lader, niet groter dan afgesproken en met mipmaps; het
## wielspoor is tot een strook bijgesneden en de vlam uit zijn plaatje geknipt.
## Zonder bestanden (een verse checkout) is er niets te controleren.
static func _geleverd() -> void:
	print("[VFX] geleverde texturen")
	for g in GELEVERD:
		var map := String(g[0])
		var naam := String(g[1])
		var bestanden := 0
		var nog_niet := 0   # net geleverd, de open editor heeft hem nog niet geimporteerd
		var d := DirAccess.open("res://assets/textures/%s/" % map)
		if d != null:
			for f in d.get_files():
				var fname := String(f).trim_suffix(".import").trim_suffix(".remap")
				if fname == f and fname.get_extension().to_lower() in ["png", "webp", "jpg", "jpeg"] \
						and fname.get_basename().to_lower().begins_with(naam):
					bestanden += 1
					if not FileAccess.file_exists("res://assets/textures/%s/%s.import" % [map, fname]):
						nog_niet += 1
		var lijst: Array = VFX._geleverde(map, naam, float(g[2]), int(g[3]), bool(g[4]), bool(g[5]))
		var fout := ""
		for e in lijst:
			var tex: Texture2D = e.tex
			# de maat geldt per beeldje van een vel, het hele vel hooguit 2048 (7 oktober)
			var cel := maxi(tex.get_width() / int(e.cols), tex.get_height() / int(e.rows))
			if cel > int(g[3]) or maxi(tex.get_width(), tex.get_height()) > 2048:
				fout = "te groot (%dx%d, beeldje %d)" % [tex.get_width(), tex.get_height(), cel]
			elif naam == "cannon" and int(e.cols) * int(e.rows) > 1 \
					and tex.get_height() / int(e.rows) * 4 > tex.get_width() / int(e.cols) * 3:
				fout = "vel niet bijgesneden (beeldje %dx%d)" % [tex.get_width() / int(e.cols), tex.get_height() / int(e.rows)]
			elif tex.get_image() == null or not tex.get_image().has_mipmaps():
				fout = "geen mipmaps"
			elif naam == "wiel" and float(tex.get_width()) > float(tex.get_height()) * 0.6:
				fout = "niet bijgesneden (%dx%d)" % [tex.get_width(), tex.get_height()]
			elif naam == "vlam" and int(e.cols) * int(e.rows) == 1 and (e.uitsnede as Rect2).get_area() > 0.9:
				fout = "vlam niet uit het plaatje geknipt"
			elif bool(g[5]) and int(e.cols) * int(e.rows) == 1 and tex.get_width() != tex.get_height():
				fout = "niet vierkant voor een billboard (%dx%d)" % [tex.get_width(), tex.get_height()]
		_ok(lijst.size() == bestanden - nog_niet and fout == "", "%s/%s: %d van %d bestanden klaar%s%s" % [map, naam,
			lijst.size(), bestanden, "" if fout == "" else ", " + fout,
			"" if nog_niet == 0 else ", %d nog niet geimporteerd (de editor doet dat zodra hij focus krijgt)" % nog_niet])


static func _tuner() -> void:
	print("[VFX] tuner")
	var scene: PackedScene = load("res://scenes/tools/VfxTuner.tscn")
	_ok(scene != null, "VfxTuner.tscn laadt")
	if scene == null:
		return
	var tuner: Node = scene.instantiate()
	_host.add_child(tuner)
	await _wacht(0.5)
	_ok(tuner.get("_cam") != null and (tuner.get("_cam") as Camera3D).current, "de camera van het bord is de camera")
	var spelbaar := 0
	for e in Catalogus.EFFECTEN:
		if String(e.get("speel", "")) == "":
			continue
		spelbaar += 1
		tuner.call("kies", String(e.id))
		await _host.get_tree().process_frame
		var oud: Node = tuner.call("toneel")
		var duur: float = tuner.call("speel")
		var toneel: Node = tuner.call("toneel")
		var meeste := 0
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < int(minf(maxf(duur, 1.0), 1.6) * 1000.0):
			await _host.get_tree().process_frame
			if is_instance_valid(toneel):
				meeste = maxi(meeste, toneel.get_child_count())
		_ok(duur > 0.0 and meeste > 2, "%s: speelt (%d dingen op het toneel)" % [e.id, meeste])
		_ok(not is_instance_valid(oud) or oud != toneel, "%s: het oude toneel is weg" % e.id)
	_ok(spelbaar >= 10, "%d effecten af te spelen" % spelbaar)
	# een wens speelt niet en zegt waarom (de eerste die er nog is)
	var wens := ""
	for e in Catalogus.EFFECTEN:
		if String(e.status) == "wens":
			wens = String(e.id)
			break
	if wens != "":
		tuner.call("kies", wens)
		var niets: float = tuner.call("speel")
		_ok(niets == 0.0 and String((tuner.get("_melding") as Label).text).contains("wens"),
			"een wens (%s) speelt niet en zegt dat" % wens)
	# een knop zetten komt aan in het spel (PawnView.fx), en de schuif volgt
	tuner.call("kies", "schot_musket")
	var oud_waarde: float = PawnView.fx("smoke_size", 1.0)
	tuner.call("zet_knop", "smoke_size", 2.25)
	var schuif: HSlider = (tuner.get("_sliders") as Dictionary).get("smoke_size")
	_ok(is_equal_approx(PawnView.fx("smoke_size", 1.0), 2.25) and schuif != null and is_equal_approx(schuif.value, 2.25),
		"een knop zetten: live in PawnView.fx en op de schuif")
	tuner.call("zet_knop", "smoke_size", oud_waarde)
	# de miniatuur rekent in het beeld tussen de panelen, net als in het spel in
	# het hele scherm (anders viel de vage rand achter de panelen; Max: "de tilt
	# shift zie ik niet echt")
	tuner.call("kies", "miniatuur")
	await _wacht(0.3)   # het onderpaneel krijgt zijn maat, de camera en de band volgen
	var stijl: MeshInstance3D = tuner.get("_stijl")
	var r: Rect2i = tuner.call("beeld_rect")
	var h: float = maxf((tuner as Node).get_viewport().get_visible_rect().size.y, 1.0)
	var beeld: Variant = (stijl.material_override as ShaderMaterial).get_shader_parameter("beeld") \
		if stijl != null else null
	_ok(beeld is Vector2 and (beeld as Vector2).distance_to(Vector2(float(r.position.y) / h, float(r.end.y) / h)) < 0.01,
		"miniatuur: de scherpe band rekent in het beeld tussen de panelen (%s)" % str(beeld))
	await _zwaai(tuner)
	await _stukjes(tuner)
	tuner.queue_free()
	await _wacht(0.8)   # lopende recepten (een schot wacht tot de kogel aankomt) laten aflopen
	_ok(Engine.time_scale == 1.0, "de tijd loopt weer gewoon na het sluiten")


## Het zwaaispoor (6 oktober): bij een bajonetstoot en een charge hangt er een
## lijntje langs de punt van het wapen, dat daarna vanzelf weer weg is. Met de knop
## op 0 komt er geen.
static func _zwaai(tuner: Node) -> void:
	for id in ["zwaaispoor", "zwaaispoor_charge"]:
		tuner.call("kies", id)
		await _host.get_tree().process_frame
		var duur: float = tuner.call("speel")
		var toneel: Node = tuner.call("toneel")
		var schutter: Node3D = tuner.get("_schutter")
		var meeste := 0
		var gezien := false
		var lengte := 0.0      # hoe ver de punt reisde (de langste kant van de doos)
		var afstand := 0.0     # hoe ver het lijntje van de schutter af lag (midden van de doos)
		var hoogte := 0.0      # en op welke hoogte (het bord ligt op 0,05)
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < int((duur + 0.5) * 1000.0):
			await _host.get_tree().process_frame
			if not is_instance_valid(toneel):
				break
			for s in toneel.find_children("Zwaaispoor*", "", false, false):
				gezien = true
				meeste = maxi(meeste, int(s.call("stukjes")))
				var ab: AABB = s.call("omvang")
				if ab.get_longest_axis_size() > lengte:
					lengte = ab.get_longest_axis_size()
					if is_instance_valid(schutter):
						var m := ab.get_center()
						afstand = Vector2(m.x - schutter.position.x, m.z - schutter.position.z).length()
						hoogte = m.y
		var over: int = toneel.find_children("Zwaaispoor*", "", false, false).size() if is_instance_valid(toneel) else 0
		_ok(gezien and meeste >= 4 and over == 0,
			"%s: een lijntje achter de punt van het wapen (tot %d punten), daarna weer weg (%d over)" % [id, meeste, over])
		_ok(lengte > 0.1 and afstand < 1.2 and hoogte > 0.1,
			"%s: de punt reist %.2f, het lijntje ligt %.2f van de schutter op hoogte %.2f" % [id, lengte, afstand, hoogte])
	var oud: float = PawnView.fx("slash_spoor", 1.0)
	PawnView.set_fx("slash_spoor", 0.0)
	tuner.call("kies", "zwaaispoor")
	await _host.get_tree().process_frame
	tuner.call("speel")
	await _wacht(0.8)
	var toneel_uit: Node = tuner.call("toneel")
	_ok(toneel_uit.find_children("Zwaaispoor*", "", false, false).is_empty(), "knop slash_spoor 0: geen lijntje")
	PawnView.set_fx("slash_spoor", oud)
	await _wacht(1.5)


## De nieuwe stukjes (6 oktober, Max: "al deze nieuwe vfx moeten hun eigen decal
## krijgen"): met een textuur van de studio tekent elk effect die in plaats van
## zijn vervanger. Zonder bestanden doet de check alsof (VFX.proef_geleverd) en
## zoekt het plaatje in de tuner.
const STUKJES := [["bullet", "musket", "schot_musket"], ["bullet", "cannon", "schot_kanon"],
	["sparks", "propje", "propjes"], ["sparks", "vonk", "vonken"], ["flash", "flits", "vonken"],
	["debris", "kluit", "inslag_aarde"], ["debris", "splinter", "inslag_materiaal"],
	["decals", "schokgolf", "kruitvat"], ["trails", "slash", "zwaaispoor"]]


static func _stukjes(tuner: Node) -> void:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 1.0, 1.0, 1.0))
	var tex := ImageTexture.create_from_image(img)
	for s in STUKJES:
		VFX.proef_geleverd(String(s[0]), String(s[1]), tex)
		tuner.call("kies", String(s[2]))
		await _host.get_tree().process_frame
		tuner.call("speel")
		var gezien := false
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 2500 and not gezien:
			await _host.get_tree().process_frame
			for mi in (tuner as Node).find_children("*", "MeshInstance3D", true, false):
				var mat := (mi as MeshInstance3D).material_override as StandardMaterial3D
				if mat != null and mat.albedo_texture == tex:
					gezien = true
					break
		_ok(gezien, "%s/%s: het geleverde plaatje komt in beeld bij %s" % [s[0], s[1], s[2]])
		VFX.proef_geleverd(String(s[0]), String(s[1]), null)
		await _wacht(0.2)
	await _wacht(1.5)   # lopende recepten laten aflopen
	# Varianten (7 oktober, Max: "3-6 unieke stofwolkjes die random worden
	# afgespeeld", "net als vuur"): liggen er meer, dan kiest het spel er elke keer
	# een uit, en ze komen allemaal aan de beurt.
	for mn in [["dust", "stof"], ["flame", "vlam"]]:
		var vier: Array = []
		for i in 4:
			var im := Image.create(8, 8, false, Image.FORMAT_RGBA8)
			im.fill(Color(1.0, 1.0, 1.0, 0.25 * float(i + 1)))
			vier.append({"tex": ImageTexture.create_from_image(im), "cols": 1, "rows": 1,
				"uitsnede": Rect2(0.0, 0.0, 1.0, 1.0)})
		VFX._proef[String(mn[0]) + "/" + String(mn[1])] = vier
		var gezien: Dictionary = {}
		for i in 40:
			var e: Dictionary = VFX._kies_geleverd(String(mn[0]), String(mn[1]))
			gezien[e.tex] = true
		VFX._proef.erase(String(mn[0]) + "/" + String(mn[1]))
		_ok(gezien.size() == 4, "%s/%s: met vier varianten komen ze alle vier aan de beurt (%d)" % [mn[0], mn[1], gezien.size()])


## Plaatjes van een effect (met venster): kiest het, speelt het op `tempo` en
## schiet op vaste momenten (echte tijd) een plaatje.
static func shot(host: Node, id: String, map: String = "", tempo: float = 1.0, knoppen: Dictionary = {}) -> int:
	_host = host
	_fouten = 0
	if DisplayServer.get_name() == "headless":
		print("[VFXSHOT] alleen met venster (headless tekent niets)")
		return 1
	if Catalogus.effect(id).is_empty():
		print("[VFXSHOT] onbekend effect: %s" % id)
		return 1
	var uit := map if map != "" else "user://vfxshot"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(uit))
	var tuner: Node = (load("res://scenes/tools/VfxTuner.tscn") as PackedScene).instantiate()
	host.add_child(tuner)
	await _wacht(0.8)
	tuner.call("kies", id)
	for k in knoppen:
		tuner.call("zet_knop", String(k), float(knoppen[k]))
	await _wacht(0.6)
	Engine.time_scale = tempo
	var duur: float = tuner.call("speel")
	var tijden: Array = [0.05, 0.2, 0.35, 0.5, 0.75, 1.1, 1.6, 2.4]
	var start := Time.get_ticks_msec()
	for i in tijden.size():
		var doel: int = start + int(float(tijden[i]) / maxf(tempo, 0.01) * 1000.0)
		while Time.get_ticks_msec() < doel:
			await host.get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := host.get_viewport().get_texture().get_image()
		var pad := "%s/%s_%d.png" % [uit, id, i + 1]
		if img == null or img.save_png(pad) != OK:
			_fouten += 1
		else:
			print("[VFXSHOT] %s" % ProjectSettings.globalize_path(pad))
	Engine.time_scale = 1.0
	print("[VFXSHOT] %s klaar (duur %.1f s, %d fouten)" % [id, duur, _fouten])
	tuner.queue_free()
	return _fouten


## `-- vfxstudio <map> [id]` (met venster; tools/vfx_studio.py start dit): elk
## effect dat in de tuner speelt, opgenomen voor de kolom "in het spel nu" van de
## VFX-studio. Per effect <map>/<id>/: rust.jpg (het toneel vlak voor het
## effect), spel_00..19.jpg op gelijke afstanden in de tijd, en info.json; alleen
## het bord tussen de panelen. Plus <map>/catalogus.json (de catalogus met de
## huidige knoppen, de terugval van de studio). Een look die in het spel nog uit
## staat (de stijl) neemt hij op in de `demo`-stand van de catalogus; die geldt
## alleen voor de opname.
const STUDIO_BEELDEN := 20
const STUDIO_TEMPO := 0.5

static func studio(host: Node, map: String, alleen: String = "") -> int:
	_host = host
	_fouten = 0
	if DisplayServer.get_name() == "headless":
		print("[VFXSTUDIO] alleen met venster (headless tekent niets)")
		return 1
	DirAccess.make_dir_recursive_absolute(map)
	var gi := FileAccess.open(map.path_join(".gdignore"), FileAccess.WRITE)
	if gi != null:
		gi.close()
	var cf := FileAccess.open(map.path_join("catalogus.json"), FileAccess.WRITE)
	if cf != null:
		cf.store_string(JSON.stringify(Catalogus.als_data(), "\t"))
		cf.close()
	var tuner: Node = (load("res://scenes/tools/VfxTuner.tscn") as PackedScene).instantiate()
	host.add_child(tuner)
	await _wacht(0.8)
	var n := 0
	for e in Catalogus.EFFECTEN:
		if String(e.get("speel", "")) == "" or (alleen != "" and String(e.id) != alleen):
			continue
		n += 1
		print("[VFXSTUDIO] bezig %s" % e.id)
		var fout: String = await _studio_effect(host, tuner, e, map.path_join(String(e.id)))
		if fout == "":
			print("[VFXSTUDIO] %s ok" % e.id)
		else:
			_fouten += 1
			print("[VFXSTUDIO] %s FOUT %s" % [e.id, fout])
	Engine.time_scale = 1.0
	tuner.queue_free()
	await _wacht(0.8)
	print("[VFXSTUDIO] klaar: %d effecten, %d fouten" % [n, _fouten])
	return _fouten


static func _studio_effect(host: Node, tuner: Node, e: Dictionary, map: String) -> String:
	DirAccess.make_dir_recursive_absolute(map)
	for oud in DirAccess.get_files_at(map):
		DirAccess.remove_absolute(map.path_join(oud))
	tuner.call("kies", String(e.id))
	var terug: Dictionary = {}
	var demo: Dictionary = e.get("demo", {})
	for k in demo:
		var nu: float = PawnView.fx(String(k), float(Catalogus.knop(String(k)).def))
		if absf(nu) < 0.001:
			terug[k] = nu
			tuner.call("zet_knop", String(k), float(demo[k]))
	await _wacht(0.5)
	var fout := ""
	if not await _bewaar_beeld(host, tuner, map.path_join("rust.jpg")):
		fout = "rust-beeld niet bewaard"
	Engine.time_scale = STUDIO_TEMPO
	var duur: float = tuner.call("speel")
	var lengte := clampf(duur + 0.5, 1.5, 3.5)   # in spel-seconden
	var stap := lengte / float(STUDIO_BEELDEN)
	if duur <= 0.0:
		fout = "speelt niet"
	else:
		var start := Time.get_ticks_msec()
		var mislukt := 0
		for i in STUDIO_BEELDEN:
			var doel: int = start + int((float(i) + 0.5) * stap / STUDIO_TEMPO * 1000.0)
			while Time.get_ticks_msec() < doel:
				await host.get_tree().process_frame
			if not await _bewaar_beeld(host, tuner, map.path_join("spel_%02d.jpg" % i)):
				mislukt += 1
		if mislukt > 0 and fout == "":
			fout = "%d beelden niet bewaard" % mislukt
	Engine.time_scale = 1.0
	for k in terug:
		tuner.call("zet_knop", String(k), float(terug[k]))
	var f := FileAccess.open(map.path_join("info.json"), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"id": e.id, "duur": duur, "lengte": lengte, "stap": stap,
			"beelden": STUDIO_BEELDEN, "tempo": STUDIO_TEMPO, "demo": demo}, "\t"))
		f.close()
	return fout


## Het bord tussen de panelen als jpg (de beeldmaat kan van de zichtbare rect
## verschillen als het venster geschaald is).
static func _bewaar_beeld(host: Node, tuner: Node, pad: String) -> bool:
	await RenderingServer.frame_post_draw
	var img := host.get_viewport().get_texture().get_image()
	if img == null:
		return false
	var vp: Vector2 = host.get_viewport().get_visible_rect().size
	var r: Rect2i = tuner.call("beeld_rect")
	var sx: float = float(img.get_width()) / maxf(vp.x, 1.0)
	var sy: float = float(img.get_height()) / maxf(vp.y, 1.0)
	var uit := Rect2i(int(r.position.x * sx), int(r.position.y * sy), int(r.size.x * sx), int(r.size.y * sy))
	uit = uit.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if uit.size.x < 8 or uit.size.y < 8:
		return false
	return img.get_region(uit).save_jpg(pad, 0.88) == OK

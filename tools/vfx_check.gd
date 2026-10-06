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
const STATUSSEN := ["spel", "wens", "diorama"]

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
	await _tuner()
	print("[VFX] %s: %d fouten" % ["PASS" if _fouten == 0 else "FAIL", _fouten])
	return _fouten


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
	var alle: Dictionary = Catalogus.KNOPPEN.duplicate()
	alle.merge(Catalogus.STIJL.KNOPPEN)
	for k in alle:
		var m: Dictionary = alle[k]
		if not (float(m.min) <= float(m.def) and float(m.def) <= float(m.max)) or float(m.step) <= 0.0:
			fout_regels.append("knop %s: standaard buiten het bereik of stap 0" % k)
	_ok(fout_regels.is_empty(), "%d effecten in %d groepen, %d knoppen%s" % [Catalogus.EFFECTEN.size(),
		Catalogus.GROEPEN.size(), Catalogus.KNOPPEN.size(),
		"" if fout_regels.is_empty() else ": " + "; ".join(fout_regels)])
	var data: Dictionary = Catalogus.als_data()
	_ok((data.effecten as Array).size() == Catalogus.EFFECTEN.size(), "als_data levert alle effecten met hun waarden")


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
	tuner.queue_free()
	await _wacht(0.8)   # lopende recepten (een schot wacht tot de kogel aankomt) laten aflopen
	_ok(Engine.time_scale == 1.0, "de tijd loopt weer gewoon na het sluiten")


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

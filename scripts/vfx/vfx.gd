extends RefCounted

## VFX (6 oktober 2026, docs/VFX-studio.md): de effecten van het bord op EEN
## plek, zodat het spel (game.gd) en de VFX-tuner precies dezelfde code
## afspelen. Zonder class_name: `const VFX := preload("res://scripts/vfx/vfx.gd")`.
##
## Alles is puur beeld onder `ouder` (het bord in het spel, de tuner-wereld in
## de tuner), in de lokale ruimte van die ouder. Knoppen via
## `PawnView.fx(sleutel, standaard)` (assets/models/effects_tuning.json); hun
## label, bereik en standaard staan in scripts/vfx/vfx_catalogus.gd.
##
## Let op de rng: schot, vuurmond, rook en vonken zijn uit game.gd verhuisd en
## trekken nog uit de globale rng, in dezelfde volgorde als daarvoor (uispel
## blijft zo gelijk). Nieuwe effecten (rookring, pluim, pankruit, propjes)
## gebruiken een eigen RandomNumberGenerator.

static var _rng: RandomNumberGenerator = null


static func _r() -> RandomNumberGenerator:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.seed = 7102026
	return _rng


## Texturen die de VFX-studio levert (6 oktober, stap 9; tools/vfx_studio.py, groep
## "Texturen en decals"): per map onder assets/textures/ de bestanden waarvan de
## naam met `naam` begint, elk een keer klaargemaakt en bewaard: hooguit `max_px`
## per kant (een vel blijft deelbaar door zijn rooster uit de naam, bv. _4x4),
## desgewenst bijgesneden tot wat er te zien is (`vierkant`: een vierkant om het
## midden, voor een billboard die anders vervormt), zwart doorzichtig als het plaatje
## zelf geen doorzichtigheid heeft (`boost` > 0, zoals PawnView._black_to_alpha), en
## met mipmaps, zodat een groot plaatje klein op het bord niet flikkert. Leeg = de
## code tekent zijn eigen vervanger. Kiezen gaat met de eigen rng, nooit de globale.
static var _geleverd: Dictionary = {}     # "map/naam" -> Array van {tex, cols, rows, uitsnede}


static func _geleverde(map: String, naam: String, boost: float = 0.0, max_px: int = 512,
		bijsnijden: bool = false, vierkant: bool = false) -> Array:
	var sleutel := "%s/%s/%s/%d/%s/%s" % [map, naam, boost, max_px, bijsnijden, vierkant]
	if _geleverd.has(sleutel):
		return _geleverd[sleutel]
	var lijst: Array = []
	var pad := "res://assets/textures/%s/" % map
	var d := DirAccess.open(pad)
	if d != null:
		var namen: Array = []
		for f in d.get_files():
			var fname := String(f).trim_suffix(".import").trim_suffix(".remap")
			if fname.get_extension().to_lower() in ["png", "webp", "jpg", "jpeg"] and not namen.has(fname):
				namen.append(fname)
		namen.sort()
		for fname in namen:
			var base := String(fname).get_basename().to_lower()
			if not base.begins_with(naam) or not ResourceLoader.exists(pad + fname):
				continue
			var tex = load(pad + fname)
			if tex is Texture2D:
				lijst.append(_maak_klaar(tex, base, boost, max_px, bijsnijden, vierkant))
	_geleverd[sleutel] = lijst
	return lijst


static func _kies_geleverd(map: String, naam: String, boost: float = 0.0, max_px: int = 512,
		bijsnijden: bool = false, vierkant: bool = false) -> Dictionary:
	var lijst := _geleverde(map, naam, boost, max_px, bijsnijden, vierkant)
	return {} if lijst.is_empty() else lijst[_r().randi() % lijst.size()]


## Een geleverde textuur zoals die in het spel moet: zie _geleverde. Ook voor
## game.gd (het wielspoor). Zonder beelddata (een VRAM-textuur) blijft hij zoals hij is.
static func _maak_klaar(tex: Texture2D, base: String, boost: float, max_px: int, bijsnijden: bool,
		vierkant: bool = false) -> Dictionary:
	var cols := 1
	var rows := 1
	var us := base.rfind("_")
	if us >= 0:
		var grid := base.substr(us + 1).split("x")
		if grid.size() == 2 and grid[0].is_valid_int() and grid[1].is_valid_int():
			cols = maxi(int(grid[0]), 1)
			rows = maxi(int(grid[1]), 1)
	var e := {"tex": tex, "cols": cols, "rows": rows, "uitsnede": Rect2(0.0, 0.0, 1.0, 1.0)}
	var img := tex.get_image()
	if img == null:
		return e
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var alpha := false
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			if img.get_pixel(x, y).a < 0.98:
				alpha = true
				break
		if alpha:
			break
	if bijsnijden and cols * rows == 1:
		var r := _inhoud(img, alpha)
		if vierkant:
			var z := mini(maxi(r.size.x, r.size.y), mini(img.get_width(), img.get_height()))
			var m := r.get_center()
			r = Rect2i(clampi(m.x - z / 2, 0, img.get_width() - z), clampi(m.y - z / 2, 0, img.get_height() - z), z, z)
		if r.size.x > 4 and r.size.y > 4:
			img = img.get_region(r)
	var celw := img.get_width() / cols
	var celh := img.get_height() / rows
	var schaal := minf(1.0, float(max_px) / float(maxi(img.get_width(), img.get_height())))
	if schaal < 1.0:
		img.resize(maxi(1, int(celw * schaal)) * cols, maxi(1, int(celh * schaal)) * rows, Image.INTERPOLATE_LANCZOS)
	if boost > 0.0 and not alpha:
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				c.a = minf(maxf(c.r, maxf(c.g, c.b)) * boost, 1.0)
				img.set_pixel(x, y, c)
	if cols * rows == 1:
		var r2 := _inhoud(img, alpha or boost > 0.0)
		e.uitsnede = Rect2(Vector2(r2.position) / Vector2(img.get_size()), Vector2(r2.size) / Vector2(img.get_size()))
	img.generate_mipmaps()
	e.tex = ImageTexture.create_from_image(img)
	return e


## Het deel van een plaatje waar iets te zien is: dekking (met alpha) of
## helderheid (op zwart), met een randje marge.
static func _inhoud(img: Image, alpha: bool) -> Rect2i:
	var w := img.get_width()
	var h := img.get_height()
	var stap := maxi(1, int(maxi(w, h) / 256))
	var x0 := w
	var y0 := h
	var x1 := -1
	var y1 := -1
	for y in range(0, h, stap):
		for x in range(0, w, stap):
			var c := img.get_pixel(x, y)
			var zicht: float = c.a if alpha else maxf(c.r, maxf(c.g, c.b))
			if zicht > 0.06:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	if x1 < 0:
		return Rect2i(0, 0, w, h)
	var marge := maxi(stap * 2, int(maxi(x1 - x0, y1 - y0) * 0.04))
	x0 = maxi(0, x0 - marge)
	y0 = maxi(0, y0 - marge)
	x1 = mini(w - 1, x1 + marge)
	y1 = mini(h - 1, y1 + marge)
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)


## Een textuur uit een vaste map (het wielspoor in game.gd), klaargemaakt als
## hierboven en bewaard; null als het bestand er niet is.
static func geleverde_textuur(map: String, naam: String, max_px: int, bijsnijden: bool) -> Texture2D:
	for e in _geleverde(map, naam, 0.0, max_px, bijsnijden):
		return e.tex
	return null


## De wind van het potje (PawnView.wind_richting, wereld) in de ruimte van `ouder`.
static func _wind(ouder: Node3D) -> Vector3:
	return ouder.global_transform.basis.inverse() * PawnView.wind_richting


## Hoe lang de kogel onderweg is: een kanonskogel razendsnel (keihard), een
## musketkogel iets rustiger. `afstand` in bord-eenheden (vakken).
static func vlucht_duur(afstand: float, kanon: bool) -> float:
	return clampf(0.016 * afstand, 0.05, 0.22) if kanon else clampf(0.06 * afstand, 0.1, 0.4)


## Een schot: de kogel (musket: een gloeiend bolletje; kanon: een strakke streep)
## vliegt in `duur` van de loop naar het doel, met de vuurmond en zijn lichtflits,
## de terugslag (`schok`, de schudder van wie de camera heeft), kruitdamp aan de
## loop die met het schot mee drijft en inslagrook bij aankomst. Geeft `duur`.
static func schot(ouder: Node3D, loop: Vector3, doel: Vector3, kanon: bool, duur: float,
		schok: Callable = Callable()) -> float:
	var proj := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	var radius: float = 0.13 if kanon else 0.055
	mesh.radius = radius
	mesh.height = radius * 2.0
	proj.mesh = mesh
	var mat := StandardMaterial3D.new()
	if kanon:
		mat.albedo_color = Color(0.16, 0.16, 0.18)
		mat.metallic = 0.5
	else:
		mat.albedo_color = Color(1.0, 0.9, 0.5)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.85, 0.4)
		mat.emission_energy_multiplier = 1.6
	proj.material_override = mat
	proj.position = loop
	ouder.add_child(proj)
	# Kanonskogel: rek de bol uit langs de vliegrichting tot een strakke streep,
	# keihard rechtdoor (geen boog). Infanterie blijft een rond tracer-bolletje.
	if kanon and loop.distance_to(doel) > 0.01:
		proj.look_at_from_position(loop, doel, Vector3.UP)
		proj.scale = Vector3(0.6, 0.6, 4.0)  # uitgerekt langs de kijkas (-Z)
	var tween := ouder.create_tween()
	tween.tween_method(func(t: float) -> void: proj.position = loop.lerp(doel, t), 0.0, 1.0, duur)
	tween.tween_callback(proj.queue_free)

	vuurmond(ouder, loop, kanon)
	# vuur-schok: korte terugslag bij het afvuren (kanon harder).
	if schok.is_valid():
		schok.call((0.55 if kanon else 0.3) * PawnView.fx("fire_shake", 1.0))
	# Rook drijft met de schotrichting mee, van de loop af.
	var richting := Vector3.ZERO
	if loop.distance_to(doel) > 0.01:
		richting = (doel - loop).normalized()
	rook(ouder, loop, 4 if kanon else 2, 0.16 if kanon else 0.09, richting)
	# De rest van het kruit (6 oktober, eigen rng): een kanon blaast een rookring
	# en een dikke pluim, een musket flitst eerst op de pan; uit allebei vliegen
	# gloeiende propjes.
	if kanon:
		rookring(ouder, loop, richting)
		pluim(ouder, loop, richting)
	else:
		pankruit(ouder, slot_bij(loop, richting))
	propjes(ouder, loop, richting, kanon)
	# Inslagrook zodra de kogel aankomt (zelfde richting = momentum).
	var inslag_aantal: int = 3 if kanon else 2
	var inslag_maat: float = 0.14 if kanon else 0.08
	ouder.get_tree().create_timer(duur).timeout.connect(func() -> void:
		if is_instance_valid(ouder):
			rook(ouder, doel, inslag_aantal, inslag_maat, richting, PawnView.fx("impact_smoke_life", 0.6))
			if kanon:
				# de kogel slaat door in de grond: aarde spat op en er blijft een krater
				inslag_aarde(ouder, doel, richting)
				krater(ouder, doel))
	return duur


## De vuurmond: de steekvlam (een flipbook uit assets/textures/fire/, zonder
## texturen een gloeiende bol) en een korte lichtflits die de omgeving even
## oplicht (vuur-licht).
static func vuurmond(ouder: Node3D, pos: Vector3, groot: bool) -> void:
	var textured := PawnView.spawn_muzzle_fire(ouder, pos, groot)
	var holder := Node3D.new()
	holder.position = pos
	ouder.add_child(holder)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.78, 0.35)
	light.light_energy = (2.6 if groot else 1.6) * PawnView.fx("fire_light", 1.6)
	light.omni_range = 2.8
	holder.add_child(light)
	var tween := holder.create_tween().set_parallel()
	if not textured:
		var flash := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		var radius: float = 0.16 if groot else 0.09
		mesh.radius = radius
		mesh.height = radius * 2.0
		flash.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.75, 0.25, 0.9)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.7, 0.2)
		mat.emission_energy_multiplier = 2.5
		flash.material_override = mat
		flash.scale = Vector3.ONE * 0.5
		holder.add_child(flash)
		tween.tween_property(flash, "scale", Vector3.ONE * (2.0 if groot else 1.4), 0.12).set_ease(Tween.EASE_OUT)
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.14).set_ease(Tween.EASE_IN)
	tween.tween_property(light, "light_energy", 0.0, 0.18)
	tween.chain().tween_callback(holder.queue_free)


## Zwartkruit-rook (de gedeelde spawner in PawnView): billboards die echt
## uitzetten, opstijgen en vervagen; zonder texturen grijze bol-wolkjes.
## Standaard het kruitdamp-vel; de koppel-pof vraagt "white_smoke".
static func rook(ouder: Node3D, pos: Vector3, aantal: int, maat: float, richting: Vector3 = Vector3.ZERO,
		levens_factor: float = 1.0, tex_wens: String = "musket") -> void:
	PawnView.spawn_powder_smoke(ouder, pos, aantal, maat, richting, levens_factor, tex_wens)


## Waar het slot (de pan) van een musket ongeveer zit: een stukje terug langs de
## loop, iets lager. Het model kent geen slot; dit klopt op de afstand waarop
## je speelt.
static func slot_bij(loop: Vector3, richting: Vector3) -> Vector3:
	var vlak := Vector3(richting.x, 0.0, richting.z)
	vlak = vlak.normalized() if vlak.length() > 0.001 else Vector3(0.0, 0.0, -1.0)
	return loop - vlak * 0.3 + Vector3(0.0, -0.02, 0.0)


## Een plukje rook: een billboard met het kruitdamp-vel uit
## assets/textures/smoke/ (zonder texturen een grijze bol) dat van `van` naar
## `naar` drijft, van maat `m0` naar `m1` groeit en in `duur` vervaagt (vol tot
## `vol` van de duur). `trans` bepaalt hoe het afremt (EXPO voor een ring die
## wegschiet en stilvalt).
static func _rookpluk(ouder: Node3D, van: Vector3, naar: Vector3, m0: float, m1: float, duur: float,
		alfa: float = 0.85, vol: float = 0.3, trans: int = Tween.TRANS_CUBIC, eind_frame: int = -1,
		wens: String = "musket", tint: Color = Color.WHITE) -> void:
	_pluk(ouder, PawnView._vfx_entry(PawnView.SMOKE_TEX_DIR, 2.3, wens), van, naar, m0, m1, duur, alfa, vol,
		trans, eind_frame, tint, 1)


## Een plukje met een gegeven textuur (`e` = {tex, cols, rows}, leeg = een grijze
## bol): zie _rookpluk. Een vel speelt vanaf `eerste` (de kruitdamp vanaf 1: beeldje
## 0 draagt de vlam van het schot).
static func _pluk(ouder: Node3D, e: Dictionary, van: Vector3, naar: Vector3, m0: float, m1: float, duur: float,
		alfa: float, vol: float, trans: int, eind_frame: int, tint: Color, eerste: int, spiegel: bool = false) -> void:
	var mi := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var cols := 1
	var rows := 1
	if not e.is_empty():
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		mi.mesh = q
		mat.albedo_texture = e.tex
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.billboard_keep_scale = true
		cols = int(e.cols)
		rows = int(e.rows)
		if cols * rows > 1:
			mat.uv1_scale = Vector3(1.0 / cols, 1.0 / rows, 1.0)
			PawnView._sheet_frame(mini(eerste, cols * rows - 1), mat, cols, rows)
		elif spiegel:
			mat.uv1_scale = Vector3(-1.0, 1.0, 1.0)
			mat.uv1_offset = Vector3(1.0, 0.0, 0.0)
	else:
		var bol := SphereMesh.new()
		bol.radius = 0.5
		bol.height = 1.0
		bol.radial_segments = 8
		bol.rings = 4
		mi.mesh = bol
	mat.albedo_color = Color(tint, alfa) if not e.is_empty() else Color(tint * Color(0.64, 0.64, 0.68), alfa * 0.8)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ouder.add_child(mi)
	mi.position = van
	mi.scale = Vector3.ONE * m0
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "position", naar, duur).set_trans(trans).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "scale", Vector3.ONE * m1, duur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if cols * rows > 1:
		# `eind_frame`: niet tot de rafelige laatste beeldjes (een ring moet dicht blijven)
		var laatste: int = cols * rows - 1 if eind_frame < 0 else mini(eind_frame, cols * rows - 1)
		tw.tween_method(PawnView._sheet_frame.bind(mat, cols, rows), mini(eerste, laatste), laatste, duur)
	tw.tween_property(mat, "albedo_color:a", 0.0, duur * (1.0 - vol)).set_delay(duur * vol).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)


## Rookring bij een kanonschot (kanon-ring): een kring plukjes die dwars op het
## schot uit de loop schiet, snel uitdijt en stilvalt, en dan met de wind
## meedrijft en vervaagt.
static func rookring(ouder: Node3D, loop: Vector3, richting: Vector3) -> void:
	var sterkte: float = PawnView.fx("kanon_ring", 1.0)
	if sterkte <= 0.0 or ouder == null:
		return
	var r := _r()
	var as_ := richting.normalized() if richting.length() > 0.001 else Vector3(0.0, 0.0, -1.0)
	var op := Vector3.UP if absf(as_.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var zij := as_.cross(op).normalized()
	op = zij.cross(as_).normalized()
	var wind := _wind(ouder) * PawnView.fx("smoke_wind", 0.6)
	var n := int(round(14.0 * clampf(sterkte, 0.4, 2.0)))
	var straal := 0.5 * sterkte
	var midden := loop + as_ * 0.15
	for i in n:
		var h := TAU * float(i) / float(n) + r.randf_range(-0.1, 0.1)
		var d := zij * cos(h) + op * sin(h)
		var naar := midden + d * straal * r.randf_range(0.9, 1.1) + as_ * r.randf_range(0.15, 0.3) \
			+ wind * 0.3 + Vector3.UP * 0.06
		_rookpluk(ouder, midden + d * 0.05, naar, 0.12, r.randf_range(0.36, 0.46) * sterkte,
			r.randf_range(1.2, 1.6), 0.95, 0.45, Tween.TRANS_EXPO, 5)


## Rookpluim bij een kanonschot (kanon-pluim): dikke wolken die met het schot
## mee naar voren rollen, opstijgen en met de wind wegdrijven; ze hangen lang.
static func pluim(ouder: Node3D, loop: Vector3, richting: Vector3) -> void:
	var sterkte: float = PawnView.fx("kanon_pluim", 1.0)
	if sterkte <= 0.0 or ouder == null:
		return
	var r := _r()
	var as_ := richting.normalized() if richting.length() > 0.001 else Vector3(0.0, 0.0, -1.0)
	var wind := _wind(ouder) * PawnView.fx("smoke_wind", 0.6)
	var n := int(round(5.0 * clampf(sterkte, 0.2, 2.0)))
	for i in n:
		var f := float(i) / float(maxi(n - 1, 1))
		var van := loop + as_ * (0.1 + 0.25 * f)
		var naar := loop + as_ * (0.5 + 0.9 * f) * r.randf_range(0.8, 1.2) \
			+ Vector3.UP * r.randf_range(0.35, 0.8) + wind * r.randf_range(0.8, 1.4)
		_rookpluk(ouder, van, naar, 0.25, r.randf_range(0.7, 1.05) * sterkte, r.randf_range(2.0, 3.0), 0.75, 0.3)


## Kruitflits op de pan (pan-flits): vlak bij het slot een fel flitsje en een
## wolkje dat recht omhoog krult, zoals bij een vuursteenslot.
static func pankruit(ouder: Node3D, slot: Vector3) -> void:
	var sterkte: float = PawnView.fx("pan_flits", 1.0)
	if sterkte <= 0.0 or ouder == null:
		return
	var mi := MeshInstance3D.new()
	var bol := SphereMesh.new()
	bol.radius = 0.035
	bol.height = 0.07
	bol.radial_segments = 8
	bol.rings = 4
	mi.mesh = bol
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.86, 0.48, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.75, 0.3)
	mat.emission_energy_multiplier = 3.0
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ouder.add_child(mi)
	mi.position = slot
	mi.scale = Vector3.ONE * 0.4 * sterkte
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 1.7 * sterkte, 0.05).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.11).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)
	_rookpluk(ouder, slot, slot + Vector3.UP * 0.35 * sterkte + _wind(ouder) * PawnView.fx("smoke_wind", 0.6) * 0.15,
		0.05, 0.18 * sterkte, 0.9, 0.7, 0.25)


## Gloeiende propjes (propjes): brandende proppen en vonken die uit de loop
## vliegen, vallen, op het bord blijven liggen en doven (van geel naar donkerrood).
static func propjes(ouder: Node3D, loop: Vector3, richting: Vector3, kanon: bool) -> void:
	var sterkte: float = PawnView.fx("propjes", 1.0)
	if sterkte <= 0.0 or ouder == null:
		return
	var r := _r()
	var as_ := richting.normalized() if richting.length() > 0.001 else Vector3(0.0, 0.0, -1.0)
	var n := int(round((9.0 if kanon else 4.0) * sterkte))
	for i in n:
		var v := as_ * r.randf_range(1.2, 2.6) * (1.4 if kanon else 1.0) \
			+ Vector3(r.randf_range(-0.5, 0.5), r.randf_range(0.2, 0.9), r.randf_range(-0.5, 0.5))
		_gloeiend(ouder, loop, v, r.randf_range(0.55, 0.95) * (1.3 if kanon else 1.0),
			r.randf_range(0.012, 0.022) * (1.4 if kanon else 1.0))


## Een gloeiend vonkje of propje: vliegt een boog, valt op het bord en dooft van
## geel naar donkerrood (propjes, explosies, een vuur dat knettert).
static func _gloeiend(ouder: Node3D, loop: Vector3, v: Vector3, duur: float, grootte: float) -> void:
	var vloer := 0.07   # net boven het bord (de tegels liggen op 0,05)
	var mi := MeshInstance3D.new()
	var bol := SphereMesh.new()
	bol.radius = 1.0
	bol.height = 2.0
	bol.radial_segments = 6
	bol.rings = 3
	mi.mesh = bol
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.78, 0.35, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.25)
	mat.emission_energy_multiplier = 2.5
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ouder.add_child(mi)
	mi.position = loop
	mi.scale = Vector3.ONE * grootte
	var tw := mi.create_tween()
	tw.tween_method(func(t: float) -> void:
		var p := loop + v * t + Vector3(0.0, -1.3, 0.0) * t * t
		p.y = maxf(p.y, vloer)
		mi.position = p
		var k: float = clampf(t / duur, 0.0, 1.0)
		mat.albedo_color = Color(1.0, lerpf(0.78, 0.18, k), lerpf(0.35, 0.05, k), 1.0 - smoothstep(0.6, 1.0, k))
		mat.emission = Color(1.0, lerpf(0.7, 0.15, k), lerpf(0.25, 0.02, k)),
		0.0, duur, duur)
	tw.tween_callback(mi.queue_free)


# --- Stof en aarde (6 oktober, stap 3) -----------------------------------------------

const STOF_KLEUR := Color(0.76, 0.68, 0.56)    # droog zand en stof, lichter dan het bord
const STOF_BEELD_MAAT := 1.6                     # een geleverde stofwolk (assets/textures/dust/) groter
const STOF_BEELD_ALFA := 0.7                     # en wat doorzichtiger dan de oude pof
## Waar vlekken en kraters op het bord liggen: net boven het bordmodel, op de
## hoogte van de bloedplassen van PawnView (pion-hoogte 0,05 + 0,015).
const GROND_Y := 0.065
const AARDE_KLEUR := Color(0.3, 0.22, 0.15)    # kluiten

static var _krater_tex: Texture2D = null


## Een plukje stof: de stofwolk uit assets/textures/dust/ (stof*.png, van de
## studio) in zijn eigen kleur, anders de witte pof in stofkleur. `donker` maakt
## hem wat donkerder (aarde bij een inslag).
static func _stofpluk(ouder: Node3D, van: Vector3, naar: Vector3, m0: float, m1: float, duur: float,
		alfa: float, vol: float, trans: int, donker: float = 0.0) -> void:
	var e := _kies_geleverd("dust", "stof", 2.3, 256, true, true)
	if e.is_empty():
		_rookpluk(ouder, van, naar, m0, m1, duur, alfa, vol, trans, 6, "white_smoke", STOF_KLEUR.darkened(donker))
	else:
		# een geleverde wolk is scherper en dichter dan de oude pof: groter en wat
		# doorzichtiger, zodat de plukjes samen een wolk vormen
		_pluk(ouder, e, van, naar, m0 * STOF_BEELD_MAAT, m1 * STOF_BEELD_MAAT, duur, alfa * STOF_BEELD_ALFA, vol,
			trans, -1, Color.WHITE.darkened(donker), 0, _r().randf() < 0.5)


static func _vlak(richting: Vector3) -> Vector3:
	var v := Vector3(richting.x, 0.0, richting.z)
	return v.normalized() if v.length() > 0.001 else Vector3(0.0, 0.0, -1.0)


## Stof bij de landing van een charge (stof-landing): een kring stofwolken die
## vanaf de hoeven over de grond naar buiten rolt, opzwelt en wegzakt.
static func stof_landing(ouder: Node3D, pos: Vector3) -> void:
	var sterkte: float = PawnView.fx("stof_landing", 1.0)
	if sterkte <= 0.0 or ouder == null:
		return
	var r := _r()
	var grond := Vector3(pos.x, 0.08, pos.z)
	var wind := _wind(ouder) * PawnView.fx("smoke_wind", 0.6) * 0.3
	var n := int(round(12.0 * clampf(sterkte, 0.3, 2.0)))
	for i in n:
		var h := TAU * float(i) / float(n) + r.randf_range(-0.2, 0.2)
		var d := Vector3(cos(h), 0.0, sin(h))
		var naar := grond + d * r.randf_range(0.5, 0.8) * sterkte + Vector3.UP * r.randf_range(0.05, 0.2) + wind
		_stofpluk(ouder, grond + d * 0.12, naar, 0.15, r.randf_range(0.45, 0.58) * sterkte,
			r.randf_range(0.9, 1.3), PawnView.fx("stof_alfa", 0.7), 0.35, Tween.TRANS_EXPO)


## Een stofje achter iets dat hard over het bord gaat (stof-galop): een ruiter
## in galop, een kanon dat wordt verreden. `factor` schaalt (een kanon minder).
static func stof_spoor(ouder: Node3D, pos: Vector3, richting: Vector3, factor: float = 1.0) -> void:
	var sterkte: float = PawnView.fx("stof_galop", 1.0) * factor
	if sterkte <= 0.0 or ouder == null:
		return
	var r := _r()
	var achter := -_vlak(richting)
	var zij := Vector3(-achter.z, 0.0, achter.x)
	var wind := _wind(ouder) * PawnView.fx("smoke_wind", 0.6) * 0.2
	for kant in [-1.0, 1.0]:
		var van: Vector3 = Vector3(pos.x, 0.08, pos.z) + achter * 0.18 + zij * float(kant) * r.randf_range(0.06, 0.16)
		var naar: Vector3 = van + achter * r.randf_range(0.15, 0.3) + zij * float(kant) * 0.08 \
			+ Vector3.UP * r.randf_range(0.1, 0.24) + wind
		_stofpluk(ouder, van, naar, 0.1, r.randf_range(0.3, 0.42) * sterkte, r.randf_range(0.6, 0.9),
			PawnView.fx("stof_alfa", 0.7) * 0.85, 0.3, Tween.TRANS_CUBIC)


## Opspattende aarde bij een kanonsinslag (aarde-inslag): kluiten die in een
## waaier met de kogel mee wegspatten, neerkomen, even blijven liggen en
## verdwijnen, en een stofwolk die opstijgt.
static func inslag_aarde(ouder: Node3D, pos: Vector3, richting: Vector3) -> void:
	var sterkte: float = PawnView.fx("aarde_inslag", 1.0)
	if sterkte <= 0.0 or ouder == null:
		return
	var r := _r()
	var grond := Vector3(pos.x, 0.06, pos.z)
	var vooruit := _vlak(richting)
	for i in int(round(12.0 * clampf(sterkte, 0.3, 2.0))):
		var h := r.randf_range(0.0, TAU)
		var d := Vector3(cos(h), 0.0, sin(h))
		var v := (d * r.randf_range(0.5, 1.2) + vooruit * r.randf_range(0.4, 1.0)) * sterkte \
			+ Vector3.UP * r.randf_range(1.6, 2.8)
		_kluit(ouder, grond, v, r.randf_range(0.035, 0.065) * clampf(sterkte, 0.5, 1.5))
	var wind := _wind(ouder) * PawnView.fx("smoke_wind", 0.6) * 0.4
	for i in int(round(6.0 * clampf(sterkte, 0.3, 2.0))):
		var h := r.randf_range(0.0, TAU)
		var d := Vector3(cos(h), 0.0, sin(h))
		var naar := grond + d * r.randf_range(0.2, 0.45) + vooruit * 0.15 + Vector3.UP * r.randf_range(0.25, 0.55) + wind
		_stofpluk(ouder, grond + d * 0.05, naar, 0.18, r.randf_range(0.45, 0.62) * sterkte,
			r.randf_range(1.1, 1.6), PawnView.fx("stof_alfa", 0.7), 0.35, Tween.TRANS_EXPO, 0.12)


## Een kluit aarde: een klein blokje dat tollend een boog vliegt, op het bord
## landt, daar 1,5-3 s blijft liggen en dan wegkrimpt.
static func _kluit(ouder: Node3D, start: Vector3, v: Vector3, maat: float) -> void:
	var r := _r()
	var mi := MeshInstance3D.new()
	var blok := BoxMesh.new()
	blok.size = Vector3.ONE
	mi.mesh = blok
	var mat := StandardMaterial3D.new()
	mat.albedo_color = AARDE_KLEUR.darkened(r.randf_range(0.0, 0.3))
	mat.roughness = 1.0
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ouder.add_child(mi)
	mi.position = start
	mi.scale = Vector3(maat, maat * r.randf_range(0.6, 1.0), maat * r.randf_range(0.7, 1.2))
	var g := 6.0
	var vloer := 0.06 + maat * 0.4
	var vlucht: float = maxf((v.y + sqrt(v.y * v.y + 2.0 * g * maxf(start.y - vloer, 0.0))) / g, 0.15)
	var tol := Vector3(r.randf_range(-12.0, 12.0), r.randf_range(-12.0, 12.0), r.randf_range(-12.0, 12.0))
	var tw := mi.create_tween()
	tw.tween_method(func(t: float) -> void:
		var p := start + v * t + Vector3(0.0, -0.5 * g, 0.0) * t * t
		p.y = maxf(p.y, vloer)
		mi.position = p
		mi.rotation = tol * t, 0.0, vlucht, vlucht)
	tw.tween_interval(r.randf_range(1.5, 3.0))
	tw.tween_property(mi, "scale", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


## Een krater of schroeiplek op het bord (krater, krater-duur): een donkere,
## onregelmatige plek met een randje opgeworpen aarde, die even blijft liggen en
## dan vervaagt. Een van de kraters uit assets/textures/decals/ (krater*.png, van
## de studio), willekeurig gedraaid; zonder die bestanden een textuur uit code.
static func krater(ouder: Node3D, pos: Vector3) -> void:
	var sterkte: float = PawnView.fx("krater", 1.0)
	if sterkte <= 0.0 or ouder == null:
		return
	var r := _r()
	var mi := MeshInstance3D.new()
	var vlak := QuadMesh.new()
	vlak.size = Vector2.ONE * 0.9 * sterkte
	mi.mesh = vlak
	var mat := StandardMaterial3D.new()
	var geleverd := _kies_geleverd("decals", "krater", 0.0, 512)
	mat.albedo_texture = geleverd.tex if not geleverd.is_empty() else _krater_textuur()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 1.0
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ouder.add_child(mi)
	mi.position = Vector3(pos.x, GROND_Y, pos.z)
	mi.rotation = Vector3(-PI * 0.5, r.randf_range(0.0, TAU), 0.0)
	mi.scale = Vector3.ONE * 0.3
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(PawnView.fx("krater_duur", 25.0), 0.5))
	tw.tween_property(mat, "albedo_color:a", 0.0, 2.0)
	tw.tween_callback(mi.queue_free)


static func _krater_textuur() -> Texture2D:
	if _krater_tex != null:
		return _krater_tex
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var ruis := FastNoiseLite.new()
	ruis.seed = 61026
	ruis.frequency = 0.05
	var verkoold := Color(0.07, 0.055, 0.045)
	var aarde := Color(0.33, 0.25, 0.17)
	var opgeworpen := Color(0.46, 0.37, 0.26)
	for y in n:
		for x in n:
			var dx := (float(x) - float(n) * 0.5 + 0.5) / (float(n) * 0.5)
			var dy := (float(y) - float(n) * 0.5 + 0.5) / (float(n) * 0.5)
			var afstand := sqrt(dx * dx + dy * dy)
			var hoek := atan2(dy, dx)
			var rand: float = 0.8 + 0.12 * ruis.get_noise_2d(cos(hoek) * 25.0, sin(hoek) * 25.0)
			var k: float = afstand / rand
			var kleur := aarde.lerp(verkoold, 1.0 - smoothstep(0.0, 0.7, k))
			var ring: float = smoothstep(0.6, 0.86, k) * (1.0 - smoothstep(0.86, 1.0, k))
			kleur = kleur.lerp(opgeworpen, ring * 0.65)
			kleur.a = (1.0 - smoothstep(0.86, 1.0, k)) * (0.8 + 0.2 * ruis.get_noise_2d(float(x) * 3.0, float(y) * 3.0))
			img.set_pixel(x, y, kleur)
	img.generate_mipmaps()
	_krater_tex = ImageTexture.create_from_image(img)
	return _krater_tex


## De inslag op het geraakte stuk (sterker = meer en verder). Per materiaal
## (`materiaal` = PawnView.impact_categorie, dezelfde indeling als het geluid;
## 6 oktober, inslag-materiaal): vlees een rode nevel en spatjes, hout (een
## kanon) splinters en houtstof, metaal (het kuras van de hp-pion) vonken met
## een witte flits. Leeg of knop 0: overal de gele vonken van vroeger.
static func vonken(ouder: Node3D, pos: Vector3, kracht: float, materiaal: String = "",
		richting: Vector3 = Vector3.ZERO) -> void:
	if materiaal != "" and PawnView.fx("inslag_materiaal", 1.0) > 0.0:
		match materiaal:
			"impact_flesh":
				inslag_vlees(ouder, pos, kracht, richting)
				return
			"impact_wood":
				inslag_hout(ouder, pos, kracht, richting)
				return
			"impact_armor":
				_flits(ouder, pos, 0.07 * clampf(kracht, 0.6, 1.6))
	var n: int = int(clampf(6.0 * kracht, 3.0, 12.0))
	for i in n:
		var spark := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radial_segments = 6
		mesh.rings = 3
		var r := randf_range(0.02, 0.05)
		mesh.radius = r
		mesh.height = r * 2.0
		spark.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.85, 0.4)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.8, 0.3)
		mat.emission_energy_multiplier = 2.0
		spark.material_override = mat
		spark.position = pos
		ouder.add_child(spark)
		var dir := Vector3(randf_range(-1, 1), randf_range(0.3, 1.2), randf_range(-1, 1)).normalized()
		var dist := randf_range(0.3, 0.7) * maxf(kracht, 0.4)
		var life := randf_range(0.25, 0.45)
		var tw := spark.create_tween().set_parallel()
		tw.tween_property(spark, "position", pos + dir * dist, life).set_ease(Tween.EASE_OUT)
		tw.tween_property(mat, "albedo_color:a", 0.0, life).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(spark.queue_free)


# --- Bloed en inslag (6 oktober, stap 4) -------------------------------------------

const BLOED_KLEUR := Color(0.42, 0.02, 0.03)
const HOUT_KLEUR := Color(0.6, 0.45, 0.28)


## Vlees: een rode nevel die met de klap mee uitwaait en een paar spatjes die
## op het bord vallen (het wondbloed zelf komt uit PawnView.play_wound).
static func inslag_vlees(ouder: Node3D, pos: Vector3, kracht: float, richting: Vector3) -> void:
	var r := _r()
	var dir := _vlak(richting)
	var k := clampf(kracht, 0.5, 1.8) * PawnView.fx("inslag_sterkte", 1.0)
	if k <= 0.0:
		return
	for i in 3:
		var naar := pos + dir * r.randf_range(0.18, 0.4) \
			+ Vector3(r.randf_range(-0.1, 0.1), r.randf_range(0.0, 0.15), r.randf_range(-0.1, 0.1))
		_rookpluk(ouder, pos, naar, 0.08, r.randf_range(0.3, 0.42) * k, r.randf_range(0.35, 0.55),
			0.8, 0.25, Tween.TRANS_EXPO, 5, "white_smoke", BLOED_KLEUR)
	for i in int(round(4.0 * k)):
		var v := dir * r.randf_range(0.6, 1.5) + Vector3(r.randf_range(-0.5, 0.5), r.randf_range(0.4, 1.2),
			r.randf_range(-0.5, 0.5))
		_druppel(ouder, pos, v, r.randf_range(0.012, 0.02))


## Hout (een kanon): splinters die tollend wegvliegen en blijven liggen, en een
## wolkje houtstof.
static func inslag_hout(ouder: Node3D, pos: Vector3, kracht: float, richting: Vector3) -> void:
	var r := _r()
	var dir := _vlak(richting)
	var k := clampf(kracht, 0.5, 2.0) * PawnView.fx("inslag_sterkte", 1.0)
	if k <= 0.0:
		return
	for i in int(round(9.0 * k)):
		var h := r.randf_range(0.0, TAU)
		var v := (Vector3(cos(h), 0.0, sin(h)) * r.randf_range(0.4, 1.0) + dir * r.randf_range(0.3, 0.9)) * k \
			+ Vector3.UP * r.randf_range(0.8, 2.0)
		_splinter(ouder, pos, v, r.randf_range(0.05, 0.1) * clampf(k, 0.7, 1.4))
	for i in 3:
		var naar := pos + Vector3(r.randf_range(-0.2, 0.2), r.randf_range(0.1, 0.3), r.randf_range(-0.2, 0.2)) + dir * 0.1
		_rookpluk(ouder, pos, naar, 0.08, r.randf_range(0.22, 0.32) * k, r.randf_range(0.6, 0.9),
			0.6, 0.25, Tween.TRANS_EXPO, 6, "white_smoke", HOUT_KLEUR.lightened(0.15))


## Een korte witte flits op het inslagpunt (metaal: de kogel ketst op het kuras).
static func _flits(ouder: Node3D, pos: Vector3, straal: float) -> void:
	var mi := MeshInstance3D.new()
	var bol := SphereMesh.new()
	bol.radius = 1.0
	bol.height = 2.0
	bol.radial_segments = 16   # rond, ook groot (8 gaf een zeshoek bij een explosie)
	bol.rings = 8
	mi.mesh = bol
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.95, 0.82, 0.8)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ouder.add_child(mi)
	mi.position = pos
	mi.scale = Vector3.ONE * straal * 0.4
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * straal, 0.05).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.1).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)


## Een splinter: een dun latje hout dat tollend een boog vliegt, op het bord
## landt, even blijft liggen en wegkrimpt.
static func _splinter(ouder: Node3D, start: Vector3, v: Vector3, lengte: float) -> void:
	var r := _r()
	var mi := MeshInstance3D.new()
	var blok := BoxMesh.new()
	blok.size = Vector3.ONE
	mi.mesh = blok
	var mat := StandardMaterial3D.new()
	mat.albedo_color = HOUT_KLEUR.darkened(r.randf_range(0.0, 0.35))
	mat.roughness = 0.9
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ouder.add_child(mi)
	mi.position = start
	mi.scale = Vector3(lengte * 0.16, lengte * 0.12, lengte)
	var g := 6.0
	var vloer := 0.06
	var vlucht: float = maxf((v.y + sqrt(v.y * v.y + 2.0 * g * maxf(start.y - vloer, 0.0))) / g, 0.15)
	var tol := Vector3(r.randf_range(-14.0, 14.0), r.randf_range(-14.0, 14.0), r.randf_range(-14.0, 14.0))
	var tw := mi.create_tween()
	tw.tween_method(func(t: float) -> void:
		var p := start + v * t + Vector3(0.0, -0.5 * g, 0.0) * t * t
		p.y = maxf(p.y, vloer)
		mi.position = p
		mi.rotation = tol * t, 0.0, vlucht, vlucht)
	tw.tween_interval(r.randf_range(2.0, 4.0))
	tw.tween_property(mi, "scale", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


## Een druppel bloed die een boog vliegt en waar hij neerkomt een klein vlekje
## achterlaat (een splat-texture uit assets/textures/blood/, in de groep
## battlefield_debris, dus het spel ruimt hem met de lijken op).
static func _druppel(ouder: Node3D, start: Vector3, v: Vector3, maat: float) -> void:
	var mi := MeshInstance3D.new()
	var bol := SphereMesh.new()
	bol.radius = 1.0
	bol.height = 2.0
	bol.radial_segments = 6
	bol.rings = 3
	mi.mesh = bol
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BLOED_KLEUR
	mat.roughness = 0.3
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ouder.add_child(mi)
	mi.position = start
	mi.scale = Vector3.ONE * maat
	var g := 6.0
	var vloer := 0.06
	var vlucht: float = maxf((v.y + sqrt(v.y * v.y + 2.0 * g * maxf(start.y - vloer, 0.0))) / g, 0.1)
	var tw := mi.create_tween()
	tw.tween_method(func(t: float) -> void:
		var p := start + v * t + Vector3(0.0, -0.5 * g, 0.0) * t * t
		p.y = maxf(p.y, vloer)
		mi.position = p, 0.0, vlucht, vlucht)
	tw.tween_callback(func() -> void:
		if is_instance_valid(ouder):
			_vlek(ouder, mi.position, v, maat * 6.0)
		mi.queue_free())


## Een bloedvlek op het bord, langgerekt in de richting `v` (een spat landt
## schuin), even uitvloeiend.
static func _vlek(ouder: Node3D, pos: Vector3, v: Vector3, maat: float, vertraging: float = 0.0) -> void:
	var r := _r()
	var tex := _splat()
	var mi := MeshInstance3D.new()
	var vlak := PlaneMesh.new()
	var rek: float = 1.0 + clampf(Vector2(v.x, v.z).length() * 0.5, 0.0, 1.2)
	vlak.size = Vector2(maat, maat * rek)
	mi.mesh = vlak
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.4
	if tex != null:
		mat.albedo_texture = tex
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	else:
		mat.albedo_color = BLOED_KLEUR
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ouder.add_child(mi)
	mi.add_to_group("battlefield_debris")
	mi.position = Vector3(pos.x, GROND_Y + 0.001 + r.randf_range(0.0, 0.005), pos.z)
	mi.rotation.y = atan2(v.x, v.z) if Vector2(v.x, v.z).length() > 0.01 else r.randf_range(0.0, TAU)
	mi.scale = Vector3(0.1, 1.0, 0.1)
	mi.visible = vertraging <= 0.0
	var tw := mi.create_tween()
	if vertraging > 0.0:
		tw.tween_interval(vertraging)
		tw.tween_callback(mi.show)
	tw.tween_property(mi, "scale", Vector3.ONE, r.randf_range(0.15, 0.3)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Een splat-texture, gekozen met de eigen rng (PawnView laadt de map; zijn
## eigen keuze trekt uit de globale rng, dus die vragen we alleen de eerste keer).
static func _splat() -> Texture2D:
	if not PawnView._blood_tex_loaded and PawnView._blood_texture("splat") == null:
		return null
	var keuze: Array = []
	for e in PawnView._blood_textures:
		if String(e.name).begins_with("splat"):
			keuze.append(e.tex)
	if keuze.is_empty():
		return null
	return keuze[_r().randi_range(0, keuze.size() - 1)]


## De bloedwaaier (bloed-waaier): bij een dode een waaier van langgerekte
## spatten op het bord, van de klap af, die na elkaar verschijnen alsof ze
## net neerkomen. Meer kracht = verder en meer.
static func bloed_waaier(ouder: Node3D, pos: Vector3, richting: Vector3, kracht: float) -> void:
	var sterkte: float = PawnView.fx("bloed_waaier", 1.0)
	if sterkte <= 0.0 or ouder == null:
		return
	var r := _r()
	var dir := _vlak(richting)
	var k := clampf(kracht, 0.5, 2.0) * sterkte
	for i in int(round(9.0 * k)):
		var hoek := r.randf_range(-0.55, 0.55)
		var d := dir.rotated(Vector3.UP, hoek)
		var afstand := r.randf_range(0.15, 0.75) * k
		var punt := Vector3(pos.x, 0.0, pos.z) + d * afstand
		_vlek(ouder, punt, d * (1.0 + afstand * 2.0), r.randf_range(0.2, 0.36) * clampf(k, 0.8, 1.5),
			0.05 + afstand * 0.25)


# --- Vuur en explosies (6 oktober, stap 5) -----------------------------------------

## Een vlam: een billboard die rechtop blijft (om de verticale as), met een vorm
## die naar boven smal wordt en ruis die omhoog stroomt en golft. Geen textuur:
## de ruis rekent de shader zelf. Additief, dus hij gloeit op elk bord.
const VUUR_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform float tijd_offset = 0.0;
uniform float sterkte = 1.0;
uniform float snelheid = 1.0;
uniform vec4 kern_kleur : source_color = vec4(1.0, 0.78, 0.32, 1.0);
uniform vec4 vlam_kleur : source_color = vec4(0.95, 0.4, 0.08, 1.0);
uniform vec4 rand_kleur : source_color = vec4(0.5, 0.07, 0.02, 1.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float ruis(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		s += a * ruis(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return s;
}

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float t = TIME * snelheid + tijd_offset;
	float x = (UV.x - 0.5) * 2.0;
	float y = 1.0 - UV.y;
	float golf = (fbm(vec2(y * 2.0 - t * 1.3, t * 0.4)) - 0.5) * 0.7 * y;
	float n = fbm(vec2((x + golf) * 2.6, y * 3.0 - t * 2.8));
	// een druppelvorm: rond onderaan, het breedst op een kwart, spits naar boven
	float breedte = 0.72 * pow(sin(3.14159 * clamp(y * 0.85 + 0.12, 0.0, 1.0)), 0.6) * (1.0 - 0.55 * y);
	float d = abs(x + golf) / max(breedte, 0.01);
	float vorm = 1.0 - smoothstep(0.35, 1.0, d + (n - 0.5) * 0.5);
	float hoog = 1.0 - smoothstep(0.3, 0.95, y + (n - 0.5) * 0.7);
	float voet = smoothstep(0.0, 0.1, y);
	float vlam = clamp(vorm * hoog * voet * (0.15 + n * 1.0), 0.0, 1.0);
	vec3 kleur = mix(rand_kleur.rgb, vlam_kleur.rgb, smoothstep(0.08, 0.45, vlam));
	kleur = mix(kleur, kern_kleur.rgb, smoothstep(0.6, 0.95, vlam));
	ALBEDO = kleur * 0.85 * sterkte;
	ALPHA = smoothstep(0.03, 0.5, vlam) * clamp(sterkte, 0.0, 1.0);
}
"""

static var _vuur_shader: Shader = null

## Een vlam uit een plaatje (assets/textures/flame/vlam*.png, van de studio): dezelfde
## staande billboard als hierboven, met het deel van het plaatje waar de vlam staat
## (`uitsnede`), dat golft (hoe hoger hoe meer, de voet blijft staan) en flakkert;
## een vel (`rooster`) speelt zijn beeldjes af. Additief: zwart telt niet mee.
const VLAM_BEELD_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D vlam_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 uitsnede = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 rooster = vec2(1.0, 1.0);
uniform float tijd_offset = 0.0;
uniform float sterkte = 1.0;
uniform float snelheid = 1.0;
uniform float spiegel = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float ruis(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float t = TIME * snelheid + tijd_offset;
	vec2 uv = UV;
	if (spiegel > 0.5) {
		uv.x = 1.0 - uv.x;
	}
	float y = 1.0 - uv.y;
	uv.x += (ruis(vec2(y * 3.0 - t * 2.4, t * 0.6)) - 0.5) * 0.16 * y;
	uv.y += (ruis(vec2(uv.x * 5.0, y * 2.0 - t * 3.1)) - 0.5) * 0.05 * y;
	vec2 cel = vec2(0.0);
	float n = rooster.x * rooster.y;
	if (n > 1.0) {
		float beeld = mod(floor(t * 12.0), n);
		cel = vec2(mod(beeld, rooster.x), floor(beeld / rooster.x));
	}
	vec2 bron = (cel + uitsnede.xy + clamp(uv, 0.0, 1.0) * uitsnede.zw) / rooster;
	vec4 c = texture(vlam_tex, bron);
	float flakker = 0.82 + 0.18 * ruis(vec2(t * 7.0, 3.1));
	ALBEDO = c.rgb * flakker * sterkte * 1.1;
	ALPHA = c.a;
}
"""
static var _vlam_beeld_shader: Shader = null


## Een vlam-quad met de vuur-shader, de voet op `voet`, `hoog` hoog; met een
## geleverd vlam-plaatje (de studio) die in plaats van de shader-vlam.
static func _vlam(ouder: Node3D, voet: Vector3, hoog: float) -> MeshInstance3D:
	var geleverd := _kies_geleverd("flame", "vlam", 0.0, 512)
	if not geleverd.is_empty():
		return _vlam_beeld(ouder, voet, hoog, geleverd)
	if _vuur_shader == null:
		_vuur_shader = Shader.new()
		_vuur_shader.code = VUUR_SHADER
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.7, 1.0)
	mi.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = _vuur_shader
	mat.set_shader_parameter("tijd_offset", _r().randf_range(0.0, 50.0))
	mat.set_shader_parameter("snelheid", _r().randf_range(0.85, 1.15))
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ouder.add_child(mi)
	mi.position = voet + Vector3.UP * hoog * 0.5
	mi.scale = Vector3.ONE * hoog
	return mi


static func _vlam_beeld(ouder: Node3D, voet: Vector3, hoog: float, e: Dictionary) -> MeshInstance3D:
	if _vlam_beeld_shader == null:
		_vlam_beeld_shader = Shader.new()
		_vlam_beeld_shader.code = VLAM_BEELD_SHADER
	var tex: Texture2D = e.tex
	var u: Rect2 = e.uitsnede
	var cols := int(e.cols)
	var rows := int(e.rows)
	var celw: float = float(tex.get_width()) / float(cols) * u.size.x
	var celh: float = float(tex.get_height()) / float(rows) * u.size.y
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(clampf(celw / maxf(celh, 1.0), 0.3, 2.0), 1.0)
	mi.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = _vlam_beeld_shader
	mat.set_shader_parameter("vlam_tex", tex)
	mat.set_shader_parameter("uitsnede", Vector4(u.position.x, u.position.y, u.size.x, u.size.y))
	mat.set_shader_parameter("rooster", Vector2(cols, rows))
	mat.set_shader_parameter("tijd_offset", _r().randf_range(0.0, 50.0))
	mat.set_shader_parameter("snelheid", _r().randf_range(0.85, 1.15))
	mat.set_shader_parameter("spiegel", 1.0 if _r().randf() < 0.5 else 0.0)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ouder.add_child(mi)
	var h := hoog * 1.25    # het plaatje is de hele vlam, de shader-vlam had lucht erboven
	mi.position = voet + Vector3.UP * h * 0.5
	mi.scale = Vector3.ONE * h
	return mi


## Een vuurtje dat `duur` seconden brandt (vuur-maat): twee of drie vlammen,
## een flakkerend licht, rook die opkringelt en af en toe een vonkje; daarna
## dooft het. Hangt onder een eigen node die zichzelf opruimt.
static func vuur(ouder: Node3D, pos: Vector3, maat: float = 1.0, duur: float = 12.0) -> void:
	var m: float = maat * PawnView.fx("vuur_maat", 1.0)
	if m <= 0.0 or duur <= 0.0 or ouder == null:
		return
	var r := _r()
	var haard := Node3D.new()
	haard.name = "Vuur"
	ouder.add_child(haard)
	haard.position = Vector3(pos.x, GROND_Y, pos.z)
	var vlammen: Array = []
	for i in 3:
		var vl := _vlam(haard, Vector3(r.randf_range(-0.07, 0.07), 0.0, r.randf_range(-0.07, 0.07)) * m,
			r.randf_range(0.3, 0.45) * m * (1.0 if i == 0 else 0.7))
		vlammen.append(vl)
	var licht := OmniLight3D.new()
	licht.light_color = Color(1.0, 0.62, 0.28)
	licht.omni_range = 2.2 * m
	licht.position = Vector3.UP * 0.35 * m
	haard.add_child(licht)
	var staat := {"rook": 0.0, "vonk": 0.0}
	var tw := haard.create_tween()
	tw.tween_method(func(t: float) -> void:
		var uit: float = clampf((duur - t) / 1.5, 0.0, 1.0)   # de laatste 1,5 s dooft het
		var aan: float = clampf(t / 0.4, 0.0, 1.0)            # en de eerste 0,4 s laait het op
		var s: float = aan * uit
		licht.light_energy = 1.4 * m * s * (0.82 + 0.1 * sin(t * 13.0) + 0.08 * sin(t * 31.0 + 1.3))
		for vl in vlammen:
			(vl.material_override as ShaderMaterial).set_shader_parameter("sterkte", s)
		if t >= float(staat.rook) and s > 0.2:
			staat.rook = t + r.randf_range(0.3, 0.5)
			var van := haard.position + Vector3.UP * 0.4 * m
			_rookpluk(ouder, van, van + Vector3.UP * r.randf_range(0.7, 1.1) * m + _wind(ouder) * 0.4,
				0.15 * m, r.randf_range(0.45, 0.7) * m, r.randf_range(1.8, 2.6), 0.55 * s, 0.25)
		if t >= float(staat.vonk) and s > 0.5:
			staat.vonk = t + r.randf_range(0.6, 1.6)
			_gloeiend(ouder, haard.position + Vector3.UP * 0.2 * m,
				Vector3(r.randf_range(-0.3, 0.3), r.randf_range(0.8, 1.4), r.randf_range(-0.3, 0.3)),
				r.randf_range(0.5, 0.9), 0.012),
		0.0, duur, duur)
	tw.tween_callback(haard.queue_free)


## Een explosie (explosie): een felle flits en licht, een vuurbal die opzwelt en
## dooft, een schokgolf over de grond, een kolom donkere rook, brokstukken en
## vonken. `schok` = de schudder van wie de camera heeft (mag leeg).
static func explosie(ouder: Node3D, pos: Vector3, kracht: float = 1.0, schok: Callable = Callable()) -> void:
	var k: float = clampf(kracht, 0.3, 2.5) * PawnView.fx("explosie", 1.0)
	if k <= 0.0 or ouder == null:
		return
	var r := _r()
	var grond := Vector3(pos.x, GROND_Y, pos.z)
	_flits(ouder, grond + Vector3.UP * 0.3 * k, 0.45 * k)
	var licht := OmniLight3D.new()
	licht.light_color = Color(1.0, 0.7, 0.35)
	licht.light_energy = 6.0 * k
	licht.omni_range = 4.5 * k
	ouder.add_child(licht)
	licht.position = grond + Vector3.UP * 0.5
	var ltw := licht.create_tween()
	ltw.tween_property(licht, "light_energy", 0.0, 0.6).set_ease(Tween.EASE_OUT)
	ltw.tween_callback(licht.queue_free)
	# de vuurbal: de kanonsvlam (assets/textures/fire/) groot, drie keer kort na
	# elkaar en iets uit elkaar, zodat hij opbolt
	_vuurbal(ouder, grond + Vector3.UP * 0.35 * k, 1.7 * k, 0.0)
	_vuurbal(ouder, grond + Vector3(r.randf_range(-0.2, 0.2), 0.25, r.randf_range(-0.2, 0.2)) * k, 1.2 * k, 0.05)
	_vuurbal(ouder, grond + Vector3(r.randf_range(-0.2, 0.2), 0.5, r.randf_range(-0.2, 0.2)) * k, 1.0 * k, 0.1)
	_stofring(ouder, grond, 1.2 * k)
	# een kolom donkere rook die opstijgt en met de wind wegdrijft
	var wind := _wind(ouder) * PawnView.fx("smoke_wind", 0.6)
	for i in int(round(8.0 * clampf(k, 0.5, 1.6))):
		var van := grond + Vector3(r.randf_range(-0.2, 0.2), 0.2, r.randf_range(-0.2, 0.2)) * k
		var naar := van + Vector3.UP * r.randf_range(0.8, 1.8) * k + wind * r.randf_range(0.6, 1.2) \
			+ Vector3(r.randf_range(-0.3, 0.3), 0.0, r.randf_range(-0.3, 0.3))
		_rookpluk(ouder, van, naar, 0.3 * k, r.randf_range(0.8, 1.2) * k, r.randf_range(2.5, 3.8), 0.8, 0.35,
			Tween.TRANS_CUBIC, -1, "musket", Color(0.55, 0.52, 0.5))
	# brokstukken en vonken
	for i in int(round(10.0 * clampf(k, 0.5, 1.6))):
		var h := r.randf_range(0.0, TAU)
		_splinter(ouder, grond + Vector3.UP * 0.15,
			Vector3(cos(h), 0.0, sin(h)) * r.randf_range(0.8, 2.0) * k + Vector3.UP * r.randf_range(1.5, 3.2), r.randf_range(0.05, 0.11))
	for i in int(round(8.0 * clampf(k, 0.5, 1.6))):
		var h := r.randf_range(0.0, TAU)
		_gloeiend(ouder, grond + Vector3.UP * 0.2,
			Vector3(cos(h), 0.0, sin(h)) * r.randf_range(0.8, 2.2) * k + Vector3.UP * r.randf_range(1.0, 2.6),
			r.randf_range(0.6, 1.1), r.randf_range(0.014, 0.026))
	if schok.is_valid():
		schok.call(1.3 * k)


## Een vuurbal: de kanonsvlam-flipbook als billboard, `maat` groot, die in
## 0,45 s opzwelt, zijn beeldjes afspeelt en uitdooft (na `vertraging`).
static func _vuurbal(ouder: Node3D, pos: Vector3, maat: float, vertraging: float) -> void:
	var e: Dictionary = PawnView._vfx_entry(PawnView.FIRE_TEX_DIR, 1.5, "cannon")
	if e.is_empty():
		return
	var quad := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	quad.mesh = q
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = e.tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	var cols := int(e.cols)
	var rows := int(e.rows)
	if cols * rows > 1:
		mat.uv1_scale = Vector3(1.0 / cols, 1.0 / rows, 1.0)
		PawnView._sheet_frame(0, mat, cols, rows)
	quad.material_override = mat
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ouder.add_child(quad)
	quad.position = pos
	quad.scale = Vector3.ONE * maat * 0.35
	quad.visible = vertraging <= 0.0
	var duur := 0.45
	var tw := quad.create_tween()
	if vertraging > 0.0:
		tw.tween_interval(vertraging)
		tw.tween_callback(quad.show)
	tw.set_parallel(true)
	tw.tween_property(quad, "scale", Vector3.ONE * maat, duur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	if cols * rows > 1:
		tw.tween_method(PawnView._sheet_frame.bind(mat, cols, rows), 0, cols * rows - 1, duur)
	tw.tween_property(mat, "albedo_color:a", 0.0, duur * 0.6).set_delay(duur * 0.4).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(quad.queue_free)


## De schokgolf: een kring stof die over de grond wegschiet (EXPO: eerst hard,
## dan stil) en oplost.
static func _stofring(ouder: Node3D, grond: Vector3, straal: float) -> void:
	var r := _r()
	var n := 16
	for i in n:
		var h := TAU * float(i) / float(n) + r.randf_range(-0.1, 0.1)
		var d := Vector3(cos(h), 0.0, sin(h))
		var van := grond + Vector3.UP * 0.05 + d * 0.15
		var naar := grond + Vector3.UP * r.randf_range(0.05, 0.15) + d * straal * r.randf_range(0.85, 1.1)
		_stofpluk(ouder, van, naar, 0.15, r.randf_range(0.35, 0.5) * clampf(straal, 0.6, 2.0), r.randf_range(0.6, 0.9),
			PawnView.fx("stof_alfa", 0.7) * 0.85, 0.3, Tween.TRANS_EXPO)


## Een kanon gaat kapot (kanon-kapot): het kruit ontploft (kleiner dan een
## kruitvat), de affuit spat in splinters uiteen en het wrak brandt na
## (vuur-duur; 0 = geen brand).
static func kanon_kapot(ouder: Node3D, pos: Vector3, richting: Vector3, kracht: float) -> void:
	if ouder == null or PawnView.fx("kanon_kapot", 1.0) <= 0.0:
		return
	explosie(ouder, pos, clampf(kracht, 0.6, 1.4) * 0.75)
	inslag_hout(ouder, pos + Vector3.UP * 0.3, clampf(kracht, 0.6, 1.4) * 1.5, richting)
	var brand: float = PawnView.fx("vuur_duur", 12.0)
	if brand > 0.0:
		vuur(ouder, pos + _vlak(richting) * 0.1, 0.8, brand)


## Het "-N" dat boven een geraakte pion opstijgt en vervaagt.
static func schade_getal(ouder: Node3D, pos: Vector3, tekst: String,
		kleur: Color = Color(1.0, 0.32, 0.26)) -> void:
	var label := Label3D.new()
	label.text = tekst
	label.font_size = 88
	label.outline_size = 16
	label.outline_modulate = Color(0.05, 0.02, 0.02, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = kleur
	label.position = pos
	ouder.add_child(label)
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y + 0.9, 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)

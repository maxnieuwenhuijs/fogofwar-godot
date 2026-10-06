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
	var e: Dictionary = PawnView._vfx_entry(PawnView.SMOKE_TEX_DIR, 2.3, wens)
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
			PawnView._sheet_frame(1, mat, cols, rows)   # beeldje 0 draagt de vlam van het schot
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
		tw.tween_method(PawnView._sheet_frame.bind(mat, cols, rows), 1, laatste, duur)
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
	var vloer := 0.07   # net boven het bord (de tegels liggen op 0,05)
	for i in n:
		var v := as_ * r.randf_range(1.2, 2.6) * (1.4 if kanon else 1.0) \
			+ Vector3(r.randf_range(-0.5, 0.5), r.randf_range(0.2, 0.9), r.randf_range(-0.5, 0.5))
		var duur := r.randf_range(0.55, 0.95) * (1.3 if kanon else 1.0)
		var grootte := r.randf_range(0.012, 0.022) * (1.4 if kanon else 1.0)
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
const AARDE_KLEUR := Color(0.3, 0.22, 0.15)    # kluiten

static var _krater_tex: Texture2D = null


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
		_rookpluk(ouder, grond + d * 0.12, naar, 0.15, r.randf_range(0.45, 0.58) * sterkte,
			r.randf_range(0.9, 1.3), PawnView.fx("stof_alfa", 0.7), 0.35, Tween.TRANS_EXPO, 6, "white_smoke", STOF_KLEUR)


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
		_rookpluk(ouder, van, naar, 0.1, r.randf_range(0.3, 0.42) * sterkte, r.randf_range(0.6, 0.9),
			PawnView.fx("stof_alfa", 0.7) * 0.85, 0.3, Tween.TRANS_CUBIC, 6, "white_smoke", STOF_KLEUR)


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
		_rookpluk(ouder, grond + d * 0.05, naar, 0.18, r.randf_range(0.45, 0.62) * sterkte,
			r.randf_range(1.1, 1.6), PawnView.fx("stof_alfa", 0.7), 0.35, Tween.TRANS_EXPO, 6, "white_smoke",
			STOF_KLEUR.darkened(0.12))


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
## dan vervaagt. De textuur wordt eenmalig in code gemaakt (geen bestand).
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
	mat.albedo_texture = _krater_textuur()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 1.0
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ouder.add_child(mi)
	mi.position = Vector3(pos.x, 0.056, pos.z)
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


## Korte vonken- en stofexplosie op het inslagpunt (sterker = meer en verder).
static func vonken(ouder: Node3D, pos: Vector3, kracht: float) -> void:
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

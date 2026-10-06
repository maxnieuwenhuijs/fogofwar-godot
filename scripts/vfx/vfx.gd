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
## Let op de rng: deze functies zijn uit game.gd verhuisd en trekken nog uit de
## globale rng, in dezelfde volgorde als daarvoor (uispel blijft zo gelijk).
## Nieuwe effecten gebruiken een eigen RandomNumberGenerator.


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
	# Inslagrook zodra de kogel aankomt (zelfde richting = momentum).
	var inslag_aantal: int = 3 if kanon else 2
	var inslag_maat: float = 0.14 if kanon else 0.08
	ouder.get_tree().create_timer(duur).timeout.connect(func() -> void:
		if is_instance_valid(ouder):
			rook(ouder, doel, inslag_aantal, inslag_maat, richting, PawnView.fx("impact_smoke_life", 0.6)))
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
static func rook(ouder: Node3D, pos: Vector3, aantal: int, maat: float, richting: Vector3 = Vector3.ZERO,
		levens_factor: float = 1.0, tex_wens: String = "") -> void:
	PawnView.spawn_powder_smoke(ouder, pos, aantal, maat, richting, levens_factor, tex_wens)


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

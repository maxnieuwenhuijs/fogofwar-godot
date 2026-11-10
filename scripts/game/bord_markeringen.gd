extends RefCounted

## De markeringen op het bord uit het ontwerp van 10 november 2026 (pdf "Match
## HUD", rechterhelft: assets/ui/match_hud/icons/). Elke soort heeft een eigen
## VORM en een eigen kleur (kleurenblind: nooit alleen kleur):
##
##   loop        blauw VIERKANT op de tegel, voetstappen er heel licht in (20%),
##               de engine zet de stamina-kost erop (Max, 10 november: "voetstap
##               icon wel vierkant maken en die voetstapjes mogen echt heel
##               heel licht"). De rand is de ruit van de ontwerper, rechtgezet
##               (assets/ui/match_hud/eigen/, tools/verwerk_ui_m3.py)
##   melee       rode ruit met gekruiste zwaarden
##   charge      groene ruit met de paardenkop
##   schot       gouden ruit met het vizier
##   vuurlijn    oranje gestreepte ruit (dracht zonder doel erin)
##   wolfstap    paarse ruit met de poot
##   opstelling  paarse ruit met de vlag
##   geselecteerd  blauwe gestreepte ruit onder je gekozen pion
##
## Een markering ligt PLAT op de tegel (zo vroeg de brief het: "markers lie
## flat on the 3D board"), gedraaid naar de camera zodat het icoon rechtop
## staat voor wie kijkt, ook voor stoel 2 (de camera staat dan andersom). De
## loop-rand niet: die ligt recht op de tegel, alleen zijn voetstappen draaien.
## Staat er een pion op (een doel), dan zie je van de ruit alleen de rand om
## zijn voeten; daarom zweeft hetzelfde icoon ook klein boven zijn hoofd.
##
## Puur beeld: geen staat, geen rng. De knoop die `maak` teruggeeft staat op
## dezelfde plek als de gekleurde plak van vroeger (game._highlights,
## render_digest leest alleen x en z).
##
##   const MARKERING := preload("res://scripts/game/bord_markeringen.gd")
##   var m: Node3D = MARKERING.maak("melee", camera, true)
##   m.position = tile_position(x, y) + Vector3(0, MARKERING.HOOGTE, 0)

const Pack := preload("res://scripts/ui/ui_pack.gd")

## soort -> [plaatje, dekking op de grond, icoon boven een pion?]
const SOORTEN := {
	# de rechtgezette rand zonder voetstappen (tools/verwerk_ui_m3.py)
	"loop": ["match_hud/eigen/Move_order_vierkant", 0.95, false],
	"melee": ["match_hud/icons/Meelee", 1.0, true],
	"charge": ["match_hud/icons/Charge", 1.0, true],
	"schot": ["match_hud/icons/Shot_target", 1.0, true],
	"vuurlijn": ["match_hud/icons/Line_of_fire", 0.55, false],
	"wolfstap": ["match_hud/icons/Wolf_step", 1.0, false],
	"opstelling": ["match_hud/icons/Deploiment", 0.8, false],
	"geselecteerd": ["match_hud/icons/target_markers/Selected_unit", 0.95, false],
	"doel": ["match_hud/icons/target_markers/Enemy_target", 1.0, true],
	"keuze": ["match_hud/icons/target_markers/Selectable_target", 0.95, false],
	"focus": ["match_hud/icons/target_markers/Focus_marker", 0.95, false],
}

const HOOGTE := 0.075        # boven de tegel (top 0,05) en de aura-rand (0,056)
const MAAT := 1.12           # zijde van het vlak in vakken: de ruit zelf vult ~86% van het plaatje
const BOVEN_HOOGTE := 1.7   # het zwevende icoon, boven het hoofd van een pion
const BOVEN_MAAT := 0.86     # in vakken (~64 px op 1080 breed)
const KOST_GROOTTE := 52
## De loop-tegel: de rand als vierkant op de tegel. LOOP_RAND = hoe breed de
## rand zelf is als deel van zijn plaatje (de rest is gloed); LOOP_VULLING =
## hoeveel van de tegel de rand beslaat.
const LOOP_RAND := 0.80
const LOOP_VULLING := 0.90
const STAPPEN := "match_hud/icons/move"   # de losse voetstappen (wit)
const STAPPEN_KLEUR := Color(0.72, 0.88, 1.0, 0.2)
const STAPPEN_MAAT := 0.5

static var _mat: Dictionary = {}    # soort -> StandardMaterial3D (gedeeld)
static var _vlak: PlaneMesh = null
static var _vlak_loop: PlaneMesh = null
static var _vlak_stappen: PlaneMesh = null
static var _mat_stappen: StandardMaterial3D = null


static func kent(soort: String) -> bool:
	return SOORTEN.has(soort) and Pack.bestaat(String(SOORTEN[soort][0]))


## De draai om Y waarmee de bovenkant van een plat plaatje naar "boven op het
## scherm" wijst: de kijkrichting van de camera, op de grond gelegd.
static func draai_naar(camera: Camera3D) -> float:
	if camera == null:
		return 0.0
	var f: Vector3 = -camera.global_transform.basis.z
	f.y = 0.0
	if f.length_squared() < 0.0001:
		return 0.0
	f = f.normalized()
	return atan2(-f.x, -f.z)


static func _materiaal(soort: String) -> StandardMaterial3D:
	if _mat.has(soort):
		return _mat[soort]
	var m := StandardMaterial3D.new()
	m.albedo_texture = Pack.tex(String(SOORTEN[soort][0]))
	m.albedo_color = Color(1.0, 1.0, 1.0, float(SOORTEN[soort][1]))
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.render_priority = 2
	_mat[soort] = m
	return m


## Een markering van deze soort. `bezet` = er staat een pion op: dan ook het
## zwevende icoon (voor de soorten die dat hebben). `kosten` > 0 zet het getal
## op een loop-tegel. Null als het plaatje er niet is (de aanroeper valt dan
## terug op de oude gekleurde plak).
static func maak(soort: String, camera: Camera3D, bezet: bool = false, kosten: int = 0) -> Node3D:
	if not kent(soort):
		return null
	if _vlak == null:
		_vlak = PlaneMesh.new()
		_vlak.size = Vector2(MAAT, MAAT)
	var wortel := Node3D.new()
	wortel.name = "Markering_" + soort
	wortel.set_meta("soort", soort)
	var grond := MeshInstance3D.new()
	grond.name = "Grond"
	grond.material_override = _materiaal(soort)
	grond.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if soort == "loop":
		# een vierkant recht op de tegel, de voetstappen er licht in
		if _vlak_loop == null:
			_vlak_loop = PlaneMesh.new()
			_vlak_loop.size = Vector2(LOOP_VULLING / LOOP_RAND, LOOP_VULLING / LOOP_RAND)
		grond.mesh = _vlak_loop
		wortel.add_child(grond)
		if Pack.bestaat(STAPPEN):
			if _vlak_stappen == null:
				_vlak_stappen = PlaneMesh.new()
				_vlak_stappen.size = Vector2(STAPPEN_MAAT, STAPPEN_MAAT)
				_mat_stappen = StandardMaterial3D.new()
				_mat_stappen.albedo_texture = Pack.tex(STAPPEN)
				_mat_stappen.albedo_color = STAPPEN_KLEUR
				_mat_stappen.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				_mat_stappen.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				_mat_stappen.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				_mat_stappen.cull_mode = BaseMaterial3D.CULL_DISABLED
				_mat_stappen.render_priority = 3
			var stappen := MeshInstance3D.new()
			stappen.name = "Stappen"
			stappen.mesh = _vlak_stappen
			stappen.material_override = _mat_stappen
			stappen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			stappen.rotation.y = draai_naar(camera)
			stappen.position.y = 0.004
			wortel.add_child(stappen)
	else:
		grond.mesh = _vlak
		grond.rotation.y = draai_naar(camera)
		wortel.add_child(grond)
	if bezet and bool(SOORTEN[soort][2]):
		var boven := Sprite3D.new()
		boven.name = "Boven"
		boven.texture = Pack.tex(String(SOORTEN[soort][0]))
		boven.pixel_size = BOVEN_MAAT / float(maxi(1, boven.texture.get_width()))
		boven.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		boven.shaded = false
		boven.no_depth_test = true
		boven.render_priority = 6
		boven.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		boven.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		boven.position = Vector3(0.0, BOVEN_HOOGTE, 0.0)
		wortel.add_child(boven)
	if kosten > 0:
		var getal := Label3D.new()
		getal.name = "Kosten"
		getal.text = str(kosten)
		getal.font_size = KOST_GROOTTE
		getal.pixel_size = 0.006
		getal.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		getal.no_depth_test = true
		getal.render_priority = 5
		getal.modulate = Color("#F4F9FF")
		getal.outline_size = 10
		getal.outline_modulate = Color(0.03, 0.09, 0.2, 0.95)
		var f := UiAssets.font("cijfers")
		if f != null:
			getal.font = f
		getal.position = Vector3(0.0, 0.16, 0.0)
		wortel.add_child(getal)
	return wortel

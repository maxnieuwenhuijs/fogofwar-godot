extends MeshInstance3D

## Het zwaaispoor (6 oktober 2026, Max: "voeg ook een slashing trail toe aan de
## melee wapens, een lijntje om het effect wat kracht bij te geven, moet ook
## allemaal tunebaar zijn"): een lijntje langs de baan van de punt van een
## bajonet, sabel, lans of bijl. Zolang het opneemt komt er elk frame een punt
## bij (uit `bron`); elk stukje vervaagt en wordt dunner in `slash_duur`. Daarna
## loopt het lijntje leeg en ruimt het zichzelf op. Het lijntje kijkt altijd naar
## de camera, dus een stoot (de punt beweegt langs het wapen) is net zo goed te
## zien als een zwaai. Het hangt onder het bord, dus het blijft liggen waar de
## zwaai was, ook als de pion doorloopt.
##
## Knoppen in effects_tuning.json (slash_*, label en bereik in vfx_catalogus.gd);
## de textuur uit assets/textures/trails/ (slash*, van de VFX-studio: links bij het
## wapen, naar rechts het oudste stuk, de randen boven en onder), anders een
## verloop uit de hoekkleuren. Additief: zwart telt niet mee. Puur beeld, geen
## rng. Zonder class_name: `preload("res://scripts/vfx/zwaaispoor.gd")`.

const VFX := preload("res://scripts/vfx/vfx.gd")
const STAP := 3   # tussenpunten per frame (een snelle zwaai blijft rond)

var bron: Callable              # () -> [punt] in de ruimte van de ouder, [] = even niets
var opnemen: float = 0.3        # zo lang komen er punten bij (s)
var kleur: Color = Color(0.92, 0.96, 1.0)
var _punten: Array = []         # {p, t}, het oudste vooraan
var _tijd := 0.0
var _duur := 0.22
var _sterkte := 1.0
var _dikte := 0.08
var _imesh: ImmediateMesh
var _mat: StandardMaterial3D
var _geleverd := false
static var _zacht_tex: Texture2D = null


## Zonder geleverde textuur: een zacht dwarsprofiel (fel in het midden, de randen
## lopen weg); het vervagen naar achteren doen de hoekkleuren.
static func _zacht() -> Texture2D:
	if _zacht_tex == null:
		var img := Image.create(4, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			var v := absf((float(y) + 0.5) / 32.0 - 0.5) * 2.0   # 0 midden, 1 rand
			for x in 4:
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, pow(1.0 - v, 1.5)))
		_zacht_tex = ImageTexture.create_from_image(img)
	return _zacht_tex


func _ready() -> void:
	_duur = maxf(PawnView.fx("slash_duur", 0.22), 0.02)
	_sterkte = PawnView.fx("slash_spoor", 1.0)
	_dikte = maxf(PawnView.fx("slash_dikte", 0.08), 0.001)
	var gloed: float = PawnView.fx("slash_gloed", 1.0)
	kleur = Color(kleur.r * gloed, kleur.g * gloed, kleur.b * gloed)
	_imesh = ImmediateMesh.new()
	mesh = _imesh
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.vertex_color_use_as_albedo = true
	var tex := VFX.geleverde_textuur("trails", "slash", 256, false)
	_geleverd = tex != null
	_mat.albedo_texture = tex if _geleverd else _zacht()
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 4.0


func _process(delta: float) -> void:
	_tijd += delta
	if _tijd <= opnemen and bron.is_valid():
		var p: Array = bron.call()
		if p.size() == 1:
			_punten.append({"p": p[0], "t": _tijd})
	while not _punten.is_empty() and _tijd - float(_punten[0].t) > _duur:
		_punten.pop_front()
	_teken()
	if _tijd > opnemen and _punten.is_empty():
		queue_free()


## Hoeveel punten het lijntje nu heeft (voor de checks).
func stukjes() -> int:
	return _punten.size()


## De doos om de punten van nu, in de ruimte van de ouder (voor de checks).
func omvang() -> AABB:
	if _punten.is_empty():
		return AABB()
	var ab := AABB(_punten[0].p, Vector3.ZERO)
	for s in _punten:
		ab = ab.expand(s.p)
	return ab


func _teken() -> void:
	_imesh.clear_surfaces()
	if _punten.size() < 2:
		return
	# de baan, rond gemaakt (Catmull-Rom), met de tijd per punt
	var baan: Array = []
	for i in _punten.size() - 1:
		var s0: Dictionary = _punten[maxi(i - 1, 0)]
		var s1: Dictionary = _punten[i]
		var s2: Dictionary = _punten[i + 1]
		var s3: Dictionary = _punten[mini(i + 2, _punten.size() - 1)]
		for k in STAP:
			var u := float(k) / float(STAP)
			baan.append([_cr(s0.p, s1.p, s2.p, s3.p, u), lerpf(float(s1.t), float(s2.t), u)])
	var laatste: Dictionary = _punten[_punten.size() - 1]
	baan.append([laatste.p, float(laatste.t)])
	# naar de camera gekeerd: dwars op de baan en op de kijkrichting
	var kijk := Vector3.UP
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		kijk = global_transform.basis.inverse() * cam.global_transform.basis.z
	var met_tex := _geleverd
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in baan.size():
		var p: Vector3 = baan[i][0]
		var raak: Vector3 = (baan[mini(i + 1, baan.size() - 1)][0] as Vector3) - (baan[maxi(i - 1, 0)][0] as Vector3)
		var dwars := raak.cross(kijk)
		dwars = dwars.normalized() if dwars.length() > 0.000001 else Vector3.ZERO
		var f: float = clampf((_tijd - float(baan[i][1])) / _duur, 0.0, 1.0)   # 0 nieuw, 1 vervaagd
		var w: float = _dikte * 0.5 * sqrt(1.0 - f)   # spits naar de staart
		var alfa: float = _sterkte * ((1.0 - smoothstep(0.8, 1.0, f)) if met_tex else pow(1.0 - f, 1.4))
		_imesh.surface_set_color(Color(kleur, alfa))
		_imesh.surface_set_uv(Vector2(f, 1.0))
		_imesh.surface_add_vertex(p - dwars * w)
		_imesh.surface_set_color(Color(kleur, alfa))
		_imesh.surface_set_uv(Vector2(f, 0.0))
		_imesh.surface_add_vertex(p + dwars * w)
	_imesh.surface_end()


## Catmull-Rom tussen p1 en p2 (een snelle zwaai van een paar frames wordt een boog).
static func _cr(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, u: float) -> Vector3:
	var u2 := u * u
	var u3 := u2 * u
	return 0.5 * ((2.0 * p1) + (p2 - p0) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u2
		+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * u3)

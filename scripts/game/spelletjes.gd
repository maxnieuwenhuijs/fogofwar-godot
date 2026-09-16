class_name Spelletjes
extends RefCounted

## Vijf mini-games in het diorama (12 september, Max: "bedenk 5 spelletjes
## ... heel low key, simpel te bedienen met een tap of een klik inhouden").
##
## Twee bedieningen, allebei met een vinger:
##   - WERPEN, in drie tikken (16 september, Max: "je klikt, je ziet de
##     richting-pijl die heen en weer gaat; dan klik je, dan staat de richting
##     vast, dan gaat een pijl of krachtmeter snel omhoog en naar beneden; dan
##     klik je weer, dan heb je je kracht"). Tik 1 op de spel-prop: een pijl
##     op de grond zwaait heen en weer (de richting). Tik 2, waar dan ook: de
##     richting staat vast en de pijl wordt de krachtmeter, hij groeit en
##     krimpt snel. Tik 3: de kracht staat vast, de worp gaat. Kegelen (de
##     bal), keilen (de stenen), het kanon (de loop komt omhoog, de pijl is
##     de dracht); vissen heeft geen richting en begint meteen met de meter
##     (twee tikken). Afbreken: een tik op een ANDERE prop, of RICHT_TIMEOUT
##     seconden niets doen. Daarvoor (12 september) was het vasthouden en
##     loslaten; die bediening bestaat alleen nog voor de cadans.
##   - OP DE MAAT: tikken op het juiste moment. Vissen (tik als de dobber
##     duikt), de tamboer-cadans (vasthouden op de trom start de ronde, dan
##     op de maat tikken; loslaten binnen HOLD_DREMPEL is een gewone tik).
##
## Puur visueel: alles hangt als tween aan zijn prop-node (een herbouw van
## het diorama ruimt het op), de willekeur komt uit de RNG van de omgeving
## (nooit de globale: -- uispel), en er wordt nooit iets aan de spelstaat
## gedaan, dus online kan het niet uit de pas lopen.
##
## Omgeving roept: druk(p, pos) vanuit klik(), laat_los(pos), beweeg(pos),
## process(delta), reset() bij een herbouw en koppel_doelen() erna. De
## bouwers (bouw_kegelspel, bouw_stenen_*, bouw_kruitvaten, bouw_hengel_*,
## maak_kanon, maak_cadans) zetten de spel-props neer en registreren ze bij
## de omgeving met `spel` = de soort.

const HOLD_DREMPEL := 0.22     # seconden vasthouden voor de cadans begint
const ANNULEER_PX := 90.0      # zo ver wegschuiven met je vinger = de cadans afbreken
const RICHT_TIMEOUT := 12.0    # seconden zonder tik: het richten stopt vanzelf
const KEGEL_AFSTAND := 1.5     # van de kogel tot de voorste fles
const VANGSTEN_MAX := 5        # zoveel vangsten blijven er op de steiger liggen

var o: Omgeving
var _kandidaat: Dictionary = {}    # ingedrukte spel-prop die op de hold-drempel wacht
var _druk_tijd := 0.0
var _druk_pos := Vector2.ZERO
var _actief: Dictionary = {}       # het richten: {p, t0, t_fase, fase, hoek, kracht, pijl, schacht, kop, vast}
                                   # fase: "richting" (pijl zwaait) of "kracht" (meter op en neer)


func _init(omgeving: Omgeving) -> void:
	o = omgeving


func reset() -> void:
	_kandidaat = {}
	_actief = {}


## Alleen voor de check: richting en kracht vastzetten (hoek in rad, kracht
## 0..1); de eerstvolgende tik (Omgeving.klik) werpt dan met die waarden.
func zet_richt(hoek: float, kracht: float) -> void:
	if _actief.is_empty():
		return
	_actief.vast = true
	_actief.fase = "kracht"
	_actief.hoek = hoek
	_actief.kracht = kracht
	_richt_process()


## Waar het richten nu staat (check en Omgeving): "" (niets), "richting" of "kracht".
func richt_fase() -> String:
	return String(_actief.get("fase", "")) if not _actief.is_empty() else ""


## Een tik ergens anders dan op een prop terwijl er gericht wordt (Omgeving.klik):
## tik 2 of 3 van het werpen. Waar = verwerkt.
func tik_elders() -> bool:
	if _actief.is_empty():
		return false
	_volgende_tik()
	return true


## Is dit de prop waar het richten op loopt?
func is_richt_prop(p: Dictionary) -> bool:
	return not _actief.is_empty() and (_actief.p as Dictionary).node == p.node


## Een tik op een ANDERE prop dan die waar het richten op loopt: afbreken.
func breek_af() -> void:
	_kandidaat = {}
	if not _actief.is_empty():
		_stop_richten()


func richt_bezig() -> bool:
	return not _actief.is_empty()


# ---------------------------------------------------------------- bediening

## Vinger op een spel-prop (na de tik van Omgeving.klik). Loopt er al een
## richten op DEZE prop, dan is dit tik 2 of 3 (op een andere prop heeft
## Omgeving.klik al afgebroken). Wacht er een spel op deze prop op een tik
## (dobber, cadans), dan is dit die tik. Anders begint het richten meteen
## (tik 1); alleen de cadans wacht op de hold-drempel.
func druk(p: Dictionary, pos: Vector2) -> void:
	if not _actief.is_empty():
		_volgende_tik()
		return
	var staat: Dictionary = p.get("spel_staat", {})
	if not staat.is_empty() and bool(staat.get("wacht_op_tik", false)):
		_spel_tik(p)
		return
	if bool(p.bezig):
		return
	_druk_tijd = o._tijd
	_druk_pos = pos
	if String(p.get("spel", "")) == "cadans":
		_kandidaat = p
		return
	_kandidaat = {}
	_start_richten(p)


## Tik 2 of 3 van het werpen: richting vast, dan kracht vast en werpen.
func _volgende_tik() -> void:
	var a: Dictionary = _actief
	if String(a.fase) == "richting" and not bool(a.vast):
		a.fase = "kracht"
		a.t_fase = o._tijd
		a.kracht = 0.0
		_toon(["prop_tik", "ui_click"], 1.15)
		_richt_process()
		return
	_werp()


## Vinger los: alleen de cadans doet hier nog iets (kort = de gewone tik).
## Waar = het was een spel-prop.
func laat_los(_pos: Vector2) -> bool:
	if not _actief.is_empty():
		return true
	if not _kandidaat.is_empty():
		var p: Dictionary = _kandidaat
		_kandidaat = {}
		if is_instance_valid(p.node) and not bool(p.bezig) and p.has("reacties"):
			p.bezig = true
			o._speel_willekeurig(p)
		return true
	return false


## Vinger beweegt: alleen de cadans-kandidaat breekt af bij wegschuiven (het
## richten in tikken niet: met een muis beweeg je nu eenmaal tussen de tikken).
func beweeg(pos: Vector2) -> void:
	if _kandidaat.is_empty():
		return
	if pos.distance_to(_druk_pos) > ANNULEER_PX:
		_kandidaat = {}


func process(delta: float) -> void:
	if not _kandidaat.is_empty() and o._tijd - _druk_tijd >= HOLD_DREMPEL:
		var p: Dictionary = _kandidaat
		_kandidaat = {}
		if is_instance_valid(p.node) and not bool(p.bezig):
			_start_richten(p)
	if not _actief.is_empty():
		if o._tijd - float(_actief.t_fase) > RICHT_TIMEOUT:
			_stop_richten()
		else:
			_richt_process()
	for p in o._props:
		if p.has("spel_staat") and is_instance_valid(p.node):
			_staat_process(p, delta)


# ---------------------------------------------------------------- richten (het werp-sjabloon)

func _start_richten(p: Dictionary) -> void:
	var soort := String(p.get("spel", ""))
	if soort == "cadans":
		_cadans_start(p)
		return
	var conf: Dictionary = p.get("spel_conf", {})
	var ouder: Node3D = p.get("pijl_ouder", p.node)
	if not is_instance_valid(ouder):
		return
	var pijl := Node3D.new()
	pijl.name = "Pijl"
	pijl.position = conf.get("pijl_pos", Vector3(0.0, 0.03, 0.0))
	pijl.rotation.y = float(conf.get("pijl_draai", 0.0))
	ouder.add_child(pijl)
	var goud := Color(0.8, 0.78, 0.7)
	var schacht := o._mesh(o._box(Vector3(0.05, 0.012, 1.0)), goud, pijl, Vector3(0.0, 0.0, -0.5))
	var kop := o._mesh(o._kegel(0.09, 0.16), goud, pijl, Vector3(0.0, 0.0, -1.08))
	kop.rotation.x = deg_to_rad(-90.0)
	for m in [schacht, kop]:
		var mi := m as MeshInstance3D
		var mat := mi.material_override as StandardMaterial3D
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# zonder zwaai (vissen) is er geen richting te kiezen: meteen de
	# krachtmeter (twee tikken)
	var fase := "kracht" if float(conf.get("zwaai", 35.0)) <= 0.0 else "richting"
	_actief = {"p": p, "t0": o._tijd, "t_fase": o._tijd, "fase": fase, "hoek": 0.0, "kracht": 0.0,
			"pijl": pijl, "schacht": schacht, "kop": kop, "vast": false}
	if soort == "kanon":
		_kanon_richt_start(p)
	_richt_process()


func _richt_process() -> void:
	var a: Dictionary = _actief
	var p: Dictionary = a.p
	if not is_instance_valid(p.node) or not is_instance_valid(a.pijl):
		_actief = {}
		return
	var conf: Dictionary = p.get("spel_conf", {})
	var t: float = o._tijd - float(a.t0)
	var tf: float = o._tijd - float(a.t_fase)
	if not bool(a.vast):
		if String(a.fase) == "richting":
			a.hoek = deg_to_rad(float(conf.get("zwaai", 35.0))) * sin(tf * float(conf.get("zwaai_snelheid", 2.4)))
			a.kracht = 0.45   # de pijl is tijdens het richten een vaste, halve lengte
		else:
			# de krachtmeter: snel op en neer (meter_tijd seconden van 0 naar 1)
			var u: float = tf / float(conf.get("meter_tijd", 0.45))
			a.kracht = 1.0 - absf(fmod(u, 2.0) - 1.0)
	var kracht: float = float(a.kracht)
	var pijl: Node3D = a.pijl
	# Min: een draai om +Y zet de pijl (lokaal -Z) naar -X, terwijl de worp
	# (sin(hoek), 0, -cos(hoek)) naar +X gaat; met plus wees de pijl naar
	# links en rolde de bal naar rechts (Max, 12 september).
	pijl.rotation.y = float(conf.get("pijl_draai", 0.0)) - float(a.hoek)
	var lengte: float = float(conf.get("pijl_min", 0.4)) + kracht * float(conf.get("pijl_max", 1.8))
	var schacht: MeshInstance3D = a.schacht
	var kop: MeshInstance3D = a.kop
	schacht.scale = Vector3(1.0, 1.0, lengte)
	schacht.position.z = -lengte * 0.5
	kop.position.z = -lengte - 0.08
	var kleur := Color(0.8, 0.78, 0.7)
	if String(a.fase) == "kracht":
		kleur = kleur.lerp(Color(1.0, 0.85, 0.3), kracht)
		if kracht >= 0.97:
			kleur = kleur.lerp(Color(1.0, 0.5, 0.2), 0.5 + 0.5 * sin(t * 12.0))
	(schacht.material_override as StandardMaterial3D).albedo_color = kleur
	(kop.material_override as StandardMaterial3D).albedo_color = kleur
	if String(p.get("spel", "")) == "kanon":
		_kanon_richt(p, float(a.hoek), kracht)


func _stop_richten() -> void:
	if _actief.is_empty():
		return
	var a: Dictionary = _actief
	if is_instance_valid(a.pijl):
		(a.pijl as Node3D).queue_free()
	var p: Dictionary = a.p
	_actief = {}
	if String(p.get("spel", "")) == "kanon" and is_instance_valid(p.node):
		_kanon_richt_stop(p)


func _werp() -> void:
	var a: Dictionary = _actief
	var p: Dictionary = a.p
	var hoek: float = float(a.hoek)
	var kracht: float = float(a.kracht)
	_stop_richten()
	if not is_instance_valid(p.node) or bool(p.bezig):
		return
	p.bezig = true
	match String(p.get("spel", "")):
		"kegelen":
			_kegelen_werp(p, hoek, kracht)
		"keilen":
			_keilen_werp(p, hoek, kracht)
		"kanon":
			_kanon_schiet(p, hoek, kracht)
		"vissen":
			_vissen_werp(p, kracht)
		_:
			p.bezig = false


## Tik op een prop waar een spel op tikken wacht.
func _spel_tik(p: Dictionary) -> void:
	match String(p.get("spel", "")):
		"vissen":
			_vissen_tik(p)
		"cadans":
			_cadans_tik(p)


func _staat_process(p: Dictionary, delta: float) -> void:
	match String(p.get("spel", "")):
		"vissen":
			_vissen_process(p, delta)
		"cadans":
			_cadans_process(p, delta)


## Een geluid met een toonhoogte (als de categorie er ligt), anders de terugval.
func _toon(categorieen: Array, toon: float) -> void:
	for cat in categorieen:
		if Audio.variant_aantal(String(cat)) > 0:
			Audio.play(String(cat), 0.0, -1, toon)
			return


func _tekst(ouder: Node3D, pos: Vector3, tekst: String, kleur: Color = Color(1.0, 0.95, 0.8)) -> void:
	if is_instance_valid(ouder):
		o._fx_tekst(ouder, pos, tekst, kleur)


# ---------------------------------------------------------------- 1. kegelen

## Tien lege flessen uit de kantine in de driehoek van het bowlen (Max:
## "iets wat bij de setting hoort", "10 stuks", "wat kleiner en geen
## ondervlak"), een kanonskogel op een plankje; de baan loopt langs de
## lokale -Z van `pos`, zonder vlak eronder. De kogel is de klikbare prop.
func bouw_kegelspel(pos: Vector3, draai: float) -> void:
	var baan := Node3D.new()
	baan.name = "Kegelbaan"
	baan.position = pos
	baan.rotation.y = draai
	o._props_root.add_child(baan)
	o._mesh(o._box(Vector3(0.26, 0.02, 0.22)), Color(0.5, 0.4, 0.27), baan, Vector3(0.0, 0.01, 0.0))
	var kegels: Array = []
	var s := 0.19
	for rij in 4:
		for i in rij + 1:
			var kx := (float(i) - float(rij) * 0.5) * s
			var kz := -KEGEL_AFSTAND - float(rij) * s * 0.866
			var k := Node3D.new()
			k.name = "Kegel%d" % kegels.size()
			k.position = Vector3(kx, 0.0, kz)
			baan.add_child(k)
			# een lege wijnfles: donkergroen glas, een hals en een kurk
			var glas := Color(0.16, 0.36, 0.2)
			var lijf := o._mesh(o._cilinder(0.03, 0.16), glas, k, Vector3(0.0, 0.08, 0.0))
			var schouder := o._mesh(o._kegel(0.03, 0.045), glas, k, Vector3(0.0, 0.1825, 0.0))
			var hals := o._mesh(o._cilinder(0.012, 0.07), glas, k, Vector3(0.0, 0.23, 0.0))
			for g in [lijf, schouder, hals]:
				var gm := (g as MeshInstance3D).material_override as StandardMaterial3D
				gm.roughness = 0.25
				gm.metallic_specular = 0.7
			o._mesh(o._cilinder(0.01, 0.02), Color(0.76, 0.62, 0.42), k, Vector3(0.0, 0.275, 0.0))
			kegels.append({"node": k, "pos": Vector3(kx, 0.0, kz)})
	var bal := Node3D.new()
	bal.name = "Kegelbal"
	bal.position = Vector3(0.0, 0.02 + 0.075, 0.0)
	baan.add_child(bal)
	var kogel := o._mesh(o._bol(0.075), Color(0.16, 0.16, 0.17), bal, Vector3.ZERO)
	(kogel.material_override as StandardMaterial3D).metallic = 0.6
	(kogel.material_override as StandardMaterial3D).roughness = 0.45
	o._registreer(bal, 0.2, [_reageer_bal_hop], {"spel": "kegelen", "baan": baan, "kegels": kegels,
			"bal_thuis": bal.position, "tik": ["prop_kogel", "impact_armor"], "pijl_ouder": baan,
			"spel_conf": {"zwaai": 26.0, "zwaai_snelheid": 2.4, "laadtijd": 1.0, "pijl_min": 0.3, "pijl_max": 1.5,
				"pijl_pos": Vector3(0.0, 0.03, 0.0)},
			"spel_score": 0})


func _reageer_bal_hop(p: Dictionary) -> void:
	var bal: Node3D = p.node
	o._geluid(["prop_kogel", "impact_armor"])
	var tw := bal.create_tween()
	tw.tween_property(bal, "position:y", bal.position.y + 0.14, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(bal, "position:y", float((p.bal_thuis as Vector3).y), 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	o._klaar(p, tw)


func _kegelen_werp(p: Dictionary, hoek: float, kracht: float) -> void:
	var bal: Node3D = p.node
	var baan: Node3D = p.baan
	var kegels: Array = p.kegels
	var d := Vector3(sin(hoek), 0.0, -cos(hoek))
	var afstand: float = 0.9 + 1.7 * kracht
	var start: Vector3 = p.bal_thuis
	var eind: Vector3 = start + d * afstand
	var duur: float = 0.45 + afstand / 2.8
	o._geluid(["prop_kegel_rol", "prop_ton"])
	var draai_as := Vector3.UP.cross(d).normalized()
	var tw := bal.create_tween()
	tw.tween_method(func(t: float) -> void:
		var voortgang := 1.0 - (1.0 - t) * (1.0 - t)
		bal.position = start + d * afstand * voortgang
		bal.basis = Basis(draai_as, afstand * voortgang / 0.075), 0.0, 1.0, duur)
	# welke kegels vallen, en wanneer: directe treffers langs de baan, dan de ketting
	var geraakt: Dictionary = {}
	var vallen: Array = []
	var kandidaten: Array = []
	for i in kegels.size():
		var rel: Vector3 = (kegels[i].pos as Vector3) - start
		rel.y = 0.0
		var langs := rel.dot(d)
		var dwars := (rel - d * langs).length()
		if langs > 0.0 and langs < afstand + 0.05 and dwars < 0.12:
			kandidaten.append([langs, i])
	kandidaten.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for kand in kandidaten:
		var langs: float = float(kand[0])
		var t_raak: float = duur * (1.0 - sqrt(maxf(0.0, 1.0 - langs / afstand)))
		_kegel_valt(p, int(kand[1]), t_raak, d, geraakt, vallen)
	for v in vallen:
		var k: Node3D = (kegels[int(v.i)] as Dictionary).node
		var f: Vector3 = v.richting
		var kt := k.create_tween()
		kt.tween_interval(float(v.tijd))
		kt.tween_callback(func() -> void:
			k.rotation.y = atan2(f.x, f.z)
			_toon(["prop_kegel", "impact_wood"], o._rng.randf_range(0.9, 1.15)))
		kt.tween_property(k, "rotation:x", 1.45, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		kt.tween_property(k, "rotation:x", 1.38, 0.08)
		kt.tween_property(k, "rotation:x", 1.45, 0.08)
		# een fles rolt nog een stukje door
		kt.tween_property(k, "rotation:y", k.rotation.y + o._rng.randf_range(-0.6, 0.6), 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var score := vallen.size()
	var midden := Vector3(0.0, 0.35, -KEGEL_AFSTAND - 0.3)
	tw.tween_interval(0.35)
	tw.tween_callback(func() -> void:
		p.spel_score = score
		if score >= 10:
			_tekst(baan, midden, "Strike!", Color(1.0, 0.85, 0.3))
			_toon(["prop_combo"], 1.0)
		elif score == 0:
			_tekst(baan, midden, "Poedel!", Color(0.85, 0.85, 0.9))
		else:
			_tekst(baan, midden, "%d flessen!" % score))
	tw.tween_interval(2.0)
	# terugzetten: de kegels overeind, de bal weer op zijn plankje
	tw.tween_callback(func() -> void:
		for v in vallen:
			var k2: Node3D = (kegels[int(v.i)] as Dictionary).node
			var rt := k2.create_tween()
			rt.tween_interval(o._rng.randf_range(0.0, 0.3))
			rt.tween_property(k2, "rotation", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			rt.tween_callback(func() -> void: _toon(["prop_tik"], 1.2)))
	tw.tween_property(bal, "scale", Vector3(0.01, 0.01, 0.01), 0.15)
	tw.tween_callback(func() -> void:
		bal.position = start
		bal.basis = Basis.IDENTITY)
	tw.tween_property(bal, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: p.tik_basis = Vector3.ONE)
	o._klaar(p, tw)


## Kegel i valt op `tijd` in `richting`, en sleept met wat kans zijn buren mee.
func _kegel_valt(p: Dictionary, i: int, tijd: float, richting: Vector3, geraakt: Dictionary, vallen: Array) -> void:
	if geraakt.has(i):
		return
	geraakt[i] = true
	vallen.append({"i": i, "tijd": tijd, "richting": richting})
	var kegels: Array = p.kegels
	var hier: Vector3 = (kegels[i] as Dictionary).pos
	for j in kegels.size():
		if geraakt.has(j):
			continue
		var naar: Vector3 = (kegels[j] as Dictionary).pos - hier
		var afstand := naar.length()
		if afstand > 0.29 or afstand < 0.001:
			continue
		var n := naar / afstand
		var mee := n.dot(richting)
		var kans := 0.72 if mee > 0.3 else (0.3 if mee > -0.3 else 0.0)
		if o._rng.randf() < kans:
			_kegel_valt(p, j, tijd + 0.07 + o._rng.randf_range(0.0, 0.06), n.lerp(richting, 0.5).normalized(), geraakt, vallen)


# ---------------------------------------------------------------- 2. keilen

## Een stapeltje platte stenen aan de rand van de plas (kind van de plas-node,
## `water` in plas-ruimte: ellips rx x rz) of op de kade (kind van Props,
## `water` = de rivier vanaf z_rand). De lokale -Z van de stapel wijst het water in.
func bouw_stenen(ouder: Node3D, lokaal: Vector3, draai: float, water: Dictionary) -> void:
	var stapel := Node3D.new()
	stapel.name = "Stenen"
	stapel.position = lokaal
	stapel.rotation.y = draai
	ouder.add_child(stapel)
	var grijs := Color(0.5, 0.52, 0.5)
	var plekken: Array = [Vector3(0.0, 0.007, 0.0), Vector3(0.03, 0.021, -0.02), Vector3(-0.02, 0.035, 0.015), Vector3(0.01, 0.049, -0.01)]
	for i in plekken.size():
		var st := o._mesh(o._cilinder(0.05, 0.014), grijs.lerp(Color(0.62, 0.6, 0.56), float(i) * 0.25), stapel, plekken[i])
		st.rotation.y = float(i) * 0.7
	var bevroren: bool = bool(water.get("bevroren", false))
	o._registreer(stapel, 0.06, [_reageer_stenen_tik], {"spel": "keilen", "water": water, "tik": ["prop_steen", "impact_wood"],
			"spel_conf": {"zwaai": 28.0, "zwaai_snelheid": 2.2, "laadtijd": 0.9, "pijl_min": 0.3,
				"pijl_max": 1.4 if String(water.get("soort", "plas")) == "rivier" else 0.9, "pijl_pos": Vector3(0.0, 0.03, 0.0)},
			"spel_score": 0, "bevroren": bevroren})


func _reageer_stenen_tik(p: Dictionary) -> void:
	var n: Node3D = p.node
	var boven: Node3D = n.get_child(n.get_child_count() - 1)
	var tw := n.create_tween()
	tw.tween_property(boven, "position:y", boven.position.y + 0.06, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(boven, "position:y", boven.position.y, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	o._klaar(p, tw)


func _in_water(water: Dictionary, punt: Vector3) -> bool:
	if String(water.get("soort", "plas")) == "rivier":
		return punt.z <= float(water.get("z_rand", -1.9))
	var rx: float = float(water.get("rx", 0.6))
	var rz: float = float(water.get("rz", 0.43))
	return (punt.x * punt.x) / (rx * rx) + (punt.z * punt.z) / (rz * rz) <= 1.0


func _keilen_werp(p: Dictionary, hoek: float, kracht: float) -> void:
	var stapel: Node3D = p.node
	var water: Dictionary = p.water
	var ouder: Node3D = stapel.get_parent()
	var rivier: bool = String(water.get("soort", "plas")) == "rivier"
	var ring_ouder: Node3D = water.get("ring_ouder", ouder)
	# richting in de ruimte van de ouder (de plas of Props)
	var d: Vector3 = stapel.transform.basis * Vector3(sin(hoek), 0.0, -cos(hoek))
	d.y = 0.0
	d = d.normalized()
	var start: Vector3 = stapel.position + Vector3(0.0, 0.06, 0.0)
	var steen := o._mesh(o._cilinder(0.05, 0.014), Color(0.55, 0.56, 0.54), ouder, start)
	var vlucht := steen.create_tween()
	if bool(p.get("bevroren", false)):
		# op het ijs glijdt en tolt de steen; van de plas af belandt hij in de sneeuw
		var glij: float = 0.5 + 1.3 * kracht
		var eind: Vector3 = start + d * glij
		var op_ijs := true
		var stap := 0.0
		while stap < glij:
			stap += 0.05
			if not _in_water(water, start + d * stap):
				op_ijs = false
				eind = start + d * stap
				break
		eind.y = 0.03
		_toon(["prop_ijs", "prop_steen"], 1.0)
		vlucht.tween_method(o._boog.bind(steen, start, start + d * 0.25 + Vector3(0.0, 0.03 - start.y, 0.0), 0.12), 0.0, 1.0, 0.22)
		vlucht.tween_property(steen, "position", eind, 0.2 + glij * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		vlucht.parallel().tween_property(steen, "rotation:y", 9.0 * kracht + 2.0, 0.2 + glij * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		vlucht.tween_callback(func() -> void:
			p.spel_score = 1 if op_ijs else 0
			if op_ijs:
				_tekst(ouder, eind + Vector3(0.0, 0.2, 0.0), "Glijdt!", Color(0.85, 0.92, 1.0))
			else:
				_toon(["prop_sneeuw", "prop_steen"], 1.0)
				_tekst(ouder, eind + Vector3(0.0, 0.2, 0.0), "Van het ijs af!", Color(0.85, 0.85, 0.9)))
		vlucht.tween_interval(1.8)
		vlucht.tween_property(steen, "scale", Vector3(0.01, 0.01, 0.01), 0.2)
		vlucht.tween_callback(steen.queue_free)
		o._klaar(p, vlucht)
		return
	# ketsen: de eerste worp, dan steeds kortere hupjes; buiten het water is het klaar
	var l0: float = (0.25 + 0.9 * kracht) if rivier else (0.14 + 0.42 * kracht)
	var n_max: int = clampi(1 + roundi(kracht * 4.0) + o._rng.randi_range(-1, 1), 1, 7)
	var landingen: Array = []
	var pos: Vector3 = start
	var doel: Vector3 = start + d * l0 * 1.4
	var in_water := false
	var k := 0
	while k <= n_max:
		var vlak := Vector3(doel.x, 0.02, doel.z)
		in_water = _in_water(water, vlak)
		landingen.append({"van": pos, "naar": vlak, "water": in_water})
		if not in_water:
			break
		pos = vlak
		doel = pos + d * l0 * pow(0.78, float(k + 1))
		k += 1
	var ketsen := 0
	for i in landingen.size():
		var l: Dictionary = landingen[i]
		var laatste: bool = i == landingen.size() - 1
		var van: Vector3 = l.van
		var naar: Vector3 = l.naar
		var piek: float = (0.22 if i == 0 else 0.1) * (0.6 + kracht * 0.8) * pow(0.8, float(i))
		vlucht.tween_method(o._boog.bind(steen, van, naar, piek), 0.0, 1.0, 0.22 if i == 0 else 0.16).set_trans(Tween.TRANS_SINE)
		if bool(l.water):
			if not laatste:
				ketsen += 1
			var nr := i
			var toon := 1.0 + 0.09 * float(i)
			vlucht.tween_callback(func() -> void:
				o._rimpel(ring_ouder, ring_ouder.to_local(ouder.to_global(naar)))
				_toon(["prop_plons", "small_blood_splash"], toon if not laatste else 0.8)
				if laatste:
					o._fx_spetters(ouder, naar, 5, Color(0.75, 0.85, 0.95))
				_keilen_kikker(water, naar, nr))
		else:
			vlucht.tween_callback(func() -> void:
				_toon(["prop_steen", "impact_wood"], 1.0)
				o._fx_wolk(ouder, naar, Color(0.55, 0.5, 0.4), 0.4))
	var eind_pos: Vector3 = (landingen.back() as Dictionary).naar
	var op_land: bool = not bool((landingen.back() as Dictionary).water)
	vlucht.tween_callback(func() -> void:
		p.spel_score = ketsen
		if ketsen == 0:
			_tekst(ouder, eind_pos + Vector3(0.0, 0.2, 0.0), "Op de kant!" if op_land else "Plons.", Color(0.85, 0.85, 0.9))
		else:
			_tekst(ouder, eind_pos + Vector3(0.0, 0.2, 0.0), "%dx geketst!" % ketsen, Color(1.0, 0.9, 0.5) if ketsen >= 4 else Color(1.0, 0.95, 0.8))
		if ketsen >= 5:
			_toon(["prop_combo"], 1.0))
	if op_land:
		vlucht.tween_interval(1.6)
		vlucht.tween_property(steen, "scale", Vector3(0.01, 0.01, 0.01), 0.2)
	else:
		vlucht.tween_property(steen, "position:y", -0.05, 0.25)
	vlucht.tween_callback(steen.queue_free)
	o._klaar(p, vlucht)


## Komt de steen langs de kikker, dan duikt die weg (reactie 2 van de kikker).
func _keilen_kikker(water: Dictionary, waar: Vector3, nr: int) -> void:
	var kikker: Node3D = water.get("kikker", null)
	if kikker == null or not is_instance_valid(kikker) or nr > 3:
		return
	if kikker.position.distance_to(waar) > 0.3:
		return
	for q in o._props:
		if q.node == kikker and not bool(q.bezig):
			o.speel_reactie(q, 2)
			return


# ---------------------------------------------------------------- 3. het kanon en de kruitvaten

## Vier kruitvaten op een rij: het doel van het dichtstbijzijnde kanon.
func bouw_kruitvaten(pos: Vector3, draai: float) -> void:
	var root := Node3D.new()
	root.name = "Kruitvaten"
	root.position = pos
	root.rotation.y = draai
	o._props_root.add_child(root)
	var vaten: Array = []
	var glb := o._prop_glb("barrel", "")
	var ps: PackedScene = load(glb) if glb != "" else null
	var plekken: Array = [Vector3(-0.42, 0.0, 0.05), Vector3(-0.14, 0.0, -0.06), Vector3(0.14, 0.0, 0.06), Vector3(0.42, 0.0, -0.04)]
	for i in plekken.size():
		var vat := Node3D.new()
		vat.name = "Vat%d" % i
		vat.position = plekken[i]
		vat.rotation.y = float(i) * 0.9
		root.add_child(vat)
		var inst: Node3D = ps.instantiate() as Node3D if ps != null else null
		if inst != null:
			vat.add_child(inst)
			var s := 0.4
			inst.scale = Vector3(s, s, s)
			var doos: AABB = o._aabb_van(inst)
			inst.position.y = -doos.position.y * s
			for mi in inst.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		else:
			o._mesh(o._cilinder(0.12, 0.32), Color(0.45, 0.33, 0.2), vat, Vector3(0.0, 0.16, 0.0))
			o._mesh(o._cilinder(0.125, 0.03), Color(0.25, 0.24, 0.24), vat, Vector3(0.0, 0.08, 0.0))
			o._mesh(o._cilinder(0.125, 0.03), Color(0.25, 0.24, 0.24), vat, Vector3(0.0, 0.24, 0.0))
		vaten.append({"node": vat, "pos": plekken[i], "om": false})
	o._registreer(root, 0.35, [_reageer_vaten_wiebel], {"soort": "kruitvaten", "vaten": vaten, "tik": ["prop_ton", "impact_wood"]})


func _reageer_vaten_wiebel(p: Dictionary) -> void:
	var root: Node3D = p.node
	o._geluid(["prop_ton", "impact_wood"])
	var tw := root.create_tween()
	var amp := 0.12
	for i in 3:
		tw.tween_property(root, "rotation:z", amp, 0.09).set_trans(Tween.TRANS_SINE)
		tw.tween_property(root, "rotation:z", -amp, 0.09).set_trans(Tween.TRANS_SINE)
		amp *= 0.5
	tw.tween_property(root, "rotation:z", 0.0, 0.08)
	o._klaar(p, tw)


## Het kanon-placeholder wordt een spel: de loop komt omhoog bij vasthouden,
## de pijl toont de dracht; bij loslaten vliegt de kogel.
func maak_kanon(p: Dictionary, loop_node: Node3D) -> void:
	p["spel"] = "kanon"
	p["loop"] = loop_node
	p["pijl_ouder"] = p.node
	# ook een richting (16 september, Max: "geef het kanon ook een richting,
	# alleen dan gaat hij sneller en het aantal graden minder"): een smalle,
	# snelle zwaai om de lijn naar de vaten; de loop draait mee
	p["spel_conf"] = {"zwaai": 14.0, "zwaai_snelheid": 4.6, "laadtijd": 1.5, "pijl_min": 1.6, "pijl_max": 5.4,
		"pijl_pos": Vector3(0.0, 0.03, 0.0), "pijl_draai": PI}
	p["spel_score"] = 0


## Na de bouw: elk kanon kijkt naar de dichtstbijzijnde kruitvaten.
func koppel_doelen() -> void:
	for p in o._props:
		if String(p.get("spel", "")) != "kanon" or not is_instance_valid(p.node):
			continue
		var root: Node3D = p.node
		var beste: Dictionary = {}
		var beste_d := 1e9
		for q in o._props:
			if String(q.get("soort", "")) != "kruitvaten" or not is_instance_valid(q.node):
				continue
			var d := root.position.distance_to((q.node as Node3D).position)
			if d < beste_d:
				beste_d = d
				beste = q
		if beste.is_empty():
			continue
		p["doel"] = beste
		var naar: Vector3 = (beste.node as Node3D).position - root.position
		root.rotation.y = atan2(naar.x, naar.z)


func _kanon_dracht(p: Dictionary, kracht: float) -> float:
	var conf: Dictionary = p.get("spel_conf", {})
	return float(conf.get("pijl_min", 1.6)) + kracht * float(conf.get("pijl_max", 5.4))


func _kanon_richt_start(p: Dictionary) -> void:
	var root: Node3D = p.node
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.3
	tm.outer_radius = 0.38
	tm.rings = 24
	tm.ring_segments = 6
	ring.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.3)
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.name = "Doelring"
	ring.scale = Vector3(1.0, 0.15, 1.0)
	root.add_child(ring)
	p["doelring"] = ring


## De richting van het kanon in zijn eigen ruimte: de pijl (pijl_draai PI,
## min de hoek) wijst naar (-sin hoek, 0, cos hoek), de kogel gaat dezelfde kant op.
func _kanon_richting(hoek: float) -> Vector3:
	return Vector3(-sin(hoek), 0.0, cos(hoek))


func _kanon_richt(p: Dictionary, hoek: float, kracht: float) -> void:
	var loop_node: Node3D = p.get("loop", null)
	if loop_node != null and is_instance_valid(loop_node):
		loop_node.rotation.x = deg_to_rad(-10.0 - 35.0 * kracht)
		loop_node.rotation.y = -hoek
	var ring: Node3D = p.get("doelring", null)
	if ring != null and is_instance_valid(ring):
		ring.position = _kanon_richting(hoek) * _kanon_dracht(p, kracht) + Vector3(0.0, 0.03, 0.0)


func _kanon_richt_stop(p: Dictionary) -> void:
	var ring: Node3D = p.get("doelring", null)
	if ring != null and is_instance_valid(ring):
		ring.queue_free()
	p.erase("doelring")
	var loop_node: Node3D = p.get("loop", null)
	if loop_node != null and is_instance_valid(loop_node):
		var tw := loop_node.create_tween()
		tw.tween_property(loop_node, "rotation:x", deg_to_rad(-10.0), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(loop_node, "rotation:y", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _kanon_schiet(p: Dictionary, hoek: float, kracht: float) -> void:
	var root: Node3D = p.node
	var mond: Vector3 = p.mond
	var dracht := _kanon_dracht(p, kracht)
	var richting := _kanon_richting(hoek)
	# de wind van het potje (dezelfde die de vlaggen laat wapperen) duwt de
	# kogel een stukje opzij; de pijl toonde de dracht zonder wind
	var wind_lokaal: Vector3 = o.global_transform.basis.inverse() * PawnView.wind_richting
	var wind_kanon: Vector3 = root.basis.inverse() * wind_lokaal
	wind_kanon.y = 0.0
	var drift: Vector3 = wind_kanon * 0.35 * kracht
	var landing := richting * dracht + Vector3(0.0, 0.05, 0.0) + drift
	var zonder_wind := richting * dracht + Vector3(0.0, 0.05, 0.0)
	o._geluid(["prop_kanon", "cannon_heavy"])
	o._fx_knal(root, mond, 1.3)
	o._fx_wolk(root, mond + Vector3(0.0, 0.05, 0.15), Color(0.8, 0.78, 0.72), 1.6)
	var terug := root.create_tween()
	var x0 := root.position.x
	var z0 := root.position.z
	terug.tween_property(root, "position", root.position + Vector3(-sin(root.rotation.y) * -0.22, 0.0, -cos(root.rotation.y) * -0.22), 0.08)
	terug.tween_property(root, "position", Vector3(x0, root.position.y, z0), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var kogel := o._mesh(o._bol(0.07), Color(0.16, 0.16, 0.17), root, mond)
	(kogel.material_override as StandardMaterial3D).metallic = 0.6
	var duur := 0.65 + 0.55 * kracht
	var tw := kogel.create_tween()
	tw.tween_method(o._boog.bind(kogel, mond, landing, 0.4 + 1.3 * kracht), 0.0, 1.0, duur)
	tw.tween_callback(func() -> void:
		_kanon_inslag(p, root.to_global(landing), root.to_global(zonder_wind))
		kogel.queue_free())
	# de loop zakt weer
	var loop_node: Node3D = p.get("loop", null)
	if loop_node != null and is_instance_valid(loop_node):
		var lt := loop_node.create_tween()
		lt.tween_interval(0.6)
		lt.tween_property(loop_node, "rotation:x", deg_to_rad(-10.0), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		lt.parallel().tween_property(loop_node, "rotation:y", 0.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _kanon_inslag(p: Dictionary, waar_globaal: Vector3, zonder_wind_globaal: Vector3) -> void:
	var root: Node3D = p.node
	var doel: Dictionary = p.get("doel", {})
	var ontploft: Array = []
	if not doel.is_empty() and is_instance_valid(doel.node):
		var vroot: Node3D = doel.node
		var lokaal: Vector3 = vroot.to_local(waar_globaal)
		var lokaal_zonder: Vector3 = vroot.to_local(zonder_wind_globaal)
		var vaten: Array = doel.vaten
		var raak := -1
		var raak_zonder := false
		for i in vaten.size():
			var v: Dictionary = vaten[i]
			var vp: Vector3 = v.pos
			if not bool(v.om) and Vector2(vp.x - lokaal.x, vp.z - lokaal.z).length() < 0.5 and raak < 0:
				raak = i
			if Vector2(vp.x - lokaal_zonder.x, vp.z - lokaal_zonder.z).length() < 0.5:
				raak_zonder = true
		if raak >= 0:
			_vat_ontploft(doel, raak, 0.0, ontploft)
		var schot_root: Node3D = root
		var inslag := root.to_local(waar_globaal)
		if ontploft.is_empty():
			o._fx_wolk(schot_root, inslag, Color(0.55, 0.5, 0.4), 0.8)
			_toon(["prop_steen", "impact_wood"], 0.9)
			_tekst(schot_root, inslag + Vector3(0.0, 0.25, 0.0), "Windje!" if raak_zonder else "Mis!", Color(0.85, 0.85, 0.9))
		else:
			var n := ontploft.size()
			var tw := vroot.create_tween()
			tw.tween_interval(0.15 * float(n) + 0.3)
			tw.tween_callback(func() -> void:
				if n >= vaten.size():
					_tekst(vroot, Vector3(0.0, 0.5, 0.0), "Alles de lucht in!", Color(1.0, 0.85, 0.3))
					_toon(["prop_combo"], 1.0)
				else:
					_tekst(vroot, Vector3(0.0, 0.5, 0.0), "%d vaten!" % n))
			# na een poos staan de vaten er weer
			tw.tween_interval(2.6)
			tw.tween_callback(func() -> void:
				for v2 in vaten:
					if bool(v2.om) and is_instance_valid(v2.node):
						v2.om = false
						var vn: Node3D = v2.node
						vn.visible = true
						vn.scale = Vector3(0.01, 0.01, 0.01)
						var vt := vn.create_tween()
						vt.tween_property(vn, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				_toon(["prop_ton", "impact_wood"], 1.0))
	else:
		var inslag2 := root.to_local(waar_globaal)
		o._fx_wolk(root, inslag2, Color(0.55, 0.5, 0.4), 0.8)
	p.spel_score = ontploft.size()
	var klaar := root.create_tween()
	klaar.tween_interval(1.2 + 0.15 * float(ontploft.size()) + (2.9 if not ontploft.is_empty() else 0.0))
	o._klaar(p, klaar)


func _vat_ontploft(doel: Dictionary, i: int, vertraging: float, ontploft: Array) -> void:
	var vaten: Array = doel.vaten
	var v: Dictionary = vaten[i]
	if bool(v.om):
		return
	v.om = true
	ontploft.append(i)
	var vroot: Node3D = doel.node
	var vn: Node3D = v.node
	var vp: Vector3 = v.pos
	var tw := vroot.create_tween()
	tw.tween_interval(vertraging)
	tw.tween_callback(func() -> void:
		o._fx_knal(vroot, vp + Vector3(0.0, 0.18, 0.0), 1.1)
		o._fx_spetters(vroot, vp + Vector3(0.0, 0.2, 0.0), 8, Color(0.45, 0.33, 0.2))
		_toon(["prop_kruitvat", "prop_kanon", "cannon_heavy"], o._rng.randf_range(0.9, 1.1))
		if is_instance_valid(vn):
			vn.visible = false)
	for j in vaten.size():
		var w: Dictionary = vaten[j]
		if bool(w.om):
			continue
		if (w.pos as Vector3).distance_to(vp) < 0.45 and o._rng.randf() < 0.75:
			_vat_ontploft(doel, j, vertraging + 0.14 + o._rng.randf_range(0.0, 0.08), ontploft)


# ---------------------------------------------------------------- 4. vissen

## Een hengel in een vorkstok aan de waterkant. `water` als bij de stenen
## (plas: ellips in de ruimte van de ouder; rivier: vanaf z_rand), de lokale
## -Z van de hengel wijst het water in.
func bouw_hengel(ouder: Node3D, lokaal: Vector3, draai: float, water: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "Hengel"
	root.position = lokaal
	root.rotation.y = draai
	ouder.add_child(root)
	var hout := Color(0.42, 0.32, 0.2)
	o._mesh(o._cilinder(0.014, 0.28), hout, root, Vector3(0.0, 0.14, 0.12))
	var stok := o._mesh(o._cilinder(0.011, 0.95), Color(0.55, 0.42, 0.25), root, Vector3.ZERO)
	stok.rotation.x = deg_to_rad(-55.0)
	stok.position = Vector3(0.0, 0.05 + 0.475 * sin(deg_to_rad(55.0)), 0.12 - 0.475 * cos(deg_to_rad(55.0)))
	var tip := Vector3(0.0, 0.05 + 0.95 * sin(deg_to_rad(55.0)), 0.12 - 0.95 * cos(deg_to_rad(55.0)))
	o._mesh(o._cilinder(0.03, 0.03), Color(0.3, 0.3, 0.32), root, Vector3(0.0, 0.14, 0.1)).rotation.z = deg_to_rad(90.0)
	var lijn := o._mesh(o._cilinder(0.004, 1.0), Color(0.9, 0.9, 0.85), root, tip)
	lijn.visible = false
	lijn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var dobber := Node3D.new()
	dobber.name = "Dobber"
	dobber.visible = false
	root.add_child(dobber)
	o._mesh(o._bol(0.035), Color(0.85, 0.2, 0.15), dobber, Vector3(0.0, 0.02, 0.0))
	o._mesh(o._bol(0.03), Color(0.95, 0.95, 0.9), dobber, Vector3(0.0, -0.015, 0.0))
	o._registreer(root, 0.85, [_reageer_hengel_wip], {"spel": "vissen", "water": water, "tip": tip, "lijn": lijn, "dobber": dobber,
			"vangsten": [], "tik": ["prop_hengel", "prop_tik"], "pijl_ouder": root,
			"spel_conf": {"zwaai": 0.0, "laadtijd": 1.0, "pijl_min": 0.7, "pijl_max": 1.4, "pijl_pos": Vector3(0.0, 0.03, -0.3)},
			"spel_score": 0})


func _reageer_hengel_wip(p: Dictionary) -> void:
	var root: Node3D = p.node
	o._geluid(["prop_hengel", "prop_tik"])
	var tw := root.create_tween()
	tw.tween_property(root, "rotation:x", 0.12, 0.12).set_trans(Tween.TRANS_SINE)
	tw.tween_property(root, "rotation:x", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	o._klaar(p, tw)


## Uitwerpen: de dobber vliegt de lengte van de pijl het water in (binnen de plas).
func _vissen_werp(p: Dictionary, kracht: float) -> void:
	var root: Node3D = p.node
	var water: Dictionary = p.water
	var ouder: Node3D = root.get_parent()
	var conf: Dictionary = p.get("spel_conf", {})
	var afstand: float = float(conf.get("pijl_min", 0.7)) + kracht * float(conf.get("pijl_max", 1.4))
	var d: Vector3 = root.transform.basis * Vector3(0.0, 0.0, -1.0)
	d.y = 0.0
	d = d.normalized()
	# in de ruimte van de ouder, en binnen het water blijven
	var landing_o: Vector3 = root.position + d * afstand
	landing_o.y = 0.02
	var stap := afstand
	while stap > 0.15 and not _in_water(water, landing_o):
		stap -= 0.05
		landing_o = root.position + d * stap
		landing_o.y = 0.02
	if not _in_water(water, landing_o):
		_toon(["prop_hengel", "prop_tik"], 1.0)
		_tekst(root, Vector3(0.0, 0.9, 0.0), "Geen water!", Color(0.85, 0.85, 0.9))
		p.bezig = false
		return
	var landing: Vector3 = root.to_local(ouder.to_global(landing_o))
	var dobber: Node3D = p.dobber
	var tip: Vector3 = p.tip
	dobber.visible = true
	dobber.position = tip
	var lijn: MeshInstance3D = p.lijn
	lijn.visible = true
	_toon(["prop_hengel", "prop_tik"], 1.0)
	p["spel_staat"] = {"wacht_op_tik": false, "fase": "vlucht", "tot": 0.0, "dips": 0, "land": landing, "landing_o": landing_o,
		"ring_ouder": water.get("ring_ouder", ouder), "t0": o._tijd}
	var tw := dobber.create_tween()
	tw.tween_method(o._boog.bind(dobber, tip, landing, 0.35), 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		var staat: Dictionary = p.get("spel_staat", {})
		if staat.is_empty():
			return
		var ro: Node3D = staat.ring_ouder
		if is_instance_valid(ro):
			o._rimpel(ro, ro.to_local(ouder.to_global(landing_o)))
		_toon(["prop_plons", "small_blood_splash"], 1.1)
		staat.fase = "wacht"
		staat.wacht_op_tik = true
		staat.tot = o._tijd + o._rng.randf_range(2.0, 5.0))


func _vissen_process(p: Dictionary, _delta: float) -> void:
	var staat: Dictionary = p.spel_staat
	var dobber: Node3D = p.dobber
	var lijn: MeshInstance3D = p.lijn
	if not is_instance_valid(dobber) or not is_instance_valid(lijn):
		p.erase("spel_staat")
		p.bezig = false
		return
	var fase := String(staat.fase)
	if fase == "wacht" or fase == "dip":
		var land: Vector3 = staat.land
		var t: float = o._tijd - float(staat.t0)
		dobber.position = Vector3(land.x, land.y + 0.012 * sin(t * 3.2) - (0.07 if fase == "dip" else 0.0), land.z)
		if o._tijd >= float(staat.tot):
			if fase == "wacht":
				staat.fase = "dip"
				staat.tot = o._tijd + 0.5
				var ro: Node3D = staat.ring_ouder
				if is_instance_valid(ro):
					o._rimpel(ro, ro.to_local((p.node as Node3D).to_global(land)))
				_toon(["prop_plons", "small_blood_splash"], 1.4)
			else:
				staat.dips = int(staat.dips) + 1
				if int(staat.dips) >= 3:
					_vissen_leeg(p, "Niets...")
					return
				staat.fase = "wacht"
				staat.tot = o._tijd + o._rng.randf_range(1.5, 3.5)
	# de lijn van de top van de hengel naar de dobber
	_span(lijn, p.tip, dobber.position)


## Een dunne cilinder van a naar b (beide in de ruimte van zijn ouder).
func _span(lijn: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var lengte := d.length()
	if lengte < 0.001:
		lijn.visible = false
		return
	var n := d / lengte
	var draai_as := Vector3.UP.cross(n)
	var basis := Basis.IDENTITY
	if draai_as.length() > 0.0001:
		basis = Basis(draai_as.normalized(), acos(clampf(Vector3.UP.dot(n), -1.0, 1.0)))
	lijn.transform = Transform3D(basis.scaled(Vector3(1.0, lengte, 1.0)), a + d * 0.5)


func _vissen_tik(p: Dictionary) -> void:
	var staat: Dictionary = p.get("spel_staat", {})
	if staat.is_empty():
		return
	if String(staat.fase) == "dip":
		_vissen_vangst(p)
	elif String(staat.fase) == "wacht":
		_vissen_leeg(p, "Te vroeg!")


func _vissen_leeg(p: Dictionary, tekst: String) -> void:
	var root: Node3D = p.node
	var dobber: Node3D = p.dobber
	var lijn: MeshInstance3D = p.lijn
	var staat: Dictionary = p.get("spel_staat", {})
	p.erase("spel_staat")
	_toon(["prop_hengel", "prop_tik"], 1.2)
	_tekst(root, (staat.get("land", Vector3(0.0, 0.0, -1.0)) as Vector3) + Vector3(0.0, 0.25, 0.0), tekst, Color(0.85, 0.85, 0.9))
	var tw := dobber.create_tween()
	tw.tween_method(o._boog.bind(dobber, dobber.position, p.tip, 0.3), 0.0, 1.0, 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		dobber.visible = false
		lijn.visible = false)
	o._klaar(p, tw)
	# de lijn volgt de dobber ook tijdens het binnenhalen
	var lt := lijn.create_tween()
	lt.tween_method(func(_t: float) -> void: _span(lijn, p.tip, dobber.position), 0.0, 1.0, 0.4)


func _vissen_vangst(p: Dictionary) -> void:
	var root: Node3D = p.node
	var dobber: Node3D = p.dobber
	var lijn: MeshInstance3D = p.lijn
	var staat: Dictionary = p.get("spel_staat", {})
	p.erase("spel_staat")
	var land: Vector3 = staat.get("land", Vector3(0.0, 0.0, -1.0))
	var r := o._rng.randf()
	var vangst := Node3D.new()
	vangst.name = "Vangst"
	root.add_child(vangst)
	vangst.position = land
	var naam := ""
	var kleur := Color(1.0, 0.95, 0.8)
	var geluid: Array = ["prop_vis", "prop_plons"]
	if r < 0.55:
		naam = "Snoek!"
		var lijf := o._mesh(o._bol(0.05), Color(0.55, 0.62, 0.5), vangst, Vector3(0.0, 0.04, 0.0))
		lijf.scale = Vector3(1.0, 0.55, 2.2)
		var staart := o._mesh(o._kegel(0.045, 0.08), Color(0.5, 0.56, 0.45), vangst, Vector3(0.0, 0.04, 0.13))
		staart.rotation.x = deg_to_rad(-90.0)
		o._mesh(o._bol(0.008), Color(0.05, 0.05, 0.05), vangst, Vector3(0.03, 0.055, -0.07))
	elif r < 0.8:
		naam = "Een laars!"
		geluid = ["val_prop", "impact_wood"]
		o._mesh(o._box(Vector3(0.09, 0.16, 0.1)), Color(0.22, 0.16, 0.1), vangst, Vector3(0.0, 0.08, 0.0))
		o._mesh(o._box(Vector3(0.09, 0.05, 0.17)), Color(0.22, 0.16, 0.1), vangst, Vector3(0.0, 0.025, 0.05))
	elif r < 0.95:
		naam = "Verloren musket!"
		geluid = ["impact_armor", "prop_tik"]
		var loop := o._mesh(o._cilinder(0.012, 0.55), Color(0.25, 0.25, 0.27), vangst, Vector3(0.0, 0.03, -0.1))
		loop.rotation.x = deg_to_rad(90.0)
		o._mesh(o._box(Vector3(0.04, 0.05, 0.25)), Color(0.4, 0.28, 0.16), vangst, Vector3(0.0, 0.03, 0.2))
	else:
		naam = "Een kist!"
		kleur = Color(1.0, 0.85, 0.3)
		geluid = ["prop_combo", "prop_munt"]
		o._mesh(o._box(Vector3(0.2, 0.13, 0.13)), Color(0.45, 0.3, 0.16), vangst, Vector3(0.0, 0.065, 0.0))
		o._mesh(o._box(Vector3(0.21, 0.03, 0.14)), Color(0.85, 0.7, 0.25), vangst, Vector3(0.0, 0.08, 0.0))
	o._fx_spetters(root, land, 8, Color(0.75, 0.85, 0.95))
	_toon(geluid, o._rng.randf_range(0.95, 1.05))
	var vangsten: Array = p.vangsten
	var plek := Vector3(0.28 + 0.13 * float(vangsten.size() % VANGSTEN_MAX), 0.0, 0.18 + 0.05 * float(vangsten.size() % 3))
	vangsten.append(vangst)
	if vangsten.size() > VANGSTEN_MAX:
		var oud: Node3D = vangsten.pop_front()
		if is_instance_valid(oud):
			oud.queue_free()
	p.spel_score = int(p.get("spel_score", 0)) + 1
	var tw := vangst.create_tween()
	tw.tween_method(o._boog.bind(vangst, land, plek, 0.7), 0.0, 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(vangst, "rotation:y", o._rng.randf_range(-2.0, 2.0), 0.6)
	tw.tween_callback(func() -> void:
		_tekst(root, plek + Vector3(0.0, 0.3, 0.0), naam, kleur)
		dobber.visible = false
		lijn.visible = false)
	# klein spartelen
	tw.tween_property(vangst, "rotation:z", 0.4, 0.1)
	tw.tween_property(vangst, "rotation:z", -0.3, 0.1)
	tw.tween_property(vangst, "rotation:z", 0.0, 0.15)
	o._klaar(p, tw)
	# de dobber en de lijn komen mee naar de kant
	var dt := dobber.create_tween()
	dt.tween_method(o._boog.bind(dobber, dobber.position, p.tip, 0.5), 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE)
	var lt := lijn.create_tween()
	lt.tween_method(func(_t: float) -> void: _span(lijn, p.tip, dobber.position), 0.0, 1.0, 0.55)


# ---------------------------------------------------------------- 5. de tamboer-cadans

## De trommel-prop wordt een spel: vasthouden telt af, dan tik je acht slagen
## op de maat; drie soldaatjes achter de trom marcheren op de plaats mee.
func maak_cadans(p: Dictionary, team: String) -> void:
	var root: Node3D = p.node
	p["spel"] = "cadans"
	p["tempo"] = 0.6
	p["spel_score"] = 0
	var jas := Color(0.7, 0.2, 0.18) if team == "red" else Color(0.22, 0.35, 0.7)
	var soldaten: Array = []
	for i in 3:
		var s := Node3D.new()
		s.name = "Soldaat%d" % i
		s.position = Vector3(-0.32 + 0.32 * float(i), 0.0, -0.5 - (0.05 if i == 1 else 0.0))
		root.add_child(s)
		var lijf := o._mesh(o._cilinder(0.045, 0.15), jas, s, Vector3(0.0, 0.135, 0.0))
		o._mesh(o._cilinder(0.03, 0.06), Color(0.9, 0.88, 0.8), s, Vector3(0.0, 0.03, 0.0))
		o._mesh(o._bol(0.035), Color(0.85, 0.72, 0.6), s, Vector3(0.0, 0.245, 0.0))
		o._mesh(o._cilinder(0.036, 0.07), Color(0.1, 0.1, 0.1), s, Vector3(0.0, 0.3, 0.0))
		lijf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		soldaten.append(s)
	var vlag := Node3D.new()
	vlag.name = "Vlaggetje"
	vlag.position = Vector3(0.62, 0.0, -0.5)
	root.add_child(vlag)
	o._mesh(o._cilinder(0.008, 0.5), Color(0.42, 0.32, 0.2), vlag, Vector3(0.0, 0.25, 0.0))
	var doek := o._mesh(o._box(Vector3(0.14, 0.09, 0.01)), jas, vlag, Vector3(0.075, 0.42, 0.0))
	p["soldaten"] = soldaten
	p["vlagdoek"] = doek
	p["vlag_basis"] = doek.position


func _cadans_start(p: Dictionary) -> void:
	var root: Node3D = p.node
	p.bezig = true
	var tempo: float = float(p.get("tempo", 0.6))
	p["spel_staat"] = {"wacht_op_tik": true, "fase": "intro", "tempo": tempo, "beat": 0, "volgende": o._tijd + tempo,
		"raak": 0, "mis": 0, "getikt_vorige": true, "getikt_volgende": false, "vorige": o._tijd}
	_tekst(root, Vector3(0.0, 0.7, 0.0), "Op de maat!", Color(1.0, 0.9, 0.5))


func _cadans_process(p: Dictionary, _delta: float) -> void:
	var staat: Dictionary = p.spel_staat
	var root: Node3D = p.node
	if o._tijd < float(staat.volgende):
		return
	var tempo: float = float(staat.tempo)
	var fase := String(staat.fase)
	if fase == "intro":
		staat.beat = int(staat.beat) + 1
		_toon(["prop_trom", "val_drum"], 1.0)
		_puls(root, Color(0.9, 0.9, 0.85))
		_tekst(root, Vector3(0.0, 0.55, 0.0), str(staat.beat), Color(0.9, 0.9, 0.85))
		if int(staat.beat) >= 4:
			staat.fase = "spel"
			staat.beat = 0
			staat.getikt_vorige = true   # de aftel-tik telt niet
		staat.vorige = float(staat.volgende)
		staat.volgende = float(staat.volgende) + tempo
		return
	# een slag verstrijkt: de vorige slag wordt afgerekend als hij niet getikt is
	if not bool(staat.getikt_vorige):
		_cadans_mis(p)
	staat.getikt_vorige = bool(staat.getikt_volgende)
	staat.getikt_volgende = false
	staat.beat = int(staat.beat) + 1
	staat.vorige = float(staat.volgende)
	staat.volgende = float(staat.volgende) + tempo
	if int(staat.beat) <= 8:
		_puls(root, Color(1.0, 0.85, 0.3))
	if int(staat.beat) > 8:
		# de laatste slag krijgt nog zijn venster; dan de uitslag
		staat.fase = "uit"
		staat.wacht_op_tik = false
		var tw := root.create_tween()
		tw.tween_interval(0.2)
		tw.tween_callback(func() -> void:
			var st: Dictionary = p.get("spel_staat", {})
			var raak: int = int(st.get("raak", 0))
			p.erase("spel_staat")
			p.spel_score = raak
			if raak >= 8:
				_tekst(root, Vector3(0.0, 0.7, 0.0), "Perfect!", Color(1.0, 0.85, 0.3))
				_toon(["prop_hoorn", "val_horn"], 1.0)
				p.tempo = maxf(0.36, float(p.get("tempo", 0.6)) * 0.9)
				for s in p.soldaten:
					if is_instance_valid(s):
						var st2 := (s as Node3D).create_tween()
						st2.tween_property(s, "rotation:y", deg_to_rad(90.0), 0.3).set_trans(Tween.TRANS_BACK)
						st2.tween_interval(1.0)
						st2.tween_property(s, "rotation:y", 0.0, 0.3)
			else:
				_tekst(root, Vector3(0.0, 0.7, 0.0), "%d van 8 in de maat" % raak)
			var doek: Node3D = p.vlagdoek
			if is_instance_valid(doek):
				var vt := doek.create_tween()
				vt.tween_property(doek, "position", p.vlag_basis, 0.6).set_trans(Tween.TRANS_SINE)
			p.bezig = false)


func _cadans_tik(p: Dictionary) -> void:
	var staat: Dictionary = p.get("spel_staat", {})
	if staat.is_empty() or String(staat.fase) != "spel":
		return
	var venster := 0.17
	if not bool(staat.getikt_vorige) and o._tijd - float(staat.vorige) <= venster:
		staat.getikt_vorige = true
		_cadans_raak(p)
	elif not bool(staat.getikt_volgende) and float(staat.volgende) - o._tijd <= venster and int(staat.beat) < 8:
		# vroeg voor de volgende slag; na de achtste is er geen volgende meer
		staat.getikt_volgende = true
		_cadans_raak(p)
	else:
		_cadans_mis(p)


func _cadans_raak(p: Dictionary) -> void:
	var staat: Dictionary = p.spel_staat
	staat.raak = int(staat.raak) + 1
	var kant: float = 1.0 if int(staat.raak) % 2 == 0 else -1.0
	for s in p.soldaten:
		if not is_instance_valid(s):
			continue
		var sn: Node3D = s
		var tw := sn.create_tween()
		tw.tween_property(sn, "position:y", 0.06, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(sn, "rotation:z", 0.12 * kant, 0.09)
		tw.tween_property(sn, "position:y", 0.0, 0.14).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(sn, "rotation:z", 0.0, 0.14)
	var doek: Node3D = p.vlagdoek
	if is_instance_valid(doek):
		var vt := doek.create_tween()
		vt.tween_property(doek, "position:y", doek.position.y + 0.012, 0.15)


func _cadans_mis(p: Dictionary) -> void:
	var staat: Dictionary = p.spel_staat
	staat.mis = int(staat.mis) + 1
	var root: Node3D = p.node
	_tekst(root, Vector3(0.0, 0.55, -0.5), "Uit de maat!", Color(0.85, 0.85, 0.9))
	for s in p.soldaten:
		if not is_instance_valid(s):
			continue
		var sn: Node3D = s
		var tw := sn.create_tween()
		tw.tween_property(sn, "rotation:z", o._rng.randf_range(-0.5, 0.5), 0.12).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(sn, "rotation:z", 0.0, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Een korte gouden ring om de trom: de maat.
func _puls(root: Node3D, kleur: Color) -> void:
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.16
	tm.outer_radius = 0.2
	tm.rings = 24
	tm.ring_segments = 6
	ring.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(kleur.r, kleur.g, kleur.b, 0.8)
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = Vector3(0.0, 0.02, 0.0)
	ring.scale = Vector3(1.0, 0.15, 1.0)
	root.add_child(ring)
	var tw := ring.create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector3(2.4, 0.15, 2.4), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.28)
	tw.chain().tween_callback(ring.queue_free)

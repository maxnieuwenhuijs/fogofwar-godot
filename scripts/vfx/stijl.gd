extends RefCounted

## Stijl: looks voor alle 3D-objecten (6 oktober 2026, docs/VFX-studio.md stap 6;
## Max: "kan je ook iets met shaders doen voor alle 3d objecten", en "een studio
## om het allemaal uit te proberen"). EEN shader over het camerabeeld, dus elk
## model, elke prop en het bord krijgt de look, ook nieuwe modellen, zonder iets
## per model. Zonder class_name: `const STIJL := preload("res://scripts/vfx/stijl.gd")`.
##
## Hoe: een vlak dat het hele scherm bedekt, als kind van de camera, met een
## shader die het beeld (hint_screen_texture) en de diepte leest. Het tekent als
## EERSTE van de doorzichtige laag (render_priority -128): Godot kopieert het
## scherm na de ondoorzichtige laag, dus de look werkt op bord en modellen, en
## rook, vuur, bloed en de andere effecten tekenen er daarna scherp overheen.
##
## Looks (knoppen in effects_tuning.json, allemaal standaard 0 = uit; staat alles
## uit, dan is het vlak onzichtbaar en kost het niets):
##   stijl_inkt       inktranden (gravure, zoals de emblemen) uit diepte- en
##                    kleursprongen; stijl_inkt_dikte in pixels
##   stijl_rand       randlicht: de binnenkant van elk silhouet licht op
##   stijl_miniatuur  miniatuur-scherpte (tilt-shift): boven en onder vaag, alsof
##                    je een echt tafelspel fotografeert; stijl_focus_y,
##                    stijl_focus_band
##   stijl_warmte     kleurstemming, -1 koel tot 1 warm
##   stijl_korrel     filmkorrel
##   stijl_trappen    kleurtrappen (cel-achtig): de lichtheid in een paar treden

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D scherm : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D diepte : hint_depth_texture, filter_nearest, repeat_disable;

uniform float inkt = 0.0;
uniform float inkt_dikte = 2.0;
uniform vec4 inkt_kleur : source_color = vec4(0.12, 0.08, 0.05, 1.0);
uniform float rand = 0.0;
uniform vec4 rand_kleur : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform float miniatuur = 0.0;
uniform float focus_y = 0.5;
uniform float focus_band = 0.22;
uniform vec2 beeld = vec2(0.0, 1.0);   // boven en onder van het spelbeeld (zet_beeld)
uniform float warmte = 0.0;
uniform float korrel = 0.0;
uniform float trappen = 0.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float lin(vec2 uv, mat4 inv_proj) {
	float d = texture(diepte, uv).r;
	vec4 p = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -p.z / p.w;
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = inkt_dikte / VIEWPORT_SIZE;
	vec3 kleur = texture(scherm, uv).rgb;
	if (miniatuur > 0.0) {
		// buiten de scherpe band: een kring van acht monsters op een lagere
		// resolutie, des te wijder naarmate je verder van de band zit. De band
		// rekent in het spelbeeld (`beeld`): in het spel het hele scherm, in de
		// VFX-tuner het stuk tussen de panelen.
		float hoog = max(beeld.y - beeld.x, 0.001);
		float buiten = max(abs((uv.y - beeld.x) / hoog - focus_y) - focus_band, 0.0);
		float straal = buiten * miniatuur * 0.06 * hoog;
		if (straal > 0.0005) {
			float lod = clamp(log2(straal * VIEWPORT_SIZE.y * 0.25 + 1.0), 0.0, 5.0);
			vec3 som = textureLod(scherm, uv, lod).rgb;
			for (int i = 0; i < 8; i++) {
				float h = float(i) * 0.785398;
				som += textureLod(scherm, uv + vec2(cos(h), sin(h)) * straal * vec2(VIEWPORT_SIZE.y / VIEWPORT_SIZE.x, 1.0), lod).rgb;
			}
			kleur = som / 9.0;
		}
	}
	if (inkt > 0.0 || rand > 0.0) {
		float dc = lin(uv, INV_PROJECTION_MATRIX);
		float dn = lin(uv + vec2(0.0, -px.y), INV_PROJECTION_MATRIX);
		float ds = lin(uv + vec2(0.0, px.y), INV_PROJECTION_MATRIX);
		float de = lin(uv + vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
		float dw = lin(uv + vec2(-px.x, 0.0), INV_PROJECTION_MATRIX);
		float dne = lin(uv + vec2(px.x, -px.y), INV_PROJECTION_MATRIX);
		float dsw = lin(uv + vec2(-px.x, px.y), INV_PROJECTION_MATRIX);
		float dnw = lin(uv + vec2(-px.x, -px.y), INV_PROJECTION_MATRIX);
		float dse = lin(uv + vec2(px.x, px.y), INV_PROJECTION_MATRIX);
		if (rand > 0.0) {
			// dichterbij dan de buren = de binnenkant van een silhouet
			float voor = max(max(dn, ds), max(de, dw)) - dc;
			kleur += rand_kleur.rgb * smoothstep(0.04, 0.3, voor) * rand * 0.6;
		}
		if (inkt > 0.0) {
			float sprong = abs(dn - ds) + abs(de - dw) + 0.7 * (abs(dne - dsw) + abs(dnw - dse));
			float rand_d = smoothstep(0.03, 0.12, sprong);
			float ln = luma(texture(scherm, uv + vec2(0.0, -px.y)).rgb);
			float ls = luma(texture(scherm, uv + vec2(0.0, px.y)).rgb);
			float le = luma(texture(scherm, uv + vec2(px.x, 0.0)).rgb);
			float lw = luma(texture(scherm, uv + vec2(-px.x, 0.0)).rgb);
			float rand_l = smoothstep(0.12, 0.35, abs(ln - ls) + abs(le - lw)) * 0.55;
			kleur = mix(kleur, inkt_kleur.rgb, clamp(max(rand_d, rand_l), 0.0, 1.0) * inkt);
		}
	}
	if (trappen > 0.0) {
		// in een waarneembare schaal (gamma) en altijd het midden van een trede:
		// donker blijft donker, maar wordt nooit zwart
		float l = luma(kleur);
		float lg = pow(max(l, 0.0), 1.0 / 2.2);
		float n = mix(10.0, 4.0, trappen);
		float lgq = mix(lg, (floor(lg * n) + 0.5) / n, trappen);
		kleur *= pow(lgq, 2.2) / max(l, 0.0001);
	}
	if (warmte != 0.0) {
		vec3 warm = vec3(1.08, 1.0, 0.86);
		vec3 koel = vec3(0.9, 0.98, 1.1);
		kleur *= mix(vec3(1.0), warmte > 0.0 ? warm : koel, abs(warmte));
	}
	if (korrel > 0.0) {
		kleur += (hash(uv * VIEWPORT_SIZE + vec2(TIME * 61.0, TIME * 17.0)) - 0.5) * korrel * 0.12;
	}
	ALBEDO = kleur;
	ALPHA = 1.0;
}
"""

## Elke knop: label, bereik, stap en standaard (de VFX-tuner toont ze; de
## catalogus neemt ze over in KNOPPEN).
const KNOPPEN: Dictionary = {
	"stijl_inkt": {"label": "inktranden", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.0},
	"stijl_inkt_dikte": {"label": "inktranden: dikte (px)", "min": 0.5, "max": 5.0, "step": 0.05, "def": 2.0},
	"stijl_rand": {"label": "randlicht", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.0},
	"stijl_miniatuur": {"label": "miniatuur-scherpte (tilt-shift)", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.0},
	"stijl_focus_y": {"label": "miniatuur: scherp op hoogte", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.5},
	"stijl_focus_band": {"label": "miniatuur: scherpe band", "min": 0.0, "max": 0.5, "step": 0.01, "def": 0.22},
	"stijl_warmte": {"label": "kleur: koel (-) of warm (+)", "min": -1.0, "max": 1.0, "step": 0.01, "def": 0.0},
	"stijl_korrel": {"label": "filmkorrel", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.0},
	"stijl_trappen": {"label": "kleurtrappen (cel)", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.0},
}

const NAAM := "StijlVlak"
static var _shader: Shader = null


## Zet het vlak op de camera (een keer; opnieuw aanroepen werkt het bij) en pas
## de knoppen toe. Geeft het vlak terug.
static func zet_op(camera: Camera3D) -> MeshInstance3D:
	if camera == null:
		return null
	var mi := camera.get_node_or_null(NAAM) as MeshInstance3D
	if mi == null:
		if _shader == null:
			_shader = Shader.new()
			_shader.code = SHADER
		mi = MeshInstance3D.new()
		mi.name = NAAM
		var vlak := QuadMesh.new()
		vlak.size = Vector2(2.0, 2.0)
		mi.mesh = vlak
		mi.extra_cull_margin = 16384.0
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := ShaderMaterial.new()
		mat.shader = _shader
		mat.render_priority = Material.RENDER_PRIORITY_MIN   # eerst van de doorzichtige laag
		mi.material_override = mat
		camera.add_child(mi)
		mi.position = Vector3(0.0, 0.0, -1.0)
	pas_toe(mi)
	return mi


## Welk deel van het scherm het spelbeeld is (`boven` en `onder` als deel van de
## hoogte, 0..1). In het spel het hele scherm (nooit gezet: de shader rekent dan
## met 0..1); de VFX-tuner legt panelen over boven- en onderkant, en zonder dit
## viel de vage rand van de miniatuur daarachter (Max, 6 oktober: "de tilt shift
## zie ik niet echt").
static func zet_beeld(mi: MeshInstance3D, boven: float, onder: float) -> void:
	if mi == null or not is_instance_valid(mi):
		return
	(mi.material_override as ShaderMaterial).set_shader_parameter("beeld", Vector2(boven, onder))


## De knoppen uit effects_tuning.json naar de shader; alles 0 = onzichtbaar.
static func pas_toe(mi: MeshInstance3D) -> void:
	if mi == null or not is_instance_valid(mi):
		return
	var mat := mi.material_override as ShaderMaterial
	var aan := false
	for k in ["stijl_inkt", "stijl_rand", "stijl_miniatuur", "stijl_warmte", "stijl_korrel", "stijl_trappen"]:
		if absf(PawnView.fx(k, 0.0)) > 0.001:
			aan = true
	mi.visible = aan
	mat.set_shader_parameter("inkt", PawnView.fx("stijl_inkt", 0.0))
	mat.set_shader_parameter("inkt_dikte", PawnView.fx("stijl_inkt_dikte", 2.0))
	mat.set_shader_parameter("rand", PawnView.fx("stijl_rand", 0.0))
	mat.set_shader_parameter("miniatuur", PawnView.fx("stijl_miniatuur", 0.0))
	mat.set_shader_parameter("focus_y", PawnView.fx("stijl_focus_y", 0.5))
	mat.set_shader_parameter("focus_band", PawnView.fx("stijl_focus_band", 0.22))
	mat.set_shader_parameter("warmte", PawnView.fx("stijl_warmte", 0.0))
	mat.set_shader_parameter("korrel", PawnView.fx("stijl_korrel", 0.0))
	mat.set_shader_parameter("trappen", PawnView.fx("stijl_trappen", 0.0))

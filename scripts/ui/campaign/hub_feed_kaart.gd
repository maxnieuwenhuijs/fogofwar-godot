class_name HubFeedKaart
extends RefCounted

## De kaartjes van de tijdlijn (pdf "Campaign_hub", pagina 2 "Feed cards
## type"): perkament met rechtsboven een gekleurd lint met het soort bericht,
## linksboven het klokje met de tijd, in het midden de spelers als portret en
## onderaan een zin. Eén builder per soort feed-item uit de SoloDriver:
##
##   report      BATTLE REPORT  rood    twee portretten, sabels, verliezen
##   nominatie   NOMINATIE      bruin   vechter -> doel
##   event       DONATIE / RUIL (blauw), TESTAMENT (zwart)
##   fase        FASE           navy    faseschild in een krans (+ STEMUITSLAG)
##   bark/chat   QUICK CHAT     groen   portret met tekstballon
##
## Alles in ontwerp-eenheden maal S (zie HubAssets).

var c: CState
var mens_id: int
var s: float
var mijn_team: int
## Gevallen: de teamchat is verzegeld (UI-spec 2b.4), er komen geen
## chatkaartjes meer bij.
var mens_dood: bool

## Lint per soort: [holder-nummer, icoon, tint van het lint].
const LINT := {
	"report": [1, "Inbattle_icon", Color.WHITE],
	"stemuitslag": [1, "Vote_icon", Color.WHITE],
	"donatie": [2, "Donation_icon", Color.WHITE],
	"ruil": [2, "Donation_icon", Color.WHITE],
	"nominatie": [3, "Nomination_icon", Color.WHITE],
	"testament": [4, "Testament_icon", Color.WHITE],
	"fase": [5, "Flag_icon", Color.WHITE],
	"systeem": [5, "Phase_icon", Color.WHITE],
	"chat": [4, "Chat_icon", HubAssets.GROEN],
}

## Barks die al een eigen kaartje hebben (de nominatie zelf): alleen in de chat.
const ALLEEN_CHAT := ["zelf_nominatie", "nominatie_teamgenoot"]


func _init(p_c: CState, p_mens_id: int, p_s: float) -> void:
	c = p_c
	mens_id = p_mens_id
	s = p_s
	mijn_team = int(c.spelers.get(mens_id, {}).get("team", 0))
	mens_dood = String(c.spelers.get(mens_id, {}).get("status", "actief")) != "actief"


func _u(v: float) -> float:
	return v * s


func _px(v: float) -> int:
	return int(round(v * s))


## Het kaartje voor een feed-item, of null als het item niet in de tijdlijn hoort.
func bouw(e: Dictionary, tijd: String) -> Control:
	match String(e.get("type", "")):
		"report":
			return _report(e, tijd)
		"nominatie":
			# Stemdetails zijn team-only (campagne-spec); de uitslag is publiek.
			if _team(int(e.get("speler", -1))) != mijn_team:
				return null
			return _nominatie(e, tijd)
		"event":
			return _event(e, tijd)
		"fase":
			return _fase(e, tijd)
		"bark", "chat":
			if int(e.get("speler", -1)) < 0:
				return _systeem(e, tijd)
			if ALLEEN_CHAT.has(String(e.get("trigger", ""))):
				return null
			# Teamchat: alleen je eigen team, en niet meer als je gevallen bent.
			if mens_dood or _team(int(e.speler)) != mijn_team:
				return null
			return _chat(e, tijd)
	return null


## De stemuitslag hangt aan een fasewissel uit de raad (niet in ronde 1: daar lootte het systeem).
func stemuitslag(e: Dictionary, tijd: String) -> Control:
	var paren: Array = e.get("paren", [])
	if paren.is_empty() or (c.rules.ronde1_loting and int(e.get("ronde", 0)) == 1):
		return null
	var hoofd: Array = paren[0]
	for p in paren:
		if int(p[0]) == mens_id or int(p[1]) == mens_id:
			hoofd = p
	var kaart := _kaart("stemuitslag", tr("HUB_TAG_VOTE_RESULT"), tijd)
	var doel: int = int(hoofd[1]) if _team(int(hoofd[0])) == mijn_team else int(hoofd[0])
	kaart.midden.add_child(_in_krans(_portret(doel, 52)))
	var regels: Array = []
	for p in paren:
		var a: int = int(p[0]) if _team(int(p[0])) == mijn_team else int(p[1])
		var b: int = int(p[1]) if a == int(p[0]) else int(p[0])
		regels.append(tr("HUB_FEED_PAIR") % [_naam(a), _naam(b)])
	kaart.zin(tr("HUB_FEED_COUNCIL_CHOSE") % _naam(doel), 9)
	kaart.zin("\n".join(regels), 7, HubAssets.INKT_ZACHT)
	return kaart.wortel


# --- Soorten -----------------------------------------------------------------------

func _report(e: Dictionary, tijd: String) -> Control:
	var kaart := _kaart("report", tr("HUB_TAG_BATTLE_REPORT"), tijd)
	var a: int = int(e.p1)
	var b: int = int(e.p2)
	if _team(a) != mijn_team:
		var t := a
		a = b
		b = t
	var rij := _rij(10)
	rij.add_child(_zijde(a, e))
	var sabels := HubAssets.icoon("Inbattle_icon", _u(40), HubAssets.INKT)
	sabels.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	rij.add_child(sabels)
	rij.add_child(_zijde(b, e))
	kaart.midden.add_child(rij)
	var winnaar: int = int(e.get("winnaar", -1))
	var zin: String = tr("HUB_FEED_REPORT_DRAW")
	if winnaar >= 0:
		zin = tr("HUB_FEED_REPORT_US") if _team(winnaar) == mijn_team else tr("HUB_FEED_REPORT_THEM")
	kaart.zin(zin, 8.5)
	if winnaar >= 0:
		kaart.zin(tr("HUB_FEED_REPORT_WHO") % [_naam(winnaar), _methode(String(e.get("methode", "")))],
			7, HubAssets.INKT_ZACHT)
	return kaart.wortel


## Een kant van het slagrapport: portret, daaronder wat het duel hem aan
## campagne-reserve kostte (ingezet min buit, in punten) en drie figuurtjes
## voor het deel van zijn reserve dat verloren ging. Het veldleger telt niet
## mee: dat staat elk duel weer vol op het bord (C10). Oude rapporten zonder
## reserve tonen de gesneuvelde pionnen.
func _zijde(sid: int, e: Dictionary) -> Control:
	var kolom := VBoxContainer.new()
	kolom.add_theme_constant_override("separation", _px(2))
	kolom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := _portret(sid, 40)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	kolom.add_child(p)
	var kleur: Color = HubAssets.BLAUW if _team(sid) == mijn_team else HubAssets.ROOD
	var getal_tekst: String
	var vol: int
	var reserve: Dictionary = e.get("reserve", {})
	if reserve.has(str(sid)):
		var z: Dictionary = (e.get("inzet", {}) as Dictionary).get(str(sid), {})
		var kosten: int = int(z.get("inf", 0)) + 2 * int(z.get("cav", 0)) + 3 * int(z.get("art", 0))
		var netto: int = kosten - int((e.get("buit", {}) as Dictionary).get(str(sid), 0))
		if netto > 0:
			getal_tekst = "-%d" % netto
		elif netto < 0:
			getal_tekst = "+%d" % -netto
		else:
			getal_tekst = "0"
		var start: int = maxi(1, int(reserve[str(sid)]))
		vol = clampi(int(ceil(3.0 * float(maxi(0, netto)) / float(start))), 0, 3)
		if netto <= 0:
			vol = 0
	else:
		var v: Dictionary = (e.get("verliezen", {}) as Dictionary).get(str(sid), {})
		var verlies: int = int(v.get("inf", 0)) + int(v.get("cav", 0)) + int(v.get("art", 0))
		getal_tekst = ("-%d" % verlies) if verlies > 0 else "0"
		vol = mini(verlies, 3)
	var rij := _rij(1)
	var getal := HubAssets.tekst(getal_tekst, _px(11), kleur, true)
	getal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rij.add_child(getal)
	for i in 3:
		var fig := HubAssets.icoon("Battle_report_team_full" if i < vol else "Battle_report_team_empty",
			_u(15), kleur)
		fig.custom_minimum_size = Vector2(_u(7), _u(15))
		rij.add_child(fig)
	kolom.add_child(rij)
	return kolom


func _nominatie(e: Dictionary, tijd: String) -> Control:
	var kaart := _kaart("nominatie", tr("HUB_TAG_NOMINATION"), tijd)
	var eigen: int = int(e.eigen)
	var vijand: int = int(e.vijand)
	var rij := _rij(12)
	rij.add_child(_portret(eigen, 42))
	rij.add_child(_pijl())
	rij.add_child(_portret(vijand, 42))
	kaart.midden.add_child(rij)
	var wie: int = int(e.get("speler", -1))
	if wie == eigen:
		kaart.zin(tr("HUB_FEED_NOMINATE_SELF") % [_naam(wie), _naam(vijand)], 7.5)
	else:
		kaart.zin(tr("HUB_FEED_NOMINATE") % [_naam(wie), _naam(eigen), _naam(vijand)], 7.5)
	return kaart.wortel


func _event(e: Dictionary, tijd: String) -> Control:
	var soort := String(e.get("soort", ""))
	var wie: int = int(e.get("speler", -1))
	var punten: int = int(e.get("inf", 0)) + 2 * int(e.get("cav", 0)) + 3 * int(e.get("art", 0))
	var cp: int = int(e.get("cp", 0))
	if soort == "testament":
		var kaart := _kaart("testament", tr("HUB_TAG_TESTAMENT"), tijd)
		var rij := _rij(8)
		rij.add_child(_portret(wie, 42))
		var mid := VBoxContainer.new()
		mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mid.add_child(_bedrag(punten, cp))
		mid.add_child(_pijl())
		rij.add_child(mid)
		rij.add_child(_portret(int(e.get("naar", wie)), 42))
		kaart.midden.add_child(rij)
		kaart.zin(String(e.get("tekst", "")), 7.5)
		return kaart.wortel
	if soort == "ruil":
		var kaart := _kaart("ruil", tr("HUB_TAG_EXCHANGE"), tijd)
		var rij := _rij(8)
		rij.add_child(_portret(wie, 42))
		rij.add_child(_pijl())
		rij.add_child(HubAssets.icoon("Donation_icon", _u(36), _kleur(wie)))
		kaart.midden.add_child(rij)
		kaart.zin(String(e.get("tekst", "")), 7.5)
		return kaart.wortel
	# Donatie (en oude items zonder soort): portret -> tent +N.
	var kaart := _kaart("donatie", tr("HUB_TAG_DONATION"), tijd)
	var rij := _rij(8)
	rij.add_child(_portret(wie, 42))
	rij.add_child(_pijl())
	if cp > 0 and punten == 0:
		var medaille := UiAssets.icoon_rect("cp", _u(34), _kleur(wie))
		rij.add_child(medaille)
	else:
		rij.add_child(HubAssets.icoon("Donation_icon", _u(36), _kleur(wie)))
	var plus := HubAssets.tekst("+%d" % (punten if punten > 0 else cp), _px(13), _kleur(wie), true)
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rij.add_child(plus)
	kaart.midden.add_child(rij)
	kaart.zin(String(e.get("tekst", "")), 7.5)
	return kaart.wortel


func _fase(e: Dictionary, tijd: String) -> Control:
	var naar: int = int(e.get("naar", 0))
	var kaart := _kaart("fase", tr("HUB_TAG_PHASE"), tijd)
	var schild := Control.new()
	schild.custom_minimum_size = Vector2(_u(34), _u(36))
	schild.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vlag := HubAssets.plaat("frames_box/Flag_frame")
	vlag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	schild.add_child(vlag)
	var poot := HubAssets.icoon("Flag_icon", 0)
	poot.anchor_left = 0.2
	poot.anchor_right = 0.8
	poot.anchor_top = 0.14
	poot.anchor_bottom = 0.7
	schild.add_child(poot)
	kaart.midden.add_child(_in_krans(schild))
	var titel := HubAssets.tekst(tr(CampaignHub.FASE_KORT.get(naar, "?")), _px(11), HubAssets.INKT, true)
	titel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kaart.midden.add_child(titel)
	kaart.midden.add_child(_sierlijn(120))
	kaart.zin(tr("HUB_FEED_PHASE_SUB") % [tr(CampaignHub.FASE_KORT.get(int(e.get("van", 0)), "?")).to_lower(),
		tr(CampaignHub.FASE_KORT.get(naar, "?")).to_lower()], 7.5)
	return kaart.wortel


func _systeem(e: Dictionary, tijd: String) -> Control:
	var kaart := _kaart("systeem", String(e.get("naam", "")).to_upper(), tijd)
	kaart.zin(String(e.get("tekst", "")), 8)
	return kaart.wortel


func _chat(e: Dictionary, tijd: String) -> Control:
	var kaart := _kaart("chat", tr("HUB_TAG_QUICK_CHAT"), tijd)
	var wie: int = int(e.get("speler", -1))
	var rij := _rij(4)
	var links := VBoxContainer.new()
	links.mouse_filter = Control.MOUSE_FILTER_IGNORE
	links.add_theme_constant_override("separation", _px(2))
	var p := _portret(wie, 38)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	links.add_child(p)
	var naam := HubAssets.tekst(_naam(wie), _px(7), HubAssets.INKT)
	naam.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	naam.custom_minimum_size = Vector2(_u(62), 0)
	naam.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	links.add_child(naam)
	rij.add_child(links)
	rij.add_child(Ballon.new(String(e.get("tekst", "")), s, String(e.type) == "chat"))
	kaart.midden.add_child(rij)
	return kaart.wortel


# --- Bouwstenen ---------------------------------------------------------------------

## Een kaartje in opbouw: wortel (perkament), midden (de portretten) en zinnen.
class Kaart:
	var wortel: PanelContainer
	var midden: VBoxContainer
	var s: float

	func zin(tekst: String, grootte: float, kleur: Color = HubAssets.INKT) -> void:
		if tekst == "":
			return
		var l := HubAssets.tekst(tekst, int(round(grootte * s)), kleur)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		midden.add_child(l)


func _kaart(soort: String, tag: String, tijd: String) -> Kaart:
	var k := Kaart.new()
	k.s = s
	k.wortel = PanelContainer.new()
	k.wortel.name = "Feed_" + soort
	k.wortel.add_theme_stylebox_override("panel", HubAssets.patch(
		"frames_box/Timeline_action_box_%d" % (3 if soort == "chat" or soort == "systeem" else 1),
		Vector2(26, 26), Vector4(_u(12), _u(8), _u(12), _u(10))))
	var kolom := VBoxContainer.new()
	kolom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kolom.add_theme_constant_override("separation", _px(4))
	k.wortel.add_child(kolom)
	var kop := HBoxContainer.new()
	kop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kop.add_theme_constant_override("separation", _px(3))
	var klok := HubAssets.icoon("Time_icon", _u(11))
	klok.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kop.add_child(klok)
	var t := HubAssets.tekst(tijd, _px(7), HubAssets.INKT_ZACHT)
	t.name = "Tijd"
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	kop.add_child(t)
	kop.add_child(_lint(soort, tag))
	kolom.add_child(kop)
	k.midden = VBoxContainer.new()
	k.midden.mouse_filter = Control.MOUSE_FILTER_IGNORE
	k.midden.add_theme_constant_override("separation", _px(3))
	kolom.add_child(k.midden)
	return k


## Het lint rechtsboven: gekleurde holder met icoon en het soort in kapitalen.
func _lint(soort: String, tag: String) -> Control:
	var spec: Array = LINT.get(soort, LINT["systeem"])
	var lint := PanelContainer.new()
	var marge := Vector4(_u(5), _u(1), _u(6), _u(1))
	if spec[2] == Color.WHITE:
		lint.add_theme_stylebox_override("panel", HubAssets.patch(
			"frames_box/Timeline_title_holder_%d" % int(spec[0]), Vector2(12, 12), marge))
	else:
		# Geen asset in deze kleur (quick chat, groen): een effen lint.
		var sb := StyleBoxFlat.new()
		sb.bg_color = spec[2]
		sb.content_margin_left = marge.x
		sb.content_margin_top = marge.y
		sb.content_margin_right = marge.z
		sb.content_margin_bottom = marge.w
		lint.add_theme_stylebox_override("panel", sb)
	lint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lint.custom_minimum_size = Vector2(_u(98), _u(14))
	var rij := HBoxContainer.new()
	rij.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rij.add_theme_constant_override("separation", _px(4))
	lint.add_child(rij)
	var ic := HubAssets.icoon(String(spec[1]), _u(10), HubAssets.IVOOR)
	if String(spec[1]) == "Vote_icon":
		ic.custom_minimum_size = Vector2(_u(16), _u(10))
	rij.add_child(ic)
	var l := HubAssets.tekst(tag, _px(7), HubAssets.IVOOR, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rij.add_child(l)
	return lint


func _rij(tussen: float) -> HBoxContainer:
	var rij := HBoxContainer.new()
	rij.alignment = BoxContainer.ALIGNMENT_CENTER
	rij.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rij.add_theme_constant_override("separation", _px(tussen))
	return rij


func _pijl() -> Control:
	var p := HubAssets.icoon("Arrow_icon", _u(30))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


func _portret(sid: int, grootte: float) -> Control:
	var sp: Dictionary = c.spelers.get(sid, {})
	var p := HubAssets.portret(int(sp.get("doctrine", 0)), _team(sid) == mijn_team,
		String(sp.get("status", "actief")) != "actief", _u(grootte))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


## Portret (of schild) in de lauwerkrans van het Nomination-icoon.
func _in_krans(binnen: Control) -> Control:
	var houder := CenterContainer.new()
	houder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var krans := HubAssets.icoon("Nomination_icon", _u(76), HubAssets.INKT)
	houder.add_child(krans)
	binnen.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var midden := CenterContainer.new()
	midden.mouse_filter = Control.MOUSE_FILTER_IGNORE
	midden.custom_minimum_size = Vector2(_u(76), _u(76))
	midden.add_child(binnen)
	houder.add_child(midden)
	return houder


func _sierlijn(breedte: float) -> Control:
	var rij := _rij(2)
	var links := HubAssets.plaat("ornaments/Ornament_1")
	links.custom_minimum_size = Vector2(_u(breedte / 2.0), _u(6))
	rij.add_child(links)
	var rechts := HubAssets.plaat("ornaments/Ornament_1")
	rechts.custom_minimum_size = Vector2(_u(breedte / 2.0), _u(6))
	rechts.flip_h = true
	rij.add_child(rechts)
	return rij


## +N versterkingspunten of CP, met het medaille-icoon.
func _bedrag(punten: int, cp: int) -> Control:
	var rij := _rij(2)
	var ic := UiAssets.icoon_rect("cp" if punten == 0 else "pool", _u(18), HubAssets.INKT)
	rij.add_child(ic)
	var l := HubAssets.tekst("+%d" % (punten if punten > 0 else cp), _px(12), HubAssets.INKT, true)
	rij.add_child(l)
	return rij


func _team(sid: int) -> int:
	return int(c.spelers.get(sid, {}).get("team", -1))


func _kleur(sid: int) -> Color:
	return HubAssets.BLAUW if _team(sid) == mijn_team else HubAssets.ROOD


func _naam(sid: int) -> String:
	return String(c.spelers.get(sid, {}).get("naam", "?"))


func _methode(m: String) -> String:
	match m:
		"haven":
			return tr("HUB_METHOD_HARBOR")
		"eliminatie":
			return tr("HUB_METHOD_ELIMINATION")
		"resign":
			return tr("HUB_METHOD_RESIGN")
		"honger":
			return tr("HUB_METHOD_HUNGER")
	return m




## De tekstballon van een quick-chat-kaartje: perkament met inkt-rand en een
## punt naar links (naar het portret).
class Ballon:
	extends Control
	var _label: Label
	var _s: float

	func _init(tekst: String, p_s: float, luid: bool) -> void:
		_s = p_s
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label = HubAssets.tekst(tekst.to_upper() if luid else tekst,
			int(round((10.0 if luid else 8.0) * p_s)), HubAssets.INKT, luid)
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_label)

	func _get_minimum_size() -> Vector2:
		var m := _label.get_combined_minimum_size()
		return Vector2(_s * 60.0, m.y + _s * 18.0)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_label.position = Vector2(_s * 18.0, _s * 6.0)
			_label.size = Vector2(size.x - _s * 26.0, size.y - _s * 12.0)
			update_minimum_size()

	func _draw() -> void:
		var staart := _s * 10.0
		var r := Rect2(Vector2(staart, _s * 2.0), size - Vector2(staart + _s * 2.0, _s * 4.0))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#EFE2C4")
		sb.border_color = HubAssets.INKT
		sb.set_border_width_all(maxi(2, int(round(_s * 1.4))))
		sb.set_corner_radius_all(int(round(_s * 12.0)))
		draw_style_box(sb, r)
		var midden := r.position.y + r.size.y * 0.5
		var punt := PackedVector2Array([Vector2(0, midden), Vector2(staart + _s * 3.0, midden - _s * 6.0),
			Vector2(staart + _s * 3.0, midden + _s * 6.0)])
		draw_colored_polygon(punt, Color("#EFE2C4"))
		draw_polyline(PackedVector2Array([punt[1], punt[0], punt[2]]), HubAssets.INKT, maxf(2.0, _s * 1.4), true)

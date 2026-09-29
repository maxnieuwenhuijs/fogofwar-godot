extends RefCounted

## De spelregels van de campagne als kaarten met iconen (29 september, Max:
## "schrijf alles op ook in een UI conforme spelregel scherm", "simpele taal en
## zo weinig mogelijk tekst", "en iconen wel gebruiken"). Per onderdeel een
## perkamenten kaart; per regel een icoon en een korte zin, of een label met
## icoon-getal-paren. De getallen komen uit de regels van DEZE campagne (CRules)
## en de duelregels van de campagne (RulesConfig.CAMPAIGN_DEFAULTS), dus het
## scherm loopt niet uit de pas met het spel.
##
## Iconen: "hub:<naam>" uit assets/ui/campaign_hub/icons, "ui:<id>" uit het
## UI-pack (UiAssets), "" = een lege plek van dezelfde breedte.

const _Punten := preload("res://core/campaign/puntentabel.gd")

const ICOON := 17.0
const LABEL_BREED := 168.0
## Lettermaten (ontwerp-eenheden): een tik groter dan de rest van de hub, want
## hier lees je (29 september, Max: "niet echt leesbaar").
const KOP := 13.0
const TEKST := 11.0
const GETAL := 12.0

var _s: float
var _r: CRules
var _d: Dictionary = RulesConfig.CAMPAIGN_DEFAULTS


func _init(regels: CRules, schaal: float) -> void:
	_r = regels
	_s = schaal


func _u(v: float) -> float:
	return v * _s


func _px(v: float) -> int:
	return int(round(v * _s))


## Alle kaarten onder elkaar, in de volgorde waarin je ze nodig hebt.
func bouw() -> VBoxContainer:
	var lijst := VBoxContainer.new()
	lijst.name = "Regels"
	lijst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lijst.add_theme_constant_override("separation", _px(10))

	var k := _kaart(lijst, "Doel", "ui:win-harbor", tr("HUB_RULE_DOEL_KOP"))
	_regel(k, "hub:Battle_report_team_full", tr("HUB_RULE_TEAMS") % _r.team_size)
	_regel(k, "ui:win-harbor", tr("HUB_RULE_KAMPIOEN"))

	k = _kaart(lijst, "Bezit", "ui:pool", tr("HUB_RULE_BEZIT_KOP"))
	_regel(k, "hub:Donation_icon", tr("HUB_RULE_VERSTERKING"))
	_regel(k, "ui:cp", tr("HUB_RULE_CP"))
	_regel(k, "ui:score", tr("HUB_RULE_ROEM"))
	_regel(k, "ui:hidden", tr("HUB_RULE_VERBORGEN"))

	k = _kaart(lijst, "Ronde", "hub:Phase_icon", tr("HUB_RULE_RONDE_KOP"))
	_regel(k, "hub:Nomination_icon", tr("HUB_RULE_RAAD"), tr("HUB_PHASE_SHORT_NOMINATION"))
	_regel(k, "hub:Donation_icon", tr("HUB_RULE_DONATIE"), tr("HUB_PHASE_SHORT_DONATION"))
	_regel(k, "hub:Inbattle_icon", tr("HUB_RULE_DUELS"), tr("HUB_PHASE_SHORT_DUELS"))
	_regel(k, "hub:Testament_icon", tr("HUB_RULE_TESTAMENT"), tr("HUB_PHASE_SHORT_TESTAMENT"))
	_regel(k, "hub:Time_icon", tr("HUB_RULE_RONDE1"))

	k = _kaart(lijst, "Doneren", "hub:Donation_icon", tr("HUB_RULE_DONEER_KOP"))
	_waarden(k, "", tr("HUB_RULE_PER_RONDE"), [
		["hub:Donation_icon", str(_r.donatie_cap_pionnen)], ["ui:cp", str(_r.donatie_cap_cp)]])
	_waarden(k, "", tr("HUB_RULE_RUIL"), [
		["ui:cp", str(maxi(1, _r.ruil_cp_per_punt))], ["hub:Arrow_icon", ""], ["hub:Donation_icon", "1"]])
	_regel(k, "ui:alive", tr("HUB_RULE_ALLEEN_LEVENDEN"))

	k = _kaart(lijst, "Duel", "hub:Inbattle_icon", tr("HUB_RULE_DUEL_KOP"))
	_regel(k, "hub:Battle_report_team_full", tr("HUB_RULE_LEGER"))
	_regel(k, "ui:spawn", tr("HUB_RULE_MEE") % _r.duel_spawn_totaal_max)
	_waarden(k, "", tr("HUB_RULE_VAANDEL"), [["hub:Donation_icon", "+%d" % int(_d.get("buit_vaandel_pt", 0))]])
	_waarden(k, "", tr("HUB_RULE_TROM"), [["ui:cp", "+%d" % int(_d.get("buit_tamboer_cp", 0))]])
	_waarden(k, "hub:Active_icon", tr("HUB_RULE_HAVEN"), [
		["ui:score", "+%d" % _r.punten_haven], ["ui:cp", "+%d" % int(_d.get("cp_haven", 0))]])
	_waarden(k, "ui:act-melee", tr("HUB_RULE_UITSCHAKELEN"), [
		["ui:score", "+%d" % _r.punten_eliminatie], ["ui:cp", "+%d" % int(_d.get("cp_eliminatie", 0))]])
	_waarden(k, "ui:forfeit", tr("HUB_RULE_VERLIES"), [["ui:score", str(_r.punten_verlies)]])

	k = _kaart(lijst, "Vallen", "hub:Dead_icon", tr("HUB_RULE_VAL_KOP"))
	_regel(k, "hub:Dead_icon", tr("HUB_RULE_ERUIT"))
	_regel(k, "hub:Testament_icon", tr("HUB_RULE_NALATEN") % _r.testament_ontvangers_max)
	_regel(k, "hub:Close_icon", tr("HUB_RULE_VERBRANDT"))
	_regel(k, "ui:dead", tr("HUB_RULE_STIL"))
	_regel(k, "ui:hidden", tr("HUB_RULE_ALLES_ZIEN"))

	k = _kaart(lijst, "Burgeroorlog", "hub:Inbattle_icon", tr("HUB_PHASE_SHORT_CIVIL_WAR"))
	_regel(k, "hub:Inbattle_icon", tr("HUB_RULE_OORLOG"))
	_regel(k, "ui:score", tr("HUB_RULE_TEAMBONUS") % _r.punten_teambonus)
	_regel(k, "hub:Dead_icon", tr("HUB_RULE_KNOCKOUT"))
	_regel(k, "hub:Nomination_icon", tr("HUB_RULE_SEED"))

	# F6.0: de punten, rechtstreeks uit de puntentabel.
	var t: Dictionary = _Punten.TABEL
	k = _kaart(lijst, "Punten", "ui:win-harbor", tr("HUB_RULE_PUNTEN_KOP"))
	_waarden(k, "hub:Battle_report_team_full", tr("HUB_RULE_PT_TEAM"), [
		["ui:win-harbor", "+%d" % int(t.team)], ["", tr("HUB_RULE_PT_OOK_DOOD")]])
	_waarden(k, "ui:win-harbor", tr("HUB_RULE_PT_KAMPIOEN"), [["ui:win-harbor", "+%d" % int(t.kampioen)]])
	_waarden(k, "hub:Inbattle_icon", tr("HUB_RULE_PT_FINALE"), [
		["ui:win-harbor", "+%d" % int(t.finale)], ["", "/"], ["ui:win-harbor", "+%d" % int(t.halve)]])
	_waarden(k, "ui:score", tr("HUB_RULE_PT_ROEM"), [["ui:win-harbor", "+%d" % int(t.per_roem)]])
	_waarden(k, "ui:act-melee", tr("HUB_RULE_PT_STUNT"), [["ui:win-harbor", "+%d" % int(t.stunt)]])
	_waarden(k, "hub:WellPlayed_icon", tr("HUB_RULE_PT_DANK"), [["ui:win-harbor", "+%d" % int(t.dank)]])
	_waarden(k, "hub:Testament_icon", tr("HUB_RULE_PT_KONINGSMAKER"), [
		["ui:win-harbor", "+%d" % int(t.koningsmaker)]])
	_regel(k, "ui:hidden", tr("HUB_RULE_PT_SOLO"))

	k = _kaart(lijst, "Chat", "hub:Chat_icon", tr("HUB_QUICK_CHAT"))
	_regel(k, "hub:Chat_icon", tr("HUB_RULE_CHAT_TEAM"))
	_regel(k, "ui:check", tr("HUB_RULE_CHAT_AKKOORD"))
	return lijst


## Een perkamenten kaart met icoon en kop; geeft de kolom voor de regels terug.
func _kaart(ouder: Control, naam: String, icoon: String, titel: String) -> VBoxContainer:
	var kaart := PanelContainer.new()
	kaart.name = "Regelkaart_" + naam
	kaart.add_theme_stylebox_override("panel", HubAssets.patch("frames_box/Timeline_action_box_2",
		Vector2(26, 26), Vector4(_u(16), _u(12), _u(16), _u(14))))
	ouder.add_child(kaart)
	var binnen := VBoxContainer.new()
	binnen.add_theme_constant_override("separation", _px(6))
	kaart.add_child(binnen)
	var kop := HBoxContainer.new()
	kop.add_theme_constant_override("separation", _px(8))
	kop.add_child(_icoon(icoon, 22.0))
	var t := HubAssets.tekst(titel, _px(KOP), HubAssets.INKT, true)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	kop.add_child(t)
	binnen.add_child(kop)
	return binnen


## Een regel: icoon, optioneel een vet kopwoord, en een korte zin.
func _regel(kaart: VBoxContainer, icoon: String, tekst: String, kop: String = "") -> void:
	var rij := HBoxContainer.new()
	rij.add_theme_constant_override("separation", _px(8))
	rij.add_child(_icoon(icoon, ICOON))
	if kop != "":
		var b := HubAssets.tekst(kop, _px(TEKST), HubAssets.INKT, true)
		b.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rij.add_child(b)
	var l := HubAssets.tekst(tekst, _px(TEKST), HubAssets.INKT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rij.add_child(l)
	kaart.add_child(rij)


## Een regel met getallen: icoon, een label van vaste breedte (zodat de
## getallen onder elkaar staan) en paren [icoon, tekst]. Een paar zonder
## icoon is een zacht woordje ("vaandel"), een paar met icoon een vet getal.
func _waarden(kaart: VBoxContainer, icoon: String, label: String, paren: Array) -> void:
	var rij := HBoxContainer.new()
	rij.add_theme_constant_override("separation", _px(8))
	rij.add_child(_icoon(icoon, ICOON))
	var l := HubAssets.tekst(label, _px(TEKST), HubAssets.INKT)
	l.custom_minimum_size = Vector2(_u(LABEL_BREED), 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rij.add_child(l)
	for paar in paren:
		var p_icoon: String = String(paar[0])
		var p_tekst: String = String(paar[1])
		var stuk := HBoxContainer.new()
		stuk.add_theme_constant_override("separation", _px(3))
		if p_icoon == "":
			var woord := HubAssets.tekst(p_tekst, _px(TEKST - 1.0), HubAssets.INKT_ZACHT)
			woord.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			stuk.add_child(woord)
		else:
			stuk.add_child(_icoon(p_icoon, ICOON))
			if p_tekst != "":
				var getal := HubAssets.tekst(p_tekst, _px(GETAL), HubAssets.INKT, true)
				getal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				stuk.add_child(getal)
		rij.add_child(stuk)
	kaart.add_child(rij)


## Icoon in inkt, of een lege plek van dezelfde maat.
func _icoon(naam: String, maat: float) -> Control:
	var ic: Control
	if naam.begins_with("hub:"):
		ic = HubAssets.icoon(naam.substr(4), _u(maat), HubAssets.INKT)
	elif naam.begins_with("ui:"):
		ic = UiAssets.icoon_rect(naam.substr(3), _u(maat), HubAssets.INKT)
	else:
		ic = Control.new()
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.custom_minimum_size = Vector2(_u(maat), _u(maat))
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return ic

extends RefCounted

## Screenshot-fixture van de campagne-hub in elke toestand (27 september,
## Max: "kijk nog eens kritisch naar de hele ui campagne"). Aangeroepen vanuit
## `-- shot campaign_hub [seed] [modus] [orakel=<pad>]` in tools/capture.gd.
##
## Modi: "" (ronde 1, jouw duel), raad, donatie, testament, burgeroorlog,
## einde, chat, popup (quick chat), doel (Stuur wie?), lid, rapport, help,
## instellingen, grootboek, paren (de andere paren van de ronde), factie, hervat,
## laden.
## Met orakel=<pad> (een duel_orakel.json) spoelt de campagne in seconden
## door; zonder orakel spelen de bots echte duels (minuten per ronde).
## Voor de plaatjes zet de fixture soms de staat recht (de mens weer levend
## met wat voorraad, zijn team aan de beurt): die staat wordt nooit bewaard.
## Burgeroorlog zoekt vanaf de seed de eerste campagne die er een haalt.
##
## Schrijft res://_shot_hub_<modus>.png (met venster) en geeft het aantal
## fouten terug (ontbrekende nodes, lege tijdlijn, quick chat die niet landt).

const HUB := "res://scripts/ui/campaign/campaign_hub.gd"
const ORAKEL := "res://scripts/training/duel_orakel.gd"


static func run(host: Node, seed_val: int, modus: String, orakel_pad: String) -> int:
	var fouten := 0
	var hub: Control = load(HUB).new()
	if modus == "factie" or modus == "hervat":
		host.add_child(hub)
		await host.get_tree().process_frame
		for kind in hub.get_children():
			hub.remove_child(kind)
			kind.queue_free()
		if modus == "factie":
			hub.call("_toon_factie_keuze")
		else:
			hub.call("_toon_hervat_keuze", SoloDriver.new(seed_val, 0))
		await host.get_tree().create_timer(0.8).timeout
		return await _bewaar(host, modus, fouten)
	var driver := _nieuwe_driver(seed_val, orakel_pad)
	_spoel_door(driver, modus)
	if modus == "burgeroorlog":
		# Een burgeroorlog waarin jij nog meedoet: anders spelen de bots hem uit
		# voordat het plaatje er is.
		var poging := 1
		while not (driver.c.fase == CState.Fase.BURGEROORLOG and driver.wacht_op_mens()) and poging < 60:
			driver = _nieuwe_driver(seed_val + poging, orakel_pad)
			_spoel_door(driver, modus)
			poging += 1
		if driver.c.fase != CState.Fase.BURGEROORLOG:
			fouten += 1
			print("[SHOT] geen burgeroorlog met de mens erin gevonden in 60 seeds vanaf %d" % seed_val)
		else:
			print("[SHOT] burgeroorlog met seed %d" % (seed_val + poging - 1))
	hub.driver = driver
	hub.mens_id = 0
	host.add_child(hub)
	await host.get_tree().create_timer(1.2).timeout
	for node_naam in ["HubFrame", "Header", "Titel", "Vlag", "Tijdlijn", "FasePaneel", "FaseVoet",
			"GrootboekKnop", "TeamLinks", "TeamRechts", "TabFase", "TabChat", "QC_Meer",
			"HelpKnop", "InstellingenKnop"]:
		if hub.find_child(node_naam, true, false) == null:
			fouten += 1
			print("[SHOT] node ontbreekt: %s" % node_naam)
	var kop: Label = hub.find_child("Header", true, false)
	if kop == null or not kop.text.contains(hub.tr("HUB_SUBTITLE").split("%d")[0].strip_edges()):
		fouten += 1
		print("[SHOT] header toont geen ronde/round")
	for kolom_naam in ["TeamLinks", "TeamRechts"]:
		var tk: VBoxContainer = hub.find_child(kolom_naam, true, false)
		if tk == null or tk.get_child_count() < 8:
			fouten += 1
			print("[SHOT] %s mist teamleden (8)" % kolom_naam)
	var tl: VBoxContainer = hub.find_child("Tijdlijn", true, false).get_child(0)
	if tl.get_child_count() < 1:
		fouten += 1
		print("[SHOT] tijdlijn is leeg")
	# De hoofdknop van de fase staat in de voet, dus altijd in beeld.
	var voet_knop := {"": "SpeelDuelKnop", "raad": "", "donatie": "KlaarKnop", "testament": "NalatenKnop",
		"einde": "NieuweCampagneKnop"}
	if voet_knop.has(modus) and String(voet_knop[modus]) != "":
		var voet: Control = hub.find_child("FaseVoet", true, false)
		if voet == null or voet.find_child(String(voet_knop[modus]), true, false) == null:
			fouten += 1
			print("[SHOT] %s staat niet in de voet" % voet_knop[modus])
	if modus in ["", "chat", "popup", "raad", "donatie"] and String(driver.c.spelers[0].status) == "actief":
		# Quick chat: een bericht moet in de tijdlijn (en het chat-tabblad) landen.
		var tl_voor := tl.get_child_count()
		hub.call("_stuur_chat", "HUB_QC_VERTROUW", -1)
		await host.get_tree().create_timer(0.3).timeout
		if tl.get_child_count() <= tl_voor and not bool(hub.get("_bezig")):
			fouten += 1
			print("[SHOT] quick chat kwam niet in de tijdlijn")
	match modus:
		"chat":
			(hub.find_child("TabChat", true, false) as Button).pressed.emit()
		"popup":
			(hub.find_child("QC_Meer", true, false) as Button).pressed.emit()
		"doel":
			hub.call("_kies_doel", "HUB_QC_STUUR", "team")
		"lid":
			hub.call("_toon_lid", _eerste_vijand(driver))
		"rapport":
			var rapport := {}
			for e in driver.feed:
				if String(e.get("type", "")) == "report":
					rapport = e
			if rapport.is_empty():
				fouten += 1
				print("[SHOT] geen slagrapport om te tonen (speel door met modus raad)")
			else:
				hub.call("_toon_report", rapport)
		"help":
			hub.call("_toon_help")
		"instellingen":
			hub.call("_toon_instellingen")
		"grootboek":
			hub.call("_toon_grootboek")
		"paren":
			hub.call("_toon_paren")
		"laden":
			hub.call("_toon_lader", _eerste_vijand(driver))
	await host.get_tree().create_timer(0.8).timeout
	return await _bewaar(host, modus, fouten)


static func _nieuwe_driver(seed_val: int, orakel_pad: String) -> SoloDriver:
	var driver := SoloDriver.new(seed_val, 0)
	driver.duel_ai = "easy"
	if orakel_pad != "":
		var o = load(ORAKEL).laad(orakel_pad)
		if o != null:
			driver.orakel = o
			driver.duel_modus = "orakel"
	return driver


## Speel de campagne door tot de gevraagde toestand. De mens stemt op een
## teamgenoot (niet zichzelf), geeft niets en laat niets na; zijn eigen duel
## speelt de driver (echt of via het orakel).
static func _spoel_door(driver: SoloDriver, modus: String) -> void:
	var doel := {"raad": CState.Fase.NOMINATIE, "donatie": CState.Fase.DONATIE,
		"rapport": CState.Fase.NOMINATIE, "lid": CState.Fase.NOMINATIE,
		"doel": CState.Fase.NOMINATIE, "testament": CState.Fase.DONATIE}
	if not doel.has(modus) and not (modus in ["burgeroorlog", "einde"]):
		return
	var guard := 0
	while guard < 2000 and driver.c.fase != CState.Fase.KLAAR:
		guard += 1
		var c: CState = driver.c
		if modus == "burgeroorlog" and c.fase == CState.Fase.BURGEROORLOG:
			break
		if doel.has(modus) and c.ronde >= 2 and c.fase == doel[modus]:
			if modus == "testament":
				# Voor het plaatje: de mens is net gevallen en mag nalaten.
				c.spelers[0].status = "uitgevallen"
				if not c.pending_testamenten.has(0):
					c.pending_testamenten.append(0)
				c.fase = CState.Fase.TESTAMENT
				c._boek("fixture", 0, 6, 2, 1, 6, 0)
				break
			if c.fase == CState.Fase.NOMINATIE and c.nominatie_stemmen.is_empty():
				c.spelers[0].status = "actief"
				c.al_genomineerd.erase(0)
				c.nominatie_team = int(c.spelers[0].team)
				break
			if c.fase == CState.Fase.DONATIE:
				c.spelers[0].status = "actief"
				c.donatie_klaar.erase(0)
				# Wat voorraad, anders staan alle plusjes uit op het plaatje.
				c._boek("fixture", 0, 5, 1, 0, 4, 0)
				break
		if driver.wacht_op_mens():
			match c.fase:
				CState.Fase.NOMINATIE:
					var eigen: Array = c.actieve_leden(int(c.spelers[0].team))
					var vijand: Array = c.actieve_leden(1 - int(c.spelers[0].team))
					var kies_eigen: int = int(eigen[eigen.size() - 1])
					for sid in eigen:
						if not c.al_genomineerd.has(sid):
							kies_eigen = int(sid)
					var kies_vijand: int = int(vijand[0])
					for sid in vijand:
						if not c.al_genomineerd.has(sid):
							kies_vijand = int(sid)
							break
					if not driver.submit_mens_nominatie(kies_eigen, kies_vijand):
						driver.submit_mens_nominatie(0, kies_vijand)
				CState.Fase.DONATIE:
					driver.submit_mens_klaar_met_doneren()
				CState.Fase.TESTAMENT:
					driver.submit_mens_testament([])
				_:
					var md: Dictionary = driver.mens_duel()
					driver.call("_speel_duel", int(md.idx), int(md.p1), int(md.p2))
		else:
			driver.stap()
	print("[SHOT] doorgespeeld tot ronde %d, fase %d" % [driver.c.ronde, driver.c.fase])


static func _eerste_vijand(driver: SoloDriver) -> int:
	var team: int = int(driver.c.spelers[0].team)
	for sid in driver.c.spelers:
		if int(driver.c.spelers[sid].team) != team:
			return int(sid)
	return 1


static func _bewaar(host: Node, modus: String, fouten: int) -> int:
	var tex := host.get_viewport().get_texture()
	var naam := "res://_shot_hub_%s.png" % (modus if modus != "" else "basis")
	if tex != null and tex.get_image() != null:
		tex.get_image().save_png(naam)
		print("[SHOT] screenshot -> %s" % naam.get_file())
	else:
		print("[SHOT] headless: geen viewport-texture, screenshot overgeslagen")
	return fouten

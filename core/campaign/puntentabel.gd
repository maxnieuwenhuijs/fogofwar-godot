extends RefCounted

## F6.0-P1 (29 september): punten uit de uitslag (uitslag.gd), per speler een
## lijst regels [reden, bedrag] en een totaal. Tabel v1 uit
## docs/F6-punten-masterplan.md §2. De tabel draagt een versie: elke campagne
## bewaart de zijne, dus een nieuwe tabel volgend seizoen herschrijft geen oude
## uitslagen. Aanspreken via preload (geen class_name).

const VERSIE := 1
const TABEL := {
	"uitgespeeld": 5,
	"team": 20,
	"per_roem": 1,
	"kampioen": 40,
	"finale": 20,
	"halve": 10,
	"eerder": 5,
	"stunt": 5,
	"laatste_stand": 5,
	"dank": 10,
	"koningsmaker": 5,
}

## Alle redenen in de volgorde van het eindscherm.
const REDENEN := ["uitgespeeld", "team", "roem", "kampioen", "finale", "halve", "eerder",
	"stunt", "laatste_stand", "dank", "koningsmaker"]

## Badges voor één seizoen (plan §4): speels, nooit een schandpaal.
const BADGES := ["kroonprins", "koningsmaker", "sluipschutter", "laatste_man", "dubbelspel"]


## De punten per speler: {id: {"totaal": n, "regels": [[reden, bedrag], ...]}}.
## `tabel` mag een deel van TABEL overschrijven (P4 meet andere tabellen).
## `opties`: {"vertrokken": [ids], "bots": [ids]}: die krijgen 0. Is de
## kampioen een bot, dan vervalt de kroonpot; de rest houdt zijn plek.
static func bereken(uitslag: Dictionary, tabel: Dictionary = {}, opties: Dictionary = {}) -> Dictionary:
	var t: Dictionary = TABEL.duplicate()
	for k in tabel:
		t[k] = int(tabel[k])
	var nul: Array = []
	for id in opties.get("vertrokken", []):
		nul.append(int(id))
	for id in opties.get("bots", []):
		nul.append(int(id))
	var uit: Dictionary = {}
	for sid in uitslag:
		var id: int = int(sid)
		if nul.has(id):
			uit[id] = {"totaal": 0, "regels": []}
			continue
		var u: Dictionary = uitslag[sid]
		var regels: Array = [["uitgespeeld", int(t.uitgespeeld)]]
		if bool(u.team_won):
			regels.append(["team", int(t.team)])
		if int(u.roem) > 0:
			regels.append(["roem", int(u.roem) * int(t.per_roem)])
		var over: int = int(u.burgeroorlog_over)
		if over == 1:
			regels.append(["kampioen", int(t.kampioen)])
		elif over == 2:
			regels.append(["finale", int(t.finale)])
		elif over == 3 or over == 4:
			regels.append(["halve", int(t.halve)])
		elif over >= 5:
			regels.append(["eerder", int(t.eerder)])
		if int(u.stunts) > 0:
			regels.append(["stunt", int(u.stunts) * int(t.stunt)])
		if bool(u.laatste_stand):
			regels.append(["laatste_stand", int(t.laatste_stand)])
		if bool(u.dank):
			regels.append(["dank", int(t.dank)])
		if bool(u.koningsmaker):
			regels.append(["koningsmaker", int(t.koningsmaker)])
		var totaal: int = 0
		for regel in regels:
			totaal += int(regel[1])
		uit[id] = {"totaal": totaal, "regels": regels}
	return uit


## De badges van één speler uit zijn uitslag.
static func badges(u: Dictionary) -> Array:
	var uit: Array = []
	if int(u.get("burgeroorlog_over", 0)) == 2:
		uit.append("kroonprins")
	if bool(u.get("koningsmaker", false)):
		uit.append("koningsmaker")
	if int(u.get("stunts", 0)) > 0:
		uit.append("sluipschutter")
	if bool(u.get("laatste_stand", false)):
		uit.append("laatste_man")
	if bool(u.get("testament_vijand", false)):
		uit.append("dubbelspel")
	return uit

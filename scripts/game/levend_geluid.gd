extends Node
## Leven op het bord: de geluiden uit de geluid-studio die het spel tot leven
## brengen (13 oktober, Max: "wat zijn nog meer geluid en of vfx details die de
## game nog meer tot leven brengen... van geritsel van uniforms tot ambient
## sounds en echos", en op het inbouwen: "helemaal goed"). SOUND-WISHLIST
## secties 12-18 plus de stemmen per factie (STEMMEN in
## tools/maak_geluid_prompts.py).
##
## Alles klinkt alleen als er een opname ligt (Audio.play_detail en
## Audio.play_stem doen anders niets): zet je in de studio een take in het
## spel, dan hoor je hem bij de volgende start meteen op zijn moment. Kansen,
## varianten en tonen komen uit een EIGEN rng: de globale is van de partij
## (-- uispel).
##
## game.gd roept de momenten aan (bij_actie, bij_melee, bij_schot,
## bij_treffer, bij_dood, bij_selectie, haven, verdwenen, beurtlicht, sps);
## de rest (sfeerlaag per diorama, kampvuur, accenten in de verte, vlag, trom,
## vliegen, wind, regen, de dreiging bij je haven) regelt _process zelf.
## Knoppen in het sfeer-paneel: leven_geluid (0 = alles uit), leven_accenten
## (gemiddelde seconden tussen twee accenten, 0 = geen), leven_stemmen (kans
## op juichen, schrikken en een bevelroep), oor_suis_kans, weer_regen_kans.

## de twaalf diorama's in de volgorde van Omgeving.DIORAMAS
const DIORAMA_SLEUTEL: Array = ["weidekamp", "boerenerf", "dorpsrand", "na_de_slag", "winterkamp",
	"rivierhaven", "bosrand", "kapelruine", "marktplein", "egypte", "alpenpas", "waterloo"]
## accenten in de verte; per diorama een eigen mengsel (geen kerkklok in Egypte)
const ACCENTEN: Array = ["ver_kanon", "ver_trom", "ver_hond", "ver_bijl", "ver_hoorn", "ver_vogels",
	"ver_kraai", "ver_kamp", "ver_donder"]
const ACCENTEN_PER: Dictionary = {
	"dorpsrand": ["ver_klok", "ver_hond", "ver_bijl", "ver_vogels", "ver_kraai", "ver_kamp", "ver_trom", "ver_kanon"],
	"kapelruine": ["ver_klok", "ver_kraai", "ver_donder", "ver_kanon", "ver_trom", "ver_hond"],
	"marktplein": ["ver_klok", "ver_hond", "ver_vogels", "ver_kamp", "ver_trom", "ver_hoorn"],
	"waterloo": ["ver_klok", "ver_trom", "ver_kanon", "ver_hoorn", "ver_hond", "ver_donder", "ver_kraai"],
	"boerenerf": ["ver_klok", "ver_hond", "ver_bijl", "ver_vogels", "ver_kraai", "ver_kamp", "ver_kanon"],
	"na_de_slag": ["ver_kraai", "ver_kanon", "ver_donder", "ver_trom", "ver_hond"],
	"egypte": ["ver_kanon", "ver_trom", "ver_hoorn", "ver_vogels", "ver_kamp"],
	"winterkamp": ["ver_kraai", "ver_kanon", "ver_trom", "ver_hoorn", "ver_kamp", "ver_hond", "ver_bijl"],
	"alpenpas": ["ver_kraai", "ver_kanon", "ver_hoorn", "ver_donder", "ver_trom"],
}

var game: Node = null
var laatste: Array = []   # de laatste geluiden die klonken (voor de checks): [categorie, vertraging]
var _rng := RandomNumberGenerator.new()
var _diorama := -1
var _t_check := 0.0
var _t_accent := 10.0
var _t_vlag := 12.0
var _t_trom := 18.0
var _t_vlieg := 20.0
var _t_wind := 45.0
var _t_onweer := 60.0
var _regen := false
var _haven_dreig := false
var _beurtlicht_aan := false
var _sps_gezien := ""
var _cyclus := -1
var _trom_vorig: Dictionary = {}     # pion -> trom_gebruikt bij de vorige blik
var _vaandel_vorig: Dictionary = {}  # pion -> stond in het blok om een eigen vaandel


func _init() -> void:
	_rng.seed = 13102027


static func aan() -> bool:
	return PawnView.fx("leven_geluid", 1.0) > 0.0


func _speel(cat: String, vertraging: float = 0.0, extra_db: float = 0.0) -> void:
	if Audio.play_detail(cat, vertraging, extra_db):
		_onthoud(cat, vertraging)


func _stem(cat: String, doctrine: int, vertraging: float = 0.0, extra_db: float = 0.0) -> void:
	if Audio.play_stem(cat, doctrine, vertraging, extra_db):
		_onthoud("%s_%s" % [cat, Constants.doctrine_folder(doctrine)], vertraging)


func _onthoud(cat: String, vertraging: float) -> void:
	laatste.append([cat, vertraging])
	if laatste.size() > 40:
		laatste.pop_front()


func _state() -> GameState:
	if game == null or game.session == null:
		return null
	return game.session.state


func _stem_kans() -> float:
	return clampf(PawnView.fx("leven_stemmen", 0.5), 0.0, 1.0)


## Het kleine broertje of de big bro: de stem heet dan cav_<stem>.
static func _stemnaam(stem: String, pawn: Pawn) -> String:
	return ("cav_" + stem) if pawn.unit_type == Constants.UnitType.CAVALRY else stem


# --- Momenten uit game.gd ----------------------------------------------------

## Elke actie (bovenaan _on_action_performed, de staat is al bijgewerkt).
func bij_actie(action: Dictionary, result: Dictionary) -> void:
	var st := _state()
	if st == null or not aan():
		return
	var soort := String(action.get("type", ""))
	if soort == "move" or soort == "wolf_step" or soort == "charge":
		var p: Pawn = st.pawns.get(int(action.get("pawn_id", -1)))
		if p != null and not p.is_eliminated:
			if soort != "charge":
				match p.unit_type:
					Constants.UnitType.INFANTRY:
						_speel("uitrusting_rammel")
					Constants.UnitType.CAVALRY:
						_speel("harnas_kraak")
				# een gewonde bloedt na terwijl hij loopt
				if p.unit_type != Constants.UnitType.ARTILLERY and p.current_hp < p.max_hp:
					_speel("bloed_drup", 0.2)
			# in het blok om een eigen vaandel gestapt: het doek wappert op
			var in_aura: bool = Rules.aura_bonus(st, p, "flag") > 0
			if in_aura and not bool(_vaandel_vorig.get(p.id, false)):
				_speel("aura_vaandel", 0.25 if soort == "move" else 0.1)
			_vaandel_vorig[p.id] = in_aura
	# iemand betaalde van de trom (Pawn.trom_gebruikt sprong aan): een slag
	var trom := false
	for p in st.pawns.values():
		var nu := bool(p.trom_gebruikt)
		if nu and not bool(_trom_vorig.get(p.id, false)):
			trom = true
		_trom_vorig[p.id] = nu
	if trom:
		_speel("aura_trom", 0.05)


## Een melee-aanval (bajonet of charge): de bajonet klikt vast of de sabel
## komt uit de schede, en wie het overleeft hijgt daarna even.
func bij_melee(aanvaller_id: int, klap_del: float, aanvaller_dood: bool) -> void:
	var st := _state()
	if st == null or not aan():
		return
	var p: Pawn = st.pawns.get(aanvaller_id)
	if p == null:
		return
	var doc: int = st.doctrine_of(p.owner_id)
	if p.unit_type == Constants.UnitType.INFANTRY:
		_speel("bajonet_op", maxf(klap_del - 0.45, 0.0))
	elif p.unit_type == Constants.UnitType.CAVALRY:
		var pv: PawnView = game._pawn_views.get(aanvaller_id)
		var arch: String = pv.archetype() if pv != null else ""
		if PawnView.melee_wapen(p.unit_type, arch, doc) == "sabel":
			_speel("sabel_trek")
	if not aanvaller_dood and p.unit_type != Constants.UnitType.ARTILLERY:
		_stem(_stemnaam("hijg", p), doc, klap_del + 1.1)


## Een schot: het herladen na het musket en de kogel die langs zoeft; bij het
## kanon de terugloop, de echo door het dal, de aarde die neerregent, de kogel
## die uitrolt en de wisser in de hete loop.
func bij_schot(schutter_id: int, soort: int, wacht: float, reistijd: float) -> void:
	if not aan():
		return
	if soort == Constants.UnitType.ARTILLERY:
		_speel("kanon_terugloop", wacht + 0.05)
		_speel("cannon_echo", wacht + 0.45)
		_speel("aarde_regen", wacht + reistijd + 0.25)
		_speel("kogel_rol", wacht + reistijd + 0.5)
		_speel("kanon_wissen", wacht + 2.4)
	else:
		if reistijd >= 0.12:
			_speel("kogel_zip", reistijd * 0.45)
		_speel("patroon_bijt", 1.0, -2.0)
		_speel("kruit_pan", 1.5, -2.0)
		_speel("laadstok", 2.0, -2.0)


## Geraakt en overleefd (in _hit_feedback, al op het moment van de klap).
func bij_treffer(pawn_id: int) -> void:
	var st := _state()
	if st == null or not aan():
		return
	var p: Pawn = st.pawns.get(pawn_id)
	if p == null or p.unit_type == Constants.UnitType.ARTILLERY:
		return
	_stem(_stemnaam("pijn_kreun", p), st.doctrine_of(p.owner_id), 0.05)


## Een dode (bovenaan _death_sound, `vertraging` = het moment van de dood).
func bij_dood(pawn_id: int, vertraging: float, kanon: bool) -> void:
	var st := _state()
	if st == null or not aan():
		return
	var p: Pawn = st.pawns.get(pawn_id)
	if p == null:
		return
	var doc: int = st.doctrine_of(p.owner_id)
	if p.unit_type == Constants.UnitType.ARTILLERY:
		_speel("splinter_regen", vertraging + 0.35)
		_speel("metaal_tinkel", vertraging + 0.6)
		_speel("wrak_knetter", vertraging + 0.9)
	else:
		_stem(_stemnaam("dood_zucht", p), doc, vertraging + 1.3)
		if kanon:
			for i in 3:
				_speel("gib_plets", vertraging + 0.45 + 0.18 * float(i) + _rng.randf_range(0.0, 0.1))
			if _rng.randf() < clampf(PawnView.fx("oor_suis_kans", 0.25), 0.0, 1.0):
				_speel("oor_suis", vertraging + 0.05)
	# de buit: vaandel of trom van de vijand (C15, alleen met het campagne-blok)
	if st.rules.campaign_actief():
		if String(p.rol) == "flag" and int(st.rules.campaign.get("buit_vaandel_pt", 0)) > 0:
			_speel("buit_vaandel", vertraging + 0.8)
		elif String(p.rol) == "drum" and int(st.rules.campaign.get("buit_tamboer_cp", 0)) > 0:
			_speel("buit_trom", vertraging + 0.8)
	# de anderen: de vijand juicht kort, een kameraad ernaast schrikt
	var vijand: int = Constants.PLAYER_2 if p.owner_id == Constants.PLAYER_1 else Constants.PLAYER_1
	if _rng.randf() < _stem_kans():
		_stem("juich_klein", st.doctrine_of(vijand), vertraging + 0.7)
	if _rng.randf() < _stem_kans():
		for q in st.pawns.values():
			if q != p and not q.is_eliminated and q.owner_id == p.owner_id \
					and q.unit_type == Constants.UnitType.INFANTRY \
					and maxi(absi(q.position.x - p.position.x), absi(q.position.y - p.position.y)) <= 1:
				_stem("schrik", doc, vertraging + 0.25)
				break


## Een pion geselecteerd (na het selectiegeluid van zijn type).
func bij_selectie(pawn: Pawn) -> void:
	var st := _state()
	if st == null or pawn == null or not aan():
		return
	match pawn.unit_type:
		Constants.UnitType.INFANTRY:
			_speel("uniform_ritsel", 0.04)
			if _rng.randf() < _stem_kans():
				_stem("bevel_roep", st.doctrine_of(pawn.owner_id), 0.12)
		Constants.UnitType.CAVALRY:
			_speel("harnas_kraak", 0.04)


## Een pion haalt de haven: het eigen kamp juicht.
func haven(pawn: Pawn) -> void:
	var st := _state()
	if st == null or pawn == null or not aan():
		return
	_stem("haven_juich", st.doctrine_of(pawn.owner_id), 0.5)


## Een pion verdwijnt zonder gevecht (in _refresh_all): vanaf de honger-cyclus
## is dat de honger.
func verdwenen(pawn: Pawn) -> void:
	var st := _state()
	if st == null or pawn == null or not aan():
		return
	var vanaf: int = int(st.rules.honger_vanaf_cyclus)
	if vanaf <= 0 or st.cycle < vanaf or pawn.unit_type == Constants.UnitType.ARTILLERY:
		return
	_stem(_stemnaam("honger_maag", pawn), st.doctrine_of(pawn.owner_id))


## Hoeveel eigen pionnen hebben nu het beurtlicht; klinkt als het aangaat.
func beurtlicht(aantal: int) -> void:
	if aantal > 0 and not _beurtlicht_aan and aan():
		_speel("beurtlicht_aan")
	_beurtlicht_aan = aantal > 0


## Steen-papier-schaar (game._sync_sps): aftellen bij een nieuwe keuze, de
## klap als de uitslag er ligt.
func sps(modus: String, poging: int) -> void:
	var sleutel := "%s:%d" % [modus, poging]
	if sleutel == _sps_gezien:
		return
	_sps_gezien = sleutel
	if not aan():
		return
	if modus == "kies":
		_speel("sps_tel")
	elif modus == "uitslag":
		_speel("sps_onthul")


# --- Zelf: sfeerlaag, accenten, vlag, trom, vliegen, wind, regen ------------

func _process(delta: float) -> void:
	if game == null:
		return
	_t_check -= delta
	if _t_check <= 0.0:
		_t_check = 0.5
		_volg_diorama()
		_kijk_rond()
	if not aan():
		return
	var st := _state()
	var bezig: bool = st != null and st.phase != Phase.Type.PRE_GAME and st.phase != Phase.Type.GAME_OVER
	var gem: float = PawnView.fx("leven_accenten", 40.0)
	if gem > 0.0:
		_t_accent -= delta
		if _t_accent <= 0.0:
			_t_accent = _rng.randf_range(gem * 0.5, gem * 1.5)
			_speel_accent()
	_t_wind -= delta
	if _t_wind <= 0.0:
		_t_wind = _rng.randf_range(45.0, 100.0)
		_speel("weer_wind_vlaag", 0.0, -2.0)
		if bezig and _drager_leeft(st, "flag"):
			_speel("vlag_wapper", 0.35)
	if _regen:
		_t_onweer -= delta
		if _t_onweer <= 0.0:
			_t_onweer = _rng.randf_range(50.0, 110.0)
			_speel("weer_onweer")
	if not bezig:
		return
	_t_vlag -= delta
	if _t_vlag <= 0.0:
		_t_vlag = _rng.randf_range(15.0, 40.0)
		if _drager_leeft(st, "flag"):
			_speel("vlag_wapper", 0.0, -3.0)
	_t_trom -= delta
	if _t_trom <= 0.0:
		_t_trom = _rng.randf_range(20.0, 50.0)
		if _drager_leeft(st, "drum"):
			_speel("trom_tik", 0.0, -3.0)
	_t_vlieg -= delta
	if _t_vlieg <= 0.0:
		_t_vlieg = _rng.randf_range(18.0, 35.0)
		if get_tree().get_nodes_in_group("battlefield_debris").size() >= 3:
			_speel("vlieg_zoem")


func _drager_leeft(st: GameState, rol: String) -> bool:
	for p in st.pawns.values():
		if not p.is_eliminated and String(p.rol) == rol:
			return true
	return false


## Het diorama wisselt (start van een potje, of de knop in het sfeer-paneel):
## een eigen sfeerlaag als die opname er ligt (anders ambient_field), het
## kampvuur zacht erbij als het kamp er een heeft, en per potje de loting
## van de regen.
func _volg_diorama() -> void:
	var om = game.get("_omgeving")
	if om == null:
		return
	var i: int = om.diorama_index()
	if i == _diorama:
		return
	_diorama = i
	var sleutel: String = String(DIORAMA_SLEUTEL[clampi(i, 1, DIORAMA_SLEUTEL.size()) - 1])
	if not aan():
		return
	Audio.zet_sfeer(sleutel)
	Audio.zet_lus("kampvuur", "sfeer_kampvuur" if _heeft_kampvuur(i) else "", -22.0)
	_regen = _rng.randf() < clampf(PawnView.fx("weer_regen_kans", 0.0), 0.0, 1.0)
	Audio.zet_lus("regen", "weer_regen" if _regen else "", -18.0)


static func _heeft_kampvuur(i: int) -> bool:
	var d: Dictionary = Omgeving.DIORAMAS[clampi(i, 1, Omgeving.DIORAMAS.size()) - 1]
	for prop in d.get("kamp", []):
		if String((prop as Array)[0]) == "kampvuur":
			return true
	return false


func _speel_accent() -> void:
	var sleutel: String = String(DIORAMA_SLEUTEL[clampi(_diorama, 1, DIORAMA_SLEUTEL.size()) - 1]) if _diorama > 0 else ""
	var lijst: Array = ACCENTEN_PER.get(sleutel, ACCENTEN)
	var opnames: Array = lijst.filter(func(c) -> bool: return Audio.heeft(String(c)))
	if opnames.is_empty():
		return
	_speel(String(opnames[_rng.randi() % opnames.size()]), 0.0, _rng.randf_range(-4.0, 0.0))


## Elke halve seconde: de dreiging bij je haven (een vijand een of twee
## stappen van zijn doel, dus van jouw kant), en de blik op het vaandel
## en de trom bijhouden (een nieuwe cyclus zet trom_gebruikt terug).
func _kijk_rond() -> void:
	var st := _state()
	if st == null:
		return
	if st.cycle != _cyclus:
		_cyclus = st.cycle
		_trom_vorig.clear()
	for p in st.pawns.values():
		if not p.is_eliminated:
			_vaandel_vorig[p.id] = Rules.aura_bonus(st, p, "flag") > 0
			_trom_vorig[p.id] = bool(p.trom_gebruikt)
	var dreig := false
	if st.phase == Phase.Type.ACTION:
		var mens: int = int(game.get("_human_id"))
		var vijand: int = Constants.PLAYER_2 if mens == Constants.PLAYER_1 else Constants.PLAYER_1
		var doel: Array = Constants.get_haven_for_player(vijand)
		for p in st.pawns.values():
			if p.is_eliminated or p.owner_id != vijand:
				continue
			for t in doel:
				var d: int = absi(p.position.x - (t as Vector2i).x) + absi(p.position.y - (t as Vector2i).y)
				if d >= 1 and d <= 2:
					dreig = true
	if dreig and not _haven_dreig and aan():
		_speel("haven_dreig")
	_haven_dreig = dreig

# Overdracht cloud-sessie 5 oktober → lokaal oppakken

Max vroeg in een cloud-sessie vier dingen. Die zijn daar gebouwd en daarna
**bewust weer weggehaald**: de cloud-checkout liep achter op Max' lokale code
(zijn `pawn_view.gd` heeft de functies op regel ~2511/2527, de repo op
~1601/1611), en er was geen Godot om te testen. Bouw ze hier opnieuw, op de
actuele lokale code, en draai de checks uit CLAUDE.md. Hieronder staat per
punt de diagnose en de aanpak die in de cloud werkte, zodat je niet opnieuw hoeft
te zoeken. Gooi dit bestand weg als alles af is.

---

## 1. Crash: "Invalid access to property or key 'name' on a base object of type 'previously freed'"

Stack: `pawn_view.gd` `_shed_one` ← `_shed_first_limb` (lokale regels 2527/2511).

**Oorzaak.** `_shed_parts` verzamelt `live = _piece.find_children("*", "MeshInstance3D", ...)`
en start een tween die `_shed_first_limb(live, dir)` pas 0,1-0,4 s later
aanroept. Is het model in die tijd vrijgegeven (pion opgeruimd, model
gewisseld), dan leest `_shed_one` `mi.name` op een dood object.

**Fix.**
- `tw.tween_callback(_shed_first_limb.bind(dir))`: geef de oude lijst niet meer mee.
- In `_shed_first_limb(dir)`: `if not is_instance_valid(_piece) or not _piece.is_inside_tree(): return`,
  daarna `live` vers ophalen uit `_piece`.
- In de lus van `_shed_one`: `if not is_instance_valid(mi): continue`.

## 2. Geluid: "dB per sound effect luistert niet naar de algemene game sound settings"

**Oorzaak (in de repo-versie).** `scripts/core/audio_manager.gd` hangt elke
AudioStreamPlayer (pool, muziek, ambience) direct aan `"Master"` en zet zelf
`volume_db = master_db + CATEGORY_DB + volume_correctie(cat)`. Er is geen knop
die over alle effecten heen gaat. **Check eerst of Max lokaal al een
geluidsmenu of volume-sliders heeft**; dan moet het daarop aansluiten in plaats
van een tweede systeem te bouwen.

**Aanpak die in de cloud gebouwd was.**
- Bussen `SFX`, `Music` en `Ambient` runtime aanmaken onder Master
  (`AudioServer.add_bus()`, `set_bus_name`, `set_bus_send(idx, "Master")`,
  alleen als `get_bus_index(naam) == -1`). Pool → `SFX`, muziek → `Music`,
  ambience → `Ambient`.
- Volumes lineair 0..1 per kanaal (`master`, `sfx`, `music`, `ambient`) in
  `user://settings.cfg`, sectie `[audio]`. Die cfg bevat ook de taal, dus eerst
  `cfg.load()` en dan pas `set_value`/`save`. Toepassen met
  `set_bus_volume_db(idx, linear_to_db(max(lin, 0.0001)))` en `set_bus_mute` bij 0.
- `set_enabled` (toets M) zet ook de Master-bus stil. Anders spelen geluiden
  die al met een vertraging in de wachtrij stonden nog af.
- Menu: Instellingen → "Geluid", met vier knoppen (Alles/Effecten/Muziek/Sfeer)
  die per klik 20% zachter zetten, en na 0% weer 100%. Teksten hardcoded NL/EN
  via `Constants.get_language()`, want de csv vraagt een `--import`.
- De dB per categorie (CATEGORY_DB + `sounds/sound_tuning.json`) blijft het
  verschil TUSSEN effecten; de bus schaalt daar overheen.

## 3. Model-tuner: alle varianten van één factie

Max letterlijk: *"ik wil dus alle varianten van dezelfde factie naast elkaar zien,
vooraan alle infantry, daarachter de cav en daarachter alle kanon-varianten"*.
Eerder ook: *"per factie rustig, niet letterlijk allemaal tegelijk"* (de
bestaande "formatie" toont 2 facties × 3 types × 5 archetypes = 30 pionnen).

**Aanpak (in `scripts/tools/model_tuner.gd`).**
- Knop "alle varianten" (toggle) + OptionButton rood/blauw in de bovenbalk,
  naast "formatie". De twee sluiten elkaar uit (`set_pressed_no_signal`).
- `_build_row()`: factie = `_fac_btn`, per type een rij van `ARCHS`
  (base/spd/hp/atk/mix), x = `(ci - 2) * 1.1`. De camera staat aan de **+z-kant**
  (`CAM_BASIS.z`), dus vooraan = grootste z: infanterie z = 1.4, cavalerie 0,
  artillerie -1.4. `face_dir(Vector2i(0, 1))`, `pv.team` uit de kleurkeuze.
- Sla een type over als de factie het niet kent. Gebruik de ACTIEVE tabel:
  `CRules.actieve_tabel().doctrine_data(fac).comp`, niet `constants.gd`
  (Muis en Beer hebben geen artillerie).
- Hergebruik `_formation_pawns` (`{"pv","fac","tp","arch"}`), dan sturen de
  sliders vanzelf het model uit de dropdowns (type + archetype).
- `_on_model_select_changed`: alleen opnieuw opbouwen als de factie wisselt,
  anders `_sync_sliders_from_tuning()`. `_retune_target` en `_reload_pawns`
  ook laten weten dat deze modus aan staat.
- Camera-size in deze modus ongeveer: spel 7.5, close-up 5.2, voorkant 5.0.

## 4. Regel 4.3.2: steen-papier-schaar bij een gelijk initiatief-bod

Max: *"rock paper scissor bij gelijk spel bid"*. Zijn antwoorden op de
ontwerpvragen:
- **Wanneer:** pas helemaal achteraan. Eerst Aanval-bod, dan Speed-bod; alleen
  als BEIDE gelijk zijn, steen-papier-schaar. Dat vervangt de terugval
  "cyclus 1/ronde 1 → speler 1, anders de vorige houder"
  (`Rules.compute_initiative`).
- **Bots:** geseed willekeurig, reproduceerbaar.
- **Oplevering:** aan, als regelversie **4.3.2** + CHANGELOG, en daarna de
  goldens opnieuw maken.

Let op: RPS is in F0.0 bewust verwijderd (B9, "dode RPS-code"). Dit is dus een
nieuw besluit. Noem het "sps" in de code: de F0.0-check grept op "rps".

**Ontwerp dat in de cloud stond (en klopte bij een zelfreview).**
- Knop `campaign.initiatief_sps` in `RulesConfig.CAMPAIGN_DEFAULTS` (default
  `true`), en expliciet in `rules_v42_campaign.json` en `v42_default.json`
  (daar ook `"rules_version": "4.3.2"`). De versie-trede in `from_dict`: is
  de versie 4.1*/4.2*/4.3.0/4.3.1/4.3.2, dan wordt het `"4.3.2"` met de knop
  aan, anders `"4.3.1"`. Let op: die regel in `rules_config.gd` bevat letterlijke
  tabs van de heredoc-bug, dus vervang hem regel-gebaseerd.
- **Geen nieuw actietype.** `ack_reveal` krijgt een optioneel veld `sps`
  (0 steen, 1 papier, 2 schaar): `Actions.make_ack_reveal(sps := -1)`, en
  `is_wellformed` eist dat `sps` een int is (`from_dict` maakt van JSON-floats al ints).
- **Een kale ack betekent dat de reducer kiest** (`_sps_auto`): een RNG met als
  zaad de sha256 van `Serializer.state_to_dict(state)` (zonder de sleutels
  `"sps"` en `"reveal_acks"`) + `"|speler|poging"`, en dan `randi_range(0,2)`.
  Daardoor hoeft geen enkele runner, agent, trainer, capture-lus of timeout
  aangepast te worden. Die acken allemaal kaal en lopen gewoon door.
- GameState: `sps_nodig`, `sps_keuzes {speler: keuze}`, `sps_winnaar` (-1),
  `sps_poging`. Ook in `clone()`.
- `Rules`: `sps_aan(state)` (campaign + knop), `sps_open(state)` (reveal en
  nodig en nog geen winnaar), `sps_winnaar(k1, k2)` (P1 wint als
  `(k1-k2+3)%3 == 1`, -1 bij gelijk). `compute_initiative` krijgt `"gelijk"`
  en geeft bij gelijk + `sps_aan` → `state.sps_winnaar` (-1 zolang er nog
  gekozen wordt).
- Reducer:
  - `_enter_reveal` zet de sps-velden op nul, berekent het initiatief en zet
    `sps_nodig = init.gelijk and sps_aan`. `cards_revealed.winner` is -1
    wanneer er gekozen moet worden.
  - `_do_ack_reveal(state, action, player, events)`: zolang `sps_open` geldt,
    keuze = `action.sps` of `_sps_auto`, met het event `sps_gekozen {player_id}`.
  - Zijn beide keuzes binnen, dan event `sps_uitslag {keuzes{"1","2"}, winner, poging}`.
    Daarna keuzes leeg, **beide acks terug op false**, en bij gelijk `poging++`,
    anders `sps_winnaar = w`.
  - Een tweede ronde kale acks bevestigt de uitslag en opent het koppelen.
    Die extra bevestiging geeft de UI een moment om de uitslag te tonen.
  - Vlak voor `_begin_linking` de sps-velden weer leegmaken.
- Validator: `ack_reveal` met `sps` alleen als `sps_open`, met waarde 0..2.
  `legal_actions` in de reveal: de kale ack VOORAAN en daarna de drie keuzes als
  `sps_open` (L1/L2 nemen `legal[0]` → de reducer kiest; altijd steen zou uit te buiten zijn).
- Serializer: een blok `"sps"` alleen schrijven als er iets niet-default is, zodat
  snapshots buiten dat moment byte-identiek blijven. Het blok ook teruglezen.
- View: `sps_open`, `sps_winnaar`, `sps_poging`, `own_sps_keuze`,
  `enemy_sps_gekozen` (bool, nooit de keuze zelf). De server haalt de rauwe actie
  al uit de client-rijen (`naarClientRij`), dus de keuze lekt daar niet.
- GameSession: `submit_ack_reveal(player, sps := -1)`, en een signal
  `sps_uitslag(keuzes, winner)` dat uit het event komt.
- game.gd:
  - In `_on_cards_revealed`: bij `winner == -1 and Rules.sps_open(...)` een
    overlay met drie knoppen tonen.
  - Bij een keuze: `submit_ack_reveal(_human_id, k)` en daarna `submit_ack_reveal(_ai_id)` (kaal).
  - `_on_sps_uitslag`: bij gelijk opnieuw drie knoppen. Bij een winnaar "X begint
    met koppelen" + beide keuzes + Doorgaan → `_continue_after_reveal()`.
- Tests (in ReducerTests):
  - een waarheidstabel voor `sps_winnaar`;
  - de hele flow (de staat zoals `CpTests._define_staat`: campaign, één pion per
    kant, dezelfde kaart `{hp: budget-2, stamina 1, attack 1}` → beide boden 0 →
    gelijk);
  - zelfde keuze → opnieuw;
  - de validator, ook een 4.1-staat zonder keuze;
  - kale acks die geseed en reproduceerbaar zijn;
  - de view houdt de keuze blind;
  - een snapshot-rondreis midden in het kiezen.

  Daarnaast: in `SpawnTests.test_campaign_blok_bumpt_rules_version` wordt de
  verwachte versie 4.3.2 (en 4.3.1 met de knop uit), en in `ValidatorTests._dispatch`
  `sps` doorgeven + `make_ack_reveal(2)` toevoegen aan de roundtrip.
- Docs: spelregels-v4.2.md (Deel A §5 een verwijzing, Deel B een nieuwe sectie "4.3.2"),
  spelregels-CHANGELOG.md, protocol.md (het optionele `sps` op `ack_reveal`),
  WIP.md, CLAUDE.md (kernregel-bullet).
- **Na het bouwen:**
  - testsuite draaien;
  - `-- makegoldens` (de campagne-goldens breken op de versie-string);
  - `golden_sims.json` opnieuw ijken;
  - `server/test/.cache/referentie_partij.json` weggooien;
  - `-- simcheck` en `-- play`, en één potje zelf met een geforceerd gelijk bod.

  De balans is niet gemeten; een volledig gelijk bod is zeldzaam.

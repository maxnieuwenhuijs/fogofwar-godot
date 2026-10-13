# Geluiden-wishlist — Fog of War

Verlanglijst van SFX om het spel levendig te maken. Sluit aan op het bestaande
`Audio`-systeem (`scripts/core/audio_manager.gd`): elk geluid is een `.wav` in
`sounds/`, gegroepeerd in een **categorie**; `Audio.play(categorie)` kiest
willekeurig een variant. Meer varianten = minder "ratel" bij herhaling.

**Legenda:** ✓ = heb je al · ➕ = nog maken/zoeken · 🎚️ = extra varianten welkom
**Variaties-vuistregel:** iets wat vaak snel achter elkaar klinkt → 3-5 varianten;
iets zeldzaams/eenmaligs (win, fase-overgang) → 1-2.

Kort, droog en "punchy" werkt het best; laat lange galm liever in het bestand
zelf zitten (dan hoeft de engine niks te mixen).

---

## 0. Het prompt-recept (ElevenLabs) -- LEES DIT EERST

*Besluit Max, 30 juli.* De oude prompts waren filmscene-beschrijvingen. Zoiets
levert een sfeerclipje op, geen bruikbaar spelgeluid. Het recept is nu:

**EEN geluidsbron. EEN korte reactie. ZES takes achter elkaar in een clip.**

```
6 short <bijvoeglijk> <bron> <reactie>s in a row,
each about 0.4 seconds, silence between each,
one <bron> only, dry close mono recording, no reverb, no music
```

Waarom zo:

| Regel | Reden |
|---|---|
| **Een laag per prompt** | Kreet, lijf-op-de-grond en musket-kletter zijn drie categorieen die het spel apart afspeelt en apart timet. Vraag je ze in een prompt, dan kun je ze nooit meer los schuiven. |
| **Zes takes in een clip** | Je knipt ze zelf uit en noemt ze `inf_die_mouse1..6`. Een categorie met varianten ratelt niet. Veel goedkoper dan zes keer genereren. |
| **Duur per take erin** | Zonder getal maakt ElevenLabs er een lange uithaal van. |
| **"one X only"** | Anders komt er een kudde of een menigte. |
| **Geen scene** | Laat "battlefield", "war-beast", "harness creaking", "dust settling" weg: dat is regie, geen geluid. |
| **Zet Duration op ~5-8s** | Genoeg voor zes takes; Prompt influence hoog (80-100%). |

**Zo niet** (dit was de oude stijl, drie lagen + regie in een prompt):

> ~~Large rodent war-beast death cry, sharp and rattling, dropping in pitch,
> with heavy thudding of a big body falling onto dirt and leather harness
> creaking. Dry and close, no music.~~

**Zo wel** (alleen de stem, zes takes, duur erin):

> 6 short deep rodent squeals in a row, each about 0.4 seconds, raspy and
> dropping in pitch, silence between each, one animal only, dry close mono
> recording, no reverb, no music

Het lijf dat neerkomt vraag je los aan (`body_hit_floor`), en het harnas dat
kraakt hoort bij `val_prop`. Dat is geen extra werk: het zijn categorieen die
je toch al nodig hebt, en het spel kan ze dan per frame timen (tuner, tab
**Geluid**).

**Voor de niet-vocale categorieen geldt hetzelfde**: zet
`<# var> short ... in a row, silence between each` voor de prompt uit de grote
tabel onderaan, dan heb je alle varianten in een generatie.

---

## 1. Interface / knoppen (kort & subtiel)

| Categorie | Bestanden | # var | Wanneer | Status |
|---|---|---|---|---|
| `ui_click` | `ui_click.wav` | 3 | Elke menuknop, koppel-tap | ✓ |
| `ui_back` | `ui_back.wav` | 2 | Uitleg sluiten | ✓ |
| `ui_hover` | `ui_hover.wav` | 1 | Muis over een menuknop | ✓ |
| `ui_error` | `ui_error.wav` | 1 | Pion kan niet; knop schudt nee | ✓ |
| `ui_toggle` | `ui_toggle.wav` | 1 | Speluitleg-tab wisselen | ✓ |
| `ui_open` | `ui_open.wav` | 2 | Overlay/uitleg opent | ✓ |
| `ui_plof` | `ui_plof.wav` | 3 | Iets ploft erin (knop klaar, badge) | synthetisch |
| `ui_stempel` | `ui_stempel.wav` | 3 | Stempel: CP, REVEALED, STEM, winst | synthetisch |
| `ui_draai` | `ui_draai.wav` | 3 | Kaart draait om (onthulling) | synthetisch |
| `ui_tel` | `ui_tel.wav` | 3 | Getal telt op (tikjes, stijgend) | synthetisch |
| `ui_munt` | `ui_munt.wav` | 3 | "+1" zweeft omhoog (donatie, dank) | synthetisch |
| `ui_blad` | `ui_blad.wav` | 3 | Hub-golf, nieuwe fase, menu-wissel | synthetisch |
| `ui_knop` | `ui_knop.wav` | 3 | Een knop indrukken (onder de klik) | synthetisch |

De zeven onderste (30 september; `ui_knop` sinds 6 oktober) horen bij de
UI-beweging (`scripts/ui/ui_beweging.gd`, `Beweging.klank`); houd de "Wanneer" hier korter
dan 40 tekens, anders leest de geluid-studio hem als prompt. Tot de echte
opnames er zijn: placeholders uit `tools/maak_ui_geluiden.py` (hout, perkament,
messing; manifest `sounds/ui/synthetisch.json`). Een echte opname op dezelfde
naam wint.

## 2. Kaarten definiëren & koppelen

| Categorie | Bestanden | # var | Wanneer | Status |
|---|---|---|---|---|
| `card_stat_up` | `card_stat_up.wav` | 3 | + op een stat (oplopend messing gewicht) | ✓ |
| `card_stat_down` | `card_stat_down.wav` | 3 | − op een stat (aflopend) | ✓ |
| `card_confirm` | `card_confirm.wav` | 2 | Kaarten bevestigd | ✓ |
| `card_deal` | `card_deal2.wav` | 2 | Kaarten uitgedeeld in de waaier | ✓ |
| `card_select` | `card_select.wav` | 3 | Kaart aantikken bij het koppelen | ✓ |
| `link_snap` | `link_snap.wav` | 3 | Kaart koppelt aan een pion (klik-vast) | ✓ |

## 3. Onthulling & fase-flow

| Categorie | Bestanden | # var | Wanneer | Status |
|---|---|---|---|---|
| `reveal` | `reveal.wav` | 2 | Kaarten onthuld (trommelroffel) | ✓ |
| `initiative` | `initiative.wav` | 1 | Wie het initiatief pakt | ✓ (uit) |
| `phase_change` | `phase_change.wav` | 2 | Nieuwe definitie-ronde | ✓ |
| `cycle_start` | `cycle_start.wav` | 1 | Nieuwe cyclus (hoornstoot, vanaf cyclus 2) | ✓ |
| `your_turn` | `your_turn.wav` | 1 | Jouw beurt in de actiefase | ✓ (uit) |

## 4. Opstellen

| Categorie | Bestanden | # var | Wanneer | Status |
|---|---|---|---|---|
| `place_pawn` | `place_pawn.wav` | 4 | Pion neerzetten op een vak | ✓ |
| `place_undo` | `place_undo.wav` | 1-2 | Ongedaan maken (omgekeerde plof) | ➕ |

## 5. Selectie & beweging per type (deels aanwezig)

| Categorie | Bestanden | # var | Wanneer | Status |
|---|---|---|---|---|
| `musket_cock` | `cockhammer.wav` | 1-2 | Infanterie geselecteerd die kan schieten | ✓ 🎚️ |
| `horse_select` | `horse_select*.wav` | 3 | Cavalerie geselecteerd | ✓ |
| `cannon_select` | `cannon_select.wav` | 3 | Artillerie geselecteerd | ✓ |
| `inf_select` | `inf_select.wav` | 3 | Infanterie zónder schot geselecteerd | ✓ |
| `deselect` | `deselect.wav` | 1 | Pion deselecteren | ✓ |
| `step` | `step1-4.wav` | 4 | Infanterie loopt (1 per vakje, cyclt + pitch) | ✓ |
| `horse_move` | `horse_move*.wav` | 2 | Cavalerie beweegt (1 galopclip per zet) | ✓ 🎚️ |
| `cannon_move` | `cannon_move*.wav` | 4 | Artillerie rolt (1 per vakje) | ✓ |

## 6. Gevecht (deels aanwezig)

| Categorie | Bestanden | # var | Wanneer | Status |
|---|---|---|---|---|
| `musket_fire` | `musket*.wav` | 3 | Infanterieschot afvuren | ✓ 🎚️ |
| `musket_echo` | `musket_echo*.wav` | 6 | Naklank van het schot | ✓ |
| `musket_hit` | `default_musket_hit.wav` | 2-3 | Kogel slaat in | 6 short musket ball impacts on a body in a row, each about 0.3 seconds, wet thud with dust, silence between each, dry close mono, no reverb, no music |
| `cannon_lontstok` | `cannon_lontstok*.wav` | 3 | Lontstok op het zundgat | synthetisch (tools/maak_kanon_geluiden.py); prompt in de geluid-studio |
| `cannon_fire` | `cannon_heavy*.wav` | 3 | Kanon afvuren | ✓ |
| `cannon_air` | `cannon_bal_flies*.wav` | 4 | Kogel door de lucht | ✓ |
| `cannon_hit` | `cannon_ball_hit.wav` | 2-3 | Kanonskogel inslag | ✓ 🎚️ (nu 1) |
| `melee_kill` | `mellee_hit*.wav` | 3 | Melee doodt het doelwit | 6 short bayonet stabs into a body in a row, each about 0.3 seconds, wet punch with a steel scrape, silence between each, dry close mono, no reverb, no music |
| `melee_survive` | `mellee_hit_no_kill.wav` | 2-3 | Doelwit overleeft de klap | 6 short steel-on-steel parry clangs in a row, each about 0.3 seconds, bright and blocked, silence between each, dry close mono, no reverb, no music |
| `retaliation` | `retaliation.wav` | 1 | Terugslag door infanterie (staal-op-staal) | 3 short steel counterstrike clangs with a single male grunt in a row, each about 0.4 seconds, silence between each, dry close mono, no reverb, no music |
| `retaliation_horse` | `retaliation_with_horse.wav` | 1 | Terugslag door een paard (hoeven) | ✓ |
| `blood_splash` | `small_blood_splash*.wav` | 3 | Levend stuk overleeft een treffer | 6 short wet blood splatters in a row, each about 0.25 seconds, silence between each, dry close mono, no reverb, no music |
| `charge_rumble` | `charge_rumble*.wav` | 3 | De dreunende aanloop onder de strijdkreet: zwaar gestamp dat de grond laat trillen (18 september; per factie als `charge_rumble_<factie>`) | synthetisch (tools/maak_wapen_geluiden.py); prompt in de geluid-studio |
| `charge_yell` | `charge_yell.wav` | 1 | Cavalerie begint een charge (strijdkreet) | 3 short male battle shouts in a row, each about 0.6 seconds, hoarse and forward, silence between each, a few men only, dry close mono, no reverb, no music |
| `pawn_block` | `pawn_block.wav` | 2 | Schot geblokkeerd (bank klaar; nog geen event) | 3 short musket ball thuds into thick wood in a row, each about 0.3 seconds, blocked and dull, silence between each, dry close mono, no reverb, no music |

## 6b. Zwaai en klap per WAPEN (17 september)

Max: "update de sounds ook voor slashing sounds en zwaard-impactgeluiden per
factie of type wapen". Elke melee-aanval speelt nu drie lagen: de ZWAAI
(`slash_<wapen>`, `melee_slash_voor` 0,18 s voor de klap), de KLAP
(`melee_kill_<wapen>` of `melee_survive_<wapen>`) en daaronder de materiaal-
laag uit 7c. Welk wapen: `PawnView.melee_wapen` (een plek): infanterie =
bajonet; ruiter base/mix = sabel, spd = lans, hp = bijl, atk per factie
(muis briquet en leeuw/wolf pallasch = sabel, varken broadaxe en krokodil
enterbijl = bijl, beer uhlanenlans = lans). Zoekvolgorde
(`Audio.melee_keten`): `<cat>_<wapen>_<factie>` (bv `melee_kill_bijl_pig`)
→ `<cat>_<wapen>` → `<cat>`. Tot de opnames er zijn liggen er synthetische
placeholders in `sounds/melee/` (`tools/maak_wapen_geluiden.py`, drie per
categorie, manifest `synthetisch.json`); een echte opname op dezelfde naam
wint. Check: `-- wapengeluidcheck`.

| Categorie | Waarvoor | Hoe | Var. | Nu |
|---|---|---|---|---|
| `slash_sabel` | Zwaai van sabel, pallasch, briquet | dun, scherp, hoog staal-whoosh | 3 | synthetisch |
| `slash_bijl` | Zwaai van broadaxe, enterbijl, de hp-bijl | breed en zwaar, laag whoosh | 3 | synthetisch |
| `slash_lans` | Stoot van de lans/piek | kort dun fluitje van een lange stok | 3 | synthetisch |
| `slash_bajonet` | Bajonetstoot van de infanterie | heel kort, met een vleugje doek | 3 | synthetisch |
| `melee_kill_sabel` | Sabelhouw die doodt | natte snede met een heldere staalklank | 3 | synthetisch |
| `melee_kill_bijl` | Bijlslag die doodt | diepe natte hak met een botkraak | 3 | synthetisch |
| `melee_kill_lans` | Lansstoot die doodt | scherpe prik, nat, de schacht bonkt | 3 | synthetisch |
| `melee_kill_bajonet` | Bajonetstoot die doodt | natte stomp met een staalschraap | 3 | synthetisch |
| `melee_survive_sabel` | Sabel geblokkeerd | helder staal-op-staal | 3 | synthetisch |
| `melee_survive_bijl` | Bijl op kuras/schild | doffe zware klank, steel ratelt na | 3 | synthetisch |
| `melee_survive_lans` | Lans schampt af | glijdende schraap met een tik | 3 | synthetisch |
| `melee_survive_bajonet` | Bajonet gepareerd | kleine geblokkeerde klink | 3 | synthetisch |

Per factie erbij (optioneel, naam `<categorie>_<factie>`, bv
`melee_kill_bijl_pig.wav`, `slash_sabel_lion_2.wav`): dan wint die van de
wapen-versie. De prompts staan in de geluid-tracker (sectie "Wapens").

## 7. Sterven per type

| Categorie | Bestanden | # var | Wanneer | Status |
|---|---|---|---|---|
| `horse_die` | `horse_die*.wav` | 2 | Cavalerie sneuvelt | 6 short horse death whinnies in a row, each about 0.5 seconds, strained and falling in pitch, silence between each, one horse only, dry close mono, no reverb, no music |
| `inf_die` | `inf_die*.wav` | 4 | Infanterie sneuvelt | 6 short soldier death cries in a row, each about 0.4 seconds, clipped and breathy, silence between each, one man only, dry close mono, no reverb, no music |
| `cannon_die` | `cannon_destroyed.wav` + `_2` | 2 | Kanon vernietigd | 6 short bursts of splintering wood and cracking cast iron in a row, each about 0.5 seconds, silence between each, dry close mono, no reverb, no music |
| `cannon_wheel_loose` | `cannon_wheel_loose.wav` + `_2` | 2 | Wiel schiet los na de crash (60% kans, 0.35s erna) | ✓ (2) INGEBOUWD |

## 7b. Sterven per FACTIE (besluit Max, 28 juli)

> **Overzicht bijhouden:** `python tools/bouw_geluid_tracker.py` bouwt
> `sound-tracker.html` (of de paneelknop "Welke geluiden ontbreken?"). Die leest
> de `sounds/`-mappen en dit bestand, dus hij loopt nooit achter: per factie zie
> je in kleur wat er ligt, wat mist, en de prompt om te kopieren.

Een muis die sneuvelt piept; een grizzly brult. Daarom naast de algemene
sterfgeluiden een **factie-variant per type**: 5 varianten per factie per type,
zodat een gevecht nooit gaat ratelen.

**Zo fijn als je wilt** (besluit Max, 28 juli): je mag ook **per model**
opnemen, dus per archetype. De zoekvolgorde is fijn -> grof:

```
inf_die_mouse_hp   ->  dit ene model (dikke muis)
inf_die_mouse      ->  hele factie
inf_die_mouse[_hp] ->  leen van de muis (als jouw factie nog niets heeft)
inf_die            ->  algemeen
```

Eén kreet voor alles volstaat dus, maar wil je de logge `hp` laten kreunen en
de spichtige `spd` laten piepen, dan zet je er gewoon een bestand bij.

**Naamconventie:** `<basiscategorie>_<factie>` -- factie in het Engels, net als
de modelmappen: `mouse pig lion bear wolf crocodile`. De basiscategorieen heten
historisch `inf_die` / `horse_die` / `cannon_die` (uit de tijd dat cavalerie nog
paarden waren); die namen houden we aan, zodat de terugval automatisch klopt.

| Type | Algemene categorie (bestaat) | Factie-categorie | # var |
|---|---|---|---|
| Infanterie | `inf_die` | `inf_die_<factie>` | 5 |
| Cavalerie (big bro) | `cav_die` (was `horse_die`) | `cav_die_<factie>[_<archetype>]`, door een kanon `cav_kanon_die_<factie>[_<archetype>]` (18 september) | 5 |
| Artillerie | `cannon_die` | `cannon_die_<factie>` | 5 |

**Muis en Beer hebben geen kanon** (stand C19, 8 augustus 2026: hun comp is
[16,4,0] en [19,3,0]). Ze mogen er ook nooit een spawnen, dus `cannon_die_mouse`
en `cannon_die_bear` zouden nooit klinken: die twee hoef je niet op te nemen.
`sound-tracker.html` vraagt er sindsdien ook niet meer om, en leest die comps
rechtstreeks uit de regels, dus dat corrigeert zichzelf als de facties ooit
weer schuiven. De algemene `cannon_die` blijft wel nodig: je hoort hem als het
kanon van je TEGENSTANDER sneuvelt.

**Wanneer klinkt de factie-kreet?** (besluit Max, 28 juli) Op **kans**, niet
bij elke dode: standaard 15% (`kreet_kans` in `effects_tuning.json`, 0..1).
Een **kanontreffer gilt altijd** -- en dan met de eigen, kortere kanonkreet
(`inf_kanon_die_<factie>`), die al vóór de inslag inzet. De rest van de tijd
hoor je het algemene `inf_die`. Zo blijft de kreet bijzonder zonder dat je
hem aan de animatie hoeft te koppelen.

**Terugval is ingebouwd** (`Audio.play_factie()`, 28 juli): bestaat de
factie-categorie niet, dan **leent** hij die van de muis (net zoals de modellen
op de muis-set terugvallen), en pas daarna het algemene geluid. Je kunt dus met
een enkele factie beginnen; niets gaat stuk zolang de rest ontbreekt.

**Stemkarakter per factie** (dit is het verschil dat je hoort):

| Factie | Infanterie | Big bro |
|---|---|---|
| Muis | hoge, korte piep -- klein en schril | zwaardere knaagdier-krijs (dikke bruine rat) |
| Varken | schril gilletje met een snuivende uithaal | diep everzwijn-gebrul, snuivend |
| Leeuw | cheetah: korte hoge tjilp/sis | leeuw: rollende brul die wegzakt |
| Beer | wasbeer: ratelend gekrijs | grizzly: laag, borstelig gebrul |
| Wolf | vos: die beruchte doordringende schreeuw | dire wolf: afgebroken huil/jank |
| Krokodil | hagedis: blazende sis die stikt | krokodil: dreunende bulderende bel |

### Prompts -- factie-stem (alleen de KREET, een laag)

Recept uit §0. Duration ~6s, Prompt influence hoog; knip er zes takes uit en
noem ze `<bestand>1..6`. Het lijf-op-de-grond en de vallende musket komen uit
`body_hit_floor` en `val_musket` -- die zitten hier bewust NIET in.

| Bestand | Prompt |
|---|---|
| `inf_die_mouse` ✓ (2) | 6 short high-pitched mouse squeaks in a row, each about 0.3 seconds, thin and cut off abruptly, silence between each, one small rodent only, dry close mono recording, no reverb, no music |
| `horse_die_mouse` | 6 short deep rodent squeals in a row, each about 0.4 seconds, raspy and dropping in pitch, silence between each, one animal only, dry close mono recording, no reverb, no music |
| `cannon_die_mouse` (niet nodig: Muis heeft geen artillerie) | 6 short bursts of splintering thin wood and snapping small iron fittings in a row, each about 0.4 seconds, silence between each, dry close mono recording, no reverb, no music |
| `inf_die_pig` | 6 short shrill pig squeals in a row, each about 0.4 seconds, snorting and breaking into a wet gurgle, silence between each, one pig only, dry close mono recording, no reverb, no music |
| `horse_die_pig` | 6 short deep boar grunts in a row, each about 0.5 seconds, snorting and rattling, silence between each, one boar only, dry close mono recording, no reverb, no music |
| `cannon_die_pig` | 6 short bursts of thick oak splitting and iron bands popping in a row, each about 0.5 seconds, silence between each, dry close mono recording, no reverb, no music |
| `inf_die_lion` | 6 short high cheetah chirps in a row, each about 0.3 seconds, strangled and ending in a hiss, silence between each, one cat only, dry close mono recording, no reverb, no music |
| `horse_die_lion` | 6 short rolling lion growls in a row, each about 0.5 seconds, full-throated and wet, silence between each, one lion only, dry close mono recording, no reverb, no music |
| `cannon_die_lion` | 6 short bursts of brass fittings snapping and hardwood splintering in a row, each about 0.4 seconds, silence between each, dry close mono recording, no reverb, no music |
| `inf_die_bear` | 6 short raccoon screeches in a row, each about 0.3 seconds, rattling and chattering, cut off abruptly, silence between each, one animal only, dry close mono recording, no reverb, no music |
| `horse_die_bear` | 6 short low chesty bear grunts in a row, each about 0.5 seconds, wet and rumbling, silence between each, one bear only, dry close mono recording, no reverb, no music |
| `cannon_die_bear` (niet nodig: Beer heeft geen artillerie) | 6 short bursts of thick iron cracking and heavy oak bursting in a row, each about 0.5 seconds, silence between each, dry close mono recording, no reverb, no music |
| `inf_die_wolf` | 6 short piercing fox screams in a row, each about 0.3 seconds, eerie and cut off mid-cry, silence between each, one fox only, dry close mono recording, no reverb, no music |
| `horse_die_wolf` | 6 short broken wolf yelps in a row, each about 0.4 seconds, dropping into a growl, silence between each, one wolf only, dry close mono recording, no reverb, no music |
| `cannon_die_wolf` | 6 short bursts of scrap iron clattering and cracked wood splitting in a row, each about 0.4 seconds, silence between each, dry close mono recording, no reverb, no music |
| `inf_die_crocodile` | 6 short sharp lizard hisses in a row, each about 0.3 seconds, sputtering and choking off, silence between each, one reptile only, dry close mono recording, no reverb, no music |
| `horse_die_crocodile` | 6 short deep crocodile bellows in a row, each about 0.5 seconds, booming and ending in a hissing exhale, silence between each, one reptile only, dry close mono recording, no reverb, no music |
| `cannon_die_crocodile` | 6 short bursts of damp iron cracking and waterlogged wood splitting in a row, each about 0.5 seconds, silence between each, dry close mono recording, no reverb, no music |

**Stem-woordenboek** (als je zelf wil varieren): muis = *high-pitched squeak* ·
varken = *shrill snorting squeal* · leeuw = *cheetah chirp* (inf) / *lion growl*
(rijdier) · beer = *raccoon screech* (inf) / *chesty bear grunt* (rijdier) ·
wolf = *fox scream* (inf) / *wolf yelp* (rijdier) · krokodil = *lizard hiss*
(inf) / *crocodile bellow* (rijdier).

### Prompts -- kanonkreet per FACTIE (`inf_kanon_die_<factie>`)

Een kanontreffer gilt ALTIJD (zie hierboven), dus deze kreet hoor je veel vaker
dan de gewone. Hij is korter en heftiger: de klap kapt hem af, en hij begint al
voor de inslag. Mik op 0,4-0,8s per take.

Ontbreekt hij, dan leent het spel de muizenkreet -- en dan gilt jouw grizzly als
een muis. Dit is dus de eerste die je per factie wilt opnemen, nog voor de
gewone doodskreet.

| Bestand | Prompt |
|---|---|
| `inf_kanon_die_pig` | 6 very short violent pig squeals in a row, each about 0.3 seconds, shrill and snorting, chopped off instantly, silence between each, one pig only, dry close mono recording, no reverb, no music |
| `inf_kanon_die_lion` | 6 very short violent cheetah shrieks in a row, each about 0.25 seconds, high and strangled, chopped off instantly, silence between each, one cat only, dry close mono recording, no reverb, no music |
| `inf_kanon_die_bear` | 6 very short violent raccoon screeches in a row, each about 0.3 seconds, rattling and chattering, chopped off instantly, silence between each, one animal only, dry close mono recording, no reverb, no music |
| `inf_kanon_die_wolf` | 6 very short piercing fox screams in a row, each about 0.25 seconds, eerie and snapped off mid-cry, silence between each, one fox only, dry close mono recording, no reverb, no music |
| `inf_kanon_die_crocodile` | 6 very short sharp lizard hisses in a row, each about 0.3 seconds, sputtering and choked off instantly, silence between each, one reptile only, dry close mono recording, no reverb, no music |


## 7b-2. Kreten per MODEL (archetype) -- de dikke klinkt niet als de dunne

*Besluit Max, 28 juli.* Naast de factie mag je ook per **archetype** opnemen:
`inf_die_mouse_hp` klinkt anders dan `inf_die_mouse_spd`. Ontbreekt een
archetype-bestand, dan pakt het spel gewoon het factie-geluid -- je hoeft dit
dus alleen te maken waar het opvalt.

**Bestandsnamen:**

| Situatie | Bestand |
|---|---|
| Doodgeschoten / bajonet | `inf_die_<factie>_<archetype>` |
| Geraakt door een KANON | `inf_kanon_die_<factie>_<archetype>` |

Archetypes: `base` `spd` `hp` `atk` `mix` -- dezelfde namen als de modellen.

**Hoe de stem verschilt per bouw** (dit is de hele truc):

| Archetype | Bouw | Stem |
|---|---|---|
| `base` | gewoon | de standaardkreet |
| `spd` | spichtig, lang, dun | hoog, ijl en snel -- meer een gil dan een kreun |
| `hp` | dik, rond, met kuras | laag en benauwd, gedempt door pantser, met een metalen kreun eronder |
| `atk` | groot en gespierd | rauw en grommend, meer woede dan pijn |
| `mix` | allrounder | neutraal; mag hetzelfde blijven als `base` |

**Kanonversies zijn KORTER**: de klap kapt de kreet af. Mik op 0,4-0,8s tegen
0,6-1,2s voor de gewone kreet -- hij begint immers al vóór de inslag.

### Prompts -- muis per archetype (`inf_die_mouse_<archetype>`)

Zelfde recept; alleen het bijvoeglijk naamwoord verschilt. Zes takes per clip.

| Bestand | Prompt |
|---|---|
| `inf_die_mouse_base` | 6 short high-pitched mouse squeaks in a row, each about 0.3 seconds, thin and cut off abruptly, silence between each, one rodent only, dry close mono recording, no reverb, no music |
| `inf_die_mouse_spd` | 6 very short thin mouse shrieks in a row, each about 0.2 seconds, extremely high-pitched and fast, silence between each, one rodent only, dry close mono recording, no reverb, no music |
| `inf_die_mouse_hp` | 6 short muffled winded grunts from a rodent behind steel plate in a row, each about 0.4 seconds, low and wheezing, silence between each, one animal only, dry close mono recording, no reverb, no music |
| `inf_die_mouse_atk` | 6 short raw snarling rodent growls in a row, each about 0.4 seconds, angry rather than pained, silence between each, one animal only, dry close mono recording, no reverb, no music |
| `inf_die_mouse_mix` | 6 short mouse squeaks in a row, each about 0.3 seconds, high-pitched and clipped, silence between each, one rodent only, dry close mono recording, no reverb, no music |

### Prompts -- muis geraakt door een KANON (`inf_kanon_die_mouse_<archetype>`)

Korter en harder; de inslag kapt hem af. Vraag de takes op 0,2-0,3s.

| Bestand | Prompt |
|---|---|
| `inf_kanon_die_mouse_base` | 6 very short violent mouse screams in a row, each about 0.25 seconds, high-pitched and desperate, chopped off instantly, silence between each, one rodent only, dry close mono recording, no reverb, no music |
| `inf_kanon_die_mouse_spd` | 6 very short piercing thin shrieks in a row, each about 0.2 seconds, extremely high, snapped off instantly, silence between each, one rodent only, dry close mono recording, no reverb, no music |
| `inf_kanon_die_mouse_hp` | 6 very short deep winded grunts muffled behind steel in a row, each about 0.3 seconds, cut off hard, silence between each, one animal only, dry close mono recording, no reverb, no music |
| `inf_kanon_die_mouse_atk` | 6 very short furious guttural roars in a row, each about 0.3 seconds, chopped off abruptly, silence between each, one animal only, dry close mono recording, no reverb, no music |
| `inf_kanon_die_mouse_mix` | 6 very short violent mouse screams in a row, each about 0.25 seconds, high-pitched, cut off instantly, silence between each, one rodent only, dry close mono recording, no reverb, no music |

*Andere facties: neem de stem uit het woordenboek in 7b en zet de bouw-
modificatie ervoor (varken-`hp` = muffled winded snort behind steel,
wolf-`spd` = very short thin fox shriek, enz.).*

## 7bis. Waarom KORT: de doodskreet en de val zijn twee geluiden

*Gemeten met `-- cliplengtes` (28 juli): de dood-animaties duren 1,8 tot 3,8
seconden, gemiddeld 3,2.* Eén geluid dat die hele animatie moet dekken wordt
een lang, komisch gerekt gepiep. Daarom splitsen we het:

| Geluid | Wanneer | Lengte |
|---|---|---|
| Doodskreet (`inf_die_<factie>` enz.) | direct bij de dodelijke treffer | **0,6-1,2s** |
| Kanonkreet (`inf_kanon_die_<factie>`) | **vlak VOOR de inslag** (kogel nog onderweg) | **0,8-1,5s** |
| Val van het voorwerp (`val_*`) | ~0,45s later, als het de grond raakt | **0,3-0,6s** |

Ze spelen **onafhankelijk** van elkaar, dus je hoeft ze niet op elkaar te
timen: kreet nu, kletter daarna. Dat klinkt ook natuurlijker dan één lang
geluid -- eerst de schreeuw, dan de stilte, dan het hout op de grond.

**Kanontreffer heeft een eigen kreet** (besluit Max, 28 juli): een kanonskogel
is geen musketkogel, dus het slachtoffer gilt zwaarder én eerder -- de kreet
zet in terwijl de kogel nog vliegt en de inslag valt er middenin. Categorie
`inf_kanon_die_<factie>`; ontbreekt hij, dan klinkt gewoon de normale
doodskreet van die factie. Prompt-richting: dezelfde stem als `inf_die_<factie>`
maar harder, langer aangehouden en abrupter afgekapt door de klap.

### Val-geluiden per voorwerp (7 categorieën)

Wat uit de handen vliegt bepaalt de klank. Ontbreekt een categorie, dan pakt
het spel automatisch `val_prop` -- je kunt dus met één generiek geluid
beginnen.

| Categorie | # var | Voorwerp | Prompt |
|---|---|---|---|
| `val_prop` | 3 | terugval voor alles | 6 short wooden and iron object clatters on packed dirt in a row, each about 0.4 seconds, dull knock with a brief metal rattle, silence between each, dry close mono recording, no reverb, no music |
| `val_musket` | 3 ✓ (2) | musket | 6 short musket drops on dirt in a row, each about 0.4 seconds, heavy wooden stock thud with an iron barrel rattle, silence between each, one musket only, dry close mono recording, no reverb, no music |
| `val_melee` | 2-3 | sabel/bijl/lans van de big bro (valt nu terug op val_prop) | 6 short heavy sabre drops on packed dirt in a row, each about 0.4 seconds, ringing steel blade clatter with a dull grip thud, silence between each, one weapon only, dry close mono recording, no reverb, no music |
| `val_drum` | 3 | trommel | 6 short side drum drops on dirt in a row, each about 0.5 seconds, hollow thump with rope and snare rattle, silence between each, one drum only, dry close mono recording, no reverb, no music |
| `val_flag` | 2 | vaandelstok | 6 short wooden pole clatters on dirt in a row, each about 0.4 seconds, hard hollow knock with a single cloth flap, silence between each, dry close mono recording, no reverb, no music |
| `val_horn` | 2 | hoorn | 6 short brass bugle drops on dirt in a row, each about 0.4 seconds, bright metallic clank with a faint ring, silence between each, dry close mono recording, no reverb, no music |
| `val_sapper` | 2 | bijl | 6 short axe drops on dirt in a row, each about 0.4 seconds, dull wooden haft thud with a broad iron clank, silence between each, dry close mono recording, no reverb, no music |
| `val_hoed` | 2-3 ✓ (1) | shako/hoedje dat afvliegt | 6 short felt hat landings on packed dirt in a row, each about 0.3 seconds, soft muffled flop with a light leather strap slap, silence between each, dry close mono recording, no reverb, no music |
| `val_canteen` | 2 | vaatje | 6 short small wooden keg drops on dirt in a row, each about 0.5 seconds, hollow thud with liquid sloshing inside, silence between each, dry close mono recording, no reverb, no music |

## 7c. Inslag-geluiden per MATERIAAL (algemeen, factie-onafhankelijk)

De klap zelf hoort bij het MATERIAAL dat geraakt wordt, niet bij de factie.
Deze laag maakt het verschil tussen "er gebeurt iets" en "dat deed pijn":
vlees klinkt nat, staal klinkt hard, hout klinkt dof.

| Categorie | # var | Wanneer | Status |
|---|---|---|---|
| `impact_flesh` | 5 | Treffer op een levend stuk (nat, doffe plof) | ✓ (2) INGEBOUWD |
| `impact_armor` | 5 | Treffer op kuras/helm (harde metalen tik) | ✓ (1) INGEBOUWD |
| `impact_wood` | 4 | Treffer op musketkolf, affuit, schild (dof hout) | ✓ (1) INGEBOUWD |
| `impact_bone` | 3 | Botbreuk bij een dodelijke melee-klap (kort, krakend) | ✓ (1) INGEBOUWD |
| `impact_dirt` | 4 | Mis: kogel slaat in de grond (aarde + steentjes) | 6 short musket ball impacts in packed dirt in a row, each about 0.3 seconds, dull thud with a spray of soil and pebbles, silence between each, dry close mono recording, no reverb, no music |
| `ricochet` | 4 | Kogel ketst af op steen/ijzer (zingende afketser) | ✓ (1) INGEBOUWD |
| `blood_splash` | 3 | Bloedspat bij een treffer | ✓ (heb je al) |
| `body_hit_floor` | 2-4 | Het LIJF raakt de grond (timing per dood-clip uit `death_pools`) | ✓ (2) 🎚️ |

### Prompts -- materiaal-inslagen

Recept uit §0: een materiaal per prompt, zes korte takes in een clip.

| Bestand | Prompt |
|---|---|
| `impact_flesh` | Wet heavy impact on flesh, a dull meaty thud with a short liquid splatter, close and dry, no reverb, no music. |
| `impact_armor` | Musket ball striking a steel cuirass, a hard bright metallic clank with a short ringing decay, close and dry, no music. |
| `impact_wood` | Musket ball smashing into a thick oak musket stock, a dull heavy wooden knock with splintering, close and dry, no music. |
| `impact_bone` | Sharp bone crack under a heavy blow, a short dry snap muffled by cloth, close, no reverb, no music. |
| `impact_dirt` | Musket ball slamming into packed dirt, a dull thud with a spray of soil and small pebbles, dry and close, no music. |
| `ricochet` | Musket ball ricocheting off stone, a bright metallic whine spinning away into the distance, dry, no music. |

**Wanneer welke -- zo zit het er nu in** (30 juli, `_impact_laag` in game.gd,
keuze-regel in `PawnView.impact_categorie`): de laag speelt bovenop het schot
of de klap, op hetzelfde inslagmoment.

| Situatie | Wat je hoort |
|---|---|
| artillerie geraakt | `impact_wood` (affuit en wielen) |
| hp-archetype geraakt | `impact_armor` (die draagt het kuras) |
| al het andere leven | `impact_flesh` |
| dodelijke melee-klap | `impact_bone` erbij, 50% kans |
| schot dat het doel OVERLEEFT | `ricochet` erbij, 40% kans |

Vijf plekken spelen hem: melee, melee-terugslag, schot, charge en
charge-terugslag. `impact_dirt` staat nog op de lijst maar heeft nog geen
plek: **een mis bestaat niet in de regels** -- schade is altijd minstens 1 en
de validator laat een schot zonder schade niet toe. Daarom is de afketser aan
het overleefde schot gehangen in plaats van aan een mis.

**Timing en volume afstellen** (Model-tuner → tab **Geluid**): achter elke
categorie staan twee velden -- **dB** (volume-correctie) en **vertraging**
(later + / eerder -). Ze worden bewaard in `sounds/sound_tuning.json` en
gelden meteen in het spel; zo schuif je de bons van een vallend lijf of musket
precies op het frame waar hij hoort, zonder code aan te raken.

**In de tuner luisteren** (Model-tuner → tab **Geluid**): per model zie je
welke categorieën er zijn, hoeveel varianten en hoe lang de langste is, met
een speelknop erachter. Ontbreekt er een, dan staat erbij op welk algemeen
geluid het terugvalt. Zo hoor je meteen of een nieuw bestand is aangekomen en
of het bij de animatielengte past.

## 8. Beurt-timer

| Categorie | Bestanden | # var | Wanneer | Status |
|---|---|---|---|---|
| `timer_tick` | `timer_tick.wav` | 1 | Laatste 5-4 sec per seconde; laatste 3 sec dubbel tempo + hoger | ✓ |
| `timer_warning` | `timer_warning.wav` | 1 | Vervangen door versnelde `timer_tick` | ✓ (uit) |
| `timer_timeout` | `timer_timeout.wav` | 1 | Tijd om, spel neemt over | ➕ |

## 9. Uitkomst & mijlpalen

| Categorie | Bestanden | # var | Wanneer | Status |
|---|---|---|---|---|
| `haven_score` | `haven_score.wav` | 2 | Pion bereikt de haven (nog niet gewonnen) | ✓ |
| `win_fanfare` | `win_fanfare.wav` | 1 | Jij wint (triomf-sting) | ✓ |
| `lose_sting` | `lose_sting.wav` | 1 | Je verliest (aflopende mineur) | ✓ |
| `wolf_step` | `wolf_step.wav` | 1-2 | Gratis Wolf-stap uitgevoerd (sluip/whoosh) | ➕ (optioneel) |

## 10. Sfeer / muziek (optioneel, laagste prioriteit)

| Categorie | Bestanden | # var | Wanneer | Status |
|---|---|---|---|---|
| `music_menu` | `music_menu.wav` | 1 loop | Hoofdmenu (rustig) | ➕ |
| `music_battle` | `music/music_battle*.wav` | 2 | In-game bed vanaf matchstart; track klaar → willekeurige volgende | ✓ |
| `ambient_field` | `music/ambient_field*.wav` | 3 | Veld-ambience onder menu én spel (incl. regen-variant) | ✓ |

Lange loops staan in `music/` (niet `sounds/`) en worden met **QOA-compressie**
geïmporteerd (34 MB WAV → ~6,7 MB in het spel). Geen naadloze loop nodig: als een
track afloopt start automatisch een willekeurige volgende variant.

---

## 11. Diorama-props om het bord (klikbaar, 8 september)

De props in het kamp en aan de overkant (`scripts/game/omgeving.gd`) zoeken
bij een klik EERST hun eigen categorie en vallen anders terug op iets uit het
arsenaal. Een bestand met precies deze naam in `sounds/` (waar dan ook, de
index zoekt op naam) doet automatisch mee, geen code nodig; varianten heten
`prop_vuur_2.wav`, `prop_vuur_3.wav` (met underscore, zo leest
`_vind_losse_bestanden` ze). Kort en droog, zoals het recept in sectie 0.

| Categorie | Bestand | Var. | Waarvoor | Terugval nu | Status |
|---|---|---|---|---|---|
| `prop_vuur` | `prop_vuur.wav` | 2-3 | kampvuur laait op na een klik: korte knetter met een vonkenzucht | geen | ➕ |
| `prop_trom` | `prop_trom.wav` | 2 | trommel: een korte roffel, twee tellen | `val_drum` (valt-geluid) | ➕ |
| `prop_ton` | `prop_ton.wav` | 2 | ton: holle houten bonk, wiebelt na | `impact_wood` | ➕ |
| `prop_hoorn` | `prop_hoorn.wav` | 1-2 | hoorn: een korte signaalstoot | `val_horn` (valt-geluid) | ➕ |
| `prop_bijl` | `prop_bijl.wav` | 2 | bijl in de stronk: droge tik op hout | `impact_wood` | ➕ |
| `prop_kogel` | `prop_kogel.wav` | 2 | kanonskogel rolt van de stapel: ijzer op ijzer, dof | `impact_armor` | ➕ |
| `prop_lantaarn` | `prop_lantaarn.wav` | 1 | lantaarn zwaait: metaal piept zachtjes | geen | ➕ |
| `prop_kraai` | `prop_kraai.wav` | 2 | kraai vliegt op: een krassende kreet en vleugelslag | geen | ➕ |
| `prop_kikker` | `prop_kikker.wav` | 2 | kikker springt de plas over: plons, klein | geen | ➕ |
| `prop_wegwijzer` | `prop_wegwijzer.wav` | 1 | wegwijzer wiebelt: hout kraakt | `impact_wood` | ➕ |

**Tik-geluiden per prop (11 september, Max: "iedere prop z'n eigen geluidjes
met variatie per prop").** Elke klik op elke prop klinkt meteen. Binnen een
combo (klikken binnen `tik_pauze` seconden, standaard 0,6, knop in het
sfeer-paneel) blijft het dezelfde variant met een oplopende toon (`tik_toon`
per klik); na een pauze herstart de ladder met een ANDERE variant van
dezelfde categorie, en elke vijfde klik geeft een chime (`prop_combo`) met
een "x5!". **Alles hieronder klinkt nu al**: `tools/maak_prop_geluiden.py`
synthetiseert per categorie 2-3 varianten (FM-bel, glasklink,
aambeeld-partialen, een kraai, een kikker...) in `sounds/props/`. Zet een
echte opname op dezelfde naam (`prop_bel.wav`, varianten `prop_bel_2.wav`,
`prop_bel_3.wav`) en de synthetische wijkt. Kort en "punchy", meestal een
kwart tot een halve seconde; drie varianten per stuk is genoeg, want de
toon varieert al per klik.

| Categorie | Waarvoor (prop) | Hoe het moet klinken | Var. | Nu |
|---|---|---|---|---|
| `prop_tik` | alles zonder eigen geluid (tent, boom, rots, bewoner) | droog houten tokje | 3 | synthetisch |
| `prop_bel` | de bel (dorp, haven, kapel, Alpen, winter) | heldere ding met een staart | 3 | synthetisch |
| `prop_glas` | glaswerk | klink, tink, twee glazen tegen elkaar | 3 | synthetisch |
| `prop_aambeeld` | aambeeld | kleng, hamer op ijzer | 3 | synthetisch |
| `prop_kookpot` | kookpot | bong, deksel op de pot | 3 | synthetisch |
| `prop_trom` | trommel | doffe slag op het vel | 3 | synthetisch |
| `prop_ton` | ton, bierton, wijnvat | holle houten bonk | 3 | synthetisch |
| `prop_hoorn` | hoorn | korte signaalstoot | 3 | synthetisch |
| `prop_bijl` | bijl, hakblok | thunk in hout | 3 | synthetisch |
| `prop_kogel` | kanonskogels | ijzer op ijzer, dof | 3 | synthetisch |
| `prop_klop` | toilethuisje (tik) | klop klop op een deur | 3 | synthetisch |
| `prop_wc` | toilethuisje (grote reacties) | deur die dichtslaat met een piep | 2 | synthetisch |
| `prop_doek` | tent | tentdoek dat klappert | 2 | synthetisch |
| `prop_kraai` | kraai, meeuw, vogels | krassende kreet | 3 | synthetisch |
| `prop_kikker` | kikker, put | kwaak | 3 | synthetisch |
| `prop_wegwijzer` | wegwijzer | hout dat kraakt | 2 | synthetisch |
| `prop_hek` | hek | kraak, lat die tikt | 2 | synthetisch |
| `prop_molen` | molen | wieken die kraken | 2 | synthetisch |
| `prop_kanon_tik` | kanon (tik) | tik op de loop | 2 | synthetisch |
| `prop_kanon` | kanon (schot) | doffe dreun | 2 | synthetisch (terugval `cannon_heavy`) |
| `prop_emmer` | put, emmer | houten emmer aan een touw | 2 | synthetisch |
| `prop_plons` | plas, fontein, sloep, put | plons met belletjes | 3 | synthetisch |
| `prop_ritsel` | palm, boom met blad | bladeren die ritselen | 3 | synthetisch |
| `prop_zand` | piramide, sfinx | zand dat schuift | 2 | synthetisch |
| `prop_steen` | ruine, rots | steen op steen | 3 | synthetisch |
| `prop_sneeuw` | sneeuwpop, kale boom in de winter | pof, knerp | 2 | synthetisch |
| `prop_hooi` | hooiberg | hooi dat ritselt | 2 | synthetisch |
| `prop_lantaarn` | lantaarnpaal, lantaarn aan de tent | tink van metaal | 3 | synthetisch |
| `prop_vuur` | kampvuur | knetter | 3 | synthetisch |
| `prop_uil` | ruine (uil) | oehoe, twee keer | 2 | synthetisch |
| `prop_kip` | toilethuisje, hooiberg (kip) | tok tok tok | 2 | synthetisch |
| `prop_munt` | fontein (muntje) | plink | 2 | synthetisch |
| `prop_kokos` | palm (kokosnoot) | bonk op de grond | 2 | synthetisch |
| `prop_boot` | steiger, sloep | hol hout op water | 2 | synthetisch |
| `prop_ijs` | bevroren plas | krak | 2 | synthetisch |
| `prop_geit` | geit (als de glb er is) | mekker | 2 | synthetisch |
| `prop_nies` | hooiberg (Hatsjoe) | een nies | 2 | synthetisch |
| `prop_kegel` | kegelen: een lege fles valt om (mini-game, 12 september) | glazen tink en een holle bons, twee of drie kort na elkaar | 3 | synthetisch |
| `prop_kegel_rol` | kegelen: de kanonskogel rolt | laag rommelend geruis van ijzer over hard gras | 2 | synthetisch |
| `prop_kruitvat` | kanon: een kruitvat ontploft | doffe knal met een knetterende staart | 2 | synthetisch |
| `prop_hengel` | vissen: uitwerpen en binnenhalen | zoef van de lijn en tikjes van de molen | 2 | synthetisch |
| `prop_vis` | vissen: de vangst klapt op de planken | natte plets met een spartel | 2 | synthetisch |
| `prop_combo` | elke vijfde klik van een combo | vrolijke chime, vier tonen omhoog | 1 | synthetisch |
| `bewoner_snurken` | tent, hooiberg (Zzz) | gesnurk | 2 | synthetisch |
| `prop_schot` | kraai geschoten | musketschot | - | `musket` (bestaat) |

**Bewoners** (de poppetjes, `assets/models/bewoners/LEESMIJ.md`): elke bewoner
noemt in zijn manifest zelf zijn categorieen (`"geluid": ["bewoner_hakken",
"prop_bijl", "impact_wood"]`, de eerste die bestaat klinkt) en het moment in
de clip (`geluid_moment`). Afspraak: `bewoner_<wat hij doet>.wav`, bv.
`bewoner_hakken.wav` (bijl in hout, kort), `bewoner_oefenen.wav` (geweerkolf
op hout). Zo deelt een varken-houthakker en een muis-houthakker een geluid.

---

## Sfeer en details: wat het bord nog meer tot leven brengt (13 oktober)

Max: "wat zijn nog meer geluid en of vfx details die de game nog meer tot leven
brengen. Bekijk alles en zet in de studios. van geritsel van uniforms tot
ambient sounds en echos of kleine puffs of smoke". De secties 12 tot en met 18
hieronder zijn **wensen**: ze staan in de geluid-studio (elk als eigen sectie,
met een prompt in `sounds/geluid_studio.json` uit `tools/maak_geluid_prompts.py`),
maar het spel speelt ze nog niet af. Eerst opnemen en kiezen, daarna inbouwen
(een `Audio.play` op het moment uit de kolom "Wanneer"). Stemmen mogen later per
factie (`pijn_kreun_mouse`, `hijg_bear`), net als de kreten. De VFX die erbij
horen staan in VFX-WISHLIST.md, secties 8 tot en met 10.

## 12. Uitrusting en uniform

| Categorie | Var. | Wanneer | Prompt (EN) |
|---|---|---|---|
| `uniform_ritsel` | 4 | Pion draait zich om of wordt geselecteerd (onder inf_select) | A soldier in a thick wool uniform turns around quickly: a short soft rustle of wool cloth and a faint creak of a leather belt. |
| `uitrusting_rammel` | 4 | Eerste stap van een infanterist: patroontas, veldfles, schede | A soldier starts to march: the short rattle of a leather cartridge box, a tin canteen and a bayonet scabbard bumping against his hip. |
| `harnas_kraak` | 3 | Big bro geselecteerd of in beweging: leer en gespen | A large animal shifts under a heavy leather harness: thick leather creaks and an iron buckle clinks once. |
| `musket_schouder` | 3 | Na het koppelen (de ready-clip): musket naar de schouder | A soldier snaps a wooden musket onto his shoulder: a firm slap of a hand on the wooden stock and a small rattle of the iron sling swivel. |
| `laadstok` | 3 | Na een schot, zachtjes: de laadstok in de loop (herladen) | A steel ramrod slid down the barrel of a flintlock musket, tapped twice at the bottom and drawn out again with a thin metallic scrape. |
| `patroon_bijt` | 2 | Herladen: een papieren patroon afbijten | A soldier tears open a paper cartridge with his teeth: a short dry rip of paper and a few grains of powder spilling. |
| `kruit_pan` | 2 | Vlak voor het schot: kruit op de pan, pan dicht | Priming a flintlock: a pinch of black powder poured into the pan with a tiny sandy hiss, then the steel frizzen snapped shut with a small click. |
| `bajonet_op` | 2 | Voor een bajonetstoot: de bajonet klikt op de loop | A steel bayonet slid onto the muzzle of a musket and twisted until it locks with a firm metallic click. |
| `sabel_trek` | 3 | Big bro trekt zijn sabel voor een charge | A heavy cavalry sabre drawn quickly from a steel scabbard: a bright ringing scrape of steel that ends in a short whoosh. |
| `vlag_wapper` | 3 | Vaandel wappert in de wind (af en toe, harder bij een vlaag) | A cloth regimental banner on a wooden pole flapping and snapping in a gust of wind for a moment. |
| `trom_tik` | 3 | De tamboer tikt in rust zacht op de rand van zijn trom | A drummer idly taps the wooden rim of a small military snare drum twice with a drumstick, soft and light. |
| `kanon_wissen` | 2 | Na een kanonschot: de natte wisser sist in de hete loop | A wet sponge on a long pole pushed into a hot cannon barrel after firing: a hiss of steam and a soft scrubbing swish. |
| `kanon_terugloop` | 2 | Kanonschot: het affuit rolt terug op zijn wielen | A field cannon recoiling after a shot: its wooden carriage on iron-rimmed wheels rolls backwards a short way over packed earth, creaking, and comes to a stop. |

## 13. Troepen die leven (stemmen zonder woorden)

| Categorie | Var. | Wanneer | Prompt (EN) |
|---|---|---|---|
| `hijg` | 3 | Na een melee of een charge: even hijgen | A small animal soldier panting hard for a moment after a fight, a few quick short breaths. |
| `pijn_kreun` | 4 | Geraakt maar overleeft: een korte kreun | A small animal soldier hit but still standing: a short pained grunt through clenched teeth, cut off. |
| `idle_geluidje` | 4 | Een pion in een afwijkende idle: snuif, geeuw, kuchje | A small animal soldier waiting in line makes one small idle sound: a sniff, a short yawn or a little throat clearing. |
| `juich_klein` | 3 | Een vijand valt: een paar eigen pionnen juichen kort | A few small animal soldiers give a short cheer together, a quick happy yelp of triumph. |
| `schrik` | 3 | Een kameraad sneuvelt vlak naast je: een korte schrik | A small animal soldier gasps in shock as a comrade falls next to him, one short startled breath. |
| `bevel_roep` | 3 | Pion geselecteerd: een korte bevelende roep, geen woorden | A small animal officer gives one short sharp barking command, no words, just a single clipped call. |
| `dood_zucht` | 2 | Na de val: de laatste uitademing, heel zacht | The very last breath of a fallen small animal, a soft weak exhale that fades out. |
| `haven_juich` | 2 | Een pion bereikt de haven: gejuich uit het eigen kamp | A group of small animal soldiers cheering together as a comrade reaches the goal, a short burst of joy, heard from across the field. |

## 14. Gevecht: de details na de klap

| Categorie | Var. | Wanneer | Prompt (EN) |
|---|---|---|---|
| `kogel_zip` | 4 | De musketkogel zoeft langs tijdens zijn vlucht | A musket ball zipping past close by: a short sharp whizz that comes and goes in a fraction of a second. |
| `cannon_echo` | 3 | Na een kanonschot: rollende donder door het dal | The rolling echo of a cannon shot rumbling away through a wide valley like distant thunder, no initial boom, only the long tail. |
| `aarde_regen` | 3 | Na een kanonsinslag: kluiten en gruis die neerkomen | Clods of earth and small stones raining down onto the ground after an explosion, a short pattering shower that thins out. |
| `splinter_regen` | 2 | Na een kanon dat kapotgaat: houtsplinters die neerkletteren | Small pieces of broken wood clattering down onto hard ground after a crash, a light rattling shower. |
| `metaal_tinkel` | 2 | Na een kanon dat kapotgaat: beslag dat natinkelt | Small iron fittings and bolts bouncing and tinkling on hard ground after a cannon breaks apart. |
| `kogel_rol` | 2 | De kanonskogel rolt na de inslag uit | A heavy iron cannonball rolling over packed earth and slowly coming to a stop, a low grinding rumble. |
| `gib_plets` | 4 | Een brokstuk van de gibs komt neer | A small wet chunk falling onto packed earth, a soft heavy plop. |
| `bloed_drup` | 3 | Een gewonde pion bloedt na terwijl hij loopt | A few drops of blood dripping onto dry earth, tiny soft wet taps. |
| `vlieg_zoem` | 2 | Boven de gesneuvelden, zodra de lijken donker worden (zacht) | A few flies buzzing lazily in the warm air, circling close by, soft and continuous. |
| `wrak_knetter` | 2 | Het brandende wrak van een kanon (laag zolang het brandt) | The burning wreck of a wooden cannon carriage: steady crackling and popping of a small wood fire with a soft roar, continuous. |
| `oor_suis` | 1 | Een kanonsinslag vlakbij: kort een piep in je oren | A high thin ringing in the ears after a nearby explosion, starting loud and slowly fading away, with everything else muffled. |

## 15. Spelmomenten die nu stil zijn

| Categorie | Var. | Wanneer | Prompt (EN) |
|---|---|---|---|
| `honger_maag` | 2 | De honger neemt een pion (vanaf cyclus 10) | An empty stomach growling loudly, a long hungry rumble, followed by a weak tired sigh. |
| `buit_vaandel` | 2 | Het vaandel van de vijand is buit (+2 versterkingspunten) | A captured regimental banner snapping in the wind, followed by a short triumphant roll on a military snare drum. |
| `buit_trom` | 2 | De trom van de vijand is buit (+4 CP) | A captured military drum set down hard on a wooden table with a hollow boom, followed by a few coins clinking. |
| `aura_trom` | 3 | Een pion gebruikt het stamina-punt van de trom | A single firm stroke on a military snare drum, crisp, with a short rattle of the snare wires. |
| `aura_vaandel` | 2 | Een pion stapt in het blok om het vaandel (+1 attack) | A cloth banner unfurling with a sudden snap in the wind. |
| `sps_tel` | 3 | Steen-papier-schaar: het aftellen | Three quick knocks of a fist on an oak table, counting down: knock, knock, knock. |
| `sps_onthul` | 2 | Steen-papier-schaar: de handen liggen open | A hand slapped flat onto an oak table with a sharp smack, the game decided. |
| `haven_dreig` | 1 | Een vijand staat een of twee stappen van jouw haven | A slow low war drum beating like a heartbeat, four heavy thumps, ominous and tense. |
| `beurtlicht_aan` | 2 | De laatste pionnen krijgen hun lichtstraal | A soft warm shimmer of tiny brass bells, a gentle glowing chime that rises and fades. |

## 16. Sfeer per diorama (lange lagen onder het spel)

Een laag per diorama (25 s, een take per generatie; het spel kan hem laten
herhalen of na afloop een andere variant kiezen, net als `ambient_field`), plus
het kampvuur dat zacht klinkt zolang het in beeld brandt.

| Categorie | Var. | Wanneer | Prompt (EN) |
|---|---|---|---|
| `sfeer_weidekamp` | 2 | Diorama Weidekamp | Ambience of a quiet army camp in a summer meadow: wind in tall grass, crickets, distant birds, the low murmur of a camp far away, a tent flap now and then. Calm, continuous, no music. |
| `sfeer_boerenerf` | 2 | Diorama Boerenerf | Ambience of a farmyard next to a battlefield: chickens clucking far off, a cow lowing once in the distance, wind through a wooden barn, a creaking gate. Calm, continuous, no music. |
| `sfeer_dorpsrand` | 2 | Diorama Dorpsrand met molen | Ambience at the edge of a small village: the slow creak of windmill sails turning, birds on rooftops, a dog far away, a light breeze. Calm, continuous, no music. |
| `sfeer_na_de_slag` | 2 | Diorama Na de slag | Ambience of a field just after a battle: smoldering fires crackling softly, crows cawing in the distance, a lonely wind, faint groans far away, an eerie stillness. Continuous, no music. |
| `sfeer_winterkamp` | 2 | Diorama Winterkamp | Ambience of a winter army camp in deep snow: a cold howling wind, snow hissing over the ground, a campfire crackling nearby, ice creaking. Continuous, no music. |
| `sfeer_rivierhaven` | 2 | Diorama Rivierhaven | Ambience of a small river harbor: water lapping against a wooden jetty, a moored boat knocking softly, gulls in the distance, ropes creaking. Calm, continuous, no music. |
| `sfeer_bosrand` | 2 | Diorama Bosrand | Ambience at the edge of a forest: leaves rustling in the wind, a woodpecker tapping far away, songbirds, branches creaking. Calm, continuous, no music. |
| `sfeer_kapelruine` | 2 | Diorama Kapelruine | Ambience of a ruined stone chapel on a hill: a hollow wind moaning through broken windows, crows, a loose bell ringing very faintly in the wind. Continuous, no music. |
| `sfeer_marktplein` | 2 | Diorama Marktplein | Ambience of a town market square heard from a distance: the muffled bustle of a crowd without words, cart wheels on cobblestones, a fountain splashing, pigeons. Continuous, no music. |
| `sfeer_egypte` | 2 | Diorama Egypte 1798 | Ambience of a desert army camp in Egypt in 1798: a dry hot wind, sand hissing over dunes, palm leaves rattling, a camel groaning far away. Continuous, no music. |
| `sfeer_alpenpas` | 2 | Diorama Alpenpas | Ambience of a high mountain pass: a strong cold wind, cowbells far down in the valley, an eagle crying once, loose stones trickling. Continuous, no music. |
| `sfeer_waterloo` | 2 | Diorama Hoeve van Waterloo | Ambience of a farm near Waterloo before a battle: a grey drizzle on a farmhouse roof, distant drums of many regiments, a wet wind, a dog barking once. Continuous, no music. |
| `sfeer_kampvuur` | 2 | Zacht bij het kampvuur in het kamp, zolang het brandt | A small campfire burning steadily close by: soft crackles, pops and the hiss of a damp log. Continuous, no music. |

## 17. Accenten in de verte (los, af en toe een)

Om de 20 tot 60 seconden een, zacht en willekeurig links of rechts; zo leeft
de wereld om het bord zonder dat je het merkt. Per diorama een eigen mengsel
(geen kerkklok in Egypte, wel in de Kapelruine).

| Categorie | Var. | Wanneer | Prompt (EN) |
|---|---|---|---|
| `ver_kanon` | 3 | Een andere slag, ver weg | A single cannon shot from another battle far away, a deep dull thud rolling across the hills, heard from far away. |
| `ver_trom` | 2 | Een ander regiment marcheert in de verte | A military drum march heard far away across the fields, a few bars of steady snare and bass drum, slowly fading. |
| `ver_klok` | 2 | Een dorpskerk slaat (Dorpsrand, Kapelruine, Marktplein) | A village church bell striking three times far away. |
| `ver_hond` | 3 | Een hond blaft in de verte | A dog barking twice far away, soft and muffled, natural outdoor echo. |
| `ver_bijl` | 2 | Iemand hakt hout in de verte | Someone chopping wood far away, three slow dull axe blows on a log. |
| `ver_hoorn` | 2 | Een signaalhoorn in de verte | A brass bugle call sounding far away, one short signal of a few notes. |
| `ver_vogels` | 3 | Een zwerm vogels vliegt op | A flock of small birds taking off together from a nearby tree, a flurry of wings and chirps. |
| `ver_kraai` | 3 | Een kraai in een boom verderop | A crow cawing twice from a tree a little way off. |
| `ver_kamp` | 2 | Het kamp achter je: pannen, een hamer, gelach | The muffled sounds of a busy army camp in the distance: a pot clanging, a hammer on a tent peg, a laugh without words. |
| `ver_donder` | 2 | Onweer achter de heuvels | Thunder rumbling far away beyond the hills, a long low roll. |

## 18. Weer en echo

| Categorie | Var. | Wanneer | Prompt (EN) |
|---|---|---|---|
| `weer_regen` | 2 | Een potje met regen (laag, samen met de regen-VFX) | Steady light rain falling on grass and on a wooden table, soft pattering drops, continuous. No thunder, no music. |
| `weer_wind_vlaag` | 3 | Een windvlaag: de vlaggen wapperen even harder | A single strong gust of wind sweeping across open grass, rising and falling away. Outdoors, no music. |
| `weer_onweer` | 2 | Onweer dichtbij, met de bliksem-VFX | A close thunderclap: a sharp crack followed by a long heavy rumble that rolls away. Outdoors, no music. |

**Echo zonder opname:** een galm per diorama (lang in de Alpenpas en de
Kapelruine, kort in het Bosrand, droog op het Marktplein) kan ook als
effect op de geluidsbus, zonder bestanden; `musket_echo` en `cannon_echo`
blijven de staart die je bewust hoort.

## ElevenLabs SFX-prompts (kopieer-klaar)

Voor **ElevenLabs → Sound Effects**. Tips die de kwaliteit sterk verhogen:
- **Engels** werkt het best; benoem het **materiaal** en het **karakter** (kort, dof, ...).
- **Duration**: zet hem op ~5-8s en vraag om **zes korte takes achter elkaar**
  (recept §0); je knipt ze uit en nummert ze. Voor eenmalige dingen (fanfare,
  loop) gewoon een take en de echte lengte.
- **Prompt influence hoog** (~80-100%) voor strak, voorspelbaar resultaat.
- Voor varianten: **genereer 3-5×** met dezelfde prompt en pak de beste — dat is
  precies waarvoor de categorieën meerdere bestanden hebben.

> **Stijlregel — 18e/19e-eeuws, diegetisch.** ÁLLE geluiden komen uit die wereld:
> **hout** (spelstukken, musketkolf, affuit, tafel, kist), **smeedijzer / messing /
> koper** (kanonloop, bajonet, sabel, gesp, mechaniek, klok, bel), **zwartkruit**
> (schoten, ontbranding), **canvas / leer / wol** (uniform, tas, laarzen),
> **perkament / papier** (kaarten, bevelen), **munten / messing gewichten** (tellers).
> **Géén** digitale, elektronische of synth-geluiden — ook de menu-UI niet. Elke prompt
> hieronder eindigt daarom bewust op materiaal + tijdperk.

Alle prompts in één tabel (⭐ = zit in het spel · "(uit)" = bestand er maar
tijdelijk gedempt · geen ster = nog te maken):

| Categorie | # var | ElevenLabs prompt (EN) |
|---|---|---|
| `ui_click` ⭐ | 3 | single soft wooden button press, muted tap on oak, no reverb, dry |
| `ui_back` ⭐ | 2 | small wooden drawer sliding shut, soft low knock, aged oak |
| `ui_hover` ⭐ | 2 | faint short parchment rustle, very quiet, dry |
| `ui_error` ⭐ | 2 | dull hollow wooden thunk, muffled negative knock, no tone |
| `ui_toggle` ⭐ | 1 | small brass latch flipping, crisp metal click, antique fitting |
| `ui_open` ⭐ | 1 | rolled parchment unfurling with a soft wooden case lid opening, short |
| `ui_plof` ⭐ | 3 | A small wooden peg popping into a hole in an old oak game board: one short, soft, round tok with a tiny upward lift, dry and close, no reverb. |
| `ui_stempel` ⭐ | 3 | A wooden hand stamp pressed firmly onto parchment with a little sealing wax: one dull, solid thud with a short papery slap, dry and close. |
| `ui_draai` ⭐ | 3 | A single stiff parchment playing card flipped over on a wooden table: a quick short paper flick and the soft tap of its edge landing. |
| `ui_tel` ⭐ | 3 | One tiny brass counter bead clicking against another on an old abacus: a very short, bright little tick, dry. |
| `ui_munt` ⭐ | 3 | A single small brass coin dropped onto an oak table: a clear short ring with one tiny bounce, dry and close. |
| `ui_blad` ⭐ | 3 | One page of thick old parchment turned over in a leather-bound book: a soft short rustle that swells and settles, dry and close. |
| `ui_knop` ⭐ | 3 | A wooden game piece pressed down onto an oak board: a very short, soft and dull little tok, lower and quieter than a click, dry and close. |
| `card_stat_up` ⭐ | 3 | small brass weight set on a balance scale, short bright metallic tick, rising |
| `card_stat_down` ⭐ | 3 | small brass weight lifted off a balance scale, short dull metallic tick, falling |
| `card_confirm` ⭐ | 2 | thick parchment card slapped onto a wooden table, wax seal press, firm |
| `card_deal` ⭐ | 2 | single stiff parchment card dealt off a stack onto oak, quick flick |
| `card_select` ⭐ | 3 | parchment card lifted off a wooden table, soft paper scrape |
| `link_snap` ⭐ | 3 | brass buckle and iron latch snapping shut, firm metallic lock-in, short |
| `reveal` ⭐ | 2 | short military field snare drum roll, black powder era, tension release, brief |
| `initiative` ⭐ (uit) | 1 | single bright brass bugle note, short call to attention, 18th century |
| `phase_change` ⭐ | 2 | soft wooden fife and light snare tap transition, brief, period military |
| `cycle_start` ⭐ | 1 | brass horn call with a bass drum hit, new campaign round, short fanfare |
| `your_turn` ⭐ (uit) | 1 | single small brass hand bell chime, gentle notification, dry |
| `place_pawn` ⭐ | 4 | carved wooden game piece set firmly on a wooden board, dull hollow thud |
| `place_undo` | 2 | wooden game piece lifted off a wooden board, soft scrape and pick up |
| `musket_cock` ⭐ | 2 | flintlock musket hammer cocking back, crisp double metal click, 18th century |
| `horse_select` ⭐ | 3 | warhorse snorting and shifting, bridle and leather tack jingle, brief |
| `cannon_select` ⭐ | 3 | heavy cast iron cannon barrel creaking on a wooden carriage, brass fitting clank, short |
| `cannon_fuse` ⭐ | 2 | cannon fuse hissing and sputtering, black powder wick burning, short |
| `cannon_lontstok` ⭐ | 3 | gunner pressing a smoldering linstock onto the touch hole of a bronze cannon, light iron tap and a short priming powder fizz, no explosion |
| `inf_select` ⭐ | 3 | soldier shouldering a wooden musket, canvas and leather strap rustle, short |
| `deselect` ⭐ | 1 | soft low wooden tap, gentle release, dry |
| `step` ⭐ | 4 | single boot step on dry earth, leather sole, marching infantry, dry |
| `horse_move` ⭐ | 2 | warhorse galloping a few steps on soil, hooves and tack, brief |
| `cannon_move` ⭐ | 4 | heavy cannon wheels rolling one turn on dirt, creaking wood and iron, short |
| `musket_fire` ⭐ | 3 | black powder musket shot, sharp crack and powder flash, 18th century |
| `musket_echo` ⭐ | 6 | distant musket shot echo rolling across an open field, black powder |
| `musket_hit` ⭐ | 3 | musket ball impact, wet flesh and dust thud, black powder era |
| `cannon_fire` ⭐ | 3 | heavy black powder cannon firing, deep boom and powder blast |
| `cannon_air` ⭐ | 4 | cast iron cannonball whistling through the air, low ominous whoosh |
| `cannon_hit` ⭐ | 3 | heavy cast iron cannonball impact, wood splinter and dirt burst |
| `melee_kill` ⭐ | 3 | bayonet and sabre killing blow, steel stab and body fall, 18th century |
| `melee_survive` ⭐ | 3 | bayonet and sabre steel parry clang, blade blocked, no kill, 18th century |
| `blood_splash` ⭐ | 3 | small wet blood splatter, non-lethal hit on a living soldier, short |
| `retaliation_horse` ⭐ | 1 | warhorse rearing and kicking back in retaliation, hooves and whinny, short |
| `retaliation` ⭐ | 1 | quick steel-on-steel counterstrike clang with a soldier grunt, short |
| `charge_yell` ⭐ | 1 | cavalry battle cry, men shouting a charge over galloping hooves, brief |
| `pawn_block` 🎚️ | 2 | musket ball thudding into a thick wooden shield, blocked shot |
| `horse_die` ⭐ | 2 | warhorse falling and dying on a battlefield, heavy body thud, brief |
| `inf_die` ⭐ | 4 | short soldier death cry, body and wooden musket clattering to the ground, black powder era |
| `cannon_die` ⭐ | 2 | cannon carriage destroyed, splintering wood and cracking cast iron, short |
| `timer_tick` ⭐ | 1 | single soft antique pendulum clock tick, brass and wood, subtle |
| `timer_warning` ⭐ (uit) | 1 | faster tense antique clock tick, brass mechanism, single, urgent |
| `timer_timeout` | 1 | dull brass bell toll, time is up, single somber strike |
| `haven_score` ⭐ | 2 | bright short brass hand bell flourish, objective reached, triumphant |
| `win_fanfare` ⭐ | 1 | short victorious period military brass fanfare with snare drum, triumphant, ~2 seconds |
| `lose_sting` ⭐ | 1 | short somber descending brass and low drum, defeat, minor key, 18th century |
| `wolf_step` | 2 | quick stealthy leather boot step and canvas whoosh, light sneak |
| `music_menu` | 1 loop | calm looping menu music, soft period strings and light military snare drum, 18th century, seamless loop |
| `music_battle` ⭐ | 2 | subtle looping battle bed, marching snare drum, low period strings and distant brass, tense but soft, loop |
| `ambient_field` ⭐ | 3 | quiet open battlefield wind, distant black powder rumble and field ambience, seamless loop |

---

## Prioriteit (mijn advies)

1. **Levendigheid nu, goedkoop:** extra varianten voor de losse 1-samples
   (`ui_click`, `musket_hit`, `cannon_hit`, `melee_survive`) — meteen minder ratel.
2. **Meest gevoelde gaten:** `place_pawn`, `card_stat_up/down`, `link_snap`,
   `inf_die`, `retaliation`, `your_turn`.
3. **Sfeer-boost:** `reveal`/`cycle_start`, `charge_yell`, `win_fanfare`/`lose_sting`.
4. **Timer-set** zodra je merkt dat mensen de klok missen.
5. **Materiaal-inslagen** (7c): grootste klap-per-euro na de losse varianten --
   zes prompts dekken elk gevecht in het spel.
6. **Factie-sterfgeluiden** (7b): het lekkerste maar ook het grootste blok
   (18 prompts x 5). Begin met de infanterie van de facties die je het meest
   speelt; de terugval dekt de rest.
7. **Muziek** het laatst (en als OGG, niet WAV).

## Naamconventie & inbouwen

- Bestand: `sounds/<categorie><nr>.wav` (bv. `place_pawn2.wav`), `snake_case`.
- Factie-varianten: `sounds/<categorie>_<factie><nr>.wav` (bv.
  `inf_die_mouse3.wav`). Aanroepen via `Audio.play_factie("inf_die", doctrine)`;
  ontbreekt de factie-categorie, dan klinkt automatisch het algemene geluid.
- Nieuwe categorie toevoegen = 2 regels in `audio_manager.gd`
  (`BANK` + `CATEGORY_DB`) en één `Audio.play("...")` op de juiste plek.
- Korte SFX → **WAV** (nul latency); alleen muziek/ambient → **OGG**.
- Draai `--import` (of open het project) nadat je bestanden toevoegt.

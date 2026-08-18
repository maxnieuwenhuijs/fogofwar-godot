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
| `ui_error` | `ui_error.wav` | 1 | Pion die niet kan handelen | ✓ |
| `ui_toggle` | `ui_toggle.wav` | 1 | Speluitleg-tab wisselen | ✓ |
| `ui_open` | `ui_open.wav` | 2 | Overlay/uitleg opent | ✓ |

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
| `cannon_fire` | `cannon_heavy*.wav` | 3 | Kanon afvuren | ✓ |
| `cannon_air` | `cannon_bal_flies*.wav` | 4 | Kogel door de lucht | ✓ |
| `cannon_hit` | `cannon_ball_hit.wav` | 2-3 | Kanonskogel inslag | ✓ 🎚️ (nu 1) |
| `melee_kill` | `mellee_hit*.wav` | 3 | Melee doodt het doelwit | 6 short bayonet stabs into a body in a row, each about 0.3 seconds, wet punch with a steel scrape, silence between each, dry close mono, no reverb, no music |
| `melee_survive` | `mellee_hit_no_kill.wav` | 2-3 | Doelwit overleeft de klap | 6 short steel-on-steel parry clangs in a row, each about 0.3 seconds, bright and blocked, silence between each, dry close mono, no reverb, no music |
| `retaliation` | `retaliation.wav` | 1 | Terugslag door infanterie (staal-op-staal) | 3 short steel counterstrike clangs with a single male grunt in a row, each about 0.4 seconds, silence between each, dry close mono, no reverb, no music |
| `retaliation_horse` | `retaliation_with_horse.wav` | 1 | Terugslag door een paard (hoeven) | ✓ |
| `blood_splash` | `small_blood_splash*.wav` | 3 | Levend stuk overleeft een treffer | 6 short wet blood splatters in a row, each about 0.25 seconds, silence between each, dry close mono, no reverb, no music |
| `charge_yell` | `charge_yell.wav` | 1 | Cavalerie begint een charge (strijdkreet) | 3 short male battle shouts in a row, each about 0.6 seconds, hoarse and forward, silence between each, a few men only, dry close mono, no reverb, no music |
| `pawn_block` | `pawn_block.wav` | 2 | Schot geblokkeerd (bank klaar; nog geen event) | 3 short musket ball thuds into thick wood in a row, each about 0.3 seconds, blocked and dull, silence between each, dry close mono, no reverb, no music |

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
| Cavalerie (big bro) | `horse_die` | `horse_die_<factie>` | 5 |
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

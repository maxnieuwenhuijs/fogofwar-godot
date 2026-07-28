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
| `musket_hit` | `default_musket_hit.wav` | 2-3 | Kogel slaat in | ✓ 🎚️ (nu 1) |
| `cannon_fire` | `cannon_heavy*.wav` | 3 | Kanon afvuren | ✓ |
| `cannon_air` | `cannon_bal_flies*.wav` | 4 | Kogel door de lucht | ✓ |
| `cannon_hit` | `cannon_ball_hit.wav` | 2-3 | Kanonskogel inslag | ✓ 🎚️ (nu 1) |
| `melee_kill` | `mellee_hit*.wav` | 3 | Melee doodt het doelwit | ✓ |
| `melee_survive` | `mellee_hit_no_kill.wav` | 2-3 | Doelwit overleeft de klap | ✓ 🎚️ (nu 1) |
| `retaliation` | `retaliation.wav` | 1 | Terugslag door infanterie (staal-op-staal) | ✓ |
| `retaliation_horse` | `retaliation_with_horse.wav` | 1 | Terugslag door een paard (hoeven) | ✓ |
| `blood_splash` | `small_blood_splash*.wav` | 3 | Levend stuk overleeft een treffer | ✓ |
| `charge_yell` | `charge_yell.wav` | 1 | Cavalerie begint een charge (strijdkreet) | ✓ |
| `pawn_block` | `pawn_block.wav` | 2 | Schot geblokkeerd (bank klaar; nog geen event) | 🎚️ (klaar) |

## 7. Sterven per type

| Categorie | Bestanden | # var | Wanneer | Status |
|---|---|---|---|---|
| `horse_die` | `horse_die*.wav` | 2 | Cavalerie sneuvelt | ✓ |
| `inf_die` | `inf_die*.wav` | 4 | Infanterie sneuvelt | ✓ |
| `cannon_die` | `cannon_destroyed.wav` | 1 | Kanon vernietigd | ✓ |

## 7b. Sterven per FACTIE (besluit Max, 28 juli)

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
| Muis | hoge, korte piep -- klein en schril | zwaardere knaagdier-krijs (oorlogskonijn) |
| Varken | schril gilletje met een snuivende uithaal | diep everzwijn-gebrul, snuivend |
| Leeuw | cheetah: korte hoge tjilp/sis | leeuw: rollende brul die wegzakt |
| Beer | wasbeer: ratelend gekrijs | grizzly: laag, borstelig gebrul |
| Wolf | vos: die beruchte doordringende schreeuw | dire wolf: afgebroken huil/jank |
| Krokodil | hagedis: blazende sis die stikt | krokodil: dreunende bulderende bel |

### Prompts -- sterfgeluiden per factie (18 prompts, elk 5x genereren)

Duration 0.6-1.2s, prompt influence hoog. Steeds hetzelfde raamwerk: **dier +
val van het lijf + materiaal** (uniform, leer, staal, hout), 18e/19e-eeuws,
geen synth.

| Bestand | Prompt |
|---|---|
| `inf_die_mouse` ✓ (2) | Tiny animal death squeak, high-pitched and short, cut off abruptly, followed by a small body collapsing into wool uniform cloth and a light musket clattering on dirt. Dry, close, no reverb tail, no music. |
| `horse_die_mouse` | Large rodent war-beast death cry, sharp and rattling, dropping in pitch, with heavy thudding of a big body falling onto dirt and leather harness creaking. Dry and close, no music. |
| `cannon_die_mouse` | Small field cannon destroyed: splintering wood, iron fittings snapping, a tiny high-pitched animal yelp cut short, gravel and dust settling. Dry, no music. |
| `inf_die_pig` | Pig death squeal, shrill and snorting, breaking into a wet gurgle, then a heavy round body slumping into wool cloth and a musket hitting the ground. Dry and close, no music. |
| `horse_die_pig` | Wild boar death roar, deep and snorting, ending in a rattling exhale, with a massive body crashing onto dirt and leather straps snapping. Dry, heavy, no music. |
| `cannon_die_pig` | Heavy field cannon destroyed: thick oak carriage splitting, iron bands popping, a short pig grunt cut off, debris raining down. Dry, no music. |
| `inf_die_lion` | Cheetah death chirp, high and strangled, ending in a hiss, with a lean body dropping onto dirt and gold-braided uniform cloth rustling. Dry and close, no music. |
| `horse_die_lion` | Lion death roar, full-throated and rolling, collapsing into a wet growl, with a huge body thudding onto dirt and heavy leather harness creaking. Dry, no music. |
| `cannon_die_lion` | Ornate field gun destroyed: brass fittings ringing as they snap, walnut carriage splintering, a short feline snarl cut off, dust settling. Dry, no music. |
| `inf_die_bear` | Raccoon death screech, rattling and chattering, breaking off suddenly, with a stocky body falling into wool cloth and a steel cuirass clanging on dirt. Dry and close, no music. |
| `horse_die_bear` | Grizzly bear death roar, low and chesty, fading into a wet rumble, with an enormous body crashing to the ground and iron-studded leather groaning. Dry, no music. |
| `cannon_die_bear` | Heavy mortar destroyed: thick iron cracking, oak block carriage bursting apart, a short bear grunt cut off, heavy debris thudding. Dry, no music. |
| `inf_die_wolf` | Fox death scream, piercing and eerie, cut off mid-cry, with a light body dropping onto dirt and patched wool and fur rustling. Dry and close, no music. |
| `horse_die_wolf` | Dire wolf death howl, broken and yelping, dropping into a growl, with a large body hitting the ground and rope-and-leather harness snapping. Dry, no music. |
| `cannon_die_wolf` | Scavenged field gun destroyed: mismatched scrap iron clattering, cracked wood splitting, a short canine yelp cut off, loose parts rolling away. Dry, no music. |
| `inf_die_crocodile` | Lizard death hiss, sharp and sputtering, choking off into silence, with a scaled body slapping onto wet dirt and damp camouflage cloth dragging. Dry and close, no music. |
| `horse_die_crocodile` | Crocodile death bellow, deep booming and guttural, ending in a hissing exhale, with an armored body slamming into wet ground and heavy tail thumping. Dry, no music. |
| `cannon_die_crocodile` | Swamp-wrapped field gun destroyed: iron cracking under damp cloth, waterlogged wood splitting, a short reptilian hiss cut off, wet debris slapping down. Dry, no music. |

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
| `val_prop` | 3 | terugval voor alles | Wooden and iron object clattering onto packed dirt, a dull knock with a short metallic rattle, dry and close, no music. |
| `val_musket` | 3 ✓ (2) | musket | Musket falling onto dirt, heavy wooden stock thudding with an iron barrel rattle, dry and close, no music. |
| `val_drum` | 3 | trommel | Military side drum dropping onto the ground, a hollow booming thump with rope and rattling snares, dry, no music. |
| `val_flag` | 2 | vaandelstok | Long wooden flag pole clattering onto dirt, a hard hollow knock and heavy cloth flapping down, dry, no music. |
| `val_horn` | 2 | hoorn | Small brass bugle dropping onto packed dirt, a bright metallic clank with a faint ringing tone, dry, no music. |
| `val_sapper` | 2 | bijl | Heavy axe dropping onto dirt, a dull wooden haft thud and a broad iron head clanking, dry, no music. |
| `val_hoed` | 2-3 ✓ (1) | shako/hoedje dat afvliegt | Stiff felt shako hat landing on packed dirt, a soft muffled flop with a light leather strap slap, dry and close, no music. |
| `val_canteen` | 2 | vaatje | Small wooden keg dropping and rolling on dirt, hollow wooden thuds with liquid sloshing inside, dry, no music. |

## 7c. Inslag-geluiden per MATERIAAL (algemeen, factie-onafhankelijk)

De klap zelf hoort bij het MATERIAAL dat geraakt wordt, niet bij de factie.
Deze laag maakt het verschil tussen "er gebeurt iets" en "dat deed pijn":
vlees klinkt nat, staal klinkt hard, hout klinkt dof.

| Categorie | # var | Wanneer | Status |
|---|---|---|---|
| `impact_flesh` | 5 | Treffer op een levend stuk (nat, doffe plof) | ➕ |
| `impact_armor` | 5 | Treffer op kuras/helm (harde metalen tik) | ➕ |
| `impact_wood` | 4 | Treffer op musketkolf, affuit, schild (dof hout) | ➕ |
| `impact_bone` | 3 | Botbreuk bij een dodelijke melee-klap (kort, krakend) | ➕ |
| `impact_dirt` | 4 | Mis: kogel slaat in de grond (aarde + steentjes) | ➕ |
| `ricochet` | 4 | Kogel ketst af op steen/ijzer (zingende afketser) | ➕ |
| `blood_splash` | 3 | Bloedspat bij een treffer | ✓ (heb je al) |
| `body_fall` | 2-4 | Het LIJF raakt de grond (timing per dood-clip uit `death_pools`) | ✓ (2) 🎚️ |

### Prompts -- materiaal-inslagen

Duration 0.3-0.8s, kort en droog.

| Bestand | Prompt |
|---|---|
| `impact_flesh` | Wet heavy impact on flesh, a dull meaty thud with a short liquid splatter, close and dry, no reverb, no music. |
| `impact_armor` | Musket ball striking a steel cuirass, a hard bright metallic clank with a short ringing decay, close and dry, no music. |
| `impact_wood` | Musket ball smashing into a thick oak musket stock, a dull heavy wooden knock with splintering, close and dry, no music. |
| `impact_bone` | Sharp bone crack under a heavy blow, a short dry snap muffled by cloth, close, no reverb, no music. |
| `impact_dirt` | Musket ball slamming into packed dirt, a dull thud with a spray of soil and small pebbles, dry and close, no music. |
| `ricochet` | Musket ball ricocheting off stone, a bright metallic whine spinning away into the distance, dry, no music. |

**Wanneer welke:** de engine kent het type van het doelwit. Vuistregel voor de
inbouw: infanterie/cavalerie geraakt -> `impact_flesh` (+ `blood_splash`);
gepantserd (hp-archetype met kuras) -> `impact_armor`; artillerie geraakt ->
`impact_wood`; dodelijke melee -> `impact_bone` erbij; schot dat mist of
geblokkeerd wordt -> `impact_dirt` / `ricochet`.

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
- **Duration kort** houden (UI: 0.2-0.5s, klappen/schoten: 0.4-1s, fanfare: 1.5-3s).
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

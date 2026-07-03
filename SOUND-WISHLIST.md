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
| `ui_click` | `ui_click.wav` | 2-3 | Elke menuknop, kaart-tap, bevestigen | ✓ 🎚️ (nu 1) |
| `ui_back` | `ui_back.wav` | 1-2 | Terug/annuleren/sluiten (zachter, lager dan click) | ➕ |
| `ui_hover` | `ui_hover.wav` | 1-2 | Muis over een knop/pion (héél subtiel, kort tikje) | ➕ |
| `ui_error` | `ui_error.wav` | 1-2 | Ongeldige actie / geweigerde zet ("dof" buzz) | ➕ |
| `ui_toggle` | `ui_toggle.wav` | 1 | Speluitleg-tab wisselen, mute aan/uit | ➕ |
| `ui_open` | `ui_open.wav` | 1 | Overlay/scherm opent (whoosh/opdoeken) | ➕ |

## 2. Kaarten definiëren & koppelen

| Categorie | Bestanden | # var | Wanneer | Status |
|---|---|---|---|---|
| `card_stat_up` | `card_stat_up.wav` | 2-3 | + op een stat (korte, oplopende blip) | ➕ |
| `card_stat_down` | `card_stat_down.wav` | 2-3 | − op een stat (aflopende blip) | ➕ |
| `card_confirm` | `card_confirm.wav` | 1-2 | Kaarten bevestigd (papier/klap) | ➕ (nu `ui_click`) |
| `card_deal` | `card_deal.wav` | 3-4 | Kaart verschijnt/legt neer in de waaier | ➕ |
| `card_select` | `card_select.wav` | 2-3 | Kaart aantikken bij het koppelen | ➕ (nu `ui_click`) |
| `link_snap` | `link_snap.wav` | 2-3 | Kaart koppelt aan een pion (klik-vast, "power-up") | ➕ |

## 3. Onthulling & fase-flow

| Categorie | Bestanden | # var | Wanneer | Status |
|---|---|---|---|---|
| `reveal` | `reveal.wav` | 1-2 | Kaarten van beide spelers onthuld (fanfare-tikje / trommel) | ➕ |
| `initiative` | `initiative.wav` | 1 | Wie het initiatief pakt (kort signaal) | ➕ |
| `phase_change` | `phase_change.wav` | 1-2 | Nieuwe ronde/fase begint (zachte overgang) | ➕ |
| `cycle_start` | `cycle_start.wav` | 1 | Nieuwe cyclus (trommelroffel / hoornstoot) | ➕ |
| `your_turn` | `your_turn.wav` | 1 | Jouw beurt begint in de actiefase (subtiele bel) | ➕ |

## 4. Opstellen

| Categorie | Bestanden | # var | Wanneer | Status |
|---|---|---|---|---|
| `place_pawn` | `place_pawn.wav` | 3-4 | Pion neerzetten op een vak (doffe "tik"/plof) | ➕ |
| `place_undo` | `place_undo.wav` | 1-2 | Ongedaan maken (omgekeerde plof) | ➕ |

## 5. Selectie & beweging per type (deels aanwezig)

| Categorie | Bestanden | # var | Wanneer | Status |
|---|---|---|---|---|
| `musket_cock` | `cockhammer.wav` | 1-2 | Infanterie geselecteerd die kan schieten | ✓ 🎚️ |
| `horse_select` | `horse_select*.wav` | 3 | Cavalerie geselecteerd | ✓ |
| `cannon_select` | `cannon_select.wav` | 1-2 | Artillerie geselecteerd (metaal/richten) | ➕ |
| `inf_select` | `inf_select.wav` | 1-2 | Infanterie zónder schot geselecteerd (nu stil) | ➕ |
| `deselect` | `deselect.wav` | 1 | Pion deselecteren (rechtermuis) | ➕ |
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
| `retaliation` | `retaliation.wav` | 2 | Terugslag raakt de aanvaller (metaal-clang/kreet) | ➕ |
| `charge_yell` | `charge_yell.wav` | 2-3 | Cavalerie begint een charge (strijdkreet) | ➕ |
| `pawn_block` | `pawn_block.wav` | 1-2 | Schot geblokkeerd door een tussenpion (optioneel) | ➕ |

## 7. Sterven per type

| Categorie | Bestanden | # var | Wanneer | Status |
|---|---|---|---|---|
| `horse_die` | `horse_die*.wav` | 2 | Cavalerie sneuvelt | ✓ |
| `inf_die` | `inf_die*.wav` | 3-4 | Infanterie sneuvelt (korte kreet/val) | ➕ |
| `cannon_die` | `cannon_die*.wav` | 2 | Kanon vernietigd (hout/metaal-splinter) | ➕ |

## 8. Beurt-timer

| Categorie | Bestanden | # var | Wanneer | Status |
|---|---|---|---|---|
| `timer_tick` | `timer_tick.wav` | 1 | Laatste ~5 sec, per seconde (subtiele tik) | ➕ |
| `timer_warning` | `timer_warning.wav` | 1 | ~3 sec resterend (urgenter) | ➕ |
| `timer_timeout` | `timer_timeout.wav` | 1 | Tijd om, spel neemt over | ➕ |

## 9. Uitkomst & mijlpalen

| Categorie | Bestanden | # var | Wanneer | Status |
|---|---|---|---|---|
| `haven_score` | `haven_score.wav` | 1-2 | Pion bereikt de haven (1 van de 2 nodig) | ➕ |
| `win_fanfare` | `win_fanfare.wav` | 1 | Jij wint (korte triomf-sting) | ➕ |
| `lose_sting` | `lose_sting.wav` | 1 | Je verliest (aflopende mineur) | ➕ |
| `wolf_step` | `wolf_step.wav` | 1-2 | Gratis Wolf-stap uitgevoerd (sluip/whoosh) | ➕ (optioneel) |

## 10. Sfeer / muziek (optioneel, laagste prioriteit)

| Categorie | Bestanden | # var | Wanneer | Status |
|---|---|---|---|---|
| `music_menu` | `music_menu.ogg` | 1 loop | Hoofdmenu (rustig, **OGG** i.p.v. WAV: lang bestand) | ➕ |
| `music_battle` | `music_battle.ogg` | 1 loop | In-game bed (zacht, marcherend) | ➕ |
| `ambient_field` | `ambient_field.ogg` | 1 loop | Wind/veld onder het spel (heel zacht) | ➕ |

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

**Interface** — geen synth; houten knoppen, messing beslag, perkament
```
ui_click    — single soft wooden button press, muted tap on oak, no reverb, dry
ui_back     — small wooden drawer sliding shut, soft low knock, aged oak
ui_hover    — faint short parchment rustle, very quiet, dry
ui_error    — dull hollow wooden thunk, muffled negative knock, no tone
ui_toggle   — small brass latch flipping, crisp metal click, antique fitting
ui_open     — rolled parchment unfurling with a soft wooden case lid opening, short
```

**Kaarten** — perkament, was, messing gewichten
```
card_stat_up   — small brass weight set on a balance scale, short bright metallic tick, rising
card_stat_down — small brass weight lifted off a balance scale, short dull metallic tick, falling
card_confirm   — thick parchment card slapped onto a wooden table, wax seal press, firm
card_deal      — single stiff parchment card dealt off a stack onto oak, quick flick
card_select    — parchment card lifted off a wooden table, soft paper scrape
link_snap      — brass buckle and iron latch snapping shut, firm metallic lock-in, short
```

**Onthulling & flow** — militaire trom, koperen hoorn/bugel, tinnen bel
```
reveal       — short military field snare drum roll, black powder era, tension release, brief
initiative   — single bright brass bugle note, short call to attention, 18th century
phase_change — soft wooden fife and light snare tap transition, brief, period military
cycle_start  — brass horn call with a bass drum hit, new campaign round, short fanfare
your_turn    — single small brass hand bell chime, gentle notification, dry
```

**Opstellen** — houten stuk op houten bord
```
place_pawn — carved wooden game piece set firmly on a wooden board, dull hollow thud
place_undo — wooden game piece lifted off a wooden board, soft scrape and pick up
```

**Selectie** — hout, ijzer, canvas/leer
```
cannon_select — heavy cast iron cannon barrel creaking on a wooden carriage, brass fitting clank, short
inf_select    — soldier shouldering a wooden musket, canvas and leather strap rustle, short
deselect      — soft low wooden tap, gentle release, dry
```

**Gevecht (extra bij het bestaande)** — zwartkruit, staal, gietijzer, hout
```
musket_hit_var    — musket ball impact, wet flesh and dust thud, black powder era
cannon_hit_var    — heavy cast iron cannonball impact, wood splinter and dirt burst
melee_survive_var — bayonet and sabre steel parry clang, blade blocked, no kill, 18th century
retaliation       — quick steel-on-steel counterstrike clang with a soldier grunt, short
charge_yell       — cavalry battle cry, men shouting a charge over galloping hooves, brief
pawn_block        — musket ball thudding into a thick wooden shield, blocked shot
```

**Sterven** — soldaat, hout+ijzer
```
inf_die    — short soldier death cry, body and wooden musket clattering to the ground, black powder era
cannon_die — cannon carriage destroyed, splintering wood and cracking cast iron, short
```

**Timer** — antiek uurwerk, koperen bel
```
timer_tick    — single soft antique pendulum clock tick, brass and wood, subtle
timer_warning — faster tense antique clock tick, brass mechanism, single, urgent
timer_timeout — dull brass bell toll, times up, single somber strike
```

**Uitkomst** — koperen fanfare, trom
```
haven_score  — bright short brass hand bell flourish, objective reached, triumphant
win_fanfare  — short victorious period military brass fanfare with snare drum, triumphant, ~2 seconds
lose_sting   — short somber descending brass and low drum, defeat, minor key, 18th century
wolf_step    — quick stealthy leather boot step and canvas whoosh, light sneak
```

**Muziek/ambient (langer; genereer of componeer als OGG-loop)** — periode-instrumenten
```
music_menu    — calm looping menu music, soft period strings and light military snare drum, 18th century, seamless loop
music_battle  — subtle looping battle bed, marching snare drum, low period strings and distant brass, tense but soft, loop
ambient_field — quiet open battlefield wind, distant black powder rumble and field ambience, seamless loop
```

---

## Prioriteit (mijn advies)

1. **Levendigheid nu, goedkoop:** extra varianten voor de losse 1-samples
   (`ui_click`, `musket_hit`, `cannon_hit`, `melee_survive`) — meteen minder ratel.
2. **Meest gevoelde gaten:** `place_pawn`, `card_stat_up/down`, `link_snap`,
   `inf_die`, `retaliation`, `your_turn`.
3. **Sfeer-boost:** `reveal`/`cycle_start`, `charge_yell`, `win_fanfare`/`lose_sting`.
4. **Timer-set** zodra je merkt dat mensen de klok missen.
5. **Muziek** het laatst (en als OGG, niet WAV).

## Naamconventie & inbouwen

- Bestand: `sounds/<categorie><nr>.wav` (bv. `place_pawn2.wav`), `snake_case`.
- Nieuwe categorie toevoegen = 2 regels in `audio_manager.gd`
  (`BANK` + `CATEGORY_DB`) en één `Audio.play("...")` op de juiste plek.
- Korte SFX → **WAV** (nul latency); alleen muziek/ambient → **OGG**.
- Draai `--import` (of open het project) nadat je bestanden toevoegt.

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

# Fog of War

Tactisch 3D-bordspel in **Godot 4.7** (Forward+, portrait 1080×1920) met
dierenfacties, mist en een campagne. Een duel gaat over 11×11: breng 2 pionnen
naar de haven aan de overkant, of veeg het vijandelijke leger van het bord.

De campagne is het spel; een los 1v1 is dezelfde economie in het klein. Er is
bewust maar één regelset (besluit C17).

## Kern van het spel

- **Kaart-gedreven activatie**: per cyclus definieer je blind kaarten
  (HP / Speed / Aanval, som = je budget) en koppel je ze aan pionnen.
  Pionnen zonder kaart "slapen" en sterven aan één treffer.
- **Drie eenheidstypes**: infanterie (melee + schot op afstand 2), cavalerie
  (charge: lopen + slaan in één beurt, springt over eigen pionnen) en artillerie
  (vaste dracht 6, dode zone op afstand 1).
- **Geen gelijkspel** (regel V0): een duel eindigt op de haven of op eliminatie.
  Vanaf cyclus 10 knaagt de honger — elke speler verliest bij het begin van een
  cyclus de pion die het verst van zijn doelhaven staat. Dus geen remise, geen
  cycluslimiet, geen eindeloze partijen.
- **Zes facties** met eigen legers, kaartbudgetten en perks (stand 8 augustus
  2026, gemeten op 44,7-56,2% winst):

  | Factie | Kaarten | Budget | Leger [inf,cav,art] | Perk |
  |---|---|---|---|---|
  | Varken | 3 | 7 | 11/5/3 | allrounder, geen zwaktes |
  | Muis | 5 | 5 | 16/4/0 | +1 Speed op elke pion, loopt door eigen pionnen |
  | Leeuw | 2 | 8 | 12/4/2 | artilleriedracht 7 |
  | Beer | 3 | 7 | 19/3/0 | +1 HP per koppeling, maar kaart-Speed max 4 |
  | Wolf | 3 | 7 | 11/8/3 | gratis stap na elke melee, cavalerie +2 Speed |
  | Krokodil | 3 | 6 | 13/5/3 | koppeling blijft geheim tot de eerste schade |

  Deze getallen staan in het `doctrines`-blok van
  `arena/arena_configs/rules_v42_campaign.json`, niet in `constants.gd`. Wat er
  op dit moment werkelijk geldt zie je met `-- facties`.
- **Vier AI-niveaus**: Easy / Medium / Hard / Ultra (god mode, diepte-5-zoeker).
- In het spel: druk op de **?**-knop voor de volledige speluitleg.

## Spelen

Open het project in Godot 4.7 en druk F5 (hoofdscene: `scenes/game/game.tscn`).
Het hoofdmenu heeft naast het losse duel ook "Solo-campagne (v4.2)": jij plus
15 bots in twee teams van 8, verdeeld over 8 persoonlijkheden (van trouwe
generaal tot rat en kamikaze), met een raad die stemt, donaties, testamenten en
een burgeroorlog zodra één team weg is.

## Het paneel (knoppen in gewone taal)

`"FogOfWar Paneel.bat"` opent het bedieningspaneel. Daar zitten de dingen die
uren draaien: TRAINING-NACHT (trainen + meten + dashboard in één), bots laten
leren, bots laten spelen, regels of facties uitproberen, en de trackers
(modellen, geluid, iconen). **Niets start automatisch** — jij drukt op de knop.

## AI trainen

De AI leert per factie 38 gewichten via self-play (CMA-lite): evaluatie,
opstelling, koppelen, CP-inzet, spawnen en de C15-buit.

| Manier | Wat het doet |
|---|---|
| Paneelknop "TRAINING-NACHT" | 7 uur trainen, dan 1 uur meten, dan dashboard |
| `train_ai.bat [min]` | 6 facties parallel (dubbelklik = 8 uur, `test` = proefrun) |
| `capture.tscn -- train <min> 6 6 <factie> <seed> <regels.json>` | één losse factie |

Alle drie trainen op `arena/arena_configs/rules_v42_campaign.json`: dat is het
spel (C17). Traint iets op iets anders, dan leert het een economie die niet
bestaat.

Resultaat komt in `data/ai_weights_f*.json`; het spel laadt dat automatisch.
Inspectie: `capture.tscn -- showweights`. Trainingsdata wordt **apart van code**
gecommit. Zie `AI_TRAINING_PLAN.md` voor de roadmap.

## Documentatie

| Document | Inhoud |
|---|---|
| `CLAUDE.md` | **Kortste ingang** — kernregels, facties, commando's, waar we zijn |
| `MASTERBOUWPLAN.md` | Fasering F0-F8, werkafspraken, besluiten B1-B17 |
| `WIP.md` | Per-stap-logboek, nieuwste bovenaan |
| `docs/spelregels-v4.2.md` | De geldende spelregels (Deel A = 4.1, Deel B = 4.2) |
| `docs/spelregels-CHANGELOG.md` | Elke regelwijziging met de meting eronder |
| `MODEL-WISHLIST.md` / `SOUND-WISHLIST.md` | Het asset-spoor, met prompts |
| `game_description.md` | v1-basisdocument waarop v4.1 voortbouwt |

## Tests & tooling

- **Tests**: `tests/TestScene.tscn` headless draaien.
- **Golden replays** (`-- simcheck`) zijn het regressiecontract: breekt er een,
  dan is dat een bewuste regelwijziging (versie-bump + CHANGELOG + opnieuw
  genereren met `-- makegoldens`) of er is iets stuk.
- **Arena**: `.\arena.ps1 -Config arena/arena_configs/<x>.json -Procs N -Naam run`,
  dashboard via `python tools/dashboard/build_dashboard.py`.
- **Fuzz**: `arena.tscn -- --fuzz [games] [seed]`.
- **Kijken zonder te spelen**: `capture.tscn -- <modus>`, o.a. `play`, `facties`,
  `tunercheck`, `meleecheck`, `cliplengtes`, `geluidcheck`, `sim`, `showweights`.
  Screenshots (`_shot*.png`) staan in .gitignore.

# Fog of War

2-speler tactisch 3D-bordspel in **Godot 4.7** (Forward+, portrait 1080×1920).
Jij (rood) tegen een AI (blauw) op een bord van 11×11 — breng 2 pionnen naar de
haven aan de overkant, of schakel het hele vijandelijke leger uit.

## Kern van het spel

- **Kaart-gedreven activatie**: per cyclus definieer je blind kaarten
  (HP / Speed / Aanval, som = je budget) en koppel je ze aan pionnen.
  Pionnen zonder kaart "slapen" en sterven aan één treffer.
- **Drie eenheidstypes**: infanterie (melee + schot op afstand 2), cavalerie
  (charge: lopen + slaan in één beurt, springt over eigen pionnen) en artillerie
  (vaste dracht 6, dode zone op afstand 1).
- **Zes facties (doctrines)** met eigen legers, kaartbudgetten en perks:
  Mens, Muis, Leeuw, Beer, Wolf en Vos.
- **Vier AI-niveaus**: Easy / Medium / Hard / Ultra (god mode, diepte-5-zoeker).
- In het spel: druk op de **?**-knop voor de volledige speluitleg.

## Spelen

Open het project in Godot 4.7 en druk F5 (hoofdscene: `scenes/game/game.tscn`).

## AI trainen

De AI leert per factie 31 gewichten via self-play (CMA-lite):

| Bestand | Wat het doet |
|---|---|
| `train_ai.bat` | 60 minuten headless trainen (dubbelklik) |
| `train_ai_nacht.bat` | 8 uur |
| `train_ai_parallel.bat` | 6 processen — één per factie (voor veel cores) |

Resultaat komt in `data/ai_weights.json` (+ `ai_weights_f*.json` bij parallel);
het spel laadt dat automatisch. Inspectie: `capture.tscn -- showweights`.
Zie `AI_TRAINING_PLAN.md` voor de roadmap.

## Documentatie

| Document | Inhoud |
|---|---|
| `WIP.md` | **Levend statusdocument** — architectuur, beslissingen, TODO |
| `spelregels-v4.1.md` | De geldende spelregels (huisregels gemarkeerd in WIP §2b) |
| `game_description.md` | v1-basisdocument waarop v4.1 voortbouwt |
| `AI_TRAINING_PLAN.md` | Trainings-roadmap (self-play → MCTS → deep-RL) |

## Tests & tooling

- **Tests**: `tests/TestScene.tscn` headless draaien (400+ asserts).
- **Scripted screenshots/sims**: `tools/capture.tscn -- <modus>`, o.a. `play`,
  `sim <ai1> <ai2> [factie1] [factie2]`, `shoottest`, `placetest`, `uitleg`,
  `train`, `showweights`. Screenshots (`_shot*.png`) staan in .gitignore.

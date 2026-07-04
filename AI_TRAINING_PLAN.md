# Bouwplan — AI trainen via self-play / machine learning

> Doel: de AI veel sterker maken door héél veel potjes te laten spelen en te leren.
> Dit document is het plan; implementatie gebeurt gefaseerd. Zie ook `WIP.md` §8.

---

## Status-update (juli 2026) — regels v4.1 + huisregels zijn live

De engine is omgebouwd (zie `WIP.md` §2b); dat verandert het trainingslandschap flink:

- **Veel grotere actieruimte**: naast bewegen/melee nu ook **schoten** (infanterie afstand 2,
  artillerie vaste dracht 6, Leeuw 7), **charges** (cavalerie: bewegen + melee in één actie)
  en de **Wolf-stap** (aparte beslissing via `choose_wolf_step`). `enumerate_actions` dekt alles.
- **Leerbare gewichten** (`AIController.default_weights`, 32 stuks) in drie groepen:
  1. **Evaluatie** (16): `haven`, `prox_scale`, `prox_second`, `guard`, `material`,
     `cav_value`, `art_value`, `hp`, `protect` (melee-dreiging), `ranged` (vuurdreiging),
     `reach`, `card_atk`, `card_hp`, `card_stam`, `r3_initiative`.
  2. **Opstelling** (6, gebruikt door `choose_placement`): `art_front`/`art_center`,
     `cav_front`/`cav_center`, `inf_front`/`inf_center` — elk thuisvak krijgt per type
     een score (voorste rij / centrum-vs-flank); schaarste type kiest eerst.
  3. **Koppelen** (10, gebruikt door `choose_link`): `aff_<type>_<stat>` (3×3 affiniteit
     kaartstat × piontype) + `link_advance` — de kern van v4.1 (kaart × type) is nu leerbaar.
  De Trainer pakt nieuwe keys automatisch mee (gemerged over defaults bij laden).
- **Doctrines als curriculum**: ✅ GEDAAN — de Trainer sampelt per potje een willekeurige
  doctrine-matchup (generalisatie over alle legers/perks); de kracht-grafiek meet op een
  vaste rotatie van 4 matchups (geen ruis). Losse metingen:
  `capture.tscn -- sim <p1> <p2> [d1] [d2]`. 6 doctrines = 21 matchups (incl. spiegels).
- **RPS is weg** (initiatief is deterministisch): één bron van ruis minder — alleen de
  AI-kaartgeneratie en Easy's top-3-keuze gebruiken nog `randi()` (seedbaar maken blijft nodig).
- **Stamina is opmaakbaar** (stap=1, melee/schot=1, charge=stappen+1): partijen zijn
  compacter (7–10 cycli i.p.v. 15–21) → snellere fitness-evaluaties.
- **Bekende eval-gaten om te leren/verbeteren**: `_is_killable` kent alleen melee-dreiging
  (schoten/charges ontbreken); koppel-strategie is type-blind (kaart × type is juist de kern);
  artillerie-schootsveld (vrije lanen) wordt niet gewogen — `ranged` vangt dit deels.

---

## 0. Uitgangspunt & realiteit

Wat we al hebben en waarom dat goud waard is voor training:

- **Headless engine** (`scripts/core/`): een hele partij speelt puur in code, zonder rendering.
  Dat maakt duizenden potjes per minuut mogelijk.
- **Sim-harness**: `tools/capture.tscn -- sim <p1> <p2>` speelt al een volledige AI-vs-AI partij
  en logt de winnaar. Dit is de basis voor batch self-play.
- **Heuristische evaluatie met gewichten** (`AIController.evaluate`): haven, nabijheid,
  bewaking, materiaal, HP. Deze gewichten zijn precies wat we eerst kunnen laten "leren".
- **Schone actie-interface**: `enumerate_actions`, `simulate`, `evaluate` — ideaal voor MCTS
  en voor het genereren van trainingsdata.

Eerlijk over de opties: **volledige deep-RL (neuraal netwerk) in Godot vergt een Python-brug en is
een groot project.** De snelste, meest kosteneffectieve winst zit in **self-play gewicht-tuning**
(Fase B) en daarna **MCTS** (Fase C). Deep-RL (Fase D) is de "all-in"-route.

### Bijzondere uitdagingen van dit spel

- **Verborgen/simultane info in de setup**: beide spelers definiëren blind hun kaarten
  (aantal × budget per doctrine); de Vos koppelt zelfs gedekt. Geen perfecte informatie →
  puur AlphaZero (dat perfecte info aanneemt) past niet 1-op-1. Praktisch: leer eerst alleen
  de **actiefase** (wel perfecte info) en houd setup/koppelen vast, of behandel setup als
  apart (bandit-)beslisprobleem.
- **Grote, variabele actieruimte**: actieve pionnen × (zetten + melees + schoten + charges);
  charges maken de vertakking van cavalerie fors (elke bereikbare positie × buurvijanden).
- **Doctrine-asymmetrie**: 21 matchups met andere samenstellingen, budgetten en perks —
  één gewichtenset hoeft niet overal optimaal te zijn (meet per matchup, evt. per-doctrine sets).
- **Meerdere acties per pion per cyclus** (opmaakbare stamina) + **schaarse beloning**
  (winst/verlies aan het eind).
- **Twee spelers, tegengestelde havens** — self-play moet beide kanten symmetrisch trainen.

---

## Fase A — Self-play infrastructuur (fundament)

Zonder dit kan er niets geleerd worden. Bouwen:

1. **Batch-runner** (headless): speel N partijen achter elkaar, verzamel resultaten.
   - Uitbreiden van de `sim`-modus: `-- simbatch <p1> <p2> <n> [seed]` → speelt N potjes,
     print winrate, gem. cycli, gem. acties, en schrijft evt. een JSON/CSV naar `res://_sim_out/`.
   - **Seedbaar** maken (deterministische RNG) voor reproduceerbaarheid: één RNG-seed per partij,
     doorgegeven aan de AI's (nu gebruiken ze `randi()` globaal). Vervang door een `RandomNumberGenerator`
     instance per AI/partij.
2. **Match-evaluator**: pit config A vs config B over K potjes (kant wisselen zodat begin-voordeel
   uitmiddelt), rapporteer winrate + betrouwbaarheidsmarge. Dit is de "fitness"-functie voor Fase B.
3. **Metrics**: winrate, gem. partijlengte, hoe vaak win-door-haven vs win-door-eliminatie,
   hoe vaak stalemate (nu geeft `sim` soms winner=-1 → onderzoeken/afvangen).

**Deliverable**: `tools/` uitbreiden met een batch-sim + winrate-rapport. Puur GDScript, headless via CLI.

---

## Fase B — Gewicht-tuning via self-play (AANBEVOLEN START)

De grootste winst voor de minste moeite. De evaluatie is (bijna) lineair in een set gewichten;
die gaan we optimaliseren door potjes te spelen en de beste te selecteren. **Geen externe tooling.**

1. **Parametriseer de evaluatie**: ✅ GEDAAN — `AIController.weights` (16 tunebare gewichten,
   zie de status-update bovenaan), gemerged geladen uit `res://data/ai_weights.json`.
   Elke AI-instantie kan eigen gewichten hebben; de Trainer leert ze al via hill-climbing.
2. **Optimalisatie-algoritme**: ✅ TWEE routes gebouwd:
   - **Hill-climbing** (dashboard, `Trainer.tscn`): 1 gewicht per generatie, live meekijken,
     spreektaal-narratie. Leuk om te volgen, leert langzaam.
   - **CMA-lite** (headless, `train_ai.bat` / `capture.tscn -- train [min] [pop] [games]`):
     populatie van kandidaten (ALLE gewichten log-normaal verstoord), fitness over potjes,
     recombinatie (meetkundig gemiddelde top-helft), verificatie vóór adoptie, en
     zelf-aanpassende stapgrootte per factie (groter bij succes, kleiner bij falen).
     Meerdere mutaties tegelijk en tóch zuiver: de hele kandidaat wordt beoordeeld,
     en alles blijft binnen de ene factie-set die de kandidaat ook echt speelt.
   - **Robuustheid v2 (na de nachtrun-analyse juli 2026)**:
     1. *Schaal-anker*: `AIController.renormalize_weights()` pint na elke recombinatie
        (én bij het laden) het geometrisch gemiddelde van |w| op de baseline-schaal.
        De eval is een lineaire som, dus dit is gedrag-neutraal — maar het stopt de
        exponentiële schaal-drift (Beer `haven`=1.2M, Leeuw `hp`=112k) die mutaties
        zinloos maakte.
     2. *Dubbele verify-gate*: 2×games potjes, helft tegen de kampioen en helft tegen
        de VASTE baseline; adoptie eist marge op het totaal (≥ 50% + 2) én geen verlies
        op een van beide helften. De oude gate (4/6 alleen tegen de kampioen) liet ~34%
        pure ruis door → 90-127 schijn-adopties per nacht.
     3. *Gepaarde vergelijking*: alle kandidaten van een generatie spelen exact hetzelfde
        tegenstander-schema (zelfde profiel, factie en kant per potje-index), met
        gebalanceerde tegenstander-facties — fitnessverschil = gewichten, niet loting.
     4. *Sigma-cap* 0.5 → 0.35 en *stap-limiet* 900 per trainingspotje (patstellingen
        kostten tot 2500 stappen; de tiebreak materiaal→haven geeft hetzelfde signaal).
   - **Volwaardige CMA-ES via Python** blijft de vervolg-optie als CMA-lite plafonneert
     (het `cma`-package rond de headless CLI-sim).
3. **Fitness** = winrate uit Fase A's match-evaluator (bv. 50-100 potjes per evaluatie, kant gewisseld).
4. **Anti-overfitting**: train tegen een *pool* van tegenstanders (huidige beste + eerdere versies +
   de vaste heuristiek), niet alleen tegen één kampioen. Voorkomt "rock-paper-scissors"-instortingen.
5. **Resultaat**: een set geleerde gewichten die je vastzet als de nieuwe standaard-eval. Meetbaar
   sterker dan de handmatige gewichten, en Hard (negamax) profiteert automatisch mee.

**Deliverable**: parametriseerbare eval + een `tools/train_weights` (GDScript of Python-wrapper rond de
CLI-sim) + een opgeslagen `best_weights.json` die de AI inlaadt.

---

## Fase C — MCTS at runtime (sterker spel, geen training)

Monte Carlo Tree Search maakt de AI per zet slimmer door vooruit te simuleren — bovenop de (getunede)
evaluatie.

- **Actiefase** (perfecte info): MCTS met UCT; playouts kort gehouden via de heuristiek als
  rollout-policy (of vervang de random rollout door de eval → "MCTS met eval-cutoff").
- **Tijdsbudget** per zet (bv. 200-500 ms) i.p.v. vaste diepte → schaalt met hardware.
- Hergebruikt `enumerate_actions` / `simulate` / `evaluate` die er al zijn.
- Kan gecombineerd met Fase B (getunede eval als rollout/leaf-waarde) én Fase D (NN als policy/value).

**Deliverable**: `scripts/ai/AIMcts.gd` (nieuwe difficulty "Expert").

---

## Fase D — Deep RL / neuraal zelfspel (all-in, AlphaZero-achtig)

De zwaarste route; alleen als B+C niet volstaan. Vereist een **Python-brug**.

1. **Brug**: [Godot RL Agents](https://github.com/edbeeching/godot_rl_agents) — koppelt Godot via een
   socket aan Python (Stable-Baselines3 / CleanRL / Sample Factory). Of een eigen brug: headless Godot
   dumpt state/ontvangt actie via stdin/stdout of TCP; Python doet de training.
2. **Observatie (state → tensor)**: 11×11 kanalen voor pion-eigenaar, actief/inactief, en per-pion
   HP/stamina/attack; plus fase, beurt, cycle/ronde, haven-voortgang. (De setup-fase apart of vast.)
3. **Actieruimte**: gemaskeerd (alleen geldige zetten). Actiefase = kies pion + doel (move/attack).
   Setup = kaart-stats (herverdeling) + koppel-keuze + RPS. Overweeg **aparte policies per fase**.
4. **Beloning**: winst/verlies (+1/−1) aan het eind; eventueel *shaped* (haven-voortgang, kills, materiaal)
   om leren te versnellen, later uitfaseren.
5. **Trainmethode**:
   - **PPO self-play** (SB3): simpelst op te zetten via godot_rl_agents.
   - **AlphaZero-lite**: NN (policy+value) + MCTS self-play in Python op een *port van de engine*
     (de regels zijn simpel genoeg om in Python te herimplementeren voor snelheid) → sterkste,
     maar meest werk. Let op de imperfecte-info-setup (beperk NN tot de actiefase of gebruik
     information-set-MCTS).
6. **Inference terug in Godot**: exporteer het getrainde netwerk naar **ONNX** en draai het in Godot
   (via een ONNX-runtime plugin), of — als het model klein/lineair blijft — bak de gewichten in GDScript.

**Deliverable**: Python-trainpipeline + geëxporteerd model + `scripts/ai/AINeural.gd` die het inlaadt.

---

## Aanbevolen volgorde & verwachting

1. **Fase A** (fundament) — een paar uur werk, direct nuttig om alles te meten.
2. **Fase B** (gewicht-tuning) — grootste ROI; maakt de bestaande AI merkbaar sterker zonder externe deps.
3. **Fase C** (MCTS) — als je een echt pittige "Expert" wilt.
4. **Fase D** (deep RL) — alleen als ambitie/tijd het toelaat; groot maar het sterkst.

Begin klein: eerst de **batch-sim + seedbare RNG + winrate-match** (Fase A), dan **hill-climbing op de
eval-gewichten** (Fase B). Daarmee laten we de AI letterlijk "veel potjes spelen en leren", volledig
binnen Godot.

## Openstaand / te beslissen

- RNG seedbaar maken (nu `randi()` in kaartgeneratie en Easy) — randvoorwaarde voor
  reproduceerbare training. RPS is al weg (deterministisch initiatief).
- Stalemates (`sim` winner=-1) afvangen: partij-limiet + tie-break-regel of gewoon als "geen winst" tellen.
- Setup-fase: meetrainen (imperfecte info, lastig) of vastzetten en alleen de actiefase leren?
- ~~Doctrine-curriculum in de Trainer~~ ✅ gedaan (random matchup per potje; vaste rotatie
  voor de kracht-grafiek).
- ~~Per-doctrine gewichtensets~~ ✅ gedaan: de kampioen is een **profiel** (per factie een
  eigen set van 31 gewichten; `AIController.save_profile`/`load_profile`, legacy plat
  formaat wordt herkend). Elke generatie muteert één factie en de uitdager speelt die
  factie ook (anders meet je ruis); het spel laadt de set die bij de AI-doctrine hoort.
- ~~Koppel-strategie type-bewust maken~~ ✅ gedaan (`aff_*`-gewichten + `link_advance`).
- ~~Opstelling leerbaar maken~~ ✅ gedaan (`art/cav/inf_front/center`-gewichten).
- **Wolf-stap in de search**: `simulate` negeert de gratis stap (alleen `choose_wolf_step`
  greedy in de sessie); voor Hard/negamax mag de stap in de simulatie mee.
- **Mutatie-schema**: nu 1 willekeurige key per generatie over 32 gewichten — convergentie
  wordt traag; overweeg 2-3 keys per mutatie of groepsgewijs (eval / opstelling / koppelen).

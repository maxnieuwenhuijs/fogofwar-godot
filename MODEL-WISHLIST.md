# 3D-modellen — ontwerpgids & verlanglijst

Het systeem zit in het spel (`PawnView.set_character`): drop een `.glb` op het
juiste pad en hij verschijnt vanzelf — geen code nodig. Elke pion toont:

1. **Ongekoppeld / opstelling** → het neutrale factie-model (`_base`).
2. **Gekoppeld aan een kaart** → het archetype-model van de dominante stat.
3. **Verborgen Krokodil-koppeling** (hidden link-perk) → tegenstander blijft
   het neutrale model zien tot de kaart onthuld wordt.

Het archetype wordt bepaald door de kaart **zoals gedefinieerd** —
factie-bonussen (Muis +1 Speed, Beer +1 HP) tellen niet mee.

---

## 1. Visuele taal — stats moeten je van een afstand "aanspringen"

Het bord toont 44 stukken op een telefoonscherm: het **silhouet** doet het werk,
niet het detail. Eén blik moet vertellen wat een pion kan.

| Archetype | Stat dominant | Silhouet | Kenmerken |
|---|---|---|---|
| `atk` | Aanval | **Bulkier: breed en gespierd** | zware schouders/borst, wapen prominent en naar voren gericht, agressieve stand (gewicht op de voorste poot), tanden/klauwen zichtbaar |
| `spd` | Speed | **Dun en gestrekt** | smal lijf, lange dunne ledematen, vooroverleunend alsof hij al rent, minimale bepakking, staart/jas wappert naar achteren |
| `hp` | HP | **Laag, rond en zwaar** | dik/mollig of bepantserd, laag zwaartepunt, stevig neergeplant op brede poten, schild/borstplaat/dikke vacht |
| `mix` | geen (gelijkspel) | **Standaard proporties** | de nette "linie-soldaat" van de factie, niets uitvergroot |
| `basis` | geen kaart | **Neutraal, rustige pose** | zelfde als mix maar in rust (wapen geschouderd, zittend dier) — verraadt níks (belangrijk voor de Krokodil) |

Vuistregels:
- Overdrijf: op 2 cm schermhoogte is 20% breder nauwelijks zichtbaar — denk 40%.
- **Onderscheid binnen de factie** is net zo belangrijk als het dier zelf: zet de
  lichaamsbouw van spd/hp/atk keihard uit elkaar zodat je ze in een oogopslag
  herkent. spd = extreem lang, dun en langlijvig · hp = extreem laag, rond en
  gedrongen · atk = extreem breed en gespierd. Zelfde kop en kleuren, maar de bouw
  schreeuwt het verschil (de pose blijft A-pose, dus het zit puur in de proporties).
- Alle vijf de varianten van één factie delen kop, kleuren en materialen; alleen
  bouw en houding verschillen. Zo herken je factie én kaart tegelijk.
- Houd de voetafdruk binnen het vak (~1×1): `hp` mag breed, niet groter dan de tegel.
- Periode: 18e/19e-eeuws (musketten, sabels, kanonnen op houten affuiten) — zelfde
  wereld als het geluidsontwerp (zie SOUND-WISHLIST.md).
- Mesh: **low poly, max 1.000 tris** (besluit juli 2026). Dat is een
  GENERATOR-instelling ("Laag Poly", target 1.000), géén prompt-woord — in de
  prompt zelf staat "low poly" niet meer (besluit Max, 28 juli), want dat maakt
  het concept-plaatje onnodig hoekig. De generator bakt het detail als texture
  op de simpele mesh. Het silhouet blijft leidend: de bouw (dun/rond/breed)
  moet het verschil vertellen, niet het micro-detail.
- **Het hele object moet in beeld** (besluit Max, 28 juli): elke prop-prompt
  eindigt met `the entire object fully in frame and not cropped` — een
  afgesneden vlaggenstok of musketloop is onbruikbaar voor de pijplijn.

Zolang een model ontbreekt doet het spel dit al met schaal-silhouetten op de
geometrische stukken (`ARCHETYPE_SCALE` in pawn_view.gd): dun/hoog = spd,
laag/rond = hp, breed = atk.

---

## 2. Alle kaartcombinaties → archetype

Formaat **HP / Speed / Aanval**. Archetype = strikt hoogste stat; gelijkspel = `mix`.

Budgetten per factie sinds C19 (8 augustus 2026): Muis 5, Krokodil 6,
Varken/Beer/Wolf 7, Leeuw 8.

### Budget 5 — Muis (6 combinaties)

| Kaart | Archetype | Lees je als |
|---|---|---|
| 3/1/1 | `hp` | dikke muis |
| 1/3/1 | `spd` | dunne schichtige muis |
| 1/1/3 | `atk` | gespierde muis met wapen |
| 2/2/1 | `mix` | standaard |
| 2/1/2 | `mix` | standaard |
| 1/2/2 | `mix` | standaard |

### Budget 6 — Krokodil (10 combinaties)

| Kaart | Arch. | | Kaart | Arch. | | Kaart | Arch. | | Kaart | Arch. |
|---|---|---|---|---|---|---|---|---|---|---|
| 4/1/1 | `hp` | | 1/4/1 | `spd` | | 1/1/4 | `atk` | | 2/2/2 | `mix` |
| 3/2/1 | `hp` | | 2/3/1 | `spd` | | 2/1/3 | `atk` | | | |
| 3/1/2 | `hp` | | 1/3/2 | `spd` | | 1/2/3 | `atk` | | | |

Het krappe budget is de prijs van de schutkleur-perk. Eén mix-kaart maar
(2/2/2): een krokodil is bijna altijd ergens uitgesproken in.

### Budget 7 — Varken, Beer, Wolf (15 combinaties)

| Kaart | Archetype | | Kaart | Archetype | | Kaart | Archetype |
|---|---|---|---|---|---|---|---|
| 5/1/1 | `hp` | | 2/4/1 | `spd` | | 2/2/3 | `atk` |
| 4/2/1 | `hp` | | 2/3/2 | `spd` | | 2/1/4 | `atk` |
| 4/1/2 | `hp` | | 1/5/1 | `spd` ⛔beer | | 1/2/4 | `atk` |
| 3/2/2 | `hp` | | 1/4/2 | `spd` | | 1/1/5 | `atk` |
| 3/3/1 | `mix` | | 3/1/3 | `mix` | | 1/3/3 | `mix` |

⛔beer = kan niet bij de Beer. Zijn `speed_max` is **4**, niet 3 (dat getal
stond hier en in twee andere documenten fout): alleen de uiterste 1/5/1 valt
voor hem af. Een echt harde beer-`spd` bestaat dus wel, maar nooit de extreemste
variant; dat mag het model uitstralen — snel voor een beer, niet snel voor een
muis.

### Budget 8 — Leeuw (21 combinaties)

| Kaart | Arch. | | Kaart | Arch. | | Kaart | Arch. | | Kaart | Arch. |
|---|---|---|---|---|---|---|---|---|---|---|
| 6/1/1 | `hp` | | 1/6/1 | `spd` | | 1/1/6 | `atk` | | 2/3/3 | `mix` |
| 5/2/1 | `hp` | | 1/5/2 | `spd` | | 1/2/5 | `atk` | | 3/2/3 | `mix` |
| 5/1/2 | `hp` | | 2/5/1 | `spd` | | 2/1/5 | `atk` | | 3/3/2 | `mix` |
| 4/3/1 | `hp` | | 1/4/3 | `spd` | | 1/3/4 | `atk` | | | |
| 4/2/2 | `hp` | | 2/4/2 | `spd` | | 2/2/4 | `atk` | | | |
| 4/1/3 | `hp` | | 3/4/1 | `spd` | | 3/1/4 | `atk` | | | |

Leeuw ging op 8 augustus van budget 9 naar 8 (hij was met 63,7% winst veruit de
sterkste). Zijn hoogste losse stat is daarmee 6 in plaats van 7 — behalve als er
in de campagne een CP op de kaart ligt: dan is het weer 9 en komt 7 terug.

**Telling**: 52 combinaties over de vier budgetten, maar dankzij de
archetype-bucketing zijn er maar **5 looks per type** nodig. Binnen een
archetype verschilt de intensiteit
(1/1/7 is extremer dan 2/2/3) — dat hoeft het model niet te tonen; de
HP-blokjes en het kaartpaneel geven de exacte cijfers.

---

## 3. Generatie-prompts per factie (Engels)

**FAMILIE-REGEL (besluit 6 juli 2026):** elke factie is een dierenfamilie.

- **Infanterie** = het kleine, antropomorfe familielid: 2 benen, donkergrijs
  Napoleontisch uniform, musket. Pipeline: Mixamo (A-pose), zoals nu.
- **Cavalerie = de "BIG BRO"**: hetzelfde dier(familie) maar dan de uit de
  kluiten gewassen grote broer -- ook **antropomorf, op twee benen**, zonder
  ruiter; geen paarden meer in het spel. Gameplay blijft identiek; alleen de
  look. Geen net uniform maar een zwaar militair harnas van leren riemen
  (ontblote borst = massa tonen).
- **Artillerie** = kanon-prop met optioneel een klein bemanningsdier van de factie
  op de affuit. GEEN losse props ernáást (het kanon rolt over het bord, dus kogels,
  zandzakken of kratten blijven achter of clippen); alleen wat aan het kanon zelf
  vastzit (camouflage-net, dekzeil, vastgesjorde touwen/vaten) rolt mee. Het
  bemanningsdier is een statisch onderdeel van de prop en animeert niet.

| Factie | Infanterie (klein broertje) | Big bro cavalerie (groot, ook 2 benen) |
|---|---|---|
| Muis | muis | **dikke bruine rat** (big bro; besluit Max 30 juli: het ruiter-op-konijn-idee van 25 juli is teruggedraaid) |
| Varken (ex-Mens) | varken | **everzwijn** met slagtanden |
| Leeuw | **cheetah** (slank, gevlekt, snel) | **leeuw** met volle manen |
| Beer | **wasbeer** (gemaskerd gezicht) | massieve grizzly |
| Wolf (= Wolf+Vos samengevoegd) | **vos** (kleine broer van de wolf) | reusachtige **dire wolf** |
| Krokodil (ex-Vos-slot, erft schutkleur-perk) | **hagedis** met camouflage-schubben | **krokodil** (gepantserd) |

**Hoeveel van elk, en wie heeft er GEEN kanon** (stand C19, 8 augustus 2026 —
uit het `doctrines`-blok, te controleren met `-- facties`). Dit bepaalt hoe vaak
een model in beeld komt en welke props je dus niet hoeft te maken:

| Factie | Infanterie | Big bro | Artillerie |
|---|---|---|---|
| Muis | 16 | 4 | **geen** |
| Varken | 11 | 5 | 3 |
| Leeuw | 12 | 4 | 2 |
| Beer | 19 | 3 | **geen** |
| Wolf | 11 | **8** | 3 |
| Krokodil | 13 | 5 | 3 |

- **Muis en Beer krijgen geen kanon.** Nul artillerie in de comp betekent dat
  `GameState.kent_type()` ze verbiedt er ooit een te spawnen, ook met een volle
  reserve. Een muizen- of berenkanon is dus verloren werk, net als de
  bijbehorende gibs en het `cannon_die`-geluid. (Beer verloor zijn kanonnen op
  8 augustus: ze kostten hem 21 procentpunt winst, want hij wint met rennen en
  een kanon verzet één vak per actie.)
- **Wolf heeft met acht de meeste big bro's**, en die zijn ook nog eens +2
  Speed. Dat model komt het vaakst en het snelst in beeld: de loop-clip mag daar
  de beste zijn.
- **Beer is met 19 het meest infanterie-zwaar**, Varken en Wolf met 11 het minst.

**Prompt-opbouw infanterie**: `Single character, <bouw>
anthropomorphic <dier> <kenmerken>, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey
Napoleonic military uniform and <hoofddeksel>, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text.`
(A-pose en "unarmed with empty hands, carrying no weapons of any kind" staan in
**elke** personage-prompt: wapens zijn losse props uit de wapen-set.)

**Prompt-opbouw big bro**: `Single character, towering <bouw> anthropomorphic
<dier> <kenmerken>, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing
a weathered, strictly dark grey Napoleonic military harness with heavy leather
straps, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text.`
Bouw per archetype (overdrijf het contrast keihard, dit maakt de kaarten binnen
een factie uit elkaar): spd = `whip-thin, greyhound-lean, long-limbed` | hp =
`colossally fat, round and squat` + pantserplaten | atk = `monstrously muscular,
hulking, battle-scarred` + ontblote tanden | base = `powerful and broad` | mix =
`solid and stocky`.

**Hoofddeksel per factie** (uniek, zodat je de factie ook aan de hoed herkent; binnen een factie hetzelfde type, hooguit licht verweerd verschil): Muis = `shako` (hoge cilinderpet) · Varken = `bicorne` (tweepuntige steek) · Leeuw = `tall black bearskin cap` (hoge berenmuts) · Beer = `round Russian ushanka fur hat` (ronde Russische bontmuts met oorflappen) · Wolf = `forage cap` (zachte veldpet) · Krokodil = `tricorne` (driepuntige musketiershoed).

**<kenmerken>** = de herkenbare diertrekken flink uitvergroot zodat het silhouet
meteen "leest" (denk 40% overdreven, net als de bouw-verschillen). Per dier:
muis = grote ronde oren + lange snorharen · rat = lange kale staart + stompe snuit ·
varken = platte wipneus + flaporen · everzwijn = enorme opkrullende slagtanden ·
cheetah = felle rozet-vlekken + traanstrepen · leeuw = kolossale manen ·
wasbeer = zwart bandietenmasker + geringde staart · grizzly = schouderbult + klauwen ·
vos = grote spitse oren + volle pluimstaart · dire wolf = ruige manen + grote hoektanden ·
hagedis = grote ogen + lange staart · krokodil = lange getande snuit + pantserschubben.
De "exaggerated stylized caricature proportions"-hint houdt de render gritty-realistisch
maar overdrijft de proporties, zodat het model op 2 cm schermhoogte herkenbaar blijft.

**Animatie big bros**: tweebenig = gewoon de Mixamo-pipeline! Alleen een
andere clip-set, want cavalerie schiet nooit: **Idle** (bv. Bouncing Fight
Idle), **Walking (In Place!)**, **Standing Melee Attack** (Swiping/Punch) als
`attack`/`melee`, en een **Death**. Geen musket-prop (het spel hangt die alleen
aan infanterie); de big bro krijgt een MELEE-wapen als losse prop, zie 3c-2.
Cavalerie-audio (nu paarden-galop) vervangen we later per
familie (brul/grom/gepiep).

### Muis -- infanterie + dikke rat als big bro

*Cavalerie teruggedraaid naar de familie-regel (besluit Max 30 juli): de big
bro is de dikke bruine rat, tweebenig, dus gewoon de Mixamo-pijplijn zoals bij
elke andere factie. Het ruiter-op-konijn-plan van 25 juli vervalt.*

> **`artillery_base` hieronder is NIET meer nodig.** De Muis heeft nul
> artillerie in zijn comp en mag er dus ook nooit een spawnen. De prompt blijft
> staan voor het geval de comp ooit weer artillerie krijgt.

| Bestand | Prompt |
|---|---|
| `infantry_base` (klaar) | Single character, average build anthropomorphic mouse with oversized round ears, long twitching whiskers and a pointed snout, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and dark grey shako, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_spd` | Single character, extremely tall, thin, lanky and long-limbed anthropomorphic mouse with oversized round ears, long twitching whiskers and a pointed snout, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and dark grey shako, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_hp` | Single character, enormously fat, round-bellied, short and squat anthropomorphic mouse with oversized round ears, long twitching whiskers and a pointed snout, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform with a dark steel cuirass and dark grey shako, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_atk` | Single character, gigantic, hulking, broad-shouldered and heavily-muscled anthropomorphic mouse with oversized round ears, long twitching whiskers and a pointed snout, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and dark grey shako, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_mix` | Single character, average build anthropomorphic mouse with oversized round ears, long twitching whiskers and a pointed snout, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and dark grey shako, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_base` | Single character, towering powerful anthropomorphic fat brown rat with a long scaly tail, a blunt whiskered snout and beady eyes, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_spd` | Single character, towering yet whip-thin, greyhound-lean and long-limbed anthropomorphic fat brown rat with a long scaly tail, a blunt whiskered snout and beady eyes, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_hp` | Single character, towering, colossally fat, round and squat anthropomorphic fat brown rat with a long scaly tail, a blunt whiskered snout and beady eyes, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps with dark steel armor plates over the harness, low stance, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_atk` | Single character, towering, monstrously muscular, hulking and battle-scarred anthropomorphic fat brown rat with a long scaly tail, a blunt whiskered snout and beady eyes, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps with bared teeth, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_mix` | Single character, towering sturdy anthropomorphic fat brown rat with a long scaly tail, a blunt whiskered snout and beady eyes, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |

| `artillery_base` | Single prop, small light Napoleonic field cannon on a weathered dark wooden gun carriage with two spoked wheels, with a small anthropomorphic mouse gunner crouched on the gun carriage. Gritty realistic AAA-game concept art, highly detailed. Dark iron barrel. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_spd` | Single prop, very light small Napoleonic horse-artillery cannon with a slender barrel on a weathered dark wooden carriage with large thin spoked wheels, with a small anthropomorphic mouse gunner crouched on the gun carriage. Gritty realistic AAA-game concept art, highly detailed. Dark iron. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_hp` | Single prop, short stubby thick-walled Napoleonic mortar on a heavy low weathered dark wooden block carriage, with a small anthropomorphic mouse gunner crouched on the carriage. Gritty realistic AAA-game concept art, highly detailed. Dark iron. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_atk` | Single prop, long-barreled Napoleonic field gun on a reinforced weathered dark wooden carriage, with a small anthropomorphic mouse gunner crouched on the gun carriage. Gritty realistic AAA-game concept art, highly detailed. Dark iron barrel. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_mix` | Single prop, small Napoleonic field cannon on a weathered dark wooden carriage, with a small anthropomorphic mouse gunner crouched on the gun carriage. Gritty realistic AAA-game concept art, highly detailed. Dark iron. Clean neutral studio background, the cannon and one gunner only, no text. |

### Varken -- varken-infanterie + everzwijn als big bro (ex-Mens)

*Varkens zijn van nature dikkig: elke variant blijft plomp en rond, ook de spd (alleen relatief slanker, nooit spichtig).*

| Bestand | Prompt |
|---|---|
| `infantry_base` | Single character, plump, chubby build anthropomorphic pig with a big flat upturned snout, floppy ears and a curly tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and dark grey bicorne hat, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_spd` | Single character, lighter and leaner but still plump and round-bellied young anthropomorphic pig with a big flat upturned snout, floppy ears and a curly tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic short military jacket and dark grey bicorne hat, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_hp` | Single character, enormously fat, pot-bellied, short and squat anthropomorphic pig with a big flat upturned snout, floppy ears and a curly tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform with a dark steel cuirass and dark grey bicorne hat, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_atk` | Single character, gigantic, hulking and heavily-muscled but still thick, porky and round-bellied anthropomorphic pig with a big flat upturned snout, floppy ears and a curly tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and dark grey bicorne hat, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_mix` | Single character, plump, chubby build anthropomorphic pig soldier with a big flat upturned snout, floppy ears and a curly tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and dark grey bicorne hat, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_base` | Single character, towering powerful anthropomorphic wild boar with enormous upward-curving tusks, a bristly spined back and a broad snout, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_spd` | Single character, towering yet whip-thin, greyhound-lean and long-limbed anthropomorphic wild boar with enormous upward-curving tusks, a bristly spined back and a broad snout, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_hp` | Single character, towering, colossally fat, round and squat anthropomorphic wild boar with enormous upward-curving tusks, a bristly spined back and a broad snout, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps with dark steel armor plates over the harness, low stance, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_atk` | Single character, towering, monstrously muscular, hulking and battle-scarred anthropomorphic wild boar with enormous upward-curving tusks, a bristly spined back and a broad snout, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps with bared teeth, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_mix` | Single character, towering sturdy anthropomorphic wild boar with enormous upward-curving tusks, a bristly spined back and a broad snout, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| Bestand | Prompt |
|---|---|
| `artillery_base` | Single prop, Napoleonic field cannon on a weathered dark wooden gun carriage with two spoked wheels, with a small anthropomorphic pig gunner crouched on the gun carriage. Gritty realistic AAA-game concept art, highly detailed. Dark iron barrel. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_spd` | Single prop, light Napoleonic horse-artillery cannon with a slender barrel on a weathered dark wooden carriage with large thin spoked wheels, with a small anthropomorphic pig gunner crouched on the gun carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_hp` | Single prop, short thick Napoleonic fortress mortar on a heavy low weathered wooden block carriage, with a small anthropomorphic pig gunner crouched on the carriage. Gritty realistic AAA-game concept art, highly detailed. Dark iron. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_atk` | Single prop, long-barreled heavy Napoleonic siege cannon on a reinforced weathered dark wooden carriage, with a small anthropomorphic pig gunner crouched on the gun carriage. Gritty realistic AAA-game concept art, highly detailed. Dark iron barrel. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_mix` | Single prop, Napoleonic field cannon on a weathered dark wooden carriage, with a small anthropomorphic pig gunner crouched on the gun carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |

### Leeuw -- cheetah-infanterie + leeuw als big bro

| Bestand | Prompt |
|---|---|
| `infantry_base` | Single character, average build anthropomorphic cheetah with bold black rosette spots and teardrop face stripes, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic officer's uniform with dark grey epaulettes and tall black bearskin cap, short trousers ending above the knee, completely barefoot: absolutely no boots, no shoes, no socks and no leg wraps, the bare furry lower legs and large bare clawed paws fully exposed and clearly visible, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_spd` | Single character, extremely tall, thin, lanky and long-limbed anthropomorphic cheetah sprinter with bold black rosette spots and teardrop face stripes, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic short military jacket and tall black bearskin cap, short trousers ending above the knee, completely barefoot: absolutely no boots, no shoes, no socks and no leg wraps, the bare furry lower legs and large bare clawed paws fully exposed and clearly visible, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_hp` | Single character, enormously fat, round, short and squat anthropomorphic cheetah with bold black rosette spots and teardrop face stripes, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic greatcoat with a dark steel cuirass and a tall black bearskin cap, short trousers ending above the knee, completely barefoot: absolutely no boots, no shoes, no socks and no leg wraps, the bare furry lower legs and large bare clawed paws fully exposed and clearly visible, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_atk` | Single character, gigantic, hulking, broad-shouldered and heavily-muscled anthropomorphic cheetah with bold black rosette spots and teardrop face stripes, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and tall black bearskin cap, short trousers ending above the knee, completely barefoot: absolutely no boots, no shoes, no socks and no leg wraps, the bare furry lower legs and large bare clawed paws fully exposed and clearly visible, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_mix` | Single character, average build anthropomorphic cheetah guard with bold black rosette spots and teardrop face stripes, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and tall black bearskin cap, short trousers ending above the knee, completely barefoot: absolutely no boots, no shoes, no socks and no leg wraps, the bare furry lower legs and large bare clawed paws fully exposed and clearly visible, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_base` | Single character, towering powerful anthropomorphic male lion with an enormous thick flowing mane, a broad muzzle and a tufted tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps and short trousers ending above the knee, completely barefoot: absolutely no boots, no shoes, no socks and no leg wraps, the bare furry lower legs and large bare clawed paws fully exposed and clearly visible, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_spd` | Single character, towering yet whip-thin, greyhound-lean and long-limbed anthropomorphic male lion with an enormous thick flowing mane, a broad muzzle and a tufted tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps and short trousers ending above the knee, completely barefoot: absolutely no boots, no shoes, no socks and no leg wraps, the bare furry lower legs and large bare clawed paws fully exposed and clearly visible, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_hp` | Single character, towering, colossally fat, round and squat anthropomorphic male lion with an enormous thick flowing mane, a broad muzzle and a tufted tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps with dark steel armor plates over the harness and short trousers ending above the knee, completely barefoot: absolutely no boots, no shoes, no socks and no leg wraps, the bare furry lower legs and large bare clawed paws fully exposed and clearly visible, low stance, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_atk` | Single character, towering, monstrously muscular, hulking and battle-scarred anthropomorphic male lion with an enormous thick flowing mane, a broad muzzle and a tufted tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps and short trousers ending above the knee, completely barefoot: absolutely no boots, no shoes, no socks and no leg wraps, the bare furry lower legs and large bare clawed paws fully exposed and clearly visible, with bared teeth, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_mix` | Single character, towering sturdy anthropomorphic male lion with an enormous thick flowing mane, a broad muzzle and a tufted tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps and short trousers ending above the knee, completely barefoot: absolutely no boots, no shoes, no socks and no leg wraps, the bare furry lower legs and large bare clawed paws fully exposed and clearly visible, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `artillery_base` | Single prop, long-barreled Napoleonic siege cannon on an ornate weathered dark wooden gun carriage with pewter detailing, with a small anthropomorphic cheetah gunner crouched on the gun carriage. Gritty realistic AAA-game concept art, highly detailed. Dark iron. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_spd` | Single prop, light long slender Napoleonic culverin cannon on a weathered dark wooden carriage with large thin wheels and pewter detailing, with a small anthropomorphic cheetah gunner crouched on the gun carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_hp` | Single prop, massive short thick Napoleonic bombard on a heavy low weathered wooden carriage with pewter detailing, with a small anthropomorphic cheetah gunner crouched on the carriage. Gritty realistic AAA-game concept art, highly detailed. Dark bronze. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_atk` | Single prop, extra long-barreled heavy Napoleonic siege cannon on a wide reinforced weathered dark wooden carriage with pewter detailing, with a small anthropomorphic cheetah gunner crouched on the gun carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_mix` | Single prop, ornate Napoleonic field cannon on a weathered dark wooden carriage with pewter detailing, with a small anthropomorphic cheetah gunner crouched on the gun carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |

### Beer -- wasbeer-infanterie + grizzly als big bro

> **`artillery_base` hieronder is NIET meer nodig.** De Beer verloor zijn
> kanonnen op 8 augustus (C19): ze kostten hem 21 procentpunt winst. Zijn comp
> is [19,3,0], dus hij mag er ook geen spawnen. De prompt blijft staan voor het
> geval de comp ooit weer artillerie krijgt.

| Bestand | Prompt |
|---|---|
| `infantry_base` | Single character, average build anthropomorphic raccoon with a bold black bandit-mask face, huge round ears and a thick black-ringed tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic greatcoat and dark grey round Russian ushanka-style fur hat with ear flaps, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_spd` | Single character, extremely tall, thin, lanky and long-limbed anthropomorphic raccoon with a bold black bandit-mask face, huge round ears and a thick black-ringed tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic short military jacket and dark grey round Russian ushanka-style fur hat with ear flaps, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_hp` | Single character, enormously fat, round-bellied, short and squat anthropomorphic raccoon with a bold black bandit-mask face, huge round ears and a thick black-ringed tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic greatcoat with a heavy dark iron breastplate and round Russian ushanka-style fur hat with ear flaps, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_atk` | Single character, gigantic, hulking, broad-shouldered and heavily-muscled anthropomorphic raccoon with a bold black bandit-mask face, huge round ears and a thick black-ringed tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and dark grey round Russian ushanka-style fur hat with ear flaps, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_mix` | Single character, average build anthropomorphic raccoon soldier with a bold black bandit-mask face, huge round ears and a thick black-ringed tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic greatcoat and round Russian ushanka-style fur hat with ear flaps, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_base` | Single character, towering powerful anthropomorphic grizzly bear with a massive shoulder hump, huge claws and a broad fanged muzzle, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_spd` | Single character, towering yet whip-thin, greyhound-lean and long-limbed anthropomorphic grizzly bear with a massive shoulder hump, huge claws and a broad fanged muzzle, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_hp` | Single character, towering, colossally fat, round and squat anthropomorphic grizzly bear with a massive shoulder hump, huge claws and a broad fanged muzzle, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps with dark steel armor plates over the harness, low stance, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_atk` | Single character, towering, monstrously muscular, hulking and battle-scarred anthropomorphic grizzly bear with a massive shoulder hump, huge claws and a broad fanged muzzle, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps with bared teeth, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_mix` | Single character, towering sturdy anthropomorphic grizzly bear with a massive shoulder hump, huge claws and a broad fanged muzzle, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `artillery_base` | Single prop, short thick Napoleonic fortress mortar on a weathered dark wooden block carriage, with a small anthropomorphic raccoon gunner crouched on the carriage. Gritty realistic AAA-game concept art, highly detailed. Dark iron. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_spd` | Single prop, light Napoleonic cannon mounted on a weathered wooden sled carriage, with a small anthropomorphic raccoon gunner crouched on the carriage. Gritty realistic AAA-game concept art, highly detailed. Dark iron. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_hp` | Single prop, heavy Napoleonic siege mortar on a massive low weathered wooden carriage, with a small anthropomorphic raccoon gunner crouched on the carriage. Gritty realistic AAA-game concept art, highly detailed. Dark iron. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_atk` | Single prop, wide-mouthed double Napoleonic mortar on a reinforced weathered dark wooden carriage, with a small anthropomorphic raccoon gunner crouched on the carriage. Gritty realistic AAA-game concept art, highly detailed. Dark iron. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_mix` | Single prop, Napoleonic winter field cannon on a weathered dark wooden carriage, with a small anthropomorphic raccoon gunner crouched on the gun carriage. Gritty realistic AAA-game concept art, highly detailed. Dark iron. Clean neutral studio background, the cannon and one gunner only, no text. |

### Wolf -- vos-infanterie + dire wolf als big bro (Wolf+Vos samengevoegd)

| Bestand | Prompt |
|---|---|
| `infantry_base` | Single character, average build anthropomorphic fox with huge pointed ears, a sharp narrow snout and a big bushy tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic tattered military uniform and dark grey forage cap, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_spd` | Single character, extremely tall, thin, lanky and long-limbed gaunt anthropomorphic fox with huge pointed ears, a sharp narrow snout and a big bushy tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic tattered short military jacket and forage cap, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_hp` | Single character, enormously fat, thick-furred, short and squat anthropomorphic fox with huge pointed ears, a sharp narrow snout and a big bushy tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic tattered greatcoat with a scavenged dark steel breastplate and dark grey forage cap, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_atk` | Single character, gigantic, hulking, broad-shouldered and heavily-muscled anthropomorphic fox with huge pointed ears, a big bushy tail and bared teeth, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic tattered military uniform and dark grey forage cap, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_mix` | Single character, average build anthropomorphic fox soldier with huge pointed ears, a sharp narrow snout and a big bushy tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic tattered military uniform and forage cap, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_base` | Single character, towering powerful anthropomorphic giant dire wolf with a shaggy mane, huge fangs and pointed ears, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_spd` | Single character, towering yet whip-thin, greyhound-lean and long-limbed anthropomorphic giant dire wolf with a shaggy mane, huge fangs and pointed ears, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_hp` | Single character, towering, colossally fat, round and squat anthropomorphic giant dire wolf with a shaggy mane, huge fangs and pointed ears, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps with dark steel armor plates over the harness, low stance, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_atk` | Single character, towering, monstrously muscular, hulking and battle-scarred anthropomorphic giant dire wolf with a shaggy mane, huge fangs and pointed ears, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps with bared teeth, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_mix` | Single character, towering sturdy anthropomorphic giant dire wolf with a shaggy mane, huge fangs and pointed ears, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `artillery_base` | Single prop, scavenged Napoleonic field cannon with ropes and burlap sacks tied around it, on a weathered dark wooden carriage, with a small anthropomorphic fox gunner crouched on the gun carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_spd` | Single prop, light Napoleonic mountain cannon on a small weathered dark wooden carriage, with a small anthropomorphic fox gunner crouched on the carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_hp` | Single prop, heavy scavenged Napoleonic cannon reinforced with scrap-iron plating bolted to the barrel, on a weathered dark wooden carriage, with a small anthropomorphic fox gunner crouched on the carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_atk` | Single prop, heavy scavenged Napoleonic cannon with extra powder kegs strapped to the weathered dark wooden carriage, with a small anthropomorphic fox gunner crouched on the gun carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_mix` | Single prop, scavenged Napoleonic field cannon on a patched weathered dark wooden carriage, with a small anthropomorphic fox gunner crouched on the gun carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |

### Krokodil -- hagedis-infanterie + krokodil als big bro (ex-Vos-slot)

**Thema**: schutkleur en hinderlaag (past bij de geheime-koppeling-perk).
Camouflage-patroon in de schubben; de artillerie zit onder netten en zeilen.

| Bestand | Prompt |
|---|---|
| `infantry_base` | Single character, average build anthropomorphic lizard with camouflage-pattern scales, big lidded eyes and a long tapering tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and a dark grey tricorne musketeer hat under a loose dark grey hooded cloak, unarmed, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_spd` | Single character, extremely tall, thin, lanky and long-limbed anthropomorphic gecko-like lizard with camouflage-pattern scales, big lidded eyes and a long tapering tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic short military jacket and dark grey tricorne musketeer hat, unarmed, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_hp` | Single character, enormously fat, round, short and squat anthropomorphic lizard with thick armored scutes and camouflage-pattern scales, big lidded eyes and a long tapering tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic greatcoat with a dark steel cuirass and a dark grey tricorne musketeer hat, unarmed, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_atk` | Single character, gigantic, hulking, broad-shouldered and heavily-muscled anthropomorphic lizard with camouflage-pattern scales, big lidded eyes and a long tapering tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and a dark grey tricorne musketeer hat under a half-open dark grey hooded cloak, unarmed, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_mix` | Single character, average build anthropomorphic lizard soldier with camouflage-pattern scales, big lidded eyes and a long tapering tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and dark grey tricorne musketeer hat, unarmed, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_base` | Single character, towering powerful anthropomorphic crocodile with a long toothy snout, armored scutes and a massive tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps low stance, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_spd` | Single character, towering yet whip-thin, greyhound-lean and long-limbed anthropomorphic crocodile with a long toothy snout, armored scutes and a massive tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps low stance, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_hp` | Single character, towering, colossally fat, round and squat anthropomorphic crocodile with a long toothy snout, thick armored scutes and a massive tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps with dark steel armor plates over the harness, very low stance, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_atk` | Single character, towering, monstrously muscular, hulking and battle-scarred anthropomorphic crocodile with a long toothy snout, armored scutes and a massive tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps with open jaws showing teeth, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_mix` | Single character, towering sturdy anthropomorphic crocodile with a long toothy snout, armored scutes and a massive tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps low stance, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `artillery_base` | Single prop, Napoleonic field cannon covered in dark grey camouflage netting with only the barrel protruding, on a weathered dark wooden carriage, with a small anthropomorphic lizard gunner crouched on the gun carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_spd` | Single prop, light Napoleonic cannon half covered by a dark grey tarp on a weathered dark wooden carriage with thin wheels, with a small anthropomorphic lizard gunner crouched on the carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_hp` | Single prop, Napoleonic cannon draped in heavy dark grey camouflage netting and burlap, on a low weathered dark wooden carriage, with a small anthropomorphic lizard gunner crouched on the carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_atk` | Single prop, long-barreled Napoleonic cannon with dark grey camouflage netting pulled aside, on a weathered dark wooden carriage, with a small anthropomorphic lizard gunner crouched on the gun carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_mix` | Single prop, Napoleonic field cannon with a folded dark grey tarp on the weathered dark wooden carriage, with a small anthropomorphic lizard gunner crouched on the carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |

## 3c. Musketten per character (alleen infanterie)

Elke infanterie-pion krijgt een **eigen musket-glb** (`<model>_musket.glb`,
optioneel; ontbreekt hij, dan valt de pion terug op `<factie>/musket.glb`). Het
wapen leest als het lijf: **de vorm van het geweer verraadt het archetype in
een oogopslag**, net als de bouw. Cavalerie (big bro/bereden) en artillerie
krijgen GEEN musket -- de game hangt die alleen aan infanterie.

**Silhouet per archetype (dit is wat je ziet):**

| Archetype | Musket-silhouet |
|---|---|
| `base` | standaard Napoleontisch vuursteenmusket, middellang, met vaste bajonet |
| `spd` | extra lang, spichtig, licht scherpschutters-geweer: dunne lange loop, minimale beslag |
| `hp` | dik, zwaar **dubbelloops** musket (twee lopen naast elkaar), **middellange loop**, met verstevigingsbanden |
| `atk` | log **groot-kaliber** musket, **middellange loop**, brede monding + overmaatse vaste bajonet-spies |
| `mix` | compacte, kale kortloops karabijn |

**Factie-twist (materiaal/decoratie, het tweede leesspoor):** Muis = dof donker
ijzer + versleten licht hout · Varken = massief donker hout met zware messing
beslagen · Leeuw = officiers-walnoot met sierlijk verguld tin-graveerwerk · Beer
= vorstig donker ijzer met bontgewikkelde greep · Wolf = geschraapt allegaartje,
schroot-reparaties en touwgewikkelde kolf · Krokodil = mat donker ijzer
omwikkeld met donkergrijze camouflagedoek.

**Prompt-template:** `Single prop, <silhouet>, <factie-twist>. Gritty realistic
AAA-game concept art, highly detailed. Side profile view, clean
neutral studio background, the weapon only, no hands, no text.`

### Muis-musketten

| Bestand | Prompt |
|---|---|
| `infantry_base_musket` | Single prop, a standard-length Napoleonic flintlock musket with a fixed bayonet, plain dark iron and worn pale wood. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `infantry_spd_musket` | Single prop, an extra-long, very slender lightweight sharpshooter's long rifle with a thin barrel, minimal fittings and a fixed bayonet, plain dark iron and worn pale wood. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `infantry_hp_musket` | Single prop, a thick, heavy double-barrelled musket with a medium-length barrel, two side-by-side barrels, reinforced bands and a fixed bayonet, plain dark iron and worn pale wood. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `infantry_atk_musket` | Single prop, a massive heavy big-bore musket with a medium-length barrel, a wide muzzle and an oversized fixed bayonet-spike, plain dark iron and worn pale wood. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `infantry_mix_musket` | Single prop, a compact plain short-barrelled carbine with a fixed bayonet, plain dark iron and worn pale wood. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |

### Varken-musketten

| Bestand | Prompt |
|---|---|
| `infantry_base_musket` | Single prop, a standard-length Napoleonic flintlock musket with a fixed bayonet, chunky dark wood with heavy brass fittings. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `infantry_spd_musket` | Single prop, an extra-long, very slender lightweight sharpshooter's long rifle with a thin barrel, minimal fittings and a fixed bayonet, chunky dark wood with heavy brass fittings. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `infantry_hp_musket` | Single prop, a thick, heavy double-barrelled musket with a medium-length barrel, two side-by-side barrels, reinforced bands and a fixed bayonet, chunky dark wood with heavy brass fittings. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `infantry_atk_musket` | Single prop, a massive heavy big-bore musket with a medium-length barrel, a wide muzzle and an oversized fixed bayonet-spike, chunky dark wood with heavy brass fittings. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `infantry_mix_musket` | Single prop, a compact plain short-barrelled carbine with a fixed bayonet, chunky dark wood with heavy brass fittings. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |

### Leeuw-musketten

| Bestand | Prompt |
|---|---|
| `infantry_base_musket` | Single prop, a standard-length Napoleonic flintlock musket with a fixed bayonet, officer-grade dark walnut with ornate gilded pewter engraving. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `infantry_spd_musket` | Single prop, an extra-long, very slender lightweight sharpshooter's long rifle with a thin barrel, minimal fittings and a fixed bayonet, officer-grade dark walnut with ornate gilded pewter engraving. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `infantry_hp_musket` | Single prop, a thick, heavy double-barrelled musket with a medium-length barrel, two side-by-side barrels, reinforced bands and a fixed bayonet, officer-grade dark walnut with ornate gilded pewter engraving. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `infantry_atk_musket` | Single prop, a massive heavy big-bore musket with a medium-length barrel, a wide muzzle and an oversized fixed bayonet-spike, officer-grade dark walnut with ornate gilded pewter engraving. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `infantry_mix_musket` | Single prop, a compact plain short-barrelled carbine with a fixed bayonet, officer-grade dark walnut with ornate gilded pewter engraving. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |

### Beer-musketten

| Bestand | Prompt |
|---|---|
| `infantry_base_musket` | Single prop, a standard-length Napoleonic flintlock musket with a fixed bayonet, frost-worn dark iron with a fur-wrapped grip. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `infantry_spd_musket` | Single prop, an extra-long, very slender lightweight sharpshooter's long rifle with a thin barrel, minimal fittings and a fixed bayonet, frost-worn dark iron with a fur-wrapped grip. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `infantry_hp_musket` | Single prop, a thick, heavy double-barrelled musket with a medium-length barrel, two side-by-side barrels, reinforced bands and a fixed bayonet, frost-worn dark iron with a fur-wrapped grip. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `infantry_atk_musket` | Single prop, a massive heavy big-bore musket with a medium-length barrel, a wide muzzle and an oversized fixed bayonet-spike, frost-worn dark iron with a fur-wrapped grip. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `infantry_mix_musket` | Single prop, a compact plain short-barrelled carbine with a fixed bayonet, frost-worn dark iron with a fur-wrapped grip. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |

### Wolf-musketten

| Bestand | Prompt |
|---|---|
| `infantry_base_musket` | Single prop, a standard-length Napoleonic flintlock musket with a fixed bayonet, scavenged mismatched parts with scrap-metal repairs and a rope-bound stock. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `infantry_spd_musket` | Single prop, an extra-long, very slender lightweight sharpshooter's long rifle with a thin barrel, minimal fittings and a fixed bayonet, scavenged mismatched parts with scrap-metal repairs and a rope-bound stock. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `infantry_hp_musket` | Single prop, a thick, heavy double-barrelled musket with a medium-length barrel, two side-by-side barrels, reinforced bands and a fixed bayonet, scavenged mismatched parts with scrap-metal repairs and a rope-bound stock. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `infantry_atk_musket` | Single prop, a massive heavy big-bore musket with a medium-length barrel, a wide muzzle and an oversized fixed bayonet-spike, scavenged mismatched parts with scrap-metal repairs and a rope-bound stock. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `infantry_mix_musket` | Single prop, a compact plain short-barrelled carbine with a fixed bayonet, scavenged mismatched parts with scrap-metal repairs and a rope-bound stock. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |

### Krokodil-musketten

| Bestand | Prompt |
|---|---|
| `infantry_base_musket` | Single prop, a standard-length Napoleonic flintlock musket with a fixed bayonet, matte dark iron wrapped in dark grey camouflage cloth. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `infantry_spd_musket` | Single prop, an extra-long, very slender lightweight sharpshooter's long rifle with a thin barrel, minimal fittings and a fixed bayonet, matte dark iron wrapped in dark grey camouflage cloth. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `infantry_hp_musket` | Single prop, a thick, heavy double-barrelled musket with a medium-length barrel, two side-by-side barrels, reinforced bands and a fixed bayonet, matte dark iron wrapped in dark grey camouflage cloth. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `infantry_atk_musket` | Single prop, a massive heavy big-bore musket with a medium-length barrel, a wide muzzle and an oversized fixed bayonet-spike, matte dark iron wrapped in dark grey camouflage cloth. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `infantry_mix_musket` | Single prop, a compact plain short-barrelled carbine with a fixed bayonet, matte dark iron wrapped in dark grey camouflage cloth. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |

## 3c-2. Melee-wapens per big bro (cavalerie)

De big bro vecht met zijn handen tot hij een wapen heeft; elk krijgt een
**eigen melee-wapen-glb** (`cavalry_<archetype>_melee.glb`, naast het model).
Alles komt uit het **echte Napoleontische arsenaal** (besluit Max, 30 juli):
briquet-sabels, sapeurs-bijlen, pallasch, lansen, partizanen-buit en
enter-wapens -- geen fantasy-knotsen. Zelfde leeswijze als de musketten,
maar uniek per vak: de **wapenfamilie** verraadt de factie, de **variant**
het archetype. Nog niet ingebouwd in het spel (props hangen nu alleen aan
infanterie): de bestandsnaam-conventie staat vast zodat de inbouw later
zonder hernoemen kan.

**Wapenfamilie per factie (het karakter):**

| Factie | Familie |
|---|---|
| Muis (rat) | infanterie-briquets (korte soldaten-sabels) |
| Varken (everzwijn) | sapeurs-bijlen |
| Leeuw | officiers-klingen (sabel, smallsword, pallasch) |
| Beer (grizzly) | kozakken-lansen |
| Wolf (dire wolf) | buitgemaakte wapens (partizanen-oorlog) |
| Krokodil | enter-wapens (marine) |

**Variant per archetype** (zelfde logica als de musketten): `base` =
standaard · `spd` = lang, dun, licht (bereik) · `hp` = kort, dik,
verstevigd · `atk` = overmaats zwaar · `mix` = compact en kaal.

### Muis (rat) -- melee

| Bestand | Prompt |
|---|---|
| `cavalry_base_melee` | Single prop, a standard Napoleonic infantry briquet short sabre with a curved single-edged blade and a simple stirrup guard, plain dark iron with a worn pale wooden grip. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_spd_melee` | Single prop, a long narrow light-cavalry sabre with a deeply curved slender blade, plain dark iron with a worn pale wooden grip. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_hp_melee` | Single prop, a short thick Napoleonic artillery gladius short sword with a broad reinforced blade, plain dark iron with a worn pale wooden grip. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_atk_melee` | Single prop, an oversized heavy briquet sabre with a wide chopping blade and a crude iron guard, plain dark iron with a worn pale wooden grip. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_mix_melee` | Single prop, a plain infantry hanger with a short straight blade, plain dark iron with a worn pale wooden grip. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |

### Varken (everzwijn) -- melee

| Bestand | Prompt |
|---|---|
| `cavalry_base_melee` | Single prop, a Napoleonic sapper's felling axe with a broad bearded blade, chunky dark wood haft with heavy brass fittings. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_spd_melee` | Single prop, a long-hafted light sapper's axe with a narrow blade, chunky dark wood haft with heavy brass fittings. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_hp_melee` | Single prop, a short double-bitted sapper's axe with two thick reinforced heads, chunky dark wood haft with heavy brass fittings. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_atk_melee` | Single prop, a colossal two-handed sapper's broadaxe with an oversized bearded blade, chunky dark wood haft with heavy brass fittings. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_mix_melee` | Single prop, a compact plain pioneer hand axe with a simple flat head, chunky dark wood haft with heavy brass fittings. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |

### Leeuw -- melee

| Bestand | Prompt |
|---|---|
| `cavalry_base_melee` | Single prop, a curved Napoleonic officer's cavalry sabre with an elegant swept guard, officer-grade dark walnut grip with ornate gilded pewter engraving. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_spd_melee` | Single prop, a long slender officer's smallsword with a fine needle blade and a delicate swept hilt, officer-grade dark walnut grip with ornate gilded pewter engraving. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_hp_melee` | Single prop, a heavy cuirassier pallasch broadsword with a wide straight reinforced blade and a full basket guard, officer-grade dark walnut grip with ornate gilded pewter engraving. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_atk_melee` | Single prop, a massive heavy-cavalry pallasch with an extra long broad blade and a crowned pommel, officer-grade dark walnut grip with ornate gilded pewter engraving. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_mix_melee` | Single prop, a plain officer's spadroon with a simple stirrup guard, officer-grade dark walnut grip with ornate gilded pewter engraving. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |

### Beer (grizzly) -- melee

| Bestand | Prompt |
|---|---|
| `cavalry_base_melee` | Single prop, a Russian cossack lance with an iron spearhead and a small tattered pennant, frost-worn dark iron with a fur-wrapped grip. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_spd_melee` | Single prop, an extra-long slender light lance with a narrow needle point, frost-worn dark iron with a fur-wrapped grip. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_hp_melee` | Single prop, a short thick boar-spear with a broad reinforced head and an iron crossbar, frost-worn dark iron with a fur-wrapped grip. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_atk_melee` | Single prop, a massive heavy uhlan lance with an oversized armor-piercing point, frost-worn dark iron with a fur-wrapped grip. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_mix_melee` | Single prop, a plain short pike with a simple iron tip, frost-worn dark iron with a fur-wrapped grip. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |

### Wolf (dire wolf) -- melee

| Bestand | Prompt |
|---|---|
| `cavalry_base_melee` | Single prop, a captured Napoleonic dragoon sabre with a notched blade and a rope-mended grip, scavenged mismatched parts with scrap-metal repairs. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_spd_melee` | Single prop, a long partisan war scythe blade mounted upright on a rough wooden pole, scavenged mismatched parts with scrap-metal repairs. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_hp_melee` | Single prop, a short heavy hacking falchion reforged from a broken cuirassier blade, scavenged mismatched parts with scrap-metal repairs. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_atk_melee` | Single prop, a massive captured cuirassier pallasch with a scrap-iron repaired hilt and a chipped blade, scavenged mismatched parts with scrap-metal repairs. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_mix_melee` | Single prop, a plain peasant hatchet with a simple worn head, scavenged mismatched parts with scrap-metal repairs. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |

### Krokodil -- melee

| Bestand | Prompt |
|---|---|
| `cavalry_base_melee` | Single prop, a broad naval boarding cutlass with a curved blade and a full sheet-iron guard, matte dark iron wrapped in dark grey camouflage cloth. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_spd_melee` | Single prop, a long slender naval boarding pike with a narrow iron spike, matte dark iron wrapped in dark grey camouflage cloth. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_hp_melee` | Single prop, a short thick naval boarding axe with a reinforced head and a rear spike, matte dark iron wrapped in dark grey camouflage cloth. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_atk_melee` | Single prop, a massive two-handed boarding axe with an oversized blade and a long back spike, matte dark iron wrapped in dark grey camouflage cloth. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_mix_melee` | Single prop, a plain short cutlass with a simple curved blade, matte dark iron wrapped in dark grey camouflage cloth. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |

## 3d. Figuranten -- vaandeldrager, tamboer, sapeur (props op de basissoldaat)

*Besluit Max, 28 juli 2026.* Elk Napoleontisch regiment liep rond met een paar
onmiskenbare figuren: de **vaandeldrager** met de adelaar, de **tamboer** die de
pas sloeg, de **hoornblazer**, de bebaarde **sapeur** met zijn bijl, de
**marketentster** met haar vaatje en de **tamboer-majeur** met zijn versierde
staf.

**De regel: ONGEKOPPELDE pionnen zijn de figuranten.**

Een pion zonder gekoppelde kaart vecht niet -- en dat is nou precies wat een
tamboer of vaandeldrager is. Zolang een pion geen kaart heeft draagt hij geen
musket maar een **attribuut**; zodra je een kaart koppelt wordt het weer de
gewone soldaat met zijn archetype-silhouet (dun/dik/breed). Loskoppelen? Dan
pakt hij zijn trommel weer op.

**Geen nieuwe karakters nodig (besluit Max):** het karaktermodel blijft gewoon
de bestaande `infantry_base` van de factie. Alleen de prop in de hand
verschilt -- exact hetzelfde mechaniek als het musket dat er nu al hangt. Je
maakt dus **zes losse props** in plaats van 24 karakters.

| Prop | Rol | Voorwerp-omschrijving (prompt-kern) |
|---|---|---|
| `prop_flag` | vaandeldrager | **alleen de KALE STOK**: tall bare Napoleonic flag pole of dark weathered wood with a metal eagle finial on top, no banner or cloth attached |
| `prop_drum` | tamboer | Napoleonic military side drum with a dark wooden shell, rope tensioning, worn drumheads and a pair of sticks |
| `prop_horn` | hoornblazer | coiled brass Napoleonic cavalry bugle with a woven cord |
| `prop_axe` | sapeur | heavy sapper felling axe with a long dark wooden haft and a broad iron head |
| `prop_barrel` | marketentster | small canteen-woman brandy keg on a leather sling |
| `prop_mace` | tamboer-majeur | ornate Napoleonic drum-major mace with a long dark staff, heavy gilded head and hanging cords with tassels |

**Prompt-template:** `Single prop, <voorwerp>. Gritty realistic AAA-game concept
art, highly detailed. Side profile view, clean neutral studio
background, the object only, no hands, no text.`

**Het vaandel-doek komt uit Godot, niet uit de glb** (besluit Max, 28 juli):
`prop_flag` is alleen de kale stok. Het doek is een rechthoekig vlak dat het
spel er zelf aan hangt, **in de teamkleur** (rood/blauw) en met een
wapper-shader. Zo kun je maat, kleur en later een embleem in code aanpassen in
plaats van ze vast te bakken in een model, en zie je van bovenaf meteen van wie
de vlag is. Bewust géén echte cloth-physics (SoftBody): dat is duur, het jittert
en je ziet het toch nauwelijks op bord-afstand. Het doek is bovendien **niet vlak gekleurd**: de shader legt er
procedureel weefsel, modder- en kruitvlekken, verbleekte randen, licht/donker
in de vouwen en een gerafelde buitenrand overheen -- dat scheelt een texture en
het schaalt met elke kleur. Knoppen staan bovenaan `pawn_view.gd`:
`VLAG_BREEDTE`, `VLAG_HOOGTE`, `VLAG_ZAKT` en de shader-uniforms
`amp`/`snelheid`/`golf` plus `vuil` (0 = schoon, 1 = smerig veldvaandel) en
`rafel` (0 = strak afgezoomd).

**Bestandspad:** `assets/models/props/<prop>.glb` (gedeeld door alle facties).
Wil je een factie-eigen variant -- een muizentrommel is nu eenmaal geen
berentrommel -- zet 'm dan als `assets/models/<factie>/<prop>.glb`; die wint.
Statische mesh: **geen rig, geen animatie, geen gibs, geen team-texture**.
Fijnafstelling (schaal/positie/rotatie in de hand) gaat via de Model-tuner,
net als bij het musket.

Waarom dit goed werkt:

1. **Het is leesbare spelinformatie.** Je ziet in een oogopslag wie nog
   ongekoppeld (en dus inactief) is.
2. **Het stat-silhouet blijft heilig** (sectie 1): een ongekoppelde pion heeft
   geen stats om te tonen, dus er gaat geen informatie verloren.
3. **Puur cosmetisch.** Geen stat, geen perk; de staat verandert niet, dus
   goldens en replays blijven byte-identiek.
4. **Deterministisch.** Welke pion welk attribuut krijgt volgt uit zijn pion-id
   (nooit `randi()`), dus dezelfde replay ziet er elke keer identiek uit.
5. **Altijd TWEE vaandels en TWEE tamboers** (besluit Max, 28 juli): de
   eerste vier infanteristen van ELK leger krijgen die rollen vast
   (vaandel, trommel, vaandel, trommel), zodat een regiment er meteen als een
   regiment uitziet. Kleine legers (< 8 infanteristen) houden het bij een
   vaandel en een tamboer. De overige attributen -- hoorn, bijl, vat, staf --
   komen daarna sporadisch: ongeveer een op de vijf (`ROL_DICHTHEID` in
   `pawn_view.gd`; 1 = iedereen, 0 = alleen de vaste rollen). Het volgnummer
   telt per leger en telt gesneuvelden mee, dus de rol blijft de hele partij
   bij dezelfde pion horen.
6. **De prop vliegt mee bij de dood.** Sneuvelt een figurant, dan tuimelt zijn
   trommel of vaandel uit de handen het bord op en blijft liggen -- exact zoals
   het musket en de hoed dat al deden (`_fling_weapon`).
6. **Alleen infanterie**, en **ontbrekende props breken niets**: die pion
   draagt dan gewoon zijn musket. Je kunt dus met een enkele trommel beginnen.

**Code-haakje: GEBOUWD (28 juli).** `PawnView.set_character()` zet een rol op
ongekoppelde infanterie (`_rol_voor_pion()`), en `_attach_weapon()` hangt dan
`prop_for(rol, factie)` aan de hand in plaats van het musket -- met terugval op
het musket als de prop nog niet bestaat. Er is dus niets meer nodig aan de
codekant: elke prop die je in `assets/models/props/` zet, staat meteen in het
spel.

### Luxe-variant voor later (optioneel): eigen rol-karakters

Wil je ooit verder gaan dan een prop -- een tamboer met een echte
tamboer-jas, een sapeur met berenmuts en leren schort -- dan staan de
karakter-prompts hieronder klaar (`infantry_<rol>.glb`, valt terug op
`infantry_base`). **Niet nodig voor de figuranten-laag hierboven.**

### Rol-prompts per factie (4 per factie)

**Muis** -- de zwerm: alles is te groot voor ze, en dat is precies de grap.

| Bestand | Prompt |
|---|---|
| `infantry_flag` | Single character, average build anthropomorphic mouse with oversized round ears, long twitching whiskers and a pointed snout, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and dark grey shako, with an empty leather flag-carrier harness and bandolier across the chest, unarmed, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_drum` | Single character, average build anthropomorphic mouse with oversized round ears, long twitching whiskers and a pointed snout, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic drummer uniform with shoulder cords and dark grey shako, with an empty drum-sling strap over the shoulder, unarmed, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_horn` | Single character, extremely thin and lanky anthropomorphic mouse with oversized round ears, long twitching whiskers and a pointed snout, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic bugler uniform with cords and dark grey shako, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_canteen` | Single character, short round anthropomorphic mouse canteen-woman with oversized round ears and long whiskers, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered dark grey Napoleonic canteen-woman outfit, apron and small dark grey shako, with an empty leather barrel-sling across the chest, unarmed, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |

**Varken** -- boers en plomp: eten en drinken zijn nooit ver weg.

| Bestand | Prompt |
|---|---|
| `infantry_flag` | Single character, plump round-bellied anthropomorphic pig with a broad snout and floppy ears, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and dark grey shako, with a heavy leather flag-carrier harness and bandolier across the chest, unarmed, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_drum` | Single character, enormously fat round-bellied anthropomorphic pig with a broad snout and floppy ears, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic drummer uniform with shoulder cords and dark grey shako, with a wide empty drum-sling strap over the shoulder, unarmed, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_canteen` | Single character, plump anthropomorphic pig canteen-woman with a broad snout and floppy ears, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered dark grey Napoleonic canteen-woman outfit with a stained apron and headscarf, with an empty leather barrel-sling across the chest, unarmed, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_sapper` | Single character, broad heavyset anthropomorphic pig with a broad snout, floppy ears and a full bushy beard, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic sapper uniform with a thick leather work apron, crossed white belts and a tall dark bearskin cap, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |

**Leeuw** -- keizerlijke praal: dit is het regiment dat pronkt.

| Bestand | Prompt |
|---|---|
| `infantry_flag` | Single character, lean athletic anthropomorphic cheetah with spotted fur, tear-stripe markings and a slender build, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform with gold-trimmed epaulettes and a plumed dark grey shako, with an ornate gilded flag-carrier harness across the chest, unarmed, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_drummajor` | Single character, tall imposing anthropomorphic lion with a full flowing mane, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing an ornate weathered dark grey Napoleonic drum-major uniform with heavy gold braid, gold-fringed epaulettes, a sash and a towering plumed bearskin cap, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_horn` | Single character, lean athletic anthropomorphic cheetah with spotted fur and tear-stripe markings, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered dark grey Napoleonic trumpeter uniform with reversed colors, gold cords and a plumed dark grey shako, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_officer` | Single character, proud upright anthropomorphic lion with a full mane, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered dark grey Napoleonic officer coat with gold epaulettes, a silk waist sash, tall boots and a plumed bicorne hat worn sideways, with an empty sabre scabbard at the hip, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |

**Beer** -- zwaar en breed: de sapeur is hier de ster.

| Bestand | Prompt |
|---|---|
| `infantry_sapper` | Single character, massive broad-shouldered anthropomorphic raccoon with a black facial mask, ringed tail and an enormous bushy beard, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic sapper uniform with a heavy studded leather work apron, crossed belts, gauntlets and a huge dark bearskin cap, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_flag` | Single character, stocky heavyset anthropomorphic raccoon with a black facial mask and ringed tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform with a dark steel cuirass and dark grey shako, with a reinforced leather flag-carrier harness across the chest, unarmed, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_drum` | Single character, stocky heavyset anthropomorphic raccoon with a black facial mask and ringed tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic drummer uniform with heavy shoulder cords and dark grey shako, with a wide reinforced empty drum-sling over the shoulder, unarmed, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_medic` | Single character, stocky anthropomorphic raccoon with a black facial mask, ringed tail and small round spectacles, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered dark grey Napoleonic field-surgeon coat with rolled-up sleeves, a blood-stained apron, a satchel strap across the chest and a soft dark grey forage cap, unarmed, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |

**Wolf** -- jagers en stropers: gehavend, geimproviseerd, sluw.

| Bestand | Prompt |
|---|---|
| `infantry_horn` | Single character, lean anthropomorphic fox with a narrow muzzle, alert pointed ears and a bushy tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic light-infantry uniform with a green-tipped plume, hunting cords and a dark grey shako, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_flag` | Single character, lean anthropomorphic fox with a narrow muzzle and bushy tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a battered, strictly dark grey Napoleonic uniform patched with scavenged fur and a dark grey shako, with a crude rope-and-leather flag-carrier harness across the chest, unarmed, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_scout` | Single character, wiry anthropomorphic fox with a narrow muzzle and bushy tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered dark grey Napoleonic skirmisher uniform with a short cut-down coat, a rolled blanket over the shoulder, a spyglass case on the belt and a soft dark grey forage cap, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_drum` | Single character, lean anthropomorphic fox with a narrow muzzle and bushy tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a battered, strictly dark grey Napoleonic drummer uniform with frayed shoulder cords and a dark grey shako, with a worn empty drum-sling over the shoulder, unarmed, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |

**Krokodil** -- moeras en schutkleur: alles is gedempt en omwikkeld.

| Bestand | Prompt |
|---|---|
| `infantry_flag` | Single character, average build anthropomorphic lizard with mottled camouflage scales, slit eyes and a long tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic uniform wrapped in dark camouflage cloth and a dark grey shako, with a cloth-wrapped flag-carrier harness across the chest, unarmed, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_scout` | Single character, low-slung sinewy anthropomorphic lizard with mottled camouflage scales, slit eyes and a long tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered dark grey Napoleonic skirmisher uniform draped with a ragged swamp-reed camouflage cloak, netting over the shoulders and a soft dark grey forage cap, unarmed, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_drum` | Single character, average build anthropomorphic lizard with mottled camouflage scales and slit eyes, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic drummer uniform with muted cords and a dark grey shako, with a cloth-wrapped empty drum-sling over the shoulder, unarmed, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_officer` | Single character, tall imposing anthropomorphic crocodile with armored scales, a long snout and heavy jaws, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered dark grey Napoleonic officer coat with muted dark braid, a waist sash, a spyglass on the belt and a plain bicorne hat, with an empty sabre scabbard at the hip, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |

### Tracker -- figuranten-props (6 stuks)

Status: `-` gewenst | `~` in aanmaak | `x` in het spel

| Prop | Rol | Status |
|---|---|---|
| `prop_flag` | vaandeldrager | - |
| `prop_drum` | tamboer | - |
| `prop_horn` | hoornblazer | - |
| `prop_axe` | sapeur | - |
| `prop_barrel` | marketentster | - |
| `prop_mace` | tamboer-majeur | - |

*(De 24 rol-karakters uit de luxe-variant hierboven zijn optioneel en staan
niet in deze tracker; zie `model-tracker.html` voor de klikbare versie van de
props.)*


**Verdeling over het bord** (besluit Max, 30 juli): vlaggen staan minimaal 4
VAKKEN uit elkaar, trommels ook. Dat gaat op echte afstand, niet op volgnummer:
het spel houdt bestaande dragers vast zolang ze mogen dragen, vult vacatures met
de kandidaat die het verst van de andere dragers staat, en geeft een rol door
als twee dragers tijdens het oprukken toch te dicht bij elkaar komen. Kleine
legers (< 8 infanteristen) krijgen alleen het eerste stel. De sporadische extra
props (hoorn, bijl, vat, staf) mogen wel op volgnummer: dat is toevallige
aankleding. De vaandeldrager staat rechtop en kijkt niet heen en weer -- anders
zwiept de vlag door het beeld. Het spel kiest daarvoor NIET de eerste idle,
maar meet per model welke rustanimatie de kop het minst beweegt (de exports
zetten ze niet in dezelfde volgorde: bij atk zwaait "Idle 1" 70 graden, bij spd
maar 1). Wil je het zelf vastzetten: `vlag_idle` in effects_tuning.json,
index in de variantenlijst, -1 = automatisch.

## 3e. Teamkleur-texturen -- witte banden, zilver of goud (Max, 30 juli)

Het model zelf blijft **strikt donkergrijs**; de teamkleur zit in de texture die
ernaast ligt. Bestandsnamen (het spel pakt ze op modelnaam):

| Bestand | Waarvoor |
|---|---|
| `<model>_blue.png` | blauw leger |
| `<model>_red.png` | rood leger |
| `<model>_blue_gore.png` / `<model>_red_gore.png` | bloederige recolor voor de gibs (optioneel) |

**Dezelfde UV-atlas als het model.** Makkelijkste route: een team klaarmaken en
daarna alleen de metaaldelen en de pluim omkleuren.

### Wat per team verschilt

| Onderdeel | Blauw | Rood |
|---|---|---|
| Kruisbanden / bandelier | wit | wit |
| Knopen | zilver | goud |
| Schouderstukken (epauletten) | zilver | goud |
| Pluim op de shako | blauw | rood |
| Uniform | donkergrijs (gelijk) | donkergrijs (gelijk) |
| Leer (schoenen, patroontas, riem) | donkerbruin (gelijk) | donkerbruin (gelijk) |

### Prompt -- blauw team (`<model>_blue.png`)

```
Texture repaint of the same character, identical UV layout, only colours change.
Weathered dark grey Napoleonic uniform, crisp white crossbelts and white waist belt,
silver metal buttons in two rows, silver bullion epaulettes on both shoulders,
a blue upright feather plume on the shako, dark brown leather shoes and cartridge pouch.
Gritty realistic AAA-game texture, subtle dirt and wear, no text, no logo.
```

### Prompt -- rood team (`<model>_red.png`)

```
Texture repaint of the same character, identical UV layout, only colours change.
Weathered dark grey Napoleonic uniform, crisp white crossbelts and white waist belt,
gold metal buttons in two rows, gold bullion epaulettes on both shoulders,
a red upright feather plume on the shako, dark brown leather shoes and cartridge pouch.
Gritty realistic AAA-game texture, subtle dirt and wear, no text, no logo.
```

### Prompt -- gore-variant (`<model>_<team>_gore.png`)

```
Same texture, identical UV layout, battle damage version: dark blood soaked into the
grey wool, red splatter across the white belts, torn fabric edges, dulled and scratched
metal. Gritty realistic AAA-game texture, no text, no logo.
```

**Voor de andere facties**: alleen de pluim en het metaal volgen het team; de
factie-eigen dingen (Krokodil-camouflagedoek, Wolf-lappen en vacht,
Beer-kuras) houden hun eigen kleur. Vervang in de prompt "dark grey Napoleonic
uniform" door de factie-beschrijving uit 3, en laat de regel over witte banden,
knopen, epauletten en pluim staan zoals hij is.

## 4. Nieuw model importeren -- stap voor stap

De volledige pijplijn (bewezen op muis base + spd, 8-9 juli). Per model lever
je **2 glb-exports uit hetzelfde .blend + textures**; de rest draait het
merge-script.

### Wat je per model levert

| Bestand | Wat | Verplicht |
|---|---|---|
| `<model>.glb` | geanimeerd model, **losse delen**, met skin + animatie | ja |
| `<model>_gibs.glb` | dezelfde losse delen, **zonder** skin + animatie (statisch) | ja (voor gibs) |
| `<model>_red.png` + `<model>_blue.png` | team-uniformen (rood/blauw leger) | ja |
| `<model>_red_gore.png` + `<model>_blue_gore.png` | bloederige recolor voor de gibs | optioneel |
| `<model>_musket.glb` | eigen musket; anders valt het terug op `<factie>/musket.glb` | optioneel |

Pad-conventie: `assets/models/<factie>/<type>_<archetype>.glb` (zie 4b).

### De stappen

1. **Genereer** het model (Tripo/Meshy, **Laag Poly ~1.000 tris**). Model met
   gescheiden lichaamsdelen is ideaal.
2. **Mixamo-rig** -- upload statisch in **A-/T-pose, zonder botten**; Mixamo
   auto-rigt (markers op kin/polsen/ellebogen/knieen/kruis). Download **1x** FBX
   "With Skin" (welke clip maakt niet uit; het gaat om het gerigde karakter).
3. **Blender -- delen splitsen & benoemen.** Knip het lijf in losse objecten en
   noem ze **exact**: `armL armR body hat legL legR tail` (Edit Mode -> selecteer
   per deel -> `P` -> Selection). Die namen sturen hoed-pop (`hat`) en de grote
   romp-poel (`body`). **Waarom los:** de enkel-ledemaat-kill verbergt een levend
   deel, dus het geanimeerde model moet losse delen hebben (1 mesh = geen limb-shed).
4. **Export 1 -- geanimeerd model** (`<model>.glb`): selecteer de **7 delen + de
   Armature**, File -> Export -> glTF 2.0 (.glb), **Skinning AAN, Animation AAN**.
5. **Export 2 -- gibs** (`<model>_gibs.glb`): selecteer **alleen de 7 delen**
   (niet de Armature), **Skinning UIT, Animation UIT**. Dit is de statische
   "gebakken" versie -- nodig omdat een skinned mesh niet los te slingeren is.
6. **Clips + rechtdraaien:**
   - Zitten alle 15 clips al in je .blend? Sleep `<model>.glb` op **`fix_model.bat`**
     (draait de kwartslag-fix; Mixamo levert bayonet/hit/ready ~90 graden gedraaid).
   - Missen er clips? Draai de donor-merge (kopieert alle clips van de master,
     met heup-schaal + kwartslag-fix + heup-locks):
     ```
     blender --background --python tools/blender_merge_character.py -- ^
         --base assets/models/<factie>/<model>.glb ^
         --donor assets/models/mouse/infantry_base.glb
     ```
     De **muis** is de master voor alle infanterie (rifle-set incl. `ready_up`).
     Draai de donor altijd tegen de **huidige** base (die is al gefixt).
7. **Textures schilderen** -- `<model>_red.png` + `<model>_blue.png` (en optioneel
   `_red_gore`/`_blue_gore`) op **dezelfde UV-atlas**. Makkelijkst: rood klaar ->
   dupliceren -> alleen de uniform-delen blauw overschilderen; en voor gore je
   team-texture dupliceren + bloed/scheuren erover.
8. **Textures verkleinen (belangrijk!)** -- zet in Godot de import van elke grote
   team/gore-PNG op **`process/size_limit=1024` + `mipmaps/generate=true`**. Zonder
   dit laadt een 4096-plaatje (~67MB VRAM) vers op het eerste gib-moment -> korte
   freeze. Op gib-formaat is 1024 onzichtbaar. De 4096-bron blijft intact.
9. **Godot importeren** -- editor openen of `Godot --headless --path . --import`.
10. **Tunen (Model-tuner, hoofdmenu).** Alleen **positioneel/schaal** per model:
    schaal, hoogte, X/Z, **musket** (schaal/pos/rot) en **vuurmond** (muzzle flash).
    OPSLAAN -> `assets/models/model_tuning.json` (mee-committen). De **melee-timing
    is globaal** (`effects_tuning.json`, Melee-tab) -- gedeelde clips = gedeelde
    timing, dus die hoef je per model niet aan te raken.

### Mixamo-cliptabel (infanterie, rifle-set)

| Clip in het spel | Mixamo-zoekterm | Aantal |
|---|---|---|
| `idle` (+ `idle2`, `idle3`) | Rifle Idle | 1-3 |
| `walk` (+ `walk2`) | Walk With Rifle -- **"In Place" aanvinken!** | 1-3 |
| `attack` | Firing Rifle (enkel schot, staand) | 1 |
| `melee` (+ `melee2`) | Bayonet Attack / Rifle Butt | 1-2 (anders valt melee op attack terug) |
| `hit` (+ `hit2`) | Hit Reaction / Standing React Small | 1-2 (overleef-reactie) |
| `die` (+ `die2`) | Rifle Death / Standing Death (voor- en achterover) | 1-2 |
| `ready` (`ready_up`) | Rifle Down To Aim / Ready | optioneel (koppel-flourish) |

**Belangrijkste valkuilen (uit de praktijk):**
- **Twee exports, altijd** -- een skinned mesh kun je niet als losse brokken
  wegslingeren; het aparte `_gibs.glb` (armature-loos) IS de gebakken versie.
- **Kwartslag** -- Mixamo levert bayonet/hit/ready ~90 graden gedraaid; het
  merge-script/`fix_model.bat` meet de heup-yaw over de hele clip en draait
  alleen de echte rig-fouten terug (fire/idle-aanslag blijft).
- **1024-textures** -- anders hapert de gib.
- **Melee-timing = globaal, plaatsing = per model.**

Cavalerie (big bro) krijgt een eigen fight-clip-set (geen musket); die master
volgt zodra het eerste big-bro-model er is.

## 4b. Bestandsconventie & fallback

```
assets/models/<factie>/<type>_<archetype>.glb
```

- factie-map (Engels): `pig` `mouse` `lion` `bear` `wolf` `crocodile`
- type: `infantry` `cavalry` `artillery`
- archetype: `base` `spd` `hp` `atk` `mix`

**Fallback-keten**: `<type>_<archetype>.glb` → `<type>_<archetype>_<factie>.glb`
(de lange exportnaam) → `<type>_base.glb` → geometrisch stuk met
archetype-silhouet. Gibs mogen `_gibs.glb` of `.gibs.glb` heten.

**Namen zijn soepel geworden** (besluit Max, 29 juli): het spel maakt clip- en
deelnamen zelf schoon. "Death 1" wordt death1, "Arm.L" telt als armL. Je hoeft
in Blender dus niets meer te hernoemen -- exporteer zoals de pijplijn het
levert. Alles werkt dus ook met maar één model per type.
`mix` mag je overslaan (valt terug op `basis`).

**Prioriteit**: eerst de 16 `_base`-modellen (elke factie meteen een eigen
gezicht), dan per factie `spd`/`hp`/`atk` (de leesbaarheid), `mix` als laatste.
Volledige set: 80 bestanden, minus overgeslagen `mix` = 64.

## 5. Technische eisen per model

**Maat, positie en richting worden automatisch genormaliseerd** (auto-fit in
`PawnView`): het spel meet het model (bij skinned modellen via het skelet),
schaalt het naar tegelmaat (infanterie ~0,9 · cavalerie ~1,1 · artillerie ~0,8
hoog, voetafdruk binnen de tegel), zet de voeten op de grond, centreert het en
draait het 180° — AI-generators leveren modellen die naar de kijker (+Z)
kijken, de voorkant in het spel is −Z. Je hoeft dus níks op maat te maken.

- **Formaat**: `.glb` (glTF-binair; mesh + materialen + evt. animaties in één bestand)
- **Polycount: MAX 1.000 tris per karakter** (besluit juli 2026). De prompts
  blijven high-quality — genereer het rijke plaatje, en laat de **Laag
  Poly-modus van de generator (target ~1.000)** de mesh maken: het detail wordt
  als texture op de simpele mesh gebakken. Rekensom: 44 stukken × 1.000 = 44k
  tris — verwaarloosbaar, zelfs op een budget-telefoon, en <1 MB per model.
- **Textures**: **1024 max** (512 kan vaak ook — de texture draagt hier al het
  detail, dus niet té klein), **1 materiaal per model**, skelet **<50 botten**.
- Bij max 1.000 tris doet het **silhouet** het vorm-werk (zie §1): overdrijf de
  bouwverschillen tussen archetypes stevig, de texture vult de rest in.
- **Teamkleur**: hoeft niet in het model — het spel zet automatisch een
  rood/blauw sokkeltje onder elk `.glb`-model.
  **Gepland (team-textures)**: leg optioneel `<basis>_team1.png` (rood leger) en
  `<basis>_team2.png` (blauw leger) naast het model — recolors van de basis-texture
  met rode/blauwe uniform-accenten. Het spel kiest dan per team de juiste albedo;
  ontbreken de bestanden, dan blijft de basis-look + het sokkeltje. (Loader-kant
  wordt gebouwd zodra de eerste recolor er is.)
- **Gibs-gore-texture (gepland):** leg optioneel `<basis>_red_gore.png` / `<basis>_blue_gore.png`
  naast het model - een bloederige recolor van de team-texture. De brokstukken
  (uit `<basis>_gibs.glb`) krijgen die automatisch; ontbreekt hij, dan de gewone
  team-texture, anders de glb-texture. Zelfde UV-atlas als het hoofdmodel.
- **Animaties (optioneel)**: `AnimationPlayer` met clips `idle` / `walk` /
  `attack` / `die` wordt automatisch opgepakt (namen instelbaar op PawnView)
- Na het droppen éénmalig importeren: editor openen of
  `Godot --headless --path . --import`

## 6. Gratis bronnen (stijl past bij low-poly bord)

- **Quaternius** (quaternius.com) — CC0, complete animal packs + soldiers
- **Kenney** (kenney.nl) — CC0, animated characters
- **Sketchfab** — filter op CC0/CC-BY + "low poly", zoek per dier
- Zelf (laten) maken in Blender: exporteer als glTF 2.0 (.glb), Y-up staat goed

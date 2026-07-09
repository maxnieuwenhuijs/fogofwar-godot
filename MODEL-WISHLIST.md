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
- Mesh: **low poly, max 1.000 tris** (besluit juli 2026). De prompts blijven
  wél high-quality/realistisch — de Laag Poly-generator (target 1.000) bakt dat
  detail als texture op de simpele mesh. Het silhouet blijft leidend: de bouw
  (dun/rond/breed) moet het verschil vertellen, niet het micro-detail.

Zolang een model ontbreekt doet het spel dit al met schaal-silhouetten op de
geometrische stukken (`ARCHETYPE_SCALE` in pawn_view.gd): dun/hoog = spd,
laag/rond = hp, breed = atk.

---

## 2. Alle kaartcombinaties → archetype

Formaat **HP / Speed / Aanval**. Archetype = strikt hoogste stat; gelijkspel = `mix`.

### Budget 5 — Muis (6 combinaties)

| Kaart | Archetype | Lees je als |
|---|---|---|
| 3/1/1 | `hp` | dikke muis |
| 1/3/1 | `spd` | dunne schichtige muis |
| 1/1/3 | `atk` | gespierde muis met wapen |
| 2/2/1 | `mix` | standaard |
| 2/1/2 | `mix` | standaard |
| 1/2/2 | `mix` | standaard |

### Budget 7 — Varken, Beer, Wolf, Krokodil (15 combinaties)

| Kaart | Archetype | | Kaart | Archetype | | Kaart | Archetype |
|---|---|---|---|---|---|---|---|
| 5/1/1 | `hp` | | 2/4/1 | `spd` ⛔beer | | 2/2/3 | `atk` |
| 4/2/1 | `hp` | | 2/3/2 | `spd` | | 2/1/4 | `atk` |
| 4/1/2 | `hp` | | 1/5/1 | `spd` ⛔beer | | 1/2/4 | `atk` |
| 3/2/2 | `hp` | | 1/4/2 | `spd` ⛔beer | | 1/1/5 | `atk` |
| 3/3/1 | `mix` | | 3/1/3 | `mix` | | 1/3/3 | `mix` |

⛔beer = kan niet bij de Beer (Speed-cap 3). De Beer heeft dus maar één
`spd`-combinatie (2/3/2) — een snelle beer is zeldzaam; dat mag het model
ook uitstralen (verrassend lichtvoetig).

### Budget 9 — Leeuw (28 combinaties)

| Kaart | Arch. | | Kaart | Arch. | | Kaart | Arch. | | Kaart | Arch. |
|---|---|---|---|---|---|---|---|---|---|---|
| 7/1/1 | `hp` | | 3/5/1 | `spd` | | 3/2/4 | `atk` | | 4/4/1 | `mix` |
| 6/2/1 | `hp` | | 3/4/2 | `spd` | | 3/1/5 | `atk` | | 4/1/4 | `mix` |
| 6/1/2 | `hp` | | 2/6/1 | `spd` | | 2/3/4 | `atk` | | 3/3/3 | `mix` |
| 5/3/1 | `hp` | | 2/5/2 | `spd` | | 2/2/5 | `atk` | | 1/4/4 | `mix` |
| 5/2/2 | `hp` | | 2/4/3 | `spd` | | 2/1/6 | `atk` | | | |
| 5/1/3 | `hp` | | 1/7/1 | `spd` | | 1/3/5 | `atk` | | | |
| 4/3/2 | `hp` | | 1/6/2 | `spd` | | 1/2/6 | `atk` | | | |
| 4/2/3 | `hp` | | 1/5/3 | `spd` | | 1/1/7 | `atk` | | | |

**Telling**: 49 combinaties totaal, maar dankzij de archetype-bucketing zijn er
maar **5 looks per type** nodig. Binnen een archetype verschilt de intensiteit
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
| Muis | muis | dikke bruine rat -- LET OP: comp is 20/0/2 (2 kanonnen, nog geen cavalerie); de rat verschijnt pas als de Muis cavalerie in z'n samenstelling krijgt |
| Varken (ex-Mens) | varken | **everzwijn** met slagtanden |
| Leeuw | **cheetah** (slank, gevlekt, snel) | **leeuw** met volle manen |
| Beer | **wasbeer** (gemaskerd gezicht) | massieve grizzly |
| Wolf (= Wolf+Vos samengevoegd) | **vos** (kleine broer van de wolf) | reusachtige **dire wolf** |
| Krokodil (ex-Vos-slot, erft schutkleur-perk) | **hagedis** met camouflage-schubben | **krokodil** (gepantserd, explosieve uitval = +1 Speed) |

**Prompt-opbouw infanterie**: `Single character, <bouw>
anthropomorphic <dier> <kenmerken>, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey
Napoleonic military uniform and <hoofddeksel>, unarmed with empty hands. Clean neutral studio background, single figure only, no text.`

**Prompt-opbouw big bro**: `Single character, towering <bouw> anthropomorphic
<dier> <kenmerken>, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing
a weathered, strictly dark grey Napoleonic military harness with heavy leather
straps. Clean neutral studio background, single figure only, no text.`
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
aan infanterie). Cavalerie-audio (nu paarden-galop) vervangen we later per
familie (brul/grom/gepiep).

### Muis -- infanterie + dikke rat + licht kanon

| Bestand | Prompt |
|---|---|
| `infantry_base` (klaar) | Single character, average build anthropomorphic mouse with oversized round ears, long twitching whiskers and a pointed snout, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and dark grey shako, unarmed with empty hands. Clean neutral studio background, single figure only, no text. |
| `infantry_spd` | Single character, extremely tall, thin, lanky and long-limbed anthropomorphic mouse with oversized round ears, long twitching whiskers and a pointed snout, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and dark grey shako. Clean neutral studio background, single figure only, no text. |
| `infantry_hp` | Single character, enormously fat, round-bellied, short and squat anthropomorphic mouse with oversized round ears, long twitching whiskers and a pointed snout, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform with a dark steel cuirass and dark grey shako. Clean neutral studio background, single figure only, no text. |
| `infantry_atk` | Single character, gigantic, hulking, broad-shouldered and heavily-muscled anthropomorphic mouse with oversized round ears, long twitching whiskers and a pointed snout, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and dark grey shako, unarmed with empty hands. Clean neutral studio background, single figure only, no text. |
| `infantry_mix` | Single character, average build anthropomorphic mouse with oversized round ears, long twitching whiskers and a pointed snout, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and dark grey shako, unarmed with empty hands. Clean neutral studio background, single figure only, no text. |
| `cavalry_base` | Single character, towering powerful anthropomorphic fat brown rat with a long scaly tail, a blunt whiskered snout and beady eyes, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps. Clean neutral studio background, single figure only, no text. |
| `cavalry_spd` | Single character, towering yet whip-thin, greyhound-lean and long-limbed anthropomorphic fat brown rat with a long scaly tail, a blunt whiskered snout and beady eyes, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps. Clean neutral studio background, single figure only, no text. |
| `cavalry_hp` | Single character, towering, colossally fat, round and squat anthropomorphic fat brown rat with a long scaly tail, a blunt whiskered snout and beady eyes, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps with dark steel armor plates over the harness, low stance. Clean neutral studio background, single figure only, no text. |
| `cavalry_atk` | Single character, towering, monstrously muscular, hulking and battle-scarred anthropomorphic fat brown rat with a long scaly tail, a blunt whiskered snout and beady eyes, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps with bared teeth. Clean neutral studio background, single figure only, no text. |
| `cavalry_mix` | Single character, towering sturdy anthropomorphic fat brown rat with a long scaly tail, a blunt whiskered snout and beady eyes, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps. Clean neutral studio background, single figure only, no text. |

| `artillery_base` | Single prop, small light Napoleonic field cannon on a weathered dark wooden gun carriage with two spoked wheels, with a small anthropomorphic mouse gunner crouched on the gun carriage. Gritty realistic AAA-game concept art, highly detailed. Dark iron barrel. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_spd` | Single prop, very light small Napoleonic horse-artillery cannon with a slender barrel on a weathered dark wooden carriage with large thin spoked wheels, with a small anthropomorphic mouse gunner crouched on the gun carriage. Gritty realistic AAA-game concept art, highly detailed. Dark iron. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_hp` | Single prop, short stubby thick-walled Napoleonic mortar on a heavy low weathered dark wooden block carriage, with a small anthropomorphic mouse gunner crouched on the carriage. Gritty realistic AAA-game concept art, highly detailed. Dark iron. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_atk` | Single prop, long-barreled Napoleonic field gun on a reinforced weathered dark wooden carriage, with a small anthropomorphic mouse gunner crouched on the gun carriage. Gritty realistic AAA-game concept art, highly detailed. Dark iron barrel. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_mix` | Single prop, small Napoleonic field cannon on a weathered dark wooden carriage, with a small anthropomorphic mouse gunner crouched on the gun carriage. Gritty realistic AAA-game concept art, highly detailed. Dark iron. Clean neutral studio background, the cannon and one gunner only, no text. |

### Varken -- varken-infanterie + everzwijn als big bro (ex-Mens)

*Varkens zijn van nature dikkig: elke variant blijft plomp en rond, ook de spd (alleen relatief slanker, nooit spichtig).*

| Bestand | Prompt |
|---|---|
| `infantry_base` | Single character, plump, chubby build anthropomorphic pig with a big flat upturned snout, floppy ears and a curly tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and dark grey bicorne hat, unarmed with empty hands. Clean neutral studio background, single figure only, no text. |
| `infantry_spd` | Single character, lighter and leaner but still plump and round-bellied young anthropomorphic pig with a big flat upturned snout, floppy ears and a curly tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic short military jacket and dark grey bicorne hat. Clean neutral studio background, single figure only, no text. |
| `infantry_hp` | Single character, enormously fat, pot-bellied, short and squat anthropomorphic pig with a big flat upturned snout, floppy ears and a curly tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform with a dark steel cuirass and dark grey bicorne hat. Clean neutral studio background, single figure only, no text. |
| `infantry_atk` | Single character, gigantic, hulking and heavily-muscled but still thick, porky and round-bellied anthropomorphic pig with a big flat upturned snout, floppy ears and a curly tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and dark grey bicorne hat, unarmed with empty hands. Clean neutral studio background, single figure only, no text. |
| `infantry_mix` | Single character, plump, chubby build anthropomorphic pig soldier with a big flat upturned snout, floppy ears and a curly tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and dark grey bicorne hat, unarmed with empty hands. Clean neutral studio background, single figure only, no text. |
| `cavalry_base` | Single character, towering powerful anthropomorphic wild boar with enormous upward-curving tusks, a bristly spined back and a broad snout, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps. Clean neutral studio background, single figure only, no text. |
| `cavalry_spd` | Single character, towering yet whip-thin, greyhound-lean and long-limbed anthropomorphic wild boar with enormous upward-curving tusks, a bristly spined back and a broad snout, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps. Clean neutral studio background, single figure only, no text. |
| `cavalry_hp` | Single character, towering, colossally fat, round and squat anthropomorphic wild boar with enormous upward-curving tusks, a bristly spined back and a broad snout, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps with dark steel armor plates over the harness, low stance. Clean neutral studio background, single figure only, no text. |
| `cavalry_atk` | Single character, towering, monstrously muscular, hulking and battle-scarred anthropomorphic wild boar with enormous upward-curving tusks, a bristly spined back and a broad snout, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps with bared teeth. Clean neutral studio background, single figure only, no text. |
| `cavalry_mix` | Single character, towering sturdy anthropomorphic wild boar with enormous upward-curving tusks, a bristly spined back and a broad snout, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps. Clean neutral studio background, single figure only, no text. |
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
| `infantry_base` | Single character, average build anthropomorphic cheetah with bold black rosette spots and teardrop face stripes, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic officer's uniform with dark grey epaulettes and tall black bearskin cap, unarmed. Clean neutral studio background, single figure only, no text. |
| `infantry_spd` | Single character, extremely tall, thin, lanky and long-limbed anthropomorphic cheetah sprinter with bold black rosette spots and teardrop face stripes, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic short military jacket and tall black bearskin cap. Clean neutral studio background, single figure only, no text. |
| `infantry_hp` | Single character, enormously fat, round, short and squat anthropomorphic cheetah with bold black rosette spots and teardrop face stripes, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic greatcoat with a dark steel cuirass and a tall black bearskin cap. Clean neutral studio background, single figure only, no text. |
| `infantry_atk` | Single character, gigantic, hulking, broad-shouldered and heavily-muscled anthropomorphic cheetah with bold black rosette spots and teardrop face stripes, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and tall black bearskin cap, carrying a heavy sabre. Clean neutral studio background, single figure only, no text. |
| `infantry_mix` | Single character, average build anthropomorphic cheetah guard with bold black rosette spots and teardrop face stripes, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and tall black bearskin cap, unarmed with empty hands. Clean neutral studio background, single figure only, no text. |
| `cavalry_base` | Single character, towering powerful anthropomorphic male lion with an enormous thick flowing mane, a broad muzzle and a tufted tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps. Clean neutral studio background, single figure only, no text. |
| `cavalry_spd` | Single character, towering yet whip-thin, greyhound-lean and long-limbed anthropomorphic male lion with an enormous thick flowing mane, a broad muzzle and a tufted tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps. Clean neutral studio background, single figure only, no text. |
| `cavalry_hp` | Single character, towering, colossally fat, round and squat anthropomorphic male lion with an enormous thick flowing mane, a broad muzzle and a tufted tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps with dark steel armor plates over the harness, low stance. Clean neutral studio background, single figure only, no text. |
| `cavalry_atk` | Single character, towering, monstrously muscular, hulking and battle-scarred anthropomorphic male lion with an enormous thick flowing mane, a broad muzzle and a tufted tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps with bared teeth. Clean neutral studio background, single figure only, no text. |
| `cavalry_mix` | Single character, towering sturdy anthropomorphic male lion with an enormous thick flowing mane, a broad muzzle and a tufted tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps. Clean neutral studio background, single figure only, no text. |
| `artillery_base` | Single prop, long-barreled Napoleonic siege cannon on an ornate weathered dark wooden gun carriage with pewter detailing, with a small anthropomorphic cheetah gunner crouched on the gun carriage. Gritty realistic AAA-game concept art, highly detailed. Dark iron. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_spd` | Single prop, light long slender Napoleonic culverin cannon on a weathered dark wooden carriage with large thin wheels and pewter detailing, with a small anthropomorphic cheetah gunner crouched on the gun carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_hp` | Single prop, massive short thick Napoleonic bombard on a heavy low weathered wooden carriage with pewter detailing, with a small anthropomorphic cheetah gunner crouched on the carriage. Gritty realistic AAA-game concept art, highly detailed. Dark bronze. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_atk` | Single prop, extra long-barreled heavy Napoleonic siege cannon on a wide reinforced weathered dark wooden carriage with pewter detailing, with a small anthropomorphic cheetah gunner crouched on the gun carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_mix` | Single prop, ornate Napoleonic field cannon on a weathered dark wooden carriage with pewter detailing, with a small anthropomorphic cheetah gunner crouched on the gun carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |

### Beer -- wasbeer-infanterie + grizzly als big bro

| Bestand | Prompt |
|---|---|
| `infantry_base` | Single character, average build anthropomorphic raccoon with a bold black bandit-mask face, huge round ears and a thick black-ringed tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic greatcoat and dark grey round Russian ushanka-style fur hat with ear flaps, unarmed. Clean neutral studio background, single figure only, no text. |
| `infantry_spd` | Single character, extremely tall, thin, lanky and long-limbed anthropomorphic raccoon with a bold black bandit-mask face, huge round ears and a thick black-ringed tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic short military jacket and dark grey round Russian ushanka-style fur hat with ear flaps. Clean neutral studio background, single figure only, no text. |
| `infantry_hp` | Single character, enormously fat, round-bellied, short and squat anthropomorphic raccoon with a bold black bandit-mask face, huge round ears and a thick black-ringed tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic greatcoat with a heavy dark iron breastplate and round Russian ushanka-style fur hat with ear flaps. Clean neutral studio background, single figure only, no text. |
| `infantry_atk` | Single character, gigantic, hulking, broad-shouldered and heavily-muscled anthropomorphic raccoon with a bold black bandit-mask face, huge round ears and a thick black-ringed tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and dark grey round Russian ushanka-style fur hat with ear flaps, carrying a large battle axe. Clean neutral studio background, single figure only, no text. |
| `infantry_mix` | Single character, average build anthropomorphic raccoon soldier with a bold black bandit-mask face, huge round ears and a thick black-ringed tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic greatcoat and round Russian ushanka-style fur hat with ear flaps, unarmed with empty hands. Clean neutral studio background, single figure only, no text. |
| `cavalry_base` | Single character, towering powerful anthropomorphic grizzly bear with a massive shoulder hump, huge claws and a broad fanged muzzle, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps. Clean neutral studio background, single figure only, no text. |
| `cavalry_spd` | Single character, towering yet whip-thin, greyhound-lean and long-limbed anthropomorphic grizzly bear with a massive shoulder hump, huge claws and a broad fanged muzzle, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps. Clean neutral studio background, single figure only, no text. |
| `cavalry_hp` | Single character, towering, colossally fat, round and squat anthropomorphic grizzly bear with a massive shoulder hump, huge claws and a broad fanged muzzle, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps with dark steel armor plates over the harness, low stance. Clean neutral studio background, single figure only, no text. |
| `cavalry_atk` | Single character, towering, monstrously muscular, hulking and battle-scarred anthropomorphic grizzly bear with a massive shoulder hump, huge claws and a broad fanged muzzle, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps with bared teeth. Clean neutral studio background, single figure only, no text. |
| `cavalry_mix` | Single character, towering sturdy anthropomorphic grizzly bear with a massive shoulder hump, huge claws and a broad fanged muzzle, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps. Clean neutral studio background, single figure only, no text. |
| `artillery_base` | Single prop, short thick Napoleonic fortress mortar on a weathered dark wooden block carriage, with a small anthropomorphic raccoon gunner crouched on the carriage. Gritty realistic AAA-game concept art, highly detailed. Dark iron. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_spd` | Single prop, light Napoleonic cannon mounted on a weathered wooden sled carriage, with a small anthropomorphic raccoon gunner crouched on the carriage. Gritty realistic AAA-game concept art, highly detailed. Dark iron. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_hp` | Single prop, heavy Napoleonic siege mortar on a massive low weathered wooden carriage, with a small anthropomorphic raccoon gunner crouched on the carriage. Gritty realistic AAA-game concept art, highly detailed. Dark iron. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_atk` | Single prop, wide-mouthed double Napoleonic mortar on a reinforced weathered dark wooden carriage, with a small anthropomorphic raccoon gunner crouched on the carriage. Gritty realistic AAA-game concept art, highly detailed. Dark iron. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_mix` | Single prop, Napoleonic winter field cannon on a weathered dark wooden carriage, with a small anthropomorphic raccoon gunner crouched on the gun carriage. Gritty realistic AAA-game concept art, highly detailed. Dark iron. Clean neutral studio background, the cannon and one gunner only, no text. |

### Wolf -- vos-infanterie + dire wolf als big bro (Wolf+Vos samengevoegd)

| Bestand | Prompt |
|---|---|
| `infantry_base` | Single character, average build anthropomorphic fox with huge pointed ears, a sharp narrow snout and a big bushy tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic tattered military uniform and dark grey forage cap, unarmed. Clean neutral studio background, single figure only, no text. |
| `infantry_spd` | Single character, extremely tall, thin, lanky and long-limbed gaunt anthropomorphic fox with huge pointed ears, a sharp narrow snout and a big bushy tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic tattered short military jacket and forage cap. Clean neutral studio background, single figure only, no text. |
| `infantry_hp` | Single character, enormously fat, thick-furred, short and squat anthropomorphic fox with huge pointed ears, a sharp narrow snout and a big bushy tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic tattered greatcoat with a scavenged dark steel breastplate and dark grey forage cap. Clean neutral studio background, single figure only, no text. |
| `infantry_atk` | Single character, gigantic, hulking, broad-shouldered and heavily-muscled anthropomorphic fox with huge pointed ears, a big bushy tail and bared teeth, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic tattered military uniform and dark grey forage cap, carrying a heavy cleaver. Clean neutral studio background, single figure only, no text. |
| `infantry_mix` | Single character, average build anthropomorphic fox soldier with huge pointed ears, a sharp narrow snout and a big bushy tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic tattered military uniform and forage cap, unarmed with empty hands. Clean neutral studio background, single figure only, no text. |
| `cavalry_base` | Single character, towering powerful anthropomorphic giant dire wolf with a shaggy mane, huge fangs and pointed ears, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps. Clean neutral studio background, single figure only, no text. |
| `cavalry_spd` | Single character, towering yet whip-thin, greyhound-lean and long-limbed anthropomorphic giant dire wolf with a shaggy mane, huge fangs and pointed ears, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps. Clean neutral studio background, single figure only, no text. |
| `cavalry_hp` | Single character, towering, colossally fat, round and squat anthropomorphic giant dire wolf with a shaggy mane, huge fangs and pointed ears, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps with dark steel armor plates over the harness, low stance. Clean neutral studio background, single figure only, no text. |
| `cavalry_atk` | Single character, towering, monstrously muscular, hulking and battle-scarred anthropomorphic giant dire wolf with a shaggy mane, huge fangs and pointed ears, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps with bared teeth. Clean neutral studio background, single figure only, no text. |
| `cavalry_mix` | Single character, towering sturdy anthropomorphic giant dire wolf with a shaggy mane, huge fangs and pointed ears, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps. Clean neutral studio background, single figure only, no text. |
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
| `infantry_base` | Single character, average build anthropomorphic lizard with camouflage-pattern scales, big lidded eyes and a long tapering tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and a dark grey tricorne musketeer hat under a loose dark grey hooded cloak, unarmed. Clean neutral studio background, single figure only, no text. |
| `infantry_spd` | Single character, extremely tall, thin, lanky and long-limbed anthropomorphic gecko-like lizard with camouflage-pattern scales, big lidded eyes and a long tapering tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic short military jacket and dark grey tricorne musketeer hat. Clean neutral studio background, single figure only, no text. |
| `infantry_hp` | Single character, enormously fat, round, short and squat anthropomorphic lizard with thick armored scutes and camouflage-pattern scales, big lidded eyes and a long tapering tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic greatcoat with a dark steel cuirass and a dark grey tricorne musketeer hat. Clean neutral studio background, single figure only, no text. |
| `infantry_atk` | Single character, gigantic, hulking, broad-shouldered and heavily-muscled anthropomorphic lizard with camouflage-pattern scales, big lidded eyes and a long tapering tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and a dark grey tricorne musketeer hat under a half-open dark grey hooded cloak revealing two daggers. Clean neutral studio background, single figure only, no text. |
| `infantry_mix` | Single character, average build anthropomorphic lizard soldier with camouflage-pattern scales, big lidded eyes and a long tapering tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and dark grey tricorne musketeer hat, unarmed with empty hands. Clean neutral studio background, single figure only, no text. |
| `cavalry_base` | Single character, towering powerful anthropomorphic crocodile with a long toothy snout, armored scutes and a massive tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps low stance. Clean neutral studio background, single figure only, no text. |
| `cavalry_spd` | Single character, towering yet whip-thin, greyhound-lean and long-limbed anthropomorphic crocodile with a long toothy snout, armored scutes and a massive tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps low stance. Clean neutral studio background, single figure only, no text. |
| `cavalry_hp` | Single character, towering, colossally fat, round and squat anthropomorphic crocodile with a long toothy snout, thick armored scutes and a massive tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps with dark steel armor plates over the harness, very low stance. Clean neutral studio background, single figure only, no text. |
| `cavalry_atk` | Single character, towering, monstrously muscular, hulking and battle-scarred anthropomorphic crocodile with a long toothy snout, armored scutes and a massive tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps with open jaws showing teeth. Clean neutral studio background, single figure only, no text. |
| `cavalry_mix` | Single character, towering sturdy anthropomorphic crocodile with a long toothy snout, armored scutes and a massive tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps low stance. Clean neutral studio background, single figure only, no text. |
| `artillery_base` | Single prop, Napoleonic field cannon covered in dark grey camouflage netting with only the barrel protruding, on a weathered dark wooden carriage, with a small anthropomorphic lizard gunner crouched on the gun carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_spd` | Single prop, light Napoleonic cannon half covered by a dark grey tarp on a weathered dark wooden carriage with thin wheels, with a small anthropomorphic lizard gunner crouched on the carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_hp` | Single prop, Napoleonic cannon draped in heavy dark grey camouflage netting and burlap, on a low weathered dark wooden carriage, with a small anthropomorphic lizard gunner crouched on the carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_atk` | Single prop, long-barreled Napoleonic cannon with dark grey camouflage netting pulled aside, on a weathered dark wooden carriage, with a small anthropomorphic lizard gunner crouched on the gun carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_mix` | Single prop, Napoleonic field cannon with a folded dark grey tarp on the weathered dark wooden carriage, with a small anthropomorphic lizard gunner crouched on the carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |

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

**Fallback-keten**: `<type>_<archetype>.glb` → `<type>_base.glb` → geometrisch
stuk met archetype-silhouet. Alles werkt dus ook met maar één model per type.
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

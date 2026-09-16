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

## 3-team. Teamstijl: rood is verweerd, blauw is gepoetst

**Besluit Max, 7 september.** Het model is voor beide teams DEZELFDE mesh; het
verschil zit in de teamjas (`<model>_red.png` / `_blue.png`, en sinds vandaag
ook `<wapen>_red.png` / `_blue.png`). Die twee jassen vertellen twee
verschillende legers:

| | Rood | Blauw |
|---|---|---|
| **Toon** | afgedankte veteranen: oorlog overleefd, jaren geleden aan de kant gezet | paradeleger, net uit het depot |
| **Stof** | versleten tot boerenkleding: echte gaten bij ellebogen, knieen en zoom, grove lappen erop genaaid, draadstof grijsbruin van de jaren | strak, diep van kleur, smetteloos |
| **Banden** | GEEN wit kruis: alleen een versleten taillegordel. Wit was pijpaarde-onderhoud, en dat doet niemand meer voor deze eenheid | smetteloos wit kruis over de borst, strak |
| **Knopen** | een enkele scheve rij op de borst: er missen er, vervangen door houten pinnen of been, de rest dof aangeslagen messing | vergulde knopen en epauletten, gepoetst |
| **Metaal** | dof, aangeslagen, roestputjes | spiegelend zilver EN goud, gepoetst |
| **Schoeisel** | gebarsten, met lappen omwikkeld | glanzend, geolied |
| **Hout** (wapen) | bleek en versleten | donker gebeitst en gelakt |

Dat is meer dan kleur: het is een verhaal dat je in een oogopslag leest. En het
werkt beter dan rood-tegen-blauw verf, want de modellen dragen al donkergrijze
uniformen -- twee tinten grijs uit elkaar houden lukt niet, versleten tegen
glimmend wel.

**Retexture-toevoeging voor het LIJF:**

| Team | Toevoeging aan de prompt |
|---|---|
| rood | `discarded veterans whose uniform has decayed into peasant clothing: no white crossbelts, just a worn waist belt and a single uneven row of buttons down the front with several missing, cloth worn through into ragged holes at elbows, knees and hem, crude mismatched patches, threadbare grey-brown fabric, rust-pitted metal, cracked shoes bound with rag` |
| blauw | `immaculate parade condition: crisp deep-toned cloth, mirror-polished silver and gleaming gold braid, gilded buttons and epaulettes, spotless white leather, everything buffed and shining` |

**Template:** `Retexture this character, keep the existing UV layout and geometry
unchanged. <team-toevoeging>. Gritty realistic AAA-game concept art, highly
detailed, no text.`

**De volledige teksten staan in `model-tracker.html`**, en daar worden ze PER
MODEL gebouwd: klap een model open en je krijgt de model-prompt, de rood- en
blauw-variant daarvan, de wapen-prompt en de rood- en blauw-retexture van dat
wapen. Deze paragraaf beschrijft de regel, de tracker draagt de tekst; verander
je iets, doe het in `const TEAM` en werk deze tabel bij.

Let op wat de tracker voor BLAUW extra doet: hij haalt "weathered" en "battered"
uit de model-prompt weg. Die woorden staan er standaard in en versterken de rode
veldstaat, maar bij blauw zou er "wearing a weathered, immaculate uniform" staan
-- dan kiest de generator er zelf een.

**Waarom rood geen wit kruis draagt.** Die banden waren wit door *pipeclay*,
witte pijpaarde die je er voor elke inspectie op smeerde: het was onderhoud, geen
materiaal. Een eenheid die aan de kant is geschoven stopt daarmee. Andere legers
uit die tijd deden het sowieso anders -- Pruisen, Russen en de Britse rifles
droegen zwart leer, Oostenrijk ongeverfd buffleer, lichte infanterie vaak maar
een schouderband of alleen een gordel. Wij nemen het armoedigste: het kruis
verdwijnt en er blijft een gordel over, met de knopenrij op de borst als enige
rest die nog verraadt dat dit ooit een uniform was.

Zelfde regel geldt voor de wapens, zie 3c. En dezelfde waarschuwing als daar:
laat de materiaal-zin uit de oorspronkelijke model-prompt WEG, anders vraag je
twee dingen tegelijk.

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
een factie uit elkaar; op 16 augustus verder aangezet omdat de generator
zachtere bouw-woorden afvlakt tot hetzelfde lijf): spd = `whip-thin,
narrow-shouldered, greyhound-lean, long-limbed` | hp = `colossally fat, round
and squat, nearly as wide as he is tall` | atk = `monstrously muscular,
hulking, battle-scarred, top-heavy with colossal arms and shoulders` | base =
`powerful, broad and upright` | mix = `stocky and barrel-chested`.

**Uitrusting per archetype (16 augustus, verzoek Max).** Bouw-woorden alleen
bleken uit de generator te veel op elkaar te lijken; daarom draagt elk
archetype nu precies EEN eigen uitrustingsstuk, altijd op zijn EIGEN plek op
het lijf, zodat het silhouet al op 2 cm schermhoogte verschilt. Hetzelfde
stuk in alle zes de facties (een keer leren = overal herkennen); alles
donker leer/staal (teamkleur komt uit de textures, dus nooit kleur als
onderscheid) en stijf aan romp of kop bevestigd -- geen wapperende capes of
losse voorwerpen, die overleven de Mixamo-auto-rig niet:

| Archetype | Plek op het lijf | Stuk |
|---|---|---|
| base | borst | twee gekruiste bandeliers met grove patronen (X-silhouet) |
| spd | kop | een enkele zeer hoge gebogen verenpluim boven op de factie-hoed |
| hp | romp | volledig zwaar borstkuras + massieve ronde schouderplaten op beide schouders (plus de lage stand) |
| atk | schouder/armen | een enkel oversized gepunt ijzeren schouderstuk + zware benagelde handschoenen (plus de ontblote tanden) |
| mix | borst (diagonaal) | dikke opgerolde deken dwars van schouder naar heup (16 augustus: was eerst een rugzak, maar die zie je van voren niet -- de dekenrol leest van alle kanten en is dik waar base's bandeliers dun en gekruist zijn) |

**Factie-herkenning cavalerie (16 augustus, correctie Max: "gaat om cavalerie
specifiek"; TERUGGEDRAAID 16 september).** Zes towering beesten in hetzelfde
donkere harnas lazen op bordafstand als een leger; het dier alleen bleek niet
genoeg. Van 16 augustus tot 16 september droeg elke big bro daarom in de
prompt de factie-hoed uit de infanterie-regel in een gehavende (`battered`)
versie. Max, 16 september: "alle cav prompts hebben nog hoedjes op die ze
allemaal niet echt hebben, fix de prompts" -- de cavalerie is BLOOTSHOOFDS,
in alle facties; de hoed is er uit alle dertig cavalerie-prompts gehaald
(tracker en deze lijst) en de tracker zet voor een cavalerie-model dat er
nog niet ligt geen hoed in de team-prompt. De spd-pluim staat sindsdien op
de schouder van het harnas. Factie-herkenning van de cavalerie komt van het
dier en de teamjas.

**Artillerie per archetype (16 augustus, verzoek Max).** Zelfde principe als
de cavalerie, met de harde regel dat het bemanningsdier OP het kanon staat
of het DUWT -- het kanon rolt over het bord, dus een dier ernaast zou
achterblijven of clippen, en alles extra's zit aan het kanon VASTGESJORD.
Drie lagen per archetype: het kanon-type (stond er al), de houding van het
dier, en wat er opgesjord zit:

| Archetype | Kanon | Dier | Opgesjord |
|---|---|---|---|
| base | standaard veldkanon | staat rechtop op de affuit, hand op de loop | nette touwrol op de staart |
| spd | licht rijdend kanon, slanke loop, grote dunne wielen | duwt achteraan, voorovergeleund midden in de pas | niets (licht = snel) |
| hp | korte dikke mortier op laag blok | zit zwaar boven op de dikke loop | zandzakken op de affuit |
| atk | lange zware loop | staat over de loop gebogen, beide handen erom | geschroeide vuurmond + rek kanonskogels |
| mix | standaard veldkanon | zit op een vastgesjord kruitvat | kruitvat met touwrol |

**Hoofddeksel per factie** (uniek, zodat je de factie ook aan de hoed herkent; binnen een factie hetzelfde type, hooguit licht verweerd verschil): Muis = `shako` (hoge cilinderpet) · Varken = `bicorne` (tweepuntige steek) · Leeuw = `tall black bearskin cap` (hoge berenmuts) · Beer = `round Russian ushanka fur hat` (ronde Russische bontmuts met oorflappen) · Wolf = `forage cap` (zachte veldpet) · Krokodil = `tricorne` (driepuntige musketiershoed). **Alleen de infanterie** (16 september, Max: de cavalerie heeft geen hoed; van 16 augustus tot 16 september stond hij ook in de cavalerie-prompts als `battered`).

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
| `cavalry_base` | Single character, towering powerful, broad and upright anthropomorphic fat brown rat with a long scaly tail, a blunt whiskered snout and beady eyes, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps and two crossed heavy dark leather bandoliers with oversized metal cartridges forming a bold X across the chest, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_spd` | Single character, towering yet whip-thin, narrow-shouldered, greyhound-lean and long-limbed anthropomorphic fat brown rat with a long scaly tail, a blunt whiskered snout and beady eyes, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps and a single very tall curved dark feather plume fixed upright to the shoulder of the harness, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_hp` | Single character, towering, colossally fat, round and squat, nearly as wide as he is tall, anthropomorphic fat brown rat with a long scaly tail, a blunt whiskered snout and beady eyes, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps and a full heavy dark steel cuirass with massive rounded dark steel pauldrons on both shoulders, low stance, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_atk` | Single character, towering, monstrously muscular, hulking and battle-scarred, top-heavy with colossal arms and shoulders, anthropomorphic fat brown rat with a long scaly tail, a blunt whiskered snout and beady eyes, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps and a single oversized spiked dark iron pauldron on one shoulder, heavy studded dark iron gauntlets and bared teeth, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_mix` | Single character, towering, stocky and barrel-chested anthropomorphic fat brown rat with a long scaly tail, a blunt whiskered snout and beady eyes, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps and a thick dark rolled blanket worn diagonally across the chest from shoulder to hip, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |

| `artillery_base` | Single prop, small light Napoleonic field cannon on a weathered dark wooden gun carriage with two spoked wheels, with a small anthropomorphic mouse gunner standing upright on the gun carriage with one hand resting on the barrel, and a neatly coiled dark rope lashed to the carriage trail. Gritty realistic AAA-game concept art, highly detailed. Dark iron barrel. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_spd` | Single prop, very light small Napoleonic horse-artillery cannon with a slender barrel on a weathered dark wooden carriage with large thin spoked wheels, with a small anthropomorphic mouse gunner pushing hard against the back of the gun carriage, leaning forward mid-stride with both hands on it. Gritty realistic AAA-game concept art, highly detailed. Dark iron. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_hp` | Single prop, short stubby thick-walled Napoleonic mortar on a heavy low weathered dark wooden block carriage, with a small anthropomorphic mouse gunner sitting heavily on top of the thick barrel, and stacked dark sandbags lashed onto the carriage. Gritty realistic AAA-game concept art, highly detailed. Dark iron. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_atk` | Single prop, long-barreled Napoleonic field gun on a reinforced weathered dark wooden carriage, with a small anthropomorphic mouse gunner standing on the gun carriage leaning aggressively over the barrel with both hands gripping it, the muzzle blackened with scorch marks and a rack of cannonballs lashed to the carriage. Gritty realistic AAA-game concept art, highly detailed. Dark iron barrel. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_mix` | Single prop, small Napoleonic field cannon on a weathered dark wooden carriage, with a small anthropomorphic mouse gunner perched on a dark powder barrel lashed to the gun carriage, with a coiled rope strapped over it. Gritty realistic AAA-game concept art, highly detailed. Dark iron. Clean neutral studio background, the cannon and one gunner only, no text. |

### Varken -- varken-infanterie + everzwijn als big bro (ex-Mens)

*Varkens zijn van nature dikkig: elke variant blijft plomp en rond, ook de spd (alleen relatief slanker, nooit spichtig).*

| Bestand | Prompt |
|---|---|
| `infantry_base` | Single character, plump, chubby build anthropomorphic pig with a big flat upturned snout, floppy ears and a curly tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and dark grey bicorne hat, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_spd` | Single character, lighter and leaner but still plump and round-bellied young anthropomorphic pig with a big flat upturned snout, floppy ears and a curly tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic short military jacket and dark grey bicorne hat, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_hp` | Single character, enormously fat, pot-bellied, short and squat anthropomorphic pig with a big flat upturned snout, floppy ears and a curly tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform with a dark steel cuirass and dark grey bicorne hat, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_atk` | Single character, gigantic, hulking and heavily-muscled but still thick, porky and round-bellied anthropomorphic pig with a big flat upturned snout, floppy ears and a curly tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and dark grey bicorne hat, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_mix` | Single character, plump, chubby build anthropomorphic pig soldier with a big flat upturned snout, floppy ears and a curly tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and dark grey bicorne hat, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_base` | Single character, towering powerful, broad and upright anthropomorphic wild boar with enormous upward-curving tusks, a bristly spined back and a broad snout, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps and two crossed heavy dark leather bandoliers with oversized metal cartridges forming a bold X across the chest, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_spd` | Single character, towering yet whip-thin, narrow-shouldered, greyhound-lean and long-limbed anthropomorphic wild boar with enormous upward-curving tusks, a bristly spined back and a broad snout, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps and a single very tall curved dark feather plume fixed upright to the shoulder of the harness, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_hp` | Single character, towering, colossally fat, round and squat, nearly as wide as he is tall, anthropomorphic wild boar with enormous upward-curving tusks, a bristly spined back and a broad snout, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps and a full heavy dark steel cuirass with massive rounded dark steel pauldrons on both shoulders, low stance, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_atk` | Single character, towering, monstrously muscular, hulking and battle-scarred, top-heavy with colossal arms and shoulders, anthropomorphic wild boar with enormous upward-curving tusks, a bristly spined back and a broad snout, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps and a single oversized spiked dark iron pauldron on one shoulder, heavy studded dark iron gauntlets and bared teeth, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_mix` | Single character, towering, stocky and barrel-chested anthropomorphic wild boar with enormous upward-curving tusks, a bristly spined back and a broad snout, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps and a thick dark rolled blanket worn diagonally across the chest from shoulder to hip, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| Bestand | Prompt |
|---|---|
| `artillery_base` | Single prop, Napoleonic field cannon on a weathered dark wooden gun carriage with two spoked wheels, with a small anthropomorphic pig gunner standing upright on the gun carriage with one hand resting on the barrel, and a neatly coiled dark rope lashed to the carriage trail. Gritty realistic AAA-game concept art, highly detailed. Dark iron barrel. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_spd` | Single prop, light Napoleonic horse-artillery cannon with a slender barrel on a weathered dark wooden carriage with large thin spoked wheels, with a small anthropomorphic pig gunner pushing hard against the back of the gun carriage, leaning forward mid-stride with both hands on it. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_hp` | Single prop, short thick Napoleonic fortress mortar on a heavy low weathered wooden block carriage, with a small anthropomorphic pig gunner sitting heavily on top of the thick barrel, and stacked dark sandbags lashed onto the carriage. Gritty realistic AAA-game concept art, highly detailed. Dark iron. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_atk` | Single prop, long-barreled heavy Napoleonic siege cannon on a reinforced weathered dark wooden carriage, with a small anthropomorphic pig gunner standing on the gun carriage leaning aggressively over the barrel with both hands gripping it, the muzzle blackened with scorch marks and a rack of cannonballs lashed to the carriage. Gritty realistic AAA-game concept art, highly detailed. Dark iron barrel. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_mix` | Single prop, Napoleonic field cannon on a weathered dark wooden carriage, with a small anthropomorphic pig gunner perched on a dark powder barrel lashed to the gun carriage, with a coiled rope strapped over it. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |

### Leeuw -- cheetah-infanterie + leeuw als big bro

| Bestand | Prompt |
|---|---|
| `infantry_base` | Single character, average build anthropomorphic cheetah with bold black rosette spots and teardrop face stripes, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic officer's uniform with dark grey epaulettes and tall black bearskin cap, short trousers ending above the knee, completely barefoot: absolutely no boots, no shoes, no socks and no leg wraps, the bare furry lower legs and large bare clawed paws fully exposed and clearly visible, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_spd` | Single character, extremely tall, thin, lanky and long-limbed anthropomorphic cheetah sprinter with bold black rosette spots and teardrop face stripes, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic short military jacket and tall black bearskin cap, short trousers ending above the knee, completely barefoot: absolutely no boots, no shoes, no socks and no leg wraps, the bare furry lower legs and large bare clawed paws fully exposed and clearly visible, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_hp` | Single character, enormously fat, round, short and squat anthropomorphic cheetah with bold black rosette spots and teardrop face stripes, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic greatcoat with a dark steel cuirass and a tall black bearskin cap, short trousers ending above the knee, completely barefoot: absolutely no boots, no shoes, no socks and no leg wraps, the bare furry lower legs and large bare clawed paws fully exposed and clearly visible, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_atk` | Single character, gigantic, hulking, broad-shouldered and heavily-muscled anthropomorphic cheetah with bold black rosette spots and teardrop face stripes, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and tall black bearskin cap, short trousers ending above the knee, completely barefoot: absolutely no boots, no shoes, no socks and no leg wraps, the bare furry lower legs and large bare clawed paws fully exposed and clearly visible, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_mix` | Single character, average build anthropomorphic cheetah guard with bold black rosette spots and teardrop face stripes, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and tall black bearskin cap, short trousers ending above the knee, completely barefoot: absolutely no boots, no shoes, no socks and no leg wraps, the bare furry lower legs and large bare clawed paws fully exposed and clearly visible, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_base` | Single character, towering powerful, broad and upright anthropomorphic male lion with an enormous thick flowing mane, a broad muzzle and a tufted tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps and two crossed heavy dark leather bandoliers with oversized metal cartridges forming a bold X across the chest and short trousers ending above the knee, completely barefoot: absolutely no boots, no shoes, no socks and no leg wraps, the bare furry lower legs and large bare clawed paws fully exposed and clearly visible, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_spd` | Single character, towering yet whip-thin, narrow-shouldered, greyhound-lean and long-limbed anthropomorphic male lion with an enormous thick flowing mane, a broad muzzle and a tufted tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps and a single very tall curved dark feather plume and short trousers ending above the knee fixed upright to the shoulder of the harness, completely barefoot: absolutely no boots, no shoes, no socks and no leg wraps, the bare furry lower legs and large bare clawed paws fully exposed and clearly visible, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_hp` | Single character, towering, colossally fat, round and squat, nearly as wide as he is tall, anthropomorphic male lion with an enormous thick flowing mane, a broad muzzle and a tufted tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps and a full heavy dark steel cuirass with massive rounded dark steel pauldrons on both shoulders and short trousers ending above the knee, completely barefoot: absolutely no boots, no shoes, no socks and no leg wraps, the bare furry lower legs and large bare clawed paws fully exposed and clearly visible, low stance, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_atk` | Single character, towering, monstrously muscular, hulking and battle-scarred, top-heavy with colossal arms and shoulders, anthropomorphic male lion with an enormous thick flowing mane, a broad muzzle and a tufted tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps and a single oversized spiked dark iron pauldron on one shoulder, heavy studded dark iron gauntlets and bared teeth and short trousers ending above the knee, completely barefoot: absolutely no boots, no shoes, no socks and no leg wraps, the bare furry lower legs and large bare clawed paws fully exposed and clearly visible, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_mix` | Single character, towering, stocky and barrel-chested anthropomorphic male lion with an enormous thick flowing mane, a broad muzzle and a tufted tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps and a thick dark rolled blanket worn diagonally across the chest from shoulder to hip and short trousers ending above the knee, completely barefoot: absolutely no boots, no shoes, no socks and no leg wraps, the bare furry lower legs and large bare clawed paws fully exposed and clearly visible, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `artillery_base` | Single prop, long-barreled Napoleonic siege cannon on an ornate weathered dark wooden gun carriage with pewter detailing, with a small anthropomorphic cheetah gunner standing upright on the gun carriage with one hand resting on the barrel, and a neatly coiled dark rope lashed to the carriage trail. Gritty realistic AAA-game concept art, highly detailed. Dark iron. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_spd` | Single prop, light long slender Napoleonic culverin cannon on a weathered dark wooden carriage with large thin wheels and pewter detailing, with a small anthropomorphic cheetah gunner pushing hard against the back of the gun carriage, leaning forward mid-stride with both hands on it. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_hp` | Single prop, massive short thick Napoleonic bombard on a heavy low weathered wooden carriage with pewter detailing, with a small anthropomorphic cheetah gunner sitting heavily on top of the thick barrel, and stacked dark sandbags lashed onto the carriage. Gritty realistic AAA-game concept art, highly detailed. Dark bronze. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_atk` | Single prop, extra long-barreled heavy Napoleonic siege cannon on a wide reinforced weathered dark wooden carriage with pewter detailing, with a small anthropomorphic cheetah gunner standing on the gun carriage leaning aggressively over the barrel with both hands gripping it, the muzzle blackened with scorch marks and a rack of cannonballs lashed to the carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_mix` | Single prop, ornate Napoleonic field cannon on a weathered dark wooden carriage with pewter detailing, with a small anthropomorphic cheetah gunner perched on a dark powder barrel lashed to the gun carriage, with a coiled rope strapped over it. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |

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
| `cavalry_base` | Single character, towering powerful, broad and upright anthropomorphic grizzly bear with a massive shoulder hump, huge claws and a broad fanged muzzle, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps and two crossed heavy dark leather bandoliers with oversized metal cartridges forming a bold X across the chest, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_spd` | Single character, towering yet whip-thin, narrow-shouldered, greyhound-lean and long-limbed anthropomorphic grizzly bear with a massive shoulder hump, huge claws and a broad fanged muzzle, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps and a single very tall curved dark feather plume fixed upright to the shoulder of the harness, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_hp` | Single character, towering, colossally fat, round and squat, nearly as wide as he is tall, anthropomorphic grizzly bear with a massive shoulder hump, huge claws and a broad fanged muzzle, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps and a full heavy dark steel cuirass with massive rounded dark steel pauldrons on both shoulders, low stance, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_atk` | Single character, towering, monstrously muscular, hulking and battle-scarred, top-heavy with colossal arms and shoulders, anthropomorphic grizzly bear with a massive shoulder hump, huge claws and a broad fanged muzzle, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps and a single oversized spiked dark iron pauldron on one shoulder, heavy studded dark iron gauntlets and bared teeth, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_mix` | Single character, towering, stocky and barrel-chested anthropomorphic grizzly bear with a massive shoulder hump, huge claws and a broad fanged muzzle, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps and a thick dark rolled blanket worn diagonally across the chest from shoulder to hip, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `artillery_base` | Single prop, short thick Napoleonic fortress mortar on a weathered dark wooden block carriage, with a small anthropomorphic raccoon gunner standing upright on the gun carriage with one hand resting on the barrel, and a neatly coiled dark rope lashed to the carriage trail. Gritty realistic AAA-game concept art, highly detailed. Dark iron. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_spd` | Single prop, light Napoleonic cannon mounted on a weathered wooden sled carriage, with a small anthropomorphic raccoon gunner pushing hard against the back of the gun carriage, leaning forward mid-stride with both hands on it. Gritty realistic AAA-game concept art, highly detailed. Dark iron. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_hp` | Single prop, heavy Napoleonic siege mortar on a massive low weathered wooden carriage, with a small anthropomorphic raccoon gunner sitting heavily on top of the thick barrel, and stacked dark sandbags lashed onto the carriage. Gritty realistic AAA-game concept art, highly detailed. Dark iron. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_atk` | Single prop, wide-mouthed double Napoleonic mortar on a reinforced weathered dark wooden carriage, with a small anthropomorphic raccoon gunner standing on the gun carriage leaning aggressively over the barrel with both hands gripping it, the muzzle blackened with scorch marks and a rack of cannonballs lashed to the carriage. Gritty realistic AAA-game concept art, highly detailed. Dark iron. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_mix` | Single prop, Napoleonic winter field cannon on a weathered dark wooden carriage, with a small anthropomorphic raccoon gunner perched on a dark powder barrel lashed to the gun carriage, with a coiled rope strapped over it. Gritty realistic AAA-game concept art, highly detailed. Dark iron. Clean neutral studio background, the cannon and one gunner only, no text. |

### Wolf -- vos-infanterie + dire wolf als big bro (Wolf+Vos samengevoegd)

| Bestand | Prompt |
|---|---|
| `infantry_base` | Single character, average build anthropomorphic fox with huge pointed ears, a sharp narrow snout and a big bushy tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic tattered military uniform and dark grey forage cap, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_spd` | Single character, extremely tall, thin, lanky and long-limbed gaunt anthropomorphic fox with huge pointed ears, a sharp narrow snout and a big bushy tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic tattered short military jacket and forage cap, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_hp` | Single character, enormously fat, thick-furred, short and squat anthropomorphic fox with huge pointed ears, a sharp narrow snout and a big bushy tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic tattered greatcoat with a scavenged dark steel breastplate and dark grey forage cap, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_atk` | Single character, gigantic, hulking, broad-shouldered and heavily-muscled anthropomorphic fox with huge pointed ears, a big bushy tail and bared teeth, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic tattered military uniform and dark grey forage cap, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `infantry_mix` | Single character, average build anthropomorphic fox soldier with huge pointed ears, a sharp narrow snout and a big bushy tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic tattered military uniform and forage cap, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_base` | Single character, towering powerful, broad and upright anthropomorphic giant dire wolf with a shaggy mane, huge fangs and pointed ears, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps and two crossed heavy dark leather bandoliers with oversized metal cartridges forming a bold X across the chest, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_spd` | Single character, towering yet whip-thin, narrow-shouldered, greyhound-lean and long-limbed anthropomorphic giant dire wolf with a shaggy mane, huge fangs and pointed ears, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps and a single very tall curved dark feather plume fixed upright to the shoulder of the harness, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_hp` | Single character, towering, colossally fat, round and squat, nearly as wide as he is tall, anthropomorphic giant dire wolf with a shaggy mane, huge fangs and pointed ears, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps and a full heavy dark steel cuirass with massive rounded dark steel pauldrons on both shoulders, low stance, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_atk` | Single character, towering, monstrously muscular, hulking and battle-scarred, top-heavy with colossal arms and shoulders, anthropomorphic giant dire wolf with a shaggy mane, huge fangs and pointed ears, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps and a single oversized spiked dark iron pauldron on one shoulder, heavy studded dark iron gauntlets and bared teeth, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_mix` | Single character, towering, stocky and barrel-chested anthropomorphic giant dire wolf with a shaggy mane, huge fangs and pointed ears, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps and a thick dark rolled blanket worn diagonally across the chest from shoulder to hip, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `artillery_base` | Single prop, scavenged Napoleonic field cannon with ropes and burlap sacks tied around it, on a weathered dark wooden carriage, with a small anthropomorphic fox gunner standing upright on the gun carriage with one hand resting on the barrel, and a neatly coiled dark rope lashed to the carriage trail. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_spd` | Single prop, light Napoleonic mountain cannon on a small weathered dark wooden carriage, with a small anthropomorphic fox gunner pushing hard against the back of the gun carriage, leaning forward mid-stride with both hands on it. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_hp` | Single prop, heavy scavenged Napoleonic cannon reinforced with scrap-iron plating bolted to the barrel, on a weathered dark wooden carriage, with a small anthropomorphic fox gunner sitting heavily on top of the thick barrel, and stacked dark sandbags lashed onto the carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_atk` | Single prop, heavy scavenged Napoleonic cannon with extra powder kegs strapped to the weathered dark wooden carriage, with a small anthropomorphic fox gunner standing on the gun carriage leaning aggressively over the barrel with both hands gripping it, the muzzle blackened with scorch marks and a rack of cannonballs lashed to the carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_mix` | Single prop, scavenged Napoleonic field cannon on a patched weathered dark wooden carriage, with a small anthropomorphic fox gunner perched on a dark powder barrel lashed to the gun carriage, with a coiled rope strapped over it. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |

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
| `cavalry_base` | Single character, towering powerful, broad and upright anthropomorphic crocodile with a long toothy snout, armored scutes and a massive tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps and two crossed heavy dark leather bandoliers with oversized metal cartridges forming a bold X across the chest, low stance, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_spd` | Single character, towering yet whip-thin, narrow-shouldered, greyhound-lean and long-limbed anthropomorphic crocodile with a long toothy snout, armored scutes and a massive tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps and a single very tall curved dark feather plume fixed upright to the shoulder of the harness, low stance, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_hp` | Single character, towering, colossally fat, round and squat, nearly as wide as he is tall, anthropomorphic crocodile with a long toothy snout, thick armored scutes and a massive tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps and a full heavy dark steel cuirass with massive rounded dark steel pauldrons on both shoulders, very low stance, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_atk` | Single character, towering, monstrously muscular, hulking and battle-scarred, top-heavy with colossal arms and shoulders, anthropomorphic crocodile with a long toothy snout, armored scutes and a massive tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps and a single oversized spiked dark iron pauldron on one shoulder, heavy studded dark iron gauntlets, with open jaws showing bared teeth, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `cavalry_mix` | Single character, towering, stocky and barrel-chested anthropomorphic crocodile with a long toothy snout, armored scutes and a massive tail, exaggerated stylized caricature proportions, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military harness with heavy leather straps and a thick dark rolled blanket worn diagonally across the chest from shoulder to hip, low stance, unarmed with empty hands, carrying no weapons of any kind. Clean neutral studio background, single figure only, no text. |
| `artillery_base` | Single prop, Napoleonic field cannon covered in dark grey camouflage netting with only the barrel protruding, on a weathered dark wooden carriage, with a small anthropomorphic lizard gunner standing upright on the gun carriage with one hand resting on the barrel, and a neatly coiled dark rope lashed to the carriage trail. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_spd` | Single prop, light Napoleonic cannon half covered by a dark grey tarp on a weathered dark wooden carriage with thin wheels, with a small anthropomorphic lizard gunner pushing hard against the back of the gun carriage, leaning forward mid-stride with both hands on it. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_hp` | Single prop, Napoleonic cannon draped in heavy dark grey camouflage netting and burlap, on a low weathered dark wooden carriage, with a small anthropomorphic lizard gunner sitting heavily on top of the thick barrel, and stacked dark sandbags lashed onto the carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_atk` | Single prop, long-barreled Napoleonic cannon with dark grey camouflage netting pulled aside, on a weathered dark wooden carriage, with a small anthropomorphic lizard gunner standing on the gun carriage leaning aggressively over the barrel with both hands gripping it, the muzzle blackened with scorch marks and a rack of cannonballs lashed to the carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |
| `artillery_mix` | Single prop, Napoleonic field cannon with a folded dark grey tarp on the weathered dark wooden carriage, with a small anthropomorphic lizard gunner perched on a dark powder barrel lashed to the gun carriage, with a coiled rope strapped over it. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, the cannon and one gunner only, no text. |

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

### Team-varianten van het musket (retexture, 7 september)

Sinds 7 september draagt het wapen een **eigen teamjas**: `<wapen>_red.png` en
`<wapen>_blue.png` naast de wapen-glb (`_melee_*` voor cavalerie). Ontbreekt zo'n
bestand, dan houdt het wapen gewoon de atlas uit zijn glb -- niets gaat stuk.

Dit zijn RETEXTURE-prompts, geen model-prompts: dezelfde mesh wordt twee keer
opnieuw beschilderd, dus **de UV-indeling moet blijven staan**. Vraag daar
expliciet om; `tools/uv_check.py` meet het antwoord (boven de 95% past hij).
Het uploadklare wapenbestand komt uit de paneelknop "Model klaarmaken voor
retexture" (`<naam>_wapen.glb`).

**Rood = bleek en versleten met dof donker ijzer. Blauw = zilver en goud met
donker gelakt hout.** Dit is de wapen-kant van de teamstijl uit 3-team. Het
teamverschil zit in het MATERIAAL, niet in verf: geen rode of blauwe banden op
de kolf. Dat leest rustiger en houdt het wapen binnen de
periode -- twee regimenten met ander materieel, niet twee geverfde speelgoed-
geweren. De factie-twist bepaalt nog steeds vorm en beslag; de teamjas ligt er
alleen overheen.

| Team | Toevoeging aan de prompt |
|---|---|
| rood | `pale bleached worn wood stock, dull tarnished dark iron fittings, scuffed, chipped and battle-worn` |
| blauw | `mirror-polished silver steel with gleaming gilded brass fittings, dark stained lacquered wood stock, immaculate parade condition` |

**Retexture-prompt-template:** `Retexture this weapon, keep the existing UV
layout and geometry unchanged. <factie-twist>, <team-toevoeging>. Gritty
realistic AAA-game concept art, highly detailed, no text.`

Voorbeeld voor `mouse/infantry_mix_musket`:

- **rood** -- `Retexture this weapon, keep the existing UV layout and geometry
  unchanged. A compact plain short-barrelled carbine with a fixed bayonet, pale
  bleached worn wood stock, dull tarnished dark iron fittings, scuffed, chipped
  and battle-worn. Gritty realistic AAA-game concept art, highly detailed, no
  text.`
- **blauw** -- `Retexture this weapon, keep the existing UV layout and geometry
  unchanged. A compact plain short-barrelled carbine with a fixed bayonet,
  mirror-polished silver steel with gleaming gilded brass fittings, dark stained
  lacquered wood stock, immaculate parade condition. Gritty realistic AAA-game
  concept art, highly detailed, no text.`

Let op: de materiaal-zin uit de factie-twist (bij de muis "plain dark iron and
worn pale wood") LAAT JE WEG in de retexture-prompt. Anders vraag je twee dingen
tegelijk -- dof donker ijzer en gepolijst zilver -- en kiest de dienst er zelf
een. De vorm zit al in de mesh; alleen de kleur hoeft nog.

Bij de **muis** ligt de rode variant dicht bij het huidige model (zijn twist is
al "worn pale wood"), en is de blauwe het echte verschil. Bij facties die al
donker hout hebben (Varken, Leeuw) is het net andersom: daar valt de rode
variant het meest op.

Waar de bestanden heen gaan in je leveringsmap:

    <factie>/<model>/weapon/red/   de png voor het rode team
    <factie>/<model>/weapon/blue/  idem blauw

De knop "Map in het spel zetten" herkent `weapon` in het pad, meet de jas tegen
de WAPEN-glb (die draagt maar een atlas, dus een verkeerde jas valt meteen door
de mand) en zet hem als `<wapen>_<team>.png` naast de glb.

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
enter-wapens -- geen fantasy-knotsen. **Ingebouwd in het spel sinds
16 augustus, zelfde systeem als het infanterie-musket.** Het geanimeerde
big bro-model komt net als de infanterie met het wapen VAST erin (de
generator bakt het bot-geparent aan de rechterhand, meestal als
`tripo_node_<uuid>`): het spel herkent zo'n meebewegend ingebakken wapen
(ook op naam-woorden als sabre/axe/lance) en laat het gewoon staan -- het
zwaait dan mee met de melee-clips. De losse `cavalry_<archetype>_melee.glb`
uit dit hoofdstuk is (net als bij de musketten) de DOODSWORP-prop en de
terugval voor modellen zonder ingebakken wapen: haal hem uit de blend met
`tools/blender_export_musket.py -- --uit <map>/cavalry_<arch>_melee.glb`.
Zelfde auto-schaal (~0,55 wereld-unit; een LANS dus in de Model-tuner
groter zetten via de wapen-schaal), kletter-categorie `val_melee`,
tuning-sleutel `<factie>/cavalry_<arch>_melee`. Tot de bestanden er liggen
vecht de big bro gewoon met blote handen.

**Type per archetype (16 augustus, verzoek Max: ook BINNEN de factie
varieren met sabels en bijlen -- eerst was elke factie een dozijn van
hetzelfde: muis en leeuw vijf klingen, varken vijf bijlen, beer vijf
lansen).** Het wapen-TYPE volgt nu het archetype, in elke factie hetzelfde,
dus het silhouet in de hand vertelt meteen de rol:

| Archetype | Type |
|---|---|
| base | sabel (gebogen kling) |
| spd | lang dun steekwapen (lans/piek/zeis) |
| hp | korte dikke bijl (wolf: kort hakblad -- buit is buit) |
| atk | het OVERMAATSE stuk uit de oude factie-familie (zie hieronder) |
| mix | kort en kaal (hanger/houwertje/hakbijltje) |

**Stijl-handtekening per factie (het karakter):** de factie herken je aan
materiaal en afwerking op ALLE vijf de wapens, plus het atk-stuk dat de
oude wapenfamilie draagt:

| Factie | Materiaal/stijl | atk-stuk (oude familie) |
|---|---|---|
| Muis (rat) | kaal soldatenijzer, bleek versleten hout | zware hakbriquet |
| Varken (everzwijn) | donker hout met zwaar koperbeslag | tweehandige sapeurs-broadaxe |
| Leeuw | officiers-walnoot met verguld graveerwerk | massieve pallasch |
| Beer (grizzly) | berijpt ijzer met bont-omwikkelde greep | zware uhlanenlans |
| Wolf (dire wolf) | schroot-reparaties, buitgemaakt allegaartje | gekaapte kurassiers-pallasch |
| Krokodil | mat ijzer met camouflagedoek om de greep | tweehandige enterbijl |

### Muis (rat) -- melee

| Bestand | Prompt |
|---|---|
| `cavalry_base_melee` | Single prop, a standard Napoleonic infantry briquet short sabre with a curved single-edged blade and a simple stirrup guard, plain dark iron with a worn pale wooden grip. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_spd_melee` | Single prop, a long slender sergeant's spontoon half-pike with a narrow leaf-shaped point, plain dark iron with a worn pale wooden shaft. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_hp_melee` | Single prop, a short thick pioneer hand axe with a broad reinforced head, plain dark iron with a worn pale wooden haft. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_atk_melee` | Single prop, an oversized heavy briquet sabre with a wide chopping blade and a crude iron guard, plain dark iron with a worn pale wooden grip. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_mix_melee` | Single prop, a plain infantry hanger with a short straight blade, plain dark iron with a worn pale wooden grip. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |

### Varken (everzwijn) -- melee

| Bestand | Prompt |
|---|---|
| `cavalry_base_melee` | Single prop, a heavy Napoleonic infantry sabre with a wide curved single-edged blade and a brass stirrup guard, chunky dark wooden grip with heavy brass fittings. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_spd_melee` | Single prop, a long slender pioneer's pike with a narrow iron spike, chunky dark wood shaft with heavy brass fittings. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_hp_melee` | Single prop, a short double-bitted sapper's axe with two thick reinforced heads, chunky dark wood haft with heavy brass fittings. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_atk_melee` | Single prop, a colossal two-handed sapper's broadaxe with an oversized bearded blade, chunky dark wood haft with heavy brass fittings. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_mix_melee` | Single prop, a plain short artillery hanger with a simple straight blade, chunky dark wooden grip with heavy brass fittings. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |

### Leeuw -- melee

| Bestand | Prompt |
|---|---|
| `cavalry_base_melee` | Single prop, a curved Napoleonic officer's cavalry sabre with an elegant swept guard, officer-grade dark walnut grip with ornate gilded pewter engraving. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_spd_melee` | Single prop, a long slender officer's lance with a fine needle point and a small silk pennant, officer-grade dark walnut shaft with ornate gilded pewter engraving. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_hp_melee` | Single prop, a short heavy officer's boarding axe with an engraved reinforced head, officer-grade dark walnut haft with ornate gilded pewter engraving. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_atk_melee` | Single prop, a massive heavy-cavalry pallasch with an extra long broad blade and a crowned pommel, officer-grade dark walnut grip with ornate gilded pewter engraving. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_mix_melee` | Single prop, a plain officer's spadroon with a simple stirrup guard, officer-grade dark walnut grip with ornate gilded pewter engraving. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |

### Beer (grizzly) -- melee

| Bestand | Prompt |
|---|---|
| `cavalry_base_melee` | Single prop, a heavy curved Russian cossack shashka sabre without a guard, frost-worn dark iron with a fur-wrapped grip. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_spd_melee` | Single prop, an extra-long slender light lance with a narrow needle point, frost-worn dark iron with a fur-wrapped grip. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_hp_melee` | Single prop, a short thick bearded axe with a broad reinforced head, frost-worn dark iron with a fur-wrapped haft. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_atk_melee` | Single prop, a massive heavy uhlan lance with an oversized armor-piercing point, frost-worn dark iron with a fur-wrapped grip. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |
| `cavalry_mix_melee` | Single prop, a plain broad Russian cossack kindjal short sword with a simple straight blade, frost-worn dark iron with a fur-wrapped grip. Gritty realistic AAA-game concept art, highly detailed. Side profile view, the entire object fully in frame and not cropped, clean neutral studio background, the weapon only, no hands, no text. |

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

## 3e. Teamkleur-texturen -- rood of blauw uniform, witte banden, zilver of goud

*(Max, 30 juli; op 3 september is het uniform zelf de teamkleur geworden.)*

Het **model** dat je genereert blijft strikt donkergrijs -- dat is de neutrale
ondergrond waar beide teams overheen gaan. De **teamkleur zit in de texture** die
naast de glb ligt, en die verft het uniform zelf: blauw leger = donkerblauwe jas,
rood leger = donkerrode jas. Bestandsnamen (het spel pakt ze op modelnaam):

| Bestand | Waarvoor |
|---|---|
| `<model>_blue.png` | blauw leger |
| `<model>_red.png` | rood leger |
| `<model>_blue_gore.png` / `<model>_red_gore.png` | bloederige recolor voor de gibs (optioneel) |

**Dezelfde UV-atlas als het model.** Makkelijkste route: een team klaarmaken en
daarna alleen de jas, het metaal en de pluim omkleuren.

### Wat per team verschilt

| Onderdeel | Blauw | Rood |
|---|---|---|
| **Uniform (jas, broek)** | **donker marineblauw** | **donker brikrood** |
| Kruisbanden / bandelier | wit | wit |
| Knopen | zilver | goud |
| Schouderstukken (epauletten) | zilver | goud |
| Pluim op de shako | lichtblauw (lichter dan de jas) | lichtrood (lichter dan de jas) |
| Leer (schoenen, patroontas, riem) | donkerbruin (gelijk) | donkerbruin (gelijk) |

De pluim is bewust **een tint lichter dan de jas**: in dezelfde kleur als het
uniform valt hij weg en dan is het silhouet op het bord een vlek. Witte banden en
de pluim doen samen het contrastwerk.

### Vaste kleuren -- altijd deze, nooit "gewoon rood"

"Blauw" en "rood" in een prompt levert elke keer een andere kleur op, en dan
staan er straks vijf verschillende blauwen op het bord. Daarom staan de kleuren
hieronder vast. De teamkleuren zijn dezelfde constanten als in
`scripts/ui/ui_assets.gd` (`TEAM_ROOD` / `TEAM_BLAUW`, plus de `_LICHT`-varianten
voor de pluim), zodat het lint op de kaart, het zegel in de UI en de pion op het
bord één kleur zijn. Wijzig je er een, wijzig je ze allebei.

| Wat | Woorden voor de prompt | Hex (naslag, niet in de prompt) | Vandaan |
|---|---|---|---|
| Uniform blauw team | `deep desaturated dark navy blue` | #2B3A78 | `UiAssets.TEAM_BLAUW` |
| Uniform rood team | `deep desaturated dark brick red` | #7E2C24 | `UiAssets.TEAM_ROOD` |
| Pluim blauw team | `lighter steel blue` | #8A9FE8 | `UiAssets.TEAM_BLAUW_LICHT` |
| Pluim rood team | `lighter coral red` | #E0705F | `UiAssets.TEAM_ROOD_LICHT` |
| Kruisbanden, riem | `crisp off-white` | #EDE9DE | -- |
| Metaal blauw team | `dull silver` | #B8BCC4 | -- |
| Metaal rood team | `antique brass gold` | #B38A47 | `UiAssets.MESSING` |
| Leer (schoenen, patroontas) | `dark brown` | #4A2F21 | `UiAssets.DONKER_LEER` |
| Bloed (gore-variant) | `dark dried blood red` | #5A1512 | **niet** de teamkleur |

**Hex-codes horen NIET in de prompt** (Max, 3 september): Nano Banana pikt ze
niet goed op en gaat er soms juist door zwabberen. In de prompt staan de
**woorden** uit de tweede kolom; de hex is voor naderhand -- controleren met de
pipet, of de kleur in Photoshop/Substance overzetten.

`Muted colours, nothing bright or saturated.` staat aan het eind van elke
textuur-prompt: dat doet het werk dat de hex niet doet, want zonder die rem komt
er een felle vlag-rood of kobaltblauw uit.

**Houd de prompt kort en noem alleen de kleuren.** Twee dingen die eruit blijven:

- **Het donkergrijs.** Dat hoort bij het model (par. 3), niet bij de texture:
  hier wordt de jas juist rood of blauw. Noem je het grijs alsnog, dan gaat de
  generator daarover en komen de teamkleuren er niet meer uit.
- **Het UV-verhaal.** "Texture repaint, identical UV layout, only colours change"
  zegt de generator niks; dat is een eis aan het bestand, geen beschrijving van
  een plaatje. Blijft gelden voor jou (zie de UV-atlas hierboven), maar het hoort
  niet in de prompt.

### Prompt -- blauw team (`<model>_blue.png`)

```
Same character in blue team colours: deep desaturated dark navy blue uniform coat, crisp
off-white crossbelts and waist belt, dull silver buttons and epaulettes, a lighter steel blue
feather plume, dark brown leather shoes and cartridge pouch. Muted colours, nothing bright or
saturated.
```

### Prompt -- rood team (`<model>_red.png`)

```
Same character in red team colours: deep desaturated dark brick red uniform coat, crisp
off-white crossbelts and waist belt, antique brass gold buttons and epaulettes, a lighter
coral red feather plume, dark brown leather shoes and cartridge pouch. Muted colours, nothing
bright or saturated.
```

### Prompt -- gore-variant (`<model>_<team>_gore.png`)

```
Same character with battle damage: dark dried blood red soaked into the uniform cloth and
splattered across the off-white belts, torn fabric, dulled and scratched metal. Team colours
unchanged. Muted colours, nothing bright or saturated.
```

### Meteen in kleur genereren (Modif e.d.) -- Max, 3 september

Er zijn twee wegen naar een gekleurde pion, en je hebt ze allebei nodig:

1. **Neutraal grijs model + losse teamtexture** (hierboven). Dit blijft de weg
   naar de glb: één model draagt beide teams, dus het model zelf mag geen kleur
   hebben.
2. **Direct in kleur**, als je gewoon een plaatje wilt zien. Dan neem je de
   model-prompt uit par. 3 en zet je de kleur er meteen in.

Voor weg 2 hoef je niks te knutselen: **de model-tracker toont per factie en
per unit naast de grijze prompt ook een ROOD- en een BLAUW-variant** met een
eigen kopieerknop (rood en blauw randje). Hij maakt ze uit dezelfde tekst, met
deze regels -- zelfde beest, zelfde attributen, nog steeds geen wapen:

| In de grijze prompt | Wordt in de team-variant |
|---|---|
| `strictly dark grey` | `deep desaturated dark brick red` (rood) / `deep desaturated dark navy blue` (blauw) |
| `dark grey epaulettes` | `antique brass gold epaulettes` / `dull silver epaulettes` |

Daarna komt er vóór `Clean neutral studio background` één zin bij, en die noemt
**alleen wat dit model echt draagt** -- anders krijgt een big bro epauletten die
hij niet heeft:

| Staat er in de prompt | Dan komt erbij |
|---|---|
| `uniform` / `greatcoat` / `military jacket` (infanterie) | `crisp off-white crossbelts and waist belt, <metaal> buttons and epaulettes` |
| `harness` (de big bro: blote borst, leren riemen) | `<metaal> buckles and metal fittings on the harness` |
| een `plume` (meestal alleen de spd) | `the feather plume in <pluim>` |
| wél een hoed maar géén pluim | `the hat band and cockade in <pluim>` |
| `Single prop` (kanon) | `The gunner wears a <jas> uniform with crisp off-white belts and <metaal> buttons.` |

En altijd als slot: `Muted colours, nothing bright or saturated.`

De **hoed zelf blijft donkergrijs** vilt; alleen de band, de kokarde of de pluim
krijgen de teamkleur. De wapens blijven eruit: `unarmed with empty hands,
carrying no weapons of any kind` staat er nog steeds in, want musketten en
melee-wapens zijn losse props uit par. 3c.

**De hoed volgt de glb, niet het doc** (Max, 3 september). De team-prompt kleurt
een model dat er al ís, dus hij moet beschrijven wat er in dat bestand zit. De
cavalerie van Muis, Varken en Leeuw is gemaakt vóór de big bro een factie-hoed
kreeg: die **vijftien modellen hebben geen `Hat`-deel**, en dan haalt de tracker
de hoed uit de kleur-prompt (bij de spd gaat de pluim mee, want die zit aan die
hoed) en noemt hij ook geen kokarde of sjerp -- niets verzinnen wat er niet op
zit, want de generator tekent het er anders bij. De teamkleur zit dan in het
harnas en het metaal. Bij een model dat nog niet bestaat beslist de prompt-tekst,
dus die krijgt zijn hoed gewoon.

Die lijst leest `python tools/bouw_hoedenlijst.py` uit de glb's zelf (`MODEL_HOED`
in de tracker). **Draai hem na elke nieuwe of vervangen glb**, dan klopt de
kleur-prompt weer met wat er op schijf staat. Stand nu: 45 modellen, 30 met hoed
(alle infanterie), 15 zonder (alle cavalerie).

*(3 september: de tracker droeg nog de prompts van 28 juli -- daar had de
cavalerie geen hoed en geen archetype-uitrusting, dus de team-variant beschreef
een ander beest dan het model. Alle 90 prompts zijn opnieuw uit dit doc
gegenereerd; par. 3 is de bron, de tracker is de kopie.)*

**Voor de andere facties**: de jas, het metaal en de pluim volgen het team; de
factie-eigen dingen (Krokodil-camouflagedoek, Wolf-lappen en vacht, Beer-kuras)
houden hun eigen kleur. Voeg die er zo nodig achteraan bij, en laat de rij
kleurwoorden **woord voor woord** staan zoals hij is: dat is nou juist het stuk
dat overal gelijk moet zijn.

## 3f. Factie-emblemen -- het DUO-wapen (2D, stijl van het UI-pack)

**Waarom nieuw** (verzoek Max, 3 september 2026): het UI-pack in
`fogofwar-assets/UI_assets_pack/Emblems/` heeft zes emblemen, maar elk daarvan
toont EEN kop -- vier keer de big bro (Beer, Leeuw, Krokodil, Wolf) en twee keer
het kleine broertje (Muis, Varken). Dat botst met de familie-regel uit par. 3:
**een factie is altijd een duo**, het kleine broertje (infanterie) plus de big
bro (cavalerie). Deze zes prompts tekenen dat duo, in exact de stijl van de
bestaande zes.

Gebruik: factiekeuze-kaart (UI-SPEC-EN §2.2), grootboekrij (§2.8), HUD en
MatchReport. In UI-DESIGN-BRIEF §2.1 en §9 staat dit als "6 doctrine-emblemen",
gedeeld met CARD-DESIGN-BRIEF §5.3.

### De stijl, uit de zes bestaande png's gelezen

| Onderdeel | Wat er ligt |
|---|---|
| Techniek | houtsnede/scratchboard: dichte pen-en-inkt arcering en stippeling, **puur zwarte inkt op wit**, geen grijstinten, geen halftoon, geen kleur |
| Kader | bust, afgesneden op borsthoogte, driekwart naar rechts, blik vooruit, streng-waardige kop |
| Kleding | hoge staande kraag, dubbele rij bolle knopen, epaulet met zware franje; in het pack draagt alle zes dezelfde bicorne |
| Achtergrond | vlak wit, geen kader, geen tekst; **geen witte snijlijn om het silhouet** -- het pack heeft die sticker-rand wel, wij niet (zie hieronder) |
| Formaat | vierkant, ~500x500 px |

### De hoeden: zes generaals, zes silhouetten (Max, 3 september)

De big bro is de **generaal** van zijn factie en draagt dus generaalstenue, geen
gewone troepenhoed. En bij elke factie een andere: samen met de kop is de hoed
het herkenpunt op 64 px, dus **geen twee facties met hetzelfde silhouet**. Het
kleine broertje houdt de **factie-eigen hoed uit par. 3**, zodat het duo bij het
3D-leger blijft horen.

| Factie | Generaalshoed van de big bro | Hoed van het broertje |
|---|---|---|
| Varken | klassieke bicorne dwars op de kop (de hoed van het pack), brede gouden bies, kokarde met rozet, **eikel-kwasten aan beide punten** | gewone kleine bicorne |
| Muis | bicorne **andersom gedragen**, punten voor en achter, met een **zeer hoge dunne rechte pluim** | shako met pluim |
| Leeuw | maarschalks-bicorne, de hele rand **omzoomd met struisveren-franje** | hoge berenmuts |
| Beer | hoge Russische **bonten papacha** met zwaar koord en een slap overhangende kruin | ushanka met opgebonden kleppen |
| Wolf | **gedeukte bicorne scheef op de kop**, een punt opengescheurd, **geknakte pluim en een geknoopte lap** om de bol | veldpet met kwastje |
| Krokodil | ouderwetse **tricorne met gouden bies**, laag over de ogen, met een **stuk camouflagenet** onder de hoedband | tricorne onder een kap |

### Vast stijlblok (vul de vijf vakjes in)

```
Two characters in one emblem, vintage black and white woodcut engraving in the style of
an antique regimental seal: a large anthropomorphic <BIG BRO> general bust in three-quarter
view facing right, wearing <GENERAALSHOED>, and a high standing-collar double-breasted
uniform coat heavy with braid, large round buttons and thick bullion epaulettes with long
fringe on the shoulders; in front of his chest on the lower left a much smaller anthropomorphic <KLEINE
BROER> soldier bust, about half his height, facing the same way and wearing <HOED>.
<FACTIE-DETAIL>. Dense pen-and-ink cross-hatching and stippling, pure solid black ink on a
plain white background, no grey tones, no halftone dots, no colour, strong contrast with
crisp white highlights in the fur. Both heads fully in frame, clearly separated by a thin
white gap so each silhouette reads on its own. Square composition, centred, the ink drawing sitting
directly on a plain white background with no outline, keyline or cut-out edge around the
silhouette, no frame, no border, no text, no lettering, no banner.
```

Negatief (voor generatoren die dat vakje hebben): `colour, grey tones,
halftone, gradient, soft shading, photo, 3D render, background scenery, text,
letters, numbers, watermark, frame, border, sticker outline, white keyline,
drop shadow, cropped heads, three or more characters`.

### De zes prompts

| Bestand | Prompt |
|---|---|
| `emblem_mouse_duo.png` | Two characters in one emblem, vintage black and white woodcut engraving in the style of an antique regimental seal: a large anthropomorphic fat brown rat general bust with a blunt whiskered snout, beady eyes and a notched ear, in three-quarter view facing right, wearing a Napoleonic general's bicorne hat worn fore-and-aft with the points to the front and back, edged with braid, a round cockade on the front point and a single very tall thin upright feather plume, and a high standing-collar double-breasted uniform coat heavy with braid, large round buttons and thick bullion epaulettes with long fringe on the shoulders; in front of his chest on the lower left a much smaller anthropomorphic mouse soldier bust with oversized round ears, long twitching whiskers and a pointed snout, about half his height, facing the same way and wearing a tall Napoleonic shako with a chin scale and an upright feather plume. Dense pen-and-ink cross-hatching and stippling, pure solid black ink on a plain white background, no grey tones, no halftone dots, no colour, strong contrast with crisp white highlights in the fur. Both heads fully in frame, clearly separated by a thin white gap so each silhouette reads on its own. Square composition, centred, the ink drawing sitting directly on a plain white background with no outline, keyline or cut-out edge around the silhouette, no frame, no border, no text, no lettering, no banner. |
| `emblem_pig_duo.png` | Two characters in one emblem, vintage black and white woodcut engraving in the style of an antique regimental seal: a large anthropomorphic wild boar general bust with enormous upward-curving tusks, a broad snout and a bristly spined mane, in three-quarter view facing right, wearing a classic Napoleonic general's bicorne hat worn athwart with a wide gold-braided edge, a round cockade with a rosette badge on the side and heavy acorn tassels hanging from both points, and a high standing-collar double-breasted uniform coat heavy with braid, large round buttons and thick bullion epaulettes with long fringe on the shoulders; in front of his chest on the lower left a much smaller anthropomorphic pig soldier bust with a big flat upturned snout, floppy ears and a round jowly face, about half his height, facing the same way and wearing a smaller plain Napoleonic bicorne hat. Dense pen-and-ink cross-hatching and stippling, pure solid black ink on a plain white background, no grey tones, no halftone dots, no colour, strong contrast with crisp white highlights in the bristles. Both heads fully in frame, clearly separated by a thin white gap so each silhouette reads on its own. Square composition, centred, the ink drawing sitting directly on a plain white background with no outline, keyline or cut-out edge around the silhouette, no frame, no border, no text, no lettering, no banner. |
| `emblem_lion_duo.png` | Two characters in one emblem, vintage black and white woodcut engraving in the style of an antique regimental seal: a large anthropomorphic lion general bust with a full flowing mane and a proud raised muzzle, in three-quarter view facing right, wearing a marshal's bicorne hat with the entire brim edged in a dense fringe of ostrich feathers, gold lace and a round cockade, and a high standing-collar double-breasted uniform coat heavy with braid, large round buttons and thick bullion epaulettes with long fringe on the shoulders; in front of his chest on the lower left a much smaller anthropomorphic cheetah soldier bust with bold black rosette spots and long teardrop face stripes, about half his height, facing the same way and wearing a tall black bearskin grenadier cap with a chin cord. Dense pen-and-ink cross-hatching and stippling, pure solid black ink on a plain white background, no grey tones, no halftone dots, no colour, strong contrast with crisp white highlights in the mane. Both heads fully in frame, clearly separated by a thin white gap so each silhouette reads on its own. Square composition, centred, the ink drawing sitting directly on a plain white background with no outline, keyline or cut-out edge around the silhouette, no frame, no border, no text, no lettering, no banner. |
| `emblem_bear_duo.png` | Two characters in one emblem, vintage black and white woodcut engraving in the style of an antique regimental seal: a large anthropomorphic grizzly bear general bust with a massive head, small round ears and a heavy shaggy neck, in three-quarter view facing right, wearing a tall Russian general's fur papakha cap with a heavy cord across the front and a soft cloth crown flopping over to one side, and a high standing-collar double-breasted greatcoat heavy with braid, large round buttons and thick bullion epaulettes with long fringe on the shoulders; in front of his chest on the lower left a much smaller anthropomorphic raccoon soldier bust with a dark bandit mask across the eyes and tufted ears, about half his height, facing the same way and wearing a round Russian ushanka fur hat with the ear flaps tied up. Dense pen-and-ink cross-hatching and stippling, pure solid black ink on a plain white background, no grey tones, no halftone dots, no colour, strong contrast with crisp white highlights in the thick fur. Both heads fully in frame, clearly separated by a thin white gap so each silhouette reads on its own. Square composition, centred, the ink drawing sitting directly on a plain white background with no outline, keyline or cut-out edge around the silhouette, no frame, no border, no text, no lettering, no banner. |
| `emblem_wolf_duo.png` | Two characters in one emblem, vintage black and white woodcut engraving in the style of an antique regimental seal: a large anthropomorphic dire wolf general bust with a long scarred muzzle, ragged pointed ears and a shaggy ruff, in three-quarter view facing right, wearing a battered bicorne hat cocked crooked on his head with one point torn open, a snapped-off feather plume and a knotted rag tied around the crown, and a high standing-collar double-breasted uniform coat, frayed and battle-worn, with tarnished braid, large round buttons and thick bullion epaulettes with long fringe on the shoulders; in front of his chest on the lower left a much smaller anthropomorphic fox soldier bust with huge pointed ears and a sharp narrow snout, about half his height, facing the same way and wearing a soft Napoleonic forage cap with a hanging tassel. Dense pen-and-ink cross-hatching and stippling, pure solid black ink on a plain white background, no grey tones, no halftone dots, no colour, strong contrast with crisp white highlights in the fur. Both heads fully in frame, clearly separated by a thin white gap so each silhouette reads on its own. Square composition, centred, the ink drawing sitting directly on a plain white background with no outline, keyline or cut-out edge around the silhouette, no frame, no border, no text, no lettering, no banner. |
| `emblem_crocodile_duo.png` | Two characters in one emblem, vintage black and white woodcut engraving in the style of an antique regimental seal: a large anthropomorphic crocodile general bust with a long toothy snout, hooded eyes and heavy armoured scutes along the neck, in three-quarter view facing right, wearing an old-fashioned general's tricorne hat edged with gold lace worn low over his eyes, with a scrap of camouflage netting tucked under the hat band, and a high standing-collar double-breasted uniform coat heavy with braid, large round buttons and thick bullion epaulettes with long fringe on the shoulders; in front of his chest on the lower left a much smaller anthropomorphic lizard soldier bust with camouflage-patterned scales and big lidded eyes, about half his height, facing the same way and wearing a Napoleonic tricorne hat under a loose hood. Dense pen-and-ink cross-hatching and stippling, pure solid black ink on a plain white background, no grey tones, no halftone dots, no colour, strong contrast with crisp white highlights on the scales. Both heads fully in frame, clearly separated by a thin white gap so each silhouette reads on its own. Square composition, centred, the ink drawing sitting directly on a plain white background with no outline, keyline or cut-out edge around the silhouette, no frame, no border, no text, no lettering, no banner. |

### Wat je aanlevert, en de enige echte test

- **1024x1024 PNG op wit** (zelfde vierkant als het pack) plus een uitsnede met
  **alpha** (`emblem_<factie>_duo_cut.png`); de UI zet ze op papierkleur, dus een
  ingebakken wit vlak valt op.
- **Geen witte rand om de tekening.** De zes uit het pack hebben een sticker-lijn
  rondom; die willen we niet. De uitsnede volgt de inkt zelf, dus geen witte halo, geen
  keyline en geen slagschaduw. Komt hij er in de generatie toch in: die rand is wit en
  zit vast aan de achtergrond, dus een vulling vanaf de beeldrand door alles wat
  doorzichtig OF wit is haalt hem weg zonder de witte lichtjes IN de tekening te raken.
  Zo zijn de zes uit het pack al schoongemaakt: `UI_assets_pack/Emblems/zonder_rand/`
  (`<Naam>_cut.png`, de originelen bleven staan).
- Factie-id in de naam is die van de mappen en de code: `mouse`, `pig`, `lion`,
  `bear`, `wolf`, `crocodile`. Naast de glb's van de factie hoeft niets: dit is
  UI-werk, geen model.
- **Verklein naar 64 px** (factiekaart) en kijk of de twee koppen nog uit elkaar
  vallen, en of je de zes generaalshoeden nog uit elkaar houdt. Zo niet: broertje
  kleiner, witte kier breder, hoed groter en simpeler. Leg de zes op die maat ook
  even naast elkaar: twee facties met hetzelfde hoed-silhouet is een fout, geen
  smaakkwestie. Slibt het bij 32 px (grootboekrij) alsnog dicht, gebruik
  daar het **bestaande enkele-kop-embleem** uit het pack: die zes blijven dus
  gewoon liggen als kleine maat.
- Zelfde regel als bij de modellen: **geen kleur** in de tekening. Team-rood en
  team-blauw komen uit de UI-laag eromheen, niet uit het embleem.

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

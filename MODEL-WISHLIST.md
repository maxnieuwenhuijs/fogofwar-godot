# 3D-modellen — ontwerpgids & verlanglijst

Het systeem zit in het spel (`PawnView.set_character`): drop een `.glb` op het
juiste pad en hij verschijnt vanzelf — geen code nodig. Elke pion toont:

1. **Ongekoppeld / opstelling** → het neutrale factie-model (`_basis`).
2. **Gekoppeld aan een kaart** → het archetype-model van de dominante stat.
3. **Verborgen Vos-koppeling** → tegenstander blijft het neutrale model zien
   tot de kaart onthuld wordt (anders verraadt het model de kaart).

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
| `basis` | geen kaart | **Neutraal, rustige pose** | zelfde als mix maar in rust (wapen geschouderd, zittend dier) — verraadt níks (belangrijk voor de Vos) |

Vuistregels:
- Overdrijf: op 2 cm schermhoogte is 20% breder nauwelijks zichtbaar — denk 40%.
- Alle vijf de varianten van één factie delen kop, kleuren en materialen; alleen
  bouw en houding verschillen. Zo herken je factie én kaart tegelijk.
- Houd de voetafdruk binnen het vak (~1×1): `hp` mag breed, niet groter dan de tegel.
- Periode: 18e/19e-eeuws (musketten, sabels, kanonnen op houten affuiten) — zelfde
  wereld als het geluidsontwerp (zie SOUND-WISHLIST.md).

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

### Budget 7 — Mens, Beer, Wolf, Vos (15 combinaties)

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

## 3. Ontwerp per factie

Elke factie = één diersoort + één stijl. Composities: Mens 13/6/3 ·
Muis 22/0/0 · Leeuw 6/10/2 · Beer 16/3/3 · Wolf 11/8/3 · Vos 13/6/3.

### Muis — geïmproviseerd leger (alleen infanterie: 5 modellen)

Kleine knagers met huis-tuin-en-keuken-uitrusting: vingerhoed als helm,
naald als degen, kurk als schild. Kleur: grijsbruin + rood sjaaltje.

| Bestand | Suggestie |
|---|---|
| `infanterie_basis` | rechtopstaande muis, nieuwsgierig om zich heen kijkend, pootjes ineen |
| `infanterie_spd` | **dunne schichtige muis**: gestrekt, laag, grote oren plat naar achteren, staart recht achteruit, mid-sprint |
| `infanterie_hp` | mollige muis, vingerhoed-helm diep over de oren, kurken schild, breed neergeplant |
| `infanterie_atk` | gespierde muis (brede borst), naald-rapier vooruit, tandjes ontbloot |
| `infanterie_mix` | nette muis-soldaat met knapzakje en speldje-bajonet geschouderd |

### Mens — Napoleontische linie (15 modellen)

Klassieke 18e/19e-eeuwse soldaten. Kleur: blauwgrijs uniform, messing knopen.

| Bestand | Suggestie |
|---|---|
| `infanterie_basis` | musketier in rust, geweer geschouderd, tricorne |
| `infanterie_spd` | voltigeur/verkenner: dun, korte jas, vooroverleunende looppas |
| `infanterie_hp` | grenadier: berenmuts, dikke overjas, borstplaat, breed en laag |
| `infanterie_atk` | stormsoldaat: brede schouders, bajonet gestrekt naar voren, uitvalspas |
| `infanterie_mix` | linie-infanterist in aanslag |
| `cavalerie_basis` | dragonder op stilstaand paard |
| `cavalerie_spd` | huzaar op slank renpaard, laag in het zadel, dolman wappert |
| `cavalerie_hp` | kurassier: borstkuras, zwaar breed paard, stapvoets |
| `cavalerie_atk` | lansier: gevelde lans, paard in galop-uitval, gespierd |
| `cavalerie_mix` | dragonder met sabel geschouderd |
| `artillerie_basis` | veldkanon op houten affuit + kanonnier ernaast |
| `artillerie_spd` | rijdende artillerie: klein licht stuk, grote dunne wielen |
| `artillerie_hp` | vestingstuk: korte dikke loop, zware lage affuit, zandzakken |
| `artillerie_atk` | houwitser: extra lange dikke loop, dreigend omhoog |
| `artillerie_mix` | standaard veldstuk |

### Leeuw — koninklijke garde (15 modellen)

Majestueus en zwaar: goud op rood, manen als uniformkraag. Alles net wat
groter en rijker versierd dan de Mens (budget 9!).

| Bestand | Suggestie |
|---|---|
| `infanterie_basis` | garde-leeuw rechtop, manen als kraag, hellebaard rustend |
| `infanterie_spd` | jonge leeuwin: slank, sluippas, geen bepakking |
| `infanterie_hp` | brede leeuw met vergulde borstplaat, laag zwaartepunt |
| `infanterie_atk` | gespierde leeuw: klauwen uit, bek open, sabel geheven |
| `infanterie_mix` | garde-leeuw in het gelid |
| `cavalerie_basis` | leeuw op strijdros met rood dekkleed |
| `cavalerie_spd` | leeuwin op renpaard, gestrekte galop |
| `cavalerie_hp` | gepantserde leeuw op zwaar paard met kopplaat |
| `cavalerie_atk` | leeuw met gevelde sabel, paard steigert |
| `cavalerie_mix` | garde-ruiter |
| `artillerie_basis` | verguld belegeringskanon (denk: dracht 7-perk → lange loop) |
| `artillerie_spd` | lichter vergulde veldslang, dunne lange loop |
| `artillerie_hp` | massief bronzen bombarde, kort en dik |
| `artillerie_atk` | dubbel-verguld monsterkanon, extra lange loop, brede affuit |
| `artillerie_mix` | koninklijk veldstuk |

### Beer — log winterleger (15 modellen)

Zwaar, traag, onverwoestbaar (HP-bonus + Speed-cap): hout en ijzer,
bontmutsen, sneeuw-thema. Kleur: donkerbruin + ijzergrijs.

| Bestand | Suggestie |
|---|---|
| `infanterie_basis` | zittende beer met bontmuts, musket over de knieën |
| `infanterie_spd` | (zeldzaam: alleen 2/3/2) lichtere bruine beer, verrassend lichtvoetig op de tenen |
| `infanterie_hp` | massieve grizzly: ijzeren borstplaat, armen wijd, als een muur |
| `infanterie_atk` | beer op achterpoten met strijdbijl, brede schouders, brullend |
| `infanterie_mix` | berensoldaat stapvoets met geschouderd musket |
| `cavalerie_basis` | beer op zwaar trekpaard |
| `cavalerie_spd` | beer op ietwat vlotter paard, nog steeds log |
| `cavalerie_hp` | beer + paard beide bepantserd, schildpad-achtig |
| `cavalerie_atk` | beer met knots, paard in zware charge |
| `cavalerie_mix` | beren-ruiter |
| `artillerie_basis` | fort-mortier: kort, dik, houten blokken-affuit |
| `artillerie_spd` | slee-kanon (getrokken licht stuk) |
| `artillerie_hp` | belegeringsmortier half ingegraven achter zandzakken |
| `artillerie_atk` | dubbele mortier, brede bek |
| `artillerie_mix` | winterveldstuk |

### Wolf — guerrilla-roedel (15 modellen)

Sluipend en opportunistisch (wolf-stap + springt over vijandelijke infanterie):
grijs, gehavende mantels, buitgemaakte spullen. Kleur: leigrijs + gifgroen accent.

| Bestand | Suggestie |
|---|---|
| `infanterie_basis` | wolf laag bij de grond, oren gespitst, loerend |
| `infanterie_spd` | magere prairiewolf: gestrekt, bijna liggend in de sprint |
| `infanterie_hp` | dikke winterwolf met dubbele vacht en gestolen borstplaat |
| `infanterie_atk` | grommende wolf met hakmes, hoge brede schoft, tanden ontbloot |
| `infanterie_mix` | roedel-wolf in draf |
| `cavalerie_basis` | wolf-ruiter op gedrongen paard (de springer!) |
| `cavalerie_spd` | wolf op licht steppenpaard, laag over de hals |
| `cavalerie_hp` | wolf met buitgemaakt kuras op stevig paard |
| `cavalerie_atk` | wolf-ruiter mid-sprong met geheven kling — dé perk-pose |
| `cavalerie_mix` | roedel-ruiter |
| `artillerie_basis` | buitgemaakt kanon, touwen en jute er nog omheen |
| `artillerie_spd` | licht bergkanon, uit elkaar te nemen |
| `artillerie_hp` | kanon achter geïmproviseerde barricade |
| `artillerie_atk` | dubbel buit-kanon, extra kruitvaten ernaast |
| `artillerie_mix` | roedel-veldstuk |

### Vos — het maskerade-leger (15 modellen)

Elegant en geheimzinnig (verborgen koppelingen!): capes en mantels die de
uitrusting verhullen. Kleur: roestrood + nachtblauwe cape. **Belangrijk:
álle varianten dragen de cape** — het verschil zit in bouw en houding, zodat
het neutrale model geloofwaardig "elke kaart" kan zijn.

| Bestand | Suggestie |
|---|---|
| `infanterie_basis` | vos rechtop, cape dicht, alleen de snuit zichtbaar — de pokerface |
| `infanterie_spd` | slanke vos, cape strak om het lijf, lage sluippas |
| `infanterie_hp` | vos met dikke wintervacht, maliënkolder glimt ónder de cape |
| `infanterie_atk` | brede vos, cape half open: twee dolken zichtbaar, gedoken aanvalshouding |
| `infanterie_mix` | vos-soldaat, cape over één schouder |
| `cavalerie_basis` | vos-ruiter met wapperende cape (de +1 Speed-perk mag je voelen) |
| `cavalerie_spd` | vos plat op een windhond-achtig paard, cape horizontaal |
| `cavalerie_hp` | vos + paard onder één groot dekkleed, silhouet verhuld |
| `cavalerie_atk` | vos-ruiter met getrokken sabel uit de cape |
| `cavalerie_mix` | elegante ruiter |
| `artillerie_basis` | kanon onder camouflagenetten, alleen de loop steekt uit |
| `artillerie_spd` | licht stuk half onder dekzeil, klaar om te verkassen |
| `artillerie_hp` | kanon in gegraven stelling met rieten manden |
| `artillerie_atk` | ontmaskerd kanon: netten eraf getrokken, lange loop |
| `artillerie_mix` | veldstuk met dekzeil |

---

## 4. Bestandsconventie & fallback

```
assets/models/<factie>/<type>_<archetype>.glb
```

- factie: `mens` `muis` `leeuw` `beer` `wolf` `vos` (kleine letters)
- type: `infanterie` `cavalerie` `artillerie`
- archetype: `basis` `spd` `hp` `atk` `mix`

**Fallback-keten**: `<type>_<archetype>.glb` → `<type>_basis.glb` → geometrisch
stuk met archetype-silhouet. Alles werkt dus ook met maar één model per type.
`mix` mag je overslaan (valt terug op `basis`).

**Prioriteit**: eerst de 16 `_basis`-modellen (elke factie meteen een eigen
gezicht), dan per factie `spd`/`hp`/`atk` (de leesbaarheid), `mix` als laatste.
Volledige set: 80 bestanden, minus overgeslagen `mix` = 64.

## 5. Technische eisen per model

- **Formaat**: `.glb` (glTF-binair; mesh + materialen + evt. animaties in één bestand)
- **Low-poly**: < 5.000 tris (er staan 44 stukken op het bord)
- **Maat**: ~0,9 unit hoog (vakken zijn 1×1); cavalerie mag ~1,1; `hp`-varianten
  breed maar binnen de tegel
- **Origin**: voeten op y = 0, gecentreerd
- **Kijkrichting**: neus naar **−Z** (de voorkant die `face_dir()` draait)
- **Teamkleur**: hoeft niet in het model — het spel zet automatisch een
  rood/blauw sokkeltje onder elk `.glb`-model
- **Animaties (optioneel)**: `AnimationPlayer` met clips `idle` / `walk` /
  `attack` / `die` wordt automatisch opgepakt (namen instelbaar op PawnView)
- Na het droppen éénmalig importeren: editor openen of
  `Godot --headless --path . --import`

## 6. Gratis bronnen (stijl past bij low-poly bord)

- **Quaternius** (quaternius.com) — CC0, complete animal packs + soldiers
- **Kenney** (kenney.nl) — CC0, animated characters
- **Sketchfab** — filter op CC0/CC-BY + "low poly", zoek per dier
- Zelf (laten) maken in Blender: exporteer als glTF 2.0 (.glb), Y-up staat goed

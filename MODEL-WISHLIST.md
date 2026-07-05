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

## 3. Generatie-prompts per factie (Engels)

Elke factie = één diersoort, allemaal in hetzelfde **weathered, strictly dark
grey Napoleonic**-thema (de teamkleur komt van het rood/blauwe sokkeltje, dus
de uniformen blijven strikt donkergrijs). Composities: Mens 13/6/3 ·
Muis 22/0/0 · Leeuw 6/10/2 · Beer 16/3/3 · Wolf 11/8/3 · Vos 13/6/3.

**Prompt-opbouw** (template): `Single character, <bouw> anthropomorphic
<dier>, A-pose. Gritty realistic AAA-game concept art, highly detailed.
Wearing a weathered, strictly dark grey Napoleonic military uniform and
<hoofddeksel>, <uitrusting>. Clean neutral studio background, single figure
only, no text.`

- **A-pose** is bewust: nodig voor rigging/animatie. Het archetype zit in de
  **bouw** (thin lean / heavyset / broad-shouldered muscular); de houding uit
  §1 komt later via de idle-animatie.
- Cavalerie: `mounted on a <paard>, neutral riding pose` i.p.v. A-pose.
- Artillerie: `Single prop` (kanon zonder bemanning), `single object only`.

### Muis (alleen infanterie: 5 prompts)

| Bestand | Prompt |
|---|---|
| `infanterie_basis` ✓ | Single character, average build anthropomorphic mouse, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and dark grey shako, unarmed with empty hands. Clean neutral studio background, single figure only, no text. |
| `infanterie_spd` | Single character, thin lean anthropomorphic mouse, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and dark grey shako. Clean neutral studio background, single figure only, no text. |
| `infanterie_hp` | Single character, heavyset round-bodied anthropomorphic mouse, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform with a dark steel cuirass and dark grey shako. Clean neutral studio background, single figure only, no text. |
| `infanterie_atk` | Single character, broad-shouldered muscular anthropomorphic mouse, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and dark grey shako, carrying a musket with fixed bayonet. Clean neutral studio background, single figure only, no text. |
| `infanterie_mix` | Single character, average build anthropomorphic mouse, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and dark grey shako, with a musket slung over the shoulder. Clean neutral studio background, single figure only, no text. |

### Mens (15 prompts)

| Bestand | Prompt |
|---|---|
| `infanterie_basis` | Single character, average build human soldier, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and dark grey bicorne hat, unarmed with empty hands. Clean neutral studio background, single figure only, no text. |
| `infanterie_spd` | Single character, thin lean human skirmisher, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey short Napoleonic jacket and dark grey shako, light field gear. Clean neutral studio background, single figure only, no text. |
| `infanterie_hp` | Single character, heavyset human grenadier, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic greatcoat with a dark steel cuirass and tall dark grey bearskin cap. Clean neutral studio background, single figure only, no text. |
| `infanterie_atk` | Single character, broad-shouldered muscular human soldier, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and dark grey shako, carrying a musket with fixed bayonet. Clean neutral studio background, single figure only, no text. |
| `infanterie_mix` | Single character, average build human line infantryman, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and dark grey shako, with a musket slung over the shoulder. Clean neutral studio background, single figure only, no text. |
| `cavalerie_basis` | Single character, average build human dragoon mounted on a standing horse, neutral riding pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic cavalry uniform and dark grey helmet, unarmed. Clean neutral studio background, single figure only, no text. |
| `cavalerie_spd` | Single character, thin lean human hussar mounted on a slender racing horse, neutral riding pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic hussar uniform with dark grey fur-trimmed pelisse and shako. Clean neutral studio background, single figure only, no text. |
| `cavalerie_hp` | Single character, heavyset human cuirassier mounted on a heavy broad draft horse, neutral riding pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic uniform with a dark steel cuirass and crested helmet. Clean neutral studio background, single figure only, no text. |
| `cavalerie_atk` | Single character, broad-shouldered muscular human lancer mounted on a muscular warhorse, neutral riding pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic uniform and dark grey czapka, holding an upright lance. Clean neutral studio background, single figure only, no text. |
| `cavalerie_mix` | Single character, average build human dragoon mounted on a horse, neutral riding pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic cavalry uniform and dark grey helmet, sabre sheathed at the hip. Clean neutral studio background, single figure only, no text. |
| `artillerie_basis` | Single prop, Napoleonic field cannon on a weathered dark wooden gun carriage with two spoked wheels. Gritty realistic AAA-game concept art, highly detailed, dark iron barrel. Clean neutral studio background, single object only, no text. |
| `artillerie_spd` | Single prop, light Napoleonic horse-artillery cannon with a slender barrel on a weathered dark wooden carriage with large thin spoked wheels. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, single object only, no text. |
| `artillerie_hp` | Single prop, short thick Napoleonic fortress mortar on a heavy low weathered wooden block carriage, sandbags at the base. Gritty realistic AAA-game concept art, highly detailed, dark iron. Clean neutral studio background, single object only, no text. |
| `artillerie_atk` | Single prop, long-barreled heavy Napoleonic siege cannon on a reinforced weathered dark wooden carriage. Gritty realistic AAA-game concept art, highly detailed, dark iron barrel. Clean neutral studio background, single object only, no text. |
| `artillerie_mix` | Single prop, Napoleonic field cannon on a weathered dark wooden carriage, stacked cannonballs beside the wheel. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, single object only, no text. |

### Leeuw (15 prompts)

| Bestand | Prompt |
|---|---|
| `infanterie_basis` | Single character, average build anthropomorphic lion with a thick mane, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic officer's uniform with dark grey epaulettes and tall plumed shako, unarmed. Clean neutral studio background, single figure only, no text. |
| `infanterie_spd` | Single character, thin lean anthropomorphic lioness, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey short Napoleonic jacket and dark grey shako, light gear. Clean neutral studio background, single figure only, no text. |
| `infanterie_hp` | Single character, heavyset anthropomorphic lion with a thick mane, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic greatcoat with a dark steel cuirass and bearskin cap. Clean neutral studio background, single figure only, no text. |
| `infanterie_atk` | Single character, broad-shouldered muscular anthropomorphic lion with a wild mane, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic uniform and plumed shako, carrying a heavy sabre. Clean neutral studio background, single figure only, no text. |
| `infanterie_mix` | Single character, average build anthropomorphic lion guard, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform and dark grey shako, with a musket slung over the shoulder. Clean neutral studio background, single figure only, no text. |
| `cavalerie_basis` | Single character, average build anthropomorphic lion mounted on a standing warhorse with dark grey caparison, neutral riding pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic cavalry uniform, unarmed. Clean neutral studio background, single figure only, no text. |
| `cavalerie_spd` | Single character, thin lean anthropomorphic lioness mounted on a slender racing horse, neutral riding pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic hussar uniform and shako. Clean neutral studio background, single figure only, no text. |
| `cavalerie_hp` | Single character, heavyset anthropomorphic lion mounted on a heavy armored draft horse with dark steel chamfron, neutral riding pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic uniform with dark steel cuirass. Clean neutral studio background, single figure only, no text. |
| `cavalerie_atk` | Single character, broad-shouldered muscular anthropomorphic lion mounted on a muscular warhorse, neutral riding pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic uniform, holding a heavy sabre upright. Clean neutral studio background, single figure only, no text. |
| `cavalerie_mix` | Single character, average build anthropomorphic lion mounted on a horse, neutral riding pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic cavalry uniform, sabre sheathed. Clean neutral studio background, single figure only, no text. |
| `artillerie_basis` | Single prop, long-barreled Napoleonic siege cannon on an ornate weathered dark wooden gun carriage with pewter detailing. Gritty realistic AAA-game concept art, highly detailed, dark iron. Clean neutral studio background, single object only, no text. |
| `artillerie_spd` | Single prop, light long slender Napoleonic culverin cannon on a weathered dark wooden carriage with large thin wheels, pewter detailing. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, single object only, no text. |
| `artillerie_hp` | Single prop, massive short thick Napoleonic bombard on a heavy low weathered wooden carriage, pewter detailing. Gritty realistic AAA-game concept art, highly detailed, dark bronze. Clean neutral studio background, single object only, no text. |
| `artillerie_atk` | Single prop, extra long-barreled heavy Napoleonic siege cannon on a wide reinforced weathered dark wooden carriage, pewter detailing. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, single object only, no text. |
| `artillerie_mix` | Single prop, ornate Napoleonic field cannon on a weathered dark wooden carriage with pewter detailing. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, single object only, no text. |

### Beer (15 prompts)

| Bestand | Prompt |
|---|---|
| `infanterie_basis` | Single character, average build anthropomorphic bear, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic greatcoat and dark grey fur cap, unarmed. Clean neutral studio background, single figure only, no text. |
| `infanterie_spd` | Single character, thin lean anthropomorphic brown bear, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey short Napoleonic jacket and dark grey fur cap, light gear. Clean neutral studio background, single figure only, no text. |
| `infanterie_hp` | Single character, massive heavyset anthropomorphic grizzly bear, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic greatcoat with a heavy dark iron breastplate and fur cap. Clean neutral studio background, single figure only, no text. |
| `infanterie_atk` | Single character, broad-shouldered muscular anthropomorphic bear, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic uniform and dark grey fur cap, carrying a large battle axe. Clean neutral studio background, single figure only, no text. |
| `infanterie_mix` | Single character, average build anthropomorphic bear soldier, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic greatcoat and fur cap, with a musket slung over the shoulder. Clean neutral studio background, single figure only, no text. |
| `cavalerie_basis` | Single character, average build anthropomorphic bear mounted on a heavy standing draft horse, neutral riding pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic cavalry greatcoat and fur cap, unarmed. Clean neutral studio background, single figure only, no text. |
| `cavalerie_spd` | Single character, thin lean anthropomorphic bear mounted on a sturdy trotting horse, neutral riding pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey short Napoleonic jacket and fur cap. Clean neutral studio background, single figure only, no text. |
| `cavalerie_hp` | Single character, massive heavyset anthropomorphic bear mounted on a heavily armored draft horse, both wearing dark iron plating, neutral riding pose. Gritty realistic AAA-game concept art, highly detailed, weathered strictly dark grey Napoleonic gear. Clean neutral studio background, single figure only, no text. |
| `cavalerie_atk` | Single character, broad-shouldered muscular anthropomorphic bear mounted on a muscular heavy warhorse, neutral riding pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic uniform and fur cap, carrying a heavy club. Clean neutral studio background, single figure only, no text. |
| `cavalerie_mix` | Single character, average build anthropomorphic bear mounted on a draft horse, neutral riding pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic cavalry greatcoat and fur cap. Clean neutral studio background, single figure only, no text. |
| `artillerie_basis` | Single prop, short thick Napoleonic fortress mortar on a weathered dark wooden block carriage. Gritty realistic AAA-game concept art, highly detailed, dark iron. Clean neutral studio background, single object only, no text. |
| `artillerie_spd` | Single prop, light Napoleonic cannon mounted on a weathered wooden sled carriage. Gritty realistic AAA-game concept art, highly detailed, dark iron. Clean neutral studio background, single object only, no text. |
| `artillerie_hp` | Single prop, heavy Napoleonic siege mortar dug in behind sandbags on a massive low weathered wooden carriage. Gritty realistic AAA-game concept art, highly detailed, dark iron. Clean neutral studio background, single object only, no text. |
| `artillerie_atk` | Single prop, wide-mouthed double Napoleonic mortar on a reinforced weathered dark wooden carriage. Gritty realistic AAA-game concept art, highly detailed, dark iron. Clean neutral studio background, single object only, no text. |
| `artillerie_mix` | Single prop, Napoleonic winter field cannon on a weathered dark wooden carriage. Gritty realistic AAA-game concept art, highly detailed, dark iron. Clean neutral studio background, single object only, no text. |

### Wolf (15 prompts)

| Bestand | Prompt |
|---|---|
| `infanterie_basis` | Single character, average build anthropomorphic wolf, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a tattered, weathered, strictly dark grey Napoleonic military uniform and dark grey forage cap, unarmed. Clean neutral studio background, single figure only, no text. |
| `infanterie_spd` | Single character, thin lean gaunt anthropomorphic wolf, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a tattered, weathered, strictly dark grey short Napoleonic jacket and forage cap, minimal gear. Clean neutral studio background, single figure only, no text. |
| `infanterie_hp` | Single character, heavyset thick-furred anthropomorphic winter wolf, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a tattered, weathered, strictly dark grey Napoleonic greatcoat with a scavenged dark steel breastplate. Clean neutral studio background, single figure only, no text. |
| `infanterie_atk` | Single character, broad-shouldered muscular anthropomorphic wolf with bared teeth, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a tattered, weathered, strictly dark grey Napoleonic uniform, carrying a heavy cleaver. Clean neutral studio background, single figure only, no text. |
| `infanterie_mix` | Single character, average build anthropomorphic wolf soldier, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a tattered, weathered, strictly dark grey Napoleonic uniform and forage cap, with a musket slung over the shoulder. Clean neutral studio background, single figure only, no text. |
| `cavalerie_basis` | Single character, average build anthropomorphic wolf mounted on a compact sturdy horse, neutral riding pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a tattered, weathered, strictly dark grey Napoleonic cavalry uniform, unarmed. Clean neutral studio background, single figure only, no text. |
| `cavalerie_spd` | Single character, thin lean anthropomorphic wolf mounted on a light steppe horse, neutral riding pose low over the neck. Gritty realistic AAA-game concept art, highly detailed. Wearing a tattered, weathered, strictly dark grey Napoleonic uniform. Clean neutral studio background, single figure only, no text. |
| `cavalerie_hp` | Single character, heavyset anthropomorphic wolf with a scavenged dark steel cuirass mounted on a sturdy horse, neutral riding pose. Gritty realistic AAA-game concept art, highly detailed, tattered strictly dark grey Napoleonic gear. Clean neutral studio background, single figure only, no text. |
| `cavalerie_atk` | Single character, broad-shouldered muscular anthropomorphic wolf mounted on a muscular horse, neutral riding pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a tattered, weathered, strictly dark grey Napoleonic uniform, holding a raised curved blade. Clean neutral studio background, single figure only, no text. |
| `cavalerie_mix` | Single character, average build anthropomorphic wolf mounted on a horse, neutral riding pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a tattered, weathered, strictly dark grey Napoleonic cavalry uniform. Clean neutral studio background, single figure only, no text. |
| `artillerie_basis` | Single prop, scavenged Napoleonic field cannon on a weathered dark wooden carriage, ropes and burlap sacks still tied around it. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, single object only, no text. |
| `artillerie_spd` | Single prop, light Napoleonic mountain cannon, disassemblable, on a small weathered dark wooden carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, single object only, no text. |
| `artillerie_hp` | Single prop, Napoleonic cannon behind an improvised barricade of crates and sandbags on a weathered dark wooden carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, single object only, no text. |
| `artillerie_atk` | Single prop, heavy scavenged Napoleonic cannon with extra powder kegs strapped to the weathered dark wooden carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, single object only, no text. |
| `artillerie_mix` | Single prop, scavenged Napoleonic field cannon on a patched weathered dark wooden carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, single object only, no text. |

### Vos (15 prompts)

**Belangrijk**: álle Vos-varianten dragen dezelfde donkergrijze cape — de bouw
verschilt, de look blijft verhullend (past bij de verborgen koppelingen).

| Bestand | Prompt |
|---|---|
| `infanterie_basis` | Single character, average build anthropomorphic fox, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic military uniform under a closed dark grey hooded cloak, only the muzzle visible, unarmed. Clean neutral studio background, single figure only, no text. |
| `infanterie_spd` | Single character, thin lean anthropomorphic fox, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic uniform under a tight dark grey hooded cloak. Clean neutral studio background, single figure only, no text. |
| `infanterie_hp` | Single character, heavyset thick-furred anthropomorphic fox, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic uniform with chainmail glinting under a dark grey hooded cloak. Clean neutral studio background, single figure only, no text. |
| `infanterie_atk` | Single character, broad-shouldered muscular anthropomorphic fox, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic uniform under a half-open dark grey hooded cloak revealing two daggers. Clean neutral studio background, single figure only, no text. |
| `infanterie_mix` | Single character, average build anthropomorphic fox soldier, A-pose. Gritty realistic AAA-game concept art, highly detailed. Wearing a weathered, strictly dark grey Napoleonic uniform with a dark grey cloak over one shoulder. Clean neutral studio background, single figure only, no text. |
| `cavalerie_basis` | Single character, average build anthropomorphic fox mounted on a standing horse, neutral riding pose, dark grey cloak draped over the back. Gritty realistic AAA-game concept art, highly detailed, weathered strictly dark grey Napoleonic uniform. Clean neutral studio background, single figure only, no text. |
| `cavalerie_spd` | Single character, thin lean anthropomorphic fox mounted low on a slender sighthound-like racing horse, neutral riding pose, dark grey cloak streaming behind. Gritty realistic AAA-game concept art, highly detailed, weathered strictly dark grey Napoleonic uniform. Clean neutral studio background, single figure only, no text. |
| `cavalerie_hp` | Single character, heavyset anthropomorphic fox mounted on a sturdy horse, horse and rider draped under one large dark grey caparison cloth, neutral riding pose. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, single figure only, no text. |
| `cavalerie_atk` | Single character, broad-shouldered muscular anthropomorphic fox mounted on a muscular horse, neutral riding pose, drawing a sabre from under a dark grey cloak. Gritty realistic AAA-game concept art, highly detailed, weathered strictly dark grey Napoleonic uniform. Clean neutral studio background, single figure only, no text. |
| `cavalerie_mix` | Single character, average build anthropomorphic fox mounted on a horse, neutral riding pose, dark grey hooded cloak. Gritty realistic AAA-game concept art, highly detailed, weathered strictly dark grey Napoleonic uniform. Clean neutral studio background, single figure only, no text. |
| `artillerie_basis` | Single prop, Napoleonic field cannon covered in dark grey camouflage netting, only the barrel protruding, on a weathered dark wooden carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, single object only, no text. |
| `artillerie_spd` | Single prop, light Napoleonic cannon half covered by a dark grey tarp, ready to move, on a weathered dark wooden carriage with thin wheels. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, single object only, no text. |
| `artillerie_hp` | Single prop, Napoleonic cannon in a dug-in emplacement with wicker gabion baskets, on a weathered dark wooden carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, single object only, no text. |
| `artillerie_atk` | Single prop, long-barreled Napoleonic cannon with dark grey camouflage netting pulled aside, on a weathered dark wooden carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, single object only, no text. |
| `artillerie_mix` | Single prop, Napoleonic field cannon with a folded dark grey tarp on the weathered dark wooden carriage. Gritty realistic AAA-game concept art, highly detailed. Clean neutral studio background, single object only, no text. |

---

## 4. De pipeline per karakter (Mixamo) + Model-tuner

1. **Genereer** het model (Laag Poly, target ~1.000) en download als `.glb`.
2. **Blender (alleen doorgeefluik)**: importeer de glb → File → Export → **FBX**
   met Path Mode **Copy** + het **embed-doosje** aan (texture zit dan ín de FBX).
3. **Upload naar Mixamo**: statisch model in **A- of T-pose, zónder botten** —
   Mixamo rigt zelf (markers op kin/polsen/ellebogen/knieën/kruis zetten).
4. **Download de clips** — FBX Binary, 30 fps, **With Skin**, en let op dat je
   éigen karakter de animatie voordoet in de viewer:

| Clip in het spel | Mixamo-zoekterm | Aantal |
|---|---|---|
| `idle` (+ `idle2`, `idle3`…) | Rifle Idle | 1-3 varianten |
| `walk` (+ `walk2`…) | Walk With Rifle — **"In Place" aanvinken!** | 1-3 varianten |
| `attack` | Firing Rifle (enkel schot, staand) | 1 |
| `melee` (+ `melee2`…) | Standing Melee Attack / Rifle Butt (kolfstoot) | 1-2 — ontbreekt hij, dan gebruikt melee de attack-clip |
| `die` (+ `die2`…) | Rifle Death / Death From The Front | 1-2 varianten |
| `aim` (voor later: aanleg-fase) | Rifle Down To Aim | optioneel |

5. **Laat alles in Downloads staan** en geef door welk bestand welk archetype
   is — het merge-script bouwt er één `.glb` van met alle clips (varianten
   worden in het spel willekeurig gekozen, met desync zodat de zwerm nooit
   synchroon beweegt).
6. **Model-tuner** (hoofdmenu → "Model-tuner"): kies factie/type/archetype,
   stel met de sliders **schaal en hoogte** af naast het referentiestuk,
   bekijk de clips met de knoppen, en klik **OPSLAAN** → schrijft
   `assets/models/model_tuning.json`, die het spel altijd toepast bovenop de
   auto-fit. (Dat bestand mee-committen.)

Cavalerie (ruiter te paard) kan Mixamo níét riggen — die pipeline volgt apart.

## 4b. Bestandsconventie & fallback

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
- **Animaties (optioneel)**: `AnimationPlayer` met clips `idle` / `walk` /
  `attack` / `die` wordt automatisch opgepakt (namen instelbaar op PawnView)
- Na het droppen éénmalig importeren: editor openen of
  `Godot --headless --path . --import`

## 6. Gratis bronnen (stijl past bij low-poly bord)

- **Quaternius** (quaternius.com) — CC0, complete animal packs + soldiers
- **Kenney** (kenney.nl) — CC0, animated characters
- **Sketchfab** — filter op CC0/CC-BY + "low poly", zoek per dier
- Zelf (laten) maken in Blender: exporteer als glTF 2.0 (.glb), Y-up staat goed

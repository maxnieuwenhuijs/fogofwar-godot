# 3D-model verlanglijst — karaktermodellen per factie

Het systeem zit in het spel (`PawnView.set_character`): drop een `.glb` op het
juiste pad en hij verschijnt vanzelf — geen code nodig. Elke pion toont:

1. **Ongekoppeld / opstelling** → het neutrale factie-model (`_basis`).
2. **Gekoppeld aan een kaart** → het archetype-model van de dominante stat.
   Muis-kaart 1 HP / 5 Speed / 1 Aanval → `muis/infanterie_spd.glb`
   (dunne, schichtige muis).
3. **Verborgen Vos-koppeling** → tegenstander blijft het neutrale model zien
   tot de kaart onthuld wordt (anders verraadt het model de kaart).

## Archetypes (dominante stat → look)

| Archetype | Wanneer | Look |
|---|---|---|
| `spd` | Speed strikt hoogste | dun, licht, schichtig, gestrekt |
| `hp` | HP strikt hoogste | fors, breed, gepantserd/dik |
| `atk` | Aanval strikt hoogste | bewapend, agressieve houding |
| `mix` | geen strikt hoogste (bv. 3/3/1) | standaard-uitvoering |
| `basis` | geen kaart gekoppeld | neutrale, rustige pose |

**Fallback-keten**: `<type>_<archetype>.glb` → `<type>_basis.glb` → geometrisch
stuk met archetype-silhouet (dun/breed/groot geschaald). Alles werkt dus ook
met maar één model per type — archetypes zijn verfijning, geen vereiste.

## Bestandsconventie

```
assets/models/<factie>/<type>_<archetype>.glb
```

- factie: `mens` `muis` `leeuw` `beer` `wolf` `vos` (kleine letters)
- type: `infanterie` `cavalerie` `artillerie`
- archetype: `basis` `spd` `hp` `atk` `mix`

Voorbeeld: `assets/models/muis/infanterie_spd.glb`

## Technische eisen per model

- **Formaat**: `.glb` (glTF-binair; mesh + materialen + evt. animaties in één bestand)
- **Low-poly**: < 5.000 tris (er staan 44 stukken op het bord)
- **Maat**: ~0,9 unit hoog (vakken zijn 1×1); cavalerie mag ~1,1
- **Origin**: voeten op y = 0, gecentreerd
- **Kijkrichting**: neus naar **−Z** (de voorkant die `face_dir()` draait)
- **Teamkleur**: hoeft niet in het model — het spel zet automatisch een
  rood/blauw sokkeltje onder elk `.glb`-model
- **Animaties (optioneel)**: `AnimationPlayer` met clips `idle` / `walk` /
  `attack` / `die` wordt automatisch opgepakt (namen instelbaar op PawnView)
- Na het droppen éénmalig importeren: editor openen of
  `Godot --headless --path . --import`

## Benodigde bestanden (✓ = aanwezig, prio 1 = `_basis` per type)

Composities: Mens 13/6/3 · Muis 22/0/0 · Leeuw 6/10/2 · Beer 16/3/3 ·
Wolf 11/8/3 · Vos 13/6/3 — de Muis heeft dus alleen infanterie nodig.

| Factie | Bestand | Prio | Idee |
|---|---|---|---|
| muis | `infanterie_basis.glb` | 1 | rustige muis, rechtop |
| muis | `infanterie_spd.glb` | 2 | dunne schichtige muis, laag/gestrekt |
| muis | `infanterie_hp.glb` | 2 | dikke mollige muis |
| muis | `infanterie_atk.glb` | 2 | muis met tandenstoker-speer/rapier |
| muis | `infanterie_mix.glb` | 3 | standaard muis-soldaat |
| mens | `infanterie_basis.glb` | 1 | musketier, geweer geschouderd |
| mens | `cavalerie_basis.glb` | 1 | ruiter te paard |
| mens | `artillerie_basis.glb` | 1 | kanon + kanonnier |
| mens | `infanterie_spd/hp/atk/mix.glb` | 2-3 | verkenner / grenadier / bajonet / linie |
| mens | `cavalerie_spd/hp/atk/mix.glb` | 2-3 | huzaar / kurassier / lansier / dragonder |
| mens | `artillerie_spd/hp/atk/mix.glb` | 2-3 | licht veldstuk / vestingstuk / houwitser / veldkanon |
| leeuw | `infanterie_basis.glb` + varianten | 1-3 | leeuwen-garde (majestueus, goud) |
| leeuw | `cavalerie_basis.glb` + varianten | 1-3 | zware leeuwen-ruiterij |
| leeuw | `artillerie_basis.glb` + varianten | 1-3 | groot belegeringskanon (dracht 7!) |
| beer | `infanterie_basis.glb` + varianten | 1-3 | brede berensoldaat (HP-bonus → stevig) |
| beer | `cavalerie_basis.glb` + varianten | 1-3 | logge maar zware beren-ruiterij |
| beer | `artillerie_basis.glb` + varianten | 1-3 | zwaar fort-kanon |
| wolf | `infanterie_basis.glb` + varianten | 1-3 | sluipende wolf, laag bij de grond |
| wolf | `cavalerie_basis.glb` + varianten | 1-3 | snelle roedel-ruiter (springt over infanterie) |
| wolf | `artillerie_basis.glb` + varianten | 1-3 | licht buit-kanon |
| vos | `infanterie_basis.glb` + varianten | 1-3 | vos met mantel (verborgen kaarten!) |
| vos | `cavalerie_basis.glb` + varianten | 1-3 | elegante snelle vossen-ruiter (+1 Speed) |
| vos | `artillerie_basis.glb` + varianten | 1-3 | gecamoufleerd kanon |

**Totaal**: 16 bestanden voor prio 1 (alles krijgt dan al een factie-eigen look),
64-80 voor de volledige set met archetypes. `mix` mag je overslaan (valt terug
op `basis`).

## Gratis bronnen (stijl past bij low-poly bord)

- **Quaternius** (quaternius.com) — CC0, complete animal packs + soldiers
- **Kenney** (kenney.nl) — CC0, animated characters
- **Sketchfab** — filter op CC0/CC-BY + "low poly", zoek per dier
- Zelf (laten) maken in Blender: exporteer als glTF 2.0 (.glb), Y-up staat goed

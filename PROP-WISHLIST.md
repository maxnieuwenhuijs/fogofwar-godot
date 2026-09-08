# Props-wishlist: het diorama om het bord

Verlanglijst van voorwerpen en poppetjes voor het landschap om het bord
(`scripts/game/omgeving.gd`). Hoort bij `prop-tracker.html`
(`python tools/bouw_prop_tracker.py`, paneelknop "Welke props ontbreken?"):
die leest deze lijst EN de mappen, dus een prop wordt groen zodra zijn glb er
ligt. Verzin hier niets bij zonder het ook in het spel te zetten: de tracker
laat zien wat het spel al procedureel neerzet (⚙), wat er als glb ligt (✓) en
wat nog gemaakt moet worden (➕).

**Twee kampen, twee werelden (Max, 8 september).** Het kamp vooraan is van
jou, de overkant van de tegenstander, en elk kamp draagt de kleur van zijn
team:

- **Rood = armoede.** Gelapt zeil, touw, ruw hout, roest, modder, stro,
  gebutst tin, alles net te klein en net te oud. Een leger dat leeft van wat
  het onderweg vindt.
- **Blauw = pompeus en rijk.** Blauw laken met goudgalon, verguld hout,
  zilver en kristal, wapenschilden, wimpels, tapijt op het gras. Een leger
  dat zijn kamp meeneemt als een salon.
- **Gedeeld** = geen team, staat er bij allebei (kampvuur, hek, plas).

## Naamgeving en maat

- Bestand: `assets/models/props/prop_<naam>.glb`. Team-variant:
  `prop_<naam>_red.glb` en `prop_<naam>_blue.glb` (dan pakt het spel voor elk
  kamp de eigen kleur; is er maar een gedeelde, dan die). Het spel zoekt op
  bestandsnaam, submappen mogen.
- Maat: **ware grootte in bordeenheden**, een tegel is 1, een pion staat
  0,62 hoog. Tent 1,0 hoog, ton 0,55, wagen 1,0, fakkel 0,8, kist 0,25. Een
  `prop_<naam>.json` naast de glb mag `hoogte` (dan schaalt het spel hem
  daarop), `draai` en `y` geven. Statisch, laagpoly (300-1.500 tris),
  textuur ingebakken, 512 tot 1024 px.
- Poppetjes (bewoners) horen NIET hier maar in `assets/models/bewoners/`
  (zie de LEESMIJ daar): die hebben clips en een factiewoord in hun naam;
  een teamwoord (`_red`/`_blue`) mag erbij voor de arm/rijk-variant.
- Elke prop is klikbaar in het spel: zonder eigen reactie krijgt een glb een
  wiebel plus het geluid uit de kolom Klik (zie SOUND-WISHLIST sectie 11).

**Legenda status:** ✓ = glb ligt er · ⚙ = het spel bouwt hem nu nog uit
primitieven (placeholder) · ➕ = nog maken. De tracker vult dit zelf in; de
kolom hier is de stand van 8 september.

**Prompt-recept (Tripo/Meshy, text-to-3D):** `low-poly game prop, 18th century
military camp, <wat>, <teamstijl>, single object, clean silhouette, baked
albedo texture, no ground plane, no text`. Teamstijl rood: `worn, patched,
poor, rope and rough wood, rust and mud`. Blauw: `ornate, gilded, blue cloth
with gold trim, polished, wealthy`.

---

## 1. Kampvuur en koken (gedeeld, met arm/rijk waar het uitmaakt)

| Bestand | Wat | Team | Klik | Status | Prompt |
|---|---|---|---|---|---|
| `prop_kampvuur` | kampvuur: stenenring, houtblokken, gloeiende as (vlammen doet het spel) | gedeeld | laait op, `prop_vuur` | ⚙ | stone ring campfire with charred logs and embers |
| `prop_kookpot` | ijzeren kookpot aan een driepoot boven het vuur | gedeeld | deksel klappert, `prop_kookpot` | ➕ | iron cooking pot hanging from a wooden tripod |
| `prop_spit` | spit met een gebraad (rood: een schrale haas; blauw: een heel zwijn) | beide | draait een slag, `prop_spit` | ➕ | roasting spit over a fire with meat |
| `prop_houtstapel` | stapel gehakt hout | gedeeld | een blok rolt eraf, `prop_hout` | ⚙ | stack of split firewood logs |
| `prop_takkenbos` | bos sprokkelhout met touw erom | rood | wiebelt | ➕ | bundle of sticks tied with rope |
| `prop_blaasbalg` | leren blaasbalg | gedeeld | pompt, `prop_blaasbalg` | ➕ | leather bellows |
| `prop_ketel` | koperen waterketel (blauw: gepoetst) | beide | fluit, `prop_ketel` | ➕ | copper kettle |
| `prop_kom` | houten kom met lepel (blauw: tinnen bord) | beide | wiebelt | ➕ | wooden bowl with a spoon |
| `prop_broodmand` | mand met brood (rood: een half brood) | beide | wiebelt | ➕ | wicker basket with bread |
| `prop_kruik` | aardewerken kruik (blauw: glazen karaf) | beide | klokt, `prop_kruik` | ➕ | clay jug |

## 2. Tent en slapen

| Bestand | Wat | Team | Klik | Status | Prompt |
|---|---|---|---|---|---|
| `prop_tent` | soldatentent: rood gelapt zeil met touwen, blauw paviljoen met goudgalon en wimpel | beide | lantaarn zwaait / doek trilt, `prop_lantaarn` | ⚙ | canvas ridge tent |
| `prop_paviljoen` | het grote officierspaviljoen, rond, blauw met gouden punt | blauw | wimpel wappert | ➕ | round officer pavilion tent with gold finial |
| `prop_veldbed` | veldbed (rood: strozak op de grond) | beide | deken beweegt | ➕ | folding camp bed with blanket |
| `prop_kist` | kist: rood kapot en gebonden, blauw met koperbeslag | beide | deksel wipt, `prop_kist` | ⚙ | wooden campaign chest |
| `prop_lantaarn` | olielantaarn aan een stok | gedeeld | zwaait, `prop_lantaarn` | ⚙ | oil lantern on a pole |
| `prop_fakkel` | fakkel in een standaard (vlam doet het spel) | gedeeld | vlamt op, `prop_vuur` | ➕ | wooden torch in an iron stand |
| `prop_kandelaar` | zilveren kandelaar met drie kaarsen | blauw | flakkert | ➕ | silver candelabra with three candles |
| `prop_pole` | vlaggenmast: de kale stok (het doek maakt het spel er zelf aan, in teamkleur) | gedeeld | wappert harder | ✓ | wooden flag pole |
| `prop_waslijn` | waslijn tussen twee stokken met vodden (rood) of hemden (blauw) | beide | wappert | ➕ | clothesline with hanging laundry |
| `prop_tapijt` | oosters tapijt op het gras voor de tent | blauw | geen | ➕ | ornate oriental rug |

## 3. Hout en ambacht

| Bestand | Wat | Team | Klik | Status | Prompt |
|---|---|---|---|---|---|
| `prop_hakblok` | hakblok: dikke stronk met een kerf | gedeeld | trilt, `prop_bijl` | ⚙ | tree stump chopping block |
| `prop_houtblok` | een los stuk hout, gekliefd | gedeeld | rolt, `prop_hout` | ➕ | split log of firewood |
| `prop_axe` | bijl (ligt in het spel op de stronk) | gedeeld | trilt, `prop_bijl` | ✓ | woodcutter axe |
| `prop_zaag` | trekzaag tegen een blok | gedeeld | zoemt, `prop_zaag` | ➕ | two-man crosscut saw |
| `prop_aambeeld` | aambeeld op een blok met hamer | gedeeld | klinkt, `prop_aambeeld` | ➕ | anvil on a wooden block with a hammer |
| `prop_werkbank` | werkbank met gereedschap | gedeeld | gereedschap rammelt | ➕ | wooden workbench with tools |
| `prop_barrel` | ton (rood: met hoepels los; blauw: wijnvat met wapen) | beide | wiebelt, `prop_ton` | ✓ | wooden barrel |
| `prop_emmer` | houten emmer (blauw: koperen emmer) | beide | klotst, `prop_emmer` | ➕ | wooden bucket |
| `prop_waterput` | put met katrol en emmer | gedeeld | katrol piept | ➕ | stone well with pulley |
| `prop_touwrol` | rol touw | gedeeld | wiebelt | ➕ | coil of rope |

## 4. Wagen en vervoer

| Bestand | Wat | Team | Klik | Status | Prompt |
|---|---|---|---|---|---|
| `prop_wagen` | huifkar: rood met gescheurde huif en scheef wiel, blauw een koets met wapen op de deur | beide | wiel draait, `prop_wagen` | ➕ | covered supply wagon |
| `prop_wiel` | los wagenwiel tegen een boom | gedeeld | rolt weg, `prop_wiel` | ➕ | wooden spoked wagon wheel |
| `prop_juk` | ossenjuk op de grond | rood | wiebelt | ➕ | wooden ox yoke |
| `prop_tuig` | paardentuig aan een paal (blauw: met zilverbeslag) | beide | rinkelt, `prop_tuig` | ➕ | horse harness hanging on a post |
| `prop_kruiwagen` | kruiwagen met zakken | rood | wipt | ➕ | wooden wheelbarrow with sacks |
| `prop_zadelbok` | zadel op een bok (blauw: verguld zadel) | beide | wiebelt | ➕ | saddle on a wooden stand |
| `prop_hooiwagen` | wagen vol hooi | rood | hooi valt | ➕ | cart full of hay |
| `prop_lafuit` | leeg kanonaffuit | gedeeld | wiebelt | ➕ | wooden cannon carriage without barrel |
| `prop_munitiekar` | munitiekar met kisten | gedeeld | deksel wipt | ➕ | ammunition cart with crates |
| `prop_slee` | sleepslede voor zware lasten | rood | schuift | ➕ | wooden sledge for hauling loads |

## 5. Wapens en uitrusting

| Bestand | Wat | Team | Klik | Status | Prompt |
|---|---|---|---|---|---|
| `prop_musketrek` | drie musketten in een piramide (rotten) | gedeeld | valt om, `prop_musketrek` | ➕ | three muskets stacked in a pyramid |
| `prop_kogels` | stapel kanonskogels | gedeeld | bovenste rolt eraf, `prop_kogel` | ⚙ | pyramid of iron cannonballs |
| `prop_kruitvat` | kruitvat met lont | gedeeld | lont sist, `prop_kruit` | ➕ | gunpowder keg with a fuse |
| `prop_kanon` | veldkanon op affuit (aan de overkant) | gedeeld | wiel draait | ➕ | small field cannon on carriage |
| `prop_mace` | knots of sabel (ligt in het spel bij de tent) | gedeeld | wiebelt | ✓ | mace |
| `prop_drum` | trommel | gedeeld | stuitert, `prop_trom` | ✓ | military snare drum |
| `prop_horn` | hoorn | gedeeld | wipt, `prop_hoorn` | ✓ | brass signal horn |
| `prop_bajonet` | bajonet in een blok | gedeeld | trilt | ➕ | bayonet stuck in a wooden block |
| `prop_patroontas` | patroontas aan een haak | gedeeld | zwaait | ➕ | leather cartridge pouch |
| `prop_sjako` | sjako op een stok (rood gedeukt, blauw met pluim) | beide | wiebelt | ➕ | shako hat on a stick |
| `prop_schild` | wapenschild op een standaard | blauw | wiebelt | ➕ | heraldic shield on a stand |
| `prop_vaandel` | opgerold vaandel tegen een kist | beide | rolt uit | ➕ | rolled regimental banner |

## 6. Eten en drinken

| Bestand | Wat | Team | Klik | Status | Prompt |
|---|---|---|---|---|---|
| `prop_bierton` | bierton met tap (rood) | rood | klokt, `prop_kruik` | ➕ | beer barrel with a tap |
| `prop_wijnvat` | wijnvat met wapen (blauw) | blauw | klokt, `prop_kruik` | ➕ | wine cask with heraldic crest |
| `prop_kaarttafel` | tafel met een landkaart en kandelaar (blauw) of een omgekeerde kist met kaart (rood) | beide | kaart wappert | ➕ | table with a map and candles |
| `prop_kruk` | krukje (blauw: gestoffeerde stoel) | beide | wipt | ➕ | three-legged wooden stool |
| `prop_appelkist` | kist appels | gedeeld | appel rolt | ➕ | crate of apples |
| `prop_kaas` | kaas op een plank | gedeeld | wiebelt | ➕ | wheel of cheese on a board |
| `prop_worst` | worsten aan een haak | gedeeld | zwaait | ➕ | sausages hanging from a hook |
| `prop_beker` | tinnen bekers (rood) of zilveren bokaal (blauw) | beide | wiebelt | ➕ | pewter cups |

## 7. Rijk: het blauwe kamp

| Bestand | Wat | Team | Klik | Status | Prompt |
|---|---|---|---|---|---|
| `prop_troon` | veldtroon met verguld snijwerk | blauw | wiebelt | ➕ | ornate gilded camp chair |
| `prop_kroonluchter` | kroonluchter aan een driepoot boven de tafel | blauw | flakkert | ➕ | crystal chandelier on a tripod |
| `prop_spiegel` | staande spiegel in gouden lijst | blauw | glimt | ➕ | standing mirror in gilded frame |
| `prop_schildersezel` | ezel met een portret van de generaal | blauw | doek wipt | ➕ | painter easel with a portrait |
| `prop_sieradenkist` | open kist met munten en juwelen | blauw | glinstert, `prop_munten` | ➕ | open treasure chest with coins |
| `prop_buste` | marmeren buste op een zuil | blauw | wiebelt | ➕ | marble bust on a pedestal |
| `prop_vergulde_kist` | vergulde kist met wapen | blauw | deksel wipt, `prop_kist` | ➕ | gilded chest with coat of arms |
| `prop_wijnrek` | rek met flessen | blauw | rinkelt | ➕ | wine bottle rack |
| `prop_theeservies` | porseleinen theeservies op een blad | blauw | rinkelt | ➕ | porcelain tea set on a tray |
| `prop_globe` | globe op een standaard | blauw | draait | ➕ | antique globe on a stand |
| `prop_pauw` | pauw (bewoner-achtig, maar statisch mag) | blauw | spreidt | ➕ | peacock |
| `prop_windhond` | liggende windhond met halsband | blauw | tilt kop | ➕ | resting greyhound with a collar |

## 8. Arm: het rode kamp

| Bestand | Wat | Team | Klik | Status | Prompt |
|---|---|---|---|---|---|
| `prop_vogelverschrikker` | vogelverschrikker met een gedeukte hoed | rood | wiebelt, kraai vliegt op | ➕ | scarecrow with a battered hat |
| `prop_kapotte_kar` | kar zonder wiel, scheef | rood | kraakt, `prop_wagen` | ➕ | broken cart missing a wheel |
| `prop_wasteil` | houten wasteil met wasbord | rood | klotst | ➕ | wooden washtub with washboard |
| `prop_hooiberg` | kleine hooiberg | rood | wiebelt | ➕ | small haystack |
| `prop_geit` | geit aan een touw | rood | mekkert, `prop_geit` | ➕ | tethered goat |
| `prop_kip` | kip (bewoner-achtig; statisch mag) | rood | fladdert, `prop_kip` | ➕ | chicken |
| `prop_gebroken_wiel` | gebroken wiel tegen een paal | rood | valt om | ➕ | broken wagon wheel leaning on a post |
| `prop_voddenlijn` | lijn met vodden en een gat in de sok | rood | wappert | ➕ | clothesline with ragged clothes |
| `prop_modderpoel` | modderpoel met een laars erin | rood | plons | ➕ | mud puddle with a boot stuck in it |
| `prop_houten_kruis` | houten kruis met een hoed erop (een gevallen kameraad) | rood | geen | ➕ | wooden grave cross with a hat |
| `prop_uitgebrand_vuur` | uitgebrande vuurplek, koud | rood | stof waait op | ➕ | cold burnt-out campfire |
| `prop_voerbak` | voerbak voor het paard, leeg | rood | wiebelt | ➕ | empty wooden feed trough |

## 9. Land en overkant (gedeeld)

| Bestand | Wat | Team | Klik | Status | Prompt |
|---|---|---|---|---|---|
| `prop_hek` | hek van palen en twee latten | gedeeld | kraai op de paal | ⚙ | rustic post and rail fence |
| `prop_wegwijzer` | wegwijzer met twee planken | gedeeld | wiebelt, `prop_wegwijzer` | ⚙ | wooden signpost with two arrows |
| `prop_plas` | plas met een kikker | gedeeld | kikker springt | ⚙ | small puddle |
| `prop_muurtje` | stenen muurtje, half ingestort | gedeeld | steen valt | ➕ | low dry-stone wall partly collapsed |
| `prop_stronk` | boomstronk met paddenstoelen | gedeeld | paddenstoel wipt | ➕ | tree stump with mushrooms |
| `prop_struik` | struik | gedeeld | ritselt | ➕ | low bush |
| `prop_boom` | kleine kale boom | gedeeld | kraai vliegt op | ➕ | small bare tree |
| `prop_grafheuvel` | grafheuvel met een steen | gedeeld | geen | ➕ | burial mound with a standing stone |
| `prop_mijlpaal` | mijlpaal met cijfer | gedeeld | wiebelt | ➕ | stone milestone |
| `prop_molensteen` | molensteen tegen een paal | gedeeld | rolt | ➕ | millstone leaning on a post |
| `prop_rots` | rotsblok met mos | gedeeld | geen | ➕ | mossy boulder |
| `prop_bloemen` | pol veldbloemen | gedeeld | vlinder | ➕ | tuft of wildflowers |

## 10. Bewoners (poppetjes, `assets/models/bewoners/`)

Per factie en per team, rood arm en blauw rijk. Naam: `<rol>_<factie>_<team>`,
bijvoorbeeld `peasant_mouse_red`. Clips: minstens een idle en een actie.

| Bestand | Wat | Team | Klik (actie-clip) | Status |
|---|---|---|---|---|
| `peasant_<factie>` | boer met bijl bij het hakblok (rood in lompen, blauw als lakei met bijl) | beide | hakt hout, `bewoner_hakken` | ➕ |
| `kok_<factie>` | kok bij de kookpot | beide | roert, proeft, `bewoner_roeren` | ➕ |
| `trommelaar_<factie>` | trommelaar bij de tent | beide | roffelt, `prop_trom` | ➕ |
| `schildwacht_<factie>` | schildwacht met musket | beide | salueert, `bewoner_salueren` | ➕ |
| `smid_<factie>` | smid bij het aambeeld | beide | hamert, `prop_aambeeld` | ➕ |
| `slaper_<factie>` | slapende soldaat tegen een ton | beide | schrikt wakker, `bewoner_snurken` | ➕ |
| `marketentster_<factie>` | marketentster met vaatje | beide | schenkt, `prop_kruik` | ➕ |
| `soldaat_mouse` | de muis-infanterist die oefent (voorbeeld, hergebruikt het pionmodel) | gedeeld | rifle butt, bajonet, `bewoner_oefenen` | ✓ |
| `hond` | kamphond (rood: magere straathond, blauw: windhond) | beide | blaft, `bewoner_hond` | ➕ |
| `kip` | kip die scharrelt | rood | fladdert, `prop_kip` | ➕ |
| `kraai` | de kraai op het hek | gedeeld | vliegt weg en komt terug, `prop_kraai` | ⚙ |
| `kikker` | de kikker in de plas | gedeeld | springt over, `prop_kikker` | ⚙ |
| `rat` | rat bij de voorraad | rood | schiet weg | ➕ |
| `kat` | kat op de kist | blauw | rekt zich uit | ➕ |

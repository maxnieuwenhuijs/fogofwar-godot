# VFX-studio: alle effecten samen bouwen en bijstellen

6 oktober 2026. Max: "hoe kan ik die rook particles of stof opwaai particles en
vfx het beste met jou gaan bouwen, kan jij voor mij ook een studio maken voor
allemaal wensen en vfx effecten zoals bloed, stof, vuurmonden, vuur, alle
soorten eigenlijk", en: "met plaatjes als concept, een prompt box, en dan met
Seedance 2.5 een filmpje maken op basis van het concept, en dat dan maken?"

Besluiten van Max (6 oktober): een Replicate-sleutel komt in
`%LOCALAPPDATA%\FogOfWar\replicate.key`; alle vier de groepen (kruitdamp en
vuurmond, stof en aarde, bloed en inslag, vuur en explosies); eerst de tuner in
Godot, daarna de concept-webpagina.

## De werkwijze per effect

1. **Wens of concept.** Max zet een wens in `VFX-WISHLIST.md` of maakt in de
   concept-webpagina een plaatje (promptvak) en daarvan een filmpje (Seedance
   2.5, plaatje naar video) en kiest "dit is hem". Het filmpje is de AFSPRAAK
   over hoe het eruitziet: een effect in het spel is kort, doorzichtig, van
   bovenaf, herhaalbaar en licht genoeg voor een telefoon; een AI-clip heeft
   een camera, een achtergrond en perspectief.
2. **Bouwen.** Uit drie dingen: deeltjes (stof, vonken, druppels, splinters),
   shaders (vuur, flits, gloed, hitte) en flipbooks (een vel beeldjes van een
   rookwolk of steekvlam; het mooist uit een rook- of vuursimulatie in Blender,
   recht van boven gerenderd; een clip op puur zwart kan soms ook). Elk effect
   krijgt knoppen in `assets/models/effects_tuning.json`.
3. **Bijstellen.** In de VFX-tuner op het echte bord, in het licht van het spel,
   met slowmo en herhalen. Opslaan schrijft de knoppen weg.
4. **In het spel.** Checks: geen fouten, alles ruimt zichzelf op, nooit de
   globale RNG in nieuwe effectcode, telefoonbudget (zie onder).

## Stappen

1. **Fundament: catalogus en VFX-tuner.**
   - `scripts/vfx/vfx.gd` (via preload): de schot-keten (kogel of kanonskogel,
     vuurmond met lichtflits, kruitdamp aan de loop, inslagrook), vonken en het
     schadegetal, uit game.gd gehaald zodat spel en tuner dezelfde code
     afspelen (game.gd houdt dunne doorgeefluiken; puur verplaatst, dezelfde
     trekjes uit de rng in dezelfde volgorde).
   - `scripts/vfx/vfx_catalogus.gd`: elk effect, bestaand en gewenst (id,
     groep, naam, wanneer, knoppen, status), plus de metadata van elke knop
     (label, bereik, standaard) op een plek.
   - `scenes/tools/VfxTuner.tscn` + `scripts/tools/vfx_tuner.gd`: links de
     effecten per groep, in het midden het bord met een schutter en een doel,
     rechts de knoppen van het gekozen effect; Speel, Herhaal, Slowmo, Donker,
     Opslaan. Paneelknop "VFX-tuner".
   - `-- vfxcheck` (elk effect uit de catalogus speelt, maakt iets, ruimt op,
     geen fouten) en `-- vfxshot <id> [map]` (plaatjes, ook voor de webpagina).
   - `VFX-WISHLIST.md`: de lijst voor Max.
2. **Kruitdamp en vuurmond.** De fout dat een musket soms de kanonvlam toont
   en de kruitdamp soms het witte koppelwolkje (de textuur werd willekeurig uit
   de map gekozen); rook die met de wind van het potje meedrijft; een rookring
   en een grote pluim bij het kanon; de kruitflits op de pan vlak voor het
   schot; gloeiende propjes uit de loop.
3. **Stof en aarde.** Stof bij de landing van een charge en achter
   galopperende ruiters; bij een kanonsinslag opspattende aarde en een krater
   of schroeiplek op het bord die later vervaagt.
4. **Bloed en inslag.** Een inslag per materiaal (vlees, hout, metaal; dezelfde
   indeling als het geluid, `PawnView.impact_categorie`) in plaats van overal
   dezelfde gele vonken; meer variatie in het bloed.
5. **Vuur en explosies.** Een kanon dat kapotgaat (splinters, rookkolom, een
   klein vuur dat even blijft branden), een ontploffend kruitvat, vuur op het
   bord.
6. **Stijl: shaders voor alle 3D-objecten** (Max, 6 oktober: "kan je ook iets
   met shaders doen voor alle 3d objecten", en bij de keuze welke looks: "een
   studio om het allemaal uit te proberen, in moddif zien de modellen er mooier
   uit"; eerst de effecten, dan dit). Een groep "Stijl" in de VFX-tuner waarin
   elke look een aan/uit en schuifjes heeft: over het hele beeld inktranden
   (gravure, zoals de emblemen), miniatuur-scherpte (tilt-shift), kleurgrading
   en korrel; per materiaal randlicht en cel-shading (op de plek waar pionnen,
   props en het bord geladen worden, niets per model); en lichtstanden (het
   spel, neutraal zoals de Model-tuner). Telefoonkosten meten.
7. **Concept-webpagina** (`tools/vfx_studio.py`, zoals de geluid-studio): per
   effect uit de catalogus een rij met waar en wanneer, status, promptvak,
   concept-plaatjes (een beeldmodel op Replicate), "maak filmpje" (Seedance
   2.5), "dit is hem", notities, en ernaast de huidige versie uit het spel
   (`-- vfxshot`). Plaatjes en filmpjes in `assets/vfx/referentie/<id>/` met
   een `.gdignore`. Elk filmpje kost geld op Max zijn Replicate-account: de
   pagina doet niets vanzelf.

## Huisregels

- Effecten zijn puur beeld: nooit spelstaat, nooit `_animaties_bezig`.
- Nieuwe effectcode trekt NOOIT uit de globale RNG (`randf`, `randi`) maar uit
  een eigen `RandomNumberGenerator`; de bestaande code doet dat nog wel en
  wordt pas omgezet als uispel bewijst dat het niets verschuift.
- Telefoonbudget: hooguit ~40 losse deeltjes per effect, flipbooks tot 1024 px
  (VRAM-compressie, mipmaps), geen schaduwen op deeltjes, alles ruimt zichzelf
  op (de check telt de nodes onder het bord voor en na).
- Elke knop staat in de catalogus met label, bereik en standaard; de code
  leest hem met `PawnView.fx(sleutel, standaard)`.

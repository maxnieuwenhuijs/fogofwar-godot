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
   elke look een schuif heeft. **Gebouwd (6 oktober):** alles als EEN shader
   over het camerabeeld (`scripts/vfx/stijl.gd`), dus niets per model of per
   materiaal: inktranden (gravure, zoals de emblemen; uit diepte- en
   kleursprongen), randlicht (de binnenkant van elk silhouet, uit de diepte),
   miniatuur-scherpte (tilt-shift), kleurstemming, korrel en kleurtrappen
   (cel). Het vlak tekent als eerste van de doorzichtige laag, zodat de
   effecten er scherp overheen komen. Alles uit = het vlak onzichtbaar, geen
   kosten; aan = een schermvullende pass met tot een stuk of twintig
   textuur-lezingen per pixel, nog niet op een telefoon gemeten. Open: de
   lichtstand "neutraal zoals de Model-tuner" (wacht op wat Max met "moddif"
   bedoelt). **Later die dag** (Max: "de tilt shift zie ik niet echt"): de
   looks staan ook in het sfeer-paneel van het spel (rijen "stijl: ...", live
   op het echte spelbeeld), en de miniatuur rekent zijn scherpe band in het
   spelbeeld: in de tuner het stuk tussen de panelen (daarvoor viel de vage
   rand erachter en zag je bijna niets), in het spel het hele scherm.
7. **Concept-webpagina** (`tools/vfx_studio.py`, zoals de geluid-studio; Max:
   "Webpagina, zoals de geluid-studio: elk effect is een rij. Er staat in waar
   en wanneer het gebeurt, met een promptvak voor concept-plaatjes, een knop
   'maak filmpje' (Seedance), een knop 'dit is hem' en notities. Daarnaast
   staat de huidige versie uit het spel."). **Gebouwd (6 oktober):**
   - Rijen: de catalogus (rechtstreeks uit `vfx_catalogus.gd` gelezen, de
     constanten uitgerekend) plus de wishlist (concept-prompt, wens); een
     wens die alleen in de wishlist staat komt er ook bij, en "nieuwe wens"
     zet er een regel in.
   - In het spel nu: `-- vfxstudio <map> [id]` (met venster) speelt elk
     effect in de VFX-tuner af en bewaart alleen het bord tussen de panelen:
     een rustbeeld en 20 beelden op gelijke afstanden (tempo 0,5), de studio
     maakt er een bewegend webp van. Een look die nog uit staat neemt hij op
     in de `demo`-stand uit de catalogus. Knop "Spelbeelden maken" of per rij.
   - Concepten via Replicate: plaatjes met Nano Banana 2 (standaard; ook Pro
     en Seedream), met of zonder basis (een spelbeeld of een eerder plaatje,
     "verder hierop"); filmpjes met Seedance 2.5, het plaatje of het
     spelbeeld als eerste beeld (`image`, beeldverhouding `adaptive`), 5 s op
     480p zonder geluid als standaard. De studio leest de invoer van een model
     uit zijn schema bij Replicate (anders de lijst in het script), zet een
     vaste zin achter elk filmpje (camera stil, effect een keer) en voor een
     plaatje op een basis, allebei aan te passen onder "zinnen".
   - Opdrachten lopen in een eigen thread; de pagina vraagt de stand op. Een
     opdracht die nog liep als de studio dichtging, haalt hij bij de volgende
     start op (al betaald). Wat Replicate maakt staat in
     `results/vfx_studio/concept/<id>/` tot je het weggooit.
   - "Dit is hem" kopieert naar `assets/vfx/referentie/<id>/beeld.*` en
     `film.mp4`; prompts, notities, keuzes, "zo is hij goed" en de
     instellingen staan in `assets/vfx/referentie/studio.json` (in git; de
     map heeft een `.gdignore`).
   - Kosten (indicatie, 6 oktober): een plaatje een paar cent (Nano Banana
     Pro rond $0,13), Seedance 2.5
     ongeveer $0,10-0,14 per seconde op 480p en $0,23-0,30 op 720p. Een
     filmpje vraagt eerst om bevestiging met de geschatte prijs.
   - Checks: `python tools/vfx_studio.py --proef` (de hele keten tegen een
     nep-Replicate op deze machine, kost niets: sleutel, plaatje met en
     zonder basis, filmpje, dit is hem, weg, geen tegoed, stoppen, hervatten,
     nieuwe wens, de webserver) en `--overzicht` (de telling).
8. **Texturen en decals aanleveren** (Max, 6 oktober: "hoe kan ik dan de VFX
   maken of aanpassen dat de details kunnen importeren zoals de plaatjes png;
   het doel is om met de studio ook de textures en alle decals die nodig zijn
   aan te leveren, en voor Claude te zien wat er gebeurt en dat te animeren in
   Blender of in game"). **Gebouwd (6 oktober):**
   - `ONDERDELEN` in de catalogus: per textuur of decal de map onder
     `assets/textures/`, de naam die het spel zoekt, de soort ("flipbook" =
     een vel met het rooster in de naam, het spel pakt het eerste bestand dat
     de naam bevat; "varianten" = alle bestanden die ermee beginnen, het spel
     kiest er een; "vast" = precies die naam), de achtergrond ("zwart" wordt
     bij het laden doorzichtig, "alpha" = een PNG met doorzichtigheid), of het
     spel er al naar kijkt, en een beginprompt voor een plaatje en een
     filmpje. Elk effect noemt zijn onderdelen. Dertien: kruitdamp, witte
     pof, vuurmond musket, vuurmond kanon, bloedspetters, bloedplas,
     bloednevel, voetstap links en rechts, wielspoor, en nog zonder code
     krater, stof en vlammen op het bord (die bouw ik om zodra er een
     textuur is).
   - In de studio een groep "Texturen en decals": per onderdeel wat er nu in
     het spel staat (op ruitjes, een vel speelt zijn beeldjes af, zwart
     doorzichtig zoals het spel het laadt), en de kandidaten: zelf erin
     slepen (png, jpg, webp, gif, mp4; een `_4x4` in de bestandsnaam wordt
     het rooster), een plaatje of filmpje laten maken (vierkant; het filmpje
     van alleen het onderdeel op zwart), een flipbook knippen uit een
     filmpje (van het onderdeel of van een effect dat het gebruikt: van, tot,
     rooster, maat per beeldje, inzoomen; OpenCV), de achtergrond weghalen
     (zwart, wit of groen wordt doorzichtig), het rooster opgeven, en "in het
     spel": de juiste naam in de juiste map, hooguit 1024 px, wat er stond
     naar `results/vfx_studio/backup/<map>/`. Een decal zonder
     doorzichtigheid wordt geweigerd. Daarna importeert Godot hem: de editor
     zelf als die openstaat, anders de knop "Importeer in Godot" (die weigert
     als de editor openstaat). Bij elk effect kun je ook zelf een plaatje of
     filmpje als concept erin slepen.
   - Een reeks, frame voor frame (Max: "1 ontploffing kan wel 12 plaatjes
     tellen; kies een vast getal en dan per frame een prompt en een
     plaatje"): per onderdeel kies je 4, 6, 8, 9, 12 of 16 frames (rooster
     2x2 tot 4x4), een onderwerp-prompt voor alle frames en per frame een
     fase-prompt (voorgevuld van "net ontstaan" via "op zijn grootst" tot
     "het laatste spoor"). De frames worden na elkaar gemaakt, elk met het
     vorige frame als basis en een vaste zin dat kader, midden, maat en
     stijl gelijk blijven; frame 1 komt uit de tekst (of je zet een eigen
     plaatje of kandidaat op een frame). Per frame opnieuw maken, versies
     doorbladeren, stoppen; een speler laat de frames na elkaar zien; "leg in
     een vel" maakt er een kandidaat met het rooster van, en die gaat met "in
     het spel" onder de goede naam het spel in. Een reeks staat in
     `studio.json` (`reeksen`); zijn frames zijn opdrachten met `reeks_frame`
     en staan niet tussen de gewone kandidaten.
   - Meekijken: van elk filmpje (van Replicate, eigen upload, en bij "dit is
     hem" ook in de referentiemap als `film_vel.jpg`) maakt de studio een
     contactvel van 12 beelden met de tijd erbij. Een plaatje kan Claude
     lezen, een filmpje niet: zo ziet hij wat er gebeurt, en bouwt hij het in
     Godot (deeltjes, shaders, de texturen) of in Blender (een simulatie van
     bovenaf, gerenderd naar een flipbook dat via dezelfde groep het spel
     ingaat).
   - Checks: `--proef` met de onderdelen erbij (op een kopie van
     `assets/textures`: upload, flipbook uit een echt testfilmpje, achtergrond
     weg, in het spel met backup, variant erbij en vervangen, weigeren zonder
     doorzichtigheid, vierkant voor een onderdeel, contactvel) en `--overzicht`
     (welke onderdelen een bestand hebben); `-- vfxcheck` controleert de
     onderdelen in de catalogus.

9. **De geleverde texturen in het spel** (Max, 6 oktober: "voeg toe behalve
   de musketshot"; hij had in de studio drie kraters, een stofwolk, een vlam
   en een wielspoor in het spel gezet, en daarna zelf een witte pof als vel
   en een bloednevel-reeks). **Gebouwd (6 oktober):**
   - `VFX._geleverde`: een lader voor alles wat de studio levert, met de eigen
     rng; maakt elk bestand een keer klaar (maat, rooster, bijsnijden, zwart
     doorzichtig, mipmaps).
   - Krater uit `decals/`, stof uit `dust/` (groter en zachter dan het plaatje,
     anders lijken het stickertjes), vlammen op het bord uit `flame/` met een
     eigen shader die golft en flakkert, het wielspoor bijgesneden tot de
     strook. Zonder bestanden doet alles wat het daarvoor deed.
   - De bloednevel speelt een vel af (de reeks van Max: `blood_mist1_4x3.png`,
     hernoemd; de studio zet het rooster voortaan zelf in de naam).
   - De kruitdamp van het musketschot bleef bewust ongemoeid.

10. **Prompts met AI en texturen weer uit het spel** (Max, 7 oktober: "geef me
    in de vfx studio wel de mogelijkheid om prompts te enhancen met ai of te
    maken dat ik beschrijf wat ik wil en dat de ai een prompt genereert en ook
    dat ik decals of plaatjes kan verwijderen weer die in gebruik zijn").
    **Gebouwd (7 oktober):**
    - Onder elk promptvak (effect, textuur en het onderwerp van een reeks) een
      regel: een vak "beschrijf in gewone taal wat je wilt zien", bij een
      effect en een textuur met een filmprompt de keuze voor een plaatje of
      voor een filmpje, en twee knoppen. **AI: maak prompt** (of Enter in het
      vak) schrijft een Engelse prompt uit je beschrijving; **AI: verbeter**
      verbetert wat er in het vak staat (leeg vak = de prompt uit de wishlist
      of de catalogus) en neemt je beschrijving mee. De nieuwe prompt komt in
      het vak en wordt bewaard; **vorige** zet de oude terug.
    - Claude krijgt mee wat de studio weet: het spel en de stijl (vaste
      systeemtekst `PROMPT_SYSTEEM`), het doel (effect-concept of textuur,
      plaatje, filmpje of reeks), naam, wanneer, de notities, de
      standaardprompt, bij een textuur de achtergrondregel (puur zwart wordt
      doorzichtig, of een vlakke kleur om weg te halen) en of het een vel of
      een variant is, en een plaatje: het gekozen spelbeeld of concept, anders
      de opname uit het spel, bij een textuur de textuur die nu in het spel
      staat. Staat "op de basis" aan, dan schrijft hij alleen de verandering
      (de studio zet de basiszin er zelf voor). Bij een filmpje geen
      camerawoorden: de filmzin komt er al achter.
    - Model `claude-opus-5-5` (effort medium) via de Anthropic-SDK
      (`python -m pip install anthropic`), met de fallback van de API bij een
      weigering. Sleutel uit `ANTHROPIC_API_KEY` of het veld "Claude-sleutel"
      bovenaan, gecontroleerd en bewaard in
      `%LOCALAPPDATA%\FogOfWar\anthropic.key`, nooit in de repo. Een
      aanroep kost een fractie van een cent.
    - **Uit het spel**: elke textuur onder "in het spel nu" heeft die knop.
      Het bestand en zijn `.import` gaan naar
      `results/vfx_studio/backup/<map>/` (en git heeft hem ook nog);
      zonder bestand tekent het spel weer zijn vervanger, bij varianten
      kiest het uit de rest. De kandidaat die hem had geleverd verliest zijn
      "in het spel".
    - Checks: `--proef` met een nep-Claude op de nepserver (sleutel weigeren
      en bewaren, maak en verbeter, de vraag draagt doel, effect, beschrijving
      en plaatje, de textuurregels, alleen de verandering op een basis, een
      weigering, rare id) en uit het spel (vel met .import en backup, een
      variant, een bestand dat er niet staat, iets buiten het onderdeel). De
      proef zet sinds die dag zijn eigen beginstand voor rook, bloed en vuur
      in zijn kopie van `assets/textures`: hij verwachtte de texturen van de
      ochtend (`musket_3x3`, zes spetters) en faalde zodra er nieuwe in het
      spel stonden.

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

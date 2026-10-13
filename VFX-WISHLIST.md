# VFX-WISHLIST: alle effecten, wat er is en wat er nog moet

Bijgehouden sinds 6 oktober 2026 (docs/VFX-studio.md). Dit is de lijst om in
te schrijven: een nieuwe wens mag gewoon als regel in de tabel van zijn groep,
in je eigen woorden. De code volgt `scripts/vfx/vfx_catalogus.gd` (daar staan
dezelfde effecten met hun knoppen); de VFX-tuner (paneelknop) speelt alles af
wat al bestaat.

Status: **spel** = zit erin (af te spelen in de tuner), **wens** = nog te
bouwen, **diorama** = in het kamp om het bord, nog met vaste waarden.

De concept-prompt (Engels, voor het beeldmodel en Seedance) beschrijft het
effect zoals het in het spel moet ogen: van schuin boven, op het houten bord,
kort en los van de achtergrond. Pas hem gerust aan.

De VFX-studio (`python tools/vfx_studio.py`, paneelknop "VFX-studio") zet elke
rij hiernaast: de versie uit het spel, een promptvak (leeg = de prompt uit deze
tabel), plaatjes en filmpjes via Replicate, "dit is hem" en notities. Een
nieuwe wens kun je ook daar invullen; hij komt dan als regel in deze tabel.

## 1. Kruitdamp en vuurmond

| Effect | Wanneer | Status | Wens / notitie | Concept-prompt |
|---|---|---|---|---|
| Musketschot | elk musketschot | spel | 6 okt: de juiste vlam en kruitdamp (was willekeurig), plus pankruit en propjes; de kogel heeft een eigen textuur (bullet/musket) | A flintlock musket firing on a miniature wooden war-game board, seen from above at an angle: a short bright orange muzzle flash and a thick puff of grey-white black-powder smoke drifting forward. |
| Kanonschot | elk kanonschot | spel | 6 okt: rookring, pluim en propjes erbij; de kogelstreep heeft een eigen textuur (bullet/cannon) | A small bronze field cannon firing on a miniature wooden board, top-down angled view: a large orange-yellow muzzle blast, a dense cloud of grey powder smoke rolling forward, dust kicked up around the wheels. |
| Kruitdamp aan de loop | na elk schot | spel | | Grey-white black-powder smoke billowing from a gun barrel and slowly rising, soft and thick, miniature scale, top-down angled view. |
| Wit wolkje bij koppelen | kaart koppelen | spel | | A clean small white puff of magical smoke around a miniature soldier figure, soft and round, top-down angled view. |
| Rook met de wind mee | alle rook | spel | 6 okt: knop rook met de wind; in de tuner de windschuif | Black-powder smoke drifting sideways in a steady breeze over a miniature battlefield board, top-down angled view. |
| Rookring en pluim bij het kanon | kanonschot | spel | 6 okt: knoppen rookring en rookpluim | A cannon shot producing an expanding smoke ring and a tall thick plume of grey smoke, miniature board, top-down angled view. |
| Kruitflits op de pan | bij een musketschot | spel | 6 okt: knop kruitflits op de pan; de flits heeft een eigen textuur (flash/flits) | The priming pan of a flintlock musket flashing: a tiny bright spark and a small puff of smoke at the lock, close-up, miniature. |
| Gloeiende propjes uit de loop | schot | spel | 6 okt: knop gloeiende propjes; eigen textuur (sparks/propje), ook voor de vonkjes van een explosie en een vuur | Glowing embers and burning paper wadding spraying from a musket barrel and falling to a wooden board, dark background. |
| Rokende loop na het schot | na elk schot, een paar seconden | wens | 13 okt: dunne kringeltjes rook uit de loop terwijl de schutter herlaadt; geluid `laadstok` | A miniature soldier figure on a wooden war-game board holding a musket just after firing, a thin wisp of grey smoke curling lazily up from the barrel, top-down angled view. |
| Kruitnevel over het slagveld | na veel schoten in een cyclus | wens | 13 okt: een dunne laag damp die zich over het bord ophoopt en met de wind wegtrekt; nooit zo dik dat je de pionnen niet ziet | A thin layer of grey gunpowder haze hanging low over a miniature wooden war-game board after a battle, soft and translucent, drifting slowly sideways, top-down angled view. |
| Patroonpapiertje bij het herladen | na een schot | wens | 13 okt: een snippertje papier dwarrelt naar beneden en blijft even liggen; geluid `patroon_bijt` | A tiny scrap of torn paper fluttering down beside a miniature soldier reloading a musket on a wooden war-game board, top-down angled view. |
| Smeulende lontstok | de bediener van een kanon in rust | wens | 13 okt: een gloeiend puntje met een dun rookdraadje dat met de wind meebuigt | A miniature cannon gunner holding a smoldering linstock on a wooden war-game board, a tiny glowing tip with a thin thread of smoke bending in the wind, top-down angled view. |

## 2. Stof en aarde

| Effect | Wanneer | Status | Wens / notitie | Concept-prompt |
|---|---|---|---|---|
| Stofjes in de lucht | boven het bord | spel | staat uit (stofdeeltjes 0); nog niet in de tuner | Fine dust motes floating in a beam of warm light above a miniature wooden board. |
| Voetsporen en wielsporen | elke stap | spel | nog niet in de tuner | Footprints and thin wheel tracks pressed into a dusty miniature board surface, top-down view. |
| Stof bij de landing van een charge | ruiter landt na zijn sprong | spel | 6 okt: knoppen stof bij de landing en stof: dekking; sinds 6 okt met de stofwolk van Max uit de studio | A miniature cavalry rider landing after a jump on a dusty board: a ring of brown dust bursting out around the horse's hooves, top-down angled view. |
| Stof achter galopperende ruiters | ruiter (of kanon) rijdt hard | spel | 6 okt: knop stof achter ruiters en kanonnen; sinds 6 okt met de stofwolk van Max uit de studio | A small trail of dust clouds kicked up behind a galloping miniature cavalry horse on a wooden board, top-down angled view. |
| Opspattende aarde bij een kanonsinslag | kanonskogel slaat in | spel | 6 okt: kluiten en een stofwolk, knop opspattende aarde; sinds 6 okt met de stofwolk van Max uit de studio; de kluiten hebben een eigen textuur (debris/kluit, een vel tolt) | A cannonball hitting the ground on a miniature board: clods of dirt and dust spraying up in a fan, top-down angled view. |
| Krater of schroeiplek | na een kanonsinslag | spel | 6 okt: knoppen krater en krater blijft liggen (s); sinds 6 okt een van de drie kraters van Max uit de studio | A small scorched crater with darkened earth on a miniature wooden board tile, top-down view. |
| Stofpufjes onder de voeten van de big bro | elke stap van een rit, op de rit-stappen | wens | 13 okt: een klein pufje stof waar een voet neerkomt, precies op de zware stap (PawnView.rit_stappen); ook bij de charge-stappen | A large miniature animal beast walking on a dusty wooden war-game board, a small puff of light brown dust bursting up under each foot as it lands, top-down angled view. |
| Stofje als een pion wordt neergezet | opstellen en een verse versterking | wens | 13 okt: een kring stof om de voet bij het neerzetten; geluid `place_pawn` | A miniature soldier figure being set down on a dusty wooden board, a small ring of dust puffing out around its base, top-down angled view. |
| Stof als een lijk neervalt | het lijf raakt de grond | wens | 13 okt: een pufje stof op het moment van body_hit_floor | A miniature animal soldier figure falling flat onto a dusty wooden board, a small cloud of dust puffing up from the impact, top-down angled view. |
| Gras en blaadjes die opwaaien | een charge of een kanonsinslag langs de rand | wens | 13 okt: sprietjes en blaadjes die met de wind meewaaien (diorama's met gras of bos) | Small blades of grass and a few leaves blown up into the air and swirling away in the wind beside a miniature war-game board, top-down angled view. |

## 3. Bloed en inslag

| Effect | Wanneer | Status | Wens / notitie | Concept-prompt |
|---|---|---|---|---|
| Vonken op metaal | treffer op het kuras (hp-pion) | spel | 6 okt: alleen nog op metaal, met een witte flits; vonk en flits hebben een eigen textuur (sparks/vonk, flash/flits) | Bright yellow sparks bursting from a bullet impact, miniature scale, dark background. |
| Treffer: flits, wankelen, wond | geraakt en overleeft | spel | | A miniature soldier figure flinching from a hit, a small spurt of blood from the chest, top-down angled view. |
| Schadegetal (-N) | boven een geraakte pion | spel | | A small red damage number "-2" popping up above a miniature soldier figure on a wooden war-game board, bold game-style digits that float up and fade, top-down angled view. |
| Inslag per materiaal | elke treffer | spel | 6 okt: vlees rode nevel en spatjes, hout splinters, metaal vonken (zoals het geluid); knoppen inslag per materiaal en inslag: hoeveel; splinters met een eigen textuur (debris/splinter) | Three impacts side by side on a miniature board: a red blood splash on cloth, wooden splinters flying from a cannon carriage, bright sparks off a steel cuirass. |
| Bloedwaaier op de grond | een dode | spel | 6 okt: langgerekte spatten van de klap af, na elkaar; knop bloedwaaier | Directional blood splatter on a wooden board after a hit, stylized, top-down view. |
| Bloeddruppels achter een gewonde | een gewonde pion loopt | wens | 13 okt: een paar druppels op het bord achter hem aan; geluid `bloed_drup` | A trail of small red blood drops on a wooden war-game board behind a wounded miniature soldier figure walking away, top-down angled view. |
| Bloedplas droogt op | over een paar cycli | wens | 13 okt: de plas wordt donkerder en doffer en trekt iets in, zodat het bord leesbaar blijft | A dried dark brown blood stain on a wooden war-game board, matte and slightly cracked at the edges, top-down view. |

## 4. Sterven en brokstukken

| Effect | Wanneer | Status | Wens / notitie | Concept-prompt |
|---|---|---|---|---|
| Sterven door een musketkogel | kill met het musket | spel | | A miniature animal soldier figure on a wooden war-game board is hit by a musket ball and topples backwards, a small puff of red mist and a little dust, stylized, top-down angled view. |
| Sterven door een kanonskogel (gibs) | kill met het kanon | spel | | A cannonball strikes a miniature animal soldier figure on a wooden war-game board and the figure bursts apart like a broken toy, pieces flying with a red splash and a cloud of dust, stylized, top-down angled view. |
| Sterven door de bajonet | kill van dichtbij | spel | | A miniature animal soldier figure is struck by a bayonet thrust and collapses on a wooden war-game board, a small red splash, stylized, top-down angled view. |
| Doormidden (sabelhouw) | kill met de charge | spel | | A cavalry sabre slash cuts a miniature animal soldier figure in two on a wooden war-game board, the halves tumbling apart with a red spray, stylized and toy-like, top-down angled view. |
| Vaandel dwarrelt neer | de vaandeldrager sneuvelt | wens | 13 okt: het doek zeilt met de wind mee naar de grond in plaats van mee te vallen; geluid `val_flag` | A small cloth regimental banner slowly sailing down to the ground in the wind on a miniature war-game board after its bearer has fallen, top-down angled view. |
| Trom rolt weg | de tamboer sneuvelt | wens | 13 okt: de trom rolt een stukje weg en valt om; geluid `val_drum` | A small military drum rolling away across a wooden war-game board and tipping over, top-down angled view. |

## 5. Vuur en explosies

| Effect | Wanneer | Status | Wens / notitie | Concept-prompt |
|---|---|---|---|---|
| Kampvuur in het diorama | in het kamp | diorama | vaste waarden in omgeving.gd | A small campfire with flickering flames and rising smoke beside a miniature army camp, top-down angled view, night. |
| Kanon gaat kapot | kanon vernietigd | spel | 6 okt: het kruit ontploft, de affuit spat uiteen, het wrak brandt na; een kanon bloedt niet meer | A miniature wooden field cannon blown apart: splinters and a wheel flying, a column of dark smoke and small flames on the wreck, top-down angled view. |
| Explosie (kruitvat) | explosie | spel | 6 okt: flits, vuurbal (kanonsvlam), stofkring, rookkolom, splinters, vonken; nu bij een kanon, straks ook kruitvaten; de schokgolf ligt als decal op de grond (decals/schokgolf) | A small gunpowder barrel exploding on a miniature board: an orange fireball, a ring of smoke and flying wooden staves, top-down angled view. |
| Vuur op het bord | iets blijft branden | spel | 6 okt: vlammen uit een eigen shader (geen textuur), flakkerend licht, rook, vonkjes; knoppen vuur: maat en brandt na; sinds 6 okt de vlam van Max uit de studio, die golft en flakkert | Small flames licking up from burning debris on a wooden game board, gentle smoke, top-down angled view. |

## 6. Stijl (alle 3D)

Een look geldt voor het hele beeld: elk model, elke prop en het bord, ook
modellen die er later bij komen. Alles staat standaard uit; in de tuner zet
je een look aan met zijn schuif (Speel schiet een musket af, zodat je hem in
actie ziet). Effecten (rook, vuur, bloed) tekenen er scherp overheen.

| Effect | Wanneer | Status | Wens / notitie | Concept-prompt |
|---|---|---|---|---|
| Inktranden (gravure) | altijd | spel | 6 okt: een donkere lijn om elk model en waar het bord van kleur verspringt, zoals de gravures van de emblemen; knoppen inktranden en dikte | A miniature war-game board with animal soldier figures rendered with dark ink outlines, like an engraving or a hand-inked illustration, top-down angled view. |
| Randlicht | altijd | spel | 6 okt: de binnenkant van elk silhouet licht warm op | Miniature animal soldier figures on a wooden board with a warm glowing rim light along their silhouettes, top-down angled view. |
| Miniatuur (tilt-shift) | altijd | spel | 6 okt: boven en onder vaag, scherp op een band; knoppen hoogte en breedte van de band | A tilt-shift photograph of a miniature war-game board with animal soldiers, sharp in the middle band and softly blurred at the top and bottom. |
| Kleurstemming en korrel | altijd | spel | 6 okt: koel tot warm, filmkorrel | A miniature battlefield board with animal soldiers in warm golden afternoon light with subtle film grain, top-down angled view. |
| Kleurtrappen (cel) | altijd | spel | 6 okt: de lichtheid in een paar treden, een getekende stripstijl | A miniature war-game board with animal soldiers in a cel-shaded comic style with flat bands of light and shadow, top-down angled view. |
| Licht zoals in de Model-tuner | altijd | wens | Max: "in moddif zien de modellen er mooier uit"; wat is moddif? | The same miniature war-game board with animal soldiers, lit by soft neutral studio light: bright and even, clean colors, gentle soft shadows, top-down angled view. |

## 7. Zwaai en klap

Max (6 oktober): "voeg ook een slashing trail toe aan de melee wapens, een
lijntje om het effect wat kracht bij te geven, moet ook allemaal tunebaar
zijn". Een lijntje langs de baan van de punt van het wapen, dat naar de camera
kijkt en snel vervaagt; eigen textuur in de studio (trails/slash).

| Effect | Wanneer | Status | Wens / notitie | Concept-prompt |
|---|---|---|---|---|
| Zwaaispoor (bajonet) | een bajonetstoot | spel | 6 okt: knoppen zwaaispoor (sterkte, duur, dikte, start, na, gloed, teamkleur); bij een korte stoot een kort lijntje | A miniature animal soldier on a wooden war-game board thrusting a bayonet, a thin bright white motion streak trailing the blade tip, top-down angled view. |
| Zwaaispoor bij een charge | de ruiter springt en slaat | spel | 6 okt: dezelfde knoppen; het lijntje volgt de bijl, sabel of lans | A miniature cavalry beast leaping and swinging an axe on a wooden war-game board, a curved bright white slash trail following the axe head, top-down angled view. |
| Vonk bij staal op staal | een klap die wordt overleefd | wens | 13 okt: een felle vonk waar de wapens elkaar raken; geluid `melee_survive_*` | Two miniature soldiers on a wooden war-game board crossing blades, a bright spark flaring where the steel meets, top-down angled view. |
| Klapster bij de treffer | het raakmoment van een melee | wens | 13 okt: een korte witte ster van een paar beelden, zoals in een strip, precies op de klap | A bold white comic-style impact star flashing for an instant where a bayonet hits a miniature soldier on a wooden war-game board, top-down angled view. |

## 8. Leven op het bord

Max (13 oktober): "wat zijn nog meer geluid en of vfx details die de game
nog meer tot leven brengen. Bekijk alles en zet in de studios. van geritsel
van uniforms tot ambient sounds en echos of kleine puffs of smoke". De
wensen van die dag staan als rij in de groep waar ze bij horen, plus de drie
secties hieronder. Waar een geluid bij hoort staat het in de notitie; die
geluiden staan in de geluid-studio (SOUND-WISHLIST.md, secties 12 tot en met 18).

| Effect | Wanneer | Status | Wens / notitie | Concept-prompt |
|---|---|---|---|---|
| Adem in de kou | Winterkamp en Alpenpas, in rust | wens | 13 okt: kleine witte ademwolkjes uit de snuiten, om de paar seconden | Tiny white puffs of breath rising from the snouts of miniature animal soldiers standing in the snow on a wooden war-game board, top-down angled view. |
| Vliegjes boven de gesneuvelden | zodra een lijk donker wordt | wens | 13 okt: een paar zwarte puntjes die rondcirkelen; geluid `vlieg_zoem` | A few tiny black flies circling lazily above a fallen miniature soldier figure on a wooden war-game board, top-down angled view. |
| Kraaien op het slagveld | als er een paar lijken liggen | wens | 13 okt: een kraai landt tussen de gesneuvelden, pikt, en vliegt op als er iemand langs loopt; geluid `ver_kraai` | A black crow landing between fallen miniature soldier figures on a wooden war-game board, pecking at the ground, top-down angled view. |
| Vuurvliegjes bij het kampvuur | Weidekamp en Bosrand | wens | 13 okt: zachte gele lichtpuntjes die rond het kampvuur zweven | Soft glowing yellow fireflies drifting around a small campfire next to a miniature war-game board at dusk, top-down angled view. |
| Vallende bladeren | Bosrand en Boerenerf | wens | 13 okt: af en toe een blad dat met de wind over het bord dwarrelt | A few autumn leaves drifting across a miniature wooden war-game board in the wind, top-down angled view. |
| Zand dat over het bord waait | Egypte 1798 | wens | 13 okt: dunne slierten zand die laag over het bord met de wind meelopen | Thin wisps of sand blowing low across a miniature war-game board in a desert camp, following the wind, top-down angled view. |
| Hitte die zindert | Egypte 1798 | wens | 13 okt: de lucht boven het zand trilt zacht (een vervorming, geen kleur) | Heat haze shimmering above a sandy miniature war-game board in the desert sun, the air softly wavering, top-down angled view. |
| Lichtbundels door de kruitdamp | als er rook boven het bord hangt | wens | 13 okt: schuine bundels zonlicht die door de kruitnevel vallen | Slanted beams of warm sunlight falling through drifting gunpowder smoke over a miniature war-game board, top-down angled view. |

## 9. Spelmomenten

| Effect | Wanneer | Status | Wens / notitie | Concept-prompt |
|---|---|---|---|---|
| Honger: de pion verkwijnt | de honger neemt een pion (vanaf cyclus 10) | wens | 13 okt: de kleur trekt eruit, hij zakt door de knieen en valt om, een wolkje stof; geluid `honger_maag` | A starving miniature animal soldier figure on a wooden war-game board slowly losing its color, sagging to its knees and toppling over in a small puff of dust, top-down angled view. |
| Buit vliegt naar je kamp | een vaandel of trom buitgemaakt | wens | 13 okt: het vaandel of de trom vliegt in een boog naar jouw kant van het bord, met een glinstering; geluid `buit_vaandel`, `buit_trom` | A small captured regimental banner flying in a high arc across a miniature war-game board toward the winning side's camp, with a golden glint, top-down angled view. |
| Slagring van de trom | een pion gebruikt de trom-stamina | wens | 13 okt: een ring die van de tamboer naar de pion uitdijt, in de teamkleur; geluid `aura_trom` | A soft glowing ring pulsing outward across a wooden war-game board from a miniature drummer to a nearby soldier, like a drum beat made visible, top-down angled view. |
| Glans van het vaandel | een pion slaat of schiet met de vaandel-aura | wens | 13 okt: een korte glans over het wapen in de teamkleur; geluid `aura_vaandel` | A brief bright glint running along the blade of a miniature soldier's bayonet standing near a regimental banner on a wooden war-game board, top-down angled view. |
| Signaalvuurpijl bij de haven | een pion bereikt de haven | wens | 13 okt: een vuurpijl uit die tijd die omhoog sist en met een pof vonken openspat; geluid `haven_juich` | A small signal rocket shooting up from the corner of a miniature war-game board and bursting into a puff of golden sparks, top-down angled view. |
| Zonlicht trekt over het bord | een nieuwe cyclus begint | wens | 13 okt: een band warm licht die in een paar seconden over het bord schuift | A band of warm morning sunlight sweeping slowly across a miniature wooden war-game board with animal soldiers, top-down angled view. |
| Dreiging bij je haven | een vijand staat vlak bij jouw haven | wens | 13 okt: de rand van je haven-vakken kleurt rood en pulseert op de trom; geluid `haven_dreig` | The corner tiles of a miniature wooden war-game board glowing with a faint pulsing red edge as an enemy soldier approaches, top-down angled view. |

## 10. Weer en licht

| Effect | Wanneer | Status | Wens / notitie | Concept-prompt |
|---|---|---|---|---|
| Regen | een potje met regen | wens | 13 okt: schuine strepen, kringen in de plassen, het bord iets donkerder en natter; geluid `weer_regen` (ambient_field heeft al een regenvariant) | Light rain falling in slanted streaks over a miniature wooden war-game board, small ripples in puddles and a darker wet sheen on the wood, top-down angled view. |
| Ochtendmist | het begin van een potje | wens | 13 okt: lage plukken mist die met de wind wegtrekken en in de eerste cyclus oplossen | Low patches of morning mist drifting over a miniature war-game board and slowly thinning out, top-down angled view. |
| Stofduiveltje | af en toe, Egypte en Weidekamp | wens | 13 okt: een klein wervelwindje dat over het gras naast het bord trekt | A small dust devil whirling across dry grass beside a miniature war-game board, top-down angled view. |
| Bliksem in de verte | onweer | wens | 13 okt: het licht flitst even op en de schaduwen springen; geluid `weer_onweer`, `ver_donder` | A flash of lightning briefly lighting up a miniature war-game board and casting sharp shadows under a stormy sky, top-down angled view. |
| Windvlaag | af en toe | wens | 13 okt: de vlaggen klapperen, rook en stof trekken even harder mee; geluid `weer_wind_vlaag` | A sudden gust of wind sweeping across a miniature war-game board, banners snapping and smoke streaming sideways, top-down angled view. |
| Tijd van de dag per cyclus | elke cyclus een stukje later | wens | 13 okt: ochtend, middag, avond; de honger valt in de schemering | The same miniature war-game board shown at morning, noon and dusk, the light shifting from cool and pale to golden with long shadows, top-down angled view. |

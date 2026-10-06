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

## 1. Kruitdamp en vuurmond

| Effect | Wanneer | Status | Wens / notitie | Concept-prompt |
|---|---|---|---|---|
| Musketschot | elk musketschot | spel | 6 okt: de juiste vlam en kruitdamp (was willekeurig), plus pankruit en propjes | A flintlock musket firing on a miniature wooden war-game board, seen from above at an angle: a short bright orange muzzle flash and a thick puff of grey-white black-powder smoke drifting forward. |
| Kanonschot | elk kanonschot | spel | 6 okt: rookring, pluim en propjes erbij | A small bronze field cannon firing on a miniature wooden board, top-down angled view: a large orange-yellow muzzle blast, a dense cloud of grey powder smoke rolling forward, dust kicked up around the wheels. |
| Kruitdamp aan de loop | na elk schot | spel | | Grey-white black-powder smoke billowing from a gun barrel and slowly rising, soft and thick, miniature scale, top-down angled view. |
| Wit wolkje bij koppelen | kaart koppelen | spel | | A clean small white puff of magical smoke around a miniature soldier figure, soft and round, top-down angled view. |
| Rook met de wind mee | alle rook | spel | 6 okt: knop rook met de wind; in de tuner de windschuif | Black-powder smoke drifting sideways in a steady breeze over a miniature battlefield board, top-down angled view. |
| Rookring en pluim bij het kanon | kanonschot | spel | 6 okt: knoppen rookring en rookpluim | A cannon shot producing an expanding smoke ring and a tall thick plume of grey smoke, miniature board, top-down angled view. |
| Kruitflits op de pan | bij een musketschot | spel | 6 okt: knop kruitflits op de pan | The priming pan of a flintlock musket flashing: a tiny bright spark and a small puff of smoke at the lock, close-up, miniature. |
| Gloeiende propjes uit de loop | schot | spel | 6 okt: knop gloeiende propjes | Glowing embers and burning paper wadding spraying from a musket barrel and falling to a wooden board, dark background. |

## 2. Stof en aarde

| Effect | Wanneer | Status | Wens / notitie | Concept-prompt |
|---|---|---|---|---|
| Stofjes in de lucht | boven het bord | spel | staat uit (stofdeeltjes 0); nog niet in de tuner | Fine dust motes floating in a beam of warm light above a miniature wooden board. |
| Voetsporen en wielsporen | elke stap | spel | nog niet in de tuner | Footprints and thin wheel tracks pressed into a dusty miniature board surface, top-down view. |
| Stof bij de landing van een charge | ruiter landt na zijn sprong | spel | 6 okt: knoppen stof bij de landing en stof: dekking | A miniature cavalry rider landing after a jump on a dusty board: a ring of brown dust bursting out around the horse's hooves, top-down angled view. |
| Stof achter galopperende ruiters | ruiter (of kanon) rijdt hard | spel | 6 okt: knop stof achter ruiters en kanonnen | A small trail of dust clouds kicked up behind a galloping miniature cavalry horse on a wooden board, top-down angled view. |
| Opspattende aarde bij een kanonsinslag | kanonskogel slaat in | spel | 6 okt: kluiten en een stofwolk, knop opspattende aarde | A cannonball hitting the ground on a miniature board: clods of dirt and dust spraying up in a fan, top-down angled view. |
| Krater of schroeiplek | na een kanonsinslag | spel | 6 okt: knoppen krater en krater blijft liggen (s) | A small scorched crater with darkened earth on a miniature wooden board tile, top-down view. |

## 3. Bloed en inslag

| Effect | Wanneer | Status | Wens / notitie | Concept-prompt |
|---|---|---|---|---|
| Vonken op metaal | treffer op het kuras (hp-pion) | spel | 6 okt: alleen nog op metaal, met een witte flits | Bright yellow sparks bursting from a bullet impact, miniature scale, dark background. |
| Treffer: flits, wankelen, wond | geraakt en overleeft | spel | | A miniature soldier figure flinching from a hit, a small spurt of blood from the chest, top-down angled view. |
| Schadegetal (-N) | boven een geraakte pion | spel | | |
| Inslag per materiaal | elke treffer | spel | 6 okt: vlees rode nevel en spatjes, hout splinters, metaal vonken (zoals het geluid); knoppen inslag per materiaal en inslag: hoeveel | Three impacts side by side on a miniature board: a red blood splash on cloth, wooden splinters flying from a cannon carriage, bright sparks off a steel cuirass. |
| Bloedwaaier op de grond | een dode | spel | 6 okt: langgerekte spatten van de klap af, na elkaar; knop bloedwaaier | Directional blood splatter on a wooden board after a hit, stylized, top-down view. |

## 4. Sterven en brokstukken

| Effect | Wanneer | Status | Wens / notitie | Concept-prompt |
|---|---|---|---|---|
| Sterven door een musketkogel | kill met het musket | spel | | |
| Sterven door een kanonskogel (gibs) | kill met het kanon | spel | | |
| Sterven door de bajonet | kill van dichtbij | spel | | |
| Doormidden (sabelhouw) | kill met de charge | spel | | |

## 5. Vuur en explosies

| Effect | Wanneer | Status | Wens / notitie | Concept-prompt |
|---|---|---|---|---|
| Kampvuur in het diorama | in het kamp | diorama | vaste waarden in omgeving.gd | A small campfire with flickering flames and rising smoke beside a miniature army camp, top-down angled view, night. |
| Kanon gaat kapot | kanon vernietigd | spel | 6 okt: het kruit ontploft, de affuit spat uiteen, het wrak brandt na; een kanon bloedt niet meer | A miniature wooden field cannon blown apart: splinters and a wheel flying, a column of dark smoke and small flames on the wreck, top-down angled view. |
| Explosie (kruitvat) | explosie | spel | 6 okt: flits, vuurbal (kanonsvlam), stofkring, rookkolom, splinters, vonken; nu bij een kanon, straks ook kruitvaten | A small gunpowder barrel exploding on a miniature board: an orange fireball, a ring of smoke and flying wooden staves, top-down angled view. |
| Vuur op het bord | iets blijft branden | spel | 6 okt: vlammen uit een eigen shader (geen textuur), flakkerend licht, rook, vonkjes; knoppen vuur: maat en brandt na | Small flames licking up from burning debris on a wooden game board, gentle smoke, top-down angled view. |

Vuurflits-textures (musket + kanon)
====================================
Drop hier muzzle-flash/vlam-afbeeldingen. Zelfde regels als de rook:

1. PNG met transparantie, of
2. AI-output 'isolated on solid black background' (zwart wordt bij het
   laden automatisch transparantie).
3. Sprite sheet: grid in de bestandsnaam (bv. muzzle_flash_3x3.png) -
   frames spelen binnen de flits-duur af.

De flits verschijnt op de per-model ingemeten Vuurmond (Model-tab),
met de lichtpuls eroverheen. Map leeg = de klassieke bol-flits.

Prompt-tip: '2D game VFX texture, musket muzzle flash, bright orange
fire burst with sparks, isolated on solid black background, high
contrast --ar 1:1'

Tunen: vuur-maat en vuur-duur (Rook-tab). Testknop: vuur / test vuur.

Makkelijker: de VFX-studio (python tools/vfx_studio.py, paneelknop
"VFX-studio", groep "Texturen en decals") zet een bestand onder de goede
naam in deze map, met een backup van de oude, en knipt ook een flipbook uit
een filmpje of haalt een achtergrond weg.

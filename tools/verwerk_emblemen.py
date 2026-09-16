# -*- coding: utf-8 -*-
"""De zes factie-emblemen uit de assets-map in het spel zetten.

16 september (Max: "gebruik deze emblemen", de duo-gravures big bro + klein
broertje): leest `<dier>_nobg.png` (1024, doorzichtige achtergrond) uit
`fogofwar-assets/UI_assets_pack/Emblems/`, knipt op de niet-doorzichtige
inhoud met een kleine marge, maakt hem vierkant en schaalt naar 500 x 500,
en schrijft `assets/ui/emblems/<Naam>.png` (de namen die UiAssets.EMBLEMEN
kent: Bear, Croccodile, Lion, Mouse, Pig, Wolf). De .import ernaast blijft
staan (mipmaps). Daarna `<godot> --headless --path . --import` en `-- uicheck`.

Gebruik:  python tools/verwerk_emblemen.py [--bron <map>] [--droogloop]
"""
import argparse
import io
import os
import sys

from PIL import Image

WORTEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOEL = os.path.join(WORTEL, "assets", "ui", "emblems")
BRON_STANDAARD = r"C:\Users\maxni\Documents\fogofwar-assets\UI_assets_pack\Emblems"
MAAT = 500
MARGE = 0.03   # deel van de maat als lucht rondom

# bronbestand -> naam in het spel (UiAssets.EMBLEMEN)
NAMEN = {"bear_nobg.png": "Bear.png", "croc_nobg.png": "Croccodile.png", "lion_nobg.png": "Lion.png",
         "mouse_nobg.png": "Mouse.png", "pig_nobg.png": "Pig.png", "wolf_nobg.png": "Wolf.png"}


def op_maat(im):
    im = im.convert("RGBA")
    doos = im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    if doos:
        im = im.crop(doos)
    b, h = im.size
    zijde = int(max(b, h) * (1.0 + 2.0 * MARGE))
    vierkant = Image.new("RGBA", (zijde, zijde), (0, 0, 0, 0))
    vierkant.alpha_composite(im, ((zijde - b) // 2, (zijde - h) // 2))
    return vierkant.resize((MAAT, MAAT), Image.LANCZOS)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bron", default=BRON_STANDAARD)
    ap.add_argument("--droogloop", action="store_true")
    a = ap.parse_args()
    fouten = 0
    for bron, naam in NAMEN.items():
        pad = os.path.join(a.bron, bron)
        if not os.path.exists(pad):
            print("  MIST: %s" % pad)
            fouten += 1
            continue
        im = op_maat(Image.open(pad))
        uit = os.path.join(DOEL, naam)
        print("  %s -> %s (%dx%d)" % (bron, os.path.relpath(uit, WORTEL), MAAT, MAAT))
        if not a.droogloop:
            im.save(uit, optimize=True)
    if a.droogloop:
        print("Droogloop: niets geschreven.")
    else:
        print("Klaar. Nu: <godot> --headless --path . --import  en  -- uicheck")
    return 1 if fouten else 0


if __name__ == "__main__":
    sys.exit(main())

"""Zet de UI-levering van milestone 3 + 4 (Match HUD, lobby, ghost mode,
meldingen, entry screen) in het project.

    python tools/verwerk_ui_m3.py <zip of map> [--droogloop] [--godot <pad>]
                                  [--geen-import]

De ontwerper levert vijf mappen met hoofdletters en spaties ("MATCH HUD/ICONS/
HIDDEN STATES/Hidden unit.png"). In het project worden dat kleine letters met
underscores voor de MAPPEN; de bestandsnamen blijven die van de ontwerper, op
spaties (worden _) en apostroffen (weg) na:

    MATCH HUD              -> assets/ui/match_hud/{box,buttons,icons,ornaments}
    MULTIPLAYER LOBBY      -> assets/ui/lobby/{bg,box,buttons,icons,ornaments}
    GHOST MODE             -> assets/ui/ghost/{box,icons}
    NOTIFICATION TEMPLATE  -> assets/ui/notificatie/{box,button,icons}
    ENTRY SCREEN           -> assets/ui/entry/{box,buttons}

Een bestand uit ENTRY SCREEN of de lobby dat byte-gelijk is aan een bestand
dat al uit MATCH HUD kwam wordt overgeslagen (de schermen pakken dan dat van
match_hud); het script zegt welke.

Het spel leest deze plaatjes op PAD via scripts/ui/ui_pack.gd (niet op naam,
zoals de eerste pack: de namen botsen onderling, er zijn drie Player_box_1's).

AFGELEID (assets/ui/match_hud/eigen/, door dit script gemaakt, niet van de
ontwerper): Move_order_vierkant.png = de blauwe rand van de loop-ruit, 45
graden gedraaid tot een VIERKANT dat op de tegel past, zonder de voetstappen
(Max, 10 november: "voetstap icon wel vierkant maken en die voetstapjes mogen
echt heel heel licht, opacity 0.2"). De voetstappen legt het spel er zelf
los op (icons/move.png op 20%), met het kostengetal erboven.

Na het kopieren: een import-ronde, dan in elke nieuwe .import de mipmaps aan
(iconen van 500 px worden op 40-90 px getekend) en nog een import-ronde.
Niet draaien met de Godot-editor open.
"""

import argparse
import hashlib
import os
import shutil
import subprocess
import sys
import tempfile
import zipfile

WORTEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOEL = os.path.join(WORTEL, "assets", "ui")

MAPPEN = {
    "MATCH HUD": "match_hud",
    "MULTIPLAYER LOBBY": "lobby",
    "GHOST MODE": "ghost",
    "NOTIFICATION TEMPLATE": "notificatie",
    "ENTRY SCREEN": "entry",
}
# MATCH HUD eerst: wat daarna byte-gelijk is valt af.
VOLGORDE = ["MATCH HUD", "MULTIPLAYER LOBBY", "GHOST MODE",
            "NOTIFICATION TEMPLATE", "ENTRY SCREEN"]

GODOT_STANDAARD = ("C:/Users/maxni/Downloads/Godot_v4.7-stable_win64.exe/"
                   "Godot_v4.7-stable_win64_console.exe")


def schoon_map(naam):
    return naam.strip().lower().replace(" ", "_")


def schoon_bestand(naam):
    return naam.strip().replace(" ", "_").replace("'", "")


def lees_bron(bron):
    """-> lijst van (pad in de levering met /, bytes)."""
    uit = []
    if os.path.isdir(bron):
        for w, _, bestanden in os.walk(bron):
            for b in bestanden:
                p = os.path.join(w, b)
                rel = os.path.relpath(p, bron).replace(os.sep, "/")
                with open(p, "rb") as f:
                    uit.append((rel, f.read()))
    else:
        with zipfile.ZipFile(bron) as z:
            for i in z.infolist():
                if not i.is_dir():
                    uit.append((i.filename, z.read(i)))
    return uit


def plan(bron):
    """-> (te kopieren [(doelpad relatief aan assets/ui, bytes)], overgeslagen [tekst])."""
    per_map = {k: [] for k in VOLGORDE}
    vreemd = []
    for rel, data in lees_bron(bron):
        delen = rel.split("/")
        if delen[0] == "__MACOSX" or delen[-1] == ".DS_Store":
            continue
        if not delen[-1].lower().endswith(".png"):
            vreemd.append(rel)
            continue
        # de levering mag een extra map eromheen hebben
        while delen and delen[0] not in MAPPEN:
            delen = delen[1:]
        if len(delen) < 2:
            vreemd.append(rel)
            continue
        per_map[delen[0]].append((delen[1:], data))
    kopie = []
    over = ["geen png of onbekende map: " + v for v in vreemd]
    gezien = {}
    for bovenmap in VOLGORDE:
        for delen, data in sorted(per_map[bovenmap], key=lambda x: "/".join(x[0])):
            mappen = [schoon_map(d) for d in delen[:-1]]
            doel = "/".join([MAPPEN[bovenmap]] + mappen + [schoon_bestand(delen[-1])])
            h = hashlib.sha1(data).hexdigest()
            if h in gezien and not gezien[h].startswith(MAPPEN[bovenmap] + "/"):
                over.append("%s = %s (byte-gelijk)" % (doel, gezien[h]))
                continue
            gezien.setdefault(h, doel)
            kopie.append((doel, data))
    return kopie, over


def maak_afgeleid(droog=False):
    """De loop-rand als vierkant. -> lijst van paden (relatief aan assets/ui)."""
    bron = os.path.join(DOEL, "match_hud", "icons", "Move_order.png")
    doel_rel = "match_hud/eigen/Move_order_vierkant.png"
    if not os.path.exists(bron):
        return []
    try:
        from PIL import Image
    except ImportError:
        print("PIL ontbreekt: %s niet gemaakt (pip install pillow)" % doel_rel)
        return []
    im = Image.open(bron).convert("RGBA")
    # de ruit is een vierkant op zijn punt: 45 graden draaien zet hem recht
    im = im.rotate(45, resample=Image.BICUBIC, expand=True)
    b, h = im.size
    px = im.load()
    cx, cy = (b - 1) / 2.0, (h - 1) / 2.0
    # de voetstappen in het midden eruit (zacht randje), de rand blijft
    schaal = b / 707.0
    kern, rand = 118.0 * schaal, 16.0 * schaal
    for y in range(h):
        for x in range(b):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if d >= kern + rand:
                continue
            f = 0.0 if d <= kern else (d - kern) / rand
            r, g, bl, a = px[x, y]
            px[x, y] = (r, g, bl, int(round(a * f)))
    # bijsnijden tot de rand met zijn gloed, vierkant en gecentreerd
    doos = im.getbbox()
    half = max(cx - doos[0], doos[2] - cx, cy - doos[1], doos[3] - cy) + 2
    im = im.crop((int(cx - half), int(cy - half), int(cx + half) + 1, int(cy + half) + 1))
    im = im.resize((384, 384), Image.LANCZOS)
    # hoe breed is de rand zelf (zonder gloed) als deel van het plaatje: het
    # spel schaalt daarop (bord_markeringen.gd, LOOP_RAND)
    alfa = im.split()[3]
    midden = [alfa.getpixel((x, 192)) for x in range(384)]
    sterk = [x for x, v in enumerate(midden) if v > 200]
    if sterk:
        print("  loop-rand: buitenkant op %.3f van het plaatje" % ((sterk[-1] - sterk[0] + 1) / 384.0))
    if not droog:
        pad = os.path.join(DOEL, doel_rel.replace("/", os.sep))
        os.makedirs(os.path.dirname(pad), exist_ok=True)
        im.save(pad)
        # de eerste versie (ruit met verbleekte voetstappen) ruimen
        for oud in ["Move_order_kosten.png", "Move_order_kosten.png.import"]:
            oud_pad = os.path.join(DOEL, "match_hud", "eigen", oud)
            if os.path.exists(oud_pad):
                os.remove(oud_pad)
    return [doel_rel]


def zet_mipmaps(paden):
    n = 0
    for rel in paden:
        imp = os.path.join(DOEL, rel.replace("/", os.sep)) + ".import"
        if not os.path.exists(imp):
            continue
        with open(imp, "r", encoding="utf-8") as f:
            tekst = f.read()
        if "mipmaps/generate=false" in tekst:
            with open(imp, "w", encoding="utf-8", newline="\n") as f:
                f.write(tekst.replace("mipmaps/generate=false", "mipmaps/generate=true"))
            n += 1
    return n


def importeer(godot):
    r = subprocess.run([godot, "--headless", "--path", WORTEL, "--import"],
                       capture_output=True, text=True, errors="replace")
    fouten = [l for l in (r.stdout + r.stderr).splitlines()
              if "ERROR" in l and "assets/ui" in l]
    return r.returncode, fouten


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("bron", help="het zip of de uitgepakte map van de ontwerper")
    ap.add_argument("--droogloop", action="store_true", help="alleen laten zien wat er zou gebeuren")
    ap.add_argument("--geen-import", action="store_true", help="niet importeren (editor open)")
    ap.add_argument("--godot", default=os.environ.get("GODOT_PATH", GODOT_STANDAARD))
    a = ap.parse_args()

    kopie, over = plan(a.bron)
    per = {}
    nieuw = gewijzigd = gelijk = 0
    for doel, data in kopie:
        per[doel.split("/")[0]] = per.get(doel.split("/")[0], 0) + 1
        pad = os.path.join(DOEL, doel.replace("/", os.sep))
        if not os.path.exists(pad):
            nieuw += 1
        else:
            with open(pad, "rb") as f:
                if f.read() == data:
                    gelijk += 1
                else:
                    gewijzigd += 1
    for k in sorted(per):
        print("  assets/ui/%-12s %3d bestanden" % (k, per[k]))
    print("nieuw %d, gewijzigd %d, ongewijzigd %d" % (nieuw, gewijzigd, gelijk))
    for o in over:
        print("  overgeslagen: " + o)
    if a.droogloop:
        print("droogloop: niets geschreven")
        return 0

    for doel, data in kopie:
        pad = os.path.join(DOEL, doel.replace("/", os.sep))
        os.makedirs(os.path.dirname(pad), exist_ok=True)
        # via een tijdelijk bestand: een half geschreven png mag er nooit staan
        fd, tmp = tempfile.mkstemp(dir=os.path.dirname(pad), suffix=".tmp")
        with os.fdopen(fd, "wb") as f:
            f.write(data)
        shutil.move(tmp, pad)
    print("geschreven: %d" % len(kopie))
    afgeleid = maak_afgeleid()
    for a_rel in afgeleid:
        print("afgeleid: assets/ui/%s" % a_rel)

    if a.geen_import:
        print("niet geimporteerd: draai zelf --import, zet de mipmaps aan en importeer opnieuw")
        return 0
    if not os.path.exists(a.godot):
        print("Godot niet gevonden (%s): geef --godot mee" % a.godot)
        return 1
    code, fouten = importeer(a.godot)
    print("import 1: exit %d, %d fouten onder assets/ui" % (code, len(fouten)))
    n = zet_mipmaps([d for d, _ in kopie] + afgeleid)
    print("mipmaps aangezet in %d .import-bestanden" % n)
    if n:
        code, fouten = importeer(a.godot)
        print("import 2: exit %d, %d fouten onder assets/ui" % (code, len(fouten)))
    for f in fouten[:20]:
        print("  " + f)
    return 1 if fouten else 0


if __name__ == "__main__":
    sys.exit(main())

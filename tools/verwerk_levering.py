# Zet een complete levering in een keer in het spel.
#
#   python tools/verwerk_levering.py "assets/new upload folder"
#   python tools/verwerk_levering.py <map> --droogloop     # eerst alleen kijken
#
# Een levering is een map met per model een submap die de .blend EN de nieuwe
# texturen bevat, bijvoorbeeld:
#
#   mouse/red/infantry_mix/  infantry_mix_mouse.blend
#                            tripo_node_<uuid>-color.png
#                            tripo_node_<uuid>-normal.png
#
# Factie, type en archetype komen uit de mapnamen (net als bouw_modellen.py),
# het TEAM komt uit het woord red/rood of blue/blauw in het pad. Een map met
# alleen texturen mag ook: dan wordt alleen de jas gewisseld op een model dat er
# al staat.
#
# Wat er gebeurt, per model:
#   1. de drie Blender-stappen (wapen, karakter, gibs) -> assets/models/...
#   2. de kleurtextuur wordt met uv_check tegen de GEBOUWDE glb gehouden
#   3. past hij, dan gaat hij erin als <model>_<team>.png met de juiste
#      import-instellingen (size_limit 1024 + mipmaps, anders hapert de gib)
#   4. past hij NIET, dan gaat hij er niet in en zegt dit script waarom
#
# Stap 2 is het hele punt. Een jas die bij een ander model hoort ziet er in het
# bestand prima uit; je merkt het pas als het model in een partij uit elkaar
# valt in verkeerde lappen. De meting kost een seconde.
#
# Normal-maps worden NIET geinstalleerd: de engine zet alleen een albedo-
# override (PawnView.apply_albedo_to) en de normal zit al in de glb gebakken.
import argparse
import hashlib
import os
import re
import shutil
import subprocess
import sys

PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(PROJ, "tools"))
from bouw_modellen import BLENDER_STANDAARD, plaats, stappen, woorden  # noqa: E402
from uv_check import geverfd, uv_maskers  # noqa: E402

TEAMWOORDEN = {"red": "red", "rood": "red", "blue": "blue", "blauw": "blue"}

IMPORT_SJABLOON = '''[remap]

importer="texture"
type="CompressedTexture2D"
path="res://.godot/imported/{naam}-{hash}.ctex"
metadata={{
"vram_texture": false
}}

[deps]

source_file="{res}"
dest_files=["res://.godot/imported/{naam}-{hash}.ctex"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=1024
detect_3d/compress_to=1
'''


def is_kleur(bestandsnaam):
    n = bestandsnaam.lower()
    return n.endswith(".png") and "normal" not in n and "roughness" not in n and "metallic" not in n


def team_uit(pad, wortel):
    w = woorden(os.path.relpath(pad, wortel).split(os.sep))
    return next((TEAMWOORDEN[x] for x in w if x in TEAMWOORDEN), None)


def verzamel(wortel):
    """Per submap: wat er te doen valt. (factie, soort, arch, team, blend, kleuren)"""
    posten = []
    for r, _, fs in os.walk(wortel):
        blends = sorted(os.path.join(r, f) for f in fs if f.lower().endswith(".blend"))
        kleuren = sorted(os.path.join(r, f) for f in fs if is_kleur(f))
        if not blends and not kleuren:
            continue
        pl = plaats(blends[0] if blends else r + os.sep + "x", wortel)
        if pl is None and kleuren:
            # Geen blend om uit af te leiden: probeer het op de map zelf.
            pl = plaats(os.path.join(r, "x.blend"), wortel)
        if pl is None:
            posten.append((None, None, None, None, blends[0] if blends else None, kleuren, r))
            continue
        factie, soort, arch = pl
        posten.append((factie, soort, arch, team_uit(r, wortel),
                       blends[0] if blends else None, kleuren, r))
    return posten


def schrijf_import(png_pad):
    res = "res://" + os.path.relpath(png_pad, PROJ).replace("\\", "/")
    imp = png_pad + ".import"
    if os.path.exists(imp):
        return False  # bestaat al: instellingen van Max niet overschrijven
    open(imp, "w", newline="\n", encoding="utf-8").write(IMPORT_SJABLOON.format(
        naam=os.path.basename(png_pad), hash=hashlib.md5(res.encode()).hexdigest(), res=res))
    return True


def past(glb, png, drempel):
    """(beste dekking in procent, materiaalnaam) van deze png op dit model."""
    groepen = uv_maskers(glb)
    verf, _maat = geverfd(png)
    scores = []
    for g in groepen.values():
        opp = int(g["masker"].sum())
        if opp:
            scores.append((100 * (g["masker"] & verf).sum() / opp, g["naam"]))
    return max(scores) if scores else (0.0, "-")


def main():
    p = argparse.ArgumentParser(description="Een complete levering (blend + texturen) in het spel zetten.")
    p.add_argument("map", help="de leveringsmap")
    p.add_argument("--uit", default=os.path.join(PROJ, "assets", "models"))
    p.add_argument("--blender", default=os.environ.get("BLENDER", BLENDER_STANDAARD))
    p.add_argument("--drempel", type=float, default=90.0, help="dekking waaronder een jas geweigerd wordt")
    p.add_argument("--droogloop", action="store_true", help="alleen tonen wat er zou gebeuren")
    a = p.parse_args()

    if not os.path.isdir(a.map):
        print(f"Dat is geen map: {a.map}")
        return 1
    posten = verzamel(a.map)
    if not posten:
        print(f"Niets gevonden in {a.map}: geen .blend en geen kleurtextuur.")
        return 1

    print(f"Gevonden in {a.map}:")
    print()
    onbekend = [x for x in posten if x[0] is None]
    goed = [x for x in posten if x[0] is not None]
    for factie, soort, arch, team, blend, kleuren, r in goed:
        wat = []
        if blend:
            wat.append("model uit .blend")
        if kleuren:
            wat.append(f"{len(kleuren)} jas" + ("" if team is None else f" ({team})"))
        merk = "" if (team or not kleuren) else "   LET OP: team onbekend, jas blijft liggen"
        print(f"  {os.path.relpath(r, a.map):48} -> {factie}/{soort}_{arch}: {', '.join(wat)}{merk}")
    for x in onbekend:
        print(f"  {os.path.relpath(x[6], a.map):48} -> ?? factie of archetype niet herkend")
    print()
    if a.droogloop:
        print("Droogloop: er is niets gebouwd en niets geinstalleerd.")
        return 1 if onbekend else 0
    if any(x[4] for x in goed) and not os.path.exists(a.blender):
        print(f"Blender niet gevonden: {a.blender}\nZet BLENDER of gebruik --blender.")
        return 1

    gebouwd, jassen, geweigerd, fout = [], [], [], []
    for factie, soort, arch, team, blend, kleuren, r in goed:
        naam = f"{factie}/{soort}_{arch}"
        doel, basis, plan = stappen(blend or "", factie, soort, arch, a.uit)
        os.makedirs(doel, exist_ok=True)
        if blend:
            mislukt = None
            for stap, args in plan:
                res = subprocess.run([a.blender] + args, capture_output=True, text=True,
                                     errors="replace", cwd=PROJ)
                if res.returncode != 0 or (stap != "wapen" and not os.path.exists(basis)):
                    mislukt = stap
                    print(f"  FOUT {naam}: Blender-stap '{stap}' mislukte")
                    for l in (res.stdout + res.stderr).splitlines()[-5:]:
                        print(f"       {l}")
                    break
            if mislukt:
                fout.append(naam)
                continue
            print(f"  OK   {naam}: model gebouwd")
            gebouwd.append(naam)
        if not os.path.exists(basis):
            if kleuren:
                print(f"  FOUT {naam}: geen model om de jas op te leggen ({os.path.basename(basis)})")
                fout.append(naam)
            continue
        for png in kleuren:
            if team is None:
                geweigerd.append((naam, os.path.basename(png), "team onbekend (geen red/blue in het pad)"))
                continue
            dekking, materiaal = past(basis, png, a.drempel)
            jas = os.path.join(doel, f"{soort}_{arch}_{team}.png")
            if dekking < a.drempel:
                geweigerd.append((naam, os.path.basename(png),
                                  f"dekt maar {dekking:.1f}% van de UV's (op '{materiaal}')"))
                continue
            shutil.copyfile(png, jas)
            schrijf_import(jas)
            print(f"  OK   {naam}: jas {team} erin ({dekking:.1f}% dekking)")
            jassen.append(os.path.relpath(jas, PROJ))

    print()
    print(f"{len(gebouwd)} model(len) gebouwd, {len(jassen)} jas(sen) geinstalleerd")
    for naam, png, waarom in geweigerd:
        print(f"  GEWEIGERD {naam}: {png} -- {waarom}")
    for naam in fout:
        print(f"  MISLUKT   {naam}")
    if onbekend:
        print(f"  {len(onbekend)} map(pen) niet geplaatst (zie hierboven)")
    print()
    if gebouwd or jassen:
        print("Nu nog, in deze volgorde:")
        print("  <godot> --headless --path . --import")
        print("  <godot> --headless --path . --script tools/_wapencheck.gd")
        print("  <godot> --path . res://tools/capture.tscn -- zweefcheck <factie>")
        print("  <godot> --headless --path . res://tools/capture.tscn -- tunercheck")
        print("Daarna de Model-tuner voor schaal en hoogte.")
    return 1 if (fout or geweigerd or onbekend) else 0


if __name__ == "__main__":
    sys.exit(main())

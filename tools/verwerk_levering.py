# Zet een complete levering in een keer in het spel.
#
#   python tools/verwerk_levering.py "assets/new upload folder"
#   python tools/verwerk_levering.py <map> --droogloop     # eerst alleen kijken
#
# Een levering is een map met per model een submap die de .blend EN de nieuwe
# texturen bevat, bijvoorbeeld:
#
#   mouse/infantry_mix/          infantry_mix_mouse.blend
#   mouse/infantry_mix/red/      de jas voor het LIJF, rood
#   mouse/infantry_mix/blue/     idem blauw
#   mouse/infantry_mix/weapon/red/   de jas voor het WAPEN, rood
#   mouse/infantry_mix/weapon/blue/  idem blauw
#
# Een map met "weapon" of "wapen" in het pad levert de jas voor het WAPEN: die
# heeft een eigen UV-atlas en gaat als <wapen>_<team>.png naast de wapen-glb,
# zodat elke factie zijn eigen musket-stijl kan dragen.
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
#
# Bij een HERBOUW waarschuwt hij over achtergebleven afstelling. De schaal en
# hoogte in model_tuning.json horen bij de mesh waarop ze gezet zijn; komt er
# een nieuwe mesh onder dezelfde naam, dan werkt die afstelling stilletijg door
# en staat het model te groot of zwevend. Dat kost je een half uur zoeken.
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys

PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT_STANDAARD = os.path.join(
    "C:", os.sep, "Users", "maxni", "Downloads", "Godot_v4.7-stable_win64.exe",
    "Godot_v4.7-stable_win64_console.exe")
sys.path.insert(0, os.path.join(PROJ, "tools"))
from bouw_modellen import (BLENDER_STANDAARD, plaats_uit_woorden,  # noqa: E402
                           stappen, woorden)
from uv_check import geverfd, uv_maskers  # noqa: E402

TEAMWOORDEN = {"red": "red", "rood": "red", "blue": "blue", "blauw": "blue"}
WAPENWOORDEN = {"weapon", "wapen", "musket", "melee"}

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


# Hoeveel mapniveaus boven een bestand we meelezen. Genoeg om
# ... mouse/red/infantry_mix te dekken ook als Max die laatste map zelf
# aanwijst, en niet zo veel dat de projectmap zelf gaat meepraten.
NIVEAUS = 6


def padwoorden(pad):
    """De laatste mapnamen + de bestandsnaam, als losse kleine woorden.

    Bewust op het VOLLEDIGE pad en niet op het stuk onder de gekozen map: Max
    wijst vaak de modelmap zelf aan (... mouse/red/infantry_mix), en dan staan
    de factie en het team een niveau HOGER dan wat hij koos. Relatief lezen gaf
    daar "team onbekend" terwijl het gewoon in het pad stond.
    """
    delen = os.path.abspath(pad).replace("/", os.sep).split(os.sep)
    stam, ext = os.path.splitext(delen[-1])
    if ext:
        delen[-1] = stam
    return woorden(delen[-NIVEAUS:])


def team_uit(pad):
    w = padwoorden(pad)
    return next((TEAMWOORDEN[x] for x in w if x in TEAMWOORDEN), None)


def is_wapenmap(pad, wortel):
    """Hoort deze map bij het WAPEN in plaats van bij het lijf?

    Alleen kijken naar het stuk ONDER de gekozen map: anders zou een pad als
    C:/.../weapons/... op een heel ander niveau al meetellen.
    """
    rel = os.path.relpath(os.path.abspath(pad), os.path.abspath(wortel))
    return any(x in WAPENWOORDEN for x in woorden(rel.split(os.sep)))


def verzamel(wortel):
    """Per submap: wat er te doen valt. (factie, soort, arch, team, blend, kleuren)"""
    posten = []
    for r, _, fs in os.walk(wortel):
        blends = sorted(os.path.join(r, f) for f in fs if f.lower().endswith(".blend"))
        kleuren = sorted(os.path.join(r, f) for f in fs if is_kleur(f))
        if not blends and not kleuren:
            continue
        # De mapnaam telt altijd mee; een blend-bestandsnaam mag aanvullen.
        w = padwoorden(r)
        if blends:
            w = w + woorden([os.path.splitext(os.path.basename(blends[0]))[0]])
        pl = plaats_uit_woorden(w)
        if pl is None:
            posten.append((None, None, None, None, blends[0] if blends else None, kleuren, r, False))
            continue
        factie, soort, arch = pl
        posten.append((factie, soort, arch, team_uit(r),
                       blends[0] if blends else None, kleuren, r,
                       is_wapenmap(r, wortel)))
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


def oude_afstelling(factie, soort, arch):
    """Tuning-sleutels die al bestaan voor een model dat we net opnieuw bouwen.

    model_tuning.json is map-onafhankelijk (`<factie>/<bestandsnaam>`), dus een
    nieuwe mesh erft de schaal, hoogte en wapenstand van zijn voorganger zonder
    dat iemand daarom vraagt. Alleen melden, niet weggooien: het is Max' werk.
    """
    pad = os.path.join(PROJ, "assets", "models", "model_tuning.json")
    if not os.path.exists(pad):
        return []
    try:
        with open(pad, encoding="utf-8") as f:
            tuning = json.load(f)
    except (OSError, ValueError):
        return []
    wapen = "melee" if soort == "cavalry" else "musket"
    kandidaten = [f"{factie}/{soort}_{arch}", f"{factie}/{soort}_{arch}_{wapen}"]
    return [k for k in kandidaten if tuning.get(k)]


def _godot(godot, args):
    r = subprocess.run([godot, "--headless", "--path", "."] + args,
                       capture_output=True, text=True, errors="replace", cwd=PROJ)
    return r.returncode, (r.stdout + r.stderr).splitlines()


def controleer(godot, modellen, facties):
    """De vaste controleronde na een bouw. Geeft het aantal problemen terug.

    Precies de reeks uit MODEL-PIPELINE-CHECKLIST F/G die anders met de hand
    getypt moest worden. Alleen de regels die over DIT werk gaan worden getoond:
    op een halflege assets-map meldt wapencheck anders tientallen "GEEN MODEL"
    voor alles wat nog niet geleverd is, en dat zegt niets over wat je net bouwde.
    """
    if not os.path.exists(godot):
        print(f"  Godot niet gevonden ({godot}); controles overgeslagen.")
        print("  Zet GODOT_PATH of gebruik --godot <pad>.")
        return 0
    problemen = 0

    print("  importeren...")
    code, _ = _godot(godot, ["--import"])
    if code != 0:
        print("  FOUT: de import van Godot gaf een foutcode")
        problemen += 1

    code, regels = _godot(godot, ["--script", "tools/_wapencheck.gd"])
    for naam in modellen:
        factie, model = naam.split("/")
        arch = model.split("_")[-1]
        soort = model.split("_")[0]
        zoek = f"{soort} {factie}/{arch}:"
        regel = next((l for l in regels if l.startswith(zoek)), None)
        if regel is None:
            print(f"  wapen  {naam}: geen uitslag van wapencheck")
            problemen += 1
        elif "GEEN MODEL" in regel:
            print(f"  wapen  {naam}: FOUT, wapencheck ziet geen model")
            problemen += 1
        else:
            print(f"  wapen  {naam}: {regel.split(':', 1)[1].strip()}")

    for factie in sorted(facties):
        code, regels = _godot(godot, ["res://tools/capture.tscn", "--", "zweefcheck", factie])
        regel = next((l for l in regels if "[ZWEEF]" in l), "")
        ok = "(PASS)" in regel
        problemen += 0 if ok else 1
        print(f"  zweef  {factie}: {regel.replace('[ZWEEF] ', '') or 'geen uitslag'}")

    code, regels = _godot(godot, ["res://tools/capture.tscn", "--", "tunercheck"])
    slot = next((l for l in regels if "klaar:" in l), "")
    gevonden = next((l for l in regels if "modellen gevonden" in l), "")
    if "0 fout" not in slot:
        problemen += 1
    print(f"  tuner  {gevonden.replace('[TUNER] ', '')} -- {slot.replace('[TUNER] klaar: ', '')}")
    return problemen


def main():
    p = argparse.ArgumentParser(description="Een complete levering (blend + texturen) in het spel zetten.")
    p.add_argument("map", help="de leveringsmap")
    p.add_argument("--uit", default=os.path.join(PROJ, "assets", "models"))
    p.add_argument("--blender", default=os.environ.get("BLENDER", BLENDER_STANDAARD))
    p.add_argument("--drempel", type=float, default=90.0, help="dekking waaronder een jas geweigerd wordt")
    p.add_argument("--droogloop", action="store_true", help="alleen tonen wat er zou gebeuren")
    p.add_argument("--godot", default=os.environ.get("GODOT_PATH", GODOT_STANDAARD))
    p.add_argument("--geen-controles", action="store_true",
                   help="niet importeren en niet controleren na afloop")
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
    for factie, soort, arch, team, blend, kleuren, r, wapen in goed:
        wat = []
        if blend:
            wat.append("model uit .blend")
        if kleuren:
            waarvoor = "wapenjas" if wapen else "jas"
            wat.append(f"{len(kleuren)} {waarvoor}" + ("" if team is None else f" ({team})"))
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
    for factie, soort, arch, team, blend, kleuren, r, wapen in goed:
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
            for sleutel in oude_afstelling(factie, soort, arch):
                print(f"  LET OP {naam}: er ligt nog afstelling onder '{sleutel}' van het "
                      f"VORIGE model. Zet hem opnieuw in de Model-tuner.")
        if not os.path.exists(basis):
            if kleuren:
                print(f"  FOUT {naam}: geen model om de jas op te leggen ({os.path.basename(basis)})")
                fout.append(naam)
            continue
        # Een wapenjas hoort bij de WAPEN-glb en wordt daar ook tegen gemeten:
        # die draagt maar een atlas, dus een verkeerde jas valt meteen door de
        # mand. Meten tegen het lijf-model zou de wapen-atlas als "beste
        # materiaal" opleveren en dus alsnog slagen.
        wapen_glb = os.path.splitext(basis)[0] + ("_melee" if soort == "cavalry" else "_musket") + ".glb"
        tegen = wapen_glb if wapen else basis
        stam = os.path.splitext(os.path.basename(tegen))[0]
        wat = "wapenjas" if wapen else "jas"
        for png in kleuren:
            if team is None:
                geweigerd.append((naam, os.path.basename(png), "team onbekend (geen red/blue in het pad)"))
                continue
            if not os.path.exists(tegen):
                geweigerd.append((naam, os.path.basename(png),
                                  f"geen {os.path.basename(tegen)} om de {wat} op te leggen"))
                continue
            dekking, materiaal = past(tegen, png, a.drempel)
            jas = os.path.join(doel, f"{stam}_{team}.png")
            if dekking < a.drempel:
                geweigerd.append((naam, os.path.basename(png),
                                  f"dekt maar {dekking:.1f}% van de UV's (op '{materiaal}')"))
                continue
            shutil.copyfile(png, jas)
            schrijf_import(jas)
            print(f"  OK   {naam}: {wat} {team} erin ({dekking:.1f}% dekking)")
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
    problemen = 0
    if (gebouwd or jassen) and not a.geen_controles:
        print("Controleren:")
        problemen = controleer(a.godot, sorted(set(gebouwd)),
                               {n.split("/")[0] for n in gebouwd} or
                               {x[0] for x in goed})
        print()
        if problemen == 0:
            print("Alles klopt. Open de Model-tuner in het hoofdmenu voor schaal en hoogte;")
            print("dat is het enige wat nog met de hand moet.")
        else:
            print(f"{problemen} probleem(en) hierboven -- laat Claude even meekijken.")
    return 1 if (fout or geweigerd or onbekend or problemen) else 0


if __name__ == "__main__":
    sys.exit(main())

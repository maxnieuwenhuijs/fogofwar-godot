# Bouw de hele inbox met .blends om naar spel-klare modellen.
#
#   python tools/bouw_modellen.py --droogloop        # alleen laten zien wat hij zou doen
#   python tools/bouw_modellen.py                    # alles bouwen
#   python tools/bouw_modellen.py --factie mouse     # één factie
#   python tools/bouw_modellen.py --model cavalry_atk
#
# Dit is de gescripte versie van MODEL-PIPELINE-CHECKLIST sectie C: per .blend
# drie Blender-stappen, in deze volgorde en niet anders.
#
#   1. blender_export_musket.py  -> <type>_<arch>_musket.glb  (infanterie)
#                                   <type>_<arch>_melee.glb   (cavalerie)
#      De losse wapen-prop: terugval en referentie. Het wapen zit óók nog in
#      het karakter zelf (stap 2); deze losse kopie vliegt bij de dood vanaf
#      de hand weg.
#   2. blender_export_blend.py   -> <type>_<arch>.glb
#      Het karakter MET het ingebakken, meebewegende wapen erin.
#   3. blender_merge_character.py --gibs -> kwartslag-fix op <type>_<arch>.glb
#      plus <type>_<arch>_gibs.glb ernaast. Bewaart en herstelt de
#      bot-kind-transforms (de zweefbug van Blender 5.1).
#
# De namen in de inbox zijn rommelig ("lion Base.blend", "pig atk.blend",
# "mouse_cavalry_atk.blend", "bear_infantry_atk/bear_infantry_atk.blend").
# Daarom wordt het pad + de bestandsnaam in woorden geknipt en daaruit worden
# factie, type en archetype herkend. Wat hij niet met zekerheid kan plaatsen
# bouwt hij NIET: dan noemt hij het bestand en gaat verder.
import argparse
import concurrent.futures
import os
import re
import subprocess
import sys
import time

PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLENDER_STANDAARD = r"C:\Program Files\Blender Foundation\Blender 5.1\blender.exe"

# Woord in de bestandsnaam -> wat het spel gebruikt.
FACTIES = {"mouse": "mouse", "muis": "mouse", "pig": "pig", "varken": "pig",
           "lion": "lion", "leeuw": "lion", "bear": "bear", "beer": "bear",
           "wolf": "wolf", "crocodile": "crocodile", "croc": "crocodile",
           "krokodil": "crocodile"}
TYPES = {"infantry": "infantry", "infanterie": "infantry",
         "cavalry": "cavalry", "cavalerie": "cavalry",
         "artillery": "artillery", "artillerie": "artillery"}
ARCHETYPEN = {"base": "base", "basis": "base", "spd": "spd", "speed": "spd",
              "snel": "spd", "hp": "hp", "health": "hp", "atk": "atk",
              "attack": "atk", "mix": "mix", "mixed": "mix"}


def woorden(pad_delen):
    """Knip mappen en bestandsnaam in losse kleine woorden."""
    uit = []
    for deel in pad_delen:
        uit += [w for w in re.split(r"[^A-Za-z0-9]+", deel.lower()) if w]
    return uit


def plaats(blend, inbox):
    """(factie, type, archetype) uit het pad, of None als het niet zeker is."""
    rel = os.path.relpath(blend, inbox)
    w = woorden(os.path.dirname(rel).split(os.sep) + [os.path.splitext(os.path.basename(rel))[0]])
    factie = next((FACTIES[x] for x in w if x in FACTIES), None)
    arch = next((ARCHETYPEN[x] for x in reversed(w) if x in ARCHETYPEN), None)
    # Geen type-woord in de naam betekent infanterie: dat is de standaard in de
    # checklist en het enige type dat elke factie heeft.
    soort = next((TYPES[x] for x in w if x in TYPES), "infantry")
    if factie is None or arch is None:
        return None
    return factie, soort, arch


def stappen(blend, factie, soort, arch, uit_map):
    """De drie Blender-aanroepen voor één model, in volgorde."""
    doel = os.path.join(uit_map, factie, soort)
    basis = os.path.join(doel, f"{soort}_{arch}.glb")
    # Infanterie draagt een musket, cavalerie een sabel/bijl/lans: zelfde stap,
    # andere bestandsnaam. Artillerie heeft geen handwapen.
    wapen = os.path.join(doel, f"{soort}_{arch}_" + ("melee" if soort == "cavalry" else "musket") + ".glb")
    uit = []
    if soort != "artillery":
        uit.append(("wapen", ["--background", blend, "--python",
                              os.path.join(PROJ, "tools", "blender_export_musket.py"),
                              "--", "--uit", wapen]))
    uit.append(("karakter", ["--background", blend, "--python",
                             os.path.join(PROJ, "tools", "blender_export_blend.py"),
                             "--", "--uit", basis]))
    uit.append(("gibs+fix", ["--background", "--python",
                             os.path.join(PROJ, "tools", "blender_merge_character.py"),
                             "--", "--base", basis, "--gibs"]))
    return doel, basis, uit


def bouw(taak, blender, logmap):
    blend, factie, soort, arch, uit_map = taak
    naam = f"{factie}/{soort}_{arch}"
    doel, basis, plan = stappen(blend, factie, soort, arch, uit_map)
    os.makedirs(doel, exist_ok=True)
    begin = time.time()
    for stap, args in plan:
        log = os.path.join(logmap, f"{factie}_{soort}_{arch}_{stap.replace('+', '_')}.log")
        r = subprocess.run([blender] + args, capture_output=True, text=True,
                           errors="replace", cwd=PROJ)
        with open(log, "w", encoding="utf-8") as f:
            f.write(" ".join([blender] + args) + "\n\n" + r.stdout + "\n--- stderr ---\n" + r.stderr)
        # Blender zet de exitcode niet altijd op 1 bij een script-fout, dus ook
        # op het bestand controleren: zonder glb is de stap niet gelukt.
        ontbreekt = stap != "wapen" and not os.path.exists(basis)
        if r.returncode != 0 or ontbreekt:
            return naam, stap, time.time() - begin, log
    if not os.path.exists(os.path.splitext(basis)[0] + "_gibs.glb"):
        return naam, "gibs+fix (geen _gibs.glb)", time.time() - begin, logmap
    return naam, None, time.time() - begin, None


def main():
    p = argparse.ArgumentParser(description="Bouw de .blend-inbox om naar spel-klare modellen.")
    p.add_argument("--inbox", default=os.path.join(PROJ, "assets", "new 3d models"))
    p.add_argument("--uit", default=os.path.join(PROJ, "assets", "models"))
    p.add_argument("--factie", help="alleen deze factie (mouse, pig, lion, bear, wolf, crocodile)")
    p.add_argument("--model", help="alleen modellen waarvan <type>_<archetype> dit bevat")
    p.add_argument("--blender", default=os.environ.get("BLENDER", BLENDER_STANDAARD))
    p.add_argument("--parallel", type=int, default=4, help="modellen tegelijk (standaard 4)")
    p.add_argument("--droogloop", action="store_true", help="alleen de indeling tonen, niets bouwen")
    a = p.parse_args()

    blends = sorted(os.path.join(r, f) for r, _, fs in os.walk(a.inbox)
                    for f in fs if f.lower().endswith(".blend"))
    if not blends:
        print(f"Geen .blend gevonden in {a.inbox}")
        return 1

    taken, onbekend = [], []
    for b in blends:
        pl = plaats(b, a.inbox)
        if pl is None:
            onbekend.append(b)
            continue
        factie, soort, arch = pl
        if a.factie and factie != a.factie:
            continue
        if a.model and a.model not in f"{soort}_{arch}":
            continue
        taken.append((b, factie, soort, arch, a.uit))

    print(f"{len(blends)} .blend in de inbox, {len(taken)} te bouwen"
          + (f", {len(onbekend)} niet te plaatsen" if onbekend else ""))
    print()
    for b, factie, soort, arch, _ in taken:
        print(f"  {os.path.relpath(b, a.inbox):58} -> {factie}/{soort}/{soort}_{arch}.glb")
    for b in onbekend:
        print(f"  {os.path.relpath(b, a.inbox):58} -> ?? factie of archetype niet herkend")
    print()
    if a.droogloop:
        print("Droogloop: niets gebouwd.")
        return 1 if onbekend else 0
    if not os.path.exists(a.blender):
        print(f"Blender niet gevonden: {a.blender}\nZet BLENDER of gebruik --blender.")
        return 1

    logmap = os.path.join(PROJ, "results", "modelbouw_" + time.strftime("%Y%m%d_%H%M%S"))
    os.makedirs(logmap, exist_ok=True)
    print(f"Bouwen met {a.parallel} tegelijk; logs in {os.path.relpath(logmap, PROJ)}")
    print()

    begin = time.time()
    fouten = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=a.parallel) as ex:
        futures = {ex.submit(bouw, t, a.blender, logmap): t for t in taken}
        for i, fut in enumerate(concurrent.futures.as_completed(futures), 1):
            naam, stap, duur, log = fut.result()
            if stap is None:
                print(f"  [{i:2}/{len(taken)}] OK   {naam:26} {duur:5.0f}s")
            else:
                fouten.append((naam, stap, log))
                print(f"  [{i:2}/{len(taken)}] FOUT {naam:26} {duur:5.0f}s  bij stap '{stap}'")

    print()
    print(f"{len(taken) - len(fouten)}/{len(taken)} gebouwd in {(time.time() - begin) / 60:.1f} min")
    for naam, stap, log in fouten:
        print(f"  FOUT {naam} bij '{stap}' -- log: {os.path.relpath(log, PROJ)}")
    if onbekend:
        print(f"  {len(onbekend)} .blend niet geplaatst (zie hierboven)")
    print()
    print("Hierna, in deze volgorde:")
    print("  <godot> --headless --path . --import")
    print("  <godot> --headless --path . --script tools/_wapencheck.gd")
    print("  <godot> --headless --path . res://tools/capture.tscn -- tunercheck")
    print("  <godot> --path . res://tools/capture.tscn -- zweefcheck <factie>")
    print("  <godot> --headless --path . res://tools/capture.tscn -- cliplengtes")
    print("Daarna de teamjassen (<model>_red.png / _blue.png) en de Model-tuner.")
    return 1 if (fouten or onbekend) else 0


if __name__ == "__main__":
    sys.exit(main())

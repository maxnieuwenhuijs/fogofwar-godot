# -*- coding: utf-8 -*-
"""Een hele map glb's in een keer als diorama-props in het spel zetten.

    python tools/verwerk_props_bulk.py results/props_blender [--alleen kruitvat,kist_red] [--geen-controles]

Voor elke `prop_<naam>[_red|_blue].glb` (of `<naam>.glb`) in de map draait hij
verwerk_prop.py zonder controles (meten, texturen afslanken, neerzetten als
assets/models/props/prop_<naam>[_team].glb), en daarna EEN keer de controles:
`--import`, de `.import` van alle uitgepakte texturen op VRAM-compressie +
mipmaps, nog een `--import`, en `-- omgevingcheck`. Zo kost een batch van
twintig props vijf minuten in plaats van een uur.
"""
import argparse
import os
import subprocess
import sys

PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(PROJ)
sys.path.insert(0, os.path.join(PROJ, "tools"))
import verwerk_prop as vp  # noqa: E402

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:  # noqa: BLE001
    pass


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("map", help="map met glb's")
    p.add_argument("--alleen", default="", help="alleen deze namen (komma's)")
    p.add_argument("--geen-controles", action="store_true")
    p.add_argument("--textuur", type=int, default=1024)
    p.add_argument("--godot", default=os.environ.get("GODOT_PATH", vp.GODOT_STANDAARD))
    a = p.parse_args()
    alleen = [x.strip() for x in a.alleen.split(",") if x.strip()]
    glbs = sorted(f for f in os.listdir(a.map) if f.lower().endswith(".glb"))
    gedaan = []
    for f in glbs:
        naam = os.path.splitext(f)[0]
        if naam.startswith("prop_"):
            naam = naam[5:]
        team = ""
        for t in ("_red", "_blue"):
            if naam.endswith(t):
                team = t[1:]
                naam = naam[: -len(t)]
        if alleen and naam not in alleen and (naam + "_" + team) not in alleen:
            continue
        cmd = [sys.executable, os.path.join("tools", "verwerk_prop.py"), os.path.join(a.map, f), naam,
               "--geen-controles", "--geen-preview", "--textuur", str(a.textuur)]
        if team:
            cmd += ["--team", team]
        r = subprocess.run(cmd, capture_output=True, text=True, errors="replace")
        regels = [x for x in r.stdout.splitlines() if x.strip().startswith(("geschreven", "FOUT", "LET OP"))]
        print("%-18s %s" % (naam + ("_" + team if team else ""), " | ".join(x.strip() for x in regels) or r.stdout.strip()[-200:]))
        if r.returncode != 0:
            print("  FOUT bij %s:\n%s" % (f, (r.stdout + r.stderr)[-800:]))
            return 1
        gedaan.append((naam, "prop_%s%s.glb" % (naam, "_" + team if team else "")))
    if not gedaan:
        print("niets te doen")
        return 0
    if a.geen_controles:
        print("KLAAR (zonder controles): %d props" % len(gedaan))
        return 0
    if not os.path.exists(a.godot):
        print("Godot niet gevonden (%s); controles overgeslagen" % a.godot)
        return 1
    print("importeren (%d props)..." % len(gedaan))
    code, regels = vp._godot(a.godot, ["--import"])
    if code != 0:
        print("FOUT: --import gaf %d" % code)
        return 1
    gewijzigd = 0
    for naam, bestandsnaam in gedaan:
        stam = os.path.splitext(bestandsnaam)[0] + "_"
        for f in os.listdir(vp.PROPS_DIR):
            if f.startswith(stam) and f.lower().endswith((".png", ".jpg", ".jpeg", ".webp")):
                if vp.zet_textuur_import(os.path.join(vp.PROPS_DIR, f), "normaal" in f):
                    gewijzigd += 1
    print("import-instellingen gezet op %d texturen, nog een keer importeren..." % gewijzigd)
    code, regels = vp._godot(a.godot, ["--import"])
    if code != 0:
        print("FOUT: de tweede --import gaf %d" % code)
        return 1
    print("omgevingcheck...")
    code, regels = vp._godot(a.godot, ["res://tools/capture.tscn", "--", "omgevingcheck"], timeout=1500)
    uitslag = [r for r in regels if r.startswith("[OMGEVING] PASS") or r.startswith("[OMGEVING] FAIL")]
    fouten = [r for r in regels if "SCRIPT ERROR" in r or "[OMGEVING] FOUT" in r]
    for r in fouten[:8]:
        print("   " + r.strip())
    geleverd = [r for r in regels if "geleverde glb-props" in r]
    gezien = set()
    for r in geleverd:
        for naam, bestandsnaam in gedaan:
            if bestandsnaam in r:
                gezien.add(bestandsnaam)
    print("omgevingcheck: %s" % (uitslag[-1] if uitslag else "geen uitslag (code %d)" % code))
    niet = [bn for _, bn in gedaan if bn not in gezien]
    print("in een diorama gezien: %d van %d%s" % (len(gezien), len(gedaan), ("; NIET: " + ", ".join(niet)) if niet else ""))
    if uitslag and uitslag[-1].startswith("[OMGEVING] PASS"):
        print("KLAAR: daarna python tools/bouw_prop_tracker.py en committen (glb, texturen, .import)")
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())

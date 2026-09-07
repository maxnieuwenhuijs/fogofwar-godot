# Maak van elke .blend in een map een uploadklaar bestand voor een retexture.
#
#   python tools/maak_retexture.py "assets/new upload folder/mouse/red/infantry_mix"
#   python tools/maak_retexture.py "assets/new 3d models/Mouse"
#
# Dit is de omweg-loze versie van:
#   blender --background <blend> --python tools/blender_export_retexture.py -- --uit <glb>
# maar dan voor een hele map, met een nette naam eraan en een rapport eronder.
#
# Wat je krijgt is het KALE LIJF: rusthouding, geen skelet, geen animaties, geen
# ingebakken wapen, lichaamsdelen aan elkaar. Dat upload je bij de
# retexture-dienst, met de uitdrukkelijke vraag om de UV's te LATEN STAAN.
# Vouwt hij toch opnieuw uit, dan past de jas niet meer op het model in het
# spel -- en dat merk je pas in de partij. Wat er terugkomt controleer je met:
#
#   python tools/uv_check.py assets/models/<factie>/<type>/<model>.glb <de png>
import argparse
import os
import subprocess
import sys
import time

PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(PROJ, "tools"))
from bouw_modellen import BLENDER_STANDAARD, plaats  # noqa: E402


def naam_voor(blend, map_pad):
    """Nette bestandsnaam: <factie>_<type>_<archetype>, anders de blend-naam."""
    # plaats() kijkt naar het pad ONDER de gekozen map; die map zelf draagt vaak
    # ook de factienaam ("...\\Mouse"), dus we geven de ouder mee als startpunt.
    pl = plaats(blend, os.path.dirname(os.path.abspath(map_pad)))
    if pl is None:
        return os.path.splitext(os.path.basename(blend))[0].replace(" ", "_")
    factie, soort, arch = pl
    return f"{factie}_{soort}_{arch}"


def main():
    p = argparse.ArgumentParser(description="Blends uit een map klaarmaken voor een retexture.")
    p.add_argument("map", help="de map met .blend-bestanden (submappen tellen mee)")
    p.add_argument("--uit", default=os.path.join(PROJ, "results", "retexture"))
    p.add_argument("--blender", default=os.environ.get("BLENDER", BLENDER_STANDAARD))
    p.add_argument("--los", action="store_true", help="lichaamsdelen NIET aan elkaar plakken")
    p.add_argument("--met-wapen", action="store_true", help="het ingebakken wapen meesturen")
    a = p.parse_args()

    if not os.path.isdir(a.map):
        print(f"Dat is geen map: {a.map}")
        return 1
    blends = sorted(os.path.join(r, f) for r, _, fs in os.walk(a.map)
                    for f in fs if f.lower().endswith(".blend"))
    if not blends:
        print(f"Geen .blend gevonden in {a.map}")
        print("Zet het bestand dat je wilt laten hertexturen in deze map en probeer opnieuw.")
        return 1
    if not os.path.exists(a.blender):
        print(f"Blender niet gevonden: {a.blender}")
        print("Zet BLENDER of gebruik --blender <pad naar blender.exe>.")
        return 1

    os.makedirs(a.uit, exist_ok=True)
    print(f"{len(blends)} .blend gevonden in {a.map}")
    print()
    gelukt, mislukt = [], []
    for i, blend in enumerate(blends, 1):
        doel = os.path.join(a.uit, naam_voor(blend, a.map) + ".glb")
        args = [a.blender, "--background", blend, "--python",
                os.path.join(PROJ, "tools", "blender_export_retexture.py"),
                "--", "--uit", doel]
        if a.los:
            args.append("--los")
        if a.met_wapen:
            args.append("--met-wapen")
        begin = time.time()
        r = subprocess.run(args, capture_output=True, text=True, errors="replace", cwd=PROJ)
        regel = next((l for l in r.stdout.splitlines() if l.startswith("RETEXTURE ->")), "")
        # Blender zet zijn exitcode niet altijd op 1 bij een script-fout, dus we
        # kijken ook of het bestand er echt staat.
        if r.returncode == 0 and os.path.exists(doel):
            kb = os.path.getsize(doel) // 1024
            detail = regel.split("(", 1)[1].rstrip(")") if "(" in regel else ""
            print(f"  [{i}/{len(blends)}] OK   {os.path.basename(doel):34} {kb:5} KB  {detail}")
            gelukt.append(doel)
        else:
            print(f"  [{i}/{len(blends)}] FOUT {os.path.basename(blend)}  ({time.time() - begin:.0f}s)")
            for l in (r.stdout + r.stderr).splitlines()[-6:]:
                print(f"        {l}")
            mislukt.append(blend)

    print()
    print(f"{len(gelukt)} klaar in {os.path.relpath(a.uit, PROJ)}")
    if gelukt:
        print()
        print("Nu doen:")
        print("  1. Upload deze bestanden bij je retexture-dienst.")
        print("  2. Vraag EXPLICIET om de UV's te laten staan (geen nieuwe unwrap).")
        print("  3. Zet de png die je terugkrijgt naast de glb als <model>_red.png of _blue.png.")
        print("  4. Controleer met: python tools/uv_check.py <model>.glb <die png>")
        print("     Boven de 95% past hij, rond de 70% is het de jas van een ander model.")
    return 1 if mislukt else 0


if __name__ == "__main__":
    sys.exit(main())

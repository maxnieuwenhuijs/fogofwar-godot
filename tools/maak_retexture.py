# Maak van elke .blend in een map een uploadklaar bestand voor een retexture.
#
#   python tools/maak_retexture.py "assets/new upload folder/mouse/red/infantry_mix"
#   python tools/maak_retexture.py "assets/new 3d models/Mouse"
#
# Dit is de omweg-loze versie van:
#   blender --background <blend> --python tools/blender_export_retexture.py -- --uit <glb>
# maar dan voor een hele map, met een nette naam eraan en een rapport eronder.
#
# Je krijgt per model TWEE bestanden, want lijf en wapen hebben elk hun eigen
# UV-atlas en kunnen dus los hertextureerd worden:
#
#   <naam>.glb        het kale lijf: rusthouding, geen skelet, geen animaties,
#                     geen wapen, lichaamsdelen aan elkaar
#   <naam>_wapen.glb  alleen het wapen, statisch en losgeknipt van het skelet
#
# Ze komen NAAST de .blend te staan, in dezelfde map, zodat alles van een model
# bij elkaar blijft: de blend, de exports die je uploadt, en straks de png's die
# je terugkrijgt. Met --uit <map> schrijf je ze ergens anders heen.
#
# Allebei upload je bij de retexture-dienst, met de uitdrukkelijke vraag om de
# UV's te LATEN STAAN. Wil je alleen het lijf: --geen-wapen.
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
    p.add_argument("--uit", default=None,
                   help="waar de exports heen gaan (standaard: naast de .blend zelf)")
    p.add_argument("--blender", default=os.environ.get("BLENDER", BLENDER_STANDAARD))
    p.add_argument("--los", action="store_true", help="lichaamsdelen NIET aan elkaar plakken")
    p.add_argument("--met-wapen", action="store_true", help="het wapen OOK in het lijf-bestand zetten")
    p.add_argument("--geen-wapen", action="store_true", help="geen apart wapenbestand maken")
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

    if a.uit:
        os.makedirs(a.uit, exist_ok=True)
    print(f"{len(blends)} .blend gevonden in {a.map}")
    print()
    gelukt, mislukt = [], []
    for i, blend in enumerate(blends, 1):
        # Standaard naast de .blend: alles van een model in een map.
        map_uit = a.uit or os.path.dirname(blend)
        doel = os.path.join(map_uit, naam_voor(blend, a.map) + ".glb")
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
            continue

        # Het wapen apart: eigen UV-atlas, dus je kunt het los laten hertexturen.
        # Hetzelfde script dat de pijplijn gebruikt voor de losse wapen-prop.
        if a.geen_wapen or a.met_wapen:
            continue
        wdoel = os.path.splitext(doel)[0] + "_wapen.glb"
        wr = subprocess.run([a.blender, "--background", blend, "--python",
                             os.path.join(PROJ, "tools", "blender_export_musket.py"),
                             "--", "--uit", wdoel],
                            capture_output=True, text=True, errors="replace", cwd=PROJ)
        wregel = next((l for l in wr.stdout.splitlines() if l.startswith("MUSKET ->")), "")
        if wr.returncode == 0 and os.path.exists(wdoel):
            wkb = os.path.getsize(wdoel) // 1024
            wdetail = wregel.split("(", 1)[1].rstrip(")") if "(" in wregel else ""
            print(f"           OK   {os.path.basename(wdoel):34} {wkb:5} KB  {wdetail}")
            gelukt.append(wdoel)
        elif "GEEN ingebakken wapen" in wr.stdout:
            print(f"           --   {os.path.basename(blend)} draagt geen wapen; alleen het lijf")
        else:
            print(f"           FOUT wapen uit {os.path.basename(blend)} halen mislukte")
            for l in (wr.stdout + wr.stderr).splitlines()[-4:]:
                print(f"                {l}")
            mislukt.append(blend)

    print()
    mappen = sorted({os.path.dirname(g) for g in gelukt})
    print(f"{len(gelukt)} klaar in:")
    for m in mappen:
        try:
            print("   " + os.path.relpath(m, PROJ))
        except ValueError:
            print("   " + m)
    if gelukt:
        print()
        print("Nu doen:")
        print("  1. Upload deze .glb-bestanden bij je retexture-dienst.")
        print("  2. Vraag EXPLICIET om de UV's te laten staan (geen nieuwe unwrap).")
        print("  3. De png voor het LIJF zet je in de kleurmap (red/ of blue/) naast de .blend;")
        print("     de knop \"Map in het spel zetten\" pakt hem daar op.")
        print("     Een png voor het WAPEN hoort in de .blend gebakken te worden en dan opnieuw")
        print("     door de bouwknop; het wapen draagt zijn eigen atlas uit de glb.")
        print("  4. Controleer met: python tools/uv_check.py <model>.glb <die png>")
        print("     Boven de 95% past hij, rond de 70% is het de jas van een ander model.")
    return 1 if mislukt else 0


if __name__ == "__main__":
    sys.exit(main())

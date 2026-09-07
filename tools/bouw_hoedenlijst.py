# -*- coding: utf-8 -*-
"""Leest uit elke model-glb of het model een hoed-deel heeft, en zet die lijst
in model-tracker.html (const MODEL_HOED).

Waarom: de team-kleur-prompts in de tracker moeten het ECHTE model beschrijven.
De doc-prompts geven de big bro sinds 16 augustus een factie-hoed, maar de
cavalerie-modellen die er nu liggen zijn daarvoor gemaakt en hebben er geen.
Noem je in een kleur-prompt toch een hoed, dan tekent de generator er een bij
en klopt het plaatje niet meer met de glb.

Draaien na elke nieuwe of vervangen glb:  python tools/bouw_hoedenlijst.py
"""
import io, json, os, re, struct, sys

WORTEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS = os.path.join(WORTEL, "assets", "models")
TRACKER = os.path.join(WORTEL, "model-tracker.html")

FACTIES = ["mouse", "pig", "lion", "bear", "wolf", "crocodile"]
UNITS = [t + "_" + a for t in ("infantry", "cavalry", "artillery")
         for a in ("base", "spd", "hp", "atk", "mix")]
HOED = re.compile(r"\b(hat|helm|shako|cap)\b", re.I)


def delen(pad):
    """De niet-bot node-namen uit een .glb (de losse mesh-delen)."""
    with io.open(pad, "rb") as f:
        f.read(12)
        clen, _ = struct.unpack("<II", f.read(8))
        j = json.loads(f.read(clen).decode("utf-8"))
    return [n.get("name", "") for n in j.get("nodes", [])
            if not n.get("name", "").startswith("mixamorig")]


def zoek_glb(factie, unit):
    for pad in (os.path.join(MODELS, factie, unit.split("_")[0], unit + ".glb"),
                os.path.join(MODELS, factie, unit + ".glb")):
        if os.path.exists(pad):
            return pad
    return None


rijen, met, zonder = [], 0, 0
for factie in FACTIES:
    for unit in UNITS:
        pad = zoek_glb(factie, unit)
        if not pad:
            continue                      # nog geen model: prompt-tekst beslist
        heeft = any(HOED.search(d) for d in delen(pad))
        rijen.append('  "%s.%s": %s,' % (factie, unit, "true" if heeft else "false"))
        met += 1 if heeft else 0
        zonder += 0 if heeft else 1

blok = ("const MODEL_HOED = {\n" + "\n".join(rijen) + "\n};")

with io.open(TRACKER, encoding="utf-8") as f:
    html = f.read()

patroon = re.compile(r"const MODEL_HOED = \{.*?\n\};", re.S)
if patroon.search(html):
    html = patroon.sub(lambda m: blok, html, count=1)
else:
    anker = "const TEAM = {"
    if anker not in html:
        sys.exit("anker 'const TEAM' niet gevonden in de tracker")
    html = html.replace(anker, blok + "\n\n" + anker, 1)

with io.open(TRACKER, "w", encoding="utf-8", newline="\n") as f:
    f.write(html)

print("%d modellen gelezen: %d met hoed, %d zonder" % (len(rijen), met, zonder))
for r in rijen:
    if "false" in r:
        print("  geen hoed:", r.strip().split('"')[1])

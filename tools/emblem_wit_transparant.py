"""Maak het wit in de factie-emblemen volledig transparant (16 september, Max:
"kan je uit de emblems de wit waarde volledig transparant maken?").

De emblemen zijn gravures: zwarte inkt op wit, met een uitgesneden (al
transparante) buitenkant. Dit script zet de helderheid om in dekking: wit
wordt volledig doorzichtig, zwart blijft dicht, grijs wordt half doorzichtig
(de arcering blijft dus arcering, ook op een donkere ondergrond). De kleur
zelf wordt zwart; een bestaande alpha (de uitsnede) blijft de bovengrens.

    python tools/emblem_wit_transparant.py [assets/ui/emblems] [--droogloop]

Het origineel gaat als kopie naar `<map>/bron/` (met een .gdignore, zodat
Godot het niet als tweede textuur importeert). Een bestand dat al is omgezet
(geen ondoorzichtig wit meer) wordt overgeslagen. Daarna: `<godot> --headless
--path . --import` en `-- uicheck`.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image


def zet_om(bron: Path, droogloop: bool) -> str:
    im = Image.open(bron).convert("RGBA")
    px = im.load()
    w, h = im.size
    wit = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            lum = (r * 299 + g * 587 + b * 114) // 1000
            if lum >= 250:
                wit += 1
            dekking = min(a, 255 - lum)
            px[x, y] = (0, 0, 0, dekking)
    if wit == 0:
        return f"{bron.name}: al omgezet (geen ondoorzichtig wit), overgeslagen"
    if droogloop:
        return f"{bron.name}: {wit} witte pixels zouden transparant worden"
    bronmap = bron.parent / "bron"
    bronmap.mkdir(exist_ok=True)
    (bronmap / ".gdignore").touch()
    kopie = bronmap / bron.name
    if not kopie.exists():
        kopie.write_bytes(bron.read_bytes())
    im.save(bron, optimize=True)
    return f"{bron.name}: {wit} witte pixels transparant, origineel in {kopie.as_posix()}"


def main(argv: list[str]) -> int:
    droogloop = "--droogloop" in argv
    rest = [a for a in argv if not a.startswith("--")]
    map_ = Path(rest[0]) if rest else Path("assets/ui/emblems")
    bestanden = sorted(p for p in map_.glob("*.png"))
    if not bestanden:
        print(f"geen png's in {map_}")
        return 1
    for p in bestanden:
        print(zet_om(p, droogloop))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

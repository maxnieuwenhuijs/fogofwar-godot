# Past deze teamjas op dit model?
#
#   python tools/uv_check.py assets/models/mouse/infantry/infantry_mix.glb \
#       assets/models/mouse/infantry/infantry_mix_red.png [meer png's...]
#
# Waarom dit bestaat: een teamjas is een losse PNG die het spel als albedo over
# een glb legt. Hoort hij bij een ANDERE mesh, dan valt het model uit elkaar in
# verkeerde lappen -- en dat zie je pas in het spel. De uuid in de bestandsnaam
# is maar een naam, en op 6 september bleek een rood-blauw-vergelijking ook al
# niet genoeg (dan controleer je twee jassen tegen elkaar, niet tegen de mesh).
#
# Deze meting gaat wel tegen de mesh: de UV-coordinaten worden uit de glb
# gelezen en als driehoeken in een masker getekend. Dat masker is precies waar
# de textuur beschilderd MOET zijn. Daarna: hoeveel van dat gebied is in de PNG
# echt beschilderd (alfa aan)? Een passende jas zit tegen de 100%; een jas van
# een ander model laat gaten vallen.
#
# Alleen numpy en Pillow nodig; de glb wordt hier zelf uitgepakt.
import argparse
import json
import os
import struct
import sys

import numpy as np
from PIL import Image

# glTF-componenttypes -> numpy
COMPONENT = {5120: "i1", 5121: "u1", 5122: "i2", 5123: "u2", 5125: "u4", 5126: "f4"}
AANTAL = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def lees_glb(pad):
    """(json-dict, bin-blok) uit een binaire glb."""
    with open(pad, "rb") as f:
        rauw = f.read()
    magic, _versie, _lengte = struct.unpack_from("<4sII", rauw, 0)
    if magic != b"glTF":
        raise SystemExit(f"{pad} is geen binaire glb")
    js, bin_blok, p = None, b"", 12
    while p < len(rauw):
        lengte, soort = struct.unpack_from("<II", rauw, p)
        data = rauw[p + 8: p + 8 + lengte]
        if soort == 0x4E4F534A:
            js = json.loads(data.decode("utf-8"))
        elif soort == 0x004E4942:
            bin_blok = data
        p += 8 + lengte + (-lengte % 4)
    return js, bin_blok


def accessor(js, bin_blok, index):
    """Eén accessor als numpy-array van vorm (count, aantal)."""
    acc = js["accessors"][index]
    soort = COMPONENT[acc["componentType"]]
    breedte = AANTAL[acc["type"]]
    n = acc["count"]
    if "bufferView" not in acc:
        return np.zeros((n, breedte), dtype=soort)
    bv = js["bufferViews"][acc["bufferView"]]
    start = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stap = bv.get("byteStride") or 0
    itemgrootte = np.dtype(soort).itemsize * breedte
    if stap and stap != itemgrootte:
        # Verweven buffer: rij voor rij de juiste bytes eruit knippen.
        uit = np.empty((n, breedte), dtype=soort)
        for i in range(n):
            o = start + i * stap
            uit[i] = np.frombuffer(bin_blok, dtype=soort, count=breedte, offset=o)
        return uit
    return np.frombuffer(bin_blok, dtype=soort, count=n * breedte, offset=start).reshape(n, breedte)


def uv_maskers(pad, res=512):
    """Per MATERIAAL een masker van de texels die zijn UV-driehoeken dekken.

    Per materiaal en niet in totaal, want een spel-glb draagt twee atlassen:
    het lijf en het ingebakken wapen. Die UV-vlakken liggen over elkaar heen,
    dus samengevoegd beslaan ze bijna de hele atlas en meet je niets meer.
    """
    js, bin_blok = lees_glb(pad)
    groepen = {}
    for mesh in js.get("meshes", []):
        for prim in mesh.get("primitives", []):
            attrs = prim.get("attributes", {})
            if "TEXCOORD_0" not in attrs:
                continue
            mat = prim.get("material", -1)
            g = groepen.setdefault(mat, {"masker": np.zeros((res, res), dtype=bool), "tris": 0})
            uv = accessor(js, bin_blok, attrs["TEXCOORD_0"]).astype(np.float64)
            if "indices" in prim:
                idx = accessor(js, bin_blok, prim["indices"]).reshape(-1)
            else:
                idx = np.arange(len(uv))
            # UV -> pixels. v loopt in glTF van boven naar beneden, net als rijen.
            p = np.column_stack([uv[:, 0] * (res - 1), uv[:, 1] * (res - 1)])
            teken_driehoeken(g["masker"], p, idx.reshape(-1, 3), res)
            g["tris"] += len(idx) // 3
    for mat, g in groepen.items():
        naam = "(geen materiaal)"
        if 0 <= mat < len(js.get("materials", [])):
            naam = js["materials"][mat].get("name", f"materiaal {mat}")
        g["naam"] = naam
    return groepen


def teken_driehoeken(masker, p, driehoeken, res):
    for a, b, c in driehoeken:
        tri = p[[a, b, c]]
        x0, y0 = np.floor(tri.min(axis=0)).astype(int)
        x1, y1 = np.ceil(tri.max(axis=0)).astype(int)
        x0, y0 = max(x0, 0), max(y0, 0)
        x1, y1 = min(x1, res - 1), min(y1, res - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        # Barycentrisch: binnen de driehoek liggen alle drie de tekens gelijk.
        (ax, ay), (bx, by), (cx, cy) = tri
        noemer = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(noemer) < 1e-12:
            masker[ys, xs] = True  # ontaarde driehoek: hele bbox aanzetten
            continue
        l1 = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / noemer
        l2 = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / noemer
        binnen = (l1 >= -0.02) & (l2 >= -0.02) & (l1 + l2 <= 1.02)
        masker[ys[binnen], xs[binnen]] = True


def geverfd(pad, res=512):
    """(masker van beschilderde texels, welke maatstaf gebruikt is).

    Tripo levert RGBA met een echte alfa: dan is alfa het antwoord. Oudere,
    platte PNG's hebben overal alfa 255; daar moet je op kleur terugvallen en
    telt bijna-zwart als onbeschilderd. Die terugval mag NIET de standaard zijn:
    de nieuwe blauwe jassen zijn zo donker dat ze er half door wegvallen.
    """
    a = np.asarray(Image.open(pad).convert("RGBA").resize((res, res), Image.NEAREST))
    alfa = a[:, :, 3] > 8
    if not alfa.all():
        return alfa, "alfa"
    return a[:, :, :3].max(axis=2) > 8, "kleur"


def main():
    p = argparse.ArgumentParser(description="Past een teamjas op de UV-indeling van een model?")
    p.add_argument("model", help="de .glb")
    p.add_argument("textures", nargs="+", help="een of meer PNG's")
    p.add_argument("--drempel", type=float, default=90.0,
                   help="dekking in procent waaronder het FOUT heet (standaard 90)")
    a = p.parse_args()

    groepen = uv_maskers(a.model)
    if not groepen:
        print("Geen UV-coordinaten in dit model: niets te vergelijken.")
        return 1
    print(f"{os.path.basename(a.model)} draagt {len(groepen)} materia(a)l(en):")
    for mat in sorted(groepen, key=lambda m: -groepen[m]["tris"]):
        g = groepen[mat]
        print(f"   {g['naam']:52} {g['tris']:5} driehoeken, "
              f"{100 * g['masker'].sum() / g['masker'].size:5.1f}% van de atlas")
    print()
    print(f"{'texture':34} {'dekking':>9}  maat   past op materiaal")
    slecht = 0
    for t_pad in a.textures:
        verf, maat = geverfd(t_pad)
        scores = []
        for mat, g in groepen.items():
            opp = int(g["masker"].sum())
            if opp == 0:
                continue
            scores.append((100 * (g["masker"] & verf).sum() / opp, g["naam"]))
        dekking, naam = max(scores) if scores else (0.0, "-")
        ok = dekking >= a.drempel
        slecht += 0 if ok else 1
        stempel = "PAST" if ok else "PAST NIET"
        print(f"{os.path.basename(t_pad):34} {dekking:8.1f}%  {maat:6} {naam}   {stempel}")
    print()
    print(f"{slecht} van de {len(a.textures)} passen niet")
    return 1 if slecht else 0


if __name__ == "__main__":
    sys.exit(main())

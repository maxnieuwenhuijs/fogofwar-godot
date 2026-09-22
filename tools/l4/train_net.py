#!/usr/bin/env python
"""L4 neuraal (22 september) -- de trainer van het netje.

Leest een of meer `beslissingen.bin` (arena met "beslis_log": true, zie
arena/beslis_log.gd voor het formaat), traint een klein MLP op de kenmerkrijen
en schrijft `data/ai_net.json` in het formaat dat NeuraalNet (GDScript) leest.

Het netje geeft elke na-staat EEN getal: de waarde voor de speler die hem
bekijkt. Twee leersignalen, samen in dat ene getal:

  imitatie   softmax over de kandidaten van een beslissing, kruisentropie met
             de zet die de logger-bot koos (L2 of een eerdere L4). Dit maakt
             van het netje eerst een kopie van de bot die de data speelde.
  uitslag    de gekozen na-staat als logit van "ik win deze partij":
             sigmoid(waarde) tegen de uitslag. Dit is wat het netje voorbij
             zijn leermeester kan brengen: het leert wat WON, niet wat L2 vond.

Gewichten van de twee: --imitatie en --uitslag. Eerste ronde (data van L2):
imitatie 1, uitslag 0.5. Latere rondes (data van L4 zelf, selfplay): imitatie
laag, uitslag hoog.

Alleen numpy. Voorbeeld:

  python tools/l4/train_net.py results/log_20260922 --uit data/ai_net.json
  python tools/l4/train_net.py results/a results/b --verborgen 48,48 --epochs 20

Daarna:  godot --headless --path . res://tools/capture.tscn -- netcheck
"""
import argparse
import glob
import json
import os
import struct
import sys
import time

import numpy as np

MAGIC = b"FOWL"

# Namen van de kenmerken, zelfde volgorde als Kenmerken.namen() in GDScript
# (alleen voor het rapport; de trainer leest de breedte uit de kop).
KANT_NAMEN = [
    "alive", "inf", "cav", "art", "actief", "hp", "stamina", "attack", "in_haven",
    "guard", "d1", "d2", "prox", "near3", "gem_d", "risk", "reach", "ranged",
    "dragers", "buit_open", "aura", "pool", "cp", "pool_bekend",
]
GLOBAAL_NAMEN = [
    "cyclus", "honger", "tot_honger", "ronde", "wanhoop",
    "doc_me_0", "doc_me_1", "doc_me_2", "doc_me_3", "doc_me_4", "doc_me_5",
    "doc_opp_0", "doc_opp_1", "doc_opp_2", "doc_opp_3", "doc_opp_4", "doc_opp_5",
]
NAMEN = ["me_" + n for n in KANT_NAMEN] + ["opp_" + n for n in KANT_NAMEN] + GLOBAAL_NAMEN
DOCTRINE_NAMEN = ["varken", "muis", "leeuw", "beer", "wolf", "krokodil"]


# ---------------------------------------------------------------------------
# Lezen
# ---------------------------------------------------------------------------

def vind_logs(paden):
    uit = []
    for p in paden:
        if os.path.isdir(p):
            uit += sorted(glob.glob(os.path.join(p, "**", "beslissingen.bin"), recursive=True))
        elif os.path.isfile(p):
            uit.append(p)
        else:
            print(f"[L4] WAARSCHUWING: {p} bestaat niet", file=sys.stderr)
    return uit


def lees_beslislog(pad, max_beslissingen=None):
    """-> dict met X (kandidaten x kenmerken, float32), seg (start-index per
    beslissing, lengte n+1), gekozen (n), partij (n), speler (n), doctrine (n),
    uitslag {partij: (winnaar, d1, d2, cycli)}, kenmerk_versie, n_kenmerken."""
    with open(pad, "rb") as f:
        buf = f.read()
    if buf[:4] != MAGIC:
        raise ValueError(f"{pad}: geen beslislog (magic {buf[:4]!r})")
    fv, kv, nk = struct.unpack_from("<HHH", buf, 4)
    if fv != 1:
        raise ValueError(f"{pad}: formaat-versie {fv} onbekend")
    pos = 10
    blokken = []
    seg = [0]
    gekozen = []
    partij = []
    speler = []
    doctrine = []
    uitslag = {}
    totaal = 0
    n = len(buf)
    while pos < n:
        soort = buf[pos]
        pos += 1
        if soort == 1:
            p, s, d, k, g = struct.unpack_from("<IBBHH", buf, pos)
            pos += 10
            rij = np.frombuffer(buf, dtype="<f4", count=k * nk, offset=pos).reshape(k, nk)
            pos += k * nk * 4
            if max_beslissingen is not None and len(gekozen) >= max_beslissingen:
                continue
            blokken.append(rij)
            totaal += k
            seg.append(totaal)
            gekozen.append(g)
            partij.append(p)
            speler.append(s)
            doctrine.append(d)
        elif soort == 2:
            p, w, d1, d2, c = struct.unpack_from("<IBBBH", buf, pos)
            pos += 9
            uitslag[p] = (w, d1, d2, c)
        else:
            raise ValueError(f"{pad}: onbekend record-soort {soort} op {pos - 1}")
    X = np.concatenate(blokken, axis=0) if blokken else np.zeros((0, nk), dtype=np.float32)
    return {
        "X": X,
        "seg": np.asarray(seg, dtype=np.int64),
        "gekozen": np.asarray(gekozen, dtype=np.int64),
        "partij": np.asarray(partij, dtype=np.int64),
        "speler": np.asarray(speler, dtype=np.int64),
        "doctrine": np.asarray(doctrine, dtype=np.int64),
        "uitslag": uitslag,
        "kenmerk_versie": kv,
        "n_kenmerken": nk,
        "pad": pad,
    }


def bundel(logs):
    """Meerdere logs achter elkaar; partijen krijgen een uniek nummer per log."""
    Xs, segs, gek, won, doc, partij_id = [], [], [], [], [], []
    offset = 0
    partij_offset = 0
    kv = None
    nk = None
    partijen = 0
    zonder_uitslag = 0
    for lg in logs:
        if kv is None:
            kv, nk = lg["kenmerk_versie"], lg["n_kenmerken"]
        elif (kv, nk) != (lg["kenmerk_versie"], lg["n_kenmerken"]):
            raise ValueError(f"{lg['pad']}: kenmerk-versie {lg['kenmerk_versie']}/{lg['n_kenmerken']} past niet op {kv}/{nk}")
        Xs.append(lg["X"])
        segs.append(lg["seg"][:-1] + offset)
        offset += lg["X"].shape[0]
        gek.append(lg["gekozen"])
        doc.append(lg["doctrine"])
        w = np.full(len(lg["gekozen"]), -1.0)
        for i, (p, s) in enumerate(zip(lg["partij"], lg["speler"])):
            u = lg["uitslag"].get(int(p))
            if u is None or u[0] == 0:
                zonder_uitslag += 1
                continue
            w[i] = 1.0 if u[0] == s else 0.0
        won.append(w)
        partij_id.append(lg["partij"] + partij_offset)
        partij_offset += (int(lg["partij"].max()) + 1) if len(lg["partij"]) else 0
        partijen += len(lg["uitslag"])
    seg = np.concatenate(segs + [np.asarray([offset])])
    return {
        "X": np.concatenate(Xs),
        "seg": seg,
        "gekozen": np.concatenate(gek),
        "won": np.concatenate(won),
        "doctrine": np.concatenate(doc),
        "partij": np.concatenate(partij_id),
        "kenmerk_versie": kv,
        "n_kenmerken": nk,
        "partijen": partijen,
        "zonder_uitslag": zonder_uitslag,
    }


def filter_doctrine(D, doctrine):
    """Alleen de beslissingen van een factie (kandidaten opnieuw aaneengeregen)."""
    idx = np.nonzero(D["doctrine"] == doctrine)[0]
    starts = D["seg"][idx]
    ends = D["seg"][idx + 1]
    lengtes = ends - starts
    rijen = np.concatenate([np.arange(a, b) for a, b in zip(starts, ends)]) if len(idx) else np.zeros(0, dtype=np.int64)
    seg = np.concatenate([[0], np.cumsum(lengtes)])
    uit = dict(D)
    uit["X"] = D["X"][rijen]
    uit["seg"] = seg
    for k in ("gekozen", "won", "doctrine", "partij"):
        uit[k] = D[k][idx]
    return uit


# ---------------------------------------------------------------------------
# Het netje
# ---------------------------------------------------------------------------

class MLP:
    def __init__(self, breedtes, rng):
        self.W = []
        self.b = []
        for i in range(len(breedtes) - 1):
            fan_in, fan_out = breedtes[i], breedtes[i + 1]
            # He-init voor relu; de laatste laag klein zodat de start ~0 is.
            schaal = np.sqrt(2.0 / fan_in) if i < len(breedtes) - 2 else 0.01
            self.W.append(rng.normal(0.0, schaal, size=(fan_in, fan_out)).astype(np.float64))
            self.b.append(np.zeros(fan_out, dtype=np.float64))
        self.m = [np.zeros_like(w) for w in self.W + self.b]
        self.v = [np.zeros_like(w) for w in self.W + self.b]
        self.t = 0

    def params(self):
        return self.W + self.b

    def forward(self, x):
        hs = [x]
        h = x
        laatste = len(self.W) - 1
        for i, (w, b) in enumerate(zip(self.W, self.b)):
            z = h @ w + b
            h = np.maximum(z, 0.0) if i < laatste else z
            hs.append(h)
        return h[:, 0], hs

    def backward(self, hs, ds):
        """ds: dL/d(uitvoer) per rij. -> gradienten in volgorde van params()."""
        gW = [None] * len(self.W)
        gb = [None] * len(self.b)
        d = ds[:, None]
        for i in range(len(self.W) - 1, -1, -1):
            h_in = hs[i]
            gW[i] = h_in.T @ d
            gb[i] = d.sum(axis=0)
            if i > 0:
                d = d @ self.W[i].T
                d = d * (hs[i] > 0.0)
        return gW + gb

    def adam(self, grads, lr, b1=0.9, b2=0.999, eps=1e-8, wd=0.0):
        self.t += 1
        for p, g, m, v in zip(self.params(), grads, self.m, self.v):
            if wd > 0.0 and p.ndim == 2:
                g = g + wd * p
            m *= b1
            m += (1 - b1) * g
            v *= b2
            v += (1 - b2) * (g * g)
            mh = m / (1 - b1 ** self.t)
            vh = v / (1 - b2 ** self.t)
            p -= lr * mh / (np.sqrt(vh) + eps)


def segment_softmax(s, seg_id, n_seg):
    """softmax per segment (beslissing) over een platte score-vector."""
    mx = np.full(n_seg, -np.inf)
    np.maximum.at(mx, seg_id, s)
    e = np.exp(s - mx[seg_id])
    som = np.zeros(n_seg)
    np.add.at(som, seg_id, e)
    return e / som[seg_id]


def maak_batch(D, idx):
    """Kandidaten van de beslissingen `idx` plat achter elkaar."""
    starts = D["seg"][idx]
    ends = D["seg"][idx + 1]
    lengtes = ends - starts
    rijen = np.concatenate([np.arange(a, b) for a, b in zip(starts, ends)])
    seg_id = np.repeat(np.arange(len(idx)), lengtes)
    gek_plat = np.cumsum(np.concatenate([[0], lengtes[:-1]])) + D["gekozen"][idx]
    return rijen, seg_id, gek_plat, lengtes


def evalueer(net, D, Xn, idx, w_im, w_uit, batch=4096):
    """-> (loss, imitatie-acc, top3-acc, uitslag-acc, uitslag-n)"""
    tot_loss = 0.0
    goed = 0
    top3 = 0
    u_goed = 0
    u_n = 0
    for k in range(0, len(idx), batch):
        sub = idx[k:k + batch]
        rijen, seg_id, gek_plat, lengtes = maak_batch(D, sub)
        s, _ = net.forward(Xn[rijen])
        p = segment_softmax(s, seg_id, len(sub))
        tot_loss += w_im * float(-np.log(p[gek_plat] + 1e-12).sum())
        # argmax per segment: eerste index met de max (zelfde regel als GDScript)
        mx = np.full(len(sub), -np.inf)
        np.maximum.at(mx, seg_id, s)
        is_max = s == mx[seg_id]
        eerste = np.zeros(len(sub), dtype=np.int64)
        gezien = np.zeros(len(sub), dtype=bool)
        for i in np.nonzero(is_max)[0]:
            g = seg_id[i]
            if not gezien[g]:
                gezien[g] = True
                eerste[g] = i
        goed += int((eerste == gek_plat).sum())
        # top-3
        rang = np.zeros(len(sub), dtype=np.int64)
        s_gek = s[gek_plat][seg_id]
        beter = (s > s_gek).astype(np.int64)
        np.add.at(rang, seg_id, beter)
        top3 += int((rang < 3).sum())
        won = D["won"][sub]
        bekend = won >= 0
        if bekend.any():
            v = s[gek_plat][bekend]
            y = won[bekend]
            pr = 1.0 / (1.0 + np.exp(-v))
            tot_loss += w_uit * float(-(y * np.log(pr + 1e-12) + (1 - y) * np.log(1 - pr + 1e-12)).sum())
            u_goed += int(((pr > 0.5) == (y > 0.5)).sum())
            u_n += int(bekend.sum())
    n = max(1, len(idx))
    return tot_loss / n, goed / n, top3 / n, (u_goed / u_n if u_n else float("nan")), u_n


def train(D, args):
    rng = np.random.default_rng(args.seed)
    X = D["X"]  # float32: een nachtrun is gigabytes, dus niet verdubbelen
    mu = X.mean(axis=0, dtype=np.float64)
    sigma = X.std(axis=0, dtype=np.float64)
    sigma = np.where(sigma < 1e-6, 1.0, sigma)
    Xn = ((X - mu.astype(np.float32)) / sigma.astype(np.float32)).astype(np.float32)
    n_besl = len(D["gekozen"])
    # Splits op PARTIJ, niet op beslissing: beslissingen uit een partij lijken
    # op elkaar en zouden anders in train en validatie tegelijk zitten.
    partijen = np.unique(D["partij"])
    rng.shuffle(partijen)
    n_val = max(1, int(len(partijen) * args.val))
    val_partijen = set(partijen[:n_val].tolist())
    is_val = np.asarray([p in val_partijen for p in D["partij"]])
    idx_train = np.nonzero(~is_val)[0]
    idx_val = np.nonzero(is_val)[0]
    breedtes = [X.shape[1]] + [int(h) for h in args.verborgen.split(",") if h.strip()] + [1]
    net = MLP(breedtes, rng)
    print(f"[L4] netje {'-'.join(map(str, breedtes))}, {n_besl} beslissingen "
          f"({len(idx_train)} train / {len(idx_val)} validatie, {len(partijen)} partijen), "
          f"{X.shape[0]} kandidaten, gemiddeld {X.shape[0] / n_besl:.1f} per beslissing")
    bekend = int((D['won'] >= 0).sum())
    print(f"[L4] uitslag bekend voor {bekend}/{n_besl} beslissingen; imitatie {args.imitatie}, uitslag {args.uitslag}")
    beste = None
    beste_score = -np.inf
    t0 = time.time()
    for epoch in range(1, args.epochs + 1):
        perm = rng.permutation(idx_train)
        lr = args.lr * (0.5 * (1 + np.cos(np.pi * (epoch - 1) / max(1, args.epochs))) if args.cosine else 1.0)
        for k in range(0, len(perm), args.batch):
            sub = perm[k:k + args.batch]
            rijen, seg_id, gek_plat, lengtes = maak_batch(D, sub)
            s, hs = net.forward(Xn[rijen])
            B = len(sub)
            ds = np.zeros_like(s)
            if args.imitatie > 0:
                p = segment_softmax(s, seg_id, B)
                d_im = p.copy()
                d_im[gek_plat] -= 1.0
                ds += args.imitatie * d_im / B
            if args.uitslag > 0:
                won = D["won"][sub]
                bek = won >= 0
                if bek.any():
                    v = s[gek_plat[bek]]
                    pr = 1.0 / (1.0 + np.exp(-v))
                    ds[gek_plat[bek]] += args.uitslag * (pr - won[bek]) / B
            grads = net.backward(hs, ds)
            net.adam(grads, lr, wd=args.wd)
        tr = evalueer(net, D, Xn, idx_train[:20000], args.imitatie, args.uitslag)
        va = evalueer(net, D, Xn, idx_val, args.imitatie, args.uitslag)
        score = -va[0]
        vlag = ""
        if score > beste_score:
            beste_score = score
            beste = [w.copy() for w in net.W], [b.copy() for b in net.b]
            vlag = " *"
        print(f"[L4] epoch {epoch:3d} lr {lr:.2e} | train loss {tr[0]:.4f} imit {tr[1]*100:5.1f}% top3 {tr[2]*100:5.1f}% "
              f"uitslag {tr[3]*100:5.1f}% | val loss {va[0]:.4f} imit {va[1]*100:5.1f}% top3 {va[2]*100:5.1f}% "
              f"uitslag {va[3]*100:5.1f}% (n={va[4]}) | {time.time() - t0:.0f}s{vlag}")
    net.W, net.b = beste
    va = evalueer(net, D, Xn, idx_val, args.imitatie, args.uitslag)
    # Per factie: waar doet het netje de bot niet na?
    for d in range(6):
        sub = idx_val[D["doctrine"][idx_val] == d]
        if len(sub) == 0:
            continue
        e = evalueer(net, D, Xn, sub, args.imitatie, args.uitslag)
        print(f"[L4]   {DOCTRINE_NAMEN[d]:<9} validatie {len(sub):5d}: imitatie {e[1]*100:5.1f}% top3 {e[2]*100:5.1f}% uitslag {e[3]*100:5.1f}%")
    return net, mu, sigma, va, Xn, idx_val


def schrijf_net(net, mu, sigma, D, va, Xn, idx_val, args, bronnen, rng):
    # Gewichten als float32 wegschrijven en de proef met DIE gewichten rekenen,
    # zodat GDScript (float32-gewichten, double-rekenen) hetzelfde vindt.
    W32 = [w.astype(np.float32) for w in net.W]
    b32 = [b.astype(np.float32) for b in net.b]
    mu32 = mu.astype(np.float32)
    sg32 = sigma.astype(np.float32)
    # Proef: een echte kenmerkrij uit de validatie.
    rij = D["seg"][idx_val[0]] if len(idx_val) else 0
    invoer = D["X"][rij].astype(np.float32)
    h = ((invoer.astype(np.float64) - mu32.astype(np.float64)) / sg32.astype(np.float64))
    for i, (w, b) in enumerate(zip(W32, b32)):
        z = h @ w.astype(np.float64) + b.astype(np.float64)
        h = np.maximum(z, 0.0) if i < len(W32) - 1 else z
    uitvoer = float(h[0])
    doc_tel = {DOCTRINE_NAMEN[d]: int((D["doctrine"] == d).sum()) for d in range(6)}
    data = {
        "versie": 1,
        "kenmerk_versie": int(D["kenmerk_versie"]),
        "kenmerken": int(D["n_kenmerken"]),
        "mu": [float(x) for x in mu32],
        "sigma": [float(x) for x in sg32],
        "lagen": [{"w": w.tolist(), "b": b.tolist()} for w, b in zip(W32, b32)],
        "proef": {"invoer": [float(x) for x in invoer], "uitvoer": uitvoer},
        "meta": {
            "bron": [os.path.relpath(b).replace("\\", "/") for b in bronnen],
            "ts": time.strftime("%Y-%m-%dT%H:%M:%S"),
            "beslissingen": int(len(D["gekozen"])),
            "partijen": int(D["partijen"]),
            "kandidaten": int(D["X"].shape[0]),
            "verborgen": args.verborgen,
            "epochs": args.epochs,
            "imitatie": args.imitatie,
            "uitslag": args.uitslag,
            "val_loss": float(va[0]),
            "val_imitatie_acc": float(va[1]),
            "val_top3_acc": float(va[2]),
            "val_uitslag_acc": (None if np.isnan(va[3]) else float(va[3])),
            "beslissingen_per_doctrine": doc_tel,
            "kenmerk_namen": NAMEN if len(NAMEN) == D["n_kenmerken"] else None,
        },
    }
    os.makedirs(os.path.dirname(os.path.abspath(args.uit)), exist_ok=True)
    with open(args.uit, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, separators=(",", ":"))
    print(f"[L4] geschreven: {args.uit} ({os.path.getsize(args.uit) / 1024:.0f} kB), proef-uitvoer {uitvoer:.6f}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("paden", nargs="+", help="beslissingen.bin of mappen (recursief)")
    ap.add_argument("--uit", default="data/ai_net.json")
    ap.add_argument("--verborgen", default="48,48", help="verborgen lagen, bv 48,48 of 32")
    ap.add_argument("--epochs", type=int, default=15)
    ap.add_argument("--batch", type=int, default=256, help="beslissingen per stap")
    ap.add_argument("--lr", type=float, default=2e-3)
    ap.add_argument("--wd", type=float, default=1e-5, help="weight decay")
    ap.add_argument("--cosine", action="store_true", default=True)
    ap.add_argument("--imitatie", type=float, default=1.0, help="gewicht imitatie-loss")
    ap.add_argument("--uitslag", type=float, default=0.5, help="gewicht uitslag-loss")
    ap.add_argument("--val", type=float, default=0.1, help="deel van de partijen voor validatie")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--max-beslissingen", type=int, default=None, help="per log (snelle proef)")
    ap.add_argument("--doctrine", type=int, default=None, help="alleen beslissingen van deze factie (0..5)")
    args = ap.parse_args()
    bronnen = vind_logs(args.paden)
    if not bronnen:
        print("[L4] geen beslissingen.bin gevonden", file=sys.stderr)
        sys.exit(1)
    logs = []
    for b in bronnen:
        lg = lees_beslislog(b, args.max_beslissingen)
        print(f"[L4] {b}: {len(lg['gekozen'])} beslissingen, {lg['X'].shape[0]} kandidaten, "
              f"{len(lg['uitslag'])} uitslagen, kenmerk-versie {lg['kenmerk_versie']} ({lg['n_kenmerken']})")
        logs.append(lg)
    D = bundel(logs)
    if args.doctrine is not None:
        D = filter_doctrine(D, args.doctrine)
        print(f"[L4] alleen {DOCTRINE_NAMEN[args.doctrine]}: {len(D['gekozen'])} beslissingen")
    if len(D["gekozen"]) < 10:
        print("[L4] te weinig beslissingen om te trainen", file=sys.stderr)
        sys.exit(1)
    net, mu, sigma, va, Xn, idx_val = train(D, args)
    print(f"[L4] beste validatie: loss {va[0]:.4f}, imitatie {va[1]*100:.1f}%, top3 {va[2]*100:.1f}%, "
          f"uitslag {va[3]*100:.1f}% (n={va[4]})")
    schrijf_net(net, mu, sigma, D, va, Xn, idx_val, args, bronnen, np.random.default_rng(args.seed))


if __name__ == "__main__":
    main()

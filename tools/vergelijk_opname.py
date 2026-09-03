# F4.3 — vergelijk twee `-- record`-opnames op wat er toe doet.
#
# Een byte-vergelijking (fc) is nooit leeg: elke opname draagt `meta.created`
# en per entry een wandkloktijd `ts`. Dit script vergelijkt de eind-zobrist,
# de eindstaat en per entry de actie, de events en de hash, en negeert alleen
# die twee tijdvelden. Gebruik:
#
#   python tools/vergelijk_opname.py <voor.json> <na.json>
#
# Zonder argumenten: user://ref_voor.json tegen user://ref_na.json (het
# F4.3-regressiepaar). Exit 0 = gelijk, 1 = verschil, 2 = bestand ontbreekt.
import json
import os
import sys


def user_pad(naam: str) -> str:
    return os.path.join(os.environ.get("APPDATA", ""), "Godot", "app_userdata",
                        "Fog Of War 0.1", naam)


def laad(pad: str) -> dict:
    with open(pad, encoding="utf-8") as f:
        return json.load(f)


def zonder_tijd(entry: dict) -> dict:
    return {k: v for k, v in entry.items() if k != "ts"}


def main() -> int:
    voor = sys.argv[1] if len(sys.argv) > 1 else user_pad("ref_voor.json")
    na = sys.argv[2] if len(sys.argv) > 2 else user_pad("ref_na.json")
    for p in (voor, na):
        if not os.path.exists(p):
            print("[OPNAME] ontbreekt: %s" % p)
            return 2
    a, b = laad(voor), laad(na)
    fouten = []
    if a.get("final_hash") != b.get("final_hash"):
        fouten.append("eind-zobrist: %s != %s" % (a.get("final_hash"), b.get("final_hash")))
    if a.get("final_state") != b.get("final_state"):
        fouten.append("eindstaat verschilt")
    ea, eb = a.get("entries", []), b.get("entries", [])
    if len(ea) != len(eb):
        fouten.append("aantal entries: %d != %d" % (len(ea), len(eb)))
    for i, (x, y) in enumerate(zip(ea, eb)):
        if zonder_tijd(x) != zonder_tijd(y):
            velden = [k for k in set(x) | set(y) if k != "ts" and x.get(k) != y.get(k)]
            fouten.append("entry %d verschilt in %s" % (i, ", ".join(sorted(velden))))
            if len(fouten) > 5:
                break
    ma = {k: v for k, v in a.get("meta", {}).items() if k != "created"}
    mb = {k: v for k, v in b.get("meta", {}).items() if k != "created"}
    if ma != mb:
        fouten.append("meta verschilt (buiten created)")
    if fouten:
        print("[OPNAME] VERSCHIL tussen %s en %s:" % (voor, na))
        for f in fouten:
            print("  - " + f)
        return 1
    print("[OPNAME] GELIJK: %d entries, eind-zobrist %s" % (len(ea), a.get("final_hash", "")[:16]))
    return 0


if __name__ == "__main__":
    sys.exit(main())

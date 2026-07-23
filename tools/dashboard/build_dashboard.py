#!/usr/bin/env python3
"""F1.5 — statisch arena-dashboard.

Leest results/**/games.jsonl, groepeert per run (= top-map onder results/),
en schrijft results/dashboard.html: winrate-matrix-heatmap, totaal-winrates
per doctrine, de bouwplan-§8.2-metrieken en de trend t.o.v. de vorige run.

Gebruik:  python tools/dashboard/build_dashboard.py [--results results] [--out results/dashboard.html]
Geen dependencies buiten de stdlib; geen n8n (werkafspraak B5).
"""

import argparse
import html
import json
import sys
from collections import defaultdict
from pathlib import Path

DOCTRINES = ["mens", "muis", "leeuw", "beer", "wolf", "vos"]


def lees_runs(results_dir: Path):
    """results/<run>/**/games.jsonl -> [{naam, meta, games:[...]}] gesorteerd op ts."""
    runs = {}
    for pad in sorted(set(results_dir.glob("**/games.jsonl"))):
        delen = pad.relative_to(results_dir).parts
        run_naam = delen[0] if len(delen) > 1 else "(root)"
        # Merged root-bestand wint: arena.ps1 voegt proc*/games.jsonl samen tot
        # results/<run>/games.jsonl — de diepere bestanden dan niet dubbel tellen.
        if len(delen) > 2 and (results_dir / run_naam / "games.jsonl").exists():
            continue
        run = runs.setdefault(run_naam, {"naam": run_naam, "meta": None, "games": []})
        # utf-8-sig: PowerShell 5.1 Set-Content schrijft een BOM voor de header.
        with open(pad, encoding="utf-8-sig") as f:
            for regel in f:
                regel = regel.strip()
                if not regel:
                    continue
                try:
                    d = json.loads(regel)
                except json.JSONDecodeError:
                    continue
                if d.get("run_meta"):
                    if run["meta"] is None or str(d.get("ts", "")) > str(run["meta"].get("ts", "")):
                        run["meta"] = d
                else:
                    run["games"].append(d)
    uit = [r for r in runs.values() if r["games"]]
    uit.sort(key=lambda r: str((r["meta"] or {}).get("ts", "")) or r["naam"])
    return uit


def winrates_per_doctrine(games):
    """Totaal-winrate per doctrine over beide kanten; remises tellen als 0.5."""
    score = defaultdict(float)
    n = defaultdict(int)
    for g in games:
        d1, d2, w = g["d1"], g["d2"], g["winner"]
        n[d1] += 1
        n[d2] += 1
        if w == 1:
            score[d1] += 1
        elif w == 2:
            score[d2] += 1
        else:
            score[d1] += 0.5
            score[d2] += 0.5
    return {d: (100.0 * score[d] / n[d]) for d in n}, dict(n)


def matrix(games):
    """(d1, d2) -> {w1, w2, remise} over de gerichte paren."""
    m = defaultdict(lambda: {"w1": 0, "w2": 0, "remise": 0})
    for g in games:
        cel = m[(g["d1"], g["d2"])]
        if g["winner"] == 1:
            cel["w1"] += 1
        elif g["winner"] == 2:
            cel["w2"] += 1
        else:
            cel["remise"] += 1
    return m


def heat_kleur(pct):
    """0% rood -> 50% wit -> 100% groen (P1-kant-winrate)."""
    if pct is None:
        return "#f4f4f4"
    t = max(0.0, min(100.0, pct)) / 100.0
    if t < 0.5:
        f = t / 0.5
        r, gr, b = 235, int(120 + 115 * f), int(120 + 115 * f)
    else:
        f = (t - 0.5) / 0.5
        r, gr, b = int(235 - 145 * f), int(235 - 55 * f), int(235 - 115 * f)
    return f"#{r:02x}{gr:02x}{b:02x}"


def agg_metrieken(games):
    tot = len(games)
    methode = defaultdict(int)
    remise_trigger = defaultdict(int)
    cycli = steps = reps = illegal = fallback = 0
    kanon_pct_som = kanon_pct_n = 0
    statue = defaultdict(int)
    haven_x = defaultdict(int)
    dpa = defaultdict(list)   # doctrine -> schade_per_actie per partij-kant
    opk = defaultdict(list)   # doctrine -> overkill_per_kill
    links = defaultdict(int)
    for g in games:
        methode[g.get("methode", "?")] += 1
        if g.get("remise_trigger"):
            remise_trigger[g["remise_trigger"]] += 1
        cycli += g.get("cycli", 0)
        steps += g.get("steps", 0)
        reps += g.get("repetitions", 0)
        illegal += g.get("illegal", 0)
        fallback += g.get("fallback", 0)
        if g.get("kanonnen", 0) > 0:
            kanon_pct_som += g.get("kanonnen_zonder_schot_pct", 0.0)
            kanon_pct_n += 1
        for profiel, aantal in g.get("statue_kills_by_profile", {}).items():
            statue[profiel] += aantal
        for x in g.get("haven_cells", []):
            haven_x[x] += 1
        spelers = g.get("spelers", {})
        for p, doctrine in (("1", g["d1"]), ("2", g["d2"])):
            st = spelers.get(p, {})
            if st.get("actions", 0) > 0:
                dpa[doctrine].append(st.get("schade_per_actie", 0.0))
            if st.get("kills", 0) > 0:
                opk[doctrine].append(st.get("overkill_per_kill", 0.0))
        for sleutel, aantal in g.get("link_matrix", {}).items():
            # p1_/p2_ -> doctrine zodat de matrix per doctrine leest
            doctrine = g["d1"] if sleutel.startswith("p1_") else g["d2"]
            links[f"{doctrine}:{sleutel[3:]}"] += aantal
    gem = lambda xs: (sum(xs) / len(xs)) if xs else 0.0
    return {
        "totaal": tot,
        "methode": dict(methode),
        "remise_trigger": dict(remise_trigger),
        "gem_cycli": cycli / tot if tot else 0,
        "gem_steps": steps / tot if tot else 0,
        "gem_repetitions": reps / tot if tot else 0,
        "illegal": illegal,
        "fallback": fallback,
        "kanon_zonder_schot_pct": (kanon_pct_som / kanon_pct_n) if kanon_pct_n else 0.0,
        "statue_kills": dict(sorted(statue.items(), key=lambda kv: -kv[1])),
        "haven_x": dict(sorted(haven_x.items())),
        "dpa": {d: gem(v) for d, v in dpa.items()},
        "opk": {d: gem(v) for d, v in opk.items()},
        "links": dict(sorted(links.items(), key=lambda kv: -kv[1])[:24]),
    }


def esc(s):
    return html.escape(str(s))


def bouw_html(runs):
    huidig = runs[-1]
    meta = huidig["meta"] or {}
    # Trendbasis: de nieuwste EERDERE run met dezelfde agent-instellingen —
    # een L2-matrix vergelijken met een L1-testje geeft schijn-trends.
    cfg = meta.get("config") or {}
    sleutel = (cfg.get("agents", {}), cfg.get("matchups"))
    vorig = None
    for r in reversed(runs[:-1]):
        r_cfg = ((r["meta"] or {}).get("config") or {})
        if (r_cfg.get("agents", {}), r_cfg.get("matchups")) == sleutel:
            vorig = r
            break
    games = huidig["games"]
    wr, wn = winrates_per_doctrine(games)
    m = matrix(games)
    met = agg_metrieken(games)
    wr_vorig = winrates_per_doctrine(vorig["games"])[0] if vorig else {}

    doctrines = [d for d in DOCTRINES if d in wn] + sorted(set(wn) - set(DOCTRINES))

    delen = []
    delen.append(f"""<!DOCTYPE html><html lang="nl"><head><meta charset="utf-8">
<title>Fog of War — arena-dashboard</title>
<style>
 body {{ font-family: system-ui, sans-serif; margin: 24px; background: #fafafa; color: #222; }}
 h1 {{ margin-bottom: 4px; }} h2 {{ margin-top: 28px; }}
 .meta {{ color: #666; font-size: 0.9em; }}
 table {{ border-collapse: collapse; margin-top: 8px; }}
 th, td {{ border: 1px solid #ccc; padding: 5px 9px; text-align: center; font-size: 0.92em; }}
 th {{ background: #eee; }}
 td.l {{ text-align: left; }}
 .sub {{ color: #555; font-size: 0.8em; }}
 .up {{ color: #0a7d32; }} .down {{ color: #b3261e; }}
 .warn {{ background: #ffe9a8; }}
 .grid {{ display: flex; flex-wrap: wrap; gap: 32px; }}
</style></head><body>
<h1>Fog of War — arena-dashboard</h1>
<p class="meta">Run <b>{esc(huidig["naam"])}</b> · {esc(meta.get("ts", "?"))} · git {esc(meta.get("git_sha", "?"))}
 · regels <b>{esc(meta.get("rules_version", "?"))}</b> · {met["totaal"]} partijen
 · agents {esc(json.dumps((meta.get("config") or {}).get("agents", {})))}
 {f"· trend t.o.v. <b>{esc(vorig['naam'])}</b> ({len(vorig['games'])} partijen)" if vorig else "· nog geen vorige run voor trend"}</p>""")

    # Totaal-winrates + trend
    delen.append("<h2>Totaal-winrate per doctrine</h2><table><tr><th>Doctrine</th><th>Winrate</th><th>Partijen</th><th>Trend</th></tr>")
    for d in doctrines:
        pct = wr[d]
        trend = ""
        if d in wr_vorig:
            dpct = pct - wr_vorig[d]
            cls = "up" if dpct >= 0 else "down"
            trend = f'<span class="{cls}">{dpct:+.1f} pp</span>'
        warn = ' class="warn"' if pct < 25 or pct > 75 else ""
        delen.append(f'<tr{warn}><td class="l">{esc(d)}</td>'
                     f'<td style="background:{heat_kleur(pct)}">{pct:.1f}%</td>'
                     f"<td>{wn[d]}</td><td>{trend}</td></tr>")
    delen.append('</table><p class="sub">Geel = buiten het F1.6-werkdoel (25–75%). Remises tellen als 0.5.</p>')

    # Matrix-heatmap
    delen.append("<h2>Winrate-matrix (gerichte paren, % voor de P1-kant)</h2><table><tr><th>P1 \\ P2</th>")
    delen.append("".join(f"<th>{esc(d)}</th>" for d in doctrines) + "</tr>")
    for d1 in doctrines:
        delen.append(f'<tr><th>{esc(d1)}</th>')
        for d2 in doctrines:
            cel = m.get((d1, d2))
            if not cel:
                delen.append('<td style="background:#f4f4f4">–</td>')
                continue
            n = cel["w1"] + cel["w2"] + cel["remise"]
            pct = 100.0 * (cel["w1"] + 0.5 * cel["remise"]) / n
            delen.append(f'<td style="background:{heat_kleur(pct)}">{pct:.0f}%'
                         f'<div class="sub">{cel["w1"]}/{cel["w2"]}/{cel["remise"]}</div></td>')
        delen.append("</tr>")
    delen.append('</table><p class="sub">Celtekst: winst P1-kant / winst P2-kant / remise.</p>')

    # §8-metrieken
    delen.append('<h2>Metrieken (bouwplan §8.2)</h2><div class="grid">')
    delen.append("<div><h3>Uitkomsten</h3><table><tr><th>Methode</th><th>Aantal</th></tr>")
    for k, v in sorted(met["methode"].items(), key=lambda kv: -kv[1]):
        delen.append(f'<tr><td class="l">{esc(k)}</td><td>{v}</td></tr>')
    for k, v in met["remise_trigger"].items():
        delen.append(f'<tr><td class="l sub">remise via {esc(k)}</td><td class="sub">{v}</td></tr>')
    delen.append(f"""</table>
<p class="sub">Gem. cycli {met["gem_cycli"]:.1f} · gem. acties {met["gem_steps"]:.0f} ·
 gem. zobrist-herhalingen {met["gem_repetitions"]:.1f} (standoff-signaal)<br>
 illegale keuzes {met["illegal"]} · fallbacks {met["fallback"]} (horen 0 te zijn)<br>
 kanonnen zonder schot: {met["kanon_zonder_schot_pct"]:.1f}% (geblokkeerde intenties)</p></div>""")

    delen.append("<div><h3>Schade per actie / overkill per kill</h3><table><tr><th>Doctrine</th><th>Schade/actie</th><th>Overkill/kill</th></tr>")
    for d in doctrines:
        delen.append(f'<tr><td class="l">{esc(d)}</td><td>{met["dpa"].get(d, 0):.2f}</td><td>{met["opk"].get(d, 0):.2f}</td></tr>')
    delen.append('</table><p class="sub">Overkill = verspilde Attack (Leeuw-spiraal); schade/actie is de Muis-meter.</p></div>')

    delen.append("<div><h3>Standbeeld-kills per kaartprofiel</h3><table><tr><th>Profiel (hp/spd/atk)</th><th>Kills</th></tr>")
    for k, v in list(met["statue_kills"].items())[:12]:
        delen.append(f'<tr><td class="l">{esc(k)}</td><td>{v}</td></tr>')
    delen.append('</table><p class="sub">De 1/5/1-oogst-vraag: goedkope kaarten die standbeelden maaien.</p>')
    delen.append("<h3>Winnende havenvakken (x)</h3><table><tr><th>Kolom x</th><th>Aantal</th></tr>")
    for k, v in met["haven_x"].items():
        delen.append(f"<tr><td>{esc(k)}</td><td>{v}</td></tr>")
    delen.append('</table><p class="sub">Hoekfort-check: winnen havens vooral in de hoeken?</p></div>')

    delen.append("<div><h3>Koppelingen kaartprofiel → type</h3><table><tr><th>Doctrine: profiel→type</th><th>Aantal</th></tr>")
    for k, v in met["links"].items():
        delen.append(f'<tr><td class="l">{esc(k)}</td><td>{v}</td></tr>')
    delen.append("</table></div></div>")

    # Runs-historie
    delen.append("<h2>Runs</h2><table><tr><th>Run</th><th>ts</th><th>git</th><th>Regels</th><th>Partijen</th></tr>")
    for r in reversed(runs):
        rm = r["meta"] or {}
        delen.append(f'<tr><td class="l">{esc(r["naam"])}</td><td>{esc(rm.get("ts", "?"))}</td>'
                     f'<td>{esc(rm.get("git_sha", "?"))}</td><td>{esc(rm.get("rules_version", "?"))}</td>'
                     f"<td>{len(r['games'])}</td></tr>")
    delen.append("</table></body></html>")
    return "".join(delen)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--results", default="results")
    ap.add_argument("--out", default=None)
    args = ap.parse_args()
    results_dir = Path(args.results)
    out = Path(args.out) if args.out else results_dir / "dashboard.html"
    runs = lees_runs(results_dir)
    if not runs:
        print(f"[DASHBOARD] geen games.jsonl gevonden onder {results_dir}/ — niets te bouwen", file=sys.stderr)
        return 1
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(bouw_html(runs), encoding="utf-8")
    totaal = sum(len(r["games"]) for r in runs)
    print(f"[DASHBOARD] {out} — {len(runs)} run(s), {totaal} partijen, nieuwste: {runs[-1]['naam']} ({len(runs[-1]['games'])} partijen)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

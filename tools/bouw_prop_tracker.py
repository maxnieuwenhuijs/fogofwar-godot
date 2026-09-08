# -*- coding: utf-8 -*-
"""Bouwt prop-tracker.html: per scene zien welke diorama-props er liggen.

    python tools/bouw_prop_tracker.py

Leest drie bronnen en verzint zelf niets:
  - PROP-WISHLIST.md            de lijst (scene, wat, team, klik, prompt)
  - assets/models/props/**.glb  wat er ECHT ligt: prop_<naam>.glb (gedeeld),
                                prop_<naam>_red.glb / _blue.glb (per team)
  - assets/models/bewoners/**   de poppetjes (glb of json), <rol>_<factie>[_team]

De status in de wishlist-kolom is alleen de stand van de dag dat hij geschreven
werd; de tracker rekent zelf: ✓ als het bestand er ligt (per team apart), ⚙ als
de wishlist zegt dat het spel hem procedureel bouwt, ➕ anders. Paneelknop:
"Welke props ontbreken?".
"""
import collections
import html
import io
import os
import re
import sys

# de Windows-console is cp1252: de symbolen in de samenvatting zouden anders crashen
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(REPO)
WISHLIST = "PROP-WISHLIST.md"
UIT = "prop-tracker.html"
PROPS_DIR = os.path.join("assets", "models", "props")
BEWONERS_DIR = os.path.join("assets", "models", "bewoners")
FACTIES = ["mouse", "pig", "lion", "bear", "wolf", "crocodile"]
TEAMS = ["red", "blue"]


def bestanden(map_, ext):
    uit = set()
    for r, _, fs in os.walk(map_):
        for f in fs:
            if f.lower().endswith(ext):
                uit.add(os.path.splitext(f)[0].lower())
    return uit


def lees_wishlist():
    """Secties met hun tabellen. Rij = dict(bestand, wat, team, klik, status, prompt)."""
    secties = []
    huidige = None
    with io.open(WISHLIST, encoding="utf-8") as f:
        for regel in f:
            regel = regel.rstrip("\n")
            m = re.match(r"^## (.+)$", regel)
            if m:
                huidige = {"titel": m.group(1).strip(), "rijen": []}
                secties.append(huidige)
                continue
            if huidige is None or not regel.startswith("|"):
                continue
            cellen = [c.strip() for c in regel.strip().strip("|").split("|")]
            if len(cellen) < 5 or cellen[0].startswith("---") or cellen[0] in ("Bestand",):
                continue
            naam = cellen[0].strip("`")
            if not naam or naam == "Bestand":
                continue
            rij = {"bestand": naam, "wat": cellen[1], "team": cellen[2].lower(),
                   "klik": cellen[3], "status": cellen[4],
                   "prompt": cellen[5] if len(cellen) > 5 else ""}
            huidige["rijen"].append(rij)
    return [s for s in secties if s["rijen"]]


def status_van(rij, props, bewoners):
    """Per team (of gedeeld) wat er ligt. Geeft (symbool, uitleg, per_team)."""
    naam = rij["bestand"].lower()
    is_bewoner = "<factie>" in naam or naam in bewoners or any(
        b.startswith(naam + "_") or b == naam for b in bewoners)
    per_team = {}
    if is_bewoner:
        # per factie tellen: peasant_<factie> -> peasant_mouse, peasant_mouse_red ...
        basis = naam.replace("<factie>", "")
        basis = basis.rstrip("_")
        gevonden = sorted(b for b in bewoners if b == basis or b.startswith(basis + "_") or b.startswith(basis))
        if "<factie>" in naam:
            for fac in FACTIES:
                heeft = [b for b in bewoners if b.startswith("%s_%s" % (basis, fac))]
                per_team[fac] = bool(heeft)
            n = sum(1 for v in per_team.values() if v)
            if n == len(FACTIES):
                return "✓", "alle facties", per_team
            if n:
                return "½", "%d van %d facties" % (n, len(FACTIES)), per_team
        elif gevonden:
            return "✓", ", ".join(gevonden), per_team
    else:
        gedeeld = naam in props
        for t in TEAMS:
            per_team[t] = ("%s_%s" % (naam, t)) in props
        if rij["team"] == "beide":
            if all(per_team.values()):
                return "✓", "rood en blauw", per_team
            if gedeeld and not any(per_team.values()):
                return "½", "alleen een gedeelde glb (geen arm/rijk-variant)", per_team
            if any(per_team.values()):
                return "½", ", ".join(t for t in TEAMS if per_team[t]) + " ligt er", per_team
        elif rij["team"] in TEAMS:
            if per_team[rij["team"]] or gedeeld:
                return "✓", "ligt er", per_team
        else:
            if gedeeld or any(per_team.values()):
                return "✓", "ligt er", per_team
    if "⚙" in rij["status"]:
        return "⚙", "placeholder uit primitieven in omgeving.gd", per_team
    return "➕", "nog maken", per_team


def bouw():
    props = bestanden(PROPS_DIR, ".glb")
    bewoners = bestanden(BEWONERS_DIR, ".glb") | bestanden(BEWONERS_DIR, ".json")
    secties = lees_wishlist()
    totaal = collections.Counter()
    for s in secties:
        s["tel"] = collections.Counter()
        for rij in s["rijen"]:
            sym, uitleg, per_team = status_van(rij, props, bewoners)
            rij["sym"] = sym
            rij["uitleg"] = uitleg
            rij["per_team"] = per_team
            s["tel"][sym] += 1
            totaal[sym] += 1
    return secties, totaal, len(props), len(bewoners)


def schrijf(secties, totaal, n_props, n_bewoners):
    def esc(s):
        return html.escape(str(s), quote=True)

    alles = sum(totaal.values())
    klaar = totaal["✓"]
    delen = []
    delen.append("""<!DOCTYPE html>
<html lang="nl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Fog of War - Prop Tracker</title>
<style>
  :root {
    --bg:#14161c; --panel:#1c1f28; --panel2:#232734; --line:#303646;
    --text:#d8dce8; --dim:#8a91a5; --accent:#e8b84b; --ok:#4caf7d; --mist:#c9556b;
    --half:#d9a441; --proc:#5a86c9; --rood:#c9556b; --blauw:#5a86c9;
  }
  * { box-sizing: border-box; }
  body { margin:0; padding:0 0 60px; background:var(--bg); color:var(--text);
         font:14px/1.5 system-ui,"Segoe UI",sans-serif; }
  header { position:sticky; top:0; z-index:50; background:var(--bg);
           border-bottom:1px solid var(--line); padding:12px 20px; }
  header h1 { margin:0 0 8px; font-size:18px; letter-spacing:.5px; }
  header h1 span { color:var(--accent); }
  .bar { height:14px; background:var(--panel2); border-radius:7px; overflow:hidden;
         border:1px solid var(--line); max-width:420px; }
  .bar > i { display:block; height:100%; background:linear-gradient(90deg,#b98a2e,var(--accent)); }
  .barlabel { font-size:12px; color:var(--dim); margin-top:4px; }
  .legenda { font-size:12px; color:var(--dim); margin-top:6px; }
  .legenda b { color:var(--text); font-weight:600; }
  main { max-width:1180px; margin:0 auto; padding:20px; }
  .intro { color:var(--dim); font-size:13px; margin:0 0 18px; }
  .intro b.rood { color:var(--rood); } .intro b.blauw { color:var(--blauw); }
  section { background:var(--panel); border:1px solid var(--line); border-radius:8px;
            margin-bottom:22px; overflow:hidden; border-top:3px solid var(--accent); }
  .fkop { display:flex; gap:14px; align-items:baseline; padding:13px 18px; }
  .fkop h2 { margin:0; font-size:17px; color:var(--accent); }
  .fkop .tel { color:var(--dim); font-size:12.5px; }
  table { width:100%; border-collapse:collapse; font-size:13px; }
  th,td { text-align:left; padding:7px 10px; border-top:1px solid var(--line); vertical-align:top; }
  th { color:var(--dim); font-weight:600; font-size:12px; }
  td.cat { font-family:ui-monospace,Consolas,monospace; font-size:12px; white-space:nowrap; }
  .s { font-weight:700; white-space:nowrap; }
  .s.ok { color:var(--ok); } .s.nee { color:var(--mist); } .s.half { color:var(--half); } .s.proc { color:var(--proc); }
  .team { font-size:11px; padding:1px 7px; border-radius:10px; border:1px solid var(--line); color:var(--dim); white-space:nowrap; }
  .team.rood { border-color:var(--rood); color:var(--rood); }
  .team.blauw { border-color:var(--blauw); color:var(--blauw); }
  .team.beide { border-color:var(--accent); color:var(--accent); }
  .uitleg { color:var(--dim); font-size:12px; }
  .prompt { color:var(--dim); font-size:11.5px; font-family:ui-monospace,Consolas,monospace;
            display:block; margin-top:4px; cursor:pointer; }
  .prompt:hover { color:var(--accent); }
  .pt { display:flex; gap:4px; margin-top:4px; flex-wrap:wrap; }
  .pt span { font-size:11px; padding:1px 6px; border-radius:10px; background:var(--panel2); color:var(--dim); }
  .pt span.ja { color:var(--ok); }
</style>
</head>
""")
    delen.append("""<body>
<header>
  <h1>Fog of War <span>Prop Tracker</span></h1>
  <div class="bar"><i style="width:%d%%"></i></div>
  <div class="barlabel">%d van %d props klaar (✓), %d half, %d placeholder (⚙), %d nog maken (➕). Op schijf: %d glb's in props/, %d bewoners.</div>
  <div class="legenda"><b>✓</b> glb ligt er (bij "beide": rood en blauw) · <b>½</b> een deel (bv. alleen de gedeelde glb) ·
  <b>⚙</b> het spel bouwt hem nu uit primitieven · <b>➕</b> nog maken. Klik op een prompt om hem te kopieren.</div>
</header>
<main>
<p class="intro">Kamp vooraan = jij, overkant = de tegenstander, elk in de kleur van zijn team:
<b class="rood">rood is armoede</b> (gelapt, touw, roest, modder) en <b class="blauw">blauw is pompeus en rijk</b>
(verguld, blauw laken met goudgalon, zilver). Bestand: <code>assets/models/props/prop_&lt;naam&gt;.glb</code>,
team-variant <code>prop_&lt;naam&gt;_red.glb</code> / <code>_blue.glb</code>; poppetjes in <code>assets/models/bewoners/</code>.
Maat: ware grootte, een tegel is 1, een pion 0,62 hoog. Bron: PROP-WISHLIST.md.</p>
""" % (int(round(100.0 * klaar / max(alles, 1))), klaar, alles, totaal["½"], totaal["⚙"], totaal["➕"], n_props, n_bewoners))
    stijl = {"rood": "worn, patched, poor, rope and rough wood, rust and mud",
             "blauw": "ornate, gilded, blue cloth with gold trim, polished, wealthy"}
    for s in secties:
        t = s["tel"]
        delen.append('<section><div class="fkop"><h2>%s</h2><span class="tel">✓ %d · ½ %d · ⚙ %d · ➕ %d</span></div>'
                     % (esc(s["titel"]), t["✓"], t["½"], t["⚙"], t["➕"]))
        delen.append("<table><tr><th>Status</th><th>Bestand</th><th>Wat</th><th>Team</th><th>Klik</th><th>Prompt</th></tr>")
        for rij in s["rijen"]:
            sym = rij["sym"]
            klasse = {"✓": "ok", "➕": "nee", "½": "half", "⚙": "proc"}.get(sym, "")
            team = rij["team"]
            teamklasse = team if team in ("rood", "blauw", "beide") else ""
            pt = ""
            if rij["per_team"]:
                pt = '<div class="pt">' + "".join(
                    '<span class="%s">%s %s</span>' % ("ja" if v else "", esc(k), "✓" if v else "➕")
                    for k, v in rij["per_team"].items() if (team == "beide" or team == k or k in FACTIES)) + "</div>"
            prompt = rij["prompt"]
            prompts = []
            if prompt:
                basis = "low-poly game prop, 18th century military camp, %s, single object, clean silhouette, baked albedo texture, no ground plane, no text" % prompt
                if team == "beide":
                    for kant in ("rood", "blauw"):
                        prompts.append((kant, "low-poly game prop, 18th century military camp, %s, %s, single object, clean silhouette, baked albedo texture, no ground plane, no text" % (prompt, stijl[kant])))
                elif team in stijl:
                    prompts.append((team, "low-poly game prop, 18th century military camp, %s, %s, single object, clean silhouette, baked albedo texture, no ground plane, no text" % (prompt, stijl[team])))
                else:
                    prompts.append(("", basis))
            prompt_html = "".join(
                '<span class="prompt" title="klik = kopieren" onclick="navigator.clipboard.writeText(this.textContent)">%s%s</span>'
                % (("[%s] " % esc(k)) if k else "", esc(p)) for k, p in prompts)
            delen.append('<tr><td><span class="s %s">%s</span><div class="uitleg">%s</div>%s</td>'
                         '<td class="cat">%s</td><td>%s</td><td><span class="team %s">%s</span></td>'
                         '<td class="uitleg">%s</td><td>%s</td></tr>'
                         % (klasse, esc(sym), esc(rij["uitleg"]), pt, esc(rij["bestand"]), esc(rij["wat"]),
                            teamklasse, esc(team), esc(rij["klik"]), prompt_html))
        delen.append("</table></section>")
    delen.append("</main></body></html>\n")
    with io.open(UIT, "w", encoding="utf-8") as f:
        f.write("".join(delen))


def main():
    if not os.path.exists(WISHLIST):
        print("Geen %s gevonden" % WISHLIST)
        return 1
    secties, totaal, n_props, n_bewoners = bouw()
    schrijf(secties, totaal, n_props, n_bewoners)
    alles = sum(totaal.values())
    print("prop-tracker.html: %d props in %d scenes; ✓ %d, ½ %d, ⚙ %d, ➕ %d (props/ %d glb, bewoners %d)"
          % (alles, len(secties), totaal["✓"], totaal["½"], totaal["⚙"], totaal["➕"], n_props, n_bewoners))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

"""Bouwt sound-tracker.html: per factie zien wat er aan geluid ligt en wat niet.

    python tools/bouw_geluid_tracker.py

Leest twee bronnen en verzint zelf niets:
  - sounds/**.wav   welke categorieen er ECHT zijn (net als de engine: een
                    achtervoegsel _2, _3 is een variant van dezelfde categorie)
  - SOUND-WISHLIST.md   de ElevenLabs-prompt per bestand

Daardoor kan hij niet verouderen: neem je een geluid op, dan wordt het vakje
groen zodra je dit script opnieuw draait. Staat er een prompt in de wishlist die
nog geen bestand heeft, dan zie je hem hier met de prompt erbij om te kopieren.
"""
import io
import os
import re
import glob
import json
import html
import collections

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(REPO)

FACTIES = [
    ("mouse", "Muis", "#c9a227"),
    ("pig", "Varken", "#d98cb3"),
    ("lion", "Leeuw", "#e0913a"),
    ("bear", "Beer", "#8d6748"),
    ("wolf", "Wolf", "#7f92a8"),
    ("crocodile", "Krokodil", "#5f9e6e"),
]

# Wat een factie MOET hebben. De volgorde is de aanraadvolgorde: de kanonkreet
# gilt altijd en hoor je dus het vaakst, de rest klinkt op kans (kreet_kans).
BASIS = [
    ("inf_kanon_die", "Kanontreffer", "Gilt ALTIJD. Hoor je het vaakst, dus begin hier."),
    ("inf_die", "Infanterie sterft", "Op kans (kreet_kans, standaard 15%)."),
    ("horse_die", "Big bro sterft", "De cavalerie: rat, everzwijn, leeuw, grizzly, dire wolf, krokodil."),
    ("cannon_die", "Kanon kapot", "Geen dier: hout dat splijt en ijzer dat knapt."),
]
ARCHETYPES = ["base", "spd", "hp", "atk", "mix"]
# Alleen deze twee kennen archetype-varianten (zie wishlist par. 7b-2).
MET_ARCHETYPE = ["inf_die", "inf_kanon_die"]


def gevonden_categorieen():
    """Categorie -> aantal varianten, precies zoals AudioManager ze groepeert."""
    uit = collections.Counter()
    for pad in glob.glob("sounds/**/*.wav", recursive=True):
        kaal = os.path.splitext(os.path.basename(pad))[0]
        delen = kaal.rsplit("_", 1)
        if len(delen) == 2 and delen[1].isdigit():
            kaal = delen[0]
        uit[kaal] += 1
    return uit


def prompts_uit_wishlist():
    """Bestandsnaam -> ElevenLabs-prompt, uit de tabellen in de wishlist."""
    uit = {}
    if not os.path.exists("SOUND-WISHLIST.md"):
        return uit
    for regel in io.open("SOUND-WISHLIST.md", encoding="utf-8"):
        m = re.match(r"^\|\s*`([a-z0-9_]+)`[^|]*\|\s*(.+?)\s*\|\s*$", regel)
        if m:
            uit.setdefault(m.group(1), m.group(2))
    return uit


def bouw():
    heeft = gevonden_categorieen()
    prompts = prompts_uit_wishlist()
    facties = []
    totaal_moet = totaal_heeft = 0
    for sleutel, naam, kleur in FACTIES:
        rijen = []
        f_moet = f_heeft = 0
        for cat, label, uitleg in BASIS:
            naam_cat = "%s_%s" % (cat, sleutel)
            n = heeft.get(naam_cat, 0)
            extra = []
            if cat in MET_ARCHETYPE:
                for a in ARCHETYPES:
                    an = "%s_%s_%s" % (cat, sleutel, a)
                    extra.append({"naam": a, "n": heeft.get(an, 0),
                                  "bestand": an, "prompt": prompts.get(an, "")})
            # Zijn ALLE archetypes er, dan wordt de factie-categorie nooit
            # bereikt: de keten pakt eerst het model-geluid. Dan is die factie
            # gewoon gedekt, ook zonder los factie-bestand (muis doet dat zo).
            via_modellen = bool(extra) and all(a["n"] for a in extra)
            f_moet += 1
            f_heeft += 1 if (n or via_modellen) else 0
            rijen.append({
                "categorie": naam_cat, "label": label, "uitleg": uitleg,
                "n": n, "via_modellen": via_modellen,
                "prompt": prompts.get(naam_cat, ""), "archetypes": extra,
            })
        totaal_moet += f_moet
        totaal_heeft += f_heeft
        facties.append({"sleutel": sleutel, "naam": naam, "kleur": kleur,
                        "rijen": rijen, "moet": f_moet, "heeft": f_heeft})
    return facties, totaal_moet, totaal_heeft


def schrijf(facties, moet, heeft):
    def esc(s):
        return html.escape(str(s), quote=True)

    kop = """<!DOCTYPE html>
<html lang="nl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Fog of War - Geluid Tracker</title>
<style>
  :root {
    --bg:#14161c; --panel:#1c1f28; --panel2:#232734; --line:#303646;
    --text:#d8dce8; --dim:#8a91a5; --accent:#e8b84b; --ok:#4caf7d; --mist:#c9556b;
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
  main { max-width:1100px; margin:0 auto; padding:20px; }
  section { background:var(--panel); border:1px solid var(--line); border-radius:8px;
            margin-bottom:22px; overflow:hidden; border-top:3px solid var(--fc); }
  .fkop { display:flex; gap:14px; align-items:baseline; padding:13px 18px; }
  .fkop h2 { margin:0; font-size:17px; color:var(--fc); }
  .fkop .tel { color:var(--dim); font-size:12.5px; }
  table { width:100%; border-collapse:collapse; font-size:13px; }
  th,td { text-align:left; padding:7px 10px; border-top:1px solid var(--line);
          vertical-align:top; }
  th { color:var(--dim); font-weight:600; font-size:12px; }
  td.cat { font-family:ui-monospace,Consolas,monospace; font-size:12px; white-space:nowrap; }
  .ja { color:var(--ok); font-weight:600; white-space:nowrap; }
  .nee { color:var(--mist); font-weight:600; white-space:nowrap; }
  .uitleg { color:var(--dim); font-size:12px; }
  .prompt { color:var(--dim); font-size:11.5px; font-family:ui-monospace,Consolas,monospace;
            display:block; margin-top:4px; cursor:pointer; }
  .prompt:hover { color:var(--accent); }
  .arch { margin-top:5px; display:flex; flex-wrap:wrap; gap:5px; }
  .arch span { font-size:11px; padding:1px 7px; border-radius:10px;
               border:1px solid var(--line); background:var(--panel2); }
  .arch span.ja { border-color:var(--ok); }
  .voet { color:var(--dim); font-size:12px; max-width:1100px; margin:0 auto; padding:0 20px; }
</style>
</head>
<body>
<header>
  <h1>Fog of War <span>Geluid Tracker</span></h1>
  <div class="bar"><i style="width:__PCT__%"></i></div>
  <div class="barlabel">__HEEFT__ van __MOET__ factie-geluiden aanwezig (__PCT__%).
    Klik een prompt om hem te kopieren.</div>
</header>
<main>
"""
    pct = int(round(100.0 * heeft / max(moet, 1)))
    uit = [kop.replace("__PCT__", str(pct)).replace("__HEEFT__", str(heeft)).replace("__MOET__", str(moet))]
    for f in facties:
        uit.append('<section style="--fc:%s">' % f["kleur"])
        uit.append('<div class="fkop"><h2>%s</h2><div class="tel">%s &middot; %d van %d</div></div>'
                   % (esc(f["naam"]), esc(f["sleutel"]), f["heeft"], f["moet"]))
        uit.append("<table><thead><tr><th>Wat</th><th>Bestand</th><th>Status</th>"
                   "<th>Prompt / toelichting</th></tr></thead><tbody>")
        for r in f["rijen"]:
            if r["n"]:
                status = '<span class="ja">%d varianten</span>' % r["n"]
            elif r.get("via_modellen"):
                status = '<span class="ja">via de 5 modellen</span>'
            else:
                status = '<span class="nee">ontbreekt</span>'
            cel = '<div class="uitleg">%s</div>' % esc(r["uitleg"])
            if r["prompt"]:
                cel += '<code class="prompt" onclick="kopieer(this)">%s</code>' % esc(r["prompt"])
            if r["archetypes"]:
                bolletjes = "".join(
                    '<span class="%s" title="%s">%s%s</span>' % (
                        "ja" if a["n"] else "", esc(a["bestand"]), esc(a["naam"]),
                        (" %d" % a["n"]) if a["n"] else "")
                    for a in r["archetypes"])
                cel += '<div class="arch">per model: %s</div>' % bolletjes
            uit.append("<tr><td>%s</td><td class=\"cat\">%s</td><td>%s</td><td>%s</td></tr>"
                       % (esc(r["label"]), esc(r["categorie"]), status, cel))
        uit.append("</tbody></table></section>")
    uit.append("""</main>
<div class="voet">
  <p><b>Terugval:</b> ontbreekt een factie-geluid, dan leent het spel dat van de
  muis, en pas daarna het algemene geluid. Niets gaat stuk zolang een factie nog
  niets heeft, maar je grizzly gilt dan wel als een muis.</p>
  <p><b>Waar zet je ze neer:</b> <code>sounds/factions/&lt;factie&gt;/</code>.
  De mapindeling is vrij; het spel zoekt op bestandsnaam. Meerdere takes:
  <code>inf_die_pig.wav</code>, <code>inf_die_pig_2.wav</code>, ...</p>
  <p>Opnieuw opbouwen: <code>python tools/bouw_geluid_tracker.py</code></p>
</div>
<script>
function kopieer(el){
  navigator.clipboard.writeText(el.textContent).then(function(){
    var oud = el.style.color; el.style.color = "#4caf7d";
    setTimeout(function(){ el.style.color = oud; }, 600);
  });
}
</script>
</body>
</html>
""")
    io.open("sound-tracker.html", "w", encoding="utf-8", newline="\n").write("\n".join(uit))


if __name__ == "__main__":
    facties, moet, heeft = bouw()
    schrijf(facties, moet, heeft)
    print("sound-tracker.html: %d van %d factie-geluiden aanwezig" % (heeft, moet))
    for f in facties:
        ontbreekt = [r["categorie"] for r in f["rijen"] if not r["n"] and not r.get("via_modellen")]
        print("  %-10s %d/%d%s" % (f["naam"], f["heeft"], f["moet"],
              ("   mist: " + ", ".join(ontbreekt)) if ontbreekt else ""))

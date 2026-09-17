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
import hashlib
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

# Categorieen die alleen bestaan als de factie dat eenheidstype ook HEEFT.
# Sinds C19 (8 augustus) hebben Muis en Beer nul artillerie in hun comp, en
# `GameState.kent_type()` verbiedt ze dan ook een kanon te spawnen. Een
# `cannon_die_bear` zou dus nooit klinken: die vragen we niet meer.
ALLEEN_BIJ_TYPE = {"cannon_die": 2}   # 2 = artillerie-slot in comp [inf,cav,art]

REGELS_BESTAND = "arena/arena_configs/rules_v42_campaign.json"


def actieve_comps():
    """Naam -> comp [inf,cav,art], zoals het spel hem NU opstelt.

    Kale tabel uit `constants.gd` (die staat in doctrine-volgorde MENS, MUIS,
    LEEUW, BEER, WOLF, VOS = index 0 t/m 5), met het `doctrines`-blok uit het
    regels-bestand eroverheen. Precies wat `-- facties` laat zien.
    """
    kaal = []
    try:
        bron = io.open("scripts/core/constants.gd", encoding="utf-8").read()
    except OSError:
        return {}
    for m in re.finditer(r'"name":\s*"([^"]+)".*?"comp":\s*\[(\d+),\s*(\d+),\s*(\d+)\]',
                         bron, re.S):
        kaal.append([m.group(1), [int(m.group(2)), int(m.group(3)), int(m.group(4))]])
    try:
        blok = (json.load(io.open(REGELS_BESTAND, encoding="utf-8")) or {}).get("doctrines") or {}
    except (OSError, ValueError):
        blok = {}
    uit = {}
    for i, (naam, comp) in enumerate(kaal):
        ov = blok.get(str(i)) or {}
        uit[naam] = [int(n) for n in ov.get("comp", comp)]
    return uit


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


# --- de props van het diorama (12 september) -------------------------------------
# Engelse ElevenLabs-prompts per prop-categorie (recept uit de wishlist: kort,
# droog, het materiaal benoemen, zes takes achter elkaar). De Nederlandse
# omschrijving uit SOUND-WISHLIST sectie 11 staat er als toelichting bij.
PROP_PROMPT_EN = {
    "prop_tik": "short dry wooden tap, small knock on a wooden game piece, no reverb",
    "prop_bel": "small brass bell struck once, clear ding with a short ringing tail, 18th century camp bell",
    "prop_glas": "two glass bottles clinking together, short bright clink, no reverb",
    "prop_aambeeld": "blacksmith hammer striking an anvil once, sharp metallic clang, short",
    "prop_kookpot": "iron lid dropped onto an iron cooking pot, dull bong, short",
    "prop_trom": "single hit on a military snare drum skin, dry and dull, no roll",
    "prop_ton": "knock on an empty wooden barrel, hollow wooden bonk, short",
    "prop_hoorn": "short signal blast on a brass hunting horn, one note, half a second",
    "prop_bijl": "axe blade biting into a wooden chopping block, single thunk",
    "prop_kogel": "iron cannonball dropped onto another iron ball, dull metallic clank",
    "prop_klop": "two quick knocks on a plank door, wooden, dry",
    "prop_wc": "small wooden outhouse door slammed shut with a squeaky hinge",
    "prop_doek": "canvas tent flap snapping in a gust of wind, short",
    "prop_kraai": "single harsh crow caw, close, dry",
    "prop_kikker": "one short frog croak, wet and throaty",
    "prop_wegwijzer": "old wooden signpost creaking as it wobbles, short creak",
    "prop_hek": "wooden fence rail knocking against a post, wood creak and tap",
    "prop_molen": "windmill sails creaking as they turn, slow wooden groan, one second",
    "prop_kanon_tik": "fingernail tap on an iron cannon barrel, small metallic tick",
    "prop_kanon": "18th century field cannon firing, deep black powder boom with a short tail",
    "prop_emmer": "wooden bucket on a rope knocking against a stone well wall",
    "prop_plons": "small splash of a stone dropped into a pond, water plop with bubbles",
    "prop_ritsel": "leaves rustling as a branch is shaken, short dry rustle",
    "prop_zand": "dry sand sliding down a dune, soft hiss, short",
    "prop_steen": "one stone knocking against another stone, dull, short",
    "prop_sneeuw": "soft crunch of packed snow, one step, muffled",
    "prop_hooi": "hay bale rustling as someone falls into it, short",
    "prop_lantaarn": "small metal oil lantern swinging and tinkling against its hook",
    "prop_vuur": "campfire crackle, a few sharp pops of burning wood, half a second",
    "prop_uil": "owl hooting twice, soft, at night",
    "prop_kip": "chicken clucking three times, startled, close",
    "prop_munt": "single coin dropped into shallow water, small plink",
    "prop_kokos": "coconut falling onto packed earth, dull thud",
    "prop_boot": "hollow knock on the hull of a wooden rowing boat floating on water",
    "prop_ijs": "thin ice cracking under a step, sharp crack with small splinters",
    "prop_geit": "goat bleating once, short",
    "prop_nies": "man sneezing once, comic, short",
    "prop_kegel": "empty glass bottles toppling over on grass, glassy tink and hollow clonk, two or three in quick succession",
    "prop_kegel_rol": "iron cannonball rolling over hard packed grass, low rumble, one second",
    "prop_kruitvat": "small gunpowder barrel exploding, dull boom with crackling embers, short",
    "prop_hengel": "fishing rod casting, line whoosh and a few clicks of the reel",
    "prop_vis": "wet fish slapping onto wooden planks and flopping twice",
    "prop_combo": "cheerful chime of four ascending notes on a small glockenspiel, short",
    "bewoner_snurken": "man snoring twice, comic, soft",
    "prop_schot": "single flintlock musket shot, black powder crack with a short echo",
}

# De zwaai en de klap per WAPEN (17 september, Max: "slashing sounds en
# zwaard-impactgeluiden per factie of type wapen"). Zelfde recept: zes takes,
# droog, dichtbij. Een factie-versie erbij: `<categorie>_<factie>.wav`.
WAPEN_PROMPT_EN = {
    "slash_sabel": "6 short cavalry sabre swings through the air in a row, each about 0.3 seconds, sharp thin steel whoosh, silence between each, dry close mono, no reverb, no music",
    "slash_bijl": "6 short heavy battle axe swings through the air in a row, each about 0.4 seconds, deep wide whoosh with the weight of the head, silence between each, dry close mono, no reverb, no music",
    "slash_lans": "6 short lance thrusts through the air in a row, each about 0.25 seconds, quick thin whistle of a long pole, silence between each, dry close mono, no reverb, no music",
    "slash_bajonet": "6 short bayonet thrusts through the air in a row, each about 0.2 seconds, quick stab whoosh with a hint of cloth, silence between each, dry close mono, no reverb, no music",
    "melee_kill_sabel": "6 short sabre slashes cutting into a body in a row, each about 0.5 seconds, wet slicing cut with a bright steel ring, silence between each, dry close mono, no reverb, no music",
    "melee_kill_bijl": "6 short heavy axe chops into a body in a row, each about 0.6 seconds, deep wet chop with a bone crack, silence between each, dry close mono, no reverb, no music",
    "melee_kill_lans": "6 short lance impalements in a row, each about 0.5 seconds, sharp puncture with a wet squelch and a wooden shaft thump, silence between each, dry close mono, no reverb, no music",
    "melee_kill_bajonet": "6 short bayonet stabs into a body in a row, each about 0.4 seconds, wet punch with a steel scrape, silence between each, dry close mono, no reverb, no music",
    "melee_survive_sabel": "6 short sabre-on-sabre parry clangs in a row, each about 0.4 seconds, bright ringing steel, blocked, silence between each, dry close mono, no reverb, no music",
    "melee_survive_bijl": "6 short axe blows blocked on a steel cuirass in a row, each about 0.4 seconds, dull heavy clank with a wooden handle rattle, silence between each, dry close mono, no reverb, no music",
    "melee_survive_lans": "6 short lance points glancing off armor in a row, each about 0.35 seconds, scraping steel slide with a tick, silence between each, dry close mono, no reverb, no music",
    "melee_survive_bajonet": "6 short bayonet parry clangs in a row, each about 0.35 seconds, small blocked steel clink with a grunt of effort, silence between each, dry close mono, no reverb, no music",
}
PROP_PROMPT_EN.update(WAPEN_PROMPT_EN)


def prop_categorieen_uit_wishlist(soort="props"):
    """De prop-rijen uit SOUND-WISHLIST (`prop_*`, `bewoner_*`): categorie ->
    {waarvoor, hoe, gewenst}. Een latere rij (de volledige tabel in sectie 11)
    overschrijft een eerdere."""
    uit = {}
    if not os.path.exists("SOUND-WISHLIST.md"):
        return uit
    for regel in io.open("SOUND-WISHLIST.md", encoding="utf-8"):
        if not regel.startswith("|"):
            continue
        cellen = [c.strip() for c in regel.strip().strip("|").split("|")]
        if len(cellen) < 4:
            continue
        m = re.match(r"^`((?:prop|bewoner)_[a-z0-9_]+|(?:slash|melee_kill|melee_survive)_[a-z]+)`$", cellen[0])
        if not m:
            continue
        cat = m.group(1)
        if soort == "props" and not cat.startswith(("prop_", "bewoner_")):
            continue
        if soort == "wapens" and cat.startswith(("prop_", "bewoner_")):
            continue
        if len(cellen) == 5:      # Categorie | Waarvoor | Hoe | Var. | Nu
            waarvoor, hoe, var_ = cellen[1], cellen[2], cellen[3]
        else:                     # Categorie | Bestand | Var. | Waarvoor | Terugval | Status
            waarvoor, hoe, var_ = cellen[3], "", cellen[2]
        nums = [int(x) for x in re.findall(r"\d+", var_)]
        uit[cat] = {"waarvoor": waarvoor, "hoe": hoe, "gewenst": max(nums) if nums else 2}
    return uit


def synthetische_hashes():
    """Bestandsnaam -> sha1 van wat tools/maak_prop_geluiden.py schreef."""
    uit = {}
    for pad in glob.glob("sounds/**/synthetisch.json", recursive=True):
        try:
            uit.update(json.load(io.open(pad, encoding="utf-8")))
        except (OSError, ValueError):
            pass
    return uit


def prop_stand(cat, synth):
    """(echt, synthetisch): hoeveel bestanden van deze categorie er liggen,
    gesplitst in echte opnames en synthetische placeholders."""
    echt = 0
    kunst = 0
    for pad in glob.glob("sounds/**/*.wav", recursive=True):
        naam = os.path.basename(pad)
        kaal = os.path.splitext(naam)[0]
        delen = kaal.rsplit("_", 1)
        if len(delen) == 2 and delen[1].isdigit():
            kaal = delen[0]
        if kaal != cat:
            continue
        h = hashlib.sha1(open(pad, "rb").read()).hexdigest()
        if synth.get(naam) == h:
            kunst += 1
        else:
            echt += 1
    return echt, kunst


def bouw_props(soort="props"):
    synth = synthetische_hashes()
    rijen = []
    for cat, info in prop_categorieen_uit_wishlist(soort).items():
        echt, kunst = prop_stand(cat, synth)
        rijen.append({"categorie": cat, "waarvoor": info["waarvoor"], "hoe": info["hoe"],
                      "gewenst": info["gewenst"], "echt": echt, "synth": kunst,
                      "prompt": PROP_PROMPT_EN.get(cat, "")})
    rijen.sort(key=lambda r: (r["echt"] > 0, r["synth"] > 0, r["categorie"]))
    return rijen


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
    comps = actieve_comps()
    facties = []
    totaal_moet = totaal_heeft = 0
    for sleutel, naam, kleur in FACTIES:
        rijen = []
        f_moet = f_heeft = 0
        comp = comps.get(naam, [])
        for cat, label, uitleg in BASIS:
            slot = ALLEEN_BIJ_TYPE.get(cat)
            if slot is not None and comp and int(comp[slot]) == 0:
                continue    # deze factie heeft dat eenheidstype niet
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
                        "rijen": rijen, "moet": f_moet, "heeft": f_heeft,
                        "comp": comp})
    return facties, totaal_moet, totaal_heeft


def schrijf(facties, moet, heeft, props=None, wapens=None):
    props = props or []
    wapens = wapens or []
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
  <div class="barlabel">__PROPS__</div>
</header>
<main>
"""
    pct = int(round(100.0 * heeft / max(moet, 1)))
    p_echt = sum(1 for r in props if r["echt"])
    p_synth = sum(1 for r in props if not r["echt"] and r["synth"])
    p_leeg = len(props) - p_echt - p_synth
    props_regel = ("Diorama-props: %d categorieen, %d echt opgenomen, %d nog synthetisch (tools/maak_prop_geluiden.py), %d leeg."
                   % (len(props), p_echt, p_synth, p_leeg)) if props else ""
    uit = [kop.replace("__PCT__", str(pct)).replace("__HEEFT__", str(heeft)).replace("__MOET__", str(moet))
           .replace("__PROPS__", esc(props_regel))]
    for f in facties:
        uit.append('<section style="--fc:%s">' % f["kleur"])
        leger = ""
        if f.get("comp"):
            c = f["comp"]
            leger = " &middot; leger %d inf / %d cav / %d art" % (c[0], c[1], c[2])
        uit.append('<div class="fkop"><h2>%s</h2><div class="tel">%s &middot; %d van %d%s</div></div>'
                   % (esc(f["naam"]), esc(f["sleutel"]), f["heeft"], f["moet"], leger))
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
    def sectie(rijen, kleur, titel, sub, voorbeeld):
        if not rijen:
            return
        s_echt = sum(1 for r in rijen if r["echt"])
        s_synth = sum(1 for r in rijen if not r["echt"] and r["synth"])
        s_leeg = len(rijen) - s_echt - s_synth
        uit.append('<section style="--fc:%s">' % kleur)
        uit.append('<div class="fkop"><h2>%s</h2><div class="tel">%s &middot; '
                   '%d echt, %d synthetisch, %d leeg &middot; %s</div></div>' % (titel, sub, s_echt, s_synth, s_leeg, voorbeeld))
        uit.append("<table><thead><tr><th>Waarvoor</th><th>Categorie</th><th>Status</th>"
                   "<th>Prompt (ElevenLabs, zes takes) / hoe het moet klinken</th></tr></thead><tbody>")
        for r in rijen:
            if r["echt"]:
                status = '<span class="ja">%d echt</span>' % r["echt"]
                if r["synth"]:
                    status += ' <span class="uitleg">+ %d synthetisch</span>' % r["synth"]
            elif r["synth"]:
                status = '<span style="color:var(--accent);font-weight:600">%d synthetisch</span>' % r["synth"]
            else:
                status = '<span class="nee">ontbreekt</span>'
            status += '<div class="uitleg">gewenst: %d</div>' % r["gewenst"]
            cel = ""
            if r["hoe"]:
                cel += '<div class="uitleg">%s</div>' % esc(r["hoe"])
            if r["prompt"]:
                cel += '<code class="prompt" onclick="kopieer(this)">%s</code>' % esc(r["prompt"])
            uit.append("<tr><td>%s</td><td class=\"cat\">%s</td><td>%s</td><td>%s</td></tr>"
                       % (esc(r["waarvoor"]), esc(r["categorie"]), status, cel))
        uit.append("</tbody></table></section>")

    sectie(props, "#8fb36a", "Diorama-props", "tik-geluiden om het bord",
           'bestanden in <code>sounds/props/</code>: <code>prop_bel.wav</code>, <code>prop_bel_2.wav</code>, ...')
    sectie(wapens, "#b3866a", "Wapens: zwaai en klap", "per wapen (sabel, bijl, lans, bajonet), een factie-opname erbij als <code>&lt;categorie&gt;_&lt;factie&gt;.wav</code>",
           'bestanden in <code>sounds/melee/</code>: <code>slash_sabel.wav</code>, <code>melee_kill_bijl_pig.wav</code>, ...')
    uit.append("""</main>
<div class="voet">
  <p><b>Terugval:</b> ontbreekt een factie-geluid, dan leent het spel dat van de
  muis, en pas daarna het algemene geluid. Niets gaat stuk zolang een factie nog
  niets heeft, maar je grizzly gilt dan wel als een muis.</p>
  <p><b>Waar zet je ze neer:</b> <code>sounds/factions/&lt;factie&gt;/</code>.
  De mapindeling is vrij; het spel zoekt op bestandsnaam. Meerdere takes:
  <code>inf_die_pig.wav</code>, <code>inf_die_pig_2.wav</code>, ...</p>
  <p><b>Diorama-props:</b> een echte opname op dezelfde naam in <code>sounds/props/</code>
  (of waar dan ook onder <code>sounds/</code>) verdringt de synthetische; de tracker
  herkent synthetisch aan <code>synthetisch.json</code> naast de bestanden
  (<code>sounds/props/</code> en <code>sounds/melee/</code>).</p>
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
    props = bouw_props()
    wapens = bouw_props("wapens")
    schrijf(facties, moet, heeft, props, wapens)
    print("sound-tracker.html: %d van %d factie-geluiden aanwezig" % (heeft, moet))
    p_echt = sum(1 for r in props if r["echt"])
    p_synth = sum(1 for r in props if not r["echt"] and r["synth"])
    p_leeg = sum(1 for r in props if not r["echt"] and not r["synth"])
    print("  props: %d categorieen, %d echt opgenomen, %d nog synthetisch, %d leeg" % (len(props), p_echt, p_synth, p_leeg))
    w_echt = sum(1 for r in wapens if r["echt"])
    w_synth = sum(1 for r in wapens if not r["echt"] and r["synth"])
    print("  wapens: %d categorieen, %d echt opgenomen, %d nog synthetisch, %d leeg" % (len(wapens), w_echt, w_synth, len(wapens) - w_echt - w_synth))
    for f in facties:
        ontbreekt = [r["categorie"] for r in f["rijen"] if not r["n"] and not r.get("via_modellen")]
        print("  %-10s %d/%d%s" % (f["naam"], f["heeft"], f["moet"],
              ("   mist: " + ", ".join(ontbreekt)) if ontbreekt else ""))

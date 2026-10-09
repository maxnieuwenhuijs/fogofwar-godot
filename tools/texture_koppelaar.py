# Texture-koppelaar (9 oktober 2026, Max: "zet ook in de paneel zet in map en
# ontdek etc texture koppelaar").
#
#   python tools/texture_koppelaar.py <map met png's> --droogloop     ONTDEK: alleen tonen
#   python tools/texture_koppelaar.py <map met png's>                 ZET IN MAP
#   python tools/texture_koppelaar.py <map met png's> --in-het-spel   en meteen de jassen erin
#
# Wat terugkomt van de retexture-dienst zijn losse png's met namen als
#   "tripo_mesh_e8755f55-d0da-...-786b2c1b8cf1003 - tripo_mesh_e8755f55-...-color.png"
# Welk model is dat, is het de jas voor het LIJF of voor het WAPEN (bij een kanon:
# de bediener of het kanon), en is hij rood of blauw? Dat zocht Max tot nu toe met
# de hand uit, en dan sleepte hij hem naar <model>/red, <model>/blue of
# <model>/weapon/red ... in de leveringsmap. Dit script doet dat:
#
# 1. ONTDEK. Elke kleur-png (geen normal/roughness/metallic) krijgt een model:
#    a. op de uuid in de naam. De uuid's van elk model komen uit de uploads naast
#       zijn .blend (<naam>.glb = lijf, <naam>_wapen.glb = wapen, uit "Model
#       klaarmaken voor retexture"), uit de jassen die er al liggen en uit het
#       gebouwde model in assets/models. Hoort een uuid bij meerdere modellen (de
#       Leeuw-bediener zit in alle vijf de kanonnen), dan krijgen ze hem allemaal.
#    b. anders op de UV's: dezelfde meting als uv_check, tegen het lijf en het
#       wapen van elk model; boven de 90% dekking telt hij.
#    Het team komt uit red/rood/blue/blauw in de naam of de map, anders uit de
#    kleur: twee jassen voor hetzelfde deel -> de roodste is rood; een losse jas
#    -> rood of blauw op zijn eigen kleurbalans (dat staat er dan als gok bij).
# 2. ZET IN MAP. De png (met zijn normal-map ernaast) gaat naar de juiste map van
#    de levering. Wat daar al lag gaat eerst naar results/koppelaar_backup/<tijd>/
#    (anders pakt "Map in het spel zetten" twee jassen voor hetzelfde deel).
#    Een png die al in de leveringsmap stond wordt verplaatst, een van buiten
#    (Downloads) gekopieerd.
# 3. --in-het-spel: daarna per model verwerk_levering.py --alleen-jassen, dus de
#    gewone UV-controle en de import-instellingen, zonder opnieuw te bouwen.
import argparse
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import time

PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(PROJ, "tools"))
from bouw_modellen import plaats_uit_woorden, woorden  # noqa: E402
from verwerk_levering import TEAMWOORDEN, is_kleur, padwoorden, wapensoort  # noqa: E402

UUID = re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")
WAPENMAPPEN = {"weapon", "wapen"}
SOORTWOORDEN = ("basecolor", "albedo", "diffuse", "color", "colour", "normalgl", "normal",
                "roughness", "metallic")
DREMPEL = 90.0


def uuids(tekst):
    return set(UUID.findall(tekst.lower()))


def lang(pad):
    """Windows-pad dat ook boven de 260 tekens werkt (Tripo-namen zijn lang)."""
    pad = os.path.abspath(pad)
    voorvoegsel = "\\\\?\\"
    if os.name == "nt" and len(pad) > 240 and not pad.startswith(voorvoegsel):
        return voorvoegsel + pad
    return pad


def glb_namen(pad):
    """Alle node-, mesh- en materiaalnamen uit een glb (alleen de json-kop)."""
    try:
        with open(pad, "rb") as f:
            kop = f.read(20)
            if len(kop) < 20 or kop[:4] != b"glTF":
                return []
            lengte = struct.unpack_from("<I", kop, 12)[0]
            js = json.loads(f.read(lengte).decode("utf-8"))
    except (OSError, ValueError):
        return []
    namen = []
    for sleutel in ("nodes", "meshes", "materials"):
        namen += [x.get("name", "") for x in js.get(sleutel, [])]
    return namen


class Model:
    def __init__(self, map_, factie, soort, arch):
        self.map = map_
        self.factie, self.soort, self.arch = factie, soort, arch
        self.uuid = {"lijf": set(), "wapen": set()}
        self.glb = {"lijf": [], "wapen": []}   # kandidaten voor de UV-meting

    @property
    def naam(self):
        return f"{self.factie}/{self.soort}_{self.arch}"

    def deelnaam(self, deel):
        if self.soort == "artillery":
            return "bediener" if deel == "lijf" else "kanon"
        return deel


def zoek_glb(wortel, naam):
    for r, _, fs in os.walk(wortel):
        if naam in fs:
            return os.path.join(r, naam)
    return None


def modellen(inbox, models_dir):
    """Elk model in de leveringsmap (een map met een .blend), met zijn uuid's."""
    uit = []
    for r, dirs, fs in os.walk(inbox):
        rel = os.path.relpath(r, inbox)
        if any(d.lower() in WAPENMAPPEN | set(TEAMWOORDEN) for d in rel.split(os.sep)):
            continue
        blends = sorted(f for f in fs if f.lower().endswith(".blend"))
        if not blends:
            continue
        pl = plaats_uit_woorden(padwoorden(r) + woorden([os.path.splitext(blends[0])[0]]))
        if pl is None:
            continue
        m = Model(r, *pl)
        # De uploads naast de blend: het lijf en het wapen apart.
        for f in fs:
            if not f.lower().endswith(".glb"):
                continue
            deel = "wapen" if f.lower().endswith("_wapen.glb") else "lijf"
            pad = os.path.join(r, f)
            m.uuid[deel] |= uuids(" ".join(glb_namen(pad)))
            m.glb[deel].append(pad)
        # De jassen die er al liggen (hun naam draagt de uuid).
        for r2, _, fs2 in os.walk(r):
            onder = os.path.relpath(r2, r).lower().split(os.sep)
            deel = "wapen" if any(d in WAPENMAPPEN for d in onder) else "lijf"
            if not any(d in TEAMWOORDEN for d in onder):
                continue
            for f in fs2:
                if f.lower().endswith(".png"):
                    m.uuid[deel] |= uuids(f)
        # Het gebouwde model en zijn wapen in assets/models.
        fac_map = os.path.join(models_dir, m.factie)
        basis = zoek_glb(fac_map, f"{m.soort}_{m.arch}.glb") if os.path.isdir(fac_map) else None
        wapen = zoek_glb(fac_map, f"{m.soort}_{m.arch}_{wapensoort(m.soort)}.glb") if os.path.isdir(fac_map) else None
        w_uuid = uuids(" ".join(glb_namen(wapen))) if wapen else set()
        m.uuid["wapen"] |= w_uuid
        if basis:
            m.uuid["lijf"] |= uuids(" ".join(glb_namen(basis))) - w_uuid
        if not m.glb["lijf"] and basis:
            m.glb["lijf"].append(basis)
        if not m.glb["wapen"] and wapen:
            m.glb["wapen"].append(wapen)
        # Een uuid die bij beide delen staat zegt niets over het deel.
        dubbel = m.uuid["lijf"] & m.uuid["wapen"]
        m.uuid["lijf"] -= dubbel
        m.uuid["wapen"] -= dubbel
        uit.append(m)
    return uit


def zonder_soort(naam):
    """Bestandsnaam zonder color/normal/...: zo vind je de normal naast een kleur-png."""
    n = os.path.splitext(naam.lower())[0]
    for w in SOORTWOORDEN:
        n = n.replace(w, "")
    return re.sub(r"[^a-z0-9]+", "", n)


def kleurbalans(bron):
    """Rood min blauw, gemiddeld over alle beschilderde pixels (-1..1). Bewust
    zonder drempel op verzadiging: die selectie verschuift zelf mee met de tint,
    en dan kwam een roder getinte jas soms blauwer uit. `bron` is een pad of
    een al geopend PIL-beeld."""
    import numpy as np
    from PIL import Image
    beeld = Image.open(lang(bron)) if isinstance(bron, str) else bron
    a = np.asarray(beeld.convert("RGBA").resize((256, 256)), dtype=np.float32) / 255.0
    rgb, alfa = a[:, :, :3], a[:, :, 3]
    keus = (alfa > 0.03) & (rgb.max(axis=2) > 0.03)
    if keus.sum() == 0:
        return 0.0
    return float((rgb[:, :, 0][keus] - rgb[:, :, 2][keus]).mean())


def origineel_beeld(glbs, u):
    """De kleurtextuur zoals hij NU in de glb zit (de jas van voor de retexture),
    als PIL-beeld; bij voorkeur die met dezelfde uuid. None als er geen is."""
    import io
    from PIL import Image
    from uv_check import lees_glb
    reserve = None
    for glb in glbs:
        try:
            js, bin_blok = lees_glb(lang(glb))
        except (OSError, SystemExit, ValueError):
            continue
        for img in js.get("images", []):
            naam = (img.get("name") or "").lower()
            if "bufferView" not in img or not any(w in naam for w in ("color", "albedo", "diffuse")):
                continue
            bv = js["bufferViews"][img["bufferView"]]
            begin = bv.get("byteOffset", 0)
            try:
                beeld = Image.open(io.BytesIO(bin_blok[begin:begin + bv["byteLength"]]))
                beeld.load()
            except Exception:  # noqa: BLE001
                continue
            if u & uuids(naam):
                return beeld
            reserve = reserve or beeld
    return reserve


def bestaande_jas(m, deel, team, behalve):
    """Een kleur-png die al in de map van dit deel en team ligt (niet `behalve`)."""
    map_ = doelmap(m, deel, team)
    if not os.path.isdir(map_):
        return None
    for f in sorted(os.listdir(map_)):
        pad = os.path.join(map_, f)
        if is_kleur(f) and os.path.abspath(pad) not in behalve:
            return pad
    return None


def team_op_kleur(x, behalve):
    """Team van een losse jas (zonder rood/blauw-partner in deze lading):
    1. lijkt hij meer op de rode of de blauwe jas die er al ligt;
    2. anders: is hij roder of blauwer dan het origineel uit de glb (gok);
    3. anders: zijn eigen kleurbalans (gok)."""
    m, deel = x["doelen"][0]
    b = x["balans"]
    rood, blauw = bestaande_jas(m, deel, "red", behalve), bestaande_jas(m, deel, "blue", behalve)
    if rood and blauw:
        br, bb = kleurbalans(rood), kleurbalans(blauw)
        team = "red" if abs(b - br) < abs(b - bb) else "blue"
        return team, "kleur (lijkt het meest op de %s jas die er al ligt)" % ("rode" if team == "red" else "blauwe")
    orig = origineel_beeld(m.glb[deel], uuids(os.path.basename(x["png"])))
    if orig is not None:
        bo = kleurbalans(orig)
        team = "red" if b > bo else "blue"
        return team, "GOK: %s dan het origineel (%+.3f)" % ("roder" if team == "red" else "blauwer", b - bo)
    return ("red" if b > 0 else "blue"), "GOK op kleur (balans %+.2f)" % b


_maskers = {}


def uv_score(glb, png_verf):
    """(dekking, raak) in procent, voor het best passende materiaal van een glb.
    Dekking = hoeveel van de UV-eilanden beschilderd is (de maat van uv_check);
    raak = hoeveel van wat beschilderd is op die eilanden valt. Een jas van een
    ander model kan toevallig hoog dekken, maar valt dan voor een flink deel
    naast de eilanden."""
    from uv_check import uv_maskers
    if glb not in _maskers:
        try:
            _maskers[glb] = uv_maskers(lang(glb))
        except Exception:  # noqa: BLE001 - een kapotte glb telt gewoon niet mee
            _maskers[glb] = {}
    geverfd_opp = max(int(png_verf.sum()), 1)
    beste = (0.0, 0.0)
    for g in _maskers[glb].values():
        opp = int(g["masker"].sum())
        if opp:
            samen = float((g["masker"] & png_verf).sum())
            dekking, raak = 100.0 * samen / opp, 100.0 * samen / geverfd_opp
            if dekking * raak > beste[0] * beste[1]:
                beste = (dekking, raak)
    return beste


def ontdek(bron, modellen_, vast_team=None):
    """Per kleur-png: {png, doelen: [(model, deel)], hoe, team, team_hoe, normals}."""
    pngs = []
    for r, _, fs in os.walk(bron):
        for f in sorted(fs):
            if f.lower().endswith(".png"):
                pngs.append(os.path.join(r, f))
    kleuren = [p for p in pngs if is_kleur(os.path.basename(p))]
    uitslag = []
    for png in kleuren:
        naam = os.path.basename(png)
        u = uuids(naam)
        doelen = [(m, deel) for m in modellen_ for deel in ("lijf", "wapen") if u & m.uuid[deel]]
        hoe = "uuid " + ", ".join(sorted(x[:8] for x in u)) if doelen else ""
        if not doelen:
            # Geen bekende uuid: op de UV's. Dat kan alleen met een echte alfa
            # (Tripo levert die); een plat plaatje is overal "beschilderd" en
            # past dan op alles.
            from uv_check import geverfd
            verf, maat = geverfd(lang(png))
            if maat != "alfa":
                hoe = "geen bekende uuid en geen alfa: op de UV's herkennen kan dan niet"
            else:
                scores = []
                for m in modellen_:
                    for deel in ("lijf", "wapen"):
                        for g in m.glb[deel]:
                            dekking, raak = uv_score(g, verf)
                            if dekking >= DREMPEL:
                                scores.append((dekking * raak / 100.0, dekking, raak, m, deel))
                if scores:
                    scores.sort(key=lambda s: -s[0])
                    top = scores[0]
                    gezien = set()
                    for sc, _dek, _raak, m, deel in scores:
                        # gelijk = dezelfde mesh (de bediener in vijf kanonnen)
                        if sc >= top[0] - 0.3 and (m.map, deel) not in gezien:
                            gezien.add((m.map, deel))
                            doelen.append((m, deel))
                    hoe = "UV %.1f%% gedekt, %.1f%% raak" % (top[1], top[2])
                else:
                    hoe = f"geen bekende uuid, en de UV's passen nergens boven {DREMPEL:.0f}%"
        team = vast_team
        team_hoe = "opgegeven" if vast_team else ""
        if team is None:
            w = padwoorden(png)
            team = next((TEAMWOORDEN[x] for x in w if x in TEAMWOORDEN), None)
            team_hoe = "uit de naam" if team else ""
        normals = [p for p in pngs if p != png and not is_kleur(os.path.basename(p))
                   and os.path.dirname(p) == os.path.dirname(png)
                   and zonder_soort(os.path.basename(p)) == zonder_soort(naam)]
        uitslag.append({"png": png, "doelen": doelen, "hoe": hoe, "team": team,
                        "team_hoe": team_hoe, "normals": normals})
    # Team op kleur: per groep (dezelfde doelen) de roodste rood, de blauwste blauw.
    groepen = {}
    for x in uitslag:
        if x["doelen"] and x["team"] is None:
            sleutel = tuple(sorted((m.map, d) for m, d in x["doelen"]))
            groepen.setdefault(sleutel, []).append(x)
    for groep in groepen.values():
        for x in groep:
            x["balans"] = kleurbalans(x["png"])
        if len(groep) == 2:
            rood = max(groep, key=lambda x: x["balans"])
            for x in groep:
                x["team"] = "red" if x is rood else "blue"
                x["team_hoe"] = "kleur (roodste van de twee)" if x is rood else "kleur (blauwste van de twee)"
        else:
            behalve = {os.path.abspath(y["png"]) for y in uitslag}
            for x in groep:
                x["team"], x["team_hoe"] = team_op_kleur(x, behalve)
    # Twee jassen voor hetzelfde deel en team: dan weet het script het niet.
    bezet = {}
    for x in uitslag:
        for m, deel in x["doelen"]:
            bezet.setdefault((m.map, deel, x["team"]), []).append(x)
    for lijst in bezet.values():
        if len(lijst) > 1:
            for x in lijst:
                x["botsing"] = True
    return uitslag


def doelmap(m, deel, team):
    return os.path.join(m.map, team) if deel == "lijf" else os.path.join(m.map, "weapon", team)


def rapport(uitslag, inbox):
    print(f"{len(uitslag)} kleur-png('s) gevonden:")
    print()
    for x in uitslag:
        naam = os.path.basename(x["png"])
        kort = naam if len(naam) <= 46 else naam[:20] + "..." + naam[-23:]
        if not x["doelen"]:
            print(f"  {kort:46}  ?? geen model gevonden ({x['hoe']})")
            continue
        team = {"red": "rood", "blue": "blauw"}.get(x["team"], "?")
        modellen_ = sorted({m.naam for m, _ in x["doelen"]})
        delen = sorted({m.deelnaam(d) for m, d in x["doelen"]})
        wat = f"{modellen_[0]}" if len(modellen_) == 1 else f"{len(modellen_)} modellen ({', '.join(modellen_)})"
        merk = "   LET OP: twee jassen voor hetzelfde deel en team, blijft liggen" if x.get("botsing") else ""
        print(f"  {kort:46}  -> {wat}, {'/'.join(delen)}, {team} [{x['hoe']}; team {x['team_hoe']}]{merk}")
        for m, deel in x["doelen"]:
            print(f"  {'':46}     {os.path.relpath(doelmap(m, deel, x['team']), inbox)}")
        if x["normals"]:
            print(f"  {'':46}     + {len(x['normals'])} normal-map(s) ernaast")
    print()


def zet_in_map(uitslag, inbox):
    """Kopieer/verplaats; geeft de geraakte modelmappen terug."""
    stempel = time.strftime("%Y%m%d_%H%M%S")
    backup = os.path.join(PROJ, "results", "koppelaar_backup", stempel)
    geraakt = set()
    geleegd = set()
    inbox_abs = os.path.abspath(inbox)
    for x in uitslag:
        if not x["doelen"] or x["team"] is None or x.get("botsing"):
            continue
        bestanden = [x["png"]] + x["normals"]
        for m, deel in x["doelen"]:
            doel = doelmap(m, deel, x["team"])
            os.makedirs(doel, exist_ok=True)
            # Wat er al lag eerst opzij (een keer per map), anders liggen er twee jassen.
            if doel not in geleegd:
                geleegd.add(doel)
                for f in os.listdir(doel):
                    oud = os.path.join(doel, f)
                    if os.path.isfile(oud) and f.lower().endswith(".png") and oud not in bestanden:
                        bk = os.path.join(backup, os.path.relpath(doel, inbox_abs))
                        os.makedirs(bk, exist_ok=True)
                        shutil.move(lang(oud), lang(os.path.join(bk, f)))
                        print(f"  opzij: {os.path.relpath(oud, inbox)} -> results/koppelaar_backup/{stempel}/")
            for b in bestanden:
                naar = os.path.join(doel, os.path.basename(b))
                if os.path.abspath(b) != os.path.abspath(naar):
                    shutil.copyfile(lang(b), lang(naar))
            print(f"  {os.path.basename(x['png'])[:40]:40} -> {os.path.relpath(doel, inbox)}")
            geraakt.add(m.map)
        # Stond hij al in de leveringsmap (losgelaten in een modelmap): weghalen,
        # anders ziet "Map in het spel zetten" hem nog een keer, zonder team.
        if os.path.abspath(x["png"]).startswith(inbox_abs):
            for b in bestanden:
                if not any(os.path.abspath(os.path.dirname(b)) == os.path.abspath(doelmap(m, d, x["team"]))
                           for m, d in x["doelen"]):
                    os.remove(lang(b))
    return sorted(geraakt)


def main():
    p = argparse.ArgumentParser(description="Png's van de retexture-dienst bij het juiste model zetten.")
    p.add_argument("map", help="de map met de png's (bijvoorbeeld Downloads)")
    p.add_argument("--inbox", default=os.path.join(PROJ, "assets", "new upload folder"),
                   help="de leveringsmap met de modelmappen (standaard assets/new upload folder)")
    p.add_argument("--models", default=os.path.join(PROJ, "assets", "models"))
    p.add_argument("--team", choices=["red", "blue"], help="alle png's in deze map zijn dit team")
    p.add_argument("--droogloop", action="store_true", help="alleen ontdekken en tonen")
    p.add_argument("--in-het-spel", action="store_true",
                   help="daarna meteen de jassen erin (verwerk_levering --alleen-jassen per model)")
    a = p.parse_args()
    if not os.path.isdir(a.map):
        print(f"Dat is geen map: {a.map}")
        return 1
    ms = modellen(a.inbox, a.models)
    print(f"{len(ms)} modellen in {os.path.relpath(a.inbox, PROJ)} "
          f"({sum(len(m.uuid['lijf']) + len(m.uuid['wapen']) for m in ms)} uuid's bekend)")
    uitslag = ontdek(a.map, ms, a.team)
    if not uitslag:
        print(f"Geen kleur-png gevonden in {a.map} (normal-, roughness- en metallic-maps tellen niet mee).")
        return 1
    rapport(uitslag, a.inbox)
    onbekend = [x for x in uitslag if not x["doelen"]]
    botsing = [x for x in uitslag if x.get("botsing")]
    gok = [x for x in uitslag if x["doelen"] and "GOK" in x["team_hoe"]]
    print(f"{len(uitslag) - len(onbekend)} herkend, {len(onbekend)} niet"
          + (f", {len(gok)} team gegokt op kleur (kijk even na)" if gok else "")
          + (f", {len(botsing)} botsen" if botsing else ""))
    if a.droogloop:
        print("Ontdek: er is niets verplaatst.")
        return 1 if (onbekend or botsing) else 0
    print()
    print("In de map zetten:")
    geraakt = zet_in_map(uitslag, a.inbox)
    print(f"{len(geraakt)} modelmap(pen) bijgewerkt.")
    if a.in_het_spel and geraakt:
        print()
        print("In het spel (alleen de jassen, met de UV-controle):")
        for m in geraakt:
            r = subprocess.run([sys.executable, os.path.join(PROJ, "tools", "verwerk_levering.py"), m,
                                "--alleen-jassen", "--geen-controles"],
                               capture_output=True, text=True, errors="replace", cwd=PROJ)
            for l in r.stdout.splitlines():
                if l.strip().startswith(("OK", "GEWEIGERD", "MISLUKT", "FOUT")):
                    print("  " + l.strip())
        print()
        print("Klik daarna even in het Godot-venster: de editor importeert de nieuwe jassen.")
    return 1 if (onbekend or botsing) else 0


if __name__ == "__main__":
    sys.exit(main())

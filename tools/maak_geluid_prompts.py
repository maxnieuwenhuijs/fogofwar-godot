# -*- coding: utf-8 -*-
"""Natuurlijke ElevenLabs-prompts voor ELKE geluidscategorie (18 september,
Max: "verbeter echt alle prompts, nu komt er alleen maar bagger uit, gebruik
echt natuurlijke termen").

    python tools/maak_geluid_prompts.py [--droogloop]

Schrijft de prompts en de instellingen (duur, prompt-invloed) per categorie
in `sounds/geluid_studio.json`, het bestand dat de geluid-studio leest. Een
prompt die je in de studio zelf hebt aangepast blijft staan (`--overschrijf`
zet alles opnieuw).

Het oude recept ("6 short ... in a row, each about 0.3 seconds, silence
between each, dry close mono, no reverb, no music") is een opsomming van
eisen; het text-to-sound-model van ElevenLabs werkt op een BESCHRIJVING: wat
klinkt er, van wie, waar, hoe het verloopt. Een geluid per prompt, in
gewone zinnen, met materiaal en beweging benoemd; variatie haal je uit de
studio (x3) en de prompt-invloed. Kreten worden per factie x archetype uit
een sjabloon gebouwd (dier + bouw van het model), de rest is met de hand
geschreven.
"""
import argparse
import io
import json
import os

WORTEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STUDIO_JSON = os.path.join(WORTEL, "sounds", "geluid_studio.json")

# -------------------------------------------------------------- de dieren
# infanterie = het kleine broertje, big bro = het grote dier (MODEL-WISHLIST)
# Gewone dierentaal (18 september, Max: "high pitched enzo maakt het raar en
# niet natuurlijk"): geen toonhoogte-bijvoeglijke naamwoorden, alleen het dier
# en het geluid dat het echt maakt (squeak, squeal, growl, hiss).
INF = {
    "mouse": ("mouse", "squeaks"),
    "pig": ("young pig", "squeals"),
    "lion": ("young cheetah", "yowls"),
    "bear": ("raccoon", "screams"),
    "wolf": ("fox", "yelps"),
    "crocodile": ("lizard", "hisses"),
}
CAV = {
    "mouse": ("a rat", "squeals"),
    "pig": ("a wild boar", "grunts and squeals"),
    "lion": ("a lion", "roars"),
    "bear": ("a grizzly bear", "roars"),
    "wolf": ("a wolf", "yelps and growls"),
    "crocodile": ("a crocodile", "bellows and hisses"),
}
# de bouw van het model, in gewone woorden (geen "higher pitched")
ARCH = {
    "base": ("", ""),
    "spd": ("small skinny ", ""),
    "hp": ("big heavy ", " wearing a steel breastplate"),
    "atk": ("huge strong ", ""),
    "mix": ("", ""),
}


def lidwoord(zin):
    return ("An " if zin[0] in "aeiou" else "A ") + zin
# hout en ijzer van het kanon per factie (MODEL-WISHLIST 3c-2)
KANON = {
    "pig": "dark oak with heavy copper fittings",
    "lion": "polished walnut with gilded brass fittings",
    "wolf": "patched scrap iron and mismatched salvaged wood",
    "crocodile": "matte iron wrapped in damp camouflage cloth",
    "mouse": "pale worn wood with plain soldier's iron",
    "bear": "frost-covered iron and fur-wrapped timber",
}
STAP_INF = {
    "mouse": "the tiny clawed paw of a mouse",
    "pig": "the small hard trotter of a young pig",
    "lion": "the soft padded paw of a young cheetah",
    "bear": "the small clawed paw of a raccoon, with a little scuff",
    "wolf": "the quick padded paw of a fox, claws ticking",
    "crocodile": "the scaly foot of a lizard slapping and dragging a little",
}
STAP_CAV = {
    "mouse": "the heavy scurrying paw of a big rat",
    "pig": "the heavy hoof of a wild boar",
    "lion": "the heavy padded paw of a lion",
    "bear": "the massive paw of a grizzly bear that makes the ground thud",
    "wolf": "the heavy paw of a huge wolf, claws digging in",
    "crocodile": "the heavy foot of a crocodile with its belly dragging over the mud",
}
FACTIES = ["mouse", "pig", "lion", "bear", "wolf", "crocodile"]

SLOT = "Close-up, dry studio recording, no reverb, no music."
# Meerdere takes in een clip (18 september, Max: "doe weer multiple, geluid
# duur dan op 7 of zo, en dan met die knip op stiltes"): de beschrijving
# blijft een geluid, de reeks-zin erachter vraagt om vijf uitvoeringen met
# stilte ertussen; de studio knipt ze op de stiltes in losse takes.
REEKS = " Play it five times in a row, each one slightly different, with a clear pause of silence between them."
REEKS_DUUR = 7.0
# lange dingen die geen reeks worden (muziek, sfeer, fanfares)
GEEN_REEKS = {"music_menu", "music_battle", "ambient_field", "win_fanfare", "lose_sting", "charge_rumble"}


def kreten():
    p, i = {}, {}
    for f in FACTIES:
        dier, kreet = INF[f]
        dier_c, kreet_c = CAV[f]
        for a, (bouw, extra) in ARCH.items():
            wie = lidwoord(bouw + dier + extra)
            naam = "" if a == "" else "_" + a
            # Max, 18 september: "al die kreten moeten krijgen: loud and very
            # short, very short bursts"
            p["inf_die_%s%s" % (f, naam)] = (
                "%s dies: one loud, very short burst as it %s in pain, cut off as it falls to the ground. One single cry. %s"
                % (wie, kreet, SLOT))
            i["inf_die_%s%s" % (f, naam)] = {"duur": 1.5, "invloed": 0.6}
            p["inf_kanon_die_%s%s" % (f, naam)] = (
                "%s is hit by a cannonball: one loud, very short burst as it %s, cut off instantly. One single short scream. %s"
                % (wie, kreet, SLOT))
            i["inf_kanon_die_%s%s" % (f, naam)] = {"duur": 0.8, "invloed": 0.6}
        # zonder archetype: dezelfde als base
        p["inf_die_%s" % f] = p["inf_die_%s_base" % f]
        i["inf_die_%s" % f] = dict(i["inf_die_%s_base" % f])
        p["inf_kanon_die_%s" % f] = p["inf_kanon_die_%s_base" % f]
        i["inf_kanon_die_%s" % f] = dict(i["inf_kanon_die_%s_base" % f])
        for a, (bouw, extra) in ARCH.items():
            wie_c = lidwoord(bouw + dier_c.split(" ", 1)[1] + extra)
            p["cav_die_%s_%s" % (f, a)] = (
                "%s is wounded in battle and dies: one loud, very short burst as it %s in pain, cut off as its heavy body falls onto the ground. One single cry. %s"
                % (wie_c, kreet_c, SLOT))
            i["cav_die_%s_%s" % (f, a)] = {"duur": 2.0, "invloed": 0.6}
            p["cav_kanon_die_%s_%s" % (f, a)] = (
                "%s is hit by a cannonball: one loud, very short burst as it %s, cut off instantly as it goes down. One single short cry. %s"
                % (wie_c, kreet_c, SLOT))
            i["cav_kanon_die_%s_%s" % (f, a)] = {"duur": 1.0, "invloed": 0.6}
        p["cav_die_%s" % f] = p["cav_die_%s_base" % f]
        i["cav_die_%s" % f] = dict(i["cav_die_%s_base" % f])
        p["cav_kanon_die_%s" % f] = p["cav_kanon_die_%s_base" % f]
        i["cav_kanon_die_%s" % f] = dict(i["cav_kanon_die_%s_base" % f])
        p["cannon_die_%s" % f] = (
            "A wooden field cannon smashed to pieces: the carriage of %s cracks and splinters, the fittings snap and clatter, a wheel wobbles and falls over. One single crash. %s"
            % (KANON[f], SLOT))
        i["cannon_die_%s" % f] = {"duur": 2.2, "invloed": 0.5}
        p["step_%s" % f] = ("A single footstep of %s on dry packed earth. Just one step. %s" % (STAP_INF[f], SLOT))
        i["step_%s" % f] = {"duur": 0.5, "invloed": 0.6}
        p["cav_move_%s" % f] = ("A single heavy footstep of %s on dry packed earth. Just one step. %s" % (STAP_CAV[f], SLOT))
        i["cav_move_%s" % f] = {"duur": 0.6, "invloed": 0.6}
    return p, i


# -------------------------------------------------------------- de rest
HAND = {
    # algemeen: sterven en bewegen zonder factie
    "inf_die": ("A small animal dies: one loud, very short burst as it cries out in pain, cut off as it falls to the ground. One single cry. " + SLOT, 1.5, 0.6),
    "cav_kanon_die": ("A large animal is hit by a cannonball: one loud, very short burst as it roars, cut off instantly as it goes down. One single short cry. " + SLOT, 1.0, 0.6),
    "cav_die": ("A large animal is wounded in battle and dies: one loud, very short burst as it roars in pain, cut off as its heavy body falls onto the ground. One single sound. " + SLOT, 2.0, 0.6),
    "cannon_die": ("A wooden field cannon smashed to pieces: oak splinters, iron fittings snap and clatter, a wheel falls over. One single crash. " + SLOT, 2.2, 0.5),
    "cannon_wheel_loose": ("A heavy wooden cannon wheel with an iron rim breaks loose, rolls wobbling for a moment and falls flat on packed earth. " + SLOT, 2.0, 0.5),
    "step": ("A single footstep of a leather army boot on dry packed earth, marching infantry. Just one step. " + SLOT, 0.5, 0.6),
    "cav_move": ("A single heavy footstep of a large beast on dry packed earth. Just one step. " + SLOT, 0.6, 0.6),
    "cannon_move": ("A heavy wooden cannon carriage on iron-rimmed wheels rolls forward one short push over rough ground, the wood creaking. " + SLOT, 1.2, 0.5),
    "wolf_step": ("A single fast padded paw step of a wolf on dry earth, claws ticking. Just one step. " + SLOT, 0.5, 0.6),
    # selectie
    "musket_cock": ("The hammer of a flintlock musket being cocked, a crisp metallic click. One click. " + SLOT, 0.6, 0.7),
    "cav_select": ("A large beast snorts once and shifts its weight, harness leather creaking, a buckle jingling. " + SLOT, 1.0, 0.5),
    "cannon_select": ("A gunner slaps the barrel of an iron cannon once and a rammer is set against the wooden carriage. " + SLOT, 0.9, 0.5),
    "inf_select": ("A soldier snaps to attention: a stamped boot on earth and the rattle of a leather cartridge box. " + SLOT, 0.7, 0.5),
    "deselect": ("A soft muted tap of a wooden game piece being set down on a wooden board. " + SLOT, 0.4, 0.6),
    # schieten
    "musket_fire": ("A single flintlock musket shot fired at close range: the sharp crack of black powder with a short puff of the pan. One shot. " + SLOT, 1.5, 0.6),
    "musket_echo": ("The distant rolling echo of a musket shot fading across open fields, no initial crack, only the tail. " + SLOT, 2.5, 0.5),
    "musket_hit": ("A musket ball striking a body at close range: a wet heavy thud with a small spray of dust. One impact. " + SLOT, 0.6, 0.6),
    "cannon_fire": ("A single black powder field cannon firing: a deep heavy boom with a sharp initial blast and a low rumbling tail. One shot. " + SLOT, 2.5, 0.6),
    "cannon_air": ("A cast iron cannonball whistling through the air overhead, a low ominous whoosh passing by. " + SLOT, 1.5, 0.5),
    "cannon_hit": ("A heavy cast iron cannonball slamming into the ground: a deep thud, a burst of dirt and splintering wood. One impact. " + SLOT, 1.5, 0.6),
    "cannon_fuse": ("A short cannon fuse burning and hissing with a sputter of sparks. " + SLOT, 1.5, 0.5),
    "pawn_block": ("A musket ball thudding into a thick wooden shield, a dull heavy knock, the shot blocked. One impact. " + SLOT, 0.6, 0.6),
    "ricochet": ("A musket ball ricocheting off stone: a sharp bright metallic whine spinning away into the distance. " + SLOT, 1.2, 0.6),
    # melee en terugslag
    "melee_kill": ("A bayonet driven into a body: a wet heavy punch with a short scrape of steel. One killing thrust. " + SLOT, 0.8, 0.6),
    "melee_survive": ("Two steel blades clashing once, a bright ringing clang as a thrust is blocked. One clash. " + SLOT, 0.8, 0.6),
    "retaliation": ("A quick steel-on-steel counterstrike, one sharp clang, and a short grunt of effort from a small soldier. " + SLOT, 0.9, 0.6),
    "retaliation_cav": ("A large beast lashes back: a heavy paw strikes with a thud and a short angry snarl. " + SLOT, 1.0, 0.5),
    "blood_splash": ("A small wet blood splatter hitting the ground, quick and light. One splatter. " + SLOT, 0.5, 0.6),
    "charge_rumble": ("The heavy pounding footsteps of a large animal charging at full speed over packed earth, getting faster, the ground trembling and rumbling under the weight. No voice. " + SLOT, 3.0, 0.5),
    "charge_yell": ("A short battle cry of animals charging into an attack, snarling and roaring over pounding feet. " + SLOT, 1.5, 0.5),
    "body_hit_floor": ("A body in a wool uniform falling and hitting packed earth, a dull heavy thump with a small rattle of gear. One fall. " + SLOT, 0.8, 0.6),
    # materiaal-laag
    "impact_flesh": ("A heavy wet impact on flesh, a dull meaty thud with a short liquid splatter. One hit. " + SLOT, 0.6, 0.6),
    "impact_armor": ("A musket ball striking a steel breastplate, a hard bright metallic clank with a short ring. One hit. " + SLOT, 0.7, 0.6),
    "impact_wood": ("A musket ball smashing into a thick oak musket stock, a dull heavy wooden knock with splintering. One hit. " + SLOT, 0.6, 0.6),
    "impact_bone": ("A sharp bone crack under a heavy blow, a short dry snap muffled by cloth. One crack. " + SLOT, 0.5, 0.6),
    "impact_dirt": ("A musket ball slamming into packed dirt, a dull thud with a spray of soil and small pebbles. One impact. " + SLOT, 0.6, 0.6),
    # vallende dingen
    "val_prop": ("A small wooden object dropped onto hard ground, a short clatter and it comes to rest. " + SLOT, 0.8, 0.5),
    "val_musket": ("A wooden musket with iron fittings dropped onto packed earth: the stock knocks, the metal rattles, it settles. " + SLOT, 1.0, 0.6),
    "val_melee": ("A steel sabre dropped onto hard ground: a bright clang, a short ring and a skid to rest. " + SLOT, 1.0, 0.6),
    "val_drum": ("A small military snare drum dropped onto the ground: a hollow thump and a short rattle of the snare wires. " + SLOT, 1.0, 0.6),
    "val_flag": ("A wooden flagpole with a cloth banner falling over onto the ground: the pole knocks, the cloth flaps and settles. " + SLOT, 1.2, 0.5),
    "val_horn": ("A brass bugle dropped onto hard ground, a bright metallic clunk and a short bounce. " + SLOT, 0.8, 0.6),
    "val_sapper": ("A heavy axe dropped onto the ground: the iron head thuds and the wooden handle knocks once. " + SLOT, 0.8, 0.6),
    "val_hoed": ("A felt soldier's hat falling onto the ground, a soft muffled flop. " + SLOT, 0.5, 0.6),
    "val_canteen": ("A small wooden keg dropped onto the ground, a hollow thump and a short roll. " + SLOT, 0.9, 0.5),
    # interface
    "ui_click": ("A single soft wooden button press, a muted tap on oak. " + SLOT, 0.3, 0.7),
    "ui_back": ("A soft wooden panel sliding shut with a gentle tap at the end. " + SLOT, 0.5, 0.6),
    "ui_hover": ("A very soft, tiny wooden tick, barely there. " + SLOT, 0.2, 0.7),
    "ui_error": ("A short dull wooden knock, a blocked, refused sound. " + SLOT, 0.4, 0.7),
    "ui_toggle": ("A small wooden latch flipping over with a light double click. " + SLOT, 0.4, 0.7),
    "ui_open": ("A parchment scroll unrolling quickly with a soft paper rustle. " + SLOT, 0.8, 0.6),
    # de korte geluiden bij de UI-beweging (30 september, Max: "korte UI
    # geluiden ook nodig toch voor alle animaties en ploffen")
    "ui_plof": ("A small wooden peg popping into a hole in an old oak game board, a short soft round tok with a tiny upward lift. " + SLOT, 0.3, 0.7),
    "ui_stempel": ("A wooden hand stamp pressed firmly onto parchment with a little sealing wax, a dull solid thud with a short papery slap. " + SLOT, 0.4, 0.6),
    "ui_draai": ("A single stiff parchment playing card flipped over on a wooden table, a quick paper flick and the soft tap of its edge landing. " + SLOT, 0.4, 0.7),
    "ui_tel": ("A tiny brass counter bead clicking against another on an old abacus, a very short bright little tick. " + SLOT, 0.2, 0.7),
    "ui_munt": ("A small brass coin dropped onto an oak table, a clear short ring with one tiny bounce. " + SLOT, 0.5, 0.6),
    "ui_blad": ("A page of thick old parchment turned over in a leather-bound book, a soft short rustle that swells and settles. " + SLOT, 0.6, 0.6),
    "card_stat_up": ("A small brass weight placed onto a balance scale, a bright short clink. " + SLOT, 0.4, 0.7),
    "card_stat_down": ("A small brass weight lifted off a balance scale, a soft short clink slightly lower in tone. " + SLOT, 0.4, 0.7),
    "card_confirm": ("A wax seal pressed firmly onto parchment, a soft thump with a short squish. " + SLOT, 0.7, 0.6),
    "card_deal": ("A single playing card dealt with a quick paper flick onto a wooden table. " + SLOT, 0.4, 0.7),
    "card_select": ("A single stiff paper card picked up from a table with a soft flick. " + SLOT, 0.4, 0.7),
    "link_snap": ("A wooden game piece snapped firmly into a wooden slot, a crisp satisfying click. " + SLOT, 0.4, 0.7),
    "reveal": ("A short military snare drum roll building for a second and ending on one firm hit. " + SLOT, 1.5, 0.6),
    "initiative": ("A single crisp stroke on a small military snare drum. " + SLOT, 0.5, 0.7),
    "phase_change": ("A short trumpet signal of two rising notes, an 18th century army bugle, clean and short. " + SLOT, 1.5, 0.5),
    "cycle_start": ("A single deep hit on a large regimental bass drum with a short natural decay. " + SLOT, 1.2, 0.6),
    "your_turn": ("A single short bright bugle note announcing a turn. " + SLOT, 0.9, 0.6),
    "place_pawn": ("A wooden game piece set down firmly on a wooden board, a solid short knock. " + SLOT, 0.4, 0.7),
    "place_undo": ("A wooden game piece lifted quickly off a wooden board, a light short scrape and tick. " + SLOT, 0.4, 0.7),
    "timer_tick": ("A single tick of an antique pocket watch. " + SLOT, 0.2, 0.7),
    "timer_warning": ("A fast series of ticks from an antique pocket watch, urgent, for one second. " + SLOT, 1.0, 0.6),
    "timer_timeout": ("A small bell on a desk struck once, a clear short ding. " + SLOT, 0.8, 0.6),
    "haven_score": ("A ship's brass bell rung twice in a harbor, bright and clean. " + SLOT, 1.8, 0.5),
    "win_fanfare": ("A short triumphant brass fanfare of trumpets and horns, a rising three-note flourish, 18th century military style.", 3.0, 0.5),
    "lose_sting": ("A short descending minor chord on solemn brass and a low drum hit, a defeated sting.", 3.0, 0.5),
    "spawn_sound": ("A puff of dust and a soft thump as a wooden game piece lands on a wooden board. " + SLOT, 0.6, 0.6),
    "music_menu": ("A calm 18th century military camp theme on fife and snare drum, slow march, soft and looping, no vocals.", 20.0, 0.3),
    "music_battle": ("A tense 18th century battle march on drums and brass, steady tempo, dramatic, looping, no vocals.", 20.0, 0.3),
    "ambient_field": ("Ambient sound of an open field near an army camp: light wind in grass, distant birds, a far-off drum, calm, looping.", 20.0, 0.3),
    # wapens: de zwaai
    "slash_sabel": ("A cavalry sabre swung fast through the air, one sharp thin steel whoosh. " + SLOT, 0.6, 0.7),
    "slash_bijl": ("A heavy battle axe swung through the air, one deep wide whoosh with the weight of the iron head. " + SLOT, 0.8, 0.7),
    "slash_lans": ("A long wooden lance thrust quickly through the air, one thin fast whistle. " + SLOT, 0.5, 0.7),
    "slash_bajonet": ("A musket with a fixed bayonet thrust forward fast, one very short whoosh with a hint of cloth rustling. " + SLOT, 0.5, 0.7),
    # wapens: de klap
    "melee_kill_sabel": ("A sabre slashing deep into a body: a wet slicing cut with a bright ring of steel. One strike. " + SLOT, 0.9, 0.6),
    "melee_kill_bijl": ("A heavy axe chopping into a body: a deep wet chop with a crack of bone. One strike. " + SLOT, 1.0, 0.6),
    "melee_kill_lans": ("A lance impaling a body: a sharp puncture, a wet squelch and the wooden shaft thumping. One strike. " + SLOT, 0.9, 0.6),
    "melee_kill_bajonet": ("A bayonet stabbed into a body: a wet punch with a short scrape of steel. One strike. " + SLOT, 0.8, 0.6),
    "melee_survive_sabel": ("Two cavalry sabres clashing once, a bright ringing steel clang, the blow blocked. " + SLOT, 0.8, 0.7),
    "melee_survive_bijl": ("A heavy axe blow blocked by a steel breastplate: a dull heavy clank and the wooden handle rattling. " + SLOT, 0.8, 0.6),
    "melee_survive_lans": ("A lance point glancing off steel armor, a scraping metallic slide ending in a tick. " + SLOT, 0.8, 0.6),
    "melee_survive_bajonet": ("A bayonet parried by a musket barrel, a small sharp steel clink and a short grunt of effort. " + SLOT, 0.7, 0.6),
    # diorama-props
    "prop_tik": ("A single dry tap of a fingernail on a small wooden game piece. " + SLOT, 0.3, 0.7),
    "prop_aambeeld": ("A blacksmith's hammer striking an iron anvil once, a bright ringing clang with a long metallic tail. " + SLOT, 1.5, 0.6),
    "prop_appel": ("An apple popping out of a wooden crate and landing on the ground with a soft thump. " + SLOT, 0.6, 0.6),
    "prop_bel": ("A small brass camp bell struck once, a clear bright ding with a short ringing tail. " + SLOT, 1.5, 0.6),
    "prop_bewoner_hak": ("A small hatchet chopping into a log on a chopping block, one solid wooden thunk. " + SLOT, 0.6, 0.7),
    "prop_bijl": ("An axe chopped into a wooden stump, one solid deep thunk. " + SLOT, 0.6, 0.7),
    "prop_boot": ("A small wooden rowing boat knocking against a wooden jetty on gentle water, a hollow wooden bump. " + SLOT, 1.0, 0.5),
    "prop_combo": ("A cheerful little chime of four ascending notes on a small glockenspiel. " + SLOT, 1.2, 0.6),
    "prop_doek": ("Canvas tent cloth flapping once in a gust of wind. " + SLOT, 0.8, 0.6),
    "prop_emmer": ("A wooden bucket on a rope lowered into a stone well, the rope creaking on a pulley and the bucket knocking the wall. " + SLOT, 1.5, 0.5),
    "prop_geit": ("A goat bleating once, a short comical baa. " + SLOT, 0.8, 0.6),
    "prop_glas": ("Two glass bottles knocked together once, a clear clink. " + SLOT, 0.5, 0.7),
    "prop_hek": ("An old wooden fence creaking as a loose plank rattles against the post. " + SLOT, 0.9, 0.6),
    "prop_hengel": ("A fishing line cast with a quick whip through the air and the reel ticking as it spins. " + SLOT, 1.2, 0.5),
    "prop_hooi": ("A pile of dry hay rustling as someone shoves it aside. " + SLOT, 0.9, 0.6),
    "prop_hoorn": ("A short single blast on a brass hunting horn, one clear note. " + SLOT, 1.0, 0.6),
    "prop_ijs": ("Thin ice on a puddle cracking under a boot, a sharp crackle. " + SLOT, 0.7, 0.6),
    "prop_kanon": ("A small cannon fired in the distance, a muffled boom with a soft echo. " + SLOT, 1.8, 0.5),
    "prop_kanon_tik": ("A knuckle tapping once on the iron barrel of a cannon, a short dull metallic tock. " + SLOT, 0.4, 0.7),
    "prop_kegel": ("An empty glass bottle knocked over, it tinks against another bottle and falls on packed earth with a hollow clonk. " + SLOT, 1.0, 0.6),
    "prop_kegel_rol": ("A heavy iron cannonball rolling over hard dry grass, a low rumbling rumble. " + SLOT, 1.5, 0.5),
    "prop_kikker": ("A frog croaking once from a pond, a short wet ribbit. " + SLOT, 0.6, 0.6),
    "prop_kip": ("A hen clucking three times, quick and busy. " + SLOT, 1.0, 0.6),
    "prop_klop": ("Two firm knocks of a knuckle on a thin wooden door. " + SLOT, 0.7, 0.7),
    "prop_kogel": ("Two iron cannonballs knocking together, a dull heavy iron clunk. " + SLOT, 0.5, 0.7),
    "prop_kokos": ("A coconut dropping from a palm tree and hitting the ground with a hard hollow thud. " + SLOT, 0.6, 0.6),
    "prop_kookpot": ("An iron lid dropped onto an iron cooking pot, a dull ringing bong. " + SLOT, 1.0, 0.6),
    "prop_kraai": ("A crow caws once. " + SLOT, 0.8, 0.6),
    "prop_kruitvat": ("A small powder keg exploding: a dull heavy bang followed by crackling sparks and falling wood. " + SLOT, 1.8, 0.5),
    "prop_lantaarn": ("A small iron lantern knocked and swinging, its metal frame tinkling twice. " + SLOT, 0.8, 0.6),
    "prop_molen": ("The wooden sails of an old windmill creaking slowly as they turn in the wind. " + SLOT, 1.5, 0.5),
    "prop_munt": ("A small coin tossed into a stone fountain, a light plink and a tiny splash. " + SLOT, 0.7, 0.6),
    "prop_nies": ("A small comical sneeze from a person hidden in a haystack, one sneeze. " + SLOT, 0.8, 0.5),
    "prop_plons": ("A stone dropped into a pond, a fat plop with a few bubbles. " + SLOT, 0.8, 0.6),
    "prop_ritsel": ("Leaves of a tree rustling in a short gust of wind. " + SLOT, 1.0, 0.6),
    "prop_sneeuw": ("A boot stepping into fresh snow, a soft crunching squeak. " + SLOT, 0.6, 0.6),
    "prop_steen": ("A stone knocked against another stone in an old ruin, a short hard clack. " + SLOT, 0.5, 0.7),
    "prop_ton": ("A knuckle knocking once on an empty wooden barrel, a hollow wooden thump. " + SLOT, 0.6, 0.7),
    "prop_trom": ("A single hit on a small military drum, a dull thump on the drumhead. " + SLOT, 0.5, 0.7),
    "prop_uil": ("An owl hooting twice at night, soft and low. " + SLOT, 1.5, 0.5),
    "prop_vis": ("A wet fish slapped onto wooden planks and flopping twice. " + SLOT, 1.0, 0.6),
    "prop_vuur": ("A campfire crackling and popping for a moment. " + SLOT, 1.2, 0.6),
    "prop_wc": ("A thin wooden outhouse door slamming shut with a squeak of the hinge. " + SLOT, 0.9, 0.6),
    "prop_wegwijzer": ("A wooden signpost creaking as its sign swings in the wind. " + SLOT, 1.0, 0.6),
    "prop_zand": ("Dry sand sliding down a slope, a soft hiss of grains. " + SLOT, 1.0, 0.6),
    "prop_schot": ("A single flintlock musket shot with a short crack and a soft echo. " + SLOT, 1.2, 0.6),
    "bewoner_snurken": ("A man snoring twice, soft and comical. " + SLOT, 1.5, 0.5),
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--droogloop", action="store_true")
    ap.add_argument("--overschrijf", action="store_true", help="ook prompts die in de studio zijn aangepast vervangen")
    ap.add_argument("--kreten", action="store_true", help="alleen de kreten (sterven, kanon) opnieuw zetten, ook als ze in de studio zijn aangepast")
    a = ap.parse_args()
    prompts, inst = kreten()
    kreet_cats = set(prompts) | {"inf_die", "cav_die", "cav_kanon_die"}
    kreet_cats = {c for c in kreet_cats if "_die" in c}
    for cat, (p, duur, invloed) in HAND.items():
        prompts[cat] = p
        inst[cat] = {"duur": duur, "invloed": invloed}
    for cat in list(prompts):
        if cat in GEEN_REEKS:
            continue
        prompts[cat] = prompts[cat].replace("One single cry. ", "").replace("One single short scream. ", "")             .replace("One single sound. ", "").replace("One single short cry. ", "").replace("One single crash. ", "").replace("Just one step. ", "")             .replace("One shot. ", "").replace("One impact. ", "").replace("One hit. ", "").replace("One strike. ", "")             .replace("One clash. ", "").replace("One click. ", "").replace("One fall. ", "").replace("One crack. ", "")             .replace("One splatter. ", "").replace("One killing thrust. ", "").replace("One clash. ", "") + REEKS
        inst[cat]["duur"] = REEKS_DUUR
    try:
        studio = json.load(io.open(STUDIO_JSON, encoding="utf-8"))
    except (OSError, ValueError):
        studio = {}
    oud_p = studio.setdefault("prompts", {})
    oud_i = studio.setdefault("instellingen", {})
    eigen = studio.setdefault("uit_generator", {})   # wat de generator schreef: zo zien we later wat Max zelf wijzigde
    nieuw = behouden = 0
    for cat, p in prompts.items():
        if not a.overschrijf and not (a.kreten and cat in kreet_cats) and cat in oud_p and oud_p[cat] != eigen.get(cat):
            behouden += 1
            continue
        oud_p[cat] = p
        oud_i[cat] = dict(inst[cat])
        eigen[cat] = p
        nieuw += 1
    studio.setdefault("standaard", {}).update({"duur": 0.0, "invloed": 0.6, "model": "eleven_text_to_sound_v2"})
    print("%d prompts gezet, %d handmatig aangepaste bewaard (--overschrijf zet ook die)" % (nieuw, behouden))
    if a.droogloop:
        for cat in sorted(prompts)[:5]:
            print(" ", cat, "->", prompts[cat][:90])
        return
    with io.open(STUDIO_JSON, "w", encoding="utf-8", newline="\n") as f:
        json.dump(studio, f, indent=1, sort_keys=True, ensure_ascii=False)
    print("geschreven:", os.path.relpath(STUDIO_JSON, WORTEL))


if __name__ == "__main__":
    main()

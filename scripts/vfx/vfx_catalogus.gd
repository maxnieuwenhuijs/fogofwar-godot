extends RefCounted

## De catalogus van alle effecten (6 oktober 2026, docs/VFX-studio.md): wat er in
## het spel zit en wat Max wil, per groep, met de knoppen die het bijstellen.
## De VFX-tuner, `-- vfxcheck`, `-- vfxshot` en (straks) de concept-webpagina
## lezen hem; de knoppen zelf staan in assets/models/effects_tuning.json en de
## code leest ze met `PawnView.fx(sleutel, standaard)`. Zonder class_name:
## `const Catalogus := preload("res://scripts/vfx/vfx_catalogus.gd")`.

const STIJL := preload("res://scripts/vfx/stijl.gd")
##
## Een effect: id, groep, naam, wanneer (in het spel), knoppen (sleutels uit
## KNOPPEN), status ("spel" = zit erin, "wens" = nog te bouwen, "diorama" = in
## het diorama maar nog met vaste waarden), speel (het recept in de tuner; leeg
## = nog niet af te spelen), schutter (wie de tuner neerzet: "musket", "kanon"
## of "ruiter"; standaard musket), doel (wat er geraakt wordt: "musket" of
## "kanon"; standaard musket), de onderdelen (texturen en decals uit
## ONDERDELEN die het gebruikt) en een notitie.

const GROEPEN: Array = [
	{"id": "kruit", "naam": "Kruitdamp en vuurmond"},
	{"id": "stof", "naam": "Stof en aarde"},
	{"id": "bloed", "naam": "Bloed en inslag"},
	{"id": "melee", "naam": "Zwaai en klap"},
	{"id": "dood", "naam": "Sterven en brokstukken"},
	{"id": "vuur", "naam": "Vuur en explosies"},
	{"id": "stijl", "naam": "Stijl (alle 3D)"},
]

## Elke knop: label, bereik, stap en standaard (dezelfde als in de Model-tuner,
## FX_DEFS, en het sfeer-paneel, AMBIANCE_DEFS, zodat ze nergens verschillen).
const KNOPPEN: Dictionary = {
	"fire_size": {"label": "vuur-maat", "min": 0.1, "max": 10.0, "step": 0.01, "def": 1.0},
	"fire_life": {"label": "vuur-duur", "min": 0.03, "max": 2.0, "step": 0.01, "def": 0.14},
	"fire_light": {"label": "vuur-licht", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.6},
	"fire_shake": {"label": "vuur-schok", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.0},
	"smoke_amount": {"label": "rook-aantal", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.0},
	"smoke_size": {"label": "rook-maat", "min": 0.1, "max": 10.0, "step": 0.01, "def": 1.0},
	"smoke_grow": {"label": "rook-groei", "min": 0.5, "max": 10.0, "step": 0.01, "def": 3.0},
	"smoke_life": {"label": "rook-duur", "min": 0.1, "max": 10.0, "step": 0.01, "def": 1.8},
	"smoke_drift": {"label": "rook-drift", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.0},
	"smoke_alpha": {"label": "rook-alpha", "min": 0.05, "max": 1.0, "step": 0.01, "def": 1.0},
	"smoke_fade": {"label": "rook-vervaag", "min": 0.0, "max": 0.95, "step": 0.01, "def": 0.35},
	"smoke_linger_chance": {"label": "rook-blijfkans", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.25},
	"smoke_rise": {"label": "rook-stijg", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.0},
	"impact_smoke_life": {"label": "inslag-rook-duur", "min": 0.05, "max": 5.0, "step": 0.01, "def": 0.6},
	"smoke_wind": {"label": "rook met de wind", "min": 0.0, "max": 3.0, "step": 0.01, "def": 0.6},
	"kanon_ring": {"label": "rookring (kanon)", "min": 0.0, "max": 2.0, "step": 0.01, "def": 1.0},
	"kanon_pluim": {"label": "rookpluim (kanon)", "min": 0.0, "max": 2.0, "step": 0.01, "def": 1.0},
	"pan_flits": {"label": "kruitflits op de pan", "min": 0.0, "max": 3.0, "step": 0.01, "def": 1.0},
	"propjes": {"label": "gloeiende propjes", "min": 0.0, "max": 3.0, "step": 0.01, "def": 1.0},
	"stof_landing": {"label": "stof bij de landing (charge)", "min": 0.0, "max": 3.0, "step": 0.01, "def": 1.0},
	"stof_galop": {"label": "stof achter ruiters en kanonnen", "min": 0.0, "max": 3.0, "step": 0.01, "def": 1.0},
	"stof_alfa": {"label": "stof: dekking", "min": 0.05, "max": 1.0, "step": 0.01, "def": 0.7},
	"aarde_inslag": {"label": "opspattende aarde (kanon)", "min": 0.0, "max": 3.0, "step": 0.01, "def": 1.0},
	"krater": {"label": "krater (maat, 0 = geen)", "min": 0.0, "max": 3.0, "step": 0.01, "def": 1.0},
	"krater_duur": {"label": "krater blijft liggen (s)", "min": 0.5, "max": 120.0, "step": 0.5, "def": 25.0},
	"inslag_materiaal": {"label": "inslag per materiaal (0 = gele vonken)", "min": 0.0, "max": 1.0, "step": 1.0, "def": 1.0},
	"bloed_waaier": {"label": "bloedwaaier bij een dode", "min": 0.0, "max": 3.0, "step": 0.01, "def": 1.0},
	"inslag_sterkte": {"label": "inslag: hoeveel (vlees en hout)", "min": 0.0, "max": 3.0, "step": 0.01, "def": 1.0},
	"vuur_maat": {"label": "vuur: maat", "min": 0.0, "max": 3.0, "step": 0.01, "def": 1.0},
	"vuur_duur": {"label": "vuur: brandt na (s, 0 = niet)", "min": 0.0, "max": 60.0, "step": 0.5, "def": 12.0},
	"explosie": {"label": "explosie: kracht", "min": 0.0, "max": 3.0, "step": 0.01, "def": 1.0},
	"kanon_kapot": {"label": "kanon ontploft (0 = uit)", "min": 0.0, "max": 1.0, "step": 1.0, "def": 1.0},
	"link_puff": {"label": "koppel-wolkje", "min": 0.0, "max": 3.0, "step": 0.01, "def": 1.0},
	"blood_burst": {"label": "wond-druppels", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.0},
	"blood_spurt": {"label": "spuit-straal", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.0},
	"blood_mist": {"label": "kanon-mist", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.0},
	"blood_mist_melee": {"label": "melee-wolk (x kanon)", "min": 0.0, "max": 2.0, "step": 0.01, "def": 0.55},
	"mist_travel": {"label": "mist-dracht", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.6},
	"drop_fall_time": {"label": "druppel-duur", "min": 0.1, "max": 10.0, "step": 0.01, "def": 1.0},
	"drop_size": {"label": "druppel-maat", "min": 0.1, "max": 10.0, "step": 0.01, "def": 1.0},
	"wound_blood": {"label": "wond-bloed (overleven)", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.0},
	"wound_delay": {"label": "wond-vertraging", "min": 0.0, "max": 3.0, "step": 0.01, "def": 0.0},
	"wound_straal": {"label": "wond-straaltje (lengte)", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.22},
	"wound_straal_dikte": {"label": "straaltje dikte (voet)", "min": 0.005, "max": 0.1, "step": 0.001, "def": 0.022},
	"wound_straal_op": {"label": "straaltje op (s)", "min": 0.01, "max": 0.5, "step": 0.01, "def": 0.07},
	"wound_straal_duur": {"label": "straaltje terug (s)", "min": 0.05, "max": 2.0, "step": 0.01, "def": 0.3},
	"drop_stain_chance": {"label": "druppel-vlekkans", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.35},
	"drop_stain_delay": {"label": "vlek-wacht", "min": 0.0, "max": 10.0, "step": 0.01, "def": 0.05},
	"drop_stain_grow": {"label": "vlek-groei", "min": 0.05, "max": 10.0, "step": 0.01, "def": 0.25},
	"gib_pool_delay": {"label": "gib-poel-wacht", "min": 0.0, "max": 10.0, "step": 0.01, "def": 0.1},
	"gib_pool_grow": {"label": "gib-poel-groei", "min": 0.05, "max": 10.0, "step": 0.01, "def": 0.45},
	"blood_extra_delay": {"label": "plas-wacht", "min": 0.0, "max": 10.0, "step": 0.01, "def": 0.4},
	"blood_grow": {"label": "plas-groei", "min": 0.05, "max": 10.0, "step": 0.01, "def": 1.0},
	"blood_size": {"label": "plas-maat", "min": 0.05, "max": 10.0, "step": 0.01, "def": 1.0},
	"death_blood_delay": {"label": "lijkpoel-fallback", "min": 0.0, "max": 10.0, "step": 0.01, "def": 0.9},
	"debris_donker_na": {"label": "donker na (s)", "min": 0.0, "max": 30.0, "step": 0.5, "def": 4.0},
	"debris_donker_duur": {"label": "donker duur (s)", "min": 0.1, "max": 15.0, "step": 0.1, "def": 2.5},
	"debris_donker": {"label": "hoe donker", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.7},
	"debris_doorzicht": {"label": "hoe doorzichtig", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.55},
	"debris_zak": {"label": "zakt in bord", "min": 0.0, "max": 0.5, "step": 0.01, "def": 0.08},
	"hat_fling_power": {"label": "hoed-kracht", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.5},
	"hat_fling_time": {"label": "hoed-hangtijd", "min": 0.1, "max": 10.0, "step": 0.01, "def": 1.8},
	"hat_pop_chance": {"label": "hoed-kans", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.55},
	"limb_shed_chance": {"label": "ledemaat-kans", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.4},
	"limb_fling_power": {"label": "ledemaat-kracht", "min": 0.0, "max": 10.0, "step": 0.01, "def": 0.9},
	"limb_fling_time": {"label": "ledemaat-hangtijd", "min": 0.1, "max": 10.0, "step": 0.01, "def": 1.0},
	"gib_fling_power": {"label": "gib-worpkracht", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.0},
	"gib_spin": {"label": "gib-tolling", "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.0},
	"gib_bloed": {"label": "bloedspatten op gibs", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.45},
	"slice_kans_sabel": {"label": "doormidden-kans (sabel)", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.85},
	"slice_kans_bajonet": {"label": "doormidden-kans (bajonet)", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.35},
	"slice_hoogte": {"label": "snijhoogte (deel van de pion)", "min": 0.15, "max": 0.85, "step": 0.01, "def": 0.55},
	"slice_hoek": {"label": "snijhoek sabel (graden)", "min": 0.0, "max": 70.0, "step": 1.0, "def": 35.0},
	"slice_hoek_bajonet": {"label": "snijhoek bajonet (graden)", "min": 0.0, "max": 70.0, "step": 1.0, "def": 10.0},
	"slice_sta": {"label": "benen staan nog (s)", "min": 0.0, "max": 2.0, "step": 0.01, "def": 0.35},
	"slice_los": {"label": "losse stukjes (wolkje)", "min": 0.0, "max": 4.0, "step": 1.0, "def": 2.0},
	"slice_kracht": {"label": "helft-worpkracht", "min": 0.0, "max": 5.0, "step": 0.01, "def": 1.0},
	"slice_tuimel": {"label": "salto's van de romp", "min": 0.0, "max": 3.0, "step": 0.5, "def": 1.0},
	"slash_spoor": {"label": "zwaaispoor (sterkte, 0 = uit)", "min": 0.0, "max": 3.0, "step": 0.01, "def": 1.0},
	"slash_duur": {"label": "zwaaispoor: hoe lang een stukje blijft (s)", "min": 0.03, "max": 0.6, "step": 0.01, "def": 0.22},
	"slash_dikte": {"label": "zwaaispoor: dikte van het lijntje", "min": 0.005, "max": 0.3, "step": 0.005, "def": 0.08},
	"slash_lengte": {"label": "zwaaispoor: wapenlengte zonder los wapen", "min": 0.1, "max": 1.5, "step": 0.01, "def": 0.5},
	"slash_start": {"label": "zwaaispoor: begint voor de klap (s)", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.2},
	"slash_na": {"label": "zwaaispoor: loopt door na de klap (s)", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.35},
	"slash_gloed": {"label": "zwaaispoor: gloed", "min": 0.0, "max": 3.0, "step": 0.01, "def": 1.0},
	"slash_team": {"label": "zwaaispoor: teamkleur (0 = wit staal)", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.35},
	"dust": {"label": "stofdeeltjes", "min": 0.0, "max": 3.0, "step": 0.01, "def": 1.0},
	"footprints": {"label": "voetsporen", "min": 0.0, "max": 1.0, "step": 1.0, "def": 1.0},
	"footprint_dark": {"label": "voetspoor-donkerte", "min": 0.0, "max": 1.0, "step": 0.01, "def": 0.32},
	"wheel_width": {"label": "wielspoor-breedte", "min": 0.005, "max": 0.12, "step": 0.001, "def": 0.024},
	"wheel_base": {"label": "wielbasis", "min": 0.05, "max": 0.6, "step": 0.005, "def": 0.17},
}

const _ROOK := ["smoke_amount", "smoke_size", "smoke_grow", "smoke_life", "smoke_drift", "smoke_alpha",
	"smoke_fade", "smoke_linger_chance", "smoke_rise"]
const _VUUR := ["fire_size", "fire_life", "fire_light", "fire_shake"]
const _WOND := ["wound_blood", "wound_delay", "wound_straal", "wound_straal_dikte", "wound_straal_op",
	"wound_straal_duur", "blood_burst", "blood_spurt", "drop_size", "drop_fall_time", "drop_stain_chance",
	"drop_stain_delay", "drop_stain_grow"]
const _LIJK := ["debris_donker_na", "debris_donker_duur", "debris_donker", "debris_doorzicht", "debris_zak"]
const _SLASH := ["slash_spoor", "slash_duur", "slash_dikte", "slash_lengte", "slash_start", "slash_na",
	"slash_gloed", "slash_team"]

## De texturen en decals die de effecten gebruiken (6 oktober, stap 8; Max: "het
## doel is om met de studio ook de textures en alle decals die nodig zijn aan te
## leveren"). Waar ze staan (assets/textures/<map>/) en hoe het spel ze vindt:
## `soort` "flipbook" = een vel met het rooster in de naam (musket_3x3.png), het
## spel neemt het eerste bestand waarvan de naam `bestand` bevat; "varianten" =
## alle bestanden die met `bestand` beginnen, het spel kiest er een; "vast" =
## precies `bestand`.png. `achtergrond` "zwart": een plaatje zonder
## doorzichtigheid krijgt die bij het laden uit de helderheid (maal `boost`);
## "alpha": een PNG met doorzichtigheid. `gebruikt` false = het spel kijkt er
## nog niet naar (eerst ombouwen). De VFX-studio levert ze aan (tools/
## vfx_studio.py, groep "Texturen en decals"); `prompt` is de beginprompt voor
## een plaatje, `film` die voor een filmpje (leeg = geen filmpje nodig).
const ONDERDELEN: Dictionary = {
	"rook_musket": {"naam": "Kruitdamp (rookwolk)", "map": "smoke", "bestand": "musket", "soort": "flipbook",
		"achtergrond": "zwart", "boost": 2.3, "gebruikt": true,
		"uitleg": "elke rookwolk van een schot: aan de loop, op de inslag, de ring en de pluim; beeldje 0 draagt de vlam, de wolk speelt vanaf beeldje 1",
		"prompt": "A single puff of grey-white black-powder smoke, soft and billowing, centered, isolated on a solid pure black background, game VFX texture, no ground, no text.",
		"film": "A single puff of grey-white black-powder smoke bursts out from the center, billows outward and slowly dissolves, isolated on a solid pure black background."},
	"rook_wit": {"naam": "Witte pof", "map": "smoke", "bestand": "white_smoke", "soort": "flipbook",
		"achtergrond": "zwart", "boost": 2.3, "gebruikt": true,
		"uitleg": "het witte wolkje bij koppelen en bij een nieuwe pion; bruin getint is het nu ook het stof",
		"prompt": "A clean round puff of soft white smoke, centered, isolated on a solid pure black background, game VFX texture, no text.",
		"film": "A small round puff of soft white smoke pops out from the center and fades away, isolated on a solid pure black background."},
	"vlam_musket": {"naam": "Vuurmond musket", "map": "fire", "bestand": "musket", "soort": "flipbook",
		"achtergrond": "zwart", "boost": 1.5, "gebruikt": true,
		"uitleg": "de steekvlam van een musket; het vel speelt af binnen de flits",
		"prompt": "A musket muzzle flash seen from the side: a short bright orange-yellow burst of fire with a few sparks, centered, isolated on a solid pure black background, game VFX texture.",
		"film": "A short bright orange muzzle flash bursts from the center and vanishes, isolated on a solid pure black background."},
	"vlam_kanon": {"naam": "Vuurmond kanon en vuurbal", "map": "fire", "bestand": "cannon", "soort": "flipbook",
		"achtergrond": "zwart", "boost": 1.5, "gebruikt": true,
		"uitleg": "de grote vlam van een kanon, en de vuurbal van een explosie",
		"prompt": "A large cannon muzzle blast: a big round burst of orange and yellow fire with dark edges, centered, isolated on a solid pure black background, game VFX texture.",
		"film": "A big ball of orange fire bursts out from the center, rolls outward and burns out into dark smoke, isolated on a solid pure black background."},
	"bloed_spetter": {"naam": "Bloedspetters", "map": "blood", "bestand": "splat", "soort": "varianten",
		"achtergrond": "alpha", "boost": 1.0, "gebruikt": true,
		"uitleg": "fijne spetters op het bord (de bloedwaaier, druppels); elke spetter kiest een variant",
		"prompt": "A small splatter of dark red blood seen from straight above, stylized, on a pure white background, game decal texture, no shadow.",
		"film": ""},
	"bloed_plas": {"naam": "Bloedplas", "map": "blood", "bestand": "blood_pool", "soort": "varianten",
		"achtergrond": "alpha", "boost": 1.0, "gebruikt": true,
		"uitleg": "de plas onder een dode, die langzaam groeit; elke plas kiest een variant",
		"prompt": "A small pool of dark red blood seen from straight above, irregular round shape, stylized, on a pure white background, game decal texture, no shadow.",
		"film": ""},
	"bloed_nevel": {"naam": "Bloednevel", "map": "blood", "bestand": "blood_mist", "soort": "varianten",
		"achtergrond": "alpha", "boost": 1.0, "gebruikt": true, "vel": true,
		"uitleg": "de rode wolk bij een dood door het kanon en bij de sabelhouw; elk plukje kiest een variant, een vel (rooster in de naam, bv. blood_mist1_4x3) speelt af",
		"prompt": "A soft cloud of fine red mist, centered, on a solid pure black background, game VFX texture.",
		"film": "A burst of fine red mist puffs out from the center and drifts apart, on a solid pure black background."},
	"voetstap_links": {"naam": "Voetstap links", "map": "footstep", "bestand": "left", "soort": "vast",
		"achtergrond": "alpha", "boost": 1.0, "gebruikt": true,
		"uitleg": "een afdruk in het stof, de neus naar boven; per factie kan ook <factie>_left (bv. mouse_left)",
		"prompt": "A single small left boot print pressed into dust, seen from straight above, toe pointing up, dark brown on a pure white background, game decal texture.",
		"film": ""},
	"voetstap_rechts": {"naam": "Voetstap rechts", "map": "footstep", "bestand": "right", "soort": "vast",
		"achtergrond": "alpha", "boost": 1.0, "gebruikt": true,
		"uitleg": "de rechtervoet; per factie kan ook <factie>_right",
		"prompt": "A single small right boot print pressed into dust, seen from straight above, toe pointing up, dark brown on a pure white background, game decal texture.",
		"film": ""},
	"wielspoor": {"naam": "Wielspoor", "map": "footstep", "bestand": "wiel", "soort": "vast",
		"achtergrond": "alpha", "boost": 1.0, "gebruikt": true,
		"uitleg": "een stukje spoor van een kanonwiel, een strook in de lengte; het spel snijdt hem bij tot wat er te zien is (zonder bestand een effen streep)",
		"prompt": "A short straight wheel track pressed into dust, seen from straight above, a narrow vertical strip, dark brown on a pure white background, game decal texture.",
		"film": ""},
	"krater": {"naam": "Krater of schroeiplek", "map": "decals", "bestand": "krater", "soort": "varianten",
		"achtergrond": "alpha", "boost": 1.0, "gebruikt": true,
		"uitleg": "na een kanonsinslag; elke krater kiest een variant en wordt willekeurig gedraaid (zonder bestanden tekent de code er zelf een)",
		"prompt": "A small scorched crater in dry earth seen from straight above, a dark burnt center with a ring of thrown-up dirt, stylized, on a pure white background, game decal texture.",
		"film": ""},
	# Stof en vuur als varianten (7 oktober, Max: "ik zie nog niet de verschillende
	# stofwolkjes, dit moeten iets van 3-6 unieke zijn die random worden afgespeeld",
	# "net als vuur"): elk plukje en elke vlam kiest er een (VFX._kies_geleverd).
	"stof": {"naam": "Stofwolk", "map": "dust", "bestand": "stof", "soort": "varianten",
		"achtergrond": "zwart", "boost": 2.3, "gebruikt": true, "vel": true,
		"uitleg": "het stof bij de landing van een charge, achter ruiters en kanonnen, bij een kanonsinslag en in de schokgolf van een explosie, in zijn eigen kleur; zet er 3-6 verschillende bij, elk wolkje kiest er willekeurig een, een vel speelt af (zonder bestand de witte pof in bruin)",
		"prompt": "A puff of light brown dust kicked up from the ground, soft and grainy, centered, isolated on a solid pure black background, game VFX texture.",
		"film": "A puff of light brown dust is kicked up from the center, spreads out and settles, isolated on a solid pure black background."},
	"vlam_bord": {"naam": "Vlammen op het bord", "map": "flame", "bestand": "vlam", "soort": "varianten",
		"achtergrond": "zwart", "boost": 1.5, "gebruikt": true, "vel": true,
		"uitleg": "de vlammen van iets dat blijft branden (het wrak van een kanon): het spel knipt de vlam uit het plaatje en laat hem golven en flakkeren; zet er 3-6 verschillende bij, elke vlam kiest er willekeurig een, een vel speelt zijn beeldjes af (zonder bestand een vlam uit de shader)",
		"prompt": "A small flickering flame, orange and yellow, centered, isolated on a solid pure black background, game VFX texture.",
		"film": "A small flame flickers and dances in place, centered, isolated on a solid pure black background, seamless loop."},
	# De nieuwe effecten van stap 2 t/m 5 elk een eigen textuur (6 oktober, Max:
	# "al deze nieuwe vfx moeten hun eigen decal krijgen"). Zonder bestand tekent
	# de code wat hij daarvoor tekende.
	"kogel_musket": {"naam": "Musketkogel in de vlucht", "map": "bullet", "bestand": "musket", "soort": "varianten",
		"achtergrond": "zwart", "boost": 1.6, "gebruikt": true, "vel": true,
		"uitleg": "de gloeiende kogel die van de loop naar het doel vliegt, als billboard (zonder bestand een geel bolletje)",
		"prompt": "A small glowing musket ball in flight, a bright yellow-orange dot with a short soft glow, centered, isolated on a solid pure black background, game VFX texture.",
		"film": ""},
	"kogel_kanon": {"naam": "Kanonskogel in de vlucht", "map": "bullet", "bestand": "cannon", "soort": "varianten",
		"achtergrond": "zwart", "boost": 1.6, "gebruikt": true, "vel": true,
		"uitleg": "de streep van een kanonskogel, plat langs de vliegrichting: links de kogel, naar rechts de streep die vervaagt (zonder bestand een donkere uitgerekte bol)",
		"prompt": "A fast cannonball motion streak seen from the side: a dark iron ball at the left with a pale smoky streak fading out to the right, a long thin horizontal shape, isolated on a solid pure black background, game VFX texture.",
		"film": ""},
	"propje": {"naam": "Gloeiend propje", "map": "sparks", "bestand": "propje", "soort": "varianten",
		"achtergrond": "zwart", "boost": 2.0, "gebruikt": true, "vel": true,
		"uitleg": "de gloeiende propjes uit de loop en de vonkjes van een explosie: ze vliegen, liggen te gloeien en doven, het spel kleurt ze van geel naar donkerrood; een vel speelt af (zonder bestand een gloeiend bolletje)",
		"prompt": "A single small glowing ember, a burning scrap of paper wadding with a bright orange core and dark edges, centered, isolated on a solid pure black background, game VFX texture.",
		"film": "A small glowing ember flickers and slowly dims, centered, isolated on a solid pure black background."},
	"vonk": {"naam": "Vonk", "map": "sparks", "bestand": "vonk", "soort": "varianten",
		"achtergrond": "zwart", "boost": 2.0, "gebruikt": true, "vel": true,
		"uitleg": "de vonken die van een kuras spatten (en de gele vonken van vroeger); elke vonk kiest een variant, een vel speelt af (zonder bestand een geel bolletje)",
		"prompt": "A single bright yellow-white spark with a short sharp glowing streak, centered, isolated on a solid pure black background, game VFX texture.",
		"film": "A bright spark flares up in the center and fades out quickly, isolated on a solid pure black background."},
	"flits": {"naam": "Flits", "map": "flash", "bestand": "flits", "soort": "varianten",
		"achtergrond": "zwart", "boost": 1.5, "gebruikt": true, "vel": true,
		"uitleg": "de korte felle flits van een kogel die op een kuras ketst, van de kruitflits op de pan en van een explosie (zonder bestand een witte bol)",
		"prompt": "A short bright white-yellow flash of light, a small round starburst with soft rays, centered, isolated on a solid pure black background, game VFX texture.",
		"film": "A bright white flash bursts in the center and vanishes, isolated on a solid pure black background."},
	"kluit": {"naam": "Kluit aarde", "map": "debris", "bestand": "kluit", "soort": "varianten",
		"achtergrond": "alpha", "boost": 1.0, "gebruikt": true, "vel": true,
		"uitleg": "de kluiten die bij een kanonsinslag opspatten, neerkomen en even blijven liggen; elke kluit kiest een variant, een vel (rooster in de naam, bv. kluit1_4x4) tolt tijdens de vlucht (zonder bestand een blokje aarde)",
		"prompt": "A single small clump of dark brown earth with a few tiny pebbles and bits of grass, seen from the side, stylized, on a pure white background, game sprite, no shadow.",
		"film": "A small clump of dark brown earth tumbles and spins in place, on a pure white background."},
	"splinter": {"naam": "Houtsplinter", "map": "debris", "bestand": "splinter", "soort": "varianten",
		"achtergrond": "alpha", "boost": 1.0, "gebruikt": true, "vel": true,
		"uitleg": "de splinters van een geraakt of ontploft kanon; elke splinter kiest een variant, een vel tolt tijdens de vlucht (zonder bestand een latje hout)",
		"prompt": "A single small jagged splinter of light brown wood, seen from the side, stylized, on a pure white background, game sprite, no shadow.",
		"film": "A small jagged wooden splinter tumbles and spins in place, on a pure white background."},
	"schokgolf": {"naam": "Schokgolf", "map": "decals", "bestand": "schokgolf", "soort": "varianten",
		"achtergrond": "alpha", "boost": 1.0, "gebruikt": true,
		"uitleg": "de kring stof die bij een explosie over de grond wegschiet, van boven gezien: het spel laat hem snel uitdijen en vervagen, onder de stofwolkjes (zonder bestand alleen de stofwolkjes)",
		"prompt": "A ring of dust and dirt blown outward over dry ground, seen from straight above, a ragged bright ring with a soft faded center, stylized, on a pure white background, game decal texture.",
		"film": ""},
	"slash": {"naam": "Zwaaispoor", "map": "trails", "bestand": "slash", "soort": "varianten",
		"achtergrond": "zwart", "boost": 1.5, "gebruikt": true,
		"uitleg": "het lijntje langs de baan van de punt van een sabel, bijl, lans of bajonet: links bij het wapen, naar rechts het oudste stuk dat vervaagt; boven en onder de randen van het lijntje (zonder bestand een zacht lijntje)",
		"prompt": "A horizontal motion streak of a sword slash: a thin bright white-blue line with soft glowing edges above and below, brightest and sharpest at the left end and fading out to the right, isolated on a solid pure black background, game VFX texture.",
		"film": ""},
}

const EFFECTEN: Array = [
	# --- Kruitdamp en vuurmond -------------------------------------------------
	{"id": "schot_musket", "groep": "kruit", "naam": "Musketschot", "status": "spel", "speel": "schot_musket",
		"wanneer": "elk musketschot: kogel, vuurmond, kruitflits op de pan, propjes, kruitdamp, inslagrook",
		"knoppen": _VUUR + ["pan_flits", "propjes", "smoke_wind"] + _ROOK + ["impact_smoke_life"], "onderdelen": ["rook_musket", "vlam_musket", "kogel_musket", "flits", "propje"]},
	{"id": "schot_kanon", "groep": "kruit", "naam": "Kanonschot", "status": "spel", "speel": "schot_kanon", "schutter": "kanon",
		"wanneer": "elk kanonschot: streep, grote vuurmond, rookring, pluim, propjes, kruitdamp, inslagrook",
		"knoppen": _VUUR + ["kanon_ring", "kanon_pluim", "propjes", "smoke_wind"] + _ROOK + ["impact_smoke_life"], "onderdelen": ["rook_musket", "vlam_kanon", "kogel_kanon", "propje"]},
	{"id": "kruitdamp", "groep": "kruit", "naam": "Kruitdamp aan de loop", "status": "spel", "speel": "kruitdamp",
		"wanneer": "na elk schot, drijft met het schot en de wind mee en stijgt op", "knoppen": ["smoke_wind"] + _ROOK, "onderdelen": ["rook_musket"]},
	{"id": "koppelwolkje", "groep": "kruit", "naam": "Wit wolkje bij koppelen", "status": "spel", "speel": "koppelwolkje",
		"wanneer": "een kaart koppelen of ontkoppelen", "knoppen": ["link_puff", "smoke_wind"] + _ROOK, "onderdelen": ["rook_wit"]},
	{"id": "rook_wind", "groep": "kruit", "naam": "Rook met de wind mee", "status": "spel", "speel": "rook_wind",
		"wanneer": "alle rook drijft met de wind van het potje, zoals de vlaggen (de tuner: schuif wind)",
		"knoppen": ["smoke_wind", "smoke_life", "smoke_linger_chance"], "onderdelen": ["rook_musket"]},
	{"id": "rookring_kanon", "groep": "kruit", "naam": "Rookring en pluim bij het kanon", "status": "spel", "speel": "rookring", "schutter": "kanon",
		"wanneer": "een kanonschot: een ring die uitdijt en stilvalt, een dikke pluim die blijft hangen",
		"knoppen": ["kanon_ring", "kanon_pluim", "smoke_wind"], "onderdelen": ["rook_musket", "vlam_kanon"]},
	{"id": "pankruit", "groep": "kruit", "naam": "Kruitflits op de pan", "status": "spel", "speel": "pankruit",
		"wanneer": "een musketschot: een flitsje en een wolkje dat bij het slot omhoog krult", "knoppen": ["pan_flits", "smoke_wind"], "onderdelen": ["rook_musket", "flits"]},
	{"id": "propjes", "groep": "kruit", "naam": "Gloeiende propjes uit de loop", "status": "spel", "speel": "propjes",
		"wanneer": "een schot: gloeiende proppen die vallen, op het bord liggen en doven", "knoppen": ["propjes"], "onderdelen": ["propje"]},
	# --- Stof en aarde ---------------------------------------------------------
	{"id": "stofjes", "groep": "stof", "naam": "Stofjes in de lucht", "status": "spel", "speel": "",
		"wanneer": "zweven boven het bord (staat uit: stofdeeltjes 0)", "knoppen": ["dust"],
		"notitie": "zit in game.gd; nog niet af te spelen in de tuner"},
	{"id": "voetsporen", "groep": "stof", "naam": "Voetsporen en wielsporen", "status": "spel", "speel": "",
		"wanneer": "elke stap over het bord", "knoppen": ["footprints", "footprint_dark", "wheel_width", "wheel_base"],
		"notitie": "zit in game.gd; nog niet af te spelen in de tuner", "onderdelen": ["voetstap_links", "voetstap_rechts", "wielspoor"]},
	{"id": "charge_stof", "groep": "stof", "naam": "Stof bij de landing van een charge", "status": "spel",
		"speel": "charge_stof", "schutter": "ruiter",
		"wanneer": "de ruiter landt na zijn sprong: een kring stof om de hoeven", "knoppen": ["stof_landing", "stof_alfa", "smoke_wind"], "onderdelen": ["stof", "rook_wit"]},
	{"id": "galop_stof", "groep": "stof", "naam": "Stof achter galopperende ruiters", "status": "spel",
		"speel": "galop_stof", "schutter": "ruiter",
		"wanneer": "een ruiter (of een kanon, minder) rijdt hard over het bord", "knoppen": ["stof_galop", "stof_alfa", "smoke_wind"], "onderdelen": ["stof", "rook_wit"]},
	{"id": "inslag_aarde", "groep": "stof", "naam": "Opspattende aarde bij een kanonsinslag", "status": "spel",
		"speel": "schot_kanon", "schutter": "kanon",
		"wanneer": "een kanonskogel slaat in: kluiten en een stofwolk", "knoppen": ["aarde_inslag", "stof_alfa", "smoke_wind"], "onderdelen": ["kluit", "stof", "rook_wit"]},
	{"id": "krater", "groep": "stof", "naam": "Krater of schroeiplek", "status": "spel",
		"speel": "schot_kanon", "schutter": "kanon",
		"wanneer": "blijft na een kanonsinslag op het bord liggen en vervaagt", "knoppen": ["krater", "krater_duur"], "onderdelen": ["krater"]},
	# --- Bloed en inslag -------------------------------------------------------
	{"id": "vonken", "groep": "bloed", "naam": "Vonken op metaal", "status": "spel", "speel": "vonken",
		"wanneer": "een treffer op het kuras van de hp-pion: vonken en een witte flits",
		"knoppen": ["inslag_materiaal"], "onderdelen": ["vonk", "flits"]},
	{"id": "treffer", "groep": "bloed", "naam": "Treffer: flits, wankelen, wond", "status": "spel", "speel": "treffer",
		"wanneer": "een pion wordt geraakt en overleeft", "knoppen": _WOND, "onderdelen": ["bloed_spetter"]},
	{"id": "schadegetal", "groep": "bloed", "naam": "Schadegetal (-N)", "status": "spel", "speel": "schadegetal",
		"wanneer": "boven een geraakte pion", "knoppen": []},
	{"id": "inslag_materiaal", "groep": "bloed", "naam": "Inslag per materiaal", "status": "spel",
		"speel": "inslag_materiaal",
		"wanneer": "vlees: rode nevel en spatjes; hout (een kanon): splinters; metaal: vonken (zoals het geluid; na elkaar)",
		"knoppen": ["inslag_materiaal", "inslag_sterkte"], "onderdelen": ["bloed_spetter", "splinter", "vonk", "flits"]},
	{"id": "bloed_variatie", "groep": "bloed", "naam": "Bloedwaaier op de grond", "status": "spel", "speel": "dood_musket",
		"wanneer": "een dode: een waaier langgerekte spatten van de klap af, na elkaar neerkomend",
		"knoppen": ["bloed_waaier", "blood_size", "blood_grow"], "onderdelen": ["bloed_spetter", "bloed_plas"]},
	# --- Zwaai en klap (6 oktober, Max: "een slashing trail aan de melee wapens,
	# een lijntje om het effect wat kracht bij te geven, allemaal tunebaar") -----
	{"id": "zwaaispoor", "groep": "melee", "naam": "Zwaaispoor (bajonet)", "status": "spel", "speel": "slash",
		"wanneer": "een melee-aanval: een lijntje langs de baan van de punt van het wapen tijdens de stoot of de zwaai, dat snel vervaagt",
		"knoppen": _SLASH, "onderdelen": ["slash"]},
	{"id": "zwaaispoor_charge", "groep": "melee", "naam": "Zwaaispoor bij een charge", "status": "spel",
		"speel": "charge_slash", "schutter": "ruiter",
		"wanneer": "de ruiter springt en slaat: het lijntje achter zijn sabel, lans of bijl", "knoppen": _SLASH,
		"onderdelen": ["slash"]},
	# --- Sterven en brokstukken ------------------------------------------------
	{"id": "dood_musket", "groep": "dood", "naam": "Sterven door een musketkogel", "status": "spel", "speel": "dood_musket",
		"wanneer": "een kill met het musket: hoed of ledemaat kan loskomen, bloedplas",
		"knoppen": ["hat_pop_chance", "hat_fling_power", "hat_fling_time", "limb_shed_chance", "limb_fling_power",
			"limb_fling_time", "blood_size", "blood_grow", "blood_extra_delay", "death_blood_delay"] + _LIJK, "onderdelen": ["bloed_plas", "bloed_spetter"]},
	{"id": "dood_kanon", "groep": "dood", "naam": "Sterven door een kanonskogel (gibs)", "status": "spel", "speel": "dood_kanon", "schutter": "kanon",
		"wanneer": "een kill met het kanon: het lijf vliegt in stukken, bloednevel",
		"knoppen": ["gib_fling_power", "gib_spin", "gib_bloed", "blood_mist", "mist_travel", "gib_pool_delay",
			"gib_pool_grow"] + _LIJK, "onderdelen": ["bloed_nevel", "bloed_plas", "bloed_spetter"]},
	{"id": "dood_bajonet", "groep": "dood", "naam": "Sterven door de bajonet", "status": "spel", "speel": "dood_bajonet",
		"wanneer": "een kill in een gevecht van dichtbij", "knoppen": ["slice_kans_bajonet", "slice_hoek_bajonet",
			"limb_shed_chance", "blood_size"] + _LIJK, "onderdelen": ["bloed_plas"]},
	{"id": "doormidden", "groep": "dood", "naam": "Doormidden (sabelhouw)", "status": "spel", "speel": "doormidden",
		"wanneer": "een kill met de charge: het lijf in twee helften",
		"knoppen": ["slice_kans_sabel", "slice_hoogte", "slice_hoek", "slice_sta", "slice_los", "slice_kracht",
			"slice_tuimel", "blood_mist_melee"] + _LIJK, "onderdelen": ["bloed_nevel", "bloed_plas"]},
	# --- Vuur en explosies -----------------------------------------------------
	{"id": "kampvuur", "groep": "vuur", "naam": "Kampvuur in het diorama", "status": "diorama", "speel": "",
		"wanneer": "brandt in het kamp; klikken geeft rook of een knal", "knoppen": [],
		"notitie": "in omgeving.gd met vaste waarden"},
	{"id": "kanon_kapot", "groep": "vuur", "naam": "Kanon gaat kapot", "status": "spel", "speel": "dood_kanon",
		"schutter": "kanon", "doel": "kanon",
		"wanneer": "een kanon wordt vernietigd: het kruit ontploft, de affuit spat uiteen, het wrak brandt na",
		"knoppen": ["kanon_kapot", "explosie", "vuur_duur", "vuur_maat", "inslag_sterkte"], "onderdelen": ["vlam_kanon", "rook_musket", "flits", "schokgolf", "splinter", "propje", "vlam_bord"]},
	{"id": "kruitvat", "groep": "vuur", "naam": "Explosie (kruitvat)", "status": "spel", "speel": "explosie",
		"wanneer": "flits, vuurbal, schokgolf, rookkolom, brokstukken en vonken (nu bij een kanon; straks ook kruitvaten)",
		"knoppen": ["explosie", "smoke_wind"], "onderdelen": ["vlam_kanon", "rook_musket", "flits", "schokgolf", "splinter", "propje"]},
	{"id": "vuur_bord", "groep": "vuur", "naam": "Vuur op het bord", "status": "spel", "speel": "vuur",
		"wanneer": "iets blijft branden (het wrak van een kanon): vlammen, flakkerend licht, rook, vonkjes",
		"knoppen": ["vuur_maat", "vuur_duur", "smoke_wind"], "onderdelen": ["vlam_bord", "propje"]},
	# --- Stijl: looks voor alle 3D-objecten (stap 6, scripts/vfx/stijl.gd) -------
	# Een look staat altijd aan zodra zijn knop boven 0 staat; Speel schiet een
	# musket af zodat je hem in actie ziet. Alles standaard uit.
	# `demo`: de stand waarin de VFX-studio een look opneemt zolang hij in het
	# spel nog uit staat (alleen voor die opname, niet bewaard).
	{"id": "inktranden", "groep": "stijl", "naam": "Inktranden (gravure)", "status": "spel", "speel": "stijl",
		"wanneer": "een donkere lijn om elk model, elke prop en waar het bord van kleur verspringt, zoals de gravures",
		"knoppen": ["stijl_inkt", "stijl_inkt_dikte"], "demo": {"stijl_inkt": 1.0}},
	{"id": "randlicht", "groep": "stijl", "naam": "Randlicht", "status": "spel", "speel": "stijl",
		"wanneer": "de binnenkant van elk silhouet licht warm op, de modellen komen los van het bord",
		"knoppen": ["stijl_rand"], "demo": {"stijl_rand": 1.0}},
	{"id": "miniatuur", "groep": "stijl", "naam": "Miniatuur (tilt-shift)", "status": "spel", "speel": "stijl",
		"wanneer": "boven en onder in beeld vaag, alsof je een echt tafelspel fotografeert",
		"knoppen": ["stijl_miniatuur", "stijl_focus_y", "stijl_focus_band"], "demo": {"stijl_miniatuur": 1.0}},
	{"id": "kleurstemming", "groep": "stijl", "naam": "Kleurstemming en korrel", "status": "spel", "speel": "stijl",
		"wanneer": "het hele beeld warmer of koeler, met filmkorrel", "knoppen": ["stijl_warmte", "stijl_korrel"],
		"demo": {"stijl_warmte": 0.6, "stijl_korrel": 0.5}},
	{"id": "kleurtrappen", "groep": "stijl", "naam": "Kleurtrappen (cel)", "status": "spel", "speel": "stijl",
		"wanneer": "de lichtheid in een paar treden, een getekende stripstijl", "knoppen": ["stijl_trappen"],
		"demo": {"stijl_trappen": 0.8}},
	{"id": "licht_neutraal", "groep": "stijl", "naam": "Licht zoals in de Model-tuner", "status": "wens", "speel": "",
		"wanneer": "Max: in moddif zien de modellen er mooier uit (wat is moddif? gelezen als de Model-tuner: neutraler, helderder licht)",
		"knoppen": []},
]


static func effect(id: String) -> Dictionary:
	for e in EFFECTEN:
		if String(e.id) == id:
			return e
	return {}


static func van_groep(groep: String) -> Array:
	var uit: Array = []
	for e in EFFECTEN:
		if String(e.groep) == groep:
			uit.append(e)
	return uit


## De metadata van een knop (ook die van de stijl, uit scripts/vfx/stijl.gd);
## een onbekende sleutel krijgt een ruim bereik zodat de tuner hem toch kan tonen.
static func knop(sleutel: String) -> Dictionary:
	if KNOPPEN.has(sleutel):
		return KNOPPEN[sleutel]
	if STIJL.KNOPPEN.has(sleutel):
		return STIJL.KNOPPEN[sleutel]
	return {"label": sleutel, "min": 0.0, "max": 10.0, "step": 0.01, "def": 1.0}


## Het onderdeel (textuur of decal) met deze id, of leeg.
static func onderdeel(id: String) -> Dictionary:
	return ONDERDELEN.get(id, {})


## Kent de catalogus deze knop (met label, bereik en standaard)?
static func bekend(sleutel: String) -> bool:
	return KNOPPEN.has(sleutel) or STIJL.KNOPPEN.has(sleutel)


## Alles als platte data (voor de concept-webpagina): groepen, effecten met hun
## knoppen en de huidige waarden uit effects_tuning.json.
static func als_data() -> Dictionary:
	var effecten: Array = []
	for e in EFFECTEN:
		var knoppen: Array = []
		for k in e.knoppen:
			var m: Dictionary = knop(String(k))
			knoppen.append({"sleutel": k, "label": m.label, "waarde": PawnView.fx(String(k), float(m.def)),
				"min": m.min, "max": m.max, "def": m.def})
		var d: Dictionary = e.duplicate()
		d["knoppen"] = knoppen
		effecten.append(d)
	return {"groepen": GROEPEN, "effecten": effecten, "onderdelen": ONDERDELEN}

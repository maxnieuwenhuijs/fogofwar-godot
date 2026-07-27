class_name Personalities
extends RefCounted

# F3.2 — de 15 bot-persoonlijkheden (bouwplan §6): archetype = gewichten +
# temperatuur + bark-profiel. Spreiding per lobby is deterministisch (seed).

const ARCHETYPES := {
	"trouwe_generaal": {
		"w_zwakste_vijand": 1.0, "w_tank": 0.0, "w_zelf": 0.2, "w_sterkste_eigen": 1.0,
		"vrijgevigheid": 0.6, "concentratie": 1.0, "loyaliteit": 1.0, "risico_afslag": 0.5,
		"temperatuur": 0.1,
		"barks": {
			"nominatie_teamgenoot": ["BARK_LOYAL_NOM_TEAM_1", "BARK_LOYAL_NOM_TEAM_2"],
			"zelf_nominatie": ["BARK_LOYAL_NOM_SELF_1"],
			"donatie": ["BARK_LOYAL_DONATE_1"],
			"testament": ["BARK_LOYAL_WILL_1"],
			"testament_naar_vijand": ["BARK_LOYAL_WILL_ENEMY_1"],
		},
	},
	"rat": {
		"w_zwakste_vijand": 0.6, "w_tank": 0.4, "w_zelf": 0.0, "w_sterkste_eigen": 0.3,
		"vrijgevigheid": 0.05, "concentratie": 1.0, "loyaliteit": 0.1, "risico_afslag": 1.0,
		"temperatuur": 0.4,
		"barks": {
			"nominatie_teamgenoot": ["BARK_RAT_NOM_TEAM_1", "BARK_RAT_NOM_TEAM_2"],
			"zelf_nominatie": ["BARK_RAT_NOM_SELF_1"],
			"donatie": ["BARK_RAT_DONATE_1"],
			"testament": ["BARK_RAT_WILL_1"],
			"testament_naar_vijand": ["BARK_RAT_WILL_ENEMY_1"],
		},
	},
	"gierigaard": {
		"w_zwakste_vijand": 1.0, "w_tank": 0.0, "w_zelf": 0.0, "w_sterkste_eigen": 0.8,
		"vrijgevigheid": 0.0, "concentratie": 1.0, "loyaliteit": 0.8, "risico_afslag": 0.9,
		"temperatuur": 0.15,
		"barks": {
			"nominatie_teamgenoot": ["BARK_MISER_NOM_TEAM_1"],
			"zelf_nominatie": ["BARK_MISER_NOM_SELF_1"],
			"donatie": ["BARK_MISER_DONATE_1"],
			"testament": ["BARK_MISER_WILL_1"],
			"testament_naar_vijand": ["BARK_MISER_WILL_ENEMY_1"],
		},
	},
	"berserker": {
		"w_zwakste_vijand": 0.2, "w_tank": 1.0, "w_zelf": 1.5, "w_sterkste_eigen": 0.2,
		"vrijgevigheid": 0.3, "concentratie": 0.5, "loyaliteit": 0.7, "risico_afslag": 0.0,
		"temperatuur": 0.5,
		"barks": {
			"nominatie_teamgenoot": ["BARK_BERSERKER_NOM_TEAM_1"],
			"zelf_nominatie": ["BARK_BERSERKER_NOM_SELF_1"],
			"donatie": ["BARK_BERSERKER_DONATE_1"],
			"testament": ["BARK_BERSERKER_WILL_1"],
			"testament_naar_vijand": ["BARK_BERSERKER_WILL_ENEMY_1"],
		},
	},
	"strateeg": {
		"w_zwakste_vijand": 0.8, "w_tank": 0.5, "w_zelf": 0.1, "w_sterkste_eigen": 1.2,
		"vrijgevigheid": 0.4, "concentratie": 1.0, "loyaliteit": 0.9, "risico_afslag": 0.6,
		"temperatuur": 0.05,
		"barks": {
			"nominatie_teamgenoot": ["BARK_STRATEGIST_NOM_TEAM_1"],
			"zelf_nominatie": ["BARK_STRATEGIST_NOM_SELF_1"],
			"donatie": ["BARK_STRATEGIST_DONATE_1"],
			"testament": ["BARK_STRATEGIST_WILL_1"],
			"testament_naar_vijand": ["BARK_STRATEGIST_WILL_ENEMY_1"],
		},
	},
	"opportunist": {
		"w_zwakste_vijand": 1.2, "w_tank": 0.1, "w_zelf": 0.4, "w_sterkste_eigen": 0.6,
		"vrijgevigheid": 0.2, "concentratie": 1.0, "loyaliteit": 0.4, "risico_afslag": 0.7,
		"temperatuur": 0.3,
		"barks": {
			"nominatie_teamgenoot": ["BARK_OPPORTUNIST_NOM_TEAM_1"],
			"zelf_nominatie": ["BARK_OPPORTUNIST_NOM_SELF_1"],
			"donatie": ["BARK_OPPORTUNIST_DONATE_1"],
			"testament": ["BARK_OPPORTUNIST_WILL_1"],
			"testament_naar_vijand": ["BARK_OPPORTUNIST_WILL_ENEMY_1"],
		},
	},
	"twijfelaar": {
		"w_zwakste_vijand": 0.7, "w_tank": 0.3, "w_zelf": 0.05, "w_sterkste_eigen": 0.7,
		"vrijgevigheid": 0.35, "concentratie": 0.5, "loyaliteit": 0.8, "risico_afslag": 0.95,
		"temperatuur": 0.6,
		"barks": {
			"nominatie_teamgenoot": ["BARK_DOUBTER_NOM_TEAM_1"],
			"zelf_nominatie": ["BARK_DOUBTER_NOM_SELF_1"],
			"donatie": ["BARK_DOUBTER_DONATE_1"],
			"testament": ["BARK_DOUBTER_WILL_1"],
			"testament_naar_vijand": ["BARK_DOUBTER_WILL_ENEMY_1"],
		},
	},
	"kamikaze": {
		"w_zwakste_vijand": 0.0, "w_tank": 1.5, "w_zelf": 1.0, "w_sterkste_eigen": 0.1,
		"vrijgevigheid": 0.8, "concentratie": 1.0, "loyaliteit": 0.9, "risico_afslag": 0.0,
		"temperatuur": 0.7,
		"barks": {
			"nominatie_teamgenoot": ["BARK_KAMIKAZE_NOM_TEAM_1"],
			"zelf_nominatie": ["BARK_KAMIKAZE_NOM_SELF_1"],
			"donatie": ["BARK_KAMIKAZE_DONATE_1"],
			"testament": ["BARK_KAMIKAZE_WILL_1"],
			"testament_naar_vijand": ["BARK_KAMIKAZE_WILL_ENEMY_1"],
		},
	},
}

const NAMEN := ["Bruno", "Vera", "Karel", "Iris", "Ludo", "Nora", "Piet", "Sasha",
	"Timo", "Ada", "Rocco", "Mila", "Dirk", "Fenna", "Olaf"]


## Deterministische lobby van `n` persoonlijkheden (rondlopend over de
## archetypes, geschud met de seed zodat elke campagne anders voelt).
static func maak_lobby(n: int, rng: SeededRng) -> Array:
	var soorten: Array = ARCHETYPES.keys()
	soorten.sort()
	var uit: Array = []
	for i in n:
		var archetype: String = soorten[i % soorten.size()]
		uit.append({
			"naam": NAMEN[i % NAMEN.size()],
			"archetype": archetype,
			"profiel": (ARCHETYPES[archetype] as Dictionary).duplicate(true),
		})
	rng.shuffle(uit)
	return uit

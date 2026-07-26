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
			"nominatie_teamgenoot": ["Voor het team, %s. Maak ons trots.", "Jij bent onze speer, %s."],
			"zelf_nominatie": ["Ik ga zelf. Plicht is plicht."],
			"donatie": ["Neem mijn troepen, %s. Win voor ons."],
			"testament": ["Mijn nalatenschap dient het team. Vaarwel."],
			"testament_naar_vijand": ["Dit... had ik nooit gedacht te doen."],
		},
	},
	"rat": {
		"w_zwakste_vijand": 0.6, "w_tank": 0.4, "w_zelf": 0.0, "w_sterkste_eigen": 0.3,
		"vrijgevigheid": 0.05, "concentratie": 1.0, "loyaliteit": 0.1, "risico_afslag": 1.0,
		"temperatuur": 0.4,
		"barks": {
			"nominatie_teamgenoot": ["Iemand moet het doen. Niet ik.", "%s lijkt me... geschikt."],
			"zelf_nominatie": ["Als het moet, dan moet het. Helaas."],
			"donatie": ["Een kleinigheid. Onthoud dit, %s."],
			"testament": ["Als ik val, val jij ooit ook."],
			"testament_naar_vijand": ["De vijand betaalt beter dan mijn 'vrienden'."],
		},
	},
	"gierigaard": {
		"w_zwakste_vijand": 1.0, "w_tank": 0.0, "w_zelf": 0.0, "w_sterkste_eigen": 0.8,
		"vrijgevigheid": 0.0, "concentratie": 1.0, "loyaliteit": 0.8, "risico_afslag": 0.9,
		"temperatuur": 0.15,
		"barks": {
			"nominatie_teamgenoot": ["%s vecht. Ik bewaak de voorraad."],
			"zelf_nominatie": ["Vooruit dan. Maar dit kost jullie wat."],
			"donatie": ["Eén pion. Meer krijg je niet."],
			"testament": ["Mijn schatten... verdeel ze wijs. Of niet."],
			"testament_naar_vijand": ["Beter bij hen dan verbrand."],
		},
	},
	"berserker": {
		"w_zwakste_vijand": 0.2, "w_tank": 1.0, "w_zelf": 1.5, "w_sterkste_eigen": 0.2,
		"vrijgevigheid": 0.3, "concentratie": 0.5, "loyaliteit": 0.7, "risico_afslag": 0.0,
		"temperatuur": 0.5,
		"barks": {
			"nominatie_teamgenoot": ["Laat MIJ gaan! ... Prima, %s dan."],
			"zelf_nominatie": ["EINDELIJK. Stuur de grootste die ze hebben!"],
			"donatie": ["Hier. Sla harder."],
			"testament": ["Ik sterf staand. Neem mijn bijl."],
			"testament_naar_vijand": ["Respect voor een waardige vijand."],
		},
	},
	"strateeg": {
		"w_zwakste_vijand": 0.8, "w_tank": 0.5, "w_zelf": 0.1, "w_sterkste_eigen": 1.2,
		"vrijgevigheid": 0.4, "concentratie": 1.0, "loyaliteit": 0.9, "risico_afslag": 0.6,
		"temperatuur": 0.05,
		"barks": {
			"nominatie_teamgenoot": ["De cijfers wijzen %s aan. Simpel."],
			"zelf_nominatie": ["Statistisch gezien... ben ik de beste optie."],
			"donatie": ["Precies afgewogen. Gebruik het goed."],
			"testament": ["Volgens plan, zelfs nu."],
			"testament_naar_vijand": ["Een investering in de eindstand."],
		},
	},
	"opportunist": {
		"w_zwakste_vijand": 1.2, "w_tank": 0.1, "w_zelf": 0.4, "w_sterkste_eigen": 0.6,
		"vrijgevigheid": 0.2, "concentratie": 1.0, "loyaliteit": 0.4, "risico_afslag": 0.7,
		"temperatuur": 0.3,
		"barks": {
			"nominatie_teamgenoot": ["Pak de zwakste. Altijd de zwakste."],
			"zelf_nominatie": ["Tegen díe? Ja, dat win ik wel."],
			"donatie": ["Zie het als een lening, %s."],
			"testament": ["Wie mij terugbetaalt in het hiernamaals..."],
			"testament_naar_vijand": ["Niets persoonlijks. Puur zakelijk."],
		},
	},
	"twijfelaar": {
		"w_zwakste_vijand": 0.7, "w_tank": 0.3, "w_zelf": 0.05, "w_sterkste_eigen": 0.7,
		"vrijgevigheid": 0.35, "concentratie": 0.5, "loyaliteit": 0.8, "risico_afslag": 0.95,
		"temperatuur": 0.6,
		"barks": {
			"nominatie_teamgenoot": ["Misschien %s? Of toch... nee, %s."],
			"zelf_nominatie": ["Oké. Oké oké oké. Ik doe het."],
			"donatie": ["Is dit genoeg? Het is vast niet genoeg."],
			"testament": ["Heb ik het goed verdeeld? Te laat nu."],
			"testament_naar_vijand": ["Was dit wel verstandig?"],
		},
	},
	"kamikaze": {
		"w_zwakste_vijand": 0.0, "w_tank": 1.5, "w_zelf": 1.0, "w_sterkste_eigen": 0.1,
		"vrijgevigheid": 0.8, "concentratie": 1.0, "loyaliteit": 0.9, "risico_afslag": 0.0,
		"temperatuur": 0.7,
		"barks": {
			"nominatie_teamgenoot": ["Stuur %s de vuurzee in!"],
			"zelf_nominatie": ["Voor de eeuwige roem!"],
			"donatie": ["Alles! Neem alles!"],
			"testament": ["As tot as. Mijn troepen aan de dappersten."],
			"testament_naar_vijand": ["Zelfs mijn vijand vocht mooier dan mijn team."],
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

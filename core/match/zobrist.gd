class_name Zobrist
extends RefCounted

# F0.7 — state-hash voor replay-checksums en (later) herhalingsdetectie.
# Implementatiekeuze uit het masterplan: start met een hash over de canonieke
# serialisatie (goedkoop, correct); een incrementele XOR-zobrist is een
# F1-optimalisatie als herhalingsdetectie in de hot loop nodig blijkt.


static func state_hash(state: GameState) -> String:
	return JSON.stringify(Serializer.state_to_dict(state)).sha256_text()


## Hash van een al geserialiseerde staat (voor vergelijking zonder object).
static func dict_hash(state_dict: Dictionary) -> String:
	return JSON.stringify(state_dict).sha256_text()

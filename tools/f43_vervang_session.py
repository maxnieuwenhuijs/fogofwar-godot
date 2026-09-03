# F4.3b (3 september 2026) — eenmalig hulpscript: game.gd praat voortaan via
# `session` (SessionInterface) in plaats van rechtstreeks tegen de autoload
# GameSession. Mechanisch: elke `GameSession.` wordt `session.`, plus de
# declaratie, de toewijzing in _ready en een idempotente signal-koppeling.
# Via python omdat game.gd `\`-regelvoortzettingen bevat (bekende
# heredoc-valkuil). Bewaard als documentatie van wat er precies gebeurd is.
import re
import sys

PAD = "scripts/game/game.gd"
t = open(PAD, encoding="utf-8").read()
oorspronkelijk = t

# 1. Declaratie na _ai_id.
oud = "var _human_id: int = Constants.PLAYER_1\nvar _ai_id: int = Constants.PLAYER_2\n"
nieuw = oud + (
    "\n## F4.3b -- de sessie waar game.gd tegen praat. Offline de autoload\n"
    "## GameSession (die IS de LocalSession), online straks een RemoteSession met\n"
    "## dezelfde signals en submits. De enige regel die GameSession nog bij naam\n"
    "## noemt is de toewijzing in _ready.\n"
    "var session: SessionInterface = null\n"
    "var _verbonden_sessie: Object = null\n"
)
assert t.count(oud) == 1, "declaratie-anker niet uniek"
t = t.replace(oud, nieuw)

# 2. Toewijzing als eerste regel van _ready.
oud = "func _ready() -> void:\n\t_board = BOARD_SCENE.instantiate()\n"
nieuw = "func _ready() -> void:\n\tsession = GameSession\n\t_board = BOARD_SCENE.instantiate()\n"
assert t.count(oud) == 1, "_ready-anker niet uniek"
t = t.replace(oud, nieuw)

# 3. Alle overige GameSession. -> session.
n_voor = t.count("GameSession.")
t = t.replace("GameSession.", "session.")
assert t.count("GameSession.") == 0

# 4. Idempotente signal-koppeling + twee nieuwe handlers.
oud = (
    "func _connect_session_signals() -> void:\n"
    "\tsession.phase_changed.connect(_on_phase_changed)\n"
    "\tsession.cards_revealed_event.connect(_on_cards_revealed)\n"
    "\tsession.wolf_step_pending.connect(_on_wolf_step_pending)\n"
    "\tsession.turn_changed.connect(_on_turn_changed)\n"
    "\tsession.action_performed.connect(_on_action_performed)\n"
    "\tsession.cycle_started.connect(_on_cycle_started)\n"
    "\tsession.game_over.connect(_on_game_over)\n"
)
nieuw = (
    "## F4.3b -- idempotent per sessie-object: wisselt de sessie (online), dan\n"
    "## gaan de oude koppelingen los en komen dezelfde op de nieuwe. Volgorde is\n"
    "## die van altijd; de twee laatste zijn de online-haken (lichaam in F4.3c/g).\n"
    "func _sessie_verbindingen() -> Array:\n"
    "\treturn [\n"
    "\t\t[\"phase_changed\", _on_phase_changed],\n"
    "\t\t[\"cards_revealed_event\", _on_cards_revealed],\n"
    "\t\t[\"wolf_step_pending\", _on_wolf_step_pending],\n"
    "\t\t[\"turn_changed\", _on_turn_changed],\n"
    "\t\t[\"action_performed\", _on_action_performed],\n"
    "\t\t[\"cycle_started\", _on_cycle_started],\n"
    "\t\t[\"game_over\", _on_game_over],\n"
    "\t\t[\"doctrines_revealed\", _on_doctrines_revealed],\n"
    "\t\t[\"state_updated\", _on_state_updated],\n"
    "\t]\n"
    "\n"
    "\n"
    "func _connect_session_signals() -> void:\n"
    "\tif session == _verbonden_sessie:\n"
    "\t\treturn\n"
    "\tif _verbonden_sessie != null:\n"
    "\t\tfor paar in _sessie_verbindingen():\n"
    "\t\t\tif _verbonden_sessie.is_connected(paar[0], paar[1]):\n"
    "\t\t\t\t_verbonden_sessie.disconnect(paar[0], paar[1])\n"
    "\tfor paar in _sessie_verbindingen():\n"
    "\t\tsession.connect(paar[0], paar[1])\n"
    "\t_verbonden_sessie = session\n"
    "\n"
    "\n"
    "## F4.3b -- haken voor de online-sessie; offline gebeurt hier (nog) niets.\n"
    "func _on_doctrines_revealed(_doctrines: Dictionary) -> void:\n"
    "\tpass\n"
    "\n"
    "\n"
    "func _on_state_updated(_state: GameState) -> void:\n"
    "\tpass\n"
)
assert t.count(oud) == 1, "connect-anker niet uniek"
t = t.replace(oud, nieuw)

open(PAD, "w", encoding="utf-8", newline="").write(t)
print("GameSession. vervangen: %d; regels %d -> %d" % (
    n_voor, oorspronkelijk.count("\n"), t.count("\n")))

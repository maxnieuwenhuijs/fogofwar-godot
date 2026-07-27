# Fog of War — UI Specification (for designers)

Companion documents: **UI-DESIGN-BRIEF** (visual direction, deliverables, phases — ask Max for the
translated summary of any section) and **ui-wireframes.html** (low-fi wireframes of every screen in
this spec). This document describes the *interface flow*: every screen, what it shows, and what the
player can do there. It reflects a working build — most screens already exist functionally
(programmer-UI) and screenshots can be provided on request.

---

## 0. The game in three sentences

A 2-player turn-based strategy board game (Godot, mobile-first portrait 1080×1920) with animal
soldiers in a Napoleonic setting. Players secretly define stat cards each round, assign them to
pawns, and fight on an 11×11 board; first to get 2 pawns into the enemy harbor (or wipe the enemy
out) wins. Around the duels sits a **campaign**: two teams of 8 players, a council that nominates
fighters, donations, testaments of fallen players, and a final civil war between the surviving
teammates.

**The MULTIPLAYER campaign is the main focus of this product and of the design.** Two teams of 8
*human* players play a social campaign (live evening sessions or async over days) — think "Among Us
energy": a shared timeline, voting, backstabbing testaments, team chat. The solo campaign (vs 15
bots) uses the *same screens*; design every campaign screen multiplayer-first, with solo as the
degenerate case (bots fill the seats, no chat pressure). Concretely that means: every waiting
moment shows *who* we are waiting for, every action of another player lands as a feed card, and
deadlines/timers are always visible (they are server-driven).

**Visual direction (summary):** hand-crafted early-19th-century military — aged parchment, ink,
wax seals, brass; engraving-style; muted earthy palette; red vs blue team accents; icons over text;
**no fantasy glow, no glossy TCG look**.

## 1. Screen map & flow

```
Main menu
 ├─ Multiplayer campaign ──► LOBBY (join code / public queue / friends)
 │                            └─► Faction pick ──► CAMPAIGN HUB ◄──────┐
 ├─ Solo campaign ──► Faction pick ──► CAMPAIGN HUB (same screens) ◄───┤
 │                          ├─ Ledger (roster)                         │
 │                          ├─ Council (vote panel)                    │ duels resolve /
 │                          ├─ Donate sheet                            │ reports land
 │                          ├─ Testament (if you fall)                 │
 │                          ├─ Team chat + quick-chat (multiplayer)    │
 │                          ├─ Civil-war bracket                       │
 │                          └─ "YOUR DUEL" ──► MATCH (board) ──► Match report ─┘
 ├─ Single duel vs AI / ranked 1v1 ──► Faction ► MATCH (board) ► End screen
 └─ How to play (5-tab rules screen, reachable everywhere via "?")

Push notifications (multiplayer) deep-link into: your duel ► Match setup ·
council open ► Council panel · new report ► the feed card · testament ► Testament panel.
```

Match flow (inside a duel): `Placement → [per cycle: Spawn → 3× (Define cards → Reveal →
Link) → Action phase] → End`.

## 2. Screens

### 2.1 Main menu
- **Shows:** game title/emblem, buttons: **Multiplayer campaign** (primary) / Solo campaign /
  Single duel / How to play / Settings.
- **Actions:** navigate. — *Design: a "field table" feel; this is the storefront of the style.*

### 2.2 Faction pick (campaign start; also used for single duels)
- **Shows:** 6 faction cards — emblem, name (Pig/Mouse/Lion/Bear/Wolf/Crocodile), army composition
  (infantry/cavalry/artillery counts), cards-per-round × stat budget, one "pro" and one "con" line.
- **Actions:** tap a faction → confirmed permanently for the whole campaign.
- **States:** none (choice is final; a confirm affordance is welcome).

### 2.3 Campaign hub (the campaign's home screen)
- **Shows, top to bottom:**
  1. Header: round number + phase name (Council / Donations / Duels / Testament / CIVIL WAR).
  2. Your balances: soldiers · cavalry · cannons (reinforcements) · CP (command points) · points.
  3. Two team columns (your team blue, enemy red): per player a portrait chip + name + balances;
     dead players greyed; currently-fighting players highlighted.
  4. **Timeline feed** (the heart of the screen): cards for everything that happens — battle
     reports, donations, votes, nominations, testaments, bot chatter ("barks"), phase banners.
     Tapping a battle report opens the full Match report.
  5. Phase panel (bottom): context panel that swaps per phase — see 2.4–2.7. While bots play, it
     shows live progress ("Bots are fighting duel 3 of 8: Nora vs Bruno…").
- **Actions:** open Ledger; tap feed cards; act in the phase panel; start YOUR duel.
- **7 feed-card types to design:** battle report, nomination, vote result, donation, testament,
  bark/quick-chat, phase banner.

### 2.4 Council panel (phase panel variant)
- **Shows:** the ballot ("Your team nominates: pick the fighters"), two pickers (own fighter ×
  enemy fighter), live vote status of teammates.
- **Actions:** pick pair → vote. Closes early on unanimity. Round 1 is drawn by lot (no council).

### 2.5 Donate panel (phase panel variant)
- **Shows:** teammate picker, steppers for soldiers/cavalry/cannons/CP, cap hints (max 10 pawns /
  3 CP per recipient per round).
- **Actions:** donate (repeatable) · "Done donating".

### 2.6 Testament panel (phase panel variant — the drama moment)
- **Shows:** "You have fallen." Recipient picker (any living player, including enemies!), what
  half of your estate amounts to, a prominent timer.
- **Actions:** bequeath half to one player · burn everything. (Timeout = everything burns.)

### 2.7 Your-duel panel (phase panel variant)
- **Shows:** "YOUR DUEL: you vs <name>. Your whole estate goes to the board — losses are gone,
  savings carry over."
- **Actions:** "Play the duel" → switches to the Match screen.

### 2.8 Ledger (roster screen)
- **Shows:** sortable table of all 16 players: portrait, faction emblem, soldiers/cavalry/cannons,
  CP, points, alive/dead. Your row highlighted. Regiment-book styling.
- **Actions:** sort by column; back.

### 2.9 Civil-war bracket
- **Shows:** tournament bracket of the surviving team: seeds, pairs, byes, results.
- **Actions:** view only (duels start via the phase panel).

### 2.10 Match report
- **Shows:** winner + win-method icon (harbor 🏰 / elimination 💀 / tiebreak / resign), cycles
  fought, losses per unit type per player, CP changes, reinforcements committed.
- **Actions:** close; (later: watch replay).

### 2.11 MATCH — the board (the biggest screen, many sub-states)
- **Layout:** 3D board fills the screen; 2D HUD overlays.
- **HUD top bar:** phase name + cycle/round counters, whose turn (color), countdown timer.
- **Board sub-states:**
  - **Placement:** drag/tap unit types onto your two home rows; ghost preview; undo; "default
    setup" button.
  - **Spawn (campaign only):** reserve counts per type; place up to 3 reinforcements on your back
    row; blind & simultaneous ("opponent is choosing too…").
  - **Define cards:** card fan at the bottom (see 2.12), CP-bet stepper, confirm.
  - **Reveal:** both card sets side by side, initiative bid percentage, "X starts".
  - **Link:** tap a card → eligible pawns highlight → tap a pawn. Alternating turns.
  - **Action phase:** tap own pawn → target markers: green = move (with step cost), red =
    melee/charge, orange = shoot (line of fire), cyan = free wolf-step. Cannon shows an
    "action pot" badge. Context button for touch actions (skip/undo).
  - **Premove (chess-style):** during the opponent's turn you can already queue your next action —
    it shows as a pinned "ghost" order on the board (pawn + target marker + small pin/seal icon)
    and executes the instant your turn starts, *unless* it became invalid (target died, path
    blocked) — then the pin dissolves with subtle feedback ("order lapsed"). One premove at a
    time; tap again to cancel/replace. Needs a distinct visual state: queued ≠ executed.
  - **Stat chips** float above active pawns: HP (green) / stamina (blue) / attack (orange);
    hidden enemy stats show a **"?" seal** — never zeros (information leak).
  - **End states:** win (harbor / elimination) / loss / draw-by-cycle-limit / resign / forfeit.
- **Actions:** everything above + resign (in pause/help menu) + "?" help button.

### 2.12 The cards
Fully specified in CARD-DESIGN-BRIEF (separate document): field-order style stat cards, 5 states
(editable / revealed / selectable / linked / card back), red & blue variants, CP-bet stamp.

### 2.13 How to play
5 tabs (The game / Turns / Units / Fighting / Factions) — restyle of an existing text screen;
illustrated examples preferred over text walls.

### 2.14 Settings
Sound, screen-shake toggle, notifications, language (NL/EN planned). Small screen, low priority.

## 2b. Multiplayer-campaign screens (MAIN FOCUS)

These make the campaign a *social* game. Solo reuses everything; these elements simply stay empty
or bot-driven there.

### 2b.1 Lobby
- **Shows:** three entry paths — big join-code input (5 characters), "Quick play" (public queue,
  aims for a live 8-player evening), "With friends" (create private lobby + shareable code). While
  filling: seat list (8 portrait slots per team) with joined players; empty seats fill with bots
  after a wait, **always visibly labeled 🤖** (trust rule: humans must instantly see who's a bot).
- **Actions:** join/create/leave; ready-up; host starts.
- **States:** filling / ready / starting.

### 2b.2 Team chat screen + quick-chat
- **Placement:** the bottom zone of the hub is a **two-tab area: [ PHASE ] [ CHAT ]** — the chat
  is a full screen state at the phase panel's position, not just an overlay. The chat tab shows an
  **unread badge**; while an action is required of you, the Phase tab pulses/marks so chat never
  hides your duty.
- **Chat screen shows:** team-only thread (portrait + message rows; bot barks share the same
  visual language), the sealed/ghost state for dead players, and the **quick-chat bar** pinned at
  the bottom: ~12 fixed phrases as icon+short-text chips ("Send me ⚔", "Donate to X", "Trust me",
  "Traitor!") — the default communication, translatable, moderation-safe. Free text is a lobby
  setting (input field only when enabled).
- **Actions:** switch tabs; send quick-chat (1 tap); free text if enabled; tap a message's
  portrait → player detail (ledger row).
- **Design note:** the quick-chat bar also appears in compact form on the Phase tab (1 row), so
  you can react without leaving the ballot/donation panel.

### 2b.3 Waiting & connection states (every blind/simultaneous moment)
- "Waiting for X, Y…" with portrait chips + a deadline bar (server-driven) — on: card define,
  spawn, placement, reveal-ack, council votes, donations.
- Reconnect: "connection lost — reconnecting (grace 0:20)" banner; opponent-disconnected state in
  a duel ("X dropped — forfeit in 0:20").
- Deadline consequence is always pre-announced ("no choice = default loadout").

### 2b.4 Ghost mode (dead players)
- Dead players keep watching: entire hub in a muted/sepia "ghost" treatment, 💀 badge on own
  portrait, team secrets visibly sealed ("sealed for the dead" — no team chat, no vote details),
  public info stays. Drama is the product: ghosts must *want* to keep watching.

### 2b.5 Push-notification landings
- 3 notification types (your duel ⚔ / council open 🗳 / new report 📜): each needs an icon + a
  one-line template, and the target screen must look correct when opened *cold* from the
  notification (esp. Testament with its timer already running).

## 3. Priorities for the first package

1. Design system: palette, 2 fonts, panel/button styles (9-patch friendly).
2. Icon set (~28 monochrome icons, readable at 24×24) + 6 faction emblems.
3. **Multiplayer campaign hub**: the 7 feed-card types + team columns + quick-chat bar +
   waiting/deadline states (2b.2–2b.3) — this is the product's living room.
4. Card frame + 5 states (CARD-DESIGN-BRIEF).
5. Match HUD (top bar, stat chips, target markers, "?" seal).
6. Lobby + ghost mode + notification templates.

Then: remaining campaign panels → menus/help → leaderboards/profile (later phase).

## 4. Practical

- Target: portrait 1080×1920, must stay readable on 6" phones; thumb-reachable actions.
- Deliverables: PNG with alpha or SVG; 9-patch-friendly frames; no hover-dependent interactions.
- Never leak information through design: hidden = "?" seal, never empty/zero values.
- All states must differ by shape/icon as well as color (color-blindness).

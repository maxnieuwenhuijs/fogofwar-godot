# Fog of War — Campagne-spec (F3.0)

> **Status: DEFINITIEF** — vastgeklikt in de F3.0-ontwerpsessie met Max
> (25 juli 2026, besluiten C1-C8). Bronnen: masterplan F3-sectie, de
> F2.1-besluiten (D1-D14 + bijstellingen) en Max' speeltest-uitspraken.
>
> **De C-besluiten:** C1 twee teams van 8 · C2 je neemt je volledige bezit
> mee het duel in · C3 uitvallen = duel verloren én voorraad te klein voor
> een nieuwe startopstelling · C4 burgeroorlog zodra een team is
> uitgeschakeld · C5 punten: haven 3 / eliminatie 2 / tiebreak 1 / verlies 0,
> teambonus +2 per lid (ook doden) · C6 flow: raad → doneren → duels ·
> C7 duel-start: doctrine-comp opstellen (gecapt op voorraad), rest =
> spawn-reserve · C8 de 15-spawns-per-potje-cap geldt ook in campagne-duels.

## 1. Opzet

- Een campagne is een reeks **raadsrondes** met 1v1-duels (v4.2-regels, de
  match-engine) tussen leden van twee teams, tot er een **kampioen** is.
- **Bezetting (C1):** solo-campagne = de mens + 15 bots, twee teams van 8
  (het async-16-model; live-varianten zijn F5-werk).
- Elke speler heeft een **campagne-bezit**: pionnen-voorraad (per type),
  CP-saldo en punten. Alles loopt als **ledger-events** (reason:
  start/donate/testament/loss/spawn/win_haven/win_eliminatie/restant/…);
  een saldo is altijd de som van het ledger, nooit een muteerbaar veld.

## 2. De raadsronde

Flow per ronde (C6, aangescherpt door **C9**, Max 26 juli):

1. **Ronde 1 — de loting:** geen raad én geen donatie-venster; het lot
   paart álle 16 spelers in random 1v1's (cross-team) en de duels beginnen
   direct — iedereen start immers met zijn eigen factie-bezit, er valt
   niets te herverdelen. De paren gaan als `loting`-actie het log in
   (systeem-actie, speler -1) zodat de replay deterministisch blijft.
2. **Ronde 2+ — raad:** nominaties + stemmen bepalen de paren; **iedereen
   die een tegenstander kan krijgen vecht** (aantal duels = kleinste
   teamgrootte, cap `duels_per_ronde_max` = 8). Overtal van het grotere
   team heeft een ronde rust.
3. **Donatie-venster**: leden schuiven pionnen/CP naar **elke levende
   teamgenoot** (C9; caps per ontvanger blijven).
4. **Duels** (solo: bot-duels op vol tempo, het mens-duel op het bord;
   **zonder cycluslimiet** — een duel eindigt op haven of eliminatie, de
   simulatie heeft alleen een ruime technische noodstop).
5. **Battlereports + ledger-verwerking**, dan de volgende ronde.

Regels (vastgelegd, masterplan):

- **Nominatie (ronde 2+):** niemand wordt 2× per raadsronde genomineerd;
  aantal duels per ronde = min(duels_per_ronde_max=8, kleinste
  teamgrootte); het kleinste team (tiebreak: minste punten) nomineert
  eerst; een team met 1 overlevende nomineert zichzelf.
- **Compat:** campagne-logs van vóór C9 dragen hun oude regels
  (`duels_per_ronde_max` 2, geen loting) in de begin-snapshot en folden
  ongewijzigd; `CRules.from_dict` valt voor ontbrekende sleutels terug op
  de oude waarden.
- **Stemmen:** default beslist de teammeerderheid; bij staking van stemmen
  wint de stem van de speler met de **kleinste pool** (die draagt het
  grootste risico).
- **Timers (solo):** bots beslissen direct; de raad wacht op de mens met een
  zachte 60s-timer (skipbaar). Online-deadlines: F5.

## 3. Economie per duel (de v4.2-koppeling)

> **C10 — vol-team-model (besluit Max, 27 juli; vervangt de C2/C7-capping
> hieronder voor nieuwe campagnes):** elk duel start je **hoe dan ook met de
> volledige doctrine-samenstelling** op het bord — het startteam is gratis en
> gegarandeerd, ook met een lege pool. De campagne-pool is puur
> **reinforcements** (start: comp × poolfactor, default 0,5) en slinkt
> uitsluitend door **inzet**: elke reinforcement die je tijdens een duel
> spawnt wordt van de campagne-pool afgeboekt (gesneuveld of overleefd —
> ingezet is ingezet). Bord-verliezen van het startteam kosten géén pool.
> De in-match-spawnvoorraad is de eigen pool, gecapt op de duel-inzetruimte
> (15). Uitvallen (C3) blijft: **duel verloren én reinforcements op**.
> Oude campagne-logs (zonder `vol_team_start` in de rules) folden onder het
> oude model hieronder.

- **Duel-inzet (C2/C7, oud model — alleen nog voor oude logs):** een
  genomineerde neemt zijn volledige campagne-bezit mee: startleger gecapt op
  de voorraad (minder dan je comp betekent kleiner beginnen), de rest is de
  spawn-reserve, en zijn hele CP-saldo is `cp_start`.
- **Spawn-cap (C8):** de limiet van 15 spawns per potje geldt ook in
  campagne-duels (max 3 per cyclus, eigen achterste rij — de vaste
  v4.2-regels).
- **Pool-afboeking:** onder C10 boekt de **inzet** af (`reason: "inzet"` in
  het ledger, via het `inzet`-veld op MATCH_RESULT); onder het oude model
  boekten de **verliezen** af (`reason: "loss"`). Spawns in het duel komen
  uit dezelfde voorraad.
- **CP-restant** van het duel vloeit terug naar de campagnepot en is daar
  overdraagbaar (besluit Max, 25 juli). Haven-winst +8 CP, eliminatie-winst
  +4 CP (ledger; D13).
- **Losse-match-setting** (buiten de campagne): 10 CP, poolfactor 1.5,
  max 15 spawns per potje (besluit Max, 25 juli).

## 4. Donaties en testament

- **Donatiecaps:** max 10 pionnen en 3 CP per ontvanger per raadsronde
  (masterplan). Doneren of houden is per lid een vrije keuze (besluit Max).
- **Testament:** wie uit de campagne valt (C3: een duel verloren én de
  voorraad kan geen nieuwe startopstelling meer vullen) laat na: maximaal
  de **helft**
  van zijn bezit, aan maximaal **2 ontvangers**, binnen de timer; timeout of
  forfeit = alles **verbrandt**.
- **Eliminatie telt door** over wedstrijden (besluit Max): een leeggevochten
  tegenstander is een volwaardige overwinning.

## 5. Punten en de burgeroorlog

- **Punten (C5)** meten roem, los van de CP/pion-economie: duelwinst via de
  haven 3, via eliminatie 2, via de tiebreak 1, verlies 0. Teamwinst-bonus
  aan het einde: +2 per lid, **ook voor gesneuvelde teamgenoten** (de doden
  droegen bij).
- **Burgeroorlog (C4):** zodra één team volledig is uitgeschakeld vechten
  de overlevenden van het winnende team onderling om
  het kampioenschap: knock-out-bracket, seeding op punten → CP → pool;
  vrijloting voor de hoogste seed bij oneven aantal; **geen raad, geen
  donaties/ruil** meer.
- De **kampioen** is de winnaar van de burgeroorlog-finale.

## 5b. Buit uit een duel (C15, 30 juli)

Wat je in een duel op figuranten verovert, komt in je campagne-bezit terecht:
een vaandeldrager levert 2 versterkingspunten op, een tamboer 2 CP. Het duel
boekt dat in de duel-staat; de campagnelaag neemt het saldo daarna over via het
gewone eindboeking-pad. Voor de raad is dat een extra reden om te weten wie zijn
vaandel verloor -- en dat staat in het battlereport.

## 6. Informatie en fog (D12-lijn)

- Het **grootboek** (ledger) is publiek: punten, donaties en testamenten zijn
  voor iedereen zichtbaar ("Among Us-gevoel").
- **Vijandelijke voorraad en CP zijn verborgen** — in duels (D12) én op de
  campagnekaart. *(30 juli: dit was in de hub en het grootboek nog niet zo; de
  saldi van andere teams staan er nu als "?" en alleen roem is publiek.)* De informatiebron is het **battlereport**: wat er in een
  duel gespawnd, verloren en verdiend is, is na afloop publiek leesbaar
  (besluit Max: "dat moet je lezen uit de battlereports of van je teammaten
  horen"). Team-chat/stem-details zijn team-only; wie dood is ziet alles.
- Bot-duels leveren een MatchReport-kaartje mét opgeslagen match-log
  (replaybaar).

## 7. Bijlage: testgevallen (F3.1-contract)

| Regel | Testgeval |
|---|---|
| Nominatie-limiet (niet 2× per ronde) | `test_nominatie_niet_dubbel` |
| Duels/ronde = min(2, kleinste team) | `test_duels_per_ronde` |
| Kleinste team nomineert eerst | `test_nominatie_volgorde` |
| 1 overlevende nomineert zichzelf | `test_zelfnominatie` |
| Stem-default teammeerderheid | `test_stem_meerderheid` |
| Staking → kleinste pool beslist | `test_stem_staking` |
| Donatiecap 10 pionnen/ontvanger/ronde | `test_donatiecap_pionnen` |
| Donatiecap 3 CP/ontvanger/ronde | `test_donatiecap_cp` |
| Testament ≤ helft | `test_testament_helft` |
| Testament ≤ 2 ontvangers | `test_testament_ontvangers` |
| Testament-timeout = verbranden | `test_testament_timeout` |
| Forfeit-keten | `test_forfeit` |
| Duel-verliezen → pool-afboeking | `test_pool_afboeking` |
| CP-restant → campagnepot | `test_cp_restant` |
| Haven/eliminatie-CP naar ledger | `test_cp_verdiensten` |
| Punten ook voor doden (teambonus) | `test_punten_doden` |
| Burgeroorlog-seeding punten→CP→pool | `test_seeding` |
| Vrijloting hoogste seed | `test_vrijloting` |
| Geen donaties in de burgeroorlog | `test_burgeroorlog_geen_ruil` |
| Ledger-fold = eindstand | `test_ledger_fold` |
| Ledger-invariant (som + bord constant behalve verbranding) | `test_ledger_invariant` |
| Punten-tarieven 3/2/1/0 + teambonus doden | `test_punten_tarieven` |
| Flow raad → doneren → duels | `test_ronde_flow` |
| Duel-start: comp gecapt op voorraad, rest reserve (oud model) | `test_duel_start_verdeling` |
| Kleiner starten bij armoede (oud model, oude logs) | `test_arm_start` |
| Spawn-cap 15 ook in campagne-duels | `test_campagne_spawn_cap` |
| Uitvals-conditie C3 (verlies + te kleine voorraad) | `test_uitvallen` |
| C10: vol team ook met lege pool + inzet boekt af, verliezen niet | `test_vol_team_start_en_inzet_boeking` |

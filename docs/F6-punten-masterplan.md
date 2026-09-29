# Masterplan: punten verdienen en krijgen (online)

> **Status: plan, 29 september 2026. Nog niets gebouwd, niets besloten.**
> Vraag van Max: "een masterplan voor online punten verdienen, en krijgen,
> sowieso de incentive als het team wint, maar ook als jij wint, zo dat je ook
> die burgeroorlog-tactieken triggert en onderling pesterij."
>
> Hoort bij **F6 (Meta)** in `MASTERBOUWPLAN.md`: dit vult de "campagnepunten"
> in waar F6.2 de seizoenen en leagues op bouwt. Stap P1 t/m P3 kunnen nu al,
> zonder server. De rest wacht op F5 (online campagne).
>
> Alle getallen zijn **tabel v1**: een eerste voorstel. Bots meten ze eerst (P4),
> daarna zet Max ze vast. Besluiten met een default staan in §10.

---

## 1. Het idee

Er komen **punten**: wat je per online campagne verdient, opgeteld per seizoen.
Ze bepalen je league en je plek op de ranglijst. **Roem** blijft wat het is: je
score binnen één campagne, die de burgeroorlog zaait.

Elke campagne heeft twee potten:

- **De teampot.** Wint je team, dan krijgt iedereen van dat team punten. Ook wie
  er al uit ligt.
- **De kroonpot.** Daarna vecht het winnende team onderling om de kroon. Hoe
  verder je komt, hoe meer punten. De kampioen pakt het meest.

In één zin: **het team is je toegangskaartje, de kroon is de hoofdprijs.** Je
hebt je teamgenoten nodig om de oorlog te winnen, en je wilt ze zwak hebben als
de burgeroorlog begint. Daar komt de pesterij vandaan.

**Verdienen doe je zelf:** duels winnen, ver komen in de burgeroorlog.
**Krijgen doe je van anderen:** je team wint, de kampioen bedankt je, je
erfgenaam wordt kampioen.

---

## 2. Tabel v1

| Wat | Punten | Voor wie |
|---|---|---|
| Campagne uitgespeeld | +5 | iedereen die niet vertrok |
| **Team wint** | **+20** | elk lid van het winnende team, ook wie eruit ligt |
| Roem | +1 per roem | iedereen (haven 3, iedereen verslagen 2, teambonus 2) |
| **Kampioen** | **+40** | 1 speler |
| Finale verloren (je viel met 2 over) | +20 | 1 speler |
| Je viel met 3 of 4 over in de burgeroorlog | +10 | |
| Je viel eerder in de burgeroorlog (5 of meer over) | +5 | |
| Stunt: je verslaat een hoger geplaatste teamgenoot | +5 per keer | burgeroorlog |
| Laatste stand: je hoort bij de laatste 2 van het verliezende team | +5 | 2 spelers |
| Dank: de kampioen kiest één gevallen teamgenoot | +10 | 1 speler |
| Koningsmaker: je testament ging naar de latere kampioen | +5 | eigen team |

Ligt er maar één speler van het winnende team nog, dan is die meteen kampioen
(zo werkt het nu al): +40, geen burgeroorlog.

**Voorbeeld.** Zestien spelers, team Noord wint.

| Speler | Wat er gebeurde | Punten |
|---|---|---|
| Vera (Noord) | kampioen, 9 roem, versloeg in de halve finale de nummer 1 | 5 + 20 + 9 + 40 + 5 = **79** |
| Karel (Noord) | verloor de finale, 10 roem | 5 + 20 + 10 + 20 = **55** |
| Bruno (Noord) | lag er in ronde 3 uit, 4 roem, testament aan Vera, kreeg haar dank | 5 + 20 + 4 + 10 + 5 = **44** |
| Ida (Zuid) | verloren team, bij de laatste twee, 6 roem | 5 + 6 + 5 = **16** |
| Otto (Zuid) | vertrok halverwege | **0** |

Gemiddeld komt een speler zo op ongeveer 29 punten per campagne (schatting:
5 uitgespeeld, 10 teampot, 6 à 7 roem, 5 à 6 kroonpot, 2 extra). P4 meet het
echte gemiddelde.

---

## 3. Waarom dit werkt: de spanning schuift vanzelf

**Bij de start** (beide teams even sterk) is je team twee keer zoveel waard als
je kroonkans:

- Teampot: 50% winkans × 20 = **10 punten**.
- Kroonpot: 50% winkans × stel dat je de burgeroorlog haalt (4 van de 8) ×
  gemiddeld 20 per deelnemer = **5 punten**.

Dus in het begin help je je team. Wie te vroeg gaat saboteren, laat zijn team
verliezen en krijgt dan niets: geen teampot, geen kroon. Die rem zit er vanzelf
in, daar is geen regel voor nodig.

**Aan het eind** draait het om. Stel: er is nog één vijand over en je team wint
vrijwel zeker (95%). Een donatie van 5 versterkingen aan Karel maakt dat 96%:
1% × (20 + ongeveer 20) = 0,4 punt voor jou. Maar Karel is je tegenstander in
de halve finale. Met jouw 5 versterkingen wint hij misschien 10% vaker van jou,
en dat kost je al snel 2 à 3 punten. Dus geef je niets. Precies het gedrag dat
we willen.

De regel erachter:

> **Wat een zet waard is** = (extra winkans voor je team) × (20 + wat de
> burgeroorlog jou waard is) + (winkans van je team) × (wat de zet doet voor je
> plek in de burgeroorlog).

Het eerste deel krimpt naarmate de oorlog gewonnen raakt, het tweede groeit. Het
kantelpunt stel je met één knop in: de **kroonfactor** (kampioen gedeeld door
teamwinst; v1: 40 ÷ 20 = 2). Hoger = eerder en harder elkaar in de rug steken.
Lager = trouwer tot het eind. P4 meet 1, 2 en 3.

### Wat spelers gaan doen

- **Sparen voor de burgeroorlog.** Versterkingen zijn je levensverzekering (je
  valt pas als ze op zijn) en straks je wapen tegen je eigen teamgenoten.
- **Rivalen de raad in sturen.** Je stemt de teamgenoot met de meeste roem tegen
  de sterkste vijand. De tijdlijn laat zien wie wie stuurde.
- **Slim doneren.** Aan de zwakke die de vijand bezighoudt, niet aan wie je in
  de halve finale treft.
- **Roem jagen voor de zaaiing.** De hoogste plekken treffen eerst de zwaksten,
  en bij een oneven aantal krijgt de nummer 1 een vrijloting.
- **De laatste vijand als hete aardappel.** Wie hem uitschakelt, pakt roem, maar
  riskeert zijn eigen reserves. Wie stuurt de raad?
- **Pactjes.** "Jij en ik tot de finale." Afdwingen kan niet, en dat is de
  bedoeling.

---

## 4. Pesterij: wat het spel ervoor levert

### Wat er al is en nu betekenis krijgt

- **De raad als wapen**: wie tegen wie vecht, bepaal je samen.
- **Doneren of houden**: wie je nu volstopt, sla je straks in de finale.
- **Het testament**: naar je favoriet (koningsmaker) of expres naar de vijand.
- **Teamchat is precies goed**: de quick chat is team-only, en je teamgenoten
  zijn je rivalen. De pesterij landt vanzelf bij de juiste mensen.

### Wat er klein bij komt (elk een knop, default aan in solo om te testen)

1. **Schaduwbracket met punten** (V4 uit het intrige-voorstel). Vanaf ronde 3
   toont de hub: "Als je team nu wint: jij plek 3, halve finale tegen Vera.
   Kampioen = +40." Zonder dit paneel vergeet je dat je teamgenoten je
   finalisten zijn.
2. **Rivaliteit in de quick chat.** Vier vaste zinnen, alleen voor je team:
   "Die kroon is van mij!", "Wacht maar tot de burgeroorlog.", "Ik onthoud
   dit.", "Bedankt voor het cadeautje!" Bots antwoorden naar karakter (de rat
   kaatst altijd terug).
3. **Stunt** (+5): de underdogs krijgen een reden om te plotten.
4. **Dank van de kampioen** (+10, V16). Vóór je valt kun je het al vragen: "Als
   ik voor je val, bedank je me dan?" Afdwingen kan niet (het spel is notaris,
   P1 in het intrige-voorstel). Juist daarom.
5. **Koningsmaker** (+5): je testament ging naar de latere kampioen. Zo houdt
   wie eruit ligt een belang in de burgeroorlog.
6. **Badges** voor één seizoen, speels: Kroonprins (finale verloren),
   Koningsmaker, Sluipschutter (stunt), Laatste man, Dubbelspel (testament naar
   de vijand). Nooit een schandpaal die blijft staan: dat is de snelste manier
   om spelers kwijt te raken.
7. **De rekening** (V14): bij de start van de burgeroorlog laat het spel zien
   wie wie heeft volgestopt.

### Wat er bewust niet in komt

- **Punten doorgeven** aan een ander. Nooit: dat is boosting.
- **Punten voor verraad**, of straf voor een gebroken belofte. Het spel legt
  vast, het oordeelt niet.
- **Punten voor hulp aan de vijand.** Dank en koningsmaker tellen alleen binnen
  je eigen team.
- **Vrije tekst.** Alleen vaste zinnen (P1 in het intrige-voorstel).

---

## 5. Online: seizoen en ranglijst

- **Rating en punten zijn twee dingen.** De rating (Glicko-2, F6.1) zegt hoe
  goed je bent en stuurt de matchmaking. De punten zeggen wat je dit seizoen
  deed en bepalen je league.
- **Seizoen van 6 weken** (F6.2). Leagues Hout, Brons, Zilver, Goud, Fabel. De
  beste 20% stijgt, de laagste 20% zakt. Zachte reset, een embleem als beloning.
- **Inleg vanaf Goud.** In Goud en Fabel kost elke campagne punten om mee te
  doen, ongeveer het gemiddelde (§2, zo'n 25). Gemiddeld spelen = stilstaan,
  winnen = stijgen, verliezen = zakken. In de lagere leagues verlies je nooit
  punten. Dit vervangt de tier-multiplier uit F6.2 (besluit 7).
- **Ranglijsten** (F6.3): seizoen, per factie, vrienden, en de fun-borden:
  koningsmakers, stunts, laatste stand.
- **Wie eruit ligt** kan alvast een nieuwe campagne starten. De punten van de
  oude komen binnen zodra die klaar is.

---

## 6. Misbruik voorkomen

| Risico | Wat we doen |
|---|---|
| Bots in de lobby (🤖) | Bots verdienen niets. Wordt een bot kampioen, dan vervalt de kroonpot; mensen houden hun eigen plek. |
| Vertrekken | Wie vertrekt, krijgt 0 punten voor die campagne. Drie deadlines op rij gemist = vertrokken. Eruit liggen is geen vertrekken. |
| Vrienden in verschillende teams | Een groep (party) komt altijd in hetzelfde team. Dank en koningsmaker alleen binnen je team. Hetzelfde apparaat of IP in één campagne: punten in de wacht tot iemand kijkt (F6.5). |
| Vrienden sparen elkaar in de burgeroorlog | Elk duel eindigt op haven of eliminatie (V0). Hetzelfde patroon vaker: vlag (F6.5). |
| Privé-lobby's | Tellen niet voor de ladder, wel voor een eigen vriendenbord. |
| Solo tegen bots | Eigen solo-bord (B6), niet op de ladder. |
| Nieuwe accounts (smurfs) | De ladder pas na een account-upgrade en 3 plaatsingscampagnes. |

---

## 7. Techniek: waar het gerekend wordt

**De uitslag in de core (GDScript).** `core/campaign/uitslag.gd` leest de
eindstaat: team, roem, wanneer je viel en hoeveel er toen nog over waren,
stunts, testament, dank. Een pure functie: deterministisch, en hetzelfde bestand
op de client en in de worker (één waarheid).

- Nodig in `CState`: per speler `uitval` = {ronde, fase, over}, bijgehouden door
  de reducer. Oude logs houden hem leeg en folden ongewijzigd.
- Nieuwe actie `DANK`: alleen de kampioen, één keer, na de kroning (de reducer
  weigert nu alles na KLAAR, daar komt deze ene uitzondering bij).

**De puntentabel ook in de core.** `core/campaign/puntentabel.gd` maakt van de
uitslag per speler een lijst regels ([reden, bedrag]), volgens een tabel met een
versienummer (`punten_versie`). Die gebruiken: het eindscherm in solo (preview),
de campagnetrainer (fitness, §8) en de server. Een nieuwe tabel volgend seizoen
herschrijft geen oude campagnes: elke campagne bewaart zijn versie.

**De ladder in Node.** Seizoen, league, inleg en ranglijsten zijn meta en
veranderen per seizoen. Die rekent de server. Tabellen (naast `ratings` en
`campaign_events`, die er al zijn):

- `seizoenen`, `campagnes` (met `punten_versie`), `campagne_spelers` (team,
  plek, roem).
- `punten_boekingen`: append-only, net als het grootboek (saldo = optelsom),
  met `UNIQUE (user, campagne, reden)`. Dubbel uitbetalen kan dan niet.
- `seizoen_standen`: elk uur opnieuw berekend (materialized).

**De stroom:** campagne klaar → de worker vouwt het log → uitslag en punten →
Node boekt alles in één transactie → ranglijst.

---

## 8. Eerst meten met bots

De campagnetrainer (F7.2) kan bots precies deze punten laten najagen. Dat is de
test: als bots op punten ineens niets meer doneren, klopt de tabel niet.

- **Fitness "eigen punten"**: gemengde teams (per team 4 stoelen kandidaat, 4
  kampioen), score = de gemiddelde punten van de kandidaatstoelen. Dit is de
  fase "eigen belang" die `docs/F7-campagnetrainer.md` §4 al noemt.
- **Drie tabellen**: kroonfactor 1 (kampioen 20), 2 (40, v1) en 3 (60).
- **Meten per tabel** (campagne-arena met het orakel): donaties per ronde, hoe
  vaak er een burgeroorlog komt, hoeveel spelers erin zitten, hoe vaak de
  teamgenoot met de meeste roem in een slechte matchup wordt gestuurd,
  testament naar de vijand, teamwinst links en rechts, lengte van de campagne.
- **Doelen**: donaties minstens 60% van wat bots doen die alleen op teamwinst
  trainen; een burgeroorlog in minstens 70% van de campagnes, met meestal 3 of
  meer spelers; campagnes hooguit 20% langer.
- **Budget**: één trainingsnacht per tabel (Max start, B13), dan een besluit.
  Geen eindeloze sweeps.
- **Eerst nodig**: het duel-orakel uit de F7-datarun.

---

## 9. Bouwstappen

| Stap | Wat | Wanneer | CHECK |
|---|---|---|---|
| **P1** | Uitslag en puntentabel in de core, `uitval` in CState, actie `DANK` | nu | Unit-tests per regel uit §2; het voorbeeld geeft precies 79 / 55 / 44 / 16 / 0; oude campagne-logs folden ongewijzigd |
| **P2** | Solo: eindscherm met je punten per regel (iconen), spelregelkaart "Punten", schaduwbracket met punten vanaf ronde 3 | nu | `-- shot campaign_hub einde\|regels` 0 fouten; preview = puntentabel |
| **P3** | Pesterij in solo: rivaliteitszinnen (met bot-antwoorden), stunt, dank kiezen op het eindscherm, koningsmaker, badges | nu | CampaignTests; bots antwoorden deterministisch per seed |
| **P4** | Bots op punten: fitness "eigen punten", drie tabellen meten | na de F7-datarun | Rapport met de metingen uit §8 per tabel; Max kiest |
| **P5** | Tabel v1 vastzetten (`punten_versie` 1) | besluit Max | Max kiest |
| **P6** | Server: tabellen, boekingen vanuit de worker | na F5.1 | Integratietest: campagne klaar → boekingen; dubbel insturen → niet dubbel; vervalst log → afgekeurd |
| **P7** | Ladder: seizoen, leagues, inleg, ranglijsten, fun-borden (F6.2, F6.3) | na P6 | Seizoenswissel-job op een testseizoen; `-- shot leaderboard` |
| **P8** | Misbruik: vertrekregel, party in één team, collusievlag, bots zonder punten (F6.4, F6.5) | met P7 | Simulaties zoals in F6.5 |
| **P9** | **MAX:** speeltest met mensen (live-8): was de burgeroorlog spannend, bleef het leuk? | na F5 | Max speelt |

---

## 10. Besluiten voor Max

Elk besluit heeft een default. Die geldt tot Max iets anders zegt.

1. **Naam:** "punten" op het scherm, LP in de code. *Default: ja.*
2. **Kroonfactor:** 2 (kampioen 40, team 20). *Wordt gemeten in P4.*
3. **Wie eruit ligt, krijgt de teampot.** *Default: ja* (zoals de teambonus in
   roem nu al werkt).
4. **Dank van de kampioen +10, koningsmaker +5.** *Default: ja.*
5. **Stunt +5, laatste stand +5.** *Default: ja.*
6. **Rivaliteitszinnen in de quick chat**, vier stuks, team-only. *Default: ja.*
7. **Inleg vanaf Goud** in plaats van de tier-multiplier uit F6.2. *Default: ja.*
8. **Privé-lobby's en solo tellen niet voor de ladder** (eigen borden).
   *Default: ja.*
9. **Vertrekken = 0 punten**; drie deadlines op rij gemist = vertrokken.
   *Default: ja.*

---

## 11. Hoe dit past bij de andere plannen

- **Intrige-voorstel** (`docs/campagne-intrige-voorstel.md`): V4 (schaduwbracket),
  V14 (de rekening) en V16 (slotscherm en dank) worden hier concreet en krijgen
  punten. P1 ("het spel is notaris") blijft staan: geen punten voor of tegen
  beloftes.
- **MASTERBOUWPLAN F6.1-F6.5**: dit document vult de "campagnepunten" in waar
  F6.2 de leagues op bouwt; rating (F6.1) blijft los.
- **F7.2 campagnetrainer**: fitness "eigen punten" is de fase "eigen belang" uit
  `docs/F7-campagnetrainer.md` §4.
- **Campagne-spec** (`docs/campagne-spec.md`): geen regel verandert. Roem,
  zaaiing en teambonus blijven zoals ze zijn; de punten zitten erbovenop.

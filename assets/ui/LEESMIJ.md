# Mappen onder assets/ui

De UI-assetpack van de ontwerper (`fogofwar-assets/UI_assets_pack`, 3
september 2026) plus zijn "Fog of war UI direction"-pdf. **Het spel zoekt op
BESTANDSNAAM, niet op pad** (`Bestandsindex`), dus je mag hier submappen
bijmaken of dingen verplaatsen. De bestandsnamen zijn precies die van de
ontwerper, typo's incluis (`button_2_bloccked.png`, `Croccodile.png`): de
code herkent beide spellingen, zodat een nieuwe drop van het pack gewoon
werkt. Nieuwe bestanden erin? Een keer `<godot> --headless --path . --import`
draaien (net als bij de i18n-csv), anders kent het spel ze niet.

```
assets/ui/
  buttons/    button_1..7 (+ _pressed, _blocked) en de lakzegel-vinkjes
  cards/      kaartframe, ruggen, linten, zegels, stempels, kransen, panelen (Frame_1..3), Texture_1
  emblems/    de zes gravures (Pig, Mouse, Lion, Bear, Wolf, Croccodile)
              Sinds 16 september zonder wit: helderheid = dekking (wit
              doorzichtig, zwart dicht, arcering half), kleur zwart; het
              origineel staat in emblems/bron/ (.gdignore). Een nieuwe
              levering gaat door `python tools/emblem_wit_transparant.py`,
              dan `--import` en `-- uicheck`.
  icons/      30 witte iconen (kleur je in met modulate)
  fonts/      Roboto Slab Regular + Bold (van deze machine); zie hieronder
  texture/    Texture_1.png (perkament)
```

## Wie wat gebruikt

Alles loopt via `scripts/ui/ui_assets.gd` (`UiAssets`): iconen op hun id uit
`docs/design/UI-SPEC-EN.md` (`UiAssets.icoon("stat-hp")`), emblemen per factie
(`UiAssets.embleem(doctrine)`), kaartonderdelen (`UiAssets.kaart("lint_rood")`),
knop- en paneelstijlen als 9-patch (`knop_stijl`, `paneel_stijl`) en het
thema dat de autoload `UiThema` over het hele spel legt. In een scherm zet je
alleen `theme_type_variation` (de lijst staat in ui_assets.gd bij
THEMA-VARIANTEN); je hoeft nergens een pad te kennen.

Controleren wat er ligt en wat mist: `<godot> --headless --path .
res://tools/capture.tscn -- uicheck` (statusbord: elk icoon-id, embleem,
kaartdeel, knop en font, plus of het thema bouwt).

## Beweging (30 september)

Elke inkom en elke microinteractie komt uit `scripts/ui/ui_beweging.gd`
(via `const Beweging := preload(...)`). Drie patronen:

- **ERIN**: een scherm of laag komt binnen (`inkom_scherm`, `inkom_rij`,
  `schuif_in`, `wissel`, `fade_in`).
- **TIK**: reactie op aanraken, keuze of waarde (elke knop via de haak in
  `UiThema`, plus `plof`, `punch`, `dip`, `stempel`, `schud`, `tel_op`,
  `duw`, `zweef`, `draai_om`, `naar_schaal`).
- **WEG**: alleen voor losse lagen (`spook_weg`: voor de logica meteen weg,
  voor het oog in 0,12 s).

| Token | Waarde | Gebruik |
|---|---|---|
| indrukken | 0,08 s QUAD out, naar 0,94-0,985 (grote knoppen minder) | elke knop |
| terugveren | 0,22 s BACK out | loslaten |
| hover | 0,12 s, 1,02-1,05, alleen met een echte muis | desktop |
| scherm in | schaal 0,94 naar 1 in 0,26 s BACK, alpha 0,16 s, waas 0,18 s | overlay, uitleg, pop-ups |
| rijen | 0,20 s per item, 0,035 s ertussen, samen hooguit 0,20 s | lijsten |
| plof | 0,24 s BACK, vanaf 0,6-0,85 | keuze, nieuw icoon |
| punch / dip | 0,07 s naar 1,25 (0,85), 0,16 s BACK terug | getallen |
| stempel | van 1,45 met -8 graden, 0,10 + 0,14 s | CP-zegel, STEM, winst |
| tel op | tot 0,5 s, de laatste tekst exact | punten, saldi |
| duw | een zachte puls na 6 s niets doen, dan elke 8 s | de knop die op jou wacht |

Huisregels (bovenin de module): alleen beeld bovenop een staat die al klopt
(nooit `visible`, teksten of submits uitstellen); nooit de root van een
CardView, `Kaartlaag.modulate`, `CpZegel.modulate`/`size` of de
statkolommen; in containers alleen alpha en een schaal die op de rust
eindigt; elke tween negeert de time_scale; headless niets (tenzij een check
forceert); alles binnen 0,45 s klaar.

Standen: Instellingen > Animaties (normaal / rustig / uit, in
`user://settings.cfg [ui] beweging`); dev-knop `ui_tempo` in het
sfeer-paneel. Controle: `-- inkomcheck [fase]`.

## Wat er (nog) niet in zit

- **Acht iconen uit de spec** zijn niet geleverd: vote, nomination, donation,
  testament, report, chat, clock, pin (campagne/sociaal en tijd). Schermen
  vallen daar terug op tekst; zodra de png's er zijn, zet je de bestandsnaam
  in `UiAssets.ICONEN` en haalt hem uit `NOG_NIET_GELEVERD`.
- **Fonts.** De pdf schrijft Roboto Slab SemiBold (tekst) en Rye Regular
  (cijfers) voor. Die twee zitten niet in het pack. In `fonts/` staan nu
  Roboto Slab Regular en Bold van deze machine; het thema gebruikt Regular
  voor tekst en Bold voor koppen en cijfers. Drop `RobotoSlab-SemiBold.ttf`
  en `Rye-Regular.ttf` (Google Fonts, OFL) in `fonts/`, importeer, en het
  thema pakt ze vanzelf op (volgorde in `UiAssets.FONTS`).
- **Gouden selectiehoeken** van de "SELECTED"-kaart (pdf pagina 3) zijn geen
  los bestand; het spel tekent een gouden rand + gloed in Selection Gold.

## Mipmaps

De iconen en kaartdelen worden vaak op 30-60% getekend; de `.import`-
bestanden hier staan daarom op `mipmaps/generate=true` en het project op
`default_texture_filter` = linear-with-mipmaps. Nieuwe png's krijgen de
Godot-standaard (geen mipmaps): zet het even aan in het importpaneel of kopieer
een bestaand `.import`-blok.

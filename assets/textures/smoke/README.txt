Zwartkruit-rook textures (musket + kanon)
==========================================
Drop hier rook-afbeeldingen. Drie vormen werken:

1. Los plaatje met transparantie (alpha).
2. Los plaatje 'isolated on solid black background' (AI-output): zwart
   wordt bij het laden automatisch transparantie (helderheid = dekking).
3. SPRITE SHEET: zet het grid in de bestandsnaam, bv.
   musket_smoke_3x3.png of kanon_rook_4x4.png - de frames spelen dan als
   animatie af over de levensduur van de wolk (ontstaan -> uitzetten ->
   oplossen). Zwarte achtergrond mag ook hier.

Elke rookwolk (loop + inslag, musket en kanon) kiest willekeurig een
bestand uit deze map; meerdere varianten = vanzelf afwisseling.
Map leeg = grijze bol-wolkjes (fallback). Tip: max ~1024px per bestand.

Tunen in de Model-tuner: rook-aantal, rook-maat, rook-groei, rook-duur,
rook-drift. Testknoppen: rook (musket) / rook (kanon).

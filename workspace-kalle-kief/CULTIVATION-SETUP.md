# Cultivation Setup Reference

## Current grow — plants & hardware
- **3 plants / 3 seeds**, 3 pots à **9 liter** each
  - 2× Linda Seeds — Gorilla Skittlez
  - 1× Elev8 Seeds — Apples and Bananas
- **Tent:** 90 cm × 90 cm
- **LED:** Lumatek ATS 200W (200W model) — 460 µmol/s PPF @ 2,3 µmol/J
- **Medium:** Coco coir, no drain/runoff possible (space constraint) — always ~2 L/pot
- **Grow phase:** In flower since **Monday 17. August 2026** (bloom day 1) — ~5 weeks into flower as of late Sept 2026

## Water (Maintal Werke tap water)
- Aktuelle vollständige Analyse (Analysen-Nr. 202622349, Probe 11.05.2026):
  siehe `WATER-ANALYSIS.md`
- Vorgänger-Analyse (Analysen-Nr. 202517265, 25.08.2025):
  pH 7,85 · Leitfähigkeit 297 µS/cm · Gesamthärte 7,16 °dH (weich)
  Calcium 33,7 · Magnesium 10,6 · Kalium 2,3 · Nitrat 8,8 mg/l (~2,0 mg/l N)
  Sulfat 16,9 · Chlorid 13,9 · Eisen 0,0096 mg/l

## Medium & irrigation
- Cocos coir, no drain/runoff possible (space constraint) — always ~2 L/pot
- pH corrected to 6,0 manually before every feed

## Fertilizers on hand
| Product | Analysis |
|---|---|
| Hakaphos Blau | 15% N (4,5 NO3 / 10,5 NH4) – 10% P2O5 – 15% K2O – 2% MgO + B/Cu/Fe/Mn/Mo/Zn (EDTA-chelate) |
| Haifa Cal (Calciumnitrat) | 15,5% N (14,4 NO3 / 1,1 NH4) – 26,5% CaO |
| EPSO Top (Bittersalz) | 16% MgO – 32,5% SO3 (= 13% S), MgSO4·7H2O |
| Peters Blossom Booster | 10-30-20 + 2% MgO, only during the flip/stretch transition |
| Peters Professional Combi Sol | 6-18-36 + 3% MgO + TE, main bloom fertilizer from ~week 4 |

### Full composition details (from manufacturer data)
- **Hakaphos Blau 15+10+15(+2)** (COMPO EXPERT): NPK + MgO 2%, plus B 0,01 / Cu 0,02 (EDTA) / Fe 0,075 (EDTA) / Mn 0,05 (EDTA) / Mo 0,001 / Zn 0,015 (EDTA) %. Physiologisch sauer, ausgeglichenes N:K, besonders geeignet für hartes Gießwasser. Dosierung (Bewässerung): 0,5–1,5 g/l.
- **Peters Professional Combi Sol 6-18-36+3MgO** (ICL): N 6% (all NO3), P2O5 18%, K2O 36%, MgO 3%, Fe 0,25 (DTPA), Mn 0,06, B 0,02, Cu 0,015, Mo 0,010, Zn 0,015 (EDTA), alle wasserlöslich. N:K = 1:6, niedriger EC. Dosierung: 0,5–1,5 g/l (Bewässerung), 0,8–2 g/l (Intervall). Empfohlen Stammlösung 1–2 h vorab ansetzen.
- **Peters Professional Blossom Booster 10-30-20+2MgO** (ICL): N 10% (5,2 NO3 / 4,8 NH4), P2O5 30%, K2O 20%, MgO 2%, Fe 0,12 (DTPA), Mn 0,06, B 0,02, Cu 0,015, Mo 0,010, Zn 0,015. Phosphat-/kalibetont zur Knospen-/Blütenbildung. Dosierung: 0,5–1,5 g/l (Bewässerung).
- **Haifa Cal GG Calciumnitrat** (Haifa): 15,5% N (14,4 NO3 / 1,1 NH4), 26,5% CaO. Voll wasserlöslich, „Greenhouse Quality". Mischt in Stammlösung NICHT mit phosphat-/sulfathaltigen Düngern (Ausfällung). pH (10% Lsg) ~5,5.
- **EPSO Top / Bittersalz** (K+S): 16% MgO, 32,5% SO3 (≈13% S), MgSO4·7H2O, für Öko-Landbau zugelassen. Voll wasserlöslich.

## Calcium / Magnesium (Ca/Mg) dosing
- **Ziel: elementares Ca:Mg ≈ 3:1** (cannabis-üblich 3:1 bis 5:1). Das Verhältnis wird auf die ELEMENTE bezogen, nicht auf Salzmasse.
- **WICHTIG — korrigierte Methode:** Der frühere "Massen-Verhältnis 2:1" war FALSCH. Er basierte auf einer Fehlannahme (gleiche Elementdichte beider Salze). Quelle/Beleg: Backup der Vorgänger-Instanz `cannabis-feeding-plan-calc` (nutrition.ts + deep-research-report.md) — dort wird immer Oxid→Element umgerechnet und 3:1 elementar anvisiert, nie eine feste 2:1-Salzregel.
- **Umrechnungsfaktoren (Oxid → Element):** CaO→Ca ×0,714 · MgO→Mg ×0,603 · P2O5→P ×0,436 · K2O→K ×0,831.
- **Elementdichte der Salze:** Haifa Cal GG = 26,5% CaO → 18,9% Ca; EPSO Top = 16% MgO → 9,65% Mg.
- **Basiswasser:** Ca 35,0 : Mg 11,4 mg/l (bereits ~3,1:1) — siehe `WATER-ANALYSIS.md`.
- **Mischbehälter: 5 Liter** (Standard-Gießkanne).

### Korrigierte 5-L-Rezeptur (Ziel 3,00:1 elementar)
- **1,05 g Haifa Cal GG + 0,7 g EPSO Top / 5 L** → Ca 74,7 : Mg 24,9 = 3,00:1, EC ≈ +0,43 mS/cm. (Massen-Verhältnis ~1,5:1, NICHT 2:1.)
- Alternative (gleicher EC-Komfort): 1,35 g Haifa + 0,9 g EPSO / 5 L → 3,00:1, EC ≈ +0,56.
- Beitrag pro g / 5 L: Haifa Cal +37,8 mg/L Ca · EPSO +19,3 mg/L Mg.
- Frühere (falsche) Praxis: 1,4 g Haifa + 0,7 g EPSO / 5 L → 3,53:1 (zu calciumlastig), EC +0,53.

## Calibration data (measured/sourced, not theoretical)
- Hakaphos Blau, manufacturer EC table (COMPO EXPERT datasheet):
  0,5‰ = 0,79 mS/cm · 1,0‰ = 1,52 mS/cm · 1,5‰ = 2,20 mS/cm
- Haifa Cal: ≈1,354 mS/cm per g/l (Kohlrausch calc from declared Ca²⁺/NH4⁺/NO3⁻)
- EPSO Top: ≈1,071 mS/cm per g/l (Kohlrausch calc from declared Mg²⁺/SO4²⁻)
- Confirmed incident: 0,9 g/l Hakaphos + 0,4 g/l Haifa Cal + 0,2 g/l EPSO Top
  measured >2,3 mS/cm total solution EC → visible leaf tip burn (nutrient/salt
  burn, not deficiency)

## Feeding methodology
- Fertilizer transitions: soft-switch (e.g. 50/50 blend over ~1 week), never abrupt
- EC ceiling in flower: 1,3-1,4 mS/cm total solution EC (meter reading), because
  of the no-runoff constraint above
- Health signal to watch: new growth/bud development, not cosmetic tip damage
  on older fan leaves

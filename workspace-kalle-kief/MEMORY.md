# MEMORY.md — Cultivation Agent (durable facts & decisions)

## Ca/Mg Berechnung — korrigierte Methode (Stand 23.09.2026)

**Entscheidung:** Die frühere "2:1 Massen-Verhältnis"-Regel für Calciumnitrat:Magnesiumsulfat
war FALSCH. Sie entstand als undokumentierte Vereinfachung und liefert in Wahrheit ~3,5–3,9:1
(elementar), nicht 3:1.

**Korrekte Methode (belegt durch Vorgänger-Instanz `cannabis-feeding-plan-calc`):**
- Immer Oxid → Element umrechnen: CaO→Ca ×0,714 · MgO→Mg ×0,603 · P2O5→P ×0,436 · K2O→K ×0,831.
- Ziel: **elementares Ca:Mg = 3:1** (cannabis 3:1–5:1), NICHT eine feste Salz-Massenregel.
- Elementdichte: Haifa Cal GG = 26,5% CaO → 18,9% Ca; EPSO Top = 16% MgO → 9,65% Mg.
- Basiswasser: Ca 35,0 : Mg 11,4 mg/l (≈3,1:1) — Mischbehälter 5 Liter.

**Empfehlung (5 L Gießkanne, Ziel 3,00:1):**
- **1,05 g Haifa Cal GG + 0,7 g EPSO Top** → Ca 74,7 : Mg 24,9 = 3,00:1, EC ≈ +0,43 mS/cm.
- (Alternative bei gleichem EC-Komfort: 1,35 g Haifa + 0,9 g EPSO → 3,00:1, EC +0,56.)
- Beitrag pro g / 5 L: Haifa Cal +37,8 mg/L Ca · EPSO +19,3 mg/L Mg.
- Alte falsche Praxis: 1,4 g + 0,7 g → 3,53:1, EC +0,53.

**Quelle der Korrektur:** Backup `/mnt/openclaw-backup/.openclaw_BAK/workspace/cannabis-feeding-plan-calc/`
(`src/utils/nutrition.ts` Konstanten + `docs/deep-research-report.md` Düngetabellen), identisch zur
Live-App `https://cannabis-feedings.apps.sieh.org/`. Beide verwenden 3:1-Band (±0,35), nie 2:1-Masse.

## Referenzmischung Blüte Woche 6 (gemessen 25.09.2026) — von Henning als Standard festgelegt

**5-L-Kanne: 3,0 g Combi Sol + 1,05 g Haifa Cal GG + 0,7 g EPSO Top → pH 6,0 → gemessene EC 1,4 mS/cm.**

- **Belegt (Meter-Messung):** Gesamt-EC 1,4 mS/cm bei dieser exakten Mischung auf Maintal-Basiswasser (Start-EC ≈ 0,30).
- Abgeleitet: Combi-Sol-Beitrag ≈ 0,67 mS/cm bei 0,6 g/L → **≈ 1,1 mS/cm pro g/L** (kennzeichnet den bisherigen Schätzwert 0,9–1,0 nach oben; für künftige Berechnungen nutzen, trotzdem immer nachmessen).
- Das ist Obergrenze des EC-Korridors 1,3–1,4; bei Salzakkumulations-Anzeichen (kein Runoff!) zuerst klares Wasser pH ~6,0, nicht weiter aufdüngsen.
- Diese Mischung ist der Referenz-Fallback für die 2-Tage-Check-ins, solange Henning keine Änderung vorgibt.

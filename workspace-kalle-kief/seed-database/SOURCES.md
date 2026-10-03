# Recherche: Seed-Felder und Quellen

Stand der Recherche: 25.09.2026. Ziel ist ein privates, künftig erweiterbares Seed-Register — keine Genbank-Akzession und kein Ersatz für ein Grow-Log.

## Welche Informationen sind sinnvoll?

Ein einzelner physischer Seed hat nicht automatisch alle Eigenschaften, die in einem Sortenkatalog stehen. Ich trenne deshalb **Sorten-/Katalogangaben** von **Daten der konkreten Seed-Einheit**:

| Bereich | Felder | Primärquelle / Regel |
|---|---|---|
| Identität der Sorte | Züchter/Marke, Sortenname exakt wie auf Packung/Bestellung, optional standardisierter Katalogname | Seed-Packung und Bestellbeleg zuerst; offizieller Züchterkatalog zum Abgleich. Originalschreibweise bleibt erhalten. |
| Vom Züchter behauptete Sortenmerkmale | Genetik/Elternlinien, feminisiert oder regulär, photoperiodisch oder autoflowering, angegebene Blütezeit, Ertrag, THC/CBD | Exakte offizielle Produktseite oder Packung. Immer als Herstellerangabe speichern, nicht als Messwert der eigenen Pflanze; sonst NULL. |
| Bestand und Herkunft | lokale Seed-ID, Los-/Chargencode, Händler, Kaufdatum, Lagerhinweis | Packung, Rechnung/Bestellbestätigung und eigene Inventarnotiz. Fehlende Werte bleiben leer. |
| Verlauf der einzelnen Seed-Einheit | zugeordneter Grow/Plant-Tag, Aussaat, Keimdatum/-ergebnis, aktueller Status, Erntebezug | Eigene zeitnahe Grow-Notizen; Messung/Beobachtung nicht durch Katalogwerte ersetzen. |
| Eigene Ergebnisse | Phänotyp, beobachtete Blütezeit, Endhöhe, Trockenertrag, Notizen | Eigene Messungen nach Harvest, inklusive Messdatum/Einheit in der Notiz oder einem späteren Grow-Log-Modul. Nicht mit Züchterprognosen vermischen. |

## Quellenhierarchie

1. **Packung und Bestellbeleg** — maßgeblich für genau das gekaufte Produkt, Losnummer, Händler und Kaufdatum.
2. **Offizielle Züchter-/Breeder-Produktseite** — maßgeblich für vom Anbieter behauptete Sortenmerkmale. Diese Angaben können sich ändern und sind keine unabhängige Messung.
3. **Eigener Grow-Log** — maßgeblich für konkrete Aussaat-, Keimungs-, Pflanzen- und Erntedaten.
4. **Sekundäre Seed-Kataloge/Foren** — nur als Recherchehinweis, nie zur stillen Überschreibung von Packungsnamen oder eigenen Beobachtungen.

## Geprüfte externe Einstiege

- [Linda Seeds offizieller Katalog](https://www.linda-seeds.com/en/) — als künftige Quelle für konkrete Linda-Produktseiten geprüft. Die exakte Gorilla-Produktseite und deren Angaben konnte ich in dieser Recherche nicht belastbar zuordnen; daher sind keine Linda-Katalogmerkmale in der Datenbank eingetragen.
- [Elev8 Seeds offizieller Katalog](https://elev8seeds.com/) — offizieller Anbieter-Katalog geprüft. Eine konkrete aktuelle Produktseite für „Apples and Bananas“ wurde nicht gefunden; daher sind keine Elev8-Katalogmerkmale eingetragen.
- [CULTIVATION-SETUP.md](../CULTIVATION-SETUP.md) — interne Primärquelle für die aktuelle Zuordnung und Stückzahlen: zwei Linda Seeds „Gorilla Zkittlez“ und ein Elev8 Seeds „Apples and Bananas“, insgesamt drei Pflanzen/Seeds. Das Setup enthält keine Charge, Kauf-, Aussaat- oder Keimdaten.

## Befüllungsentscheidung

- Die beiden Sortennamen werden **genau wie im Grow-Setup** gespeichert.
- Eingetragen sind **2 Sorten-Datensätze und 3 Seed-Einheiten**, weil das Setup drei Seeds/Pflanzen nennt. Die Unit-IDs sind lokale Datenbank-IDs, keine ursprünglichen Packungs- oder Pflanzenschilder.
- Nicht belegte Angaben (Genetik, Seed-Typ, THC/CBD, Ertrag, Charge, Kauf-/Aussaat-/Keimdatum, Händler und Lagerort) bleiben leer. Es wurden dafür keine Werte geschätzt.

## Ergänzung: Recherche zu Alternativen für Apples and Bananas

Die beiden vom Nutzer angehängten Textdateien wurden als **Quellenbehauptungen** erfasst, nicht als unabhängig bestätigte Händlerdaten:

- `media://inbound/pasted-text-1790315562108---b9498418-70f3-49a0-a830-4d8ad62a5107.txt` — Angebotsvergleich für Apples and Bananas S1 sowie Shop-/Versandhinweise.
- `media://inbound/pasted-text-1790315596879---7416c5e9-6ca0-4653-9316-021159fd128c.txt` — Banana Brawler, Banana Punch, Fat Banana, Banana Purp und Orbital Banana F1; im Text genannte Merkmale, Empfehlungen, Packungsgrößen und Preise.

Die Datenbank trennt die **Original-Angebotsreferenz Apples and Bananas S1** und einen erwähnten **Apples & Bananas von Cookies** (anderer Breeder) von den fünf eigentlichen Alternativ-Kandidaten. Der Breeder des Mr.-Hanf-Angebots „Apples and Bananas S1“ wurde im Text nicht ausdrücklich genannt und bleibt daher offen. Preise, Lagerbestand, Versandbedingungen und Sortenmerkmale haben `verified = 0`-Status; Shop-URLs sind gespeicherte Prüfziele, keine bestätigten aktuellen Angebote. `Orbital Banana F1` wurde ohne Produktlink überliefert.

## Linda-Seeds-Suche: Original und Alternativen (25.09.2026)

Korrektur der vorherigen Rechercheaussage: **Linda Seeds listet das gesuchte Original von Elev8 Seeds tatsächlich.** Die direkte [Linda-Produktseite für Apples and Bananas — Elev8 Seeds](https://www.linda-seeds.com/en/buy-feminized-marijuana-seeds/sativa/extremely-high-content-of-thc/large-yield/apples-and-bananas-elev8-seeds) wurde am 25.09.2026 mit HTTP 200 abgerufen; Seitentitel: „Apples and Bananas seeds by Elev8 Seeds – order here“. Die frühere Vorprüfung über die Produkt-Sitemap hatte diesen Treffer übersehen.

Linda nennt für dieses Original **Platinum Cookies × Granddaddy Purple × Blue Power × Gelatti**, feminisierte photoperiodische Samen, 8–9 Wochen Blüte, 24 % THC und ein fruchtiges Apfel-/Bananenprofil mit erdigen, würzigen und petroligen Noten. Angezeigter Preis: **51,90 € inkl. MwSt., zzgl. Versand**. Das sind Angaben der Händlerseite, keine unabhängigen Messwerte oder direkte Breeder-Bestätigung. Die auslesbare Seite nannte keine Packungsgröße; „order here“ im Titel ist außerdem kein eindeutiger Lagerbestandsnachweis.

Auch den Ziel-Eintrag **Apples and Bananas S1 — Elev8 Seeds** habe ich auf der [Mr.-Hanf-Produktseite](https://mr-hanf.de/samen-shop/weitere-kategorien/usa-genetik/apples-and-bananas-s1) geprüft. Sie nennt dieselbe beworbene Vierer-Linie sowie Apfel-/Bananen-, erdige und würzige Noten mit cremig-würzigem Abgang (Händlerangaben; keine direkte Elev8-Seite). Mr. Hanf führt „S1“ im Angebotstitel; die Linda-Seite lässt diese Bezeichnung weg, daher ist damit keine identische Packungsvariante belegt.

Damit ist Linda zunächst eine Bezugsquelle für **das Original**, nicht bloß ein Ersatz.

Linda listet zwei sehr nahe, anders gezüchtete Varianten mit fast gleichem Namen:

1. [Apple and Bananas — Kannabia Seeds](https://www.linda-seeds.com/en/buy-feminized-marijuana-seeds/hybrid/extremely-high-content-of-thc/large-yield/apple-and-bananas-kannabia-seeds): Linda gibt Platinum Cookies × Grandaddy Purple × Blue Power × Gelatti an und beschreibt sauren Apfel/reife Banane mit cremig-würzigem Abschluss; Blüte etwa 65–70 Tage, THC bis 27 % laut Händlerseite.
2. [Apple Bananas — 00 Seeds Bank](https://www.linda-seeds.com/en/buy-feminized-marijuana-seeds/hybrid/extremely-high-content-of-thc/large-yield/apple-bananas-00-seeds-bank): Linda nennt Platinum Cookies, GDP, Bluepower und Gelati sowie Apfel-/Bananen-/Beerennoten; feminisiert, 8–9 Wochen und 25 % THC laut Händlerseite.

Beide sind **die stärksten naheliegenden Ersatzkandidaten nach Sortenname, beworbener Elternlinie und Fruchtprofil**: Die dort genannten Elternlinien stimmen mit der Händlerangabe zum Elev8-Ziel überein. Beide Kandidaten stammen aber von anderen Breedern; identische Zuchtlinie, Stabilität oder Phänotyp sind dadurch nicht belegt.

Weitere Linda-Angebote mit Teilüberschneidung:

- [Banana Brawler — Royal Queen Seeds](https://www.linda-seeds.com/en/buy-feminized-marijuana-seeds/hybrid/extremely-high-content-of-thc/large-yield/banana-brawler-royal-queen-seeds): Linda nennt Gelatti × Blue Power und Banane/Würze/erdig-waldige Noten; ca. 24 % THC, 8–10 Wochen. Der frühere angehängte Vergleich nannte 8–9 Wochen; beide Händlertexte sind in der DB erhalten.
- [Apple Fritter — Elev8 Seeds](https://www.linda-seeds.com/en/buy-feminized-marijuana-seeds/hybrid/extremely-high-content-of-thc/large-yield/apple-fritter-elev8-seeds): gleiche Marke wie das Ziel, aber andere Linie (Sour Apple × Animal Cookies) und Apfelgebäck/Erde/Vanille statt Banane.
- [Banana Punch — Linda Seeds](https://www.linda-seeds.com/en/buy-feminized-marijuana-seeds/hybrid/extremely-high-content-of-thc/large-yield/banana-punch-linda-seeds): Banana OG × Purple Punch und Banane/Ananas laut Linda; daher nur dann interessant, wenn Banane wichtiger ist als die restliche A&B-Linie.

Die Produktseiten ließen sich am Recherchetag abrufen; das ist kein verlässlicher Nachweis des aktuellen Lagerbestands. Beim ersten reinen Text-Extractor-Lauf waren Variantenmengen unsichtbar; die spätere Browser-DOM-Prüfung hat auf diesen Seiten je einen aktuell ausgewählten 1er bzw. 3er samt Preis offengelegt (siehe Live-Preisprüfung unten).

## Live-Preisprüfung der Rechercheangebote (25.09.2026)

Die Preise unten wurden erneut direkt aus den gerenderten Produktseiten im Browser ausgelesen. Bei Mr. Hanf standen Packungsgröße, Variantenpreis und Bestell-/Lagerstatus gemeinsam auf der jeweiligen Seite. Bei Linda Seeds wurde die vorausgewählte Packungsvariante gegen den angezeigten Seitenpreis geprüft. EUR/Seed = Packungspreis ÷ Samenanzahl; Versand ist nicht enthalten. Händlerpreise und Bestandslabels sind Momentaufnahmen, keine Preisgarantie.

| Datenbankeintrag | Händlerangebot (Preis ÷ Samen) | €/Seed |
|---|---|---:|
| Apples and Bananas S1 — Elev8 Seeds | [Mr. Hanf](https://mr-hanf.de/samen-shop/weitere-kategorien/usa-genetik/apples-and-bananas-s1): 3 für 39,99 €; 6 für 89,99 € | 13,33 €; 15,00 € |
| Apples and Bananas — Elev8 Seeds (Linda; ohne S1-Zusatz) | [Linda Seeds](https://www.linda-seeds.com/en/buy-feminized-marijuana-seeds/sativa/extremely-high-content-of-thc/large-yield/apples-and-bananas-elev8-seeds): vorausgewählte 3er-Packung 51,90 € | 17,30 € |
| Apple and Bananas — Kannabia Seeds | [Linda Seeds](https://www.linda-seeds.com/en/buy-feminized-marijuana-seeds/hybrid/extremely-high-content-of-thc/large-yield/apple-and-bananas-kannabia-seeds): vorausgewählter 1er 4,25 € (Sale, statt 8,50 €) | 4,25 € |
| Apple Bananas — 00 Seeds Bank | [Linda Seeds](https://www.linda-seeds.com/en/buy-feminized-marijuana-seeds/hybrid/extremely-high-content-of-thc/large-yield/apple-bananas-00-seeds-bank): vorausgewählter 1er 5,50 € | 5,50 € |
| Banana Brawler — Royal Queen Seeds | [Mr. Hanf](https://mr-hanf.de/samen-shop/feminisierte-samen/banana-brawler): 1 für 12,00 €; 3 für 29,00 €; 5 für 44,00 €; 10 für 80,00 € | 12,00 €; 9,67 €; 8,80 €; 8,00 € |
| Apple Fritter — Elev8 Seeds | [Linda Seeds](https://www.linda-seeds.com/en/buy-feminized-marijuana-seeds/hybrid/extremely-high-content-of-thc/large-yield/apple-fritter-elev8-seeds): Seite zeigte „from 49,50 EUR“, aber auch „Item currently not available“ | nicht als kaufbares Angebot geführt |
| Banana Punch — Barney’s Farm | [Mr. Hanf](https://mr-hanf.de/samen-shop/banana-punch-barneys-farm): 3 für 31,15 €; 5 für 44,26 €; 10 für 76,50 €. 1er für 11,49 € war ausverkauft. | 10,38 €; 8,85 €; 7,65 € |
| Banana Punch — Linda Seeds | [Linda Seeds](https://www.linda-seeds.com/en/buy-feminized-marijuana-seeds/hybrid/extremely-high-content-of-thc/large-yield/banana-punch-linda-seeds): vorausgewählter 1er 3,50 € | 3,50 € |
| Banana Purp — Medical Seeds | [Mr. Hanf](https://mr-hanf.de/samen-shop/weitere-kategorien/medizinische-samen/banana-purp): 3 für 22,99 €; 5 für 38,00 €; 10 für 75,00 € | 7,66 €; 7,60 €; 7,50 € |
| Fat Banana — Royal Queen Seeds | [Mr. Hanf](https://mr-hanf.de/samen-shop/sortenvielfalt/thc-reiche-sorten/fat-banana): 1 für 9,50 €; 3 für 25,00 €; 5 für 37,50 €; 10 für 70,00 € | 9,50 €; 8,33 €; 7,50 €; 7,00 € |
| Orbital Banana F1 — Royal Queen Seeds | [Mr. Hanf](https://mr-hanf.de/en/seed-shop/variety-diversity/f1-cannabis-varieties/orbital-banana-f1): 1 für 15,50 €; 3 für 38,00 €; 5 für 57,00 €; 10 für 105,00 € | 15,50 €; 12,67 €; 11,40 €; 10,50 € |

**Aus der bepreisten Vergleichstabelle ausgeschlossen:** *Apples & Bananas — Cookies*: für diesen DB-Eintrag ließ sich kein exaktes, passendes Händlerangebot mit Preis und Packungsgröße verifizieren; ein ähnlich benanntes Kannabia-Produkt ist ein anderer Züchtereintrag. Apple Fritter ist wegen der expliziten Nichtverfügbarkeit ebenfalls nicht als aktueller Kaufpreis gelistet. Der ältere Anhangspreis für Orbital Banana F1 (3: 30,40 €) bleibt als historische Nutzerangabe in der Datenbank erhalten und wurde nicht als Live-Preis verwendet.

Die live geprüften Angebote sind als `candidate_offers`-Zeilen mit eigenen `source_catalog`-Belegen in Migration `005_live_offer_prices_2026-09-25.sql` gespeichert; ältere Anhangsangaben bleiben zur Herkunftsklärung erhalten und werden nicht mit den Live-Angeboten verwechselt.

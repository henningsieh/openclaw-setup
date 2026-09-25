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
- [CULTIVATION-SETUP.md](../CULTIVATION-SETUP.md) — interne Primärquelle für die aktuelle Zuordnung und Stückzahlen: zwei Linda Seeds „Gorilla Skittlez“ und ein Elev8 Seeds „Apples and Bananas“, insgesamt drei Pflanzen/Seeds. Das Setup enthält keine Charge, Kauf-, Aussaat- oder Keimdaten.

## Befüllungsentscheidung

- Die beiden Sortennamen werden **genau wie im Grow-Setup** gespeichert. Für Gorilla Skittlez bleibt ein möglicher abweichender Katalogname offen, bis die Packung oder die exakte offizielle Produktseite vorliegt.
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

Die Produktseiten ließen sich am Recherchetag abrufen; das ist kein verlässlicher Nachweis des aktuellen Lagerbestands. Auf der Kannabia-Seite wurden 4,25 € (statt 8,50 €) angezeigt, auf der Linda-eigenen Banana-Punch-Seite 3,50 €; der extrahierte Text zeigte jeweils keine Packungsgröße, daher keine Stückpreise ableiten.

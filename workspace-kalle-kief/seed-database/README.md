# Seed-Datenbank

Private SQLite-Datenbank für Sorten, einzelne Seeds und ihre Datenherkunft.

## Dateien

- `seed-registry.sqlite3` — aktuelle Datenbank
- `schema.sql` — Tabellen- und Felddefinition
- `initial-data.sql` — nachvollziehbare Erstbefüllung; kann nach leerer Schema-Erzeugung ausgeführt werden
- `migrations/` — vorwärts gerichtete Schema-/Daten-Erweiterungen für eine vorhandene Datenbank
- `SOURCES.md` — recherchierte Feldliste, Quellenhierarchie und offene Angaben

## Datenmodell

- `cultivars`: eine Zeile pro benannter Sorte/Produkt. Züchterangaben sind ausdrücklich „claimed“/Herstellerangaben.
- `seed_units`: eine Zeile pro konkreter Seed-Einheit, inklusive Inventar-, Keimungs- und Grow-Verlauf.
- `seed_research_candidates` und `candidate_offers`: Alternativen in der Recherche und dazugehörige Shop-Angebote. Das sind **keine** Seeds im eigenen Bestand.
- `grow_runs`: Grow-Zuordnung und bekannte Grow-Eckdaten.
- `source_catalog` und `field_evidence`: Quelle und Beleg/Notiz pro eingetragenem Feld.

Unbekannte oder noch nicht belegte Werte bleiben SQL-`NULL`; es wird nichts aus ähnlichen Katalogen ergänzt. Datumswerte verwenden `YYYY-MM-DD`. Felder mit Spanne/Herstellerwortlaut bleiben Text, damit Bereiche nicht in eine scheinpräzise Einzelzahl umgewandelt werden.

Die angehängten Preis- und Sortenangaben sind als **ungeprüfte Nutzer-übermittelte Claims** gespeichert. `verified = 0` markiert Kandidaten, deren Anbieterangaben noch nicht auf einer Produktseite kontrolliert wurden; `verified = 1` bedeutet lediglich, dass eine passende Produktseite abgerufen und deren Angaben als Händler-/Züchter-Claims festgehalten wurden. Das ist keine unabhängige biologische Bestätigung und bestätigt nicht den Lagerbestand. Recherche-Kandidaten sind kein eigener Bestand.

## Abfragen

Seed-Bestand mit Sorte und Status:

```sql
SELECT s.seed_id, c.breeder_as_recorded, c.cultivar_name_as_recorded,
       s.lifecycle_status, s.status_as_of, s.lot_code, s.sown_on, s.germinated_on
FROM seed_units AS s
JOIN cultivars AS c USING (cultivar_id)
ORDER BY s.seed_id;
```

Quellenbelege anzeigen:

```sql
SELECT e.entity_kind, e.entity_id, e.field_name, src.title, src.uri, e.excerpt_or_note
FROM field_evidence AS e
JOIN source_catalog AS src USING (source_id)
ORDER BY e.entity_kind, e.entity_id, e.evidence_id;
```

Alternativen samt den überlieferten Angeboten anzeigen:

```sql
SELECT c.product_name, c.breeder_as_reported, c.profile_claims, c.genetics_claim,
       o.retailer, o.pack_size_seeds, o.price_claim, o.product_url, c.verified
FROM seed_research_candidates AS c
LEFT JOIN candidate_offers AS o USING (candidate_id)
WHERE c.candidate_role = 'alternative'
ORDER BY c.product_name, o.pack_size_seeds;
```

Mit `sqlite3 seed-registry.sqlite3` lässt sich die Datenbank interaktiv öffnen. Für spätere Änderungen nur neue Einträge ergänzen; `initial-data.sql` nicht erneut auf die bereits befüllte Datenbank anwenden.

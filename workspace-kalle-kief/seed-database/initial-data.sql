PRAGMA foreign_keys = ON;

INSERT INTO source_catalog
    (source_id, source_kind, title, uri, accessed_on, used_for_values, limitations)
VALUES
    ('SRC-SETUP', 'grow_reference', 'Cultivation setup reference', '../CULTIVATION-SETUP.md', '2026-09-25', 1,
     'Internal source. Establishes cultivar labels and counts for the current grow; it does not record packet/lot data or individual sowing and germination dates.'),
    ('SRC-LINDA-CATALOG', 'breeder_catalog', 'Linda Seeds official catalog entry point', 'https://www.linda-seeds.com/en/', '2026-09-25', 0,
     'Official catalog homepage checked for source policy. Exact Gorilla product page/name and product claims were not verified in this pass; no catalog traits were imported.'),
    ('SRC-ELEV8-CATALOG', 'breeder_catalog', 'Elev8 Seeds official catalog entry point', 'https://elev8seeds.com/', '2026-09-25', 0,
     'Official catalog homepage checked for source policy. An exact Apples and Bananas product page was not located in the current catalog; no catalog traits were imported.'),
    ('SRC-LINDA-AB-KANNABIA', 'other', 'Linda Seeds product listing: Apple and Bananas — Kannabia Seeds',
     'https://www.linda-seeds.com/en/buy-feminized-marijuana-seeds/hybrid/extremely-high-content-of-thc/large-yield/apple-and-bananas-kannabia-seeds',
     '2026-09-25', 1, 'Linda Seeds retailer product page, fetched successfully. Genetics, aroma and cultivation figures are retailer/breeder claims, not independent measurements.'),
    ('SRC-LINDA-AB-00SEEDS', 'other', 'Linda Seeds product listing: Apple Bananas — 00 Seeds Bank',
     'https://www.linda-seeds.com/en/buy-feminized-marijuana-seeds/hybrid/extremely-high-content-of-thc/large-yield/apple-bananas-00-seeds-bank',
     '2026-09-25', 1, 'Linda Seeds retailer product page, fetched successfully. Genetics, aroma and cultivation figures are retailer/breeder claims, not independent measurements.'),
    ('SRC-LINDA-BANANA-BRAWLER', 'other', 'Linda Seeds product listing: Banana Brawler — Royal Queen Seeds',
     'https://www.linda-seeds.com/en/buy-feminized-marijuana-seeds/hybrid/extremely-high-content-of-thc/large-yield/banana-brawler-royal-queen-seeds',
     '2026-09-25', 1, 'Linda Seeds retailer product page, fetched successfully. Product characteristics are retailer/breeder claims; reported flowering time differs from the earlier user-provided comparison.'),
    ('SRC-LINDA-APPLE-FRITTER-ELEV8', 'other', 'Linda Seeds product listing: Apple Fritter — Elev8 Seeds',
     'https://www.linda-seeds.com/en/buy-feminized-marijuana-seeds/hybrid/extremely-high-content-of-thc/large-yield/apple-fritter-elev8-seeds',
     '2026-09-25', 1, 'Linda Seeds retailer product page, fetched successfully. Product characteristics are retailer/breeder claims, not independent measurements.'),
    ('SRC-LINDA-BANANA-PUNCH', 'other', 'Linda Seeds product listing: Banana Punch — Linda Seeds',
     'https://www.linda-seeds.com/en/buy-feminized-marijuana-seeds/hybrid/extremely-high-content-of-thc/large-yield/banana-punch-linda-seeds',
     '2026-09-25', 1, 'Linda Seeds product page, fetched successfully. Product characteristics are seller claims, not independent measurements.'),
    ('SRC-MRHANF-ELEV8-AB', 'other', 'Mr. Hanf product listing: Apples and Bananas S1 — Elev8 Seeds',
     'https://mr-hanf.de/samen-shop/weitere-kategorien/usa-genetik/apples-and-bananas-s1',
     '2026-09-25', 1, 'Retailer product page fetched successfully; it identifies the breeder as Elev8 Seeds and gives the listed lineages/profile. Treat as retailer-reported product data, not direct breeder confirmation.'),
    ('SRC-LINDA-ELEV8-AB', 'other', 'Linda Seeds product listing: Apples and Bananas — Elev8 Seeds',
     'https://www.linda-seeds.com/en/buy-feminized-marijuana-seeds/sativa/extremely-high-content-of-thc/large-yield/apples-and-bananas-elev8-seeds',
     '2026-09-25', 1, 'Linda retailer page fetched successfully (HTTP 200). Product/genetics claims are retailer claims; the readable page did not establish pack size or explicit stock status.');

INSERT INTO grow_runs (grow_id, label, flowering_started_on, notes, source_id)
VALUES ('GROW-2026-CURRENT', 'Aktueller Indoor-Coco-Grow 2026', '2026-08-17',
        'Grow reference records 3 plants / seeds: 2 × Linda Seeds — Gorilla Skittlez; 1 × Elev8 Seeds — Apples and Bananas.',
        'SRC-SETUP');

INSERT INTO cultivars
    (cultivar_id, breeder_as_recorded, cultivar_name_as_recorded, standardized_name, notes)
VALUES
    ('CV-LINDA-GORILLA-SKITTLEZ', 'Linda Seeds', 'Gorilla Skittlez', NULL,
     'Name kept exactly as written in the grow reference. Do not normalize to a catalog spelling until the packet or an exact official product page confirms it.'),
    ('CV-ELEV8-APPLES-BANANAS', 'Elev8 Seeds', 'Apples and Bananas', NULL,
     'Name kept exactly as written in the grow reference. Cultivar traits remain blank until supported by the packet or an exact official product page.');

INSERT INTO seed_units
    (seed_id, cultivar_id, grow_id, lifecycle_status, status_as_of, notes)
VALUES
    ('SEED-2026-001', 'CV-LINDA-GORILLA-SKITTLEZ', 'GROW-2026-CURRENT', 'flowering', '2026-09-25',
     'Database-assigned unit ID; setup records two seeds/plants of this cultivar but does not map individual seeds to plant labels.'),
    ('SEED-2026-002', 'CV-LINDA-GORILLA-SKITTLEZ', 'GROW-2026-CURRENT', 'flowering', '2026-09-25',
     'Database-assigned unit ID; setup records two seeds/plants of this cultivar but does not map individual seeds to plant labels.'),
    ('SEED-2026-003', 'CV-ELEV8-APPLES-BANANAS', 'GROW-2026-CURRENT', 'flowering', '2026-09-25',
     'Database-assigned unit ID; setup records one seed/plant of this cultivar but does not provide a physical plant label.');

INSERT INTO field_evidence (entity_kind, entity_id, field_name, source_id, excerpt_or_note)
VALUES
    ('grow', 'GROW-2026-CURRENT', 'flowering_started_on', 'SRC-SETUP', 'Grow reference: flowering since Monday 17 August 2026.'),
    ('grow', 'GROW-2026-CURRENT', 'plant_and_seed_counts', 'SRC-SETUP', 'Grow reference: 3 plants / 3 seeds.'),
    ('cultivar', 'CV-LINDA-GORILLA-SKITTLEZ', 'breeder_as_recorded', 'SRC-SETUP', 'Grow reference: 2 × Linda Seeds — Gorilla Skittlez.'),
    ('cultivar', 'CV-LINDA-GORILLA-SKITTLEZ', 'cultivar_name_as_recorded', 'SRC-SETUP', 'Grow reference spelling preserved verbatim: Gorilla Skittlez.'),
    ('cultivar', 'CV-ELEV8-APPLES-BANANAS', 'breeder_as_recorded', 'SRC-SETUP', 'Grow reference: 1 × Elev8 Seeds — Apples and Bananas.'),
    ('cultivar', 'CV-ELEV8-APPLES-BANANAS', 'cultivar_name_as_recorded', 'SRC-SETUP', 'Grow reference spelling preserved verbatim: Apples and Bananas.'),
    ('seed_unit', 'SEED-2026-001', 'cultivar_and_count', 'SRC-SETUP', 'First local unit ID instantiated from the recorded count 2 × Linda Seeds — Gorilla Skittlez; no physical plant tag is recorded.'),
    ('seed_unit', 'SEED-2026-002', 'cultivar_and_count', 'SRC-SETUP', 'Second local unit ID instantiated from the recorded count 2 × Linda Seeds — Gorilla Skittlez; no physical plant tag is recorded.'),
    ('seed_unit', 'SEED-2026-003', 'cultivar_and_count', 'SRC-SETUP', 'Local unit ID instantiated from the recorded count 1 × Elev8 Seeds — Apples and Bananas; no physical plant tag is recorded.'),
    ('seed_unit', 'SEED-2026-001', 'lifecycle_status', 'SRC-SETUP', 'The reference describes the current three-plant grow as flowering; individual plant labels are absent.'),
    ('seed_unit', 'SEED-2026-002', 'lifecycle_status', 'SRC-SETUP', 'The reference describes the current three-plant grow as flowering; individual plant labels are absent.'),
    ('seed_unit', 'SEED-2026-003', 'lifecycle_status', 'SRC-SETUP', 'The reference describes the current three-plant grow as flowering; individual plant labels are absent.');

INSERT INTO source_catalog
    (source_id, source_kind, title, uri, accessed_on, used_for_values, limitations)
VALUES
    ('SRC-ALT-AAB-RETAILERS', 'other', 'User-provided pasted comparison: Apples and Bananas retailers',
     'media://inbound/pasted-text-1790315562108---b9498418-70f3-49a0-a830-4d8ad62a5107.txt', '2026-09-25', 1,
     'Prices, shipping, availability, tax, pack size and product identity are transcribed as claims from the attachment; not independently checked.'),
    ('SRC-ALT-CULTIVARS', 'other', 'User-provided pasted comparison: banana cultivar alternatives',
     'media://inbound/pasted-text-1790315596879---7416c5e9-6ca0-4653-9316-021159fd128c.txt', '2026-09-25', 1,
     'Product traits, prices, availability and similarity/recommendation language are transcribed as claims from the attachment; not independently checked.');

INSERT INTO seed_research_candidates
    (candidate_id, candidate_role, product_name, breeder_as_reported, profile_claims, genetics_claim,
     seed_type_claim, thc_claim, flowering_time_claim, recommendation_claim, source_id, verified, notes)
VALUES
    ('CAND-AAB-MRHANF', 'target_listing', 'Apples and Bananas S1', 'Elev8 Seeds',
     'Frisch/fruchtig: Apfel und Banane, erdig/würzig; cremig-würziger Abgang (Mr. Hanf listing claim).',
     'Platinum Cookies × Granddaddy Purple × Blue Power × Gelatti (Mr. Hanf listing claim).',
     'S1, feminisiert, photoperiodisch (Mr. Hanf listing claim).', NULL, '8–9 weeks (Mr. Hanf listing claim).', NULL,
     'SRC-MRHANF-ELEV8-AB', 1,
     'Mr. Hanf product page identifies breeder as Elev8 Seeds and gives the target profile. This is a retailer claim, not a direct Elev8 source.'),
    ('CAND-AAB-COOKIES', 'same_name_other_breeder', 'Apples & Bananas', 'Cookies', NULL, NULL,
     NULL, NULL, NULL, NULL, 'SRC-ALT-AAB-RETAILERS', 0,
     'Laut Attachment hat Zamnesia nur diese Variante eines anderen Breeders; daher nicht als Elev8-Genetikgleichheit behandeln.'),
    ('CAND-BANANA-BRAWLER', 'alternative', 'Banana Brawler', 'Royal Queen Seeds',
     'Anhang: süß/cremig, tropische Banane, gassy/erdig; Linda-Seite: reife Banane, Würze, erdig-waldig (jeweils Anbieter-/Rechercheangabe).',
     'Linda-Seite nennt Gelatti × Blue Power.', NULL, 'ca. 24 % (Linda-Seite/Anhang).',
     'Anhang: 8–9 Wochen; Linda-Seite: 8–10 Wochen.',
     'Im Anhang als A&B-ähnlicher Vibe bewertet; Linda bestätigt die Banane-/Erdnoten, aber keine Gleichheit mit Elev8.',
     'SRC-ALT-CULTIVARS', 1, 'Zusätzliche Linda-Produktseite geprüft; siehe Linda-Angebot mit eigener Quellenzuordnung. Abweichende Blütezeitangaben bleiben erhalten.'),
    ('CAND-BANANA-PUNCH', 'alternative', 'Banana Punch', 'Barney''s Farm',
     'Banane, tropische Beeren und Citrus (Behauptung im Attachment).', 'Banana OG × Purple Punch (Behauptung im Attachment).',
     NULL, '26 % THC (Behauptung im Attachment).', NULL,
     'Im Attachment als aromatisch besonders nah beschrieben.', 'SRC-ALT-CULTIVARS', 0, NULL),
    ('CAND-FAT-BANANA', 'alternative', 'Fat Banana', 'Royal Queen Seeds',
     'Als Klassiker mit Banana-Genetik und solide beschrieben (Behauptung im Attachment).', NULL,
     NULL, NULL, NULL, 'Im Attachment als günstigste Option bewertet.', 'SRC-ALT-CULTIVARS', 0, NULL),
    ('CAND-BANANA-PURP', 'alternative', 'Banana Purp', 'Medical Seeds', NULL,
     'Banana OG × Purple Punch 2.0 (Behauptung im Attachment).', NULL, NULL, NULL, NULL,
     'SRC-ALT-CULTIVARS', 0, NULL),
    ('CAND-ORBITAL-BANANA-F1', 'alternative', 'Orbital Banana F1', 'Royal Queen Seeds',
     'Als moderner, stabiler F1-Hybrid beschrieben (Behauptung im Attachment).', NULL, NULL, NULL, NULL, NULL,
     'SRC-ALT-CULTIVARS', 0,
     'Im Attachment war kein Produktlink angegeben.');

INSERT INTO candidate_offers
    (offer_id, candidate_id, retailer, product_url, pack_size_seeds, price_claim, availability_claim,
     shipping_claim, source_id, notes)
VALUES
    ('OFFER-AAB-MRHANF-3', 'CAND-AAB-MRHANF', 'Mr. Hanf',
     'https://mr-hanf.de/samen-shop/weitere-kategorien/usa-genetik/apples-and-bananas-s1',
     3, '39,99 € (Sale; zuvor 49,99 € laut Attachment)', NULL,
     'Versandkostenfrei ab 40 € Bestellwert; Versandkosten darunter nicht angegeben.', 'SRC-ALT-AAB-RETAILERS', 'Im Attachment als günstigste Option bezeichnet.'),
    ('OFFER-AAB-MRHANF-6', 'CAND-AAB-MRHANF', 'Mr. Hanf',
     'https://mr-hanf.de/samen-shop/weitere-kategorien/usa-genetik/apples-and-bananas-s1',
     6, '89,99 €', NULL, 'Versandkostenfrei ab 40 € Bestellwert laut Attachment.', 'SRC-ALT-AAB-RETAILERS', NULL),
    ('OFFER-AAB-PEVGROW-3', 'CAND-AAB-MRHANF', 'Pevgrow', NULL, 3,
     '45,00 € (statt 60 € laut Attachment)', NULL, 'Internationaler Versand; Dauer/Kosten im Attachment nicht beziffert.', 'SRC-ALT-AAB-RETAILERS', NULL),
    ('OFFER-AAB-CANNOPTIKUM-3', 'CAND-AAB-MRHANF', 'Cannoptikum', NULL, 3, '47,35 €', NULL, NULL,
     'SRC-ALT-AAB-RETAILERS', NULL),
    ('OFFER-AAB-LINDA-3', 'CAND-AAB-MRHANF', 'Linda Seeds', NULL, 3, '51,90 €', NULL, NULL,
     'SRC-ALT-AAB-RETAILERS', NULL),
    ('OFFER-AAB-ALCHIMIA', 'CAND-AAB-MRHANF', 'Alchimia', NULL, NULL, '50–55 € aufwärts', NULL,
     'Internationaler Anbieter laut Attachment; nicht weiter aufgeschlüsselt.', 'SRC-ALT-AAB-RETAILERS', 'Packungsgröße im Attachment nicht genannt.'),
    ('OFFER-AAB-COOKIES-ZAMNESIA', 'CAND-AAB-COOKIES', 'Zamnesia', NULL, NULL, NULL,
     'Laut Attachment Apples & Bananas von Cookies erhältlich; anderer Breeder als Elev8.', NULL,
     'SRC-ALT-AAB-RETAILERS', 'Preis/Packungsgröße nicht genannt.'),
    ('OFFER-BRAWLER-3', 'CAND-BANANA-BRAWLER', 'Mr. Hanf',
     'https://mr-hanf.de/samen-shop/feminisierte-samen/banana-brawler', 3, '23,20 €',
     'Lieferbar nach Deutschland laut Attachment.', 'Versandkostenfrei ab 40 € Bestellwert laut Attachment.',
     'SRC-ALT-CULTIVARS', NULL),
    ('OFFER-BRAWLER-5', 'CAND-BANANA-BRAWLER', 'Mr. Hanf',
     'https://mr-hanf.de/samen-shop/feminisierte-samen/banana-brawler', 5, '35,20 €',
     'Lieferbar nach Deutschland laut Attachment.', 'Versandkostenfrei ab 40 € Bestellwert laut Attachment.',
     'SRC-ALT-CULTIVARS', NULL),
    ('OFFER-PUNCH-3', 'CAND-BANANA-PUNCH', 'Mr. Hanf',
     'https://mr-hanf.de/samen-shop/sortenvielfalt/banana-punch-barneys-farm', 3, '31,15 €',
     'Lieferbar nach Deutschland laut Attachment.', 'Versandkostenfrei ab 40 € Bestellwert laut Attachment.',
     'SRC-ALT-CULTIVARS', NULL),
    ('OFFER-PUNCH-5', 'CAND-BANANA-PUNCH', 'Mr. Hanf',
     'https://mr-hanf.de/samen-shop/sortenvielfalt/banana-punch-barneys-farm', 5, '44,26 €',
     'Lieferbar nach Deutschland laut Attachment.', 'Versandkostenfrei ab 40 € Bestellwert laut Attachment.',
     'SRC-ALT-CULTIVARS', NULL),
    ('OFFER-FAT-BANANA-3', 'CAND-FAT-BANANA', 'Mr. Hanf',
     'https://mr-hanf.de/samen-shop/sortenvielfalt/thc-reiche-sorten/fat-banana', 3, '20,00 €',
     'Lieferbar nach Deutschland laut Attachment.', 'Versandkostenfrei ab 40 € Bestellwert laut Attachment.',
     'SRC-ALT-CULTIVARS', NULL),
    ('OFFER-FAT-BANANA-5', 'CAND-FAT-BANANA', 'Mr. Hanf',
     'https://mr-hanf.de/samen-shop/sortenvielfalt/thc-reiche-sorten/fat-banana', 5, '30,00 €',
     'Lieferbar nach Deutschland laut Attachment.', 'Versandkostenfrei ab 40 € Bestellwert laut Attachment.',
     'SRC-ALT-CULTIVARS', NULL),
    ('OFFER-BANANA-PURP-3', 'CAND-BANANA-PURP', 'Mr. Hanf',
     'https://mr-hanf.de/samen-shop/weitere-kategorien/medizinische-samen/banana-purp', 3, '22,99 €',
     'Lieferbar nach Deutschland laut Attachment.', 'Versandkostenfrei ab 40 € Bestellwert laut Attachment.',
     'SRC-ALT-CULTIVARS', NULL),
    ('OFFER-ORBITAL-BANANA-F1-3', 'CAND-ORBITAL-BANANA-F1', 'Mr. Hanf', NULL, 3, '30,40 €',
     'Lieferbar nach Deutschland laut Attachment.', 'Versandkostenfrei ab 40 € Bestellwert laut Attachment.',
     'SRC-ALT-CULTIVARS', 'Im Attachment ohne Produktlink.');

INSERT OR IGNORE INTO seed_research_candidates
    (candidate_id, candidate_role, product_name, breeder_as_reported, profile_claims, genetics_claim,
     seed_type_claim, thc_claim, flowering_time_claim, recommendation_claim, source_id, verified, notes)
VALUES
    ('CAND-LINDA-AB-KANNABIA', 'alternative', 'Apple and Bananas', 'Kannabia Seeds',
     'Fresh/tart apple and ripe/sweet banana; creamy and lightly spicy finish (Linda listing claim).',
     'Platinum Cookies × Grandaddy Purple × Blue Power × Gelatti (Linda listing claim).',
     'feminized, photoperiod (Linda listing)', 'up to 27% (Linda listing claim)', '65–70 days (Linda listing claim)',
     'Closest apparent match by name plus listed apple/banana profile and reported parent names; distinct breeder, so not a verified equivalent to Elev8 stock.',
     'SRC-LINDA-AB-KANNABIA', 1, 'Linda Seeds product page checked 2026-09-25; stock status not separately confirmed.'),
    ('CAND-LINDA-AB-00SEEDS', 'alternative', 'Apple Bananas', '00 Seeds Bank',
     'Earthy base with apple, banana and light berry notes (Linda listing claim).',
     'Platinum Cookies, GDP, Bluepower and Gelati (Linda listing claim; spelling preserved).',
     'feminized (Linda listing)', '25% (Linda listing claim)', '8–9 weeks (Linda listing claim)',
     'Very close apparent match by product name, listed parent names and apple/banana profile; distinct breeder, so not a verified equivalent to Elev8 stock.',
     'SRC-LINDA-AB-00SEEDS', 1, 'Linda Seeds product page checked 2026-09-25; stock status not separately confirmed.'),
    ('CAND-LINDA-APPLE-FRITTER-ELEV8', 'alternative', 'Apple Fritter', 'Elev8 Seeds',
     'Sweet apple-pastry profile with earthy and vanilla notes (Linda listing claim).',
     'Sour Apple × Animal Cookies (Linda listing claim).',
     'feminized (Linda listing)', '32% (Linda listing claim)', '8 weeks (Linda listing claim)',
     'Secondary option if staying with Elev8 and prioritizing apple/cookie sweetness; it is not a banana-profile substitute.',
     'SRC-LINDA-APPLE-FRITTER-ELEV8', 1, 'Linda Seeds product page checked 2026-09-25; stock status not separately confirmed.'),
    ('CAND-LINDA-BANANA-PUNCH', 'alternative', 'Banana Punch', 'Linda Seeds',
     'Ripe banana with a light pineapple note (Linda listing claim).',
     'Banana OG × Purple Punch (Linda listing claim).',
     'feminized, photoperiod (Linda listing)', '23–25% (Linda listing claim)', '8–10 weeks (Linda listing claim)',
     'Lower-similarity option if banana aroma is the priority; listed genetics/profile otherwise differ from the target.',
     'SRC-LINDA-BANANA-PUNCH', 1, 'Separate from Banana Punch listings by other breeders. Linda Seeds product page checked 2026-09-25; stock status not separately confirmed.');

INSERT OR IGNORE INTO candidate_offers
    (offer_id, candidate_id, retailer, product_url, pack_size_seeds, price_claim, availability_claim,
     shipping_claim, source_id, notes)
VALUES
    ('OFFER-AAB-MRHANF-3-LIVE', 'CAND-AAB-MRHANF', 'Mr. Hanf',
     'https://mr-hanf.de/samen-shop/weitere-kategorien/usa-genetik/apples-and-bananas-s1',
     3, '39,99 € Sale (49,99 € list price; live page on 2026-09-25)',
     '3-seed option marked in stock on the page when checked.', NULL, 'SRC-MRHANF-ELEV8-AB', NULL),
    ('OFFER-AAB-MRHANF-6-LIVE', 'CAND-AAB-MRHANF', 'Mr. Hanf',
     'https://mr-hanf.de/samen-shop/weitere-kategorien/usa-genetik/apples-and-bananas-s1',
     6, '89,99 € (live page on 2026-09-25)',
     '6-seed option marked orderable on the page when checked.', NULL, 'SRC-MRHANF-ELEV8-AB', NULL),
    ('OFFER-LINDA-AB-KANNABIA', 'CAND-LINDA-AB-KANNABIA', 'Linda Seeds',
     'https://www.linda-seeds.com/en/buy-feminized-marijuana-seeds/hybrid/extremely-high-content-of-thc/large-yield/apple-and-bananas-kannabia-seeds',
     NULL, '4,25 € angezeigt (zuvor 8,50 €); Packungsgröße im extrahierten Text nicht erkennbar.',
     'Produktseite erreichbar; Lagerstatus nicht separat bestätigt.', 'zzgl. Versand laut Seite.', 'SRC-LINDA-AB-KANNABIA', NULL),
    ('OFFER-LINDA-AB-00SEEDS', 'CAND-LINDA-AB-00SEEDS', 'Linda Seeds',
     'https://www.linda-seeds.com/en/buy-feminized-marijuana-seeds/hybrid/extremely-high-content-of-thc/large-yield/apple-bananas-00-seeds-bank',
     NULL, NULL, 'Produktseite erreichbar; Lagerstatus nicht separat bestätigt.', NULL,
     'SRC-LINDA-AB-00SEEDS', 'Im extrahierten Seitentext war kein Preis sichtbar.'),
    ('OFFER-LINDA-BANANA-BRAWLER', 'CAND-BANANA-BRAWLER', 'Linda Seeds',
     'https://www.linda-seeds.com/en/buy-feminized-marijuana-seeds/hybrid/extremely-high-content-of-thc/large-yield/banana-brawler-royal-queen-seeds',
     NULL, NULL, 'Produktseite erreichbar; Lagerstatus nicht separat bestätigt.', NULL,
     'SRC-LINDA-BANANA-BRAWLER', 'Linda listet Gelatti × Blue Power, Banane/Würze/erdig-waldige Noten, ca. 24% THC und 8–10 Wochen. Der frühere Anhang nannte 8–9 Wochen; Abweichung erhalten.'),
    ('OFFER-LINDA-APPLE-FRITTER', 'CAND-LINDA-APPLE-FRITTER-ELEV8', 'Linda Seeds',
     'https://www.linda-seeds.com/en/buy-feminized-marijuana-seeds/hybrid/extremely-high-content-of-thc/large-yield/apple-fritter-elev8-seeds',
     NULL, NULL, 'Produktseite erreichbar; Lagerstatus nicht separat bestätigt.', NULL,
     'SRC-LINDA-APPLE-FRITTER-ELEV8', NULL),
    ('OFFER-LINDA-BANANA-PUNCH', 'CAND-LINDA-BANANA-PUNCH', 'Linda Seeds',
     'https://www.linda-seeds.com/en/buy-feminized-marijuana-seeds/hybrid/extremely-high-content-of-thc/large-yield/banana-punch-linda-seeds',
     NULL, '3,50 € angezeigt; Packungsgröße im extrahierten Text nicht erkennbar.',
     'Produktseite erreichbar; Lagerstatus nicht separat bestätigt.', 'zzgl. Versand laut Seite.',
     'SRC-LINDA-BANANA-PUNCH', NULL),
    ('OFFER-LINDA-ELEV8-AB-LIVE', 'CAND-AAB-MRHANF', 'Linda Seeds',
     'https://www.linda-seeds.com/en/buy-feminized-marijuana-seeds/sativa/extremely-high-content-of-thc/large-yield/apples-and-bananas-elev8-seeds',
     NULL, '51,90 € (inkl. MwSt., exkl. Versand; Seite geprüft 2026-09-25)',
     'Produktseite erreichbar; Seitentitel sagt „order here“, expliziter Lagerbestand nicht bestätigt.',
     'Versandkosten laut Seite zusätzlich; Betrag nicht übernommen.', 'SRC-LINDA-ELEV8-AB',
     'Linda nennt Elev8 Seeds — Apples and Bananas, ohne S1-Zusatz; Packungsgröße nicht erkennbar. Nicht als identische S1-Packungsvariante belegt.');

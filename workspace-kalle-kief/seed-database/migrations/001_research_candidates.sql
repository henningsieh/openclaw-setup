PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS seed_research_candidates (
    candidate_id       TEXT PRIMARY KEY,
    candidate_role     TEXT NOT NULL CHECK (candidate_role IN (
        'target_listing', 'alternative', 'same_name_other_breeder'
    )),
    product_name       TEXT NOT NULL,
    breeder_as_reported TEXT,
    profile_claims     TEXT,
    genetics_claim     TEXT,
    seed_type_claim    TEXT,
    thc_claim          TEXT,
    flowering_time_claim TEXT,
    recommendation_claim TEXT,
    source_id          TEXT NOT NULL REFERENCES source_catalog(source_id),
    verified           INTEGER NOT NULL DEFAULT 0 CHECK (verified IN (0, 1)),
    notes              TEXT
);

CREATE TABLE IF NOT EXISTS candidate_offers (
    offer_id           TEXT PRIMARY KEY,
    candidate_id       TEXT NOT NULL REFERENCES seed_research_candidates(candidate_id),
    retailer           TEXT NOT NULL,
    product_url        TEXT,
    pack_size_seeds    INTEGER CHECK (pack_size_seeds IS NULL OR pack_size_seeds > 0),
    price_claim        TEXT,
    availability_claim TEXT,
    shipping_claim     TEXT,
    source_id          TEXT NOT NULL REFERENCES source_catalog(source_id),
    notes              TEXT
);

CREATE INDEX IF NOT EXISTS idx_candidates_role ON seed_research_candidates(candidate_role);
CREATE INDEX IF NOT EXISTS idx_candidate_offers_candidate ON candidate_offers(candidate_id);

INSERT OR IGNORE INTO source_catalog
    (source_id, source_kind, title, uri, accessed_on, used_for_values, limitations)
VALUES
    ('SRC-ALT-AAB-RETAILERS', 'other', 'User-provided pasted comparison: Apples and Bananas retailers',
     'media://inbound/pasted-text-1790315562108---b9498418-70f3-49a0-a830-4d8ad62a5107.txt', '2026-09-25', 1,
     'Prices, shipping, availability, tax, pack size and product identity are transcribed as claims from the attachment; not independently checked.'),
    ('SRC-ALT-CULTIVARS', 'other', 'User-provided pasted comparison: banana cultivar alternatives',
     'media://inbound/pasted-text-1790315596879---7416c5e9-6ca0-4653-9316-021159fd128c.txt', '2026-09-25', 1,
     'Product traits, prices, availability and similarity/recommendation language are transcribed as claims from the attachment; not independently checked.');

INSERT OR IGNORE INTO seed_research_candidates
    (candidate_id, candidate_role, product_name, breeder_as_reported, profile_claims, genetics_claim,
     seed_type_claim, thc_claim, flowering_time_claim, recommendation_claim, source_id, verified, notes)
VALUES
    ('CAND-AAB-MRHANF', 'target_listing', 'Apples and Bananas S1', NULL, NULL, NULL,
     'S1 feminisiert', NULL, NULL, NULL, 'SRC-ALT-AAB-RETAILERS', 0,
     'Preis-/Shopvergleich für das gesuchte Original; Breeder im Attachment nicht ausdrücklich genannt. Nicht ohne Prüfung mit dem bereits erfassten Elev8-Eintrag zusammenführen.'),
    ('CAND-AAB-COOKIES', 'same_name_other_breeder', 'Apples & Bananas', 'Cookies', NULL, NULL,
     NULL, NULL, NULL, NULL, 'SRC-ALT-AAB-RETAILERS', 0,
     'Laut Attachment hat Zamnesia nur diese Variante eines anderen Breeders; daher nicht als Elev8-Genetikgleichheit behandeln.'),
    ('CAND-BANANA-BRAWLER', 'alternative', 'Banana Brawler', 'Royal Queen Seeds',
     'Süß, cremig, tropische Banane mit gassy/erdigem Unterton (Behauptung im Attachment).', NULL,
     NULL, '24 % THC (Behauptung im Attachment).', '8–9 Wochen Blüte (Behauptung im Attachment).',
     'Im Attachment als Top-Empfehlung und A&B-ähnlicher Vibe bewertet.', 'SRC-ALT-CULTIVARS', 0, NULL),
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

INSERT OR IGNORE INTO candidate_offers
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

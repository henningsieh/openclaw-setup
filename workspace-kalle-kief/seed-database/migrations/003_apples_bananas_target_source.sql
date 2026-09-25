PRAGMA foreign_keys = ON;

INSERT OR IGNORE INTO source_catalog
    (source_id, source_kind, title, uri, accessed_on, used_for_values, limitations)
VALUES
    ('SRC-MRHANF-ELEV8-AB', 'other', 'Mr. Hanf product listing: Apples and Bananas S1 — Elev8 Seeds',
     'https://mr-hanf.de/samen-shop/weitere-kategorien/usa-genetik/apples-and-bananas-s1',
     '2026-09-25', 1, 'Retailer product page fetched successfully; it identifies the breeder as Elev8 Seeds and gives the listed lineages/profile. Treat as retailer-reported product data, not direct breeder confirmation.');

UPDATE seed_research_candidates
SET breeder_as_reported = 'Elev8 Seeds',
    profile_claims = 'Frisch/fruchtig: Apfel und Banane, erdig/würzig; cremig-würziger Abgang (Mr. Hanf listing claim).',
    genetics_claim = 'Platinum Cookies × Granddaddy Purple × Blue Power × Gelatti (Mr. Hanf listing claim).',
    seed_type_claim = 'S1, feminisiert, photoperiodisch (Mr. Hanf listing claim).',
    flowering_time_claim = '8–9 weeks (Mr. Hanf listing claim).',
    source_id = 'SRC-MRHANF-ELEV8-AB',
    verified = 1,
    notes = 'Mr. Hanf product page identifies breeder as Elev8 Seeds and gives the target profile. This is a retailer claim, not a direct Elev8 source.'
WHERE candidate_id = 'CAND-AAB-MRHANF';

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
     '6-seed option marked orderable on the page when checked.', NULL, 'SRC-MRHANF-ELEV8-AB', NULL);

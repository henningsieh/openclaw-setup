PRAGMA foreign_keys = ON;

UPDATE seed_research_candidates
SET profile_claims = 'Anhang: süß/cremig, tropische Banane, gassy/erdig; Linda-Seite: reife Banane, Würze, erdig-waldig (jeweils Anbieter-/Rechercheangabe).',
    genetics_claim = 'Gelatti × Blue Power (Linda-Seeds-Produktseite).',
    flowering_time_claim = 'Anhang: 8–9 Wochen; Linda-Seeds-Produktseite: 8–10 Wochen.',
    verified = 1,
    notes = 'Zusätzliche Linda-Produktseite geprüft; siehe Linda-Angebot mit eigener Quellenzuordnung. Abweichende Blütezeitangaben bleiben erhalten.'
WHERE candidate_id = 'CAND-BANANA-BRAWLER';

INSERT OR IGNORE INTO source_catalog
    (source_id, source_kind, title, uri, accessed_on, used_for_values, limitations)
VALUES
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
     '2026-09-25', 1, 'Linda Seeds product page, fetched successfully. Product characteristics are seller claims, not independent measurements.');

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
     'SRC-LINDA-BANANA-PUNCH', NULL);

PRAGMA foreign_keys = ON;

INSERT OR IGNORE INTO source_catalog
    (source_id, source_kind, title, uri, accessed_on, used_for_values, limitations)
VALUES
    ('SRC-LINDA-ELEV8-AB', 'other', 'Linda Seeds product listing: Apples and Bananas — Elev8 Seeds',
     'https://www.linda-seeds.com/en/buy-feminized-marijuana-seeds/sativa/extremely-high-content-of-thc/large-yield/apples-and-bananas-elev8-seeds',
     '2026-09-25', 1, 'Linda retailer page fetched successfully (HTTP 200). Product/genetics claims are retailer claims; the readable page did not establish pack size or explicit stock status.');

INSERT OR IGNORE INTO candidate_offers
    (offer_id, candidate_id, retailer, product_url, pack_size_seeds, price_claim, availability_claim,
     shipping_claim, source_id, notes)
VALUES
    ('OFFER-LINDA-ELEV8-AB-LIVE', 'CAND-AAB-MRHANF', 'Linda Seeds',
     'https://www.linda-seeds.com/en/buy-feminized-marijuana-seeds/sativa/extremely-high-content-of-thc/large-yield/apples-and-bananas-elev8-seeds',
     NULL, '51,90 € (inkl. MwSt., exkl. Versand; Seite geprüft 2026-09-25)',
     'Produktseite erreichbar; Seitentitel sagt „order here“, expliziter Lagerbestand nicht bestätigt.',
     'Versandkosten laut Seite zusätzlich; Betrag nicht übernommen.', 'SRC-LINDA-ELEV8-AB',
     'Linda nennt Elev8 Seeds — Apples and Bananas, ohne S1-Zusatz; Packungsgröße nicht erkennbar. Nicht als identische S1-Packungsvariante belegt.');

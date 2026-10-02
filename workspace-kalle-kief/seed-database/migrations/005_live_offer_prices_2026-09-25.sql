PRAGMA foreign_keys = ON;
BEGIN;

INSERT OR IGNORE INTO source_catalog
    (source_id, source_kind, title, uri, accessed_on, used_for_values, limitations)
VALUES
    ('SRC-MRHANF-BRAWLER-LIVE', 'other', 'Mr. Hanf live offer: Banana Brawler — Royal Queen Seeds',
     'https://mr-hanf.de/samen-shop/feminisierte-samen/banana-brawler', '2026-09-25', 1,
     'Product page read in the rendered browser. Pack variants, displayed prices and page stock labels are retailer claims; shipping excluded.'),
    ('SRC-MRHANF-PUNCH-LIVE', 'other', 'Mr. Hanf live offer: Banana Punch — Barney’s Farm',
     'https://mr-hanf.de/samen-shop/banana-punch-barneys-farm', '2026-09-25', 1,
     'Product page read in the rendered browser. Pack variants, displayed prices and page stock labels are retailer claims; the 1-seed option was marked sold out and is excluded.'),
    ('SRC-MRHANF-PURP-LIVE', 'other', 'Mr. Hanf live offer: Banana Purp — Medical Seeds',
     'https://mr-hanf.de/samen-shop/weitere-kategorien/medizinische-samen/banana-purp', '2026-09-25', 1,
     'Product page read in the rendered browser. Pack variants, displayed prices and page stock labels are retailer claims; shipping excluded.'),
    ('SRC-MRHANF-FAT-LIVE', 'other', 'Mr. Hanf live offer: Fat Banana — Royal Queen Seeds',
     'https://mr-hanf.de/samen-shop/sortenvielfalt/thc-reiche-sorten/fat-banana', '2026-09-25', 1,
     'Product page read in the rendered browser. Pack variants, displayed prices and page stock labels are retailer claims; shipping excluded.'),
    ('SRC-MRHANF-ORBITAL-LIVE', 'other', 'Mr. Hanf live offer: Orbital Banana F1 — Royal Queen Seeds',
     'https://mr-hanf.de/en/seed-shop/variety-diversity/f1-cannabis-varieties/orbital-banana-f1', '2026-09-25', 1,
     'English product page read in the rendered browser. Pack variants, displayed prices and page stock labels are retailer claims; shipping excluded.'),
    ('SRC-LINDA-KANNABIA-LIVE', 'other', 'Linda Seeds live offer: Apple and Bananas — Kannabia Seeds',
     'https://www.linda-seeds.com/en/buy-feminized-marijuana-seeds/hybrid/extremely-high-content-of-thc/large-yield/apple-and-bananas-kannabia-seeds', '2026-09-25', 1,
     'Rendered product page showed the selected one-seed option at 4.25 EUR, reduced from 8.50 EUR; retailer claim, shipping excluded.'),
    ('SRC-LINDA-00SEEDS-LIVE', 'other', 'Linda Seeds live offer: Apple Bananas — 00 Seeds Bank',
     'https://www.linda-seeds.com/en/buy-feminized-marijuana-seeds/hybrid/extremely-high-content-of-thc/large-yield/apple-bananas-00-seeds-bank', '2026-09-25', 1,
     'Rendered product page showed the selected one-seed option at 5.50 EUR; retailer claim, shipping excluded.'),
    ('SRC-LINDA-BANANA-PUNCH-LIVE', 'other', 'Linda Seeds live offer: Banana Punch — Linda Seeds',
     'https://www.linda-seeds.com/en/buy-feminized-marijuana-seeds/hybrid/extremely-high-content-of-thc/large-yield/banana-punch-linda-seeds', '2026-09-25', 1,
     'Rendered product page showed the selected one-seed option at 3.50 EUR; retailer claim, shipping excluded.'),
    ('SRC-LINDA-ELEV8-AB', 'other', 'Linda Seeds product listing: Apples and Bananas — Elev8 Seeds',
     'https://www.linda-seeds.com/en/buy-feminized-marijuana-seeds/sativa/extremely-high-content-of-thc/large-yield/apples-and-bananas-elev8-seeds', '2026-09-25', 1,
     'Rendered product page showed the selected 3-seed option at 51.90 EUR and a 6-seed option; no separate 6-seed price was displayed in the captured page text. Retailer claim, shipping excluded; listing omits S1 so exact pack identity to the Mr. Hanf S1 listing is not established.'),
    ('SRC-LINDA-APPLE-FRITTER-ELEV8', 'other', 'Linda Seeds product listing: Apple Fritter — Elev8 Seeds',
     'https://www.linda-seeds.com/en/buy-feminized-marijuana-seeds/hybrid/extremely-high-content-of-thc/large-yield/apple-fritter-elev8-seeds', '2026-09-25', 0,
     'Rendered page showed a from-price of 49.50 EUR but explicitly stated the item is currently unavailable. No current purchasable offer entered.');

UPDATE source_catalog SET accessed_on='2026-09-25', used_for_values=1,
    limitations='Rendered product page showed the selected 3-seed option at 51.90 EUR and a 6-seed option; no separate 6-seed price was visible in the captured page text. Retailer claim, shipping excluded; listing omits S1 so exact pack identity to Mr. Hanf listing is not established.'
WHERE source_id='SRC-LINDA-ELEV8-AB';
UPDATE source_catalog SET accessed_on='2026-09-25', used_for_values=0,
    limitations='Rendered page showed a from-price of 49.50 EUR but explicitly stated the item is currently unavailable. No current purchasable offer entered.'
WHERE source_id='SRC-LINDA-APPLE-FRITTER-ELEV8';

UPDATE source_catalog SET accessed_on='2026-09-25', used_for_values=1,
    limitations='Product page read in the rendered browser on 2026-09-25. The page showed the selected 3-seed option at 39.99 EUR (sale) and the 6-seed option at 89.99 EUR; retailer claims, shipping excluded.'
WHERE source_id='SRC-MRHANF-ELEV8-AB';

UPDATE candidate_offers SET pack_size_seeds=3,
    price_claim='51,90 € (3 Samen; Live-Produktseite, 2026-09-25)',
    product_url='https://www.linda-seeds.com/en/buy-feminized-marijuana-seeds/sativa/extremely-high-content-of-thc/large-yield/apples-and-bananas-elev8-seeds',
    availability_claim='3er-Variante vorausgewählt; Produktseite bietet „Add to Cart“; Bestandsstatus nicht separat geprüft.',
    source_id='SRC-LINDA-ELEV8-AB',
    notes='Browser-Livecheck 2026-09-25: angezeigter Preis gehört zur vorausgewählten 3er-Variante. Die 6er-Variante wurde gelistet, aber ihr Preis war im ausgelesenen Zustand nicht separat sichtbar.'
WHERE offer_id='OFFER-LINDA-ELEV8-AB-LIVE';

UPDATE candidate_offers SET pack_size_seeds=1,
    price_claim='3,50 € (1 Samen; Live-Produktseite, 2026-09-25)',
    availability_claim='1er-Variante vorausgewählt; Produktseite bietet „Add to Cart“; Bestandsstatus nicht separat geprüft.',
    source_id='SRC-LINDA-BANANA-PUNCH-LIVE',
    notes='Browser-Livecheck 2026-09-25; der angezeigte Preis gehört zur vorausgewählten 1er-Variante.'
WHERE offer_id='OFFER-LINDA-BANANA-PUNCH';

INSERT OR IGNORE INTO candidate_offers
    (offer_id,candidate_id,retailer,product_url,pack_size_seeds,price_claim,availability_claim,shipping_claim,source_id,notes)
VALUES
    ('OFFER-LINDA-KANNABIA-1-LIVE','CAND-LINDA-AB-KANNABIA','Linda Seeds',
     'https://www.linda-seeds.com/en/buy-feminized-marijuana-seeds/hybrid/extremely-high-content-of-thc/large-yield/apple-and-bananas-kannabia-seeds',1,
     '4,25 € (Sale; 1 feminisierter Samen; Live-Produktseite, 2026-09-25)',
     '1er-Variante vorausgewählt; Produktseite bietet „Add to Cart“; Bestandsstatus nicht separat geprüft.',
     'zzgl. Versand laut Seite.','SRC-LINDA-KANNABIA-LIVE','Preis gilt für die vorausgewählte 1er-Variante.'),
    ('OFFER-LINDA-00SEEDS-1-LIVE','CAND-LINDA-AB-00SEEDS','Linda Seeds',
     'https://www.linda-seeds.com/en/buy-feminized-marijuana-seeds/hybrid/extremely-high-content-of-thc/large-yield/apple-bananas-00-seeds-bank',1,
     '5,50 € (1 feminisierter Samen; Live-Produktseite, 2026-09-25)',
     '1er-Variante vorausgewählt; Produktseite bietet „Add to Cart“; Bestandsstatus nicht separat geprüft.',
     'zzgl. Versand laut Seite.','SRC-LINDA-00SEEDS-LIVE','Preis gilt für die vorausgewählte 1er-Variante.'),
    ('OFFER-BRAWLER-1-LIVE','CAND-BANANA-BRAWLER','Mr. Hanf','https://mr-hanf.de/samen-shop/feminisierte-samen/banana-brawler',1,'12,00 €','Bestellbereit laut Produktseite.',NULL,'SRC-MRHANF-BRAWLER-LIVE','Live-Preis und Packungsgröße direkt auf Produktseite geprüft am 2026-09-25.'),
    ('OFFER-BRAWLER-3-LIVE','CAND-BANANA-BRAWLER','Mr. Hanf','https://mr-hanf.de/samen-shop/feminisierte-samen/banana-brawler',3,'29,00 €','Bestellbereit laut Produktseite.',NULL,'SRC-MRHANF-BRAWLER-LIVE','Live-Preis und Packungsgröße direkt auf Produktseite geprüft am 2026-09-25.'),
    ('OFFER-BRAWLER-5-LIVE','CAND-BANANA-BRAWLER','Mr. Hanf','https://mr-hanf.de/samen-shop/feminisierte-samen/banana-brawler',5,'44,00 €','Bestellbereit laut Produktseite.',NULL,'SRC-MRHANF-BRAWLER-LIVE','Live-Preis und Packungsgröße direkt auf Produktseite geprüft am 2026-09-25.'),
    ('OFFER-BRAWLER-10-LIVE','CAND-BANANA-BRAWLER','Mr. Hanf','https://mr-hanf.de/samen-shop/feminisierte-samen/banana-brawler',10,'80,00 €','Bestellbereit laut Produktseite.',NULL,'SRC-MRHANF-BRAWLER-LIVE','Live-Preis und Packungsgröße direkt auf Produktseite geprüft am 2026-09-25.'),
    ('OFFER-PUNCH-3-LIVE','CAND-BANANA-PUNCH','Mr. Hanf','https://mr-hanf.de/samen-shop/banana-punch-barneys-farm',3,'31,15 €','Bestellbereit laut Produktseite.',NULL,'SRC-MRHANF-PUNCH-LIVE','Live-Preis und Packungsgröße direkt auf Produktseite geprüft am 2026-09-25.'),
    ('OFFER-PUNCH-5-LIVE','CAND-BANANA-PUNCH','Mr. Hanf','https://mr-hanf.de/samen-shop/banana-punch-barneys-farm',5,'44,26 €','Auf Lager laut Produktseite.',NULL,'SRC-MRHANF-PUNCH-LIVE','Live-Preis und Packungsgröße direkt auf Produktseite geprüft am 2026-09-25.'),
    ('OFFER-PUNCH-10-LIVE','CAND-BANANA-PUNCH','Mr. Hanf','https://mr-hanf.de/samen-shop/banana-punch-barneys-farm',10,'76,50 €','Bestellbereit laut Produktseite.',NULL,'SRC-MRHANF-PUNCH-LIVE','Live-Preis und Packungsgröße direkt auf Produktseite geprüft am 2026-09-25.'),
    ('OFFER-PURP-3-LIVE','CAND-BANANA-PURP','Mr. Hanf','https://mr-hanf.de/samen-shop/weitere-kategorien/medizinische-samen/banana-purp',3,'22,99 €','Bestellbereit laut Produktseite.',NULL,'SRC-MRHANF-PURP-LIVE','Live-Preis und Packungsgröße direkt auf Produktseite geprüft am 2026-09-25.'),
    ('OFFER-PURP-5-LIVE','CAND-BANANA-PURP','Mr. Hanf','https://mr-hanf.de/samen-shop/weitere-kategorien/medizinische-samen/banana-purp',5,'38,00 €','Bestellbereit laut Produktseite.',NULL,'SRC-MRHANF-PURP-LIVE','Live-Preis und Packungsgröße direkt auf Produktseite geprüft am 2026-09-25.'),
    ('OFFER-PURP-10-LIVE','CAND-BANANA-PURP','Mr. Hanf','https://mr-hanf.de/samen-shop/weitere-kategorien/medizinische-samen/banana-purp',10,'75,00 €','Bestellbereit laut Produktseite.',NULL,'SRC-MRHANF-PURP-LIVE','Live-Preis und Packungsgröße direkt auf Produktseite geprüft am 2026-09-25.'),
    ('OFFER-FAT-1-LIVE','CAND-FAT-BANANA','Mr. Hanf','https://mr-hanf.de/samen-shop/sortenvielfalt/thc-reiche-sorten/fat-banana',1,'9,50 €','Bestellbereit laut Produktseite.',NULL,'SRC-MRHANF-FAT-LIVE','Live-Preis und Packungsgröße direkt auf Produktseite geprüft am 2026-09-25.'),
    ('OFFER-FAT-3-LIVE','CAND-FAT-BANANA','Mr. Hanf','https://mr-hanf.de/samen-shop/sortenvielfalt/thc-reiche-sorten/fat-banana',3,'25,00 €','Bestellbereit laut Produktseite.',NULL,'SRC-MRHANF-FAT-LIVE','Live-Preis und Packungsgröße direkt auf Produktseite geprüft am 2026-09-25.'),
    ('OFFER-FAT-5-LIVE','CAND-FAT-BANANA','Mr. Hanf','https://mr-hanf.de/samen-shop/sortenvielfalt/thc-reiche-sorten/fat-banana',5,'37,50 €','Bestellbereit laut Produktseite.',NULL,'SRC-MRHANF-FAT-LIVE','Live-Preis und Packungsgröße direkt auf Produktseite geprüft am 2026-09-25.'),
    ('OFFER-FAT-10-LIVE','CAND-FAT-BANANA','Mr. Hanf','https://mr-hanf.de/samen-shop/sortenvielfalt/thc-reiche-sorten/fat-banana',10,'70,00 €','Bestellbereit laut Produktseite.',NULL,'SRC-MRHANF-FAT-LIVE','Live-Preis und Packungsgröße direkt auf Produktseite geprüft am 2026-09-25.'),
    ('OFFER-ORBITAL-1-LIVE','CAND-ORBITAL-BANANA-F1','Mr. Hanf','https://mr-hanf.de/en/seed-shop/variety-diversity/f1-cannabis-varieties/orbital-banana-f1',1,'15,50 €','Ready to Order laut englischer Produktseite.',NULL,'SRC-MRHANF-ORBITAL-LIVE','Live-Preis und Packungsgröße direkt auf Produktseite geprüft am 2026-09-25.'),
    ('OFFER-ORBITAL-3-LIVE','CAND-ORBITAL-BANANA-F1','Mr. Hanf','https://mr-hanf.de/en/seed-shop/variety-diversity/f1-cannabis-varieties/orbital-banana-f1',3,'38,00 €','Ready to Order laut englischer Produktseite.',NULL,'SRC-MRHANF-ORBITAL-LIVE','Live-Preis und Packungsgröße direkt auf Produktseite geprüft am 2026-09-25.'),
    ('OFFER-ORBITAL-5-LIVE','CAND-ORBITAL-BANANA-F1','Mr. Hanf','https://mr-hanf.de/en/seed-shop/variety-diversity/f1-cannabis-varieties/orbital-banana-f1',5,'57,00 €','In Stock laut englischer Produktseite.',NULL,'SRC-MRHANF-ORBITAL-LIVE','Live-Preis und Packungsgröße direkt auf Produktseite geprüft am 2026-09-25.'),
    ('OFFER-ORBITAL-10-LIVE','CAND-ORBITAL-BANANA-F1','Mr. Hanf','https://mr-hanf.de/en/seed-shop/variety-diversity/f1-cannabis-varieties/orbital-banana-f1',10,'105,00 €','Ready to Order laut englischer Produktseite.',NULL,'SRC-MRHANF-ORBITAL-LIVE','Live-Preis und Packungsgröße direkt auf Produktseite geprüft am 2026-09-25.');

COMMIT;

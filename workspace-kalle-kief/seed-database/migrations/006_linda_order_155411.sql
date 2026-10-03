PRAGMA foreign_keys = ON;
BEGIN;

-- Keep incoming purchases separate from physical seed_units until receipt is confirmed.
CREATE TABLE IF NOT EXISTS purchase_orders (
    purchase_id        TEXT PRIMARY KEY,
    supplier           TEXT NOT NULL,
    supplier_order_ref TEXT NOT NULL,
    ordered_on         TEXT NOT NULL,
    payment_status     TEXT NOT NULL,
    receipt_status     TEXT NOT NULL DEFAULT 'awaiting_delivery'
        CHECK (receipt_status IN ('awaiting_delivery', 'partially_received', 'received', 'cancelled')),
    total_amount       REAL,
    currency           TEXT,
    source_id          TEXT NOT NULL REFERENCES source_catalog(source_id)
);

CREATE TABLE IF NOT EXISTS purchase_order_items (
    purchase_item_id TEXT PRIMARY KEY,
    purchase_id      TEXT NOT NULL REFERENCES purchase_orders(purchase_id),
    cultivar_id      TEXT NOT NULL REFERENCES cultivars(cultivar_id),
    quantity         INTEGER NOT NULL CHECK (quantity > 0),
    item_kind        TEXT NOT NULL CHECK (item_kind IN ('paid', 'bonus')),
    line_total       REAL,
    notes            TEXT
);

CREATE INDEX IF NOT EXISTS idx_purchase_items_order ON purchase_order_items(purchase_id);

INSERT OR IGNORE INTO source_catalog
    (source_id, source_kind, title, uri, accessed_on, used_for_values, limitations)
VALUES
    ('SRC-LINDA-ORDER-155411', 'purchase_record', 'Linda Seeds order confirmation 155411',
     'user-provided order details; no document stored', '2026-10-02', 1,
     'Entered from Henning’s pasted order confirmation. Paid/order date and listed quantities are recorded; shipment and physical receipt are not confirmed. Billing address and payment details intentionally omitted.');

INSERT OR IGNORE INTO source_catalog
    (source_id, source_kind, title, uri, accessed_on, used_for_values, limitations)
VALUES
    ('SRC-LINDA-BANANA-PUNCH-USER-LINK', 'other', 'User-supplied product link: Banana Punch — Linda Seeds',
     'https://www.linda-seeds.com/de/feminisierte-hanfsamen-kaufen/hybrid/extrem-hoher-thc-gehalt/hoher-ertrag/banana-punch-linda-seeds', NULL, 0,
     'Link supplied with the order details; not fetched in this update. No cultivar traits imported.'),
    ('SRC-LINDA-ZKITTLEZ-USER-LINK', 'other', 'User-supplied product link: Zkittlez — Linda Seeds',
     'https://www.linda-seeds.com/de/feminisierte-hanfsamen-kaufen/indica/extrem-hoher-thc-gehalt/sehr-hoher-ertrag/zkittlez-linda-seeds', NULL, 0,
     'Link supplied with the order details; not fetched in this update. No cultivar traits imported.'),
    ('SRC-KANNABIA-APPLE-BANANAS-USER-LINK', 'other', 'User-supplied product link: Apple and Bananas — Kannabia Seeds',
     'https://www.linda-seeds.com/de/feminisierte-hanfsamen-kaufen/hybrid/extrem-hoher-thc-gehalt/hoher-ertrag/apple-and-bananas-kannabia-seeds', NULL, 0,
     'Link supplied with the order details; not fetched in this update. No cultivar traits imported.');

INSERT OR IGNORE INTO cultivars
    (cultivar_id, breeder_as_recorded, cultivar_name_as_recorded, seed_presentation, notes)
VALUES
    ('CV-LINDA-BANANA-PUNCH-2026', 'Linda Seeds', 'Banana Punch', 'feminized',
     'Product identity and feminized presentation as listed on order 155411; cultivar traits are not inferred from the product link.'),
    ('CV-LINDA-ZKITTLEZ-2026', 'Linda Seeds', 'Zkittlez', 'feminized',
     'Product identity and feminized presentation as listed on order 155411; cultivar traits are not inferred from the product link.'),
    ('CV-KANNABIA-APPLE-AND-BANANAS-2026', 'Kannabia Seeds', 'Apple and Bananas', 'feminized',
     'Product identity and feminized presentation as listed on order 155411; cultivar traits are not inferred from the product link.'),
    ('CV-WOS-WILD-THAILAND-2026', 'World of Seeds', 'Wild Thailand', 'unknown',
     'Free seeds listed on order 155411; seed presentation/type not specified in the order details.');

INSERT OR IGNORE INTO purchase_orders
    (purchase_id, supplier, supplier_order_ref, ordered_on, payment_status, receipt_status,
     total_amount, currency, source_id)
VALUES
    ('PUR-LINDA-155411', 'Linda Seeds', '155411', '2026-10-02', 'paid', 'awaiting_delivery',
     52.50, 'EUR', 'SRC-LINDA-ORDER-155411');

INSERT OR IGNORE INTO purchase_order_items
    (purchase_item_id, purchase_id, cultivar_id, quantity, item_kind, line_total, notes)
VALUES
    ('PUR-LINDA-155411-BANANA-PUNCH', 'PUR-LINDA-155411', 'CV-LINDA-BANANA-PUNCH-2026', 5, 'paid', 13.50, NULL),
    ('PUR-LINDA-155411-ZKITTLEZ', 'PUR-LINDA-155411', 'CV-LINDA-ZKITTLEZ-2026', 3, 'paid', 9.50, NULL),
    ('PUR-LINDA-155411-APPLE-BANANAS-PAID', 'PUR-LINDA-155411', 'CV-KANNABIA-APPLE-AND-BANANAS-2026', 5, 'paid', 29.50, 'Bestellzeile „5 + 2“; bezahlte Menge.'),
    ('PUR-LINDA-155411-APPLE-BANANAS-BONUS', 'PUR-LINDA-155411', 'CV-KANNABIA-APPLE-AND-BANANAS-2026', 2, 'bonus', NULL, 'Gratiszugabe zur Bestellzeile „5 + 2“.'),
    ('PUR-LINDA-155411-WILD-THAILAND', 'PUR-LINDA-155411', 'CV-WOS-WILD-THAILAND-2026', 3, 'bonus', NULL, 'Gratis Samen; Menge laut Bestellbestätigung.');

COMMIT;

PRAGMA foreign_keys = ON;
BEGIN;

ALTER TABLE seed_units ADD COLUMN purchase_item_id TEXT REFERENCES purchase_order_items(purchase_item_id);

INSERT OR IGNORE INTO source_catalog
    (source_id, source_kind, title, uri, accessed_on, used_for_values, limitations)
VALUES
    ('SRC-LINDA-ORDER-145873', 'purchase_record', 'Linda Seeds order confirmation 145873',
     'user-provided order details; no document stored', '2026-03-14', 1,
     'Entered from Henning’s pasted order confirmation and clarification. The three auto products (18 seeds total) were for a friend and are excluded from Henning’s inventory. Billing address and payment details intentionally omitted.');

INSERT OR IGNORE INTO cultivars
    (cultivar_id, breeder_as_recorded, cultivar_name_as_recorded, seed_presentation, notes)
VALUES
    ('CV-LINDA-AUTO-FAT-BLUEBERRY-2026', 'Linda Seeds', 'Auto Fat Blueberry', 'feminized', 'Order 145873; for a friend, not Henning’s inventory.'),
    ('CV-LINDA-AUTO-WHITE-WIDOW-2026', 'Linda Seeds', 'Auto White Widow', 'feminized', 'Order 145873; for a friend, not Henning’s inventory.'),
    ('CV-LINDA-STRAWBERRY-HAZE-AUTO-2026', 'Linda Seeds', 'Strawberry Haze Auto', 'feminized', 'Order 145873; for a friend, not Henning’s inventory.'),
    ('CV-LINDA-WHITE-WIDOW-2026', 'Linda Seeds', 'White Widow', 'feminized', 'Order 145873; seed characteristics beyond the listed presentation are not inferred.'),
    ('CV-BARNEYS-TROPICANNA-BANANA-2026', 'Barney’s Farm', 'Tropicanna Banana', 'unknown', 'Free seed listed on order 145873; presentation/type not specified in the order details.');

INSERT OR IGNORE INTO purchase_orders
    (purchase_id, supplier, supplier_order_ref, ordered_on, payment_status, receipt_status,
     total_amount, currency, source_id)
VALUES
    ('PUR-LINDA-145873', 'Linda Seeds', '145873', '2026-03-14', 'paid', 'received',
     82.50, 'EUR', 'SRC-LINDA-ORDER-145873');

INSERT OR IGNORE INTO purchase_order_items
    (purchase_item_id, purchase_id, cultivar_id, quantity, item_kind, line_total, notes)
VALUES
    ('PUR-LINDA-145873-AUTO-FAT-BLUEBERRY', 'PUR-LINDA-145873', 'CV-LINDA-AUTO-FAT-BLUEBERRY-2026', 3, 'paid', 8.50, 'Für einen Freund; nicht Teil von Henning’s Bestand.'),
    ('PUR-LINDA-145873-AUTO-WHITE-WIDOW', 'PUR-LINDA-145873', 'CV-LINDA-AUTO-WHITE-WIDOW-2026', 5, 'paid', 12.50, 'Für einen Freund; nicht Teil von Henning’s Bestand.'),
    ('PUR-LINDA-145873-STRAWBERRY-HAZE-AUTO', 'PUR-LINDA-145873', 'CV-LINDA-STRAWBERRY-HAZE-AUTO-2026', 10, 'paid', 25.50, 'Für einen Freund; nicht Teil von Henning’s Bestand.'),
    ('PUR-LINDA-145873-GORILLA-ZKITTLEZ', 'PUR-LINDA-145873', 'CV-LINDA-GORILLA-ZKITTLEZ', 10, 'paid', 23.50, NULL),
    ('PUR-LINDA-145873-WHITE-WIDOW', 'PUR-LINDA-145873', 'CV-LINDA-WHITE-WIDOW-2026', 5, 'paid', 12.50, NULL),
    ('PUR-LINDA-145873-TROPICANNA-BANANA', 'PUR-LINDA-145873', 'CV-BARNEYS-TROPICANNA-BANANA-2026', 3, 'bonus', NULL, 'Gratis Samen.'),
    ('PUR-LINDA-145873-APPLES-BANANAS-ELEV8', 'PUR-LINDA-145873', 'CV-ELEV8-APPLES-BANANAS', 2, 'bonus', NULL, 'Gratis Samen; eine Einheit ist im aktuellen Grow.' );

UPDATE seed_units
SET purchase_item_id='PUR-LINDA-145873-GORILLA-ZKITTLEZ',
    supplier='Linda Seeds', acquired_on='2026-03-14',
    notes=COALESCE(notes || ' ', '') || 'Herkunft laut Henning: Bestellung 145873.'
WHERE seed_id IN ('SEED-2026-001','SEED-2026-002');

UPDATE seed_units
SET purchase_item_id='PUR-LINDA-145873-APPLES-BANANAS-ELEV8',
    supplier='Linda Seeds', acquired_on='2026-03-14',
    notes=COALESCE(notes || ' ', '') || 'Herkunft laut Henning: Gratis-Samen aus Bestellung 145873.'
WHERE seed_id='SEED-2026-003';

INSERT OR IGNORE INTO seed_units
    (seed_id, cultivar_id, supplier, acquired_on, lifecycle_status, status_as_of, purchase_item_id, notes)
VALUES
    ('SEED-2026-004','CV-LINDA-GORILLA-ZKITTLEZ','Linda Seeds','2026-03-14','inventory','2026-10-03','PUR-LINDA-145873-GORILLA-ZKITTLEZ','Einheit aus der verbleibenden Bestellmenge; aktueller Besitz laut Bestandszuordnung.'),
    ('SEED-2026-005','CV-LINDA-GORILLA-ZKITTLEZ','Linda Seeds','2026-03-14','inventory','2026-10-03','PUR-LINDA-145873-GORILLA-ZKITTLEZ','Einheit aus der verbleibenden Bestellmenge; aktueller Besitz laut Bestandszuordnung.'),
    ('SEED-2026-006','CV-LINDA-GORILLA-ZKITTLEZ','Linda Seeds','2026-03-14','inventory','2026-10-03','PUR-LINDA-145873-GORILLA-ZKITTLEZ','Einheit aus der verbleibenden Bestellmenge; aktueller Besitz laut Bestandszuordnung.'),
    ('SEED-2026-007','CV-LINDA-GORILLA-ZKITTLEZ','Linda Seeds','2026-03-14','inventory','2026-10-03','PUR-LINDA-145873-GORILLA-ZKITTLEZ','Einheit aus der verbleibenden Bestellmenge; aktueller Besitz laut Bestandszuordnung.'),
    ('SEED-2026-008','CV-LINDA-GORILLA-ZKITTLEZ','Linda Seeds','2026-03-14','inventory','2026-10-03','PUR-LINDA-145873-GORILLA-ZKITTLEZ','Einheit aus der verbleibenden Bestellmenge; aktueller Besitz laut Bestandszuordnung.'),
    ('SEED-2026-009','CV-LINDA-GORILLA-ZKITTLEZ','Linda Seeds','2026-03-14','inventory','2026-10-03','PUR-LINDA-145873-GORILLA-ZKITTLEZ','Einheit aus der verbleibenden Bestellmenge; aktueller Besitz laut Bestandszuordnung.'),
    ('SEED-2026-010','CV-LINDA-GORILLA-ZKITTLEZ','Linda Seeds','2026-03-14','inventory','2026-10-03','PUR-LINDA-145873-GORILLA-ZKITTLEZ','Einheit aus der verbleibenden Bestellmenge; aktueller Besitz laut Bestandszuordnung.'),
    ('SEED-2026-011','CV-LINDA-GORILLA-ZKITTLEZ','Linda Seeds','2026-03-14','inventory','2026-10-03','PUR-LINDA-145873-GORILLA-ZKITTLEZ','Einheit aus der verbleibenden Bestellmenge; aktueller Besitz laut Bestandszuordnung.'),
    ('SEED-2026-012','CV-LINDA-WHITE-WIDOW-2026','Linda Seeds','2026-03-14','inventory','2026-10-03','PUR-LINDA-145873-WHITE-WIDOW','Aus der an dich gelieferten Bestellung; als Bestand erfasst.'),
    ('SEED-2026-013','CV-LINDA-WHITE-WIDOW-2026','Linda Seeds','2026-03-14','inventory','2026-10-03','PUR-LINDA-145873-WHITE-WIDOW','Aus der an dich gelieferten Bestellung; als Bestand erfasst.'),
    ('SEED-2026-014','CV-LINDA-WHITE-WIDOW-2026','Linda Seeds','2026-03-14','inventory','2026-10-03','PUR-LINDA-145873-WHITE-WIDOW','Aus der an dich gelieferten Bestellung; als Bestand erfasst.'),
    ('SEED-2026-015','CV-LINDA-WHITE-WIDOW-2026','Linda Seeds','2026-03-14','inventory','2026-10-03','PUR-LINDA-145873-WHITE-WIDOW','Aus der an dich gelieferten Bestellung; als Bestand erfasst.'),
    ('SEED-2026-016','CV-LINDA-WHITE-WIDOW-2026','Linda Seeds','2026-03-14','inventory','2026-10-03','PUR-LINDA-145873-WHITE-WIDOW','Aus der an dich gelieferten Bestellung; als Bestand erfasst.'),
    ('SEED-2026-017','CV-BARNEYS-TROPICANNA-BANANA-2026','Linda Seeds','2026-03-14','inventory','2026-10-03','PUR-LINDA-145873-TROPICANNA-BANANA','Gratis Samen aus der an dich gelieferten Bestellung; als Bestand erfasst.'),
    ('SEED-2026-018','CV-BARNEYS-TROPICANNA-BANANA-2026','Linda Seeds','2026-03-14','inventory','2026-10-03','PUR-LINDA-145873-TROPICANNA-BANANA','Gratis Samen aus der an dich gelieferten Bestellung; als Bestand erfasst.'),
    ('SEED-2026-019','CV-BARNEYS-TROPICANNA-BANANA-2026','Linda Seeds','2026-03-14','inventory','2026-10-03','PUR-LINDA-145873-TROPICANNA-BANANA','Gratis Samen aus der an dich gelieferten Bestellung; als Bestand erfasst.'),
    ('SEED-2026-020','CV-ELEV8-APPLES-BANANAS','Linda Seeds','2026-03-14','inventory','2026-10-03','PUR-LINDA-145873-APPLES-BANANAS-ELEV8','Zweite Gratis-Einheit. Nur eine der zwei bestellten Einheiten ist dem aktuellen Grow zugeordnet.');

INSERT OR IGNORE INTO field_evidence (entity_kind, entity_id, field_name, source_id, excerpt_or_note)
VALUES
    ('cultivar','CV-LINDA-GORILLA-ZKITTLEZ','cultivar_name_as_recorded','SRC-LINDA-ORDER-145873','Linda Seeds Gorilla Zkittlez.'),
    ('seed_unit','SEED-2026-001','purchase_origin','SRC-LINDA-ORDER-145873','Henning bestätigt Herkunft aus Bestellung 145873.'),
    ('seed_unit','SEED-2026-002','purchase_origin','SRC-LINDA-ORDER-145873','Henning bestätigt Herkunft aus Bestellung 145873.'),
    ('seed_unit','SEED-2026-003','purchase_origin','SRC-LINDA-ORDER-145873','Henning bestätigt Herkunft aus der Gratiszugabe Apples and Bananas — Elev8 Seeds.');

COMMIT;

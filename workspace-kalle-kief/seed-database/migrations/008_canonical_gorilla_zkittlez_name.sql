PRAGMA foreign_keys = ON;
PRAGMA defer_foreign_keys = ON;
BEGIN;

UPDATE seed_units
SET cultivar_id='CV-LINDA-GORILLA-ZKITTLEZ'
WHERE cultivar_id='CV-LINDA-GORILLA-SKITTLEZ';

UPDATE purchase_order_items
SET cultivar_id='CV-LINDA-GORILLA-ZKITTLEZ'
WHERE cultivar_id='CV-LINDA-GORILLA-SKITTLEZ';

UPDATE field_evidence
SET entity_id='CV-LINDA-GORILLA-ZKITTLEZ'
WHERE entity_kind='cultivar' AND entity_id='CV-LINDA-GORILLA-SKITTLEZ';

UPDATE cultivars
SET cultivar_id='CV-LINDA-GORILLA-ZKITTLEZ',
    cultivar_name_as_recorded='Gorilla Zkittlez',
    notes='Product name recorded for the current grow; cultivar traits remain blank until supported by a product source.'
WHERE cultivar_id='CV-LINDA-GORILLA-SKITTLEZ';

UPDATE field_evidence
SET excerpt_or_note=replace(excerpt_or_note, 'Gorilla Skittlez', 'Gorilla Zkittlez');
UPDATE seed_units
SET notes=replace(notes, 'Gorilla Skittlez', 'Gorilla Zkittlez');
UPDATE grow_runs
SET notes=replace(notes, 'Gorilla Skittlez', 'Gorilla Zkittlez');
UPDATE source_catalog
SET title=replace(title, 'Gorilla Skittlez', 'Gorilla Zkittlez'),
    limitations=replace(limitations, 'Gorilla Skittlez', 'Gorilla Zkittlez');
UPDATE purchase_order_items
SET notes=replace(notes, 'Gorilla Skittlez', 'Gorilla Zkittlez');

COMMIT;

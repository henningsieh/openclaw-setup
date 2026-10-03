PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS source_catalog (
    source_id       TEXT PRIMARY KEY,
    source_kind     TEXT NOT NULL CHECK (source_kind IN (
        'grow_reference', 'seed_packet', 'purchase_record', 'breeder_catalog', 'grow_log', 'other'
    )),
    title           TEXT NOT NULL,
    uri             TEXT NOT NULL,
    accessed_on     TEXT,
    used_for_values INTEGER NOT NULL DEFAULT 0 CHECK (used_for_values IN (0, 1)),
    limitations     TEXT
);

CREATE TABLE IF NOT EXISTS grow_runs (
    grow_id          TEXT PRIMARY KEY,
    label            TEXT NOT NULL,
    flowering_started_on TEXT,
    notes            TEXT,
    source_id        TEXT REFERENCES source_catalog(source_id)
);

CREATE TABLE IF NOT EXISTS cultivars (
    cultivar_id              TEXT PRIMARY KEY,
    breeder_as_recorded      TEXT NOT NULL,
    cultivar_name_as_recorded TEXT NOT NULL,
    standardized_name        TEXT,
    genetics                 TEXT,
    seed_presentation        TEXT CHECK (seed_presentation IN ('feminized', 'regular', 'unknown')),
    flowering_type           TEXT CHECK (flowering_type IN ('photoperiod', 'autoflower', 'unknown')),
    breeder_claimed_flowering_time TEXT,
    breeder_claimed_yield     TEXT,
    breeder_claimed_thc       TEXT,
    breeder_claimed_cbd       TEXT,
    notes                    TEXT
);

CREATE TABLE IF NOT EXISTS seed_units (
    seed_id          TEXT PRIMARY KEY,
    cultivar_id      TEXT NOT NULL REFERENCES cultivars(cultivar_id),
    purchase_item_id TEXT REFERENCES purchase_order_items(purchase_item_id),
    grow_id          TEXT REFERENCES grow_runs(grow_id),
    plant_label      TEXT,
    supplier         TEXT,
    acquired_on      TEXT,
    lot_code         TEXT,
    sown_on          TEXT,
    germinated_on    TEXT,
    germination_result TEXT CHECK (germination_result IN ('germinated', 'failed', 'unknown')),
    lifecycle_status TEXT NOT NULL DEFAULT 'unknown' CHECK (lifecycle_status IN (
        'inventory', 'planted', 'germinated', 'vegetative', 'flowering', 'harvested', 'failed', 'unknown'
    )),
    status_as_of     TEXT,
    storage_notes    TEXT,
    notes            TEXT
);

CREATE TABLE IF NOT EXISTS field_evidence (
    evidence_id    INTEGER PRIMARY KEY,
    entity_kind    TEXT NOT NULL CHECK (entity_kind IN ('grow', 'cultivar', 'seed_unit')),
    entity_id      TEXT NOT NULL,
    field_name     TEXT NOT NULL,
    source_id      TEXT NOT NULL REFERENCES source_catalog(source_id),
    excerpt_or_note TEXT NOT NULL
);

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

-- Purchases track ordered/incoming quantities separately from physically held seed_units.
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

CREATE INDEX IF NOT EXISTS idx_seed_units_cultivar ON seed_units(cultivar_id);
CREATE INDEX IF NOT EXISTS idx_seed_units_grow ON seed_units(grow_id);
CREATE INDEX IF NOT EXISTS idx_field_evidence_entity ON field_evidence(entity_kind, entity_id);
CREATE INDEX IF NOT EXISTS idx_candidates_role ON seed_research_candidates(candidate_role);
CREATE INDEX IF NOT EXISTS idx_candidate_offers_candidate ON candidate_offers(candidate_id);
CREATE INDEX IF NOT EXISTS idx_purchase_items_order ON purchase_order_items(purchase_id);

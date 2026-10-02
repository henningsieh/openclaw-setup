---
name: seed-inventory-database
description: Build or extend a personal seed inventory/database for owned stock, or research candidate alternatives and verified retailer prices for a hard-to-source cultivar; separate owned seeds from research candidates, preserve provenance, and verify entries against the stored data.
---

# Personal seed inventory

Use for a grower's own seed stock and its sources, not a formal genebank or botanical accession system.

1. Read the current grow/seed references and the existing inventory before editing. State the recorded cultivar names and counts separately: one cultivar record per named product, one seed-unit row per individually counted seed. Do not confuse number of cultivars with number of seeds or plants.
2. Define the fields and source plan briefly before populating. Prefer fields that support identity, inventory, and later grow tracking: breeder/brand and name as recorded; optional standardized catalog name; seed type, genetics, claimed flowering time/yield/THC/CBD; local unit ID, lot, supplier, acquired/sown/germinated dates, germination result, status, grow/plant label, storage and notes. Separate cultivar claims from observations of a particular plant.
3. Use sources by what they can actually establish: packet/order record for the exact purchased product, lot, supplier and purchase date; the exact official breeder product page for breeder-claimed traits; the user's setup or grow log for actual grow assignment and observed dates/results. Preserve the recorded spelling; only add a standardized name when an exact product source confirms it. Never borrow traits from a similarly named cultivar or third-party listing as if they described this seed.
4. Keep unknowns NULL/blank and record why or what source is missing. Do not infer lot, purchase, sowing, germination, phenotype, or product traits. If the grow reference gives an aggregate count without plant tags, local seed-unit IDs may represent that count but must be labelled as database IDs, not claimed physical labels.
5. Create/update the dedicated inventory folder with a short schema, source/method note, and database or equivalent data file. Keep evidence attached to individual fields/records where practical; include a simple query/readme if useful.
6. Verify the result from the stored database: integrity/foreign-key check when supported, cultivar count and unit count, each name-count pair, and source links for populated claims. Report files created, checked totals, unfilled data, and concrete blockers; do not claim completion from SQL text alone.

## Branch: research candidates and retailer offers

When the task is comparing cultivar alternatives or verifying prices for a hard-to-source cultivar rather than adding owned stock, also read `research-candidates-and-offers.md`. Keep those candidates in their own tables; they are not `seed_units`.

In all branches, bound the work to the field/source decisions and the exact relevant pages. Do not escalate into unrelated genebank standards, broad botany, or tool installation merely to fill optional fields.

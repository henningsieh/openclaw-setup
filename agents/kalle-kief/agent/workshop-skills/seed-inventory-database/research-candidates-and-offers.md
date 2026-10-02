# Research candidates and retailer offers

Read this when the user is comparing alternatives to a hard-to-source cultivar, or asks for verified prices or a priced comparison. These rows are research only — they are never owned stock.

## Separate candidates from stock

- If the user is comparing alternatives rather than adding stock, record a research candidate separately from `seed_units`; distinguish the target listing, the same cultivar/name sold by another breeder, and genuinely proposed alternatives. Store retailer offers separately per candidate.
- Preserve the user's desired similarity criteria and attach recommendation/rationale to its source; a shared name, flavor note, or banana lineage alone does not prove genetic equivalence.
- Treat pasted attachments and captured listings as claims from that source, not verified product facts. Record source URI/provenance and access date, keep prices and availability explicitly provisional, and leave a candidate unverified until an exact product or packet source has been checked. Do not change owned-stock counts for research-only candidates.

## Verified prices and `EUR/Seed`

- When the user asks for verified prices or an `EUR/Seed` comparison, verify the live exact retailer/product offer and the seed count for the same selected pack variant. Calculate `EUR/Seed = pack price in EUR ÷ seeds in that pack`, then round only for display; link the offer and record check date.
- A generic "from" price, a pack-size list without a matching price, a pasted price, or a visible product page without an offer is insufficient. Do not include an entry in the requested priced comparison unless both inputs are verified; report excluded entries separately only if useful, not as unpriced rows in the table.

## Research tooling

- Bound research to the field/source decisions and exact relevant product pages.
- Before browser work, inspect the browser tool's current status/doctor result; start or navigate only when a usable browser is reported.
- Use direct product-page fetch for readable static details and browser control when variants/prices are dynamically rendered.
- For web search, send only filters supported by the active provider; on an explicit unsupported-filter error, remove that filter and retry once rather than varying the query repeatedly.
- If the exact offer remains unavailable or ambiguous, do not guess a price or pack size; leave it out of a requested verified-price comparison and state the concrete limitation.

## Verify research updates

For alternative-research updates, also check candidate/offer counts, unverified status, and confirm research candidates did not become owned seed units.

# Power Query Code

Two queries, run in sequence. Read `table1-modified.pq` first — it contains the actual decision logic (normalization, operational-note detection, confidence scoring, price-divergence flagging). `final-cleaned-data.pq` applies those decisions across the full ~542,000-row transaction dataset to produce the recovered `Description` column.

- **`table1-modified.pq`** — StockCode-level: one row per product code, computing `DescriptionStatus` (Auto-Accept / Manual Review), `TopDescription`, and `PriceVarianceFlag`.
- **`final-cleaned-data.pq`** — row-level: joins those decisions back onto every transaction, layering in manual overrides and the suspected-multi-variant flag, and writes the final `Description` value for each row.

Full reasoning behind every rule and threshold in these scripts is in [`../methodology`](../methodology).

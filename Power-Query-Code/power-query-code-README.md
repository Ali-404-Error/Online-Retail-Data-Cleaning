# Power Query Code

Two queries, run in sequence. Read `Table1-Modified.pq` first — it contains the actual decision logic (normalization, operational-note detection, confidence scoring, price-divergence flagging). `Final-Cleaned-Data.pq` applies those decisions across the full ~542,000-row transaction dataset to produce the recovered `Description` column.

- **`Table1-Modified.pq`** — StockCode-level: one row per product code, computing `DescriptionStatus` (Auto-Accept / Manual Review), `TopDescription`, and `PriceVarianceFlag`.
- **`Final-Cleaned-Data.pq`** — row-level: joins those decisions back onto every transaction, layering in manual overrides and the suspected-multi-variant flag, writes the final `Description` value for each row, and classify each transaction to its suitable event.

Full reasoning behind every rule and threshold in these scripts is in [`../Methodology`](../Methodology).

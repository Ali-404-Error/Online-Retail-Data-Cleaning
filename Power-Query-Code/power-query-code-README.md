# Power Query Code

Two queries, run in sequence. Read `Table1-Modified.pq` first — it contains the actual decision logic (normalization, operational-note detection, confidence scoring, price-divergence flagging). `Final-Cleaned-Data.pq` applies those decisions across the full ~542,000-row transaction dataset to produce the recovered `Description` column.

- **`Table1-Modified.pq`** — StockCode-level: one row per product code, computing `DescriptionStatus` (Auto-Accept / Manual Review), `TopDescription`, and `PriceVarianceFlag`.
- **`Final-Cleaned-Data.pq`** — row-level: joins those decisions back onto every transaction, layering in manual overrides and the suspected-multi-variant flag, writes the final `Description` value for each row (stage1), assign a `TransactionType` to each row (stage 2), and sets `CustomerID` to text before investigating (stage 3).
- **`CustomerID-Invoice.pq`** — one row per invoice unit, counting every line per `IvoiceNo`, computing `BlankLines` into a 0 or 1 check, and layering those rows with `IsPartial` flag.
- **`CustomerID-Country.pq`** — one row per country, groups every country line in one row, same as `InvoiceNo`, calculating `BlankShare` per country in its own lines, no flags applied.
- **`CustomerID-Month.pq`** — same as `Country`, calculated by start of month to avoid different years collisions, no flags applied.

Full reasoning behind every rule and threshold in these scripts is in [`../Methodology`](../Methodology).

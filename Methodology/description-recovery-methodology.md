# Description Recovery & Validation — Methodology

**Dataset:** UCI Online Retail (raw `.xls`, ~542,000 transaction rows)
**Tool:** Microsoft Excel / Power Query
**Stage goal:** Recover missing `Description` values using other transactions of the same `StockCode`, while distinguishing real product data from operational noise, and flagging cases too ambiguous to resolve automatically.

---

## 1. Problem Statement

`Description` was missing on 1,454 rows. Since `StockCode` is a product identifier repeated across many transactions, a missing description could often be recovered by finding another row with the same `StockCode` that *did* have a description. The challenge was building that recovery process in a way that was accurate, auditable, and safe to run unattended across hundreds of thousands of rows — rather than simply picking whichever description happened to appear first.

## 2. Diagnosis

Before any recovery logic could run correctly, two structural data-quality issues had to be found and fixed:

- **Mixed `StockCode` types.** Roughly 487,000 rows had `StockCode` stored as a number, and ~55,000 as text. Under this mismatch, identical codes like `22139` (number) and `"22139"` (text) failed to group together, silently corrupting any code-based lookup. Fixed by explicitly casting `StockCode` to Text before any grouping.
- **Case and whitespace inconsistency.** The same StockCode and the same Description sometimes appeared with different capitalization or trailing spaces (`15056BL` vs `15056bl`). This inflated the apparent number of "different" descriptions per product. Fixed by applying `UPPERCASE` + `Trim` to both `StockCode` and `Description` early in the pipeline.

Applying both fixes reduced the initial set of "ambiguous" StockCodes (more than one distinct description) from 1,324 to 1,318 — a small but real improvement confirming the case/whitespace fix mostly cleaned up duplicate *codes*, not duplicate *descriptions*.

## 3. Recovery Method

For each `StockCode`:

1. Grouped all non-null, non-blank `Description` values used with that code, along with their transaction count and median `UnitPrice`.
2. If exactly one distinct description existed → **high confidence, auto-recoverable.**
3. If more than one existed → computed a **Confidence score**: the winning candidate's transaction count divided by the total transaction count across all candidates for that code. A score of 1.0 means every transaction agreed; a score near 0.5 means the candidates were roughly tied.

## 4. Filtering Out Non-Product Rows

A large share of apparent "ambiguity" turned out to be operational/internal entries — warehouse notes, adjustments, and fees — rather than real competing product names (e.g. `"damaged"`, `"wet/rusty"`, `"check"`, `"AMAZON FEE"`, `"DOTCOM POSTAGE"`). These rows needed to be excluded from the *candidate pool* before grouping, without deleting them from the dataset.

`IsOperationalNote` flags a row true if:
- `CustomerID` is blank **and** `UnitPrice = 0` **and** `Quantity < 0` (the behavioral signature of an internal adjustment), **or**
- the description text contains a `?`, or matches a curated list of junk-indicator words compiled by direct inspection of the data (`CHECK`†, `AMAZON`†, `FOUND`, `ADJUSTMENT`, `WRONGLY`, `DOTCOM`†, `DAMAGED`, `RETURNED`, `TEST`, `MAILOUT`, `PUT`, `MARKED`, `CODED`).

† These three words were initially added as broad substring matches, then had to be corrected after discovering they also appear inside legitimate product names (e.g. `"BROWN CHECK CAT DOORSTOP"`, `"AMAZONITE"`-style items, real `dotcomgiftshop.com` storefront sales with genuine prices). `CHECK` was narrowed to an **exact match** rather than a substring match; `DOTCOM` was removed from the junk list entirely once its transactions were confirmed to be legitimate (just zero-priced in some cases, which is handled separately by the price-divergence check, not by exclusion).

A separate flag, `HasBlankDescription`, was also needed: a StockCode with one real description plus a few genuinely blank rows was being miscounted as "2 candidates" (the real text, and a phantom `null` candidate) before this fix, artificially inflating the ambiguous bucket from 686 down to a corrected 332 once excluded.

Applying both filters reduced the ambiguous StockCode count from **1,318 → 686 → 332** (operational-note filter, then null-candidate fix).

## 5. Resolving Remaining Ambiguity: Confidence Threshold

For the 332 remaining ambiguous StockCodes, a **Confidence ≥ 0.9** threshold was set to separate auto-resolvable cases from genuine manual review. This threshold was not chosen arbitrarily — the full set of confidence scores was sorted, and 0.9 was chosen because it sat safely inside a natural gap in the distribution (no real StockCode's score fell between roughly 0.9 and the next cluster below it), meaning the exact choice of number within that gap made no difference to the classification outcome.

This left **95 StockCodes** below the threshold, needing manual review.

## 6. A Second Dimension: Price Divergence

Confidence alone measures agreement on *wording*, not on *product identity*. Manual inspection surfaced cases where two candidate descriptions for one StockCode had a very high confidence score (one text clearly dominant) but represented genuinely different products at different price points — e.g. `84906` ("with bobbles" vs. plain, 3x price difference) and the `84997B/C/D` children's-cutlery family (consistently priced higher than the adult version).

A `PriceDivergencePct` metric was built: `|winning candidate's median price − runner-up's median price| / average of the two`, expressed as a percentage so it is comparable across cheap and expensive items alike. A **0.5 (50%) threshold** was chosen the same way as the confidence threshold — sorted, and set inside a genuine, verified gap between known safe cases (0-17%, e.g. `82486`, same product typed two ways) and known real-variant cases (71-200%, e.g. `84906`).

Decision: rather than blocking recovery whenever price diverges, `DescriptionStatus` (Auto-Accept / Manual Review) was kept based on **confidence alone**, and `PriceVarianceFlag` was built as an **independent** column based on price divergence alone. Rationale: price differences are more likely to reflect time-based or promotional pricing variation than genuinely different products, and collapsing both signals into one column would hide that distinction from anyone reviewing the data later. This decision is explicitly reversible — `PriceVarianceFlag` remains queryable on every row it applies to.

## 7. Manual Review

The 95 StockCodes below the confidence threshold were reviewed individually, using full context (both candidate descriptions, their prices, and their transaction counts) rather than text alone. A consistent rule was applied:

- **Pure spelling, spacing, or word-order variation** (e.g. `"DOG AND BALL WALL ART"` vs `"WALL ART DOG AND BALL"`) → safe to merge, picked the higher-count winner.
- **A stylistic/seasonal tag with no conflicting spec** (e.g. `"CHRISTMAS HANGING HEART"` vs `"HANGING HEART"`) → safe to merge, even where price also diverges, since `PriceVarianceFlag` independently captures the price signal.
- **A genuine conflicting attribute** — color, material, size/count, or function (e.g. `"TRINKET BOX"` vs `"TRINKET POT"`; `"9 POINT"` vs `"6 POINT"`) → **left unresolved**, regardless of price. Forcing a single answer here risks silently misrepresenting real product variants sharing one StockCode.

Of the 95, 19 rows were classified as suspected multi-variant StockCodes and left unresolved; the remainder were resolved and recorded in a manual override table.

One anomaly (`TUMBLER, BAROQUE` / `TUMBLER NEW ENGLAND`, StockCodes `79030D`/`79030G`) showed a 4x price gap despite near-identical wording; currency/country effects were tested and ruled out directly against the raw data. Cause remains undetermined; resolved to the majority-wording candidate with the anomaly noted rather than left unresolved, since wording gave no basis for suspecting two distinct products.

## 8. Final Classification

Every StockCode falls into exactly one of four outcomes:

| Outcome | Meaning | Flag |
|---|---|---|
| **Auto-Accept** | Single clear description, or ambiguous but resolved with ≥0.9 confidence | `DescriptionStatus = "Auto-Accept"` |
| **Manual Override** | Reviewed individually, wording safely merged | Present in `ManualOverrides` lookup table |
| **Unrecoverable** | No real (non-blank, non-junk) description exists anywhere for this code | `IsDescriptionUnrecoverable = true` |
| **Suspected Multi-Variant** | Multiple real descriptions exist, but appear to represent genuinely different products sharing one StockCode | `IsSuspectedMultiVariantCode = true` |

`PriceVarianceFlag` is tracked independently across all rows and does not gate any of the four outcomes above.

## 9. Applying the Recovery

A `Description` fill was computed row-by-row with this priority order:

1. If the row is an operational note → leave its own text untouched (never overwritten).
2. Else if its StockCode has a manual override → use the override description.
3. Else if its StockCode is Auto-Accept → use the top (majority) description.
4. Else → leave as-is (covers Manual Review-unresolved and Unrecoverable rows, which stay blank).

## 10. Limitations & Known Trade-offs

- **Person-name and free-text junk entries** (e.g. staff names, "CAN'T MANAGE THIS SECTION"-style notes) cannot be reliably caught by keyword matching, since their phrasing is effectively unbounded. These were caught individually during manual review rather than by a general rule.
- **Seasonal tagging is not preserved** in the final `Description` (e.g. "CHRISTMAS" merged away). This information is not lost — it remains recoverable from `InvoiceDate` — but is not present in `Description` itself.
- **~19 StockCodes remain genuinely unresolved** (suspected multi-variant), reflecting an underlying data-quality issue (StockCode reuse across distinct products) rather than a gap in this recovery process. Recommended follow-up: audit these codes against an external product catalog if one becomes available.
- Every threshold in this pipeline (0.9 confidence, 0.5 price divergence, the junk-word list) was derived from direct inspection of this dataset's actual distribution, not assumed in advance — and each is independently re-checkable if the underlying data changes.

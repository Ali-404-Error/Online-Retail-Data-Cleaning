## Transaction Type Classification — Methodology

**Stage Goal**: label every row by the kind of event it represents, so later analysis can include or exclude rows on purpose instead of mixed sales and other transaction mistakenly.

---

## 1. Problem Statement

Negative `Quantity` and zero `UnitPrice` showed in the data from the start, but were only handled in `IsOperationalNote` that was built for the description-recovery stage. This stage uncover the answer for a different question which is "what kind of transaction is this?"

## 2. Investigation

These are the counts for the points needed to be checked for starters
| Check | Rows |
|---|---|
| `Quantity < 0` | 10,624 |
| `UnitPrice <= 0` | 2,517 |
| `InvoiceNo` starts with `C` | 9,288 |
| `Quantity < 0` and `InvoiceNo` starts with `C` | 9,288 |
| `Quantity = 0` | 0 |

**Customer Cancellation**. All 9,288 `C`-prefixed rows have negative quantity, a subset of the negative-quantity rows.

**The remaining 1,336 rows** (no `C`-prefix) have a consistent profile: blank `CustomerID`, zero `UnitPrice`, and `Description` is either blank or an operational note. So, no customer was involved which refers to the transactions being internal write-offs or adjustments.

**Zero or negative price with positive quantity**. Of the 2,517 rows with `UnitPrice <= 0`, there was a total count of 1,181 rows that have positive quantity. A transaction happened, no money changed hands. This group isn't uniform as in:

- 1,141 rows have no `CustomerID`. `Description` is a mix of real products, operational notes, bad-debts adjustments, and blanks.
- 40 rows have real customers with their IDs typed in. Including real products, 6 rows with `StockCode` "M" / `Description` "MANUAL", and 1 row with `StockCode` "PADS". None were carrying a prefixed-`C`.

## 3. Classification

Every row falls into one of four categories, checked in this exact testing order:

```
if Text.StartsWith([InvoiceNo], "C") then "Customer Cancellation"
else if [Quantity] < 0 then "Internal write off"
else if [UnitPrice] <= 0 then "Non-Standard Pricing"
else "sale"
```

| Order | Test | Category | Reasoning |
|---|---|---|---|
| 1 | `InvoiceNo` starts with `C` | Customer Cancellation | All 9,288 such rows have negative quantity, so no second condition needed |
| 2 | `Quantity < 0` | Internal write off | After step 1, every remaining row was shown to have blank `CustomerID` and zero `UnitPrice` |
| 3 | `UnitPrice <= 0` | Non-Standard Pricing | After step 2, what is left has positive quantity |
| 4 | Otherwise | sale | Positive quantity and price, no `C` prefix |

The classification uses only `InvoiceNo`, `Quantity`, and `UnitPrice`. The use of `Description` was excluded, because within each group it was inconsistent, so it could not separate groups in a reliable way. `InvoiceNo` column type was changed into text so the formula used could run, leaving it as number or mixed strings would result in expresion errors.

## 4. Verification

| Type | Rows Count |
|---|---|
| Customer Cancellation | 9,288 |
| Internal write off | 1,336 |
| Non-Standard Pricing | 1,181 |
| sale | 530,104 |
| Total Count | 541,909 |

Three reconciliation checks, all matching the counts from the investigation stage:

1. The four types sum to the full rows count.
2. Cancellations plus write-offs (9,288 + 1,336) equal the original negative-quantity count of 10,624.
3. Write-offs plus Non-Standard Pricing (1,336 + 1,181) equal the original `UnitPrice <=0` count of 2,517.

## 5. Cancellations offset sales: USE NET QUANTITY

A `Customer Cancellation` row reverses an earlier  sale, so the two belong together in any volume or revenue calculation. Filtering to `sale` alone counts reversed orders at full value and leads to fake or misleading profit information.
Example on the case: one `sale` row of +80,955 units has a `Customer Cancellation` row of -80,955 units on the same product. Both rows have the same customer, StockCode, about ten minutes apart on the same day between the two invoices. The order was placed then cancelled, so there is no net effect. Both rows are classified correctly by structure, but a calculation that uses only `sale` would overstate the product by the full value of order (fake profit).

Rule for analysis: when measuring sales volume or revenue, net `sale` against `Customer Cancellation` instead of using `sale` alone.

## 6. Decision: No reversed-sale flag

A flag marking sales that were reversed later was considered to be built but it happened to be not:

- **Netting already handles this situation**. Summing quantity across both types cancels the pair without any row-to-row matching.
- **Matching is unreliable**. The sale and its cancellation share no key. A match would have to use `StockCode`, `CustomerID` and negated quantity. Partial returns would not match, and a return months later cannot be found with a same-day shortcut.
- **The check did not show widespread reversal**. Among the 20 `sale` rows with large units (2,000 or more), about 4 rows had cancellations on the same day next to them. This is a low bound as the check only sees cancellations adjacent in the sorted view, so a reversal on another date would be missed. It does not support a percentage claim, and does not change the decision since netting works regardless of the date.

## 7. Relationship to `IsOperationalNote`

`IsOperationalNote` flags a row when `CustomerID` is blank, `UnitPrice` is zero, and `Quantity` is negative, or when the description contains a junk keyword. The numeric half is a subset of `Internal write off`, so on those rows both columns agree.

The two columns stay separate because they answer different questions. `IsOperationalNote` decides whether a row's text can be used as a candidate product name. The overlap is intentional, but neither column replaces the other.

## 8. Limitations

- `Non-Standard Pricing` **is a blend**. It contains giveaways, bad-debt adjustments, manual lines and a few real-customer entries. It was not split further, because every sub-reason leads to the same treatment: not an ordinary paid sale, excluded from revenue, and not a stock loss like a write-off. The sub-reasons are noted as examples, not tagged individually.
- **Extreme quantities are not addressed**. Some `sale` rows have very large quantities, whether the unmatched ones are genuine bulk orders or entry errors that belongs to the outliers review stage.
- **The classification only labels rows**. No rows are removed or changed, whether to include or exclude them is a decision for each analysis.

# Missing CustomerID — Methodology

**Stage Goal**:
- Understand why `CustomerID` is blank in about quarter of the rows.
- Decide what to do with those rows.
- Document what the gap does and does not tell, so later analysis can use or exclude them on purpose.

---

## 1. Problem Statement

- `CustomerID` is blank on 135,080 of 541,909 rows (24.9%). Any customer-level analysis (number of customers, repeat purchases, spend per customer) silently skips a quarter of the data unless the gap is understood first. Deleting the rows would remove a quarter of the sales, and inventing IDs would fabricate customers that do not exist.
- Before choosing either, this stage looks at where the blanks sit and how they are structured.

## 2. Investigation

### 2.1 By transaction type

Using the `TransactionType` column from the previous stage:

| Type | Rows NO. | Blank CustomerID | Blank Share |
|---|---|---|---|
| Sale | 530,104 | 132,220 | 25% |
| Internal write off | 1,336 | 1,336 | 100% |
| Non-Standard Pricing | 1,181 | 1,141 | 97% |
| Customer Cancellation | 9,288 | 383 | 4% |
| Total | 541,909 | 135,080 | - |

- About 98% of the blanks are on `Sales` rows.
- The write-offs are always blank, which fits the earlier finding that no customers are involved in them.
- A quarter of all sales being blank is a different matter as it a gap in the main revenue rows, not a side effect of unusual transaction types.

### 2.2 The unit is the invoice

One row is one invoice line (one product on one invoice), so 135,080 blank rows do not mean 135,080 orders. The question that decides how the blanks can be used is whether blankness belongs to the whole invoice or to individual lines. To answer that, the data was grouped by `InvoiceNo` with two counts: total lines, and lines with a blank `CustomerID` (a helper column of 1 for blank and 0 for filled, then summed).

Results across the whole table (checked against the full dataset):

| Invoice group | Invoices | lines |
|---|---|---|
| Every line is blank | 3,710 | 135,080 |
| No blank lines | 22,190 | 406,829 |
| Some blank, some filled | 0 | 0 |
| Total | 25,900 | 541,909 |

Two checks support the zeros in third row:

1. Searching for the exceptions (invoices with more than 0 blank lines and fewer blank lines than total lines), none was found.
2. The lines inside the fulle blank invoices add up to exactly 135,080 lines, the total number of blank rows, which leaves no room for partly blank invoices.

An invoice either has a customer on every line or on none. Blankness is a property of the order.

### 2.3 Size of the anonymous invoices

| | Invoices | Lines | Average lines per invoice |
|---|---|---|---|
| Anonymous (Blank) | 3,710 | 135,080 | about 36.4 |
| Identified | 22,190 | 406,829 | about 18.3 |

Anonymous invoices are 14% of the invoices and 25% of the lines. They average about twice as many lines per invoice as identified ones.

### 2.4 By Country

The blank share by country (line level, which is safe because blankness is all-or-nothing per invoice):
- **United Kingdom**: 133,600 blank lines out of 495,478 (about 27%), which is 98.9% of all blanks.
- **Hong Kong**: 288 of 288 lines are blank (100%).
- **All other countries together**: 1,480 blank lines (1.1% of all blanks). Most countries have none at all (Germany, Spain, The Netherlands, Belgium, Australia).
- **Countries with some blanks**: Eire 711 of 8,196 (8.7%). Switzerland 125 of 2,002 (6.2%), Palestine 47 of 297 (15.8%).
- **Unspecified**: 202 of 446 lines are blank (45.3%). `Unspecified` is a placeholder for missing country, it is a separate data gap and is not handled in this stage.

The totals of the country table reconcile to 541,909 rows and 135,080 blank rows.

### 2.5 By Month

Blank share of lines by month:

| Month | Lines | Blank lines | Share |
|---|---|---|---|
| Dec 2010 | 42,481 | 15,631 | 36.8% |
| Jan 2011 | 35,147 | 13,235 | 37.7% |
| Feb 2011 | 27,707 | 7,344 | 26.5% |
| Mar 2011 | 36,748 | 8,926 | 24.3% |
| Apr 2011 | 29,916 | 6,718 | 22.5% | 
| May 2011 | 37,030 | 8,122 | 21.9% |
| Jun 2011 | 36,874 | 9,038 | 24.5% |
| Jul 2011| 39,518 | 12,016 | 30.4% |
| Aug 2011 | 35,284 | 7,622 | 21.6% |
| Sep 2011 | 50,226 | 9,404 | 18.7% |
| Oct 2011 | 60,742 | 10,047 | 16.5% |
| Nov 2011 | 84,711 | 19,113 | 22.6% |
| Dec 2011 | 25,525 | 7,864 | 30.8% |

- Start of the month was used instead of the month number because the data spans two Decembers.
- The share stays between 16.5% and 37.7% in every month, and no month is clse to 0% or 100%.
- The share is lowest in the busy autumn months mostly identified lines grow (November has 84,711 lines), while the number of blank lines each month stays in a similar range.
- The last row is a partial month, since the dataset ends early in December 2011.

---

## 3. What The Evidence Support

1. The gap is stable acroos the whole year. A period when customer capture was switched off would show up as months near 0% or 100%, and none do.
2. The gap is almost entirely a UK feature, and it is made up of whole orders.
3. Anonymous orders are real sales (132,220 of the blank rows are `sale`), and they are larger than identified orders by line count.

---

## 4. Decisions

1. **No rows are removed**. They are real sales, and removing them would bias revenue and product figure.
2. **No customerIDs are imputed**. Any invented ID would be a fabricated customer.
3. **`CustomerID` is converted from any to text**, in the same early step that types `StockCode`and `InvoiceNo`. An ID is a label, not a number to calculate with. The count of blank rows is unchanged by the conversion.
4. **No separate flag column is added**. Filtering `CustomerID` to blank or non-blank does the same job. Because blankness is all-or-nothing per invoice, that filter never splits an order. A flag can be added later if the data is exported to a tool that can't handle blanks properly.

---

## 5. How The Gap Affects Analysis

- Customer-level analysis uses only rows with `CustomerID`. Because the blanks are whole invoices, excluding them removes whole orders.
- Revenue and product analysis can use all rows
- Comparisons the two groups are possible, since invoice counts, sizes, countries, and months are all known for each.

### Relationship to `TransactionType`

- All 1,336 `Internal write off` rows have no customer by nature, and 1,141 of the 1,181 `Non-Standard Pricing` rows are blank as well.
- 383 `Customer Cancellation` rows have no customerID. They cannot be tied to the customer who made the original purchase, so netting cancellations against sales per customer would miss them. Netting per product still includes them.
- `Customer Cancellation` blank rows may point to a control weakness, such as refunds that nobody can trace. This stage cannot confirm or rule it out. A test would be to match these 383 rows to earlier sales by StockCode, quantity, and unit price, and see how many have a clear original sale.
---

## 6. Limitations

1. **The cause is unknown**. The dataset has no field that says why an order has no customer. Guest checkout, a separate sales channel, wholesale or something else would all fit te numbers, so none claimed.
2. **Larger size is observed, not explained**. Anonymous invoices average about twice the lines of the identified ones, but a comparison of order value and product mix between the two groups was not done, because it would not change how the rows are treated.
3. `Unspecified` in country columns is a separate gap and still need its own treatment.
4. **The classification only descripe the gap**. No row changed apart from the data type of `CustomerID`.

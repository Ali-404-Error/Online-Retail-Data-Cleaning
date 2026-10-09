# Online Retail Data Cleaning

Cleaning the [UCI Online Retail dataset](https://archive.ics.uci.edu/dataset/352/online+retail) (~542,000 transaction rows) in Excel and Power Query. The project runs in stages, and each stage is documented separately.

| Stage | Goal | Write-up |
|---|---|---|
| 1. Description Recovery | Recover missing product descriptions | [methodology](./Methodology/description-recovery-methodology.md) |
| 2. Transaction Type | Label every row by the kind of event it represents | [methodology](./Methodology/transaction-type-classification.md) |

## Stage 1: Description Recovery

### The Problem

1,454 transaction rows were missing a product `Description`. Since `StockCode` repeats across many transactions, a missing description could often be recovered by cross-referencing other rows sharing the same code — but doing that safely at scale required first catching several hidden data-quality issues (mixed data types, inconsistent capitalization, internal operational notes mixed into the description field) that would otherwise have corrupted the recovery logic.

### Results

Every product code in the dataset was classified into one of four outcomes:

| Outcome | Count | Meaning |
|---|---|---|
| Auto-Accept | `3733` | Single or clearly-dominant description, recovered automatically |
| Manual Override | `76` | Ambiguous, resolved by individual review |
| Suspected Multi-Variant | `19` | Multiple real descriptions likely represent genuinely different products sharing one code — left unresolved by design |
| Unrecoverable | `130` | No real description exists anywhere in the data for this code |

Two thresholds used in the pipeline (a 0.9 confidence score for automatic resolution, a 50% price-divergence flag for suspected variants) were not assumed — both were derived by sorting the real data and finding a genuine gap in the distribution.

## Stage 2: Transaction Type

### The Problem

Negative quantities and zero prices were mixed in with ordinary sales. Any revenue or inventory calculation built on the raw columns would count customer cancellations, internal write-offs and zero-price giveaways as normal sales.

### Results

Every row was assigned exactly one type, using only `InvoiceNo`, `Quantity` and `UnitPrice`:

| Type | Rows | Meaning |
|---|---|---|
| Customer Cancellation | 9,288 | `C`-prefixed invoice; reverses an earlier sale |
| Internal write off | 1,336 | Negative quantity, no customer, zero price; internal stock adjustment |
| Non-Standard Pricing | 1,181 | Positive quantity but zero or negative price; goods moved without payment |
| sale | 530,104 | Positive quantity, positive price |

The four types sum to 541,909 rows, and the counts reconcile against the original negative-quantity (10,624) and non-positive-price (2,517) checks.

One analysis rule came out of this stage: cancellations offset earlier sales, so volume and revenue should be measured on net quantity across both types, not on `sale` alone. A separate "reversed sale" flag was considered and rejected; the methodology explains why.

## What's in This Repo

- **[`Methodology/`](./Methodology)**: the full write-up for each stage: every bug found, every threshold and why, every judgment call.
- **[`Power-Query-Code/`](./Power-Query-Code)**: the M code behind both stages.
- **[`Data-Sample/`](./Data-Sample)**: a CSV sample of the stage 1 output across all four description outcomes.
- **[`DATASET`](./DATASET.md)**: dataset source, license and citation.
- **[`WORKBOOK`](./WORKBOOK.md)**: what the local workbook contains and what the repo exposes from it.

## Tools

Microsoft Excel + Power Query (M language). No external libraries or scripts.
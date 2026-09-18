# Online Retail — Description Recovery Pipeline

Cleaning and recovering missing `Description` values in the [UCI Online Retail dataset](https://archive.ics.uci.edu/dataset/352/online+retail) (~542,000 transaction rows), built entirely in Power Query.

## The Problem

1,454 transaction rows were missing a product `Description`. Since `StockCode` repeats across many transactions, a missing description could often be recovered by cross-referencing other rows sharing the same code — but doing that safely at scale required first catching several hidden data-quality issues (mixed data types, inconsistent capitalization, internal operational notes mixed into the description field) that would otherwise have corrupted the recovery logic.

## Results

Every product code in the dataset was classified into one of four outcomes:

| Outcome | Count | Meaning |
|---|---|---|
| Auto-Accept | `3733` | Single or clearly-dominant description, recovered automatically |
| Manual Override | `76` | Ambiguous, resolved by individual review |
| Suspected Multi-Variant | `19` | Multiple real descriptions likely represent genuinely different products sharing one code — left unresolved by design |
| Unrecoverable | `165` | No real description exists anywhere in the data for this code |

Two thresholds used in the pipeline (a 0.9 confidence score for automatic resolution, a 50% price-divergence flag for suspected variants) were not assumed — both were derived by sorting the real data and finding a genuine gap in the distribution.

## What's in This Repo

- **[`Methodology/`](./Methodology)** — the full write-up: every bug found, every threshold and why, every judgment call and its reasoning.
- **[`Power-Query-Code/`](./Power-Query-Code)** — the actual M code behind the pipeline, split into the stages described in the methodology (normalization, junk-entry detection, confidence scoring, final classification).
- **[`Data-Sample/`](./Data-Sample)** — a before/after CSV sample showing recovered rows across all four outcome categories.
- **[`DATASET/`](DATASET.md)** _ includes the webpage for the dataset, license, and citation.
- **[`WORKBOOK/`](WORKBOOK.md)** _ refers to what the workbook includes and what the git repo shows from it rather than exposing the whole source 

## Tools

Microsoft Excel + Power Query (M language). No external libraries or scripts.

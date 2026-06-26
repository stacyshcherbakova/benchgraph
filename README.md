# BenchGraph

Working name (provisional). A local-first, Mac-native tool for taking experimental
data to trustworthy statistics and publication-quality figures — without writing code.

See [`docs/`](./docs/README.md) for the research and product planning, including the
[MVP and roadmap](./docs/product/mvp-roadmap.md).

## What's in this first MVP

This repository contains the **validated analysis engine** the product is built on —
the part the roadmap calls non-negotiable ("accurate calculations for included tests,
with independent test fixtures") — plus a CLI that performs the core promise
end-to-end: **import data → run an analysis → export a figure**.

- **`BenchGraphKit`** — a Swift library:
  - **Tables & import**: `DataTable` (column / XY / grouped) and a tolerant
    CSV/TSV/paste parser (`CSVImporter`) that handles headers, quoted fields,
    thousands separators, empty cells, and non-numeric "missing" tokens.
  - **Analyses** (each returns a provenance-rich `AnalysisResult` carrying the
    formula, assumptions, warnings, and excluded-cell count):
    descriptive statistics, one-sample / paired / unpaired t tests
    (Student & Welch), one-way ANOVA with **Bonferroni & Holm post-hoc**
    pairwise comparisons, Mann-Whitney U, **Wilcoxon signed-rank**,
    Pearson & Spearman correlation, simple linear regression,
    **D'Agostino-Pearson normality test**, and 4PL dose-response curve fitting
    (Levenberg-Marquardt) with standard-curve interpolation.
  - **Distributions**: self-contained normal, Student's t, and F distributions
    (via a regularized incomplete beta), so p-values depend on no external library.
  - **Export**: a deterministic, text-based `SVGRenderer`, plus a CoreGraphics
    renderer for **PDF, PNG, and TIFF** — scatter/XY plots with fitted curves
    and log axes, bar charts with selectable SD/SEM/CI error bars, **box and
    violin plots**, **significance brackets** linked to analysis p-values, and
    **journal theme presets**. A `FigureExport` helper picks the format by file
    extension.
  - **Project files**: a versioned, human-readable JSON `ProjectDocument`
    (`.benchgraph`) that round-trips the data and analysis spec so a project
    reopens exactly.
- **`benchgraph`** — a CLI front end demonstrating the workflow.
- **`BenchGraphApp`** — a SwiftUI macOS app (window) built on the same engine:
  paste CSV/TSV data, see it parsed, pick an analysis, and get a live
  provenance-rich result plus a native chart. Export figures to SVG/PDF/PNG/TIFF
  and save/open `.benchgraph` project files.

A signed/notarized DMG for distribution is the remaining V1 packaging step (it
requires an Apple Developer ID); this MVP establishes and verifies the engine,
CLI, and app on top of it.

## Requirements

- macOS 13+
- Swift 6 (Xcode or the Command Line Tools)

## Build, test, run

```bash
swift build                 # build the library + CLI
./scripts/test.sh           # run the test suite (56 tests)
```

`scripts/test.sh` wraps `swift test` with the framework paths needed when only the
Command Line Tools are installed (no full Xcode). With Xcode installed, plain
`swift test` works too.

### Run the desktop app

```bash
./scripts/build-app.sh      # builds BenchGraph.app (double-clickable bundle)
open BenchGraph.app         # launch it
```

The app opens with a sample dose-response dataset loaded. Paste your own CSV/TSV
on the left, choose an analysis from the picker, and the results panel and chart
update live. Switch column charts between bars/box/violin, pick a journal theme,
and use **Export figure…** to save the current chart as SVG, PDF, PNG, or TIFF.

### CLI examples

```bash
# Descriptive statistics for every column
.build/debug/benchgraph describe examples/groups.csv

# Welch's unpaired t test on the first two columns
.build/debug/benchgraph ttest examples/groups.csv

# ANOVA post-hoc pairwise comparisons (Bonferroni & Holm)
.build/debug/benchgraph posthoc groups.csv

# 4PL dose-response: fit, interpolate x at response 50, export a PDF figure
.build/debug/benchgraph doseresponse examples/dose-response.csv \
    --interpolate 50 --out examples/dose-response.pdf   # or .svg/.png/.tiff

# Full command list (describe, ttest, anova, posthoc, mannwhitney,
# wilcoxon, normality, correlate, regress, doseresponse)
.build/debug/benchgraph help
```

## Validation

Every analysis is covered by golden-value tests whose reference numbers were computed
independently with SciPy (`scipy.stats`), matching the validation plan's "compare
against at least two independent references" guidance. The 4PL fit is tested against
noise-free data with known parameters, and SVG output is checked for well-formedness
and byte-stable determinism (so figures can be snapshot-tested).

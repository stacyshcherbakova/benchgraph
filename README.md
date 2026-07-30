# BenchGraph

Working name (provisional). A local-first, Mac-native tool for taking experimental
data to trustworthy statistics and publication-quality figures — without writing code.

New here? Start with the [user guide](./docs/guide/getting-started.md). See
[`docs/`](./docs/README.md) for the research and product planning, including the
[MVP and roadmap](./docs/product/mvp-roadmap.md).

## What's in this first MVP

This repository contains the **validated analysis engine** the product is built on —
the part the roadmap calls non-negotiable ("accurate calculations for included tests,
with independent test fixtures") — plus a CLI that performs the core promise
end-to-end: **import data → run an analysis → export a figure**.

- **`BenchGraphKit`** — a Swift library:
  - **Tables & import**: `DataTable` (column / XY / grouped), a tolerant
    CSV/TSV/paste parser (`CSVImporter`) that handles headers, quoted fields,
    thousands separators, empty cells, and non-numeric "missing" tokens, a
    **dependency-free `XLSXImporter`** (a minimal ZIP+XML reader using the OS
    `Compression` framework), and an editable string grid (`EditGrid`) that the
    app types into.
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
    renderer for **PDF, PNG, and TIFF** — scatter/XY plots with fitted curves,
    log axes, and **residual plots**, bar charts with selectable SD/SEM/CI error
    bars, **box and violin plots**, **significance brackets** linked to analysis
    p-values, and **journal theme presets**. `FigureExport` picks the format by
    file extension; `FigureLayout` composes several figures into one
    **multi-panel figure with A/B/C labels**; and `ExportManifest` records the
    data source, options, and app version alongside an export.
  - **Project files**: a versioned, human-readable JSON `ProjectDocument`
    (`.benchgraph`, schema v3) that round-trips the data, analysis spec,
    presentation options, and **staged multi-panel figures** so a project reopens
    exactly. Panels are stored as the figure that was drawn, not a recipe to
    re-run, so reopening never silently redraws published work.
- **`benchgraph`** — a CLI front end demonstrating the workflow.
- **`BenchGraphApp`** — a SwiftUI macOS app built on the same engine: type into
  an **editable data grid** (or paste/import CSV/TSV/XLSX), pick an analysis, and
  get a live provenance-rich result plus a native chart, with **undo/redo** across
  edits. Export figures to SVG/PDF/PNG/TIFF, **copy them as vector** (PDF+SVG) to
  the clipboard, build **multi-panel figures** with **drag-to-reorder** panels,
  and save/open `.benchgraph` project files (which the app registers so they open
  on double-click). A **Help menu** carries quick-start cards backed by the
  published guide.

The signing/notarization/DMG pipeline is scripted in `scripts/build-app.sh`;
producing a distributable signed DMG needs an Apple Developer ID credential.

## Requirements

- macOS 13+
- Swift 6 (Xcode or the Command Line Tools)

## Build, test, run

```bash
swift build                 # build the library + CLI
./scripts/test.sh           # run the test suite (120 tests)
```

`scripts/test.sh` wraps `swift test` with the framework paths needed when only the
Command Line Tools are installed (no full Xcode). With Xcode installed, plain
`swift test` works too.

### Run the desktop app

```bash
./scripts/build-app.sh      # builds BenchGraph.app (double-clickable bundle)
open BenchGraph.app         # launch it
```

The app opens with a sample dose-response dataset loaded. Type directly into the
data grid, or paste/**Import…** CSV/TSV/XLSX, then choose an analysis from the
picker and the results panel and chart update live; ⌘Z / ⇧⌘Z undo and redo any
edit. Switch column charts between bars/box/violin, toggle residuals for fits,
pick a journal theme, and use **Export chart…** (SVG/PDF/PNG/TIFF, with a
`.manifest.json` written alongside) or **Copy (vector)**. For 4PL fits, an
**Interpolate x at y** field reads concentrations back off the standard curve.

In the **Multi-panel figure** section, **Add current chart** captures the chart
as a thumbnail panel (A, B, C…). **Drag the cards** to reorder them — the letters
follow position — or right-click for Move left / Move right. **Export panels…**
combines them into one labeled figure; the toolbar's **Export chart…** exports
only the chart on screen. Staged panels are saved with the project and covered by
undo.

The **Help** menu has quick-start cards for these workflows and links to the
[full guide](./docs/guide/getting-started.md).

### CLI examples

```bash
# Descriptive statistics for every column
.build/debug/benchgraph describe examples/groups.csv

# Welch's unpaired t test on the first two columns
.build/debug/benchgraph ttest examples/groups.csv

# ANOVA post-hoc pairwise comparisons (Bonferroni & Holm)
.build/debug/benchgraph posthoc examples/groups.csv

# 4PL dose-response: fit, interpolate x at response 50, export a PDF figure
.build/debug/benchgraph doseresponse examples/dose-response.csv \
    --interpolate 50 --out examples/dose-response.pdf   # or .svg/.png/.tiff

# Read an .xlsx workbook directly, and export a residual plot
.build/debug/benchgraph anova examples/multipanel/B-treatment-groups.xlsx
.build/debug/benchgraph regress examples/dose-response.csv \
    --residuals --out residuals.svg

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

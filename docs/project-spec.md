# Project And Architecture Spec

Last updated: 2026-07-03. Engine version: `0.1.0-mvp`.

This document describes how BenchGraph is built and why — the system
architecture and the design decisions behind it. It deliberately does not
track feature status or the release plan; that lives in
[MVP and roadmap](./product/mvp-roadmap.md). For positioning and competitor
analysis see [market research](./research/market-research.md).

## Purpose

BenchGraph is a local-first, Mac-native tool for taking experimental data to
trustworthy statistics and publication-quality figures — without writing code.
The repository today contains a working MVP: a validated analysis engine, a CLI
that performs import → analysis → figure export end-to-end, and a SwiftUI
desktop app built on the same engine.

## System Overview

One Swift package (`Package.swift`, Swift 6, macOS 13+) produces three products:

| Product | Kind | Role |
| --- | --- | --- |
| `BenchGraphKit` | Library | The validated engine: tables, import, analyses, provenance, export, project files. UI-agnostic. | 
| `benchgraph` | Executable | A CLI front end demonstrating the full workflow. |
| `BenchGraphApp` | Executable | A SwiftUI macOS app; packaged into `BenchGraph.app` by `scripts/build-app.sh`. |

The engine carries no UI dependencies. The CLI and app are thin front ends over
the same `BenchGraphKit` types, so any analysis behaves identically in both.

## Repository Layout

```text
Sources/
  BenchGraphKit/
    Tables/        DataTable, CSVImporter, XLSXImporter, EditGrid
    Stats/         analyses + self-contained Distributions
    Provenance/    AnalysisResult (the result envelope)
    Export/        SVGRenderer, CGChartRenderer, FigureExport, FigureLayout,
                   ExportManifest, Significance, Theme
    Document/      ProjectDocument (.benchgraph file, schema v2)
  benchgraph/      CLI (main.swift)
  BenchGraphApp/   SwiftUI app (AppModel, ContentView, ChartView, BenchGraphApp)
Tests/             SciPy-validated golden-value + rendering + multi-panel +
                   manifest + XLSX + editable-grid + project-file tests
scripts/           build-app.sh (bundle + signing/notarization/DMG), test.sh
examples/          sample CSV + exported figures
docs/              this documentation
```

## Key Design Decisions

### D1 — Zero external dependencies; self-contained distributions

The engine implements normal, Student's t, and F distributions itself (via a
regularized incomplete beta), so p-values depend on no third-party library.

*Why:* statistical software lives or dies on trust and reproducibility. No
external numerical dependency means no version drift in computed p-values,
simple distribution, and a result that can be reproduced from the source alone.

### D2 — A provenance-rich result envelope

Every analysis returns the same `AnalysisResult` envelope
(`Sources/BenchGraphKit/Provenance/AnalysisResult.swift`), carrying the analysis
name, model formula, named output values, stated assumptions, warnings, the
count of excluded (missing/non-numeric) cells, and the engine version that
produced it.

*Why:* transparency is the product thesis. The UI and CLI never have to
reverse-engineer how a number was produced — the engine ships the explanation
alongside the value.

### D3 — An open, versioned project file (`.benchgraph`)

A project saves as a custom extension wrapping **plain, pretty-printed,
key-sorted JSON** (`ProjectDocument`, schema `version` 2). It stores the raw
data verbatim, the table kind, header flag, the selected analysis (by a
**stable key, decoupled from its UI label**), the presentation options
(error-bar type, plot style, theme, significance/residual toggles), and the
engine version that wrote it. Loads reject any file whose `version` is newer
than the running build understands, tolerate the legacy label-based identifier
written by earlier builds, and read v1 files (whose option fields are absent)
by falling back to defaults — the option fields are optional and decode to nil.

*Why a custom extension rather than just `.json`?* The extension and the
byte-format are independent concerns: JSON is *what the bytes are*; the
extension is *which app owns the document and what it represents to the OS*.
`.json` is a generic, unowned type (`public.json`) — double-clicking one opens
whatever JSON handler the user happens to have, and it can't carry a custom
icon, Quick Look preview, or Spotlight identity. A `.benchgraph` extension (with
its own UTI) lets the app claim the document and be the thing that opens it. It
also buys **format-evolution freedom**: `.json` is a literal promise that the
bytes are JSON forever, whereas `.benchgraph` promises only "a BenchGraph
project," so the encoding can later be gzipped, packaged as a zip, or grow
binary attachments without the extension lying. (For the same reason `.docx`,
`.key`, and Sketch files are all zip archives under a branded extension; none
are named `.zip`.)

*Why keep the bytes open, then?* Because the transparency that matters —
human-readable, git-diffable, no opaque blob — comes entirely from the contents
being JSON, which holds regardless of the extension. Sorted keys +
pretty-printing keep output byte-stable for diffing, on-brand for a transparent,
trustworthy tool and the deliberate opposite of a closed proprietary format.

**Resolved since the first MVP draft:**

- The file **now persists the presentation options** (error-bar type, plot
  style, theme, significance/residual toggles) alongside the data and analysis,
  so "reopens exactly as saved" holds for the app's configurable options. The
  paired/unpaired and Student/Welch choices are encoded in the analysis key
  itself. Full multi-panel *layout* specs are not yet persisted.
- The app **registers the `.benchgraph` document type** with macOS via
  `build-app.sh` (an exported UTI conforming to `public.json` plus
  `CFBundleDocumentTypes` in the Info.plist), and the app delegate routes
  Finder-opened files into the live window, so double-click-to-open works. The
  app and `.benchgraph` documents carry a custom icon, generated in code by
  `scripts/make-icon.swift` (no binary design assets) and packed into
  `assets/AppIcon.icns`. A Quick Look preview is still future polish.

### D4 — Deterministic, dependency-free rendering

Figures render two ways: a text-based `SVGRenderer` that is byte-stable and
therefore snapshot-testable, and a CoreGraphics `CGChartRenderer` for PDF, PNG,
and TIFF. `FigureExport` selects the format from the output file extension.
`FigureLayout` composes several figures into one multi-panel publication figure
(A/B/C labels) through the same renderers, and `ExportManifest` records the data
source, analysis options, and app version alongside an export.

*Why:* deterministic SVG lets figures be regression-tested like any other
output, and CoreGraphics covers the publication raster/vector formats without an
external graphics dependency.

## Validation Methodology

Every analysis is covered by golden-value tests whose reference numbers were
computed independently with SciPy (`scipy.stats`), following the validation
plan's "compare against at least two independent references" guidance. The 4PL
dose-response fit is tested against noise-free data with known parameters, and
SVG output is checked for well-formedness and byte-stable determinism. See the
[roadmap](./product/mvp-roadmap.md) for the current suite size and coverage
table.

## Non-Goals

- **Not a full Prism clone.** Build the smallest credible workflow that makes a
  Mac-heavy lab switch for routine analyses, not every feature.
- **Local-first, no cloud/sync** in the MVP.
- **Direct DMG distribution, not the Mac App Store** (signing/notarization is the
  remaining V1 packaging step).
- **Large-data performance is not a target.** Data is embedded as text in the
  project file on the assumption that bench-science datasets are small.

## Open Questions And Follow-Ups

- Define a **schema migration path** for when `ProjectDocument.version` bumps
  again — today loads reject newer versions and read older ones by treating new
  fields as optional, but there is no explicit upgrade step for structural
  changes.
- **Persist multi-panel layout specs** in the project file (today the staged
  panels live only in the running session; the composed figure and its manifest
  are exported, but the layout itself is not saved).
- Make **grouped tables first-class** (currently parsed but not a first-class
  table kind).
- **XLSX import scope**: the reader handles a single sheet, shared/inline
  strings, and numbers; multi-sheet selection, styled/date cells, and formulas
  (beyond their cached value) are out of scope for now.
- Ship the **signed/notarized DMG**: the pipeline is scripted in
  `build-app.sh`; running it needs an Apple Developer ID credential. Tracked in
  the [roadmap](./product/mvp-roadmap.md).

## Build, Test, Run

```bash
swift build                 # build the library + CLI
./scripts/test.sh           # run the test suite
./scripts/build-app.sh      # build BenchGraph.app (release; pass `debug` for faster builds)
open BenchGraph.app         # launch the desktop app
```

`build-app.sh` produces an ad-hoc-signed bundle by default. For a distributable
build, set `DEVELOPER_ID_APP` (hardened-runtime Developer ID signing),
`MAKE_DMG=1` (package a DMG), and `NOTARY_PROFILE` (submit to `notarytool` and
staple). See the header of `scripts/build-app.sh` for the exact variables.

See the repository's top-level `README.md` for CLI command examples.

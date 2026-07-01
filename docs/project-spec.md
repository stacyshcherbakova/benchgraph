# Project And Architecture Spec

Last updated: 2026-06-30. Engine version: `0.1.0-mvp`.

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
    Tables/        DataTable, CSVImporter
    Stats/         analyses + self-contained Distributions
    Provenance/    AnalysisResult (the result envelope)
    Export/        SVGRenderer, CGChartRenderer, FigureExport, Significance, Theme
    Document/      ProjectDocument (.benchgraph file)
  benchgraph/      CLI (main.swift)
  BenchGraphApp/   SwiftUI app (AppModel, ContentView, ChartView, BenchGraphApp)
Tests/             SciPy-validated golden-value + rendering + project-file tests
scripts/           build-app.sh, test.sh
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
key-sorted JSON** (`ProjectDocument`, schema `version` 1). It stores the raw
pasted data verbatim, the table kind, header flag, the selected analysis (by a
**stable key, decoupled from its UI label**), and the engine version that wrote
it. Loads reject any file whose `version` is newer than the running build
understands, and tolerate the legacy label-based identifier written by earlier
builds.

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

**Known limitations (see open questions):**

- The file does **not yet persist analysis options or chart styling** (error-bar
  type, theme, paired/unpaired choice, post-hoc method, interpolation target,
  etc.). So "reopens exactly as saved" is currently partial: it restores the
  data and *which* analysis, not its full configuration.
- The app does **not yet register the `.benchgraph` document type** with macOS
  (no `CFBundleDocumentTypes` / exported UTI in the Info.plist), so the OS-level
  payoff of a custom extension — double-click-to-open, a custom icon, Quick Look
  — is intended but not wired up. Today the extension functions as a naming
  convention; registering the type is a packaging follow-up.

### D4 — Deterministic, dependency-free rendering

Figures render two ways: a text-based `SVGRenderer` that is byte-stable and
therefore snapshot-testable, and a CoreGraphics `CGChartRenderer` for PDF, PNG,
and TIFF. `FigureExport` selects the format from the output file extension.

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

- **Persist analysis options and chart styling** in the project file so reopen
  is exact (the main remaining gap in D3).
- Define a **schema migration path** for when `ProjectDocument.version` bumps —
  today loads only reject newer versions; there is no upgrade step.
- Make **grouped tables first-class** (currently parsed but not a first-class
  table kind).
- Remaining MVP/V1 work (XLSX import, editable table + undo, multi-panel layout
  and export manifest, signed/notarized DMG) is tracked in the
  [roadmap](./product/mvp-roadmap.md), not here.

## Build, Test, Run

```bash
swift build                 # build the library + CLI
./scripts/test.sh           # run the test suite
./scripts/build-app.sh      # build BenchGraph.app (release; pass `debug` for faster builds)
open BenchGraph.app         # launch the desktop app
```

See the repository's top-level `README.md` for CLI command examples.

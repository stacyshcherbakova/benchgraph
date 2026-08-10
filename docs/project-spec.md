# Project And Architecture Spec

Last updated: 2026-07-30. Engine version: `0.1.0-mvp`.

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
                   ExportManifest, PanelOrder, Significance, Theme
    Docs/          HelpTopic (in-app help catalog + published-guide URLs)
    Document/      ProjectDocument (.benchgraph file, schema v3), PanelRecord
  benchgraph/      CLI (main.swift)
  BenchGraphApp/   SwiftUI app (AppModel, ContentView, ChartView, BenchGraphApp)
Tests/             SciPy-validated golden-value + rendering + multi-panel +
                   manifest + XLSX + editable-grid + project-file +
                   figure-Codable + panel-order + interpolation + help tests
scripts/           build-app.sh (bundle + DMG), test.sh, docs.sh,
                   make-icon.swift
assets/            generated AppIcon.icns
examples/          sample CSVs, plus a four-file multi-panel demo study
docs/              this documentation, including the user guide under guide/
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
key-sorted JSON** (`ProjectDocument`, schema `version` 3). It stores the raw
data verbatim, the table kind, header flag, the selected analysis (by a
**stable key, decoupled from its UI label**), the presentation options
(error-bar type, plot style, theme, significance/residual toggles), the staged
multi-panel figure (see D5), and the engine version that wrote it. Loads reject
any file whose `version` is newer than the running build understands, tolerate
the legacy label-based identifier written by earlier builds, and read v1 and v2
files by falling back to defaults — every field added after v1 is optional and
decodes to nil.

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
  itself.
- Schema v3 **persists the staged multi-panel figure** — the panels in A/B/C
  order, the grid width, and any dose-response interpolation targets — so a
  part-built figure survives a save. How panels are stored is D5.
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

(One caveat on determinism: only SVG is byte-stable. CoreGraphics stamps a
per-render `/ID` into every PDF, so two exports of the same figure never match
byte-for-byte. Snapshot tests therefore assert on SVG and check PDF only for
validity.)

### D5 — Panels persist as the rendered figure, not a re-run recipe

A staged multi-panel figure is stored in the project file as the exact
`FigureExport.Request` that was drawn (`PanelRecord`), not as inputs to
re-analyse on load. The whole render tree — the request, its renderer groups,
significance brackets, and a nominal `PlotPoint` replacing what were tuples — is
`Codable` for this purpose. The panel's `ExportManifest` and its source CSV ride
along as provenance, and thumbnails are re-rendered on load rather than stored.

*Why:* a staged panel is a snapshot of a past chart, and a figure may already be
in a submitted manuscript. Re-deriving it on load would mean that a later change
to a fit tolerance, a kernel bandwidth, or a significance threshold silently
redraws published work — the graphical form of exactly the version drift D1
exists to prevent. Storing the drawn figure also keeps the semantics the app
already has: panels in one figure commonly come from different datasets, so
there is no single "current data" to re-derive them from. The recipe is retained
so a panel can still be traced, and re-derived deliberately, rather than behind
the user's back.

### D6 — One user guide, two lengths

The published site carries the long-form guide (`docs/guide/`). The app carries
a short, task-shaped card per topic, shown from the Help menu, ending in a link
to the full page. Both come from one catalog, `HelpTopic` in the engine, whose
topic `id` is also the slug of its page — and a test asserts every slug has a
page whose title matches, and that no page is unreachable from the app.

*Why:* documentation duplicated by hand drifts, and the app is the wrong place
for reference-length prose. Making the app answer the immediate question and
link out for the rest keeps one authority. Putting the catalog in the engine
rather than the UI is what makes the slug-to-page binding testable — the same
reason `EditGrid` lives there. The guide is deliberately *not* bundled as an app
resource: SwiftPM would require the files to live inside the app target, and
`build-app.sh` copies only the executable into the bundle, so a resource-based
help system would work under `swift run` and silently show nothing in the
shipped `.app`.

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
- **Direct DMG distribution, not the Mac App Store.** Distribution requires an
  Apple Developer Program subscription.
- **Large-data performance is not a target.** Data is embedded as text in the
  project file on the assumption that bench-science datasets are small.

## Open Questions And Follow-Ups

- Define a **schema migration path** for when `ProjectDocument.version` bumps
  past 3 — today loads reject newer versions and read older ones by treating new
  fields as optional, but there is no explicit upgrade step for structural
  changes. Note that `FigureExport.Request`'s synthesized coding keys are now
  part of the file format: renaming a case or an associated-value label is a
  breaking change, pinned by a test rather than by a hand-written encoder.
- **Per-panel themes.** The theme is global: changing it restyles every staged
  panel. Letting each panel carry its own theme would allow mixed figures, at
  the cost of a more complex export path.
- **Show interpolated points on the dose-response chart.** The values appear in
  the result pane; drawing a marker and dropline would need a new `ChartSpec`
  case supported by all three renderers.
- **Split `BenchGraphAppCore` out of the app target** so `AppModel` can be
  tested. Today `BenchGraphApp` is an `.executableTarget` with `@main`, which
  cannot be linked into a test bundle, so the undo tracks and document restore
  are verified by hand.
- Make **grouped tables first-class** (currently parsed but not a first-class
  table kind).
- **XLSX import scope**: the reader handles a single sheet, shared/inline
  strings, and numbers; multi-sheet selection, styled/date cells, and formulas
  (beyond their cached value) are out of scope for now.
- Ship the **DMG**: the pipeline is scripted in `build-app.sh` and needs an
  Apple Developer Program subscription to run.

## Build, Test, Run

```bash
swift build                 # build the library + CLI
./scripts/test.sh           # run the test suite
./scripts/build-app.sh      # build BenchGraph.app (release; pass `debug` for faster builds)
open BenchGraph.app         # launch the desktop app
```

`build-app.sh` builds for local use by default. A distributable DMG needs an
Apple Developer Program subscription; see the header of `scripts/build-app.sh`
for the variables that enable it.

See the repository's top-level `README.md` for CLI command examples.

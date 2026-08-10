# MVP And Product Roadmap

Source check date: 2026-07-30.

## Current Status

**Stage: MVP scope code-complete; V1 roughly a third done.** The analysis,
graphs, export, and provenance core is complete, and the previously outstanding
MVP items are now built: an editable data table with undo/redo, persisted
analysis/chart options, multi-panel layout + export manifest, XLSX import,
copy-as-vector, and residual plots. Since then the multi-panel workflow has been
finished off — panels reorder by dragging, are covered by undo, and persist into
the project file — and the app has gained a Help menu backed by a published
[user guide](../guide/getting-started.md). The `.benchgraph` document type is
registered and the DMG pipeline is scripted.

**Shipping a build needs an Apple Developer Program subscription.** **V1 as
defined below is a larger target** — six of its nine bullets (in-app updates,
crash reporting, journal-size presets, XLSX export, R/Python export, power
calculators) have no code yet. See the ticked [MVP Scope](#mvp-scope) and
[Version Roadmap](#version-roadmap) below.

## Product Thesis

Build a local-first macOS desktop app for bench scientists who need a fast path from experimental data to trustworthy statistics and publication-quality figures.

Do not clone every GraphPad Prism feature. Build the smallest credible workflow that makes a Mac-heavy lab choose it for routine analyses.

## Implementation Status

As of the current build, a Swift implementation exists: a tested engine
(`BenchGraphKit`), a `benchgraph` CLI, and a SwiftUI app (`BenchGraph.app`).
The suite has 120 tests: SciPy-validated stats fixtures plus figure-rendering,
multi-panel, manifest, XLSX-import, editable-grid, project-file,
figure-serialisation, panel-order, interpolation, and help-catalog tests.

| MVP area | Status |
| --- | --- |
| Native macOS app (SwiftUI window) | Done |
| Editable data table (typeable grid) + undo/redo | Done |
| Paste + CSV/TSV import | Done |
| XLSX import (dependency-free ZIP+XML reader) | Done |
| Column / XY templates | Done (grouped: parsed, not first-class) |
| Descriptive stats, t tests (paired/unpaired, Student/Welch) | Done |
| One-way ANOVA + post-hoc (Bonferroni, Holm) | Done |
| Mann-Whitney, Wilcoxon signed-rank | Done |
| Pearson / Spearman, linear regression | Done |
| 4PL dose-response + standard-curve interpolation | Done |
| Normality test (D'Agostino-Pearson) | Done |
| Residual plots (regression / dose-response) | Done |
| Graphs: scatter, bar+error, box, violin, XY, dose-response curve | Done |
| Box / violin plots, journal theme presets | Done |
| Selectable error bars (SD/SEM/CI) | Done |
| Significance annotations on graphs | Done |
| Export: SVG, PDF, PNG, TIFF | Done |
| Copy figure as vector (PDF + SVG to clipboard) | Done |
| Multi-panel layout with A/B/C labels | Done |
| Drag to reorder staged panels | Done |
| Undo/redo across panel staging | Done |
| Export manifest (data source, options, app version) | Done |
| Project file (`.benchgraph`, versioned JSON, save/open) | Done |
| Persist analysis + chart options in project file | Done (schema v3) |
| Persist staged panels + layout in project file | Done (schema v3) |
| `.benchgraph` document type registered (double-click to open) | Done |
| Live provenance (assumptions, warnings, excluded, formula) | Done |
| In-app Help menu + published user guide | Done |
| File menu, standard shortcuts, unsaved-changes tracking | Done |
| Distributable DMG | Pipeline scripted; needs an Apple Developer Program subscription |

## MVP

### Goal

A distributable macOS DMG that lets a user create a local project, enter/import data, run a small set of validated analyses, generate publication-quality graphs, assemble simple figure layouts, and export clean files. Distribution requires an Apple Developer Program subscription.

### MVP User Promise

"Paste your assay data, choose the right table type, run a common analysis, and export a clean figure in minutes, without writing code."

### MVP Scope

- [x] Native macOS document app with one project file.
- [x] Local-first storage. No account required for core use.
- Data entry and import:
  - [x] Paste from Excel/Numbers.
  - [x] CSV/TSV import.
  - [x] Editable data table (typeable grid) with add/remove rows and columns.
  - [x] Basic XLSX import if feasible without large dependency risk. *(dependency-free ZIP+XML reader)*
  - [x] Column, grouped, and XY table templates. *(partial: grouped is parsed but not a first-class template)*
- Analysis:
  - [x] Descriptive statistics.
  - [x] Paired/unpaired t test.
  - [x] One-way ANOVA with common multiple-comparison corrections.
  - [x] Mann-Whitney and Wilcoxon.
  - [x] Pearson/Spearman correlation.
  - [x] Linear regression.
  - [x] Nonlinear regression for standard curve and 4-parameter logistic dose-response. *(interpolation of unknowns exposed in the app as well as the CLI)*
  - [x] Normality checks and residual plots where relevant.
- Graphs:
  - [x] Scatter, column/bar, box, violin, line/XY, dose-response curve.
  - [x] Error bars: SD, SEM, CI.
  - [x] Significance annotations linked to analysis results.
  - [x] Theme presets for common journal-style output.
- Layout and export:
  - [x] Single graph export: PDF, SVG, PNG, TIFF.
  - [x] Copy as vector where possible. *(PDF + SVG to the clipboard)*
  - [x] Simple multi-panel layout with labels A/B/C. *(drag to reorder; saved in the project file)*
  - [x] Export manifest that records data source, analysis options, and app version.
- Provenance:
  - [x] Recompute analyses when source data or options change.
  - [x] Show assumptions, excluded values, model formula, P value adjustment, CI level, and warnings.
  - [x] Keep analysis outputs linked to exact table and graph.
  - [x] Undo/redo across table and option edits. *(including panel staging and reordering)*
- Help:
  - [x] In-app Help menu with task-shaped cards for the core workflows.
  - [x] Published user guide, linked from the app. *(one catalog drives both; a test binds each card to its page)*

### Out Of Scope For MVP

- Cloud collaboration.
- AI assistant.
- Full Prism file import/export.
- Full SPSS/JMP/Stata method breadth.
- Regulatory validation claims.
- Windows version.
- Team admin, SSO, SCIM.
- Complex survey methods, mixed models, survival analysis, SEM, Bayesian modules.

## Minimum Credible Feature Set

The product is credible only if it has:

- [x] A polished Mac-native data table and graph editing experience. *(editable spreadsheet-style grid with add/remove rows and columns, plus a live native chart)*
- [x] Accurate calculations for included tests, with independent test fixtures.
- [x] Dose-response and standard-curve workflows.
- [x] Robust import/paste from spreadsheet data. *(CSV/TSV/paste and XLSX)*
- [x] High-quality vector export.
- [x] Persistent project files that reopen exactly. *(schema v3 also persists analysis + chart options and the staged panels)*
- [x] Linked data -> analysis -> graph updates.
- [x] Clear warnings for invalid assumptions, missing data, unequal group sizes, and ambiguous repeated-measures structure.
- [x] Undo/redo across table, analysis, and graph edits.

## Core Workflows

### 1. Spreadsheet To Figure

1. New project.
2. Select table type: column, grouped, or XY.
3. Paste data from Excel/Numbers.
4. Pick analysis template.
5. Review assumptions and results.
6. Generate linked graph.
7. Export graph or layout.

### 2. Dose-Response Or Standard Curve

1. Create XY table.
2. Paste concentration and response values.
3. Select model: linear, log-linear, 4PL.
4. Fit curve and inspect residuals.
5. Interpolate unknowns.
6. Export graph and result table.

### 3. Group Comparison Figure

1. Create grouped table.
2. Enter condition, treatment, replicate data.
3. Choose one-way ANOVA or nonparametric alternative.
4. Apply multiple-comparison correction.
5. Place significance annotations automatically.
6. Adjust final labels and export.

### 4. Multi-Panel Publication Figure

1. Build a graph, then capture it as a panel; repeat for each dataset.
2. Drag the panel cards to set the A/B/C order, and choose the grid width.
3. Export PDF/SVG/TIFF at journal-ready size, with an export manifest.
4. Save the project — the staged panels are stored with it.

## Version Roadmap

### V1: Local Scientific Figure Workbench

**Status: In progress (active target) — MVP scope code-complete, but six of the
nine bullets below have no code yet. Packaging alone does not get us to V1.**

Target: solo researchers and small labs.

- Complete MVP scope. *(done)*
- Strong project file format. *(done — schema v3)*
- Installer DMG and release pipeline. *(scripted; needs an Apple Developer Program subscription)*
- In-app update mechanism. *(not started)*
- Crash reporting with explicit opt-in. *(not started)*
- Expanded graph templates and journal-size presets. *(journal themes shipped; size presets not started — `FigureLayout.Spec` has the geometry but nothing exposes it)*
- More robust XLSX import/export. *(import shipped, single-sheet; there is no XLSX writer at all)*
- R/Python script export for supported analyses. *(not started)*
- Basic sample-size/power calculators. *(not started)*

### V2: Advanced Analysis And Team Workflows

**Status: Not started.**

Target: labs, core facilities, and small biotech teams.

- Two-way and repeated-measures ANOVA.
- Mixed-effects model support for common unbalanced/repeated designs.
- Survival curves, ROC, contingency tables, chi-square/Fisher tests.
- More nonlinear models and custom equations.
- Template library for assay families.
- Optional team workspace for shared templates, not required for local files.
- Comments and review notes inside the project file.
- Plugin or scripting boundary for advanced users.
- Batch processing for repeated plates/assays.
- Better audit log for data edits and analysis option changes.

### V3: Institutional And Regulated Workflows

**Status: Not started.**

Target: larger biotech/pharma/clinical research groups.

- Optional cloud sync and web review.
- SSO/SCIM, lab/team administration.
- Role-based sharing and locked templates.
- Signed analysis reports and stronger audit trails.
- Validation package for selected calculations.
- ELN/LIMS import/export integrations.
- AI-assisted analysis guidance with strict citation/provenance boundaries.
- Automation API for headless exports and CI-style report generation.

## Technical Direction

The MVP architecture is now built; see the
[project and architecture spec](../project-spec.md) for detail. As implemented:

- App: Swift + SwiftUI, with a UI-agnostic engine (`BenchGraphKit`) shared by the app and CLI; AppKit used where needed for document windows, menu commands, and export.
- Rendering: a custom vector-first renderer — a deterministic, text-based SVG renderer plus a Core Graphics renderer for PDF/PNG/TIFF — rather than relying on Swift Charts for export control.
- Data model: a single versioned JSON project document (schema v3) holding the raw data, the analysis specification, the presentation options (error-bar type, plot style, theme, significance/residual toggles), and the staged multi-panel figure, so a project reopens exactly. Panels are stored as the rendered figure rather than a recipe to re-run — see the spec's D5.
- File format: a plain, human-readable, key-sorted JSON `.benchgraph` file — explicit, inspectable, and diffable, with no opaque blobs. The `.benchgraph` document type is registered with macOS (exported UTI + `CFBundleDocumentTypes`), so projects open on double-click. (The earlier SQLite / package-directory option was considered but not adopted.)
- Stats engine: a small validated native Swift core with **zero external dependencies** (self-contained distributions) and independent SciPy reference fixtures. Re-evaluate an embedded R or Rust/C++ numerical core before V2.

Still forward-looking:

- Distribution: `scripts/build-app.sh` scripts the whole DMG pipeline behind environment variables; running it needs an Apple Developer Program subscription. In-app updates remain future work.
- Privacy: default offline. Any telemetry, crash reporting, licensing, or cloud sync must be explicit and separable.

## Product Risks

- **Statistical correctness**: one wrong P value can destroy trust. Use reference datasets, independent calculations, and visible assumptions.
- **Workflow ambiguity**: repeated measures, missing values, nested designs, and multiple comparisons are easy to mis-specify. The UI must guide structure before running tests.
- **Graph export quality**: scientists will judge the app by the exported PDF/SVG/TIFF. Export must be deterministic and editable downstream.
- **Mac distribution friction**: distribution requires an Apple Developer Program subscription, and packaging, licensing, and updates are production work, not polish.
- **Native chart limits**: standard Apple chart components may not satisfy publication layout, axis, annotation, and export requirements.
- **Scope creep**: competing with SPSS/JMP/Stata method breadth is not viable early. Focus on common wet-lab workflows.
- **Pricing pressure**: open-source tools are free and Prism is entrenched. The app needs clear value: less friction, better Mac UX, better exports, and fair lab licensing.
- **IP/trademark**: avoid Prism naming, file-format reverse engineering claims, or marketing that implies compatibility without legal review.

## Validation Plan

- Build golden-data fixtures for every supported analysis.
- Compare outputs against at least two independent references where possible.
- Snapshot test exported PDF/SVG structure and rendered raster output.
- Stress test paste/import with empty cells, text labels, NaN-like tokens, repeated headers, decimal separators, and long column names.
- Usability test with real users on five workflows: t test, one-way ANOVA, 4PL dose-response, standard curve interpolation, and multi-panel export.

## Open Product Questions

- Should V1 include custom nonlinear equations, or only curated models?
- Should the first pricing model be personal/lab perpetual, subscription, or hybrid?
- Should R/Python export be in MVP or V1?
- ~~Is XLSX import critical for MVP?~~ Resolved: basic XLSX import shipped in the MVP via a dependency-free reader.
- ~~Does the target buyer value App Store distribution, or is direct DMG expected?~~ Resolved: direct DMG download, no App Store.

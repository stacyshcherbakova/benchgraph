# MVP And Product Roadmap

Source check date: 2026-05-28.

## Current Status

**Stage: MVP build phase, working toward V1.** The analysis, graphs, export, and
provenance core of the MVP is essentially complete. Remaining MVP gaps:
XLSX import, an editable data table + undo/redo, multi-panel layout + export
manifest, copy-as-vector, residual plots, and a signed/notarized DMG. See the
ticked [MVP Scope](#mvp-scope) and [Version Roadmap](#version-roadmap) below.

## Product Thesis

Build a local-first macOS desktop app for bench scientists who need a fast path from experimental data to trustworthy statistics and publication-quality figures.

Do not clone every GraphPad Prism feature. Build the smallest credible workflow that makes a Mac-heavy lab choose it for routine analyses.

## Implementation Status

As of the current build, a Swift implementation exists: a tested engine
(`BenchGraphKit`), a `benchgraph` CLI, and a SwiftUI app (`BenchGraph.app`).
The suite has 56 tests (39 SciPy-validated stats fixtures plus figure-rendering
and project-file tests).

| MVP area | Status |
| --- | --- |
| Native macOS app (SwiftUI window) | Done |
| Paste + CSV/TSV import, parsed preview | Done |
| Column / XY templates | Done (grouped: parsed, not first-class) |
| Descriptive stats, t tests (paired/unpaired, Student/Welch) | Done |
| One-way ANOVA + post-hoc (Bonferroni, Holm) | Done |
| Mann-Whitney, Wilcoxon signed-rank | Done |
| Pearson / Spearman, linear regression | Done |
| 4PL dose-response + standard-curve interpolation | Done |
| Normality test (D'Agostino-Pearson) | Done |
| Graphs: scatter, bar+error, box, violin, XY, dose-response curve | Done |
| Export: SVG, PDF, PNG, TIFF | Done |
| Project file (`.benchgraph`, versioned JSON, save/open) | Done |
| Live provenance (assumptions, warnings, excluded, formula) | Done |
| XLSX import | Not started |
| Box / violin plots, journal theme presets | Done |
| Significance annotations on graphs | Done; multi-panel layout not started |
| Selectable error bars (SD/SEM/CI) | Done; export manifest not started |
| Signed + notarized DMG | Not started (needs Apple Developer ID) |

## MVP

### Goal

A signed, notarized macOS DMG that lets a user create a local project, enter/import data, run a small set of validated analyses, generate publication-quality graphs, assemble simple figure layouts, and export clean files.

### MVP User Promise

"Paste your assay data, choose the right table type, run a common analysis, and export a clean figure in minutes, without writing code."

### MVP Scope

- [x] Native macOS document app with one project file.
- [x] Local-first storage. No account required for core use.
- Data entry and import:
  - [x] Paste from Excel/Numbers.
  - [x] CSV/TSV import.
  - [ ] Basic XLSX import if feasible without large dependency risk.
  - [x] Column, grouped, and XY table templates. *(partial: grouped is parsed but not a first-class template)*
- Analysis:
  - [x] Descriptive statistics.
  - [x] Paired/unpaired t test.
  - [x] One-way ANOVA with common multiple-comparison corrections.
  - [x] Mann-Whitney and Wilcoxon.
  - [x] Pearson/Spearman correlation.
  - [x] Linear regression.
  - [x] Nonlinear regression for standard curve and 4-parameter logistic dose-response.
  - [x] Normality checks and residual plots where relevant. *(partial: normality done; no residual plot yet)*
- Graphs:
  - [x] Scatter, column/bar, box, violin, line/XY, dose-response curve.
  - [x] Error bars: SD, SEM, CI.
  - [x] Significance annotations linked to analysis results.
  - [x] Theme presets for common journal-style output.
- Layout and export:
  - [x] Single graph export: PDF, SVG, PNG, TIFF.
  - [ ] Copy as vector where possible.
  - [ ] Simple multi-panel layout with labels A/B/C.
  - [ ] Export manifest that records data source, analysis options, and app version.
- Provenance:
  - [x] Recompute analyses when source data or options change.
  - [x] Show assumptions, excluded values, model formula, P value adjustment, CI level, and warnings.
  - [x] Keep analysis outputs linked to exact table and graph.

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

- [x] A polished Mac-native data table and graph editing experience. *(partial: read-only parsed preview + raw-text editor; no editable spreadsheet grid)*
- [x] Accurate calculations for included tests, with independent test fixtures.
- [x] Dose-response and standard-curve workflows.
- [x] Robust import/paste from spreadsheet data. *(partial: CSV/TSV/paste done; XLSX not yet)*
- [x] High-quality vector export.
- [x] Persistent project files that reopen exactly.
- [x] Linked data -> analysis -> graph updates.
- [x] Clear warnings for invalid assumptions, missing data, unequal group sizes, and ambiguous repeated-measures structure.
- [ ] Undo/redo across table, analysis, and graph edits.

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

1. Create or import several graphs.
2. Add them to layout.
3. Align panels and add labels.
4. Export PDF/SVG/TIFF at journal-ready size.
5. Save project with export manifest.

## Version Roadmap

### V1: Local Scientific Figure Workbench

**Status: In progress (active target) — MVP scope not yet complete.**

Target: solo researchers and small labs.

- Complete MVP scope.
- Strong project file format.
- Installer DMG, signed/notarized release pipeline.
- In-app update mechanism.
- Crash reporting with explicit opt-in.
- Expanded graph templates and journal-size presets.
- More robust XLSX import/export.
- R/Python script export for supported analyses.
- Basic sample-size/power calculators.

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
- Data model: a single versioned JSON project document holding the raw data plus the analysis specification. Persisting full graph/layout specs is planned, not yet done.
- File format: a plain, human-readable, key-sorted JSON `.benchgraph` file — explicit, inspectable, and diffable, with no opaque blobs. (The earlier SQLite / package-directory option was considered but not adopted.)
- Stats engine: a small validated native Swift core with **zero external dependencies** (self-contained distributions) and independent SciPy reference fixtures. Re-evaluate an embedded R or Rust/C++ numerical core before V2.

Still forward-looking:

- Distribution: Developer ID signing, notarized DMG, optional Sparkle-style signed updates.
- Privacy: default offline. Any telemetry, crash reporting, licensing, or cloud sync must be explicit and separable.

## Product Risks

- **Statistical correctness**: one wrong P value can destroy trust. Use reference datasets, independent calculations, and visible assumptions.
- **Workflow ambiguity**: repeated measures, missing values, nested designs, and multiple comparisons are easy to mis-specify. The UI must guide structure before running tests.
- **Graph export quality**: scientists will judge the app by the exported PDF/SVG/TIFF. Export must be deterministic and editable downstream.
- **Mac distribution friction**: signing, notarization, DMG packaging, licensing, and updates are production work, not polish.
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
- Is XLSX import critical for MVP, or can CSV/paste cover the first release?
- Does the target buyer value App Store distribution, or is direct DMG expected?

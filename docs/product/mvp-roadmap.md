# MVP And Product Roadmap

Source check date: 2026-05-28.

Working name: BenchGraph. Provisional.

## Product Thesis

Build a local-first macOS desktop app for bench scientists who need a fast path from experimental data to trustworthy statistics and publication-quality figures.

Do not clone every GraphPad Prism feature. Build the smallest credible workflow that makes a Mac-heavy lab choose it for routine analyses.

## Implementation Status

As of the current build, a Swift implementation exists: a tested engine
(`BenchGraphKit`), a `benchgraph` CLI, and a SwiftUI app (`BenchGraph.app`).
The analysis engine is verified by 39 tests against independent SciPy references.

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
| Graphs: scatter, bar+error, XY, dose-response curve | Done |
| Export: SVG, PDF, PNG, TIFF | Done |
| Project file (`.benchgraph`, versioned JSON, save/open) | Done |
| Live provenance (assumptions, warnings, excluded, formula) | Done |
| XLSX import | Not started |
| Box / violin plots, journal theme presets | Not started |
| Significance annotations on graphs, multi-panel layout | Not started |
| Selectable error bars (SD/SEM/CI), export manifest | Partial / not started |
| Signed + notarized DMG | Not started (needs Apple Developer ID) |

## MVP

### Goal

A signed, notarized macOS DMG that lets a user create a local project, enter/import data, run a small set of validated analyses, generate publication-quality graphs, assemble simple figure layouts, and export clean files.

Apple's direct macOS distribution path requires Developer ID signing, notarization, and developer-managed updates/support outside the Mac App Store.[^apple-distribution][^apple-signing]

### MVP User Promise

"Paste your assay data, choose the right table type, run a common analysis, and export a clean figure in minutes, without writing code."

### MVP Scope

- Native macOS document app with one project file.
- Local-first storage. No account required for core use.
- Data entry and import:
  - Paste from Excel/Numbers.
  - CSV/TSV import.
  - Basic XLSX import if feasible without large dependency risk.
  - Column, grouped, and XY table templates.
- Analysis:
  - Descriptive statistics.
  - Paired/unpaired t test.
  - One-way ANOVA with common multiple-comparison corrections.
  - Mann-Whitney and Wilcoxon.
  - Pearson/Spearman correlation.
  - Linear regression.
  - Nonlinear regression for standard curve and 4-parameter logistic dose-response.
  - Normality checks and residual plots where relevant.
- Graphs:
  - Scatter, column/bar, box, violin, line/XY, dose-response curve.
  - Error bars: SD, SEM, CI.
  - Significance annotations linked to analysis results.
  - Theme presets for common journal-style output.
- Layout and export:
  - Single graph export: PDF, SVG, PNG, TIFF.
  - Copy as vector where possible.
  - Simple multi-panel layout with labels A/B/C.
  - Export manifest that records data source, analysis options, and app version.
- Provenance:
  - Recompute analyses when source data or options change.
  - Show assumptions, excluded values, model formula, P value adjustment, CI level, and warnings.
  - Keep analysis outputs linked to exact table and graph.

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

- A polished Mac-native data table and graph editing experience.
- Accurate calculations for included tests, with independent test fixtures.
- Dose-response and standard-curve workflows.
- Robust import/paste from spreadsheet data.
- High-quality vector export.
- Persistent project files that reopen exactly.
- Linked data -> analysis -> graph updates.
- Clear warnings for invalid assumptions, missing data, unequal group sizes, and ambiguous repeated-measures structure.
- Undo/redo across table, analysis, and graph edits.

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

Recommended starting architecture:

- App: Swift + SwiftUI with AppKit where needed for professional table editing, document windows, menu commands, and export.
- Rendering: custom vector-first graph renderer using Core Graphics/PDF/SVG output. Avoid relying only on Swift Charts if it cannot guarantee scientific export control.
- Data model: local document package containing tables, analysis specs, graph specs, layout specs, and generated caches.
- Stats engine: small validated native core for MVP tests, with strict fixtures and independent reference outputs. Re-evaluate embedded R or a Rust/C++ numerical core before V2.
- File format: explicit versioned schema, likely SQLite or a package directory with JSON metadata plus binary caches. Do not hide analysis options in opaque blobs.
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
- Should project files be single-file SQLite, macOS package directory, or zipped package?
- Does the target buyer value App Store distribution, or is direct DMG expected?

## Sources

[^apple-distribution]: Apple macOS distribution overview: https://developer.apple.com/macos/distribution/
[^apple-signing]: Apple Platform Security, app code signing process in macOS: https://support.apple.com/en-mide/guide/security/sec3ad8e6e53/web

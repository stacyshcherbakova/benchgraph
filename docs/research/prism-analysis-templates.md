# Prism Feature Comparison (Reference)

Source check date: 2026-06-07. BenchGraph column checked against the build on
2026-08-10.

Internal reference only. This page lists what GraphPad Prism does and whether
BenchGraph does it, so we can see the gap at a glance. It is research, not
marketing copy and not a compatibility claim.

**BenchGraph** means reachable by a user in the app or the CLI. A capability
that exists in the engine but is not exposed is marked No, with a note.

| Area | Capability | Prism | BenchGraph |
| --- | --- | --- | --- |
| Tables | Column table (one group per column) | Yes | Yes |
| Tables | XY table (x paired with y) | Yes | Yes |
| Tables | Grouped table (rows × column groups, replicates) | Yes | No — parsed, not a first-class template |
| Tables | Contingency table | Yes | No |
| Tables | Survival table | Yes | No |
| Tables | Parts-of-whole table | Yes | No |
| Tables | Multiple-variables table | Yes | No |
| Tables | Nested table (subcolumns within groups) | Yes | No |
| Descriptive | Descriptive statistics, CI of the mean | Yes | Yes |
| Descriptive | Frequency distribution / histogram | Yes | No |
| Descriptive | Row statistics (per-row mean/SD/SEM) | Yes | No |
| Two groups | Unpaired t test (Student) | Yes | Yes |
| Two groups | Unpaired t test (Welch) | Yes | Yes |
| Two groups | Paired t test | Yes | Yes |
| Two groups | One-sample t test | Yes | No — in the engine, not exposed |
| Two groups | Mann-Whitney U | Yes | Yes |
| Two groups | Wilcoxon matched-pairs | Yes | Yes |
| Many groups | One-way ANOVA (ordinary) | Yes | Yes |
| Many groups | Repeated-measures one-way ANOVA | Yes | No |
| Many groups | Brown-Forsythe / Welch ANOVA | Yes | No |
| Many groups | Post-hoc: Bonferroni, Holm | Yes | Yes |
| Many groups | Post-hoc: Tukey, Dunnett, Sidak | Yes | No |
| Many groups | Kruskal-Wallis, Friedman | Yes | No |
| Many groups | Two-way ANOVA | Yes | No |
| Many groups | Three-way ANOVA | Yes | No |
| Many groups | Mixed-effects model (REML) | Yes | No |
| Many groups | Multiple t tests, one per row | Yes | No |
| Many groups | Nested t test / nested one-way ANOVA | Yes | No |
| Assumptions | D'Agostino-Pearson normality test | Yes | Yes |
| Assumptions | Shapiro-Wilk, Anderson-Darling, Kolmogorov-Smirnov | Yes | No |
| Assumptions | Outlier identification (Grubbs, ROUT) | Yes | No |
| Assumptions | Analyse a stack of P values (FDR) | Yes | No |
| Regression | Simple linear regression | Yes | Yes |
| Regression | Residual plots | Yes | Yes |
| Regression | 4PL dose-response fit | Yes | Yes |
| Regression | Interpolate unknowns off a standard curve | Yes | Yes |
| Regression | Wider nonlinear model library (binding, kinetics, exponential) | Yes | No — 4PL only |
| Regression | User-defined equations | Yes | No |
| Regression | Shared / constrained parameters, weighting, model comparison | Yes | No |
| Regression | Deming (Model II) regression | Yes | No |
| Regression | Spline / LOWESS | Yes | No |
| Regression | Smooth, differentiate, integrate a curve | Yes | No |
| Regression | Area under the curve | Yes | No |
| Regression | Multiple linear regression | Yes | No |
| Regression | Logistic regression | Yes | No |
| Correlation | Pearson correlation | Yes | Yes |
| Correlation | Spearman correlation | Yes | Yes |
| Correlation | Correlation matrix across many variables | Yes | No |
| Specialised | Chi-square / Fisher's exact, risk and odds | Yes | No |
| Specialised | Kaplan-Meier survival, log-rank | Yes | No |
| Specialised | Cox proportional hazards | Yes | No |
| Specialised | ROC curve | Yes | No |
| Specialised | Bland-Altman agreement | Yes | No |
| Specialised | Principal component analysis | Yes | No |
| Specialised | Fraction of total / observed vs expected | Yes | No |
| Data prep | Transform X and/or Y | Yes | No |
| Data prep | Transform concentrations (log/antilog dilutions) | Yes | No |
| Data prep | Normalize to 0–100% or defined min/max | Yes | No |
| Data prep | Prune, transpose, remove baseline, column math | Yes | No |
| Graphs | Scatter / XY with fitted curve | Yes | Yes |
| Graphs | Bar chart with error bars | Yes | Yes |
| Graphs | Selectable error bars (SD, SEM, 95% CI) | Yes | Yes |
| Graphs | Box plot | Yes | Yes |
| Graphs | Violin plot | Yes | Yes |
| Graphs | Log axes | Yes | Yes |
| Graphs | Significance brackets linked to the analysis | Yes | Yes |
| Graphs | Journal theme presets | Yes | Yes |
| Graphs | Multi-panel figure layout with A/B/C labels | Yes | Yes |
| Graphs | Journal-size presets | Yes | No |
| Import | Paste from Excel / Numbers | Yes | Yes |
| Import | CSV / TSV import | Yes | Yes |
| Import | XLSX import | Yes | Yes — single sheet |
| Export | PDF and SVG (vector) | Yes | Yes |
| Export | PNG and TIFF (raster) | Yes | Yes |
| Export | Copy figure as vector to the clipboard | Yes | Yes |
| Export | XLSX export | Yes | No |
| Export | Export analysis as R / Python script | No | No — planned for V1 |
| Workflow | Results recompute when data or options change | Yes | Yes |
| Workflow | Undo / redo across edits | Yes | Yes |
| Workflow | Project file holding data, options, and figures | Yes | Yes |
| Workflow | Open, documented, diffable project format | No — proprietary `.pzf` | Yes — versioned JSON |
| Workflow | Assumptions, warnings, and excluded cells shown with every result | Partial | Yes |
| Workflow | Provenance manifest written beside every export | No | Yes |
| Workflow | Command-line interface | No | Yes |
| Workflow | Runs natively on macOS | Yes | Yes |
| Workflow | Runs on Windows | Yes | No |
| Workflow | Works offline with no account | Partial — subscription activation | Yes |

## Where the gaps sit

Everything BenchGraph answers Yes to is validated against SciPy fixtures; see
the [MVP and roadmap](../product/mvp-roadmap.md) for what is planned next.

The concentration of No rows is in grouped and specialised analyses — two-way
ANOVA, survival, contingency, ROC, PCA — and in data preparation, where Prism's
transform-and-normalise steps have no equivalent. The Yes rows cluster in the
common wet-lab path: describe, compare two or several groups, fit a curve, draw
it, export it.

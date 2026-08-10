# Prism Analysis Templates (Reference)

Source check date: 2026-06-07.

Internal reference only. This page catalogs the analyses GraphPad Prism exposes,
so we can scope which ones we need and in what order. It is research, not
marketing copy and not a compatibility claim.

In Prism, the available analyses depend on the **data table type**. The same
"Analyze" dialog filters its options based on whether the active table is XY,
Column, Grouped, Contingency, Survival, Parts of whole, Multiple variables, or
Nested. The sections below follow that structure.

For how this maps to our own scope, see the
[MVP and roadmap](../product/mvp-roadmap.md). The MVP deliberately ships only a
small validated subset of the list below.

## How analyses attach to tables

| Table type | Typical data shape | Primary analyses |
| --- | --- | --- |
| XY | X paired with one or more Y (subcolumns for replicates) | Regression, correlation, curve fit, interpolation, AUC |
| Column | One group per column, values stacked down | Descriptive stats, t tests, one-way ANOVA, normality, outliers |
| Grouped | Rows × column groups with replicates | Two-/three-way ANOVA, multiple t tests, mixed-effects |
| Contingency | Counts in a 2×2 or R×C table | Chi-square, Fisher's exact, risk/odds, diagnostic metrics |
| Survival | Time + event/censor code per subject | Kaplan-Meier, log-rank, Cox regression |
| Parts of whole | Single set of values forming a whole | Fraction of total, observed-vs-expected |
| Multiple variables | One row per subject, one column per variable | Multiple regression, logistic regression, PCA, correlation matrix |
| Nested | Subcolumns nested within group columns | Nested t test, nested one-way ANOVA |

## XY analyses

- **Linear regression** — slope, intercept, confidence bands, runs test.
- **Nonlinear regression (curve fit)** — built-in model library (dose-response,
  exponential, binding, enzyme kinetics, etc.) plus user-defined equations;
  shared/constrained parameters, replicates, weighting, comparison of models.
- **Interpolate a standard curve** — fit a curve, read unknowns back off it.
- **Deming (Model II) linear regression** — error in both X and Y.
- **Spline and LOWESS** — smoothed curve without a model.
- **Smooth, differentiate, or integrate a curve** — curve preprocessing.
- **Area under the curve (AUC)** — total/peak area with baseline handling.
- **Correlation** — Pearson or Spearman for paired X/Y.

## Column analyses

- **Column statistics** — descriptive statistics, CI of the mean, normality and
  lognormality tests, one-sample t / Wilcoxon test.
- **t tests** — paired/unpaired, with Welch's correction; nonparametric
  Mann-Whitney and Wilcoxon matched-pairs.
- **One-way ANOVA** — ordinary, repeated-measures, or Brown-Forsythe/Welch, with
  multiple-comparison corrections (Tukey, Dunnett, Sidak, Holm, Bonferroni, etc.);
  nonparametric Kruskal-Wallis and Friedman.
- **Identify outliers** — Grubbs' and ROUT methods.
- **Normality and lognormality tests** — Shapiro-Wilk, D'Agostino-Pearson,
  Anderson-Darling, Kolmogorov-Smirnov.
- **Frequency distribution** — histogram bins / cumulative.
- **ROC curve** — diagnostic sensitivity/specificity.
- **Bland-Altman** — method-comparison agreement.
- **Analyze a stack of P values** — multiple-comparison/FDR across a P-value set.

## Grouped analyses

- **Two-way ANOVA** — two factors, with or without repeated measures; multiple
  comparisons across rows/columns.
- **Three-way ANOVA** — three factors.
- **Mixed-effects model (REML)** — repeated measures tolerant of missing values.
- **Multiple t tests — one per row** — row-wise comparisons with multiplicity
  correction (e.g., two-stage FDR).
- **Row statistics** — per-row means/SD/SEM/CI.

## Contingency table analyses

- **Chi-square and Fisher's exact test** — association in 2×2 or R×C tables, with
  relative risk, odds ratio, sensitivity, specificity, likelihood ratios, and
  confidence intervals.

## Survival analyses

- **Survival curve (Kaplan-Meier)** — median survival, curves, at-risk handling.
- **Comparison of survival curves** — log-rank and Gehan-Breslow-Wilcoxon tests,
  hazard ratio.
- **Cox proportional hazards regression** — multivariable survival modeling.

## Parts of whole analyses

- **Fraction of total** — express each value as a fraction/percentage of its
  column, row, or grand total.
- **Compare observed distribution with expected** — chi-square or binomial test
  against an expected distribution.

## Multiple variables analyses

- **Correlation matrix** — pairwise correlations across many variables.
- **Multiple linear regression** — several predictors, one continuous outcome.
- **Simple and multiple logistic regression** — binary outcome modeling, ROC,
  classification.
- **Principal component analysis (PCA)** — dimensionality reduction.
- **Select and transform / extract and rearrange** — subset and reshape variables.

## Nested analyses

- **Nested t test** — two groups with subsamples nested in each.
- **Nested one-way ANOVA** — several groups with nested subsamples.

## Data preparation analyses

These behave like analyses (they produce a linked results table that recomputes
when source data changes) but transform data rather than test hypotheses. They are
available across most table types.

- **Transform** — apply functions to X and/or Y.
- **Transform concentrations (X)** — log/antilog dilution handling for X.
- **Normalize** — scale to 0-100% or to defined min/max.
- **Prune rows** — thin or average rows.
- **Remove baseline and column math** — subtract/divide against a baseline column.
- **Transpose X and Y** — swap orientation.
- **Fraction of total** — also usable as a preprocessing step.

## Mapping to MVP scope

For convenience, the analyses the MVP plans to ship as a validated subset:

| Capability | Prism analysis equivalent | MVP? |
| --- | --- | --- |
| Descriptive statistics | Column statistics | Yes |
| t tests (paired/unpaired) | t tests | Yes |
| Nonparametric two-group | Mann-Whitney, Wilcoxon | Yes |
| One-way ANOVA + corrections | One-way ANOVA | Yes |
| Correlation | Pearson/Spearman correlation | Yes |
| Linear regression | Linear regression | Yes |
| Dose-response / standard curve | Nonlinear regression (4PL), Interpolate | Yes |
| Normality / residuals | Normality tests | Yes |
| Two-/three-way ANOVA, mixed-effects | Grouped analyses | V2 |
| Survival, ROC, contingency | Survival / Contingency analyses | V2 |
| Logistic / multiple regression, PCA | Multiple variables analyses | Post-MVP |

See [MVP and roadmap](../product/mvp-roadmap.md) for the full staged plan.

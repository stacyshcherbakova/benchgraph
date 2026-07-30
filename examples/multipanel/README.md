# Multi-panel demo dataset

Synthetic data from one made-up study — compound **BG-118** tested on a cancer
cell line — designed so each file drives a different panel of a four-panel
publication figure. Values are generated with known ground truth plus noise, so
the analyses recover sensible parameters (see below).

| File | Table shape | Analysis to pick | Panel |
| --- | --- | --- | --- |
| `A-dose-response.csv` | XY (concentration, viability), triplicate | 4PL dose-response | Sigmoid curve, log x |
| `B-treatment-groups.csv` | 4 columns × n=12 | One-way ANOVA → post-hoc | Box or violin + significance brackets |
| `C-paired-donors.csv` | 2 columns × 10 donors, paired by row | Paired t test | Bars ± SEM |
| `D-engagement-vs-viability.csv` | XY, 24 wells | Linear regression / Pearson | Scatter + fit line |

`B-treatment-groups.xlsx` is the same data as the CSV, as a workbook — use it to
exercise the XLSX importer.

## Ground truth built into the data

- **A** — 4PL with top 99, bottom 6, EC50 42 nM, Hill 1.15. The fit recovers
  EC50 ≈ 45.5, R² ≈ 0.993.
- **B** — group means 98.5 / 82 / 41.5 / 22. Every pairwise contrast is
  significant after Bonferroni and Holm correction.
- **C** — treatment drops each donor to ~55% of their own baseline, so the
  paired test is strongly significant (p ≈ 1e-9) with donor-level variation
  that would wash out an unpaired test.
- **D** — viability = 101 − 0.83 × engagement + noise. Regression recovers
  slope ≈ −0.84, R² ≈ 0.957.

## Building the figure in the app

1. Import a file (**Import…**), pick the matching analysis, choose the chart
   style, then **Add current chart** in the *Multi-panel figure* section at the
   bottom of the left pane.
2. Repeat for each file. Panels are labelled A, B, C… in staging order; reorder
   by right-clicking a panel card and choosing **Move left** / **Move right**.
   With two or more panels a **Columns** stepper appears to set the grid width.
3. Export with the **Export figure…** button *inside the Multi-panel section*
   (grid icon) — not the one in the toolbar, which exports only the single
   chart currently on screen. It writes one combined SVG / PDF / PNG / TIFF
   plus an export manifest.

Note: staged panels are not saved into a `.benchgraph` project and are not
covered by undo, so build and export a multi-panel figure in one sitting.

`preview.png` is what all four panels look like composed in a 2×2 grid.

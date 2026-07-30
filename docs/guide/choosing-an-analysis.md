# Choosing An Analysis

Every analysis expects your data laid out one of two ways. Getting the layout
right is most of the work; the test itself follows from your design.

## The two table shapes

**Column tables — one group per column.** Each column is a condition, each row
is a replicate. Column headers become the group labels on the figure. Columns do
not have to be the same length; blanks are excluded and counted.

```
Vehicle,Low,High
98.2,81.4,42.1
101.5,79.8,38.7
96.9,84.2,44.0
```

**XY tables — first column x, second column y.** One (x, y) pair per row. Any
further columns are ignored by these analyses.

```
Concentration,Response
1,9.1
3,23.0
10,49.5
```

Switching between a column analysis and an XY analysis **reinterprets the grid
you already have**. Going from a four-group ANOVA to linear regression will read
columns 1 and 2 as x and y and leave the rest out of the analysis. The hint line
under the picker always states the current expectation.

## Which test

| Your situation | Analysis | Table |
| --- | --- | --- |
| Summarise one column | Descriptive statistics | Column |
| Is one column normally distributed? | Normality (D'Agostino-Pearson) | Column |
| Two independent groups | Unpaired t test (Welch) | Column |
| Two independent groups, equal variances assumed | Unpaired t test (Student) | Column |
| Two measurements on the same subjects | Paired t test | Column |
| Two groups, not normally distributed | Mann-Whitney U | Column |
| Two paired measurements, not normally distributed | Wilcoxon signed-rank | Column |
| Three or more groups | One-way ANOVA | Column |
| Which groups differ, after ANOVA | ANOVA post-hoc (pairwise) | Column |
| Do two variables move together? | Pearson correlation | XY |
| As above, but ranked or non-linear | Spearman correlation | XY |
| Fit a straight line | Linear regression | XY |
| Fit a sigmoid, get an EC50 | 4PL dose-response | XY |

### Notes on the ones people get wrong

**Welch is the default, and usually right.** It does not assume the two groups
have equal variances. Only choose Student's if you have a positive reason to
assume equal variance.

**Paired means paired by row.** For a paired t test or Wilcoxon, row 3 of column
1 and row 3 of column 2 must be the same subject. Pairing removes
between-subject variation, so it detects real differences an unpaired test would
miss — but only if the rows genuinely correspond.

**Run ANOVA before post-hoc.** ANOVA answers "do these groups differ at all?".
Post-hoc answers "which ones?", with Bonferroni and Holm corrections for the
multiple comparisons. Comparing every pair with t tests and no correction
inflates your false-positive rate.

**Correlation is not regression.** Correlation measures how tightly two
variables move together, with neither treated as the cause. Regression fits a
line to predict y from x. If it matters which variable is which, you want
regression.

## Read the provenance before you report

The result pane lists the **assumptions** each test relies on and **warns** when
your data strains them — a small sample for a four-parameter fit, a fit that did
not fully converge, an interpolation target outside the fitted range.

**Excluded cells** counts anything blank or non-numeric that was left out. If
that number surprises you, check the grid before trusting the result.

---

Next: [Multi-panel figures](./multi-panel-figures.md) or
[Exporting and provenance](./exporting-and-provenance.md).

# Getting Started

BenchGraph turns a table of measurements into a validated statistic and a
publication-ready figure, without writing code. This page walks through the
whole loop once.

The window has two halves. On the **left** is your input: the data grid and the
analysis and chart options. On the **right** is the output: the result, the
assumptions behind it, and the chart. Everything on the right recomputes as you
change anything on the left — there is no "run" button.

The app opens with a sample dose-response dataset already loaded, so there is a
live figure to look at before you have typed anything. Replace it whenever you
are ready.

## 1. Get your data in

Four ways, whichever suits you:

- **Type into the grid.** Click a cell and type. **Row** and **Column** add
  more.
- **Paste.** Copy a block of cells from Excel or Numbers and press **Paste**.
- **Import a file.** Press **Import…** for a `.csv`, `.tsv`, or `.xlsx`
  workbook.
- **Load a sample.** Press **Sample** for a small dataset shaped to the analysis
  you have selected.

Tick **Header row** if your first row holds column names rather than
measurements. Those names become the group labels on your figure, so they are
worth getting right.

## 2. Pick an analysis

Choose from the menu at the top of the left pane. The grey line underneath tells
you what shape the data needs — for example *"One group per column. Headers name
the groups."*

Analyses fall into two families, and switching between them changes how your
columns are read. [Choosing an analysis](./choosing-an-analysis.md) covers which
test suits which design.

## 3. Read the result, not just the number

The right pane gives you more than a p-value:

- **The value** — the statistic, its degrees of freedom, and the p-value.
- **The formula** — exactly what was computed.
- **Assumptions** — what the test relies on. Check these before you report it.
- **Warnings** — where your data strains those assumptions.
- **Excluded cells** — how many blank or non-numeric cells were left out.

Every number is selectable, so you can copy a value straight into a manuscript.

## 4. Shape the figure

Depending on the analysis you will see some of:

- **Plot** — draw grouped data as bars, a box plot, or a violin.
- **Error bars** — SD, SEM, or a 95% confidence interval. These say very
  different things; pick deliberately and state which you used.
- **Significance** — draw brackets with stars over the compared groups.
- **Graph / Residuals** — for regression and dose-response, switch between the
  fit and its residuals.
- **Theme** — a journal preset controlling palette and fonts.

## 5. Export

- **Export chart…** saves the chart currently on screen.
- **Copy (vector)** puts it on the clipboard as PDF and SVG, ready to paste into
  Illustrator, Word, or Keynote.

Use `.svg` or `.pdf` to stay vector and scale without loss; `.png` and `.tiff`
are raster. A `.manifest.json` is written alongside recording how the figure was
made — see [Exporting and provenance](./exporting-and-provenance.md).

To combine several charts into one lettered figure, see
[Multi-panel figures](./multi-panel-figures.md).

## 6. Save your work

**Save** writes a `.benchgraph` project holding your data, your options, and any
staged panels. It is plain, versioned JSON, so it stays readable and diffable.
Double-clicking one in Finder opens it.

## Undo covers everything

⌘Z undoes any change — a cell edit, an option change, staging or clearing a
panel. ⇧⌘Z redoes. A run of typing collapses into one undo step, so you are not
stepping back a character at a time.

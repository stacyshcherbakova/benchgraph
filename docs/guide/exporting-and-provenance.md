# Exporting And Provenance

Every export can be traced back to the data and the options that produced it.

## Getting the figure out

| Action | What it does |
| --- | --- |
| **Export chart…** | Writes the single chart currently on screen |
| **Export panels…** | Writes the staged panels as one composed multi-panel figure |
| **Copy (vector)** | Puts the figure on the clipboard as both PDF and SVG |

**Copy (vector)** pastes straight into Illustrator, Word, Keynote, or Google
Docs as editable vector art rather than a screenshot.

## Choosing a format

The file extension picks the format.

| Extension | Kind | Use it for |
| --- | --- | --- |
| `.svg` | Vector | Editing in Illustrator or Inkscape; web |
| `.pdf` | Vector | Journal submission; LaTeX |
| `.png` | Raster | Slides, quick sharing |
| `.tiff` | Raster | Journals that demand TIFF |

Vector scales to any size without softening. Use raster only where something
downstream requires it.

## The manifest

Every export writes a `.manifest.json` next to the figure. It records:

- the analysis that was run and the formula used
- the table shape, header setting, row count, and column names
- the chart options — error-bar kind, plot style, significance, theme
- the engine version that produced it
- the full result, including assumptions, warnings, and excluded-cell count

Keep it with the figure — it is what makes the figure reproducible later, or by
someone else. Multi-panel exports get a manifest listing every panel in order
with its letter and title.

The manifest does **not** contain your raw data, so it is safe to send to a
collaborator alongside the figure. Your data lives in the project file.

## Project files

**Save** writes a `.benchgraph` file holding the data, every option, and any
staged panels, so a session reopens exactly as you left it. Double-clicking one
in Finder opens it.

The format is pretty-printed, key-sorted JSON with named fields and a schema
version, so it diffs cleanly in version control and is readable without the app.
Older project files keep loading — options that did not exist yet come back as
defaults.

## Why panels do not redraw themselves

A staged panel is stored as **the figure that was drawn**, not as instructions
to redraw it later. Reopening a project shows the same figure you staged, byte
for byte.

If panels were re-derived on load, a later change to a fitting tolerance or a
smoothing bandwidth could alter a figure that is already in a submitted
manuscript. The analysis that produced each panel is kept
alongside it as provenance, so a panel can still be traced back — but what you
saw is what you get back.

---

Back to [Getting started](./getting-started.md), or see the
[project spec](../project-spec.md) for the reasoning behind the file format.

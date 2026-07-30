# Exporting And Provenance

A figure is worth little if you cannot say where its numbers came from. Every
export BenchGraph writes can be traced back to the data and the options that
produced it.

## Getting the figure out

| Action | What it does |
| --- | --- |
| **Export chart…** | Writes the single chart currently on screen |
| **Export panels…** | Writes the staged panels as one composed multi-panel figure |
| **Copy (vector)** | Puts the figure on the clipboard as both PDF and SVG |

**Copy (vector)** is usually the fastest route into a manuscript: paste straight
into Illustrator, Word, Keynote, or Google Docs and it arrives as editable
vector art rather than a screenshot.

## Choosing a format

The file extension picks the format.

| Extension | Kind | Use it for |
| --- | --- | --- |
| `.svg` | Vector | Editing in Illustrator or Inkscape; web |
| `.pdf` | Vector | Journal submission; LaTeX |
| `.png` | Raster | Slides, quick sharing |
| `.tiff` | Raster | Journals that demand TIFF |

Prefer a vector format wherever it is accepted. Vector output scales to any size
without softening, and journals routinely print figures larger or smaller than
you drew them. Reach for raster only when something downstream insists on it.

## The manifest

Every export writes a `.manifest.json` next to the figure. It records:

- the analysis that was run and the formula used
- the table shape, header setting, row count, and column names
- the chart options — error-bar kind, plot style, significance, theme
- the engine version that produced it
- the full result, including assumptions, warnings, and excluded-cell count

Keep it with the figure. Months later it answers "what exactly did I do here?"
without you having to remember, and it makes a figure reproducible by someone
who was not there. Multi-panel exports get a manifest listing every panel in
order with its letter and title.

The manifest deliberately does **not** contain your raw data — it is a
description of the analysis, safe to pass to a collaborator alongside the
figure. Your data lives in the project file.

## Project files

**Save** writes a `.benchgraph` file holding the data, every option, and any
staged panels, so a session reopens exactly as you left it. Double-clicking one
in Finder opens it.

The format is deliberately plain: pretty-printed, key-sorted JSON with named
fields, and a schema version. That means it diffs cleanly in version control,
you can read it without the app, and nothing about your analysis is locked in an
opaque blob. Older project files keep loading — options that did not exist yet
come back as defaults.

## Why panels do not redraw themselves

A staged panel is stored as **the figure that was drawn**, not as instructions
to redraw it later. Reopening a project therefore shows you the same figure you
staged, byte for byte.

This is deliberate. If panels were re-derived on load, a later improvement to a
fitting tolerance or a smoothing bandwidth could quietly change a figure that is
already in a submitted manuscript. The analysis that produced each panel is kept
alongside it as provenance, so a panel can still be traced back — but what you
saw is what you get back.

---

Back to [Getting started](./getting-started.md), or see the
[project spec](../project-spec.md) for the reasoning behind the file format.

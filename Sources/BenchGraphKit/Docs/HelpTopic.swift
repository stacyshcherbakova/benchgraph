import Foundation

/// One task-shaped help card shown inside the app.
///
/// The app carries the short form — a summary and a handful of imperative steps
/// — while the published guide carries the long form. `id` is both the card's
/// identity and the slug of its page under `docs/guide/`, so `HelpTopicTests`
/// can prove every in-app "read the full guide" link resolves to a page that
/// actually exists (spec D6).
public struct HelpTopic: Identifiable, Sendable, Equatable, Codable {
    public let id: String
    public let title: String
    public let summary: String
    public let steps: [String]

    public init(id: String, title: String, summary: String, steps: [String]) {
        self.id = id
        self.title = title
        self.summary = summary
        self.steps = steps
    }
}

/// The published documentation site, and the in-app help catalog that links into it.
public enum BenchGraphDocs {

    /// Root of the published guide. Mirrors `site_url` in `mkdocs.yml`.
    public static let siteURL = URL(string: "https://stacyshcherbakova.github.io/benchgraph/")!

    /// The page for a guide slug.
    ///
    /// MkDocs runs with `use_directory_urls` at its default of `true`, so
    /// `docs/guide/getting-started.md` is published at `…/guide/getting-started/`
    /// — a trailing-slash directory URL, not a `.md` file. Building the `.md`
    /// form here would 404 from every help card.
    public static func url(forGuide slug: String) -> URL {
        siteURL.appendingPathComponent("guide").appendingPathComponent(slug, isDirectory: true)
    }

    public static func topic(_ slug: String) -> HelpTopic? {
        topics.first { $0.id == slug }
    }

    public static let topics: [HelpTopic] = [
        HelpTopic(
            id: "getting-started",
            title: "Getting Started",
            summary: """
            BenchGraph turns a table of measurements into a validated statistic \
            and a publication-ready figure. The left pane is your data and \
            options; the right pane is the result and the chart, both recomputed \
            live as you edit.
            """,
            steps: [
                "Put your data in the grid: type into it, press Paste for data copied from Excel or Numbers, or press Import… for a CSV, TSV, or XLSX file.",
                "Tick Header row if your first row holds column names.",
                "Pick an analysis from the menu at the top of the left pane. The grey line under it tells you what shape the data needs.",
                "Read the result on the right — the value, the formula used, the assumptions it relies on, and any warnings.",
                "Adjust the chart with the Plot, Error bars, Significance, and Theme controls.",
                "Press Export chart… to save the figure as SVG, PDF, PNG, or TIFF.",
                "⌘Z undoes anything, including option changes; ⇧⌘Z redoes."
            ]),
        HelpTopic(
            id: "choosing-an-analysis",
            title: "Choosing An Analysis",
            summary: """
            Each analysis expects the data laid out one of two ways. Column \
            analyses read one group per column; XY analyses read the first \
            column as x and the second as y. Switching between the two \
            reinterprets the grid, so check the hint under the picker.
            """,
            steps: [
                "One group per column — descriptive statistics, t tests, ANOVA and its post-hoc comparisons, Mann-Whitney, Wilcoxon, and normality.",
                "Comparing exactly two columns — t tests use the first two columns; paired tests and Wilcoxon match them row by row, so keep each subject on its own row.",
                "Three or more groups — use one-way ANOVA, then ANOVA post-hoc for the pairwise comparisons with Bonferroni and Holm correction.",
                "First column x, second column y — correlation, linear regression, and 4PL dose-response.",
                "Check the Assumptions list in the result before reporting: it names what the test relies on, and Warnings flags where your data strains it.",
                "Excluded cells counts anything blank or non-numeric that was left out of the calculation."
            ]),
        HelpTopic(
            id: "multi-panel-figures",
            title: "Multi-Panel Figures",
            summary: """
            A multi-panel figure is built by capturing one chart at a time. Get a \
            chart looking right, capture it as a panel, then change the data or \
            analysis and capture the next. Panels are lettered A, B, C… by \
            position and export as one combined figure.
            """,
            steps: [
                "Build a chart as usual, then press Add current chart in the Multi-panel figure section at the bottom of the left pane.",
                "Load the next dataset and pick its analysis, then press Add current chart again. Panels can come from completely different files.",
                "Drag a panel card sideways to reorder it — the letters follow position, so dragging a card to the front makes it A. Right-click a card for Move left / Move right instead.",
                "Set Columns to choose how many panels sit in each row. The summary line shows the resulting grid.",
                "Press Export panels… to write the combined figure. The Export chart… button in the toolbar exports only the single chart on screen.",
                "Staged panels are saved with the project and covered by ⌘Z, so a Clear can be undone."
            ]),
        HelpTopic(
            id: "exporting-and-provenance",
            title: "Exporting And Provenance",
            summary: """
            Every export can be traced back to the data and options that produced \
            it. Figures go out as vector or raster, and a manifest written \
            alongside records exactly how the numbers were obtained.
            """,
            steps: [
                "Export chart… writes the single chart on screen; Export panels… writes the staged multi-panel figure.",
                "Choose the format by file extension: .svg and .pdf stay vector and scale without loss, .png and .tiff are raster.",
                "Copy (vector) puts the figure on the clipboard as both PDF and SVG, for pasting straight into Illustrator, Word, or Keynote.",
                "A .manifest.json is written next to the figure recording the data source, analysis, options, engine version, and the full result — keep it with the figure for your records.",
                "Save the project as a .benchgraph file to keep the data, options, and staged panels together. The format is plain JSON and versioned, so it stays readable.",
                "Panels are stored exactly as they were drawn, so reopening a project will not silently redraw a figure you have already published."
            ])
    ]
}

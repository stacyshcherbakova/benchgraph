import Foundation

/// A provenance record written alongside an exported figure.
///
/// The roadmap asks for "an export manifest that records data source, analysis
/// options, and app version." This captures exactly that as plain, key-sorted
/// JSON: which analysis ran, over what data shape, with which presentation
/// options, and the full result envelope — so an exported figure can always be
/// traced back to how it was produced.
public struct ExportManifest: Codable, Equatable, Sendable {
    /// Producing application name.
    public var app: String
    /// Engine version that produced the figure and results.
    public var engineVersion: String
    /// ISO-8601 timestamp of the export.
    public var exportedAt: String

    /// Human-readable analysis name (e.g. "Unpaired t test (Welch)").
    public var analysis: String
    /// Stable analysis key, decoupled from the display label.
    public var analysisKey: String
    /// Table shape the data was interpreted as ("column" / "xy" / "grouped").
    public var tableKind: String
    /// Whether the first data row was treated as a header.
    public var hasHeader: Bool
    /// Number of data rows in the source table.
    public var rowCount: Int
    /// Column names of the source table.
    public var columnNames: [String]

    /// Error-bar statistic, when the figure is a bar chart.
    public var errorBar: String?
    /// Column-figure plot style, when applicable.
    public var plotStyle: String?
    /// Whether significance brackets were drawn, when applicable.
    public var showSignificance: Bool?
    /// Journal theme preset name.
    public var theme: String

    /// The full result envelope (values, assumptions, warnings, exclusions).
    public var result: AnalysisResult?

    public init(
        analysis: String,
        analysisKey: String,
        tableKind: String,
        hasHeader: Bool,
        rowCount: Int,
        columnNames: [String],
        errorBar: String? = nil,
        plotStyle: String? = nil,
        showSignificance: Bool? = nil,
        theme: String,
        result: AnalysisResult? = nil,
        app: String = "BenchGraph",
        engineVersion: String = BenchGraph.version,
        exportedAt: String = ExportManifest.timestamp()
    ) {
        self.app = app
        self.engineVersion = engineVersion
        self.exportedAt = exportedAt
        self.analysis = analysis
        self.analysisKey = analysisKey
        self.tableKind = tableKind
        self.hasHeader = hasHeader
        self.rowCount = rowCount
        self.columnNames = columnNames
        self.errorBar = errorBar
        self.plotStyle = plotStyle
        self.showSignificance = showSignificance
        self.theme = theme
        self.result = result
    }

    /// Encode to pretty, key-sorted JSON (stable, human-inspectable, diffable),
    /// matching the project-file style.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// A default export filename derived from an image path (e.g.
    /// `figure.pdf` → `figure.manifest.json`).
    public static func filename(forFigure figurePath: String) -> String {
        let url = URL(fileURLWithPath: figurePath)
        let base = url.deletingPathExtension().lastPathComponent
        return "\(base).manifest.json"
    }

    public static func timestamp(_ date: Date = Date()) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }
}

/// A provenance record for a multi-panel figure export: which panels it
/// contains, in order, plus the app/engine/theme that produced it.
public struct LayoutManifest: Codable, Equatable, Sendable {
    public struct PanelEntry: Codable, Equatable, Sendable {
        public let label: String
        public let title: String
        public init(label: String, title: String) {
            self.label = label
            self.title = title
        }
    }

    public var app: String
    public var engineVersion: String
    public var exportedAt: String
    public var theme: String
    public var panels: [PanelEntry]

    public init(theme: String, panels: [PanelEntry],
                app: String = "BenchGraph",
                engineVersion: String = BenchGraph.version,
                exportedAt: String = ExportManifest.timestamp()) {
        self.app = app
        self.engineVersion = engineVersion
        self.exportedAt = exportedAt
        self.theme = theme
        self.panels = panels
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}

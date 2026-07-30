import Foundation

/// A BenchGraph project file: an explicit, versioned, human-inspectable JSON
/// document holding the data and analysis specification, so a project reopens
/// exactly as it was saved. The roadmap insists analysis options not be hidden
/// in opaque blobs — this is plain JSON with named fields.
public struct ProjectDocument: Codable, Equatable {

    /// Current on-disk schema version. Bump when the shape changes.
    ///
    /// v2 adds the chart/analysis presentation options so a saved project
    /// reopens *exactly* as configured, not just with its data and analysis.
    ///
    /// v3 adds the staged multi-panel figure — the panels themselves, the grid
    /// width, and any 4PL interpolation targets — so a part-built figure
    /// survives a save. Panels are stored as the rendered figure rather than a
    /// recipe to re-run (see the spec's D5).
    ///
    /// Every field added after v1 is optional, so older files still load: the
    /// options come back nil and the app falls back to its defaults.
    public static let currentVersion = 3

    /// Conventional file extension for project files.
    public static let fileExtension = "benchgraph"

    public var version: Int
    /// How the data columns should be interpreted.
    public var tableKind: TableKind
    /// The source data exactly as entered/pasted (CSV/TSV text).
    public var data: String
    /// Whether the first row is a header.
    public var hasHeader: Bool
    /// The selected analysis, stored by a stable identifier (not its display
    /// label), so re-wording the UI label does not break older project files.
    public var analysisName: String
    /// Engine version that wrote the file, for provenance.
    public var savedWithEngine: String

    // MARK: Presentation options (schema v2+, optional for back-compat)

    /// Which spread statistic the bar error bars represent (SD / SEM / 95% CI).
    public var errorBar: ErrorBarKind?
    /// How column data is drawn, stored as an opaque UI token (e.g. the app's
    /// "Bars" / "Box" / "Violin"); the engine treats it as a plain string.
    public var plotStyle: String?
    /// Whether significance brackets are drawn on column figures.
    public var showSignificance: Bool?
    /// Name of the journal theme preset applied to the figure.
    public var themeName: String?
    /// Whether a regression/dose-response figure shows residuals instead of the fit.
    public var showResiduals: Bool?

    // MARK: Multi-panel staging (schema v3+, optional for back-compat)

    /// Figures staged for the multi-panel layout, in A/B/C order.
    public var panels: [PanelRecord]?
    /// How many panels per row in the composed figure.
    public var layoutColumns: Int?
    /// 4PL response values to interpolate x back at.
    public var interpolateTargets: [Double]?

    public init(
        tableKind: TableKind,
        data: String,
        hasHeader: Bool,
        analysisName: String,
        errorBar: ErrorBarKind? = nil,
        plotStyle: String? = nil,
        showSignificance: Bool? = nil,
        themeName: String? = nil,
        showResiduals: Bool? = nil,
        panels: [PanelRecord]? = nil,
        layoutColumns: Int? = nil,
        interpolateTargets: [Double]? = nil,
        version: Int = ProjectDocument.currentVersion,
        savedWithEngine: String = BenchGraph.version
    ) {
        self.version = version
        self.tableKind = tableKind
        self.data = data
        self.hasHeader = hasHeader
        self.analysisName = analysisName
        self.savedWithEngine = savedWithEngine
        self.errorBar = errorBar
        self.plotStyle = plotStyle
        self.showSignificance = showSignificance
        self.themeName = themeName
        self.showResiduals = showResiduals
        self.panels = panels
        self.layoutColumns = layoutColumns
        self.interpolateTargets = interpolateTargets
    }

    public enum LoadError: Error, Equatable {
        case unreadable
        case malformed(String)
        case unsupportedVersion(Int)
    }

    /// Encode to pretty, key-sorted JSON (stable output for diffing).
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    public func save(to url: URL) throws {
        try encoded().write(to: url, options: .atomic)
    }

    /// Decode from JSON, rejecting versions newer than this build understands.
    public static func decoded(from data: Data) throws -> ProjectDocument {
        let doc: ProjectDocument
        do {
            doc = try JSONDecoder().decode(ProjectDocument.self, from: data)
        } catch {
            throw LoadError.malformed(error.localizedDescription)
        }
        guard doc.version <= currentVersion else {
            throw LoadError.unsupportedVersion(doc.version)
        }
        return doc
    }

    public static func load(from url: URL) throws -> ProjectDocument {
        guard let data = try? Data(contentsOf: url) else { throw LoadError.unreadable }
        return try decoded(from: data)
    }
}
